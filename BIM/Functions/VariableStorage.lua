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

return {
    chests = chests, -- key of an itemname, value example {['side']=peripheral.getName(chest),['slot']=j,['count']=item.count,['name']=name}
    list = itemlist, -- list of items in system { {count:int, name:string} }
    name = projectName,
    setEnv = setEnv,
    getEnv = getEnv,
    setKeyEnv = setKeyEnv
}
