use std::path::PathBuf;
use structopt::StructOpt;
use std::process::{Command, Stdio};
use failure::ResultExt;
use serde::Deserialize;
use serde_json::to_string;

#[derive(Deserialize, Debug)]
struct Intercepted {
    loadfile: Vec<PathBuf>,
    ioopen: Vec<PathBuf>
}
static INTERCEPT_SCRIPT: &'static str = include_str!("lua/intercept.lua");

#[derive(StructOpt)]
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
    /// The main file of your lua project.
    target: PathBuf,
    /// The arguments to pass to the lua script.
    arg: Vec<String>
}
#[paw::main]
fn main(opts: Opts) -> Result<(), exitfailure::ExitFailure> {
  let Intercepted { loadfile, ioopen } =
    serde_json::from_slice(&Command::new(which::which(opts.interpreter).context("Could not find lua interpreter. Please provide the --interpreter option")?)
      .arg("-e").arg(format!("arg={{[0]={},{}}}",
        to_string(&opts.target)?,
        opts.arg.iter().map(to_string).collect::<Result<Vec<_>, _>>()?.join(",")))
      .arg("-e").arg(format!("(function(...) {} end)(...)", INTERCEPT_SCRIPT))
      .stderr(Stdio::inherit())
      .output()?.stdout
    ).context("interception failed")?;

  let outpath = opts.output.unwrap_or(opts.target.with_extension("bundle.lua"));
  let files = [&loadfile[..], &ioopen[..]].concat();

  println!("Creating bundle of {:?} at {:?}", files, outpath);
  if opts.preload {
    println!("Also preloading {:?}", loadfile);
  }
  
  Ok(())
}
