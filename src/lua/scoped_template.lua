local  scripts,   files,   cwd 
    = {scripts}, {files}, {cwd}

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
    {normalizeplatform}
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
local filemeta = {{
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
}}
filemeta.__index = filemeta
local function open(filename, mode)
    local ref = files[normalize(filename)]
    if ref then return setmetatable({{0, ref}}, filemeta) end
    -- TODO: Implement proper error handling
    return nil, filename .. ": No such file or directory", 2
end
local vio = {{}}
for key, value in pairs(io) do
    vio[key] = value
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

return vloadfile({entrypoint})(...)
