# Lua VFS

This branch is a POC of the bundler - `cargo run -- --preload` (equivalent of `lua-vfs --preload`) in the `tests/tts_toy` directory will bundle the example project (stolen from <https://github.com/TwilightImperiumContentCreators/TTS-TwilightImperium>) into an `init.bundle.lua` which will function within TTS.


### Atom TTS Package replacment

This program can be used with https://github.com/Ayplow/ttscli to replicate the workflow in atom.

```sh
find -name "*.lua" | entr -s "lua-vfs --preload | ttscli set-script"
```
