use failure::ResultExt;
use serde::Deserialize;
use serde_json::to_string;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use structopt::StructOpt;

#[derive(Deserialize, Debug)]
struct Intercepted {
    loadfile: Vec<PathBuf>,
    ioopen: Vec<PathBuf>,
}
static INTERCEPT_SCRIPT: &'static str = include_str!("lua/intercept.lua");
// static BUNDLE_TEMPLATE: &'static str = include_str!("lua/scoped_template.lua");
#[derive(Debug, StructOpt)]
/// Bundle your lua projects into a single script
struct Opts {
    #[structopt(short, long)]
    /// Insert loaded lua scripts inline to support interpreters without
    /// the load function.
    preload: bool,
    #[structopt(short, long)]
    /// File to write the generated bundle to.
    output: Option<PathBuf>,
    #[structopt(short, long, default_value = "lua")]
    /// Path to the lua executable to use.
    interpreter: PathBuf,
    #[structopt(default_value = "init.lua")]
    /// The main file of your lua project.
    target: PathBuf,
    /// The arguments to pass to the lua script.
    arg: Vec<String>,
}

fn path_for_vfs(path: &std::path::Path) -> Option<String> {
    use std::path::Component;
    if let Ok(canonical) = std::fs::canonicalize(path) {
        let components = canonical.components().map(|c| match c {
            Component::RootDir => Some(""),
            Component::CurDir => Some("."),
            Component::ParentDir => Some(".."),
            // TODO: Implement prefix translation
            Component::Prefix(_) => Some(""),
            Component::Normal(ref s) => s.to_str()
        })
            .collect::<Option<Vec<_>>>();

        return components.map(|v| {
            if v.len() == 1 && v[0].is_empty() {
                // Special case for '/'
                "/".to_string()
            } else {
                v.join("/")
            }
        })
    }
    None
}

#[paw::main]
fn main(opts: Opts) -> Result<(), exitfailure::ExitFailure> {
    let Intercepted { loadfile, ioopen } =
        serde_json::from_slice(
            &Command::new(which::which(opts.interpreter).context(
                "Could not find lua interpreter. Please provide the --interpreter option",
            )?)
            .arg("-e")
            .arg(format!(
                "arg={{[0]={},{}}}",
                to_string(&opts.target)?,
                opts.arg
                    .iter()
                    .map(to_string)
                    .collect::<Result<Vec<_>, _>>()?
                    .join(",")
            ))
            .arg("-e")
            .arg(format!("return(function(){} end)()", INTERCEPT_SCRIPT))
            .stderr(Stdio::inherit())
            .output()?
            .stdout,
        )
        .context("interception failed")?;

    let files = [&loadfile[..], &ioopen[..]].concat();

    let bundle = format!(
        include_str!("lua/scoped_template.lua"),
        scripts = if opts.preload {
            format!(
                "{{{}}}",
                loadfile
                    .iter()
                    .map(|file| -> Result<_, exitfailure::ExitFailure> {
                        Ok(format!(
                            "[{}]=function(_ENV,loadfile,io)return function(...){} end end",
                            to_string(&path_for_vfs(file).unwrap())?,
                            std::fs::read_to_string(file)?
                        ))
                    })
                    .collect::<Result<Vec<_>, _>>()?
                    .join(",")
            )
        } else {
            String::from("false")
        },
        files = format!(
            "{{{}}}",
            files
                .iter()
                .map(|file| -> Result<_, exitfailure::ExitFailure> {
                    Ok(format!(
                        "[{}]={{{}}}",
                        to_string(&path_for_vfs(file).unwrap())?,
                        to_string(&std::fs::read_to_string(file)?.replace("\r\n", "\n"))?
                    ))
                })
                .collect::<Result<Vec<_>, _>>()?
                .join(",")
        ),
        cwd = to_string(&path_for_vfs(&std::env::current_dir()?).unwrap())?,
        entrypoint = to_string(&opts.target)?,
        normalizeplatform = ""
    );

    if let Some(outpath) = opts.output {
        println!("Creating bundle of {:?} at {:?}", files, outpath);
        if opts.preload {
            println!("Also preloading {:?}", loadfile);
        }
        std::fs::write(outpath, bundle)?;
    } else {
        println!("{}", bundle)
    }

    Ok(())
}
