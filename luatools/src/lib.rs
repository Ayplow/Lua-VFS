#![crate_type="dylib"]
#![feature(plugin_registrar, rustc_private)]

extern crate syntax;
extern crate syntax_pos;
extern crate rustc;
extern crate rustc_plugin;

use syntax::ext::base::{self, *};
use syntax::ext::build::AstBuilder;
use syntax::symbol::Symbol;
use std::path::PathBuf;
use syntax_pos::{Span, FileName};
use rustc_plugin::Registry;
use syntax::tokenstream;

pub fn expand_include_lua(cx: &mut ExtCtxt<'_>, sp: Span, tts: &[tokenstream::TokenTree])
                          -> Box<dyn base::MacResult+'static> {
    let file = match get_single_str_from_tts(cx, sp, tts, "include_lua!") {
        Some(f) => f,
        None => return DummyResult::expr(sp)
    };
    let file = res_rel_file(cx, sp, file);
    // return DummyResult::expr(sp);
    match std::process::Command::new("lua")
            .arg("CommandLineMinify.lua")
            .arg(std::env::current_dir().unwrap().join(&file))
            .arg("stdout")
            .current_dir(std::path::Path::new(file!()).parent().unwrap().join("LuaMinify"))
            .output() {
        Ok(output) => {
            if output.status.success() {
                match String::from_utf8(output.stdout) {
                    Ok(src) => {
                        // let interned_src = Symbol::intern(&src);
                        let interned_src = Symbol::intern(&src);

                        // Add this input file to the code map to make it available as
                        // dependency information
                        cx.source_map().new_source_file(file.into(), String::new());

                        base::MacEager::expr(cx.expr_str(sp, interned_src))
                    },
                    Err(e) => {
                        cx.span_err(sp, &format!("couldn't read {}: {}", file.display(), e));
                        DummyResult::expr(sp)
                    }
                }
            } else {
                cx.span_err(sp, &format!("couldn't minify {}: {}", file.display(), String::from_utf8(output.stderr).unwrap()));
                DummyResult::expr(sp)

            }
        },
        // Err(ref e) if e.kind() == ErrorKind::InvalidData => {
        //     cx.span_err(sp, &format!("{} wasn't a utf-8 file", file.display()));
        //     DummyResult::expr(sp)
        // }
        Err(e) => {
            cx.span_err(sp, &format!("couldn't read {}: {}", file.display(), e));
            DummyResult::expr(sp)
        }
    }
}
#[plugin_registrar]
pub fn plugin_registrar(reg: &mut Registry) {
    reg.register_macro("include_lua", expand_include_lua);
}

// resolve a file-system path to an absolute file-system path (if it
// isn't already)
fn res_rel_file(cx: &mut ExtCtxt<'_>, sp: syntax_pos::Span, arg: String) -> PathBuf {
    let arg = PathBuf::from(arg);
    // Relative paths are resolved relative to the file in which they are found
    // after macro expansion (that is, they are unhygienic).
    if !arg.is_absolute() {
        let callsite = sp.source_callsite();
        let mut path = match cx.source_map().span_to_unmapped_path(callsite) {
            FileName::Real(path) => path,
            FileName::DocTest(path, _) => path,
            other => panic!("cannot resolve relative path in non-file source `{}`", other),
        };
        path.pop();
        path.push(arg);
        path
    } else { arg }
}