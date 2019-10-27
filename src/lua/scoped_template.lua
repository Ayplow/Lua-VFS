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
local _loadfile = __LUA_VFS.DEFAULT.loadfile or function(filename)
    return nil, "cannot open " .. filename .. ": No such file or directory"
end
local function assert_arg(n, val, tp, verify, msg, lev)
    if type(val) ~= tp then
        error(("argument %d expected a '%s', got a '%s'"):format(n, tp,
                                                                 type(val)),
              lev or 2)
    end
    if verify and not verify(val) then
        error(("argument %d: '%s' %s"):format(n, val, msg), lev or 2)
    end
end
local function assert_string(n, val) assert_arg(n, val, 'string', nil, nil, 3) end
local is_windows = __LUA_VFS.IS_WINDOWS
local sep = is_windows and '\\' or '/'
local np_pat1, np_pat2 = ('[^SEP]+SEP%.%.SEP?'):gsub("SEP", sep),
                         ('SEP+%.?SEP'):gsub("SEP", sep)
local function normpath(P)
    assert_string(1, P)
    if is_windows then
        if P:match '^\\\\' then -- UNC
            return '\\\\' .. normpath(P:sub(3))
        end
        P = P:gsub('/', '\\')
    end
    local k
    repeat -- /./ -> /
        P, k = P:gsub(np_pat2, sep)
    until k == 0
    repeat -- /A/../ -> /
        P, k = P:gsub(np_pat1, '')
    until k == 0
    if P == '' then P = '.' end
    return P
end

local function is_relative(path)
    return path:sub(1, 1) == '/' or is_windows and path:sub(2, 2) == ':'
end
local function abspath(path)
    return is_relative(path) and path or CWD .. sep .. path
end
local function resolve_file(path) return FILES[normpath(abspath(path))] end
-- TODO: Remove this function
local function TODO() error "Not Implemented" end
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
io = setmetatable({
    open = function(filename, mode)
        local ref = resolve_file(filename)
        if ref then return file(ref, mode) end
        -- TODO: Implement proper error handling
        return nil, filename .. ": No such file or directory", 2
    end
}, {__index = __LUA_VFS.DEFAULT.io})
local bound_tmpl = "loadfile, io = ... return function(...)\n%s\nend"
local format = string.format
loadfile = load and function(...)
    local filename, mode, env = ...
    local file, err
    if filename then
        file, err = io.open(filename)
    else
        filename = "stdin"
        file = io.stdin
    end
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
