--[[ TODO
- Gracefully handle os.exit
- Fully intercept the io library. E.g io.lines("file")
]]
-- iter = io.open("test.lua")
-- print(load(iter:lines())())
-- loadfile = nil
-- io.open = nil
-- load= nil
-- os.exit()
-- print(loadfile "notafile.lku")
-- loadfile = nil

--[[ Minimum enironvment required for this file:
_ENV: {
    rawget: function,
    error: function,
    print: function,
    type: function,
    loadfile: function, -- Alternatively, a shim can be created with io: { open, stdin: FILE { close, read } } and load
    _G: <_ENV>
}
- _ENV is getfenv() in Lua5.1
- The functions are all treated as their PUC-Rio counterparts, but no checks are made.
- Finally, to intercept them, the script must be able to replace the `io.open` and `loadfile`
  functions. This will be done with an assignment, meaning use of __newindex is permitted.
]]
-- Function signature of Lua5.2 loadfile. Ignores `mode` argument
local poly_loadfile
local l_loadfile, l_load, l_print, l_error, l_type, l_io
    =   loadfile,   load,   print,   error,   type,   io
local l_open = l_io.open

do
    local _loadfile = l_loadfile
    local format = "*a"
    if not _loadfile then
        local l_stdin = l_io.stdin
        local l_read = l_stdin.read
        local l_close = l_stdin.close
        if not (l_open and l_read and l_close and l_load) then
            l_error("Could not polyfill loadfile.")
        end
        function _loadfile(filename, ...)
            local file, err
            if filename then
                file, err = l_open(filename)
            else
                filename = "stdin"
                file = l_stdin
            end
            if file then
                local contents = l_read(file, format)
                l_close(file)
                return l_load(contents, "=" .. filename, ...)
            else
                return nil, "cannot open " .. err
            end
        end
    end
    if _VERSION == "5.1" then
        local l_setfenv = setfenv
        function poly_loadfile(filename, _, env)
            return l_setfenv(_loadfile(filename), env)
        end
    else
        if _VERSION == "5.3" then
            format = "a"
        end
        poly_loadfile = _loadfile
    end
end

local ioop_log = {}
if l_type(l_open) == "function" then
    ioop_log.n = 0
    function io.open(filename, ...)
        local n     = ioop_log.n + 1
        ioop_log[n] = filename
        ioop_log.n  = n 
        return l_open(filename, ...)
    end
end
local lf_log = {}
if l_type(l_loadfile) == "function" then
    lf_log.n = 0
    function loadfile(filename, ...)
        local n   = lf_log.n + 1
        lf_log[n] = filename
        lf_log.n  = n
        return l_loadfile(filename, ...)
    end
end
local l_arg = arg
local init_path = l_arg[0]
local emuenv_path = ...
local offset = 1
local function doinitfile(...)
    local c_arg = {[-1] = l_arg[-1]}
    local i, v = 0, init_path
    repeat
        c_arg[i] = v
        i = i + 1
        v = l_arg[i + offset]
    until not v
    arg = c_arg
    -- TODO: Gracefully handle invalid entrypoint
    return poly_loadfile(init_path, nil, ...)()
end
local function dofiles()
    if emuenv_path then
        offset = 2
        if emuenv_path ~= "-" then
            arg = {[-1] = l_arg[-1], [0] = emuenv_path}
            -- TODO: Gracefully handle invalid emuenv
            return poly_loadfile(emuenv_path)()(doinitfile)
        end
    end
    return doinitfile()
end
dofiles()

local list_tab
function list_tab(tab)
    if tab.n then
        for n=1, tab.n do
            l_print("/ /?/")
            l_print(tab[n])
        end
    end
end
l_print("[[VFS::INTERCEPTED]]")
l_print(l_type(l_load) == "function")
l_print("/ /:/load log")
list_tab(lf_log)
l_print("/ /:/io log")
list_tab(ioop_log)
l_print("[[VFS::RESULTS_DONE]]")

while true do end