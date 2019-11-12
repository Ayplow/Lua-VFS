use assert_cmd::prelude::*;
use std::io::Write;
use std::path::Path;
use std::process::Command;
use tempfile::NamedTempFile;
use failure::ResultExt;

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
    which::which("lua").context("lua interpreter not present in PATH")?;
    Ok(assert_eq!(
        Command::new("lua")
            .arg("-e")
            .arg("loadfile = nil load = nil io = nil")
            .arg(bundle.path())
            .output()?
            .stdout,
        Command::new("lua")
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
