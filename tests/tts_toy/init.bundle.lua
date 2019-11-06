local  scripts,   files,   cwd 
    = {["/home/marli/Documents/Programming/Lua-VFS/tests/tts_toy/init.lua"]=function(_ENV,loadfile,io)return function(...)loadfile "default_require.lua" ()
local TI = require "twilight"

local jordTile = TI.MapTile:new(1, {'Jord', "Jard"}, {"ɑ", "ᵝ"})

--[[ The onLoad event is called after the game save finishes loading. --]]
function onLoad()
    print(jordTile)
end

--[[ The onUpdate event is called once per frame. --]]
function onUpdate()
--noop
end end end,["/home/marli/Documents/Programming/Lua-VFS/tests/tts_toy/default_require.lua"]=function(_ENV,loadfile,io)return function(...)--[[
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
end end end,["/home/marli/Documents/Programming/Lua-VFS/tests/tts_toy/twilight.lua"]=function(_ENV,loadfile,io)return function(...)--[[ TwilightImperium.lua - Firoso 2019
Written for use by the Twilight Imperium Tabletop Simulator Community
https://github.com/TwilightImperiumContentCreators/TTS-TwilightImperium
This file contains classes, functions, and tables for the domain models
for Twilight Imperium
--]]
local pairs, setmetatable,       concat,        upper,        format
    = pairs, setmetatable, table.concat, string.upper, string.format
local _ENV = {}
Constants = {
  PlanetTypes = {
    None = "None",
    Hazardous = "Hazardous",
    Cultural = "Cultural",
    Industrial = "Industrial",
    MecatolRex = "Mecatol Rex",
    HomeWorlds = {
      Sol = "Sol HomeWorld",
      -- etc
    },
    TechnologySpeciality = {
      None = "",
      Red = "Red - Warfare",
      Blue = "Blue - Propulsion",
      Yellow = "Yellow - Cybernetic",
      Green = "Green - Biotic"
    }
  },
  Anomolies = {
    AlphaWormhole = "ɑ Wormhole",
    BetaWormhole = "ᵝ Wormhole",
    DeltaWormhole = "δ Wormhole",
    AsteroidField = "Asteroid Field",
    Supernova = "Supernova",
    Nebula = "Nebula",
    GravityRift = "GravityRift"
  }
}

-- ABSTRACTIONS --
-- Represents assets that can be exhausted to gain some benefit.
local Exhaustable = {}
Exhaustable.__index = Exhaustable
function Exhaustable:exhaust()
  if self.exhausted then
    return false, "Already exhausted"
  end

  self.exhausted = true
  return true
end
function Exhaustable:ready()
  self.exhausted = true
end
function Exhaustable:new()
  return setmetatable({ exhausted = false }, Exhaustable)
end

-- An individual Planet
Planet = {}
-- Subclass Exhaustable
for k, v in pairs(Exhaustable) do
  Planet[k] = v
end
function Planet:__tostring()
  return format("%s%s - %dR %dI%s%s |%s|",
            self.tileId ~= -1 and "("..self.tileId..")" or "",
            self.name,
            self.resources,
            self.influence,
            self.planetType ~= Constants.PlanetTypes.None and (" - " .. self.planetType) or "",
            self.technologySpeciality  ~= Constants.PlanetTypes.TechnologySpeciality.None and (" - " .. self.technologySpeciality)  or "",
            self.exhausted and "Exhausted"  or "Ready")
end
function Planet:new(
  name, -- the name of the planet
  tileId, -- the id of the tile associated with this planet or -1 for 'none'
  resources, -- the resources provided by this planet
  influence, -- the influence provided by this planet
  planetType, -- the type of this planet
  technologySpeciality -- the technologySpeciality provided by the planet
)
  return setmetatable({
    name = name or 'unknown',
    tileId = tileId or -1,
    resources = resources or 0,
    influence = influence or 0,
    planetType = planetType or Constants.PlanetTypes.None,
    technologySpeciality = technologySpeciality
      or Constants.PlanetTypes.TechnologySpeciality.None
  }, Planet)
end

--[[ A single tile of the board
Provides a view into planets and anomalies local to the tile
--]]
MapTile = {}
MapTile.__index = MapTile
function MapTile:__tostring()
  return self.description
end
function MapTile:containsPlanet(name)
  return self.planets[upper(name)] or false
end
function MapTile:new(
  id, -- the numeric Id of the tile as shown center-left of the tile art.
  planets, -- a table containing a list of plants on this tile.
  anomolies -- a table containing the anomolies on this tile.
)
  local planetSet = {}
  for _, name in pairs(planets) do
    planetSet[upper(name)] = true
  end
  return setmetatable({
    id = id or -1,
    planets = planetSet,
    anomolies = anomolies or {},
    description = format("%d%s%s",
                    id,
                    #planets > 0 and " - " .. concat(planets, ", ") or "",
                    #anomolies > 0 and " - " .. concat(anomolies, ", ") or "")
  }, MapTile)
end
return _ENV end end}, {["/home/marli/Documents/Programming/Lua-VFS/tests/tts_toy/init.lua"]={"loadfile \"default_require.lua\" ()\nlocal TI = require \"twilight\"\n\nlocal jordTile = TI.MapTile:new(1, {'Jord', \"Jard\"}, {\"ɑ\", \"ᵝ\"})\n\n--[[ The onLoad event is called after the game save finishes loading. --]]\nfunction onLoad()\n    print(jordTile)\nend\n\n--[[ The onUpdate event is called once per frame. --]]\nfunction onUpdate()\n--noop\nend"},["/home/marli/Documents/Programming/Lua-VFS/tests/tts_toy/default_require.lua"]={"--[[\n    A lua implementation of the `require` method.\n    Depends:\n        loadfile\n        OR\n        io.open\n        io:read\n        load\n    Will change as little of the enviroment as possible.\n]]\nif not io.open then\n    error \"Require cannot be implemented without `io.open`\"\nend\nif not loadfile then\n    if not load then\n        error \"Require cannot be implemented without `load` or `loadfile`\"\n    end\nend\n\npackage = package or {}\npackage.path = package.path or (os and os.getenv and (os.getenv(\"LUA_PATH_\" .. _VERSION:sub(5):gsub(\"%.\", \"_\")) or os.getenv \"LUA_PATH\")) or \"./?.lua;./?/init.lua\"\npackage.config = package.config or \"/\\n;\\n?\\n!\\n-\"\npackage.preload = package.preload or {}\npackage.loaded = package.loaded or {}\n\nlocal DIR_SEP = package.config:sub(1, 1)\nlocal TEMPLATE_SEP = package.config:sub(3, 3)\nlocal PATH_SUB = package.config:sub(5, 5)\nlocal package = package\nlocal preload = package.preload\nlocal loaded = package.loaded\n\nlocal function pattern_escape(str)\n    return (str:gsub(\"[%(%)%.%%%+%-%*%?%[%]%^%$]\", \"%%%0\"))\nend\n\nlocal function consume_loader(modname, loader, val)\n    local content = loader(modname, val)\n    if loaded[modname] == nil then\n        if content == nil then\n            loaded[modname] = true\n        else\n            loaded[modname] = content\n        end\n    end\n    return loaded[modname]\nend\n\nrequire = require or function(modname)\n    if loaded[modname] ~= nil then\n        return loaded[modname]\n    end\n    if not package.searchers then\n        error(\"'package.searchers' must be a table\", 2)\n    end\n    local err = \"\"\n    for _, searcher in ipairs(package.searchers) do\n        local func, val = searcher(modname)\n        if type(func) == \"function\" then\n            return consume_loader(modname, func, val)\n        elseif type(func) == \"string\" then\n            err = err .. func\n        end\n    end\n    error(\"module '\" .. modname .. \"' not found:\" .. err, 2)\nend\n\nlocal function LF(modname, path)\n    return loadfile(path)(modname, path)\nend\npackage.searchers = package.searchers or {\n    function(modname)\n        return preload[modname] ~= nil and preload[modname] or \"\\n        no field package.preload['\" .. modname .. \"']\"\n    end\n}\npackage.searchers[2] = function(modname)\n    local path, err = package.searchpath(modname, package.path)\n    if path then\n        return LF, path\n    end\n    return err\nend\n\n\npackage.searchpath = package.searchpath or function(name, path, sep, rep)\n    name = name:gsub(sep and pattern_escape(sep) or \"%.\", rep or DIR_SEP)\n    local err = \"\"\n    for template in (path .. TEMPLATE_SEP):gmatch(\"(.-)\" .. TEMPLATE_SEP) do\n        local match = template:gsub(pattern_escape(PATH_SUB), name)\n        local file = io.open(match)\n        if file then\n            file:close()\n            return match\n        end\n        err = err .. \"\\n        no file '\" .. match .. \"'\"\n    end\n    return nil, err\nend\n\nloadfile = loadfile or function(filename, mode, env)\n    local file, err\n    if filename then\n        file, err = io.open(filename)\n    else\n        filename = \"stdin\"\n        file = io.stdin\n    end\n    if file then\n        return load(file:read(\"a\"), \"=\" .. filename, mode, env or _ENV)\n    else\n        return nil, \"cannot open \" .. err\n    end\nend"},["/home/marli/Documents/Programming/Lua-VFS/tests/tts_toy/twilight.lua"]={"--[[ TwilightImperium.lua - Firoso 2019\nWritten for use by the Twilight Imperium Tabletop Simulator Community\nhttps://github.com/TwilightImperiumContentCreators/TTS-TwilightImperium\nThis file contains classes, functions, and tables for the domain models\nfor Twilight Imperium\n--]]\nlocal pairs, setmetatable,       concat,        upper,        format\n    = pairs, setmetatable, table.concat, string.upper, string.format\nlocal _ENV = {}\nConstants = {\n  PlanetTypes = {\n    None = \"None\",\n    Hazardous = \"Hazardous\",\n    Cultural = \"Cultural\",\n    Industrial = \"Industrial\",\n    MecatolRex = \"Mecatol Rex\",\n    HomeWorlds = {\n      Sol = \"Sol HomeWorld\",\n      -- etc\n    },\n    TechnologySpeciality = {\n      None = \"\",\n      Red = \"Red - Warfare\",\n      Blue = \"Blue - Propulsion\",\n      Yellow = \"Yellow - Cybernetic\",\n      Green = \"Green - Biotic\"\n    }\n  },\n  Anomolies = {\n    AlphaWormhole = \"ɑ Wormhole\",\n    BetaWormhole = \"ᵝ Wormhole\",\n    DeltaWormhole = \"δ Wormhole\",\n    AsteroidField = \"Asteroid Field\",\n    Supernova = \"Supernova\",\n    Nebula = \"Nebula\",\n    GravityRift = \"GravityRift\"\n  }\n}\n\n-- ABSTRACTIONS --\n-- Represents assets that can be exhausted to gain some benefit.\nlocal Exhaustable = {}\nExhaustable.__index = Exhaustable\nfunction Exhaustable:exhaust()\n  if self.exhausted then\n    return false, \"Already exhausted\"\n  end\n\n  self.exhausted = true\n  return true\nend\nfunction Exhaustable:ready()\n  self.exhausted = true\nend\nfunction Exhaustable:new()\n  return setmetatable({ exhausted = false }, Exhaustable)\nend\n\n-- An individual Planet\nPlanet = {}\n-- Subclass Exhaustable\nfor k, v in pairs(Exhaustable) do\n  Planet[k] = v\nend\nfunction Planet:__tostring()\n  return format(\"%s%s - %dR %dI%s%s |%s|\",\n            self.tileId ~= -1 and \"(\"..self.tileId..\")\" or \"\",\n            self.name,\n            self.resources,\n            self.influence,\n            self.planetType ~= Constants.PlanetTypes.None and (\" - \" .. self.planetType) or \"\",\n            self.technologySpeciality  ~= Constants.PlanetTypes.TechnologySpeciality.None and (\" - \" .. self.technologySpeciality)  or \"\",\n            self.exhausted and \"Exhausted\"  or \"Ready\")\nend\nfunction Planet:new(\n  name, -- the name of the planet\n  tileId, -- the id of the tile associated with this planet or -1 for 'none'\n  resources, -- the resources provided by this planet\n  influence, -- the influence provided by this planet\n  planetType, -- the type of this planet\n  technologySpeciality -- the technologySpeciality provided by the planet\n)\n  return setmetatable({\n    name = name or 'unknown',\n    tileId = tileId or -1,\n    resources = resources or 0,\n    influence = influence or 0,\n    planetType = planetType or Constants.PlanetTypes.None,\n    technologySpeciality = technologySpeciality\n      or Constants.PlanetTypes.TechnologySpeciality.None\n  }, Planet)\nend\n\n--[[ A single tile of the board\nProvides a view into planets and anomalies local to the tile\n--]]\nMapTile = {}\nMapTile.__index = MapTile\nfunction MapTile:__tostring()\n  return self.description\nend\nfunction MapTile:containsPlanet(name)\n  return self.planets[upper(name)] or false\nend\nfunction MapTile:new(\n  id, -- the numeric Id of the tile as shown center-left of the tile art.\n  planets, -- a table containing a list of plants on this tile.\n  anomolies -- a table containing the anomolies on this tile.\n)\n  local planetSet = {}\n  for _, name in pairs(planets) do\n    planetSet[upper(name)] = true\n  end\n  return setmetatable({\n    id = id or -1,\n    planets = planetSet,\n    anomolies = anomolies or {},\n    description = format(\"%d%s%s\",\n                    id,\n                    #planets > 0 and \" - \" .. concat(planets, \", \") or \"\",\n                    #anomolies > 0 and \" - \" .. concat(anomolies, \", \") or \"\")\n  }, MapTile)\nend\nreturn _ENV"}}, "/home/marli/Documents/Programming/Lua-VFS/tests/tts_toy"

local io, load, ENV,               _
    = io, load, _ENV or getfenv(), string
local sub,  gsub,  format,  find
   =_.sub,_.gsub,_.format,_.find
local stdin = io and io.stdin
local whole = VERSION == "5.3" and "a" or "*a"
local loadfile = loadfile or function(filename, mode, env)
    if filename then
        return nil, "cannot open " .. filename .. ": No such file or directory"
    end
    -- If load/stdin are missing from the environment, this
    -- throws attempt to index/call errors, which seem
    -- descriptive enough
    return load(stdin:read(whole), "=stdin", mode, env or ENV)
end

local function normalize(P)
    
    if sub(P, 1, 1) ~= "/" then
        P = cwd .. "/" .. P
    end
    local k
    repeat -- /./ -> /
        P, k = gsub(P, "/+%.?/", "/")
    until k == 0
    repeat -- /A/../ -> /
        P, k = gsub(P, "[^/]+/%.%./?", "")
    until k == 0
    if P == "" then P = "." end
    return P
end
-- TODO: Remove this function
local function TODO() error "not implemented" end
local filemeta = {
    read = function(handle, format)
        local contents = handle[2][1]
        if format == "a" or format == "*a" then
            local current = handle[1]
            handle[1] = #contents
            return sub(contents, current, handle[1])
        elseif format == "l" then
            local current = handle[1]
            local to = find(contents, "\n", current)
            handle[1] = to + 1
            return sub(contents, current, to - 1)
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
    __gc = function() end,
    __name = "FILE*"
}
filemeta.__index = filemeta
local function open(filename, mode)
    local ref = files[normalize(filename)]
    if ref then return setmetatable({0, ref}, filemeta) end
    -- TODO: Implement proper error handling
    return nil, filename .. ": No such file or directory", 2
end
local vio = {}
if io then
    for key, value in pairs(io) do
        vio[key] = value
    end
end
vio.open = open
local bound_tmpl = "local loadfile,io=... return function(...)\n%s\nend"
local vloadfile
vloadfile = load and function(...)
    local filename, mode, env = ...
    -- TODO: Handle errors
    local file = open(filename)
    if file then
        -- TODO: Check if this binding template is really doing anything useful.
        return load(format(bound_tmpl, file:read("a")), "=" .. filename, mode,
                    env or ENV)(vloadfile, vio)
    else
        return loadfile(...)
    end
    -- Should we force the compiler to make this decision?
end or scripts and function(...)
    local filename, mode, env = ...
    -- If we don't have load, fall back to using preloaded functions
    local script = scripts[normalize(filename)]
    if script then
        return script(env or ENV, vloadfile, vio)
    else
        return loadfile(...)
    end
end or loadfile

return vloadfile("init.lua")(...)
