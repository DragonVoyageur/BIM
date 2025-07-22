local projectName = 'BIM'
local chests = {}
local env = {}
local itemlist = {}

local function setKeyEnv(value, key)
    if key ~= nil then
        env[key] = value
    end
end

local function getEnv(key)
    if key == nil then
        return next(env)
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

do
    local setNames = { 'Inventories', 'IgnoreInv', 'Buffer', 'Columns', 'Monitor' }
    local settingPath = projectName .. '/' .. projectName .. '.settings'
    if not settings.load(settingPath) then
        local setVal = { 'inventory', { 'left', 'right', 'top', 'bottom', 'front', 'back' }, 'none', '2', 'none' }
        for i, name in ipairs(setNames) do
            settings.set(projectName .. '.' .. name, setVal[i])
        end
        settings.save(settingPath)
    end

    local options = {
        { description = ' Inventory by type to store items', default = 'inventory', type = 'string' },
        { description = ' Inventories by name to ignore, like the buffer', default = { 'left', 'right', 'top', 'bottom', 'front', 'back' }, type = 'table' },
        { description = ' The inventory at the bottom that the turtle uses to manage items', default = 'none', type = 'string' },
        { description = ' Amount of columns to display information', default = '2', type = 'string' },
        { description = ' Monitor to output display information to', default = 'none', type = 'string' }
    }
    env = {}
    for i, name in ipairs(setNames) do
        env[name] = settings.get(projectName .. '.' .. name)
        settings.define(projectName .. '.' .. name, options[i])
    end
    env['Name'] = projectName
end

return {
    chests = chests, -- key of an itemname, value example {['side']=peripheral.getName(chest),['slot']=j,['count']=item.count,['name']=name}
    list = itemlist, -- list of items in system { {count:int, displayName:string, id:string} }
    name = projectName,
    itemDetailsMapLocation = detailsLocation,
    itemDetailsMap = dMap,
    getEnv = getEnv,
    setKeyEnv = setKeyEnv
}
