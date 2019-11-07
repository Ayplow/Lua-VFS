# Lua VFS

Single file emulation of the lua filesystem.

A compiler for emulating the lua filesystem methods, allowing projects to be packaged into a single lua file to be used in an interpreter. This can be used for packaging configuration information, and emulating the require method where need be.

## Features

- TODO: No non-essential data about host computer - shouldnt include usernames/drive names
- TODO: Can be decompiled with full accuracy
  - For simplicity's sake, it would be *nice* to leave source intact
- Different operation modes depending on the existence of `load`
- Able to nest efficiently

### Automatic resolution methods
  
Options:

- TODO: Static analysis of lua files
  - Find calls to `require` and load the string literals to attempt to locate relevant files
  - Allow optional regex to find extra calls
- Active analysis of runtime
  - TODO: Proxy filesystem methods, recording all calls to the methods
  - Analysis patching to compile for custom enviroments
  - Output patching to patch individual methods like `require`

The latter one is clearly ideal, but it needs an emulator to be built for any enviroment it is to be used in, needing more work on a per-project basis. Both discovery methods will be fully supported.

## Modified methods

- `io`
  - `open`
  - `read`
  - `write`
- `os`
  - `getenv` (Not implemented)

Optional:

Because many enviroments do not support `load` due to security reasons, the compiler is also able to load lua source code as individual chunks. When acting in this mode, `loadfile` is changed to be able to load these Virtual Files.

- `loadfile`

However, these changes bring the calls down from C into lua, meaning the other filesystem methods need to be patched to make use of them...

### Patched methods

TODO:

- `io`
  - `close`
  - `flush`
  - `input`
  - `lines`
  - `output`
  - `type`
  - `seek`
  - `setvbuf`
- `require`

## Problems

- How to handle the conflicting paths between the VFS and an interpreter used later
  - Concatenate them
    - Probably works for most code without an issues
    - Would be painfully unpredicatable to handle in edge cases where require is rewritten
  - New variable for original path
    - Makes interaction with the new filesystem more involved
    - Probably ideal - normal lua code wouldnt be aware of a second filesystem anyway

arg, io.open, loadfile, os.getenv all need to be replaced in the context of the files.

### Options

- Just replace the methods in _ENV.
  - Perfect local compatibiltiy - its literally the exect same place they would be accessed from in real execution
  - External scripts would start reading from the VFS
- Implemented: Use `local` declarations at the top of the bundle
  - Would be scoped to all VFS files
  - Would be invisible to external scripts
  - requires files to be loaded with `loadfile`
  - Fails at key reads like for key in env do _ENV[key]() end (returning the global version)

- Clone _ENV and edit that
  - `load` has to be patched too
  - Would be scoped to VFS files
  - External scripts would use 'real' methods
  - Attempts to place variables in _ENV for other scripts would fail
- Make a proxy to _ENV with a metatable
  - `load` has to be patched too
  - Can probably be the most accurate
    - Writes to _ENV will write to the global _ENV
    - Reads from _ENV will read from global _ENV
    - UNLESS key is specifically one we edit
  - Will be unpredictable
    - Trying to get setmetatable(_ENV...) to work properly will be patchwork

Unfortunately, none of these really work perfectly, so our best option is going to be to implement them all, and let users choose which of the 4 different modes work best for them. Local vars would be default.

Option #2 would have to be chosen during compilation, but the others should be able to be changed at runtime, to allow configuration in the source.

### Atom TTS Package replacment

This program can be used with https://github.com/Ayplow/ttscli to replicate the workflow in atom.

```sh
find -name "*.lua" | entr -s "lua-vfs --preload | ttscli set-script"
```