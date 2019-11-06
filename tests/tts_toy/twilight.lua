--[[ TwilightImperium.lua - Firoso 2019
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
return _ENV