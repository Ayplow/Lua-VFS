local _ = [[
TODO: Fully intercept the io library. E.g io.lines("file"foo)
TODO: Minify this file before bundling with the binary, so this can be a real comment
Minimum enironvment required for this file:
_ENV: {
    rawget: function,
    error: function,
    print: function,
    type: function,
    -- EITHER
    loadfile: function,
    -- OR
    io: {
      open: function,
      stdin: {
        close: function,
        read: function
      }
    },
    load: function
}
- _ENV is getfenv() in Lua5.1
- The functions are all treated as their PUC-Rio counterparts, but no checks are made.
- Finally, to intercept them, the script must be able to replace the `io.open` and `loadfile`
  functions. This will be done with an assignment, meaning use of __newindex is permitted.
  
Function signature of Lua5.2 loadfile. Ignores `mode` argument
]]
local poly_loadfile
local lloadfile, lio, lload
    =  loadfile,  io,  load
local print, type, os, open
    = print, type, os, lio.open

do
    local _loadfile = lloadfile
    local format = "*a"
    if not _loadfile then
        local stdin = lio.stdin
        local read = stdin.read
        local close = stdin.close
        if not (open and read and close and load) then
            print("Could not polyfill loadfile.")
            return
        end
        function _loadfile(filename, ...)
            local file, err
            if filename then
                file, err = open(filename)
            else
                filename = "stdin"
                file = stdin
            end
            if file then
                local contents = read(file, format)
                close(file)
                return lload(contents, "=" .. filename, ...)
            else
                return nil, "cannot open " .. err
            end
        end
    end
    if _VERSION == "5.1" then
        local setfenv = setfenv
        function poly_loadfile(filename, _, env)
            return setfenv(_loadfile(filename), env)
        end
    else
        if _VERSION == "5.3" then
            format = "a"
        end
        poly_loadfile = _loadfile
    end
end

local ioop_log = {n=0}
if open then
    function io.open(filename, ...)
        local n     = ioop_log.n + 1
        ioop_log[n] = filename
        ioop_log.n  = n 
        return open(filename, ...)
    end
end
local lf_log = {n=0}
if lloadfile then
    function loadfile(filename, ...)
        local n   = lf_log.n + 1
        lf_log[n] = filename
        lf_log.n  = n
        return lloadfile(filename, ...)
    end
end

local function stringtojson(s)
    return "\""
        .. s
          :gsub("\\", "\\\\")
          :gsub("\"", "\\\"")
          :gsub("\n", "\\n")
          :gsub("\r", "\\r")
        .. "\""
end
local function stringlisttojson(list)
    local body = list[1] and stringtojson(list[1]) or ""
    for n=2, list.n do
        body = body .. "," .. stringtojson(list[n])
    end
    return "[" .. body .. "]"
end
local exit = os.exit
function os.exit(...)
    print("{"
        -- .. "\"hasLoad\":"
        -- .. tostring(type(load) == "function")
        -- .. ","
        .. "\"loadfile\":"
        .. stringlisttojson(lf_log)
        .. ",\"ioopen\":"
        .. stringlisttojson(ioop_log)
        .. "}")
    return exit(...)
end
local success, err = pcall(function()
    loadfile(arg[0])()
end)
if not success then
    print("An error occurred during execution: ", err)
end
os.exit()