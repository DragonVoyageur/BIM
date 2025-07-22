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

--- Call when adding a new item or on first construction
local function saveTable(table, where)
    local file = fs.open(where, "w")
    assert(file, "Unable to open " .. where .. " for writing.")

    file.write("return " .. textutils.serialise(table))
    file:close()
end

local detailsLocation = "/" .. projectName .. "/" .. projectName .. "_itemDetailsMap.lua"
local reqLocation = "/" .. projectName .. "." .. projectName .. "_itemDetailsMap"
local itemDetailsMap = {}
if fs.exists(detailsLocation) then -- Protection against malformed map file
    local ok, result = pcall(require, reqLocation)
    if ok and type(result) == "table" then
        itemDetailsMap = result
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

local function saveItemDetails()
    saveTable(itemDetailsMap, detailsLocation)
end

local function setItemDetail(name, chest, slot, suppressSave)
    if not itemDetailsMap[name] then
        local detail = chest.getItemDetail(slot)
        if detail and detail.displayName then
            -- details.itemGroups is apparently deprecated and the wiki says it's no longer available. but I see it in mc 1.21.7
            itemDetailsMap[name] = {
                tags = detail.tags,
                maxCount = detail.maxCount,
                displayName = detail.displayName
            }
            if not suppressSave then
                saveItemDetails()
            end
            return true
        end
    end
    return false
end

local Vs = {
    chests = chests, -- key of an itemname, value example {['side']=peripheral.getName(chest),['slot']=j,['count']=item.count,['name']=name}
    list = itemlist, -- list of items in system { {count:int, displayName:string, id:string} }
    name = projectName,
    setItemDetail = setItemDetail,
    itemDetailsMap = itemDetailsMap,
    saveItemDetails = saveItemDetails,
    getEnv = getEnv,
    setKeyEnv = setKeyEnv
}

return Vs
