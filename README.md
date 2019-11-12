# Lua VFS

This branch is a POC of the bundler - example usage at https://github.com/Ayplow/tts-boilerplate


### Atom TTS Package replacment

This program can be used with https://github.com/Ayplow/ttscli to replicate the workflow in atom.

```sh
find -name "*.lua" | entr -s "lua-vfs --preload | ttscli set-script"
```
