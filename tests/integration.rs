use assert_cmd::prelude::*;
use failure::ResultExt;
use std::io::Write;
use std::path::Path;
use std::process::Command;
use tempfile::NamedTempFile;

fn test_bundle(path: &Path) -> Result<(), exitfailure::ExitFailure> {
    let mut bundle = NamedTempFile::new()?;
    bundle.write_all(
        &Command::cargo_bin(env!("CARGO_PKG_NAME"))?
            .current_dir(path)
            .arg("--preload")
            .output()?
            .stdout,
    )?;
    // TODO: Improve usability for alternative locations
    let interpreter = std::env::var("LUA").unwrap_or("lua".into());
    which::which(&interpreter).context("lua interpreter not present in PATH")?;
    println!("{:?}", Command::new(&interpreter)
            .arg("-e")
            .arg("loadfile = nil load = nil io = nil")
            .arg(bundle.path())
            .output()?
            .stdout);
    Ok(assert_eq!(
        Command::new(&interpreter)
            .arg("-e")
            .arg("loadfile = nil load = nil io = nil")
            .arg(bundle.path())
            .output()?
            .stdout,
        Command::new(&interpreter)
            .current_dir(path)
            .arg("init.lua")
            .output()?
            .stdout
    ))
}
#[test]
fn external_txt() -> Result<(), exitfailure::ExitFailure> {
    // TODO: Can we improve the way this folder is located?
    test_bundle(Path::new("tests/external_txt"))
}
