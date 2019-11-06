loadfile "default_require.lua" ()
local TI = require "twilight"

local jordTile = TI.MapTile:new(1, {'Jord', "Jard"}, {"ɑ", "ᵝ"})

--[[ The onLoad event is called after the game save finishes loading. --]]
function onLoad()
    print(jordTile)
end

--[[ The onUpdate event is called once per frame. --]]
function onUpdate()
--noop
end