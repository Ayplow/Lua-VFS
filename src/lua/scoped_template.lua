local __LUA_VFS = {
    -- TODO: If there is a way to get the runtime CWD, that would be ideal.
    CWD = {{{cwd}}}, -- type: string - Absolute CWD
    ENTRYPOINT = {{{entrypoint}}}, -- type: string - Entry lua file path
    IS_WINDOWS = {{{is_windows}}}, -- type: boolean - Whether the compilation platform was windows
    DEFAULT = {loadfile = loadfile, io = io, require = require}
}
local loadfile, io, require
__LUA_VFS.FILES = {{{files}}} -- type: Table[string, {string, function}] - Collection of file references keyed by absolute path
local FILES, CWD = __LUA_VFS.FILES, __LUA_VFS.CWD
local stdin = __LUA_VFS.DEFAULT.io.stdin
local _loadfile = __LUA_VFS.DEFAULT.loadfile or function(filename, mode, env)
    if filename then
        return nil, "cannot open " .. filename .. ": No such file or directory"
    end
    -- If load/stdin are missing from the environment, this
    -- throws attempt to index/call errors, which seem
    -- descriptive enough
    return load(stdin:read("a"), "=stdin", ...)
end

local function normalize(P)
    {{{normalizeplatform}}}
    if P:sub(1, 1) ~= "/" then
        P = cwd .. "/" .. P
    end
    local k
    repeat -- /./ -> /
        P, k = P:gsub("/+%.?/", "/")
    until k == 0
    repeat -- /A/../ -> /
        P, k = P:gsub("[^/]+/%.%./?", "")
    until k == 0
    if P == "" then P = "." end
    return P
end
local function resolve_file(path) return FILES[normalize(path)] end
-- TODO: Remove this function
local function TODO() error "not implemented" end
local filemeta = {
    read = function(handle, format)
        local contents = handle[2][1]
        if format == "a" then
            local current = handle[1]
            handle[1] = #contents
            return contents:sub(current, handle[1])
        elseif format == "l" then
            local current = handle[1]
            local to = contents:find("\n", current)
            handle[1] = to + 1
            return contents:sub(current, to - 1)
        end
        return TODO()
    end,
    write = TODO,
    seek = TODO,
    setvbuf = TODO,
    lines = TODO,
    flush = TODO,
    close = function(handle)
        -- TODO: Fully implement
    end,
    __tostring = TODO,
    __gc = TODO,
    __name = "FILE*"
}
filemeta.__index = filemeta
local function file(ref, mode) return setmetatable({0, ref}, filemeta) end
local function open(filename, mode)
    local ref = resolve_file(filename)
    if ref then return file(ref, mode) end
    -- TODO: Implement proper error handling
    return nil, filename .. ": No such file or directory", 2
end
io = {}
for key, value in pairs(__LUA_VFS.DEFAULT.io) do
    io[key] = value
end
io.open = open
local bound_tmpl = "loadfile,io=... return function(...)\n%s\nend"
local format = string.format
loadfile = load and function(...)
    local filename, mode, env = ...
    local file = open(filename)
    if file then
        -- TODO: Check if this binding template is really doing anything useful.
        return load(format(bound_tmpl, file:read("a")), "=" .. filename, mode,
                    env or _ENV)(loadfile, io)
    else
        return _loadfile()
    end
end or function(...)
    local filename, mode, env = ...
    -- If we don't have load, fall back to using preloaded functions
    local file = resolve_file(filename)
    if file then
        return file[2](env or _ENV)
    else
        return _loadfile(...)
    end
end

return loadfile(__LUA_VFS.ENTRYPOINT)(...)
