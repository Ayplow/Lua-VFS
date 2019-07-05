#![feature(try_trait)]
#![feature(plugin)]
#![feature(bind_by_move_pattern_guards)]
#![plugin(luatools)]
use serde::Serialize;
use std::collections::HashMap;
use std::env;
use std::fs::File;
use std::io::{self, Read, Write};
use std::ops::Try;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use structopt::StructOpt;
use which::which;

use path_clean::PathClean;

pub fn absolute_path<P>(path: P) -> io::Result<PathBuf>
where
    P: AsRef<Path>,
{
    let path = path.as_ref();
    if path.is_absolute() {
        Ok(path.to_path_buf().clean())
    } else {
        Ok(env::current_dir()?.join(path).clean())
    }
}
#[derive(StructOpt, Debug)]
/// Packages bundles of lua source files to allow simpler packaging and encapsulation.
struct Args {
    #[structopt(short, long)]
    /// Path to output bundle to.
    output: Option<PathBuf>,
    /// The entrypoint script for the bundle
    ///
    /// If output option isn't specified, bundle will be output to [basename].bundle.lua
    entrypoint: PathBuf,
    #[structopt(subcommand)]
    strategy: Strategy,
}
#[derive(StructOpt, Debug)]
/// Discovery strategy for files to bundle
enum Strategy {
    #[structopt(name = "active")]
    Active {
        #[structopt(long, value_name = "FILE")]
        /// Path to a lua interpreter
        luapath: Option<PathBuf>,
        #[structopt(short, long, value_name = "FILE")]
        /// An environment emulator to use for the script
        emuenv: Option<PathBuf>,
        /// Arguments for the script
        args: Vec<String>,
    },
}
#[macro_export]
macro_rules! or {
    ( $x:expr $(, $y:expr)* ) => {
        $x.into_result()$(.or_else(|_| $y.into_result()))*.ok()
    }
}
fn consume_until<I1, I2>(iter: &mut I1, until: &mut I2) -> Option<Vec<I1::Item>>
where
    I1: Iterator,
    I2: Iterator,
    I1::Item: PartialOrd<I2::Item> + std::marker::Copy,
{
    let mut found = Vec::new();
    let mut looking_for = until.next().unwrap();
    for value in iter {
        found.push(value);
        if value == looking_for {
            let next = until.next();
            if next.is_none() {
                return Some(found);
            }
            looking_for = next.unwrap();
        }
    }
    None
}
#[derive(Serialize)]
struct TemplateData<'a> {
    files: String,
    cwd: String,
    entrypoint: String,
    is_windows: &'a str,
}
#[paw::main]
fn main(args: Args) -> Result<(), Box<dyn std::error::Error>> {
    let has_load: bool;
    let mut io_paths: Vec<PathBuf> = Vec::new();
    let mut load_paths: Vec<PathBuf> = Vec::new();
    match args.strategy {
        Strategy::Active {
            args: script_args,
            luapath,
            emuenv,
        } => {
            let intercept_script = format!(
                "(function(...) {} end)({})",
                include_lua!("lua/intercept.lua"),
                match emuenv.as_ref().and_then(|buf| buf.to_str()) {
                    Some(s) => format!("\"{}\"", s),
                    _ => "nil".into(),
                }
            );
            let interpreter =
                or!(luapath, which("lua"), which("lua53")).ok_or("Couldnt find lua executable")?;
            let mut args = vec![
                "-e".into(),
                intercept_script,
                args.entrypoint.to_str().unwrap().into(),
            ];
            args.extend(script_args);

            let mut child = Command::new(interpreter)
                .args(args)
                .stdout(Stdio::piped())
                .spawn()?;
            let stdout = child
                .stdout
                .take()
                .ok_or("Could not capture standard output.")?;
            let mut bytes = stdout.bytes().map(|r| r.unwrap());
            let start_marker = "[[VFS::INTERCEPTED]]";
            let end_marker = "[[VFS::RESULTS_DONE]]";
            let output = consume_until(&mut bytes, &mut start_marker.bytes())
                .and_then(|_| consume_until(&mut bytes, &mut end_marker.bytes()))
                .and_then(|mut b| {
                    b.truncate(b.len() - end_marker.len());
                    String::from_utf8(b).ok()
                })
                .ok_or("Malformed interception script payload")?;

            child.kill()?;
            let re = regex::Regex::new("/ /:/.*\n")?;
            let mut result = re.split(&output);
            has_load = result.next().unwrap().trim() == "true";
            for paths in &mut [&mut load_paths, &mut io_paths] {
                let mut results = result.next().unwrap().trim().split("/ /?/");
                results.next();
                paths.extend(results.map(|rec| rec.trim().into()));
            }
        }
    }
    let template = mustache::compile_str(include_str!("lua/scoped_template.lua"))?;
    let mut map = HashMap::new();
    for path in io_paths {
        let mut file = File::open(&path)?;
        let mut contents = String::new();
        file.read_to_string(&mut contents)?;
        map.insert(
            absolute_path(path)?,
            format!("{{{}}}", serde_json::to_string(&contents)?),
        );
    }
    if has_load {
        for path in load_paths {
            let mut file = File::open(&path)?;
            let mut contents = String::new();
            file.read_to_string(&mut contents)?;
            map.insert(
                absolute_path(path)?,
                format!("{{{}}}", serde_json::to_string(&contents)?),
            );
        }
    } else {
        for path in load_paths {
            let mut file = File::open(&path)?;
            let mut contents = String::new();
            file.read_to_string(&mut contents)?;
            map.insert(
                absolute_path(path)?,
                format!(
                    "{{{}, function(_ENV) return function(...) {} end end}}",
                    serde_json::to_string(&contents)?,
                    contents
                ),
            );
        }
    }
    let path = PathBuf::from(&args.entrypoint);
    let mut file = File::open(&path)?;
    let mut contents = String::new();
    file.read_to_string(&mut contents)?;
    map.insert(
        absolute_path(path)?,
        format!(
            "{{{}, function(_ENV) return function(...) {} end end}}",
            serde_json::to_string(&contents)?,
            contents
        ),
    );

    write!(
        File::create(match args.output {
            Some(path) => path,
            _ => {
                let mut output_name = PathBuf::from(&args.entrypoint);
                output_name.set_extension(
                    &[
                        "bundle.",
                        output_name.extension().unwrap().to_str().unwrap(),
                    ]
                    .concat(),
                );
                output_name
            }
        })
        .unwrap(),
        "{}",
        template.render_to_string(&TemplateData {
            cwd: serde_json::to_string(&std::env::current_dir()?)?,
            entrypoint: serde_json::to_string(&args.entrypoint)?,
            is_windows: if cfg!(windows) { "true" } else { "false" },
            files: format!(
                "{{ {} }}",
                map.iter()
                    .map(|(key, value)| format!(
                        "[{}] = {}",
                        serde_json::to_string(key).unwrap(),
                        value
                    ))
                    .collect::<Vec<String>>()
                    .join(", ")
            )
        })?
    )?;
    Ok(())
}
