local projectName = 'BIM'
local chests = {}
local env = {}
local itemlist = {}

local function setKeyEnv(value, key)
    if key ~= nil then
        env[key] = value
    end
end

local function setEnv(value)
    env = value
end

local function getEnv(key)
    if key == nil then
        return env
    else
        return env[key]
    end
end

local detailsLocation = "/" .. projectName .. "/" .. projectName .. "_itemDetailsMap.lua"
local reqLocation = "/" .. projectName .. "." .. projectName .. "_itemDetailsMap"
local dMap = {}
if fs.exists(detailsLocation) then -- Protection against malformed map file
    local ok, result = pcall(require, reqLocation)
    if ok and type(result) == "table" then
        dMap = result
    end
end

return {
    chests = chests, -- key of an itemname, value example {['side']=peripheral.getName(chest),['slot']=j,['count']=item.count,['name']=name}
    list = itemlist, -- list of items in system { {count:int, displayName:string, id:string} }
    name = projectName,
    itemDetailsMapLocation = detailsLocation,
    itemDetailsMap = dMap,
    setEnv = setEnv,
    getEnv = getEnv,
    setKeyEnv = setKeyEnv
}
