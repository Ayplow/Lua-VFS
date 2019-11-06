--[[
    A lua implementation of the `require` method.
    Depends:
        loadfile
        OR
        io.open
        io:read
        load
    Will change as little of the enviroment as possible.
]]
if not io.open then
    error "Require cannot be implemented without `io.open`"
end
if not loadfile then
    if not load then
        error "Require cannot be implemented without `load` or `loadfile`"
    end
end

package = package or {}
package.path = package.path or (os and os.getenv and (os.getenv("LUA_PATH_" .. _VERSION:sub(5):gsub("%.", "_")) or os.getenv "LUA_PATH")) or "./?.lua;./?/init.lua"
package.config = package.config or "/\n;\n?\n!\n-"
package.preload = package.preload or {}
package.loaded = package.loaded or {}

local DIR_SEP = package.config:sub(1, 1)
local TEMPLATE_SEP = package.config:sub(3, 3)
local PATH_SUB = package.config:sub(5, 5)
local package = package
local preload = package.preload
local loaded = package.loaded

local function pattern_escape(str)
    return (str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"))
end

local function consume_loader(modname, loader, val)
    local content = loader(modname, val)
    if loaded[modname] == nil then
        if content == nil then
            loaded[modname] = true
        else
            loaded[modname] = content
        end
    end
    return loaded[modname]
end

require = require or function(modname)
    if loaded[modname] ~= nil then
        return loaded[modname]
    end
    if not package.searchers then
        error("'package.searchers' must be a table", 2)
    end
    local err = ""
    for _, searcher in ipairs(package.searchers) do
        local func, val = searcher(modname)
        if type(func) == "function" then
            return consume_loader(modname, func, val)
        elseif type(func) == "string" then
            err = err .. func
        end
    end
    error("module '" .. modname .. "' not found:" .. err, 2)
end

local function LF(modname, path)
    return loadfile(path)(modname, path)
end
package.searchers = package.searchers or {
    function(modname)
        return preload[modname] ~= nil and preload[modname] or "\n        no field package.preload['" .. modname .. "']"
    end
}
package.searchers[2] = function(modname)
    local path, err = package.searchpath(modname, package.path)
    if path then
        return LF, path
    end
    return err
end


package.searchpath = package.searchpath or function(name, path, sep, rep)
    name = name:gsub(sep and pattern_escape(sep) or "%.", rep or DIR_SEP)
    local err = ""
    for template in (path .. TEMPLATE_SEP):gmatch("(.-)" .. TEMPLATE_SEP) do
        local match = template:gsub(pattern_escape(PATH_SUB), name)
        local file = io.open(match)
        if file then
            file:close()
            return match
        end
        err = err .. "\n        no file '" .. match .. "'"
    end
    return nil, err
end

loadfile = loadfile or function(filename, mode, env)
    local file, err
    if filename then
        file, err = io.open(filename)
    else
        filename = "stdin"
        file = io.stdin
    end
    if file then
        return load(file:read("a"), "=" .. filename, mode, env or _ENV)
    else
        return nil, "cannot open " .. err
    end
end