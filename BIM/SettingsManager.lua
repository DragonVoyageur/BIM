
--#region Locals--
local menuClick = {}
local menuSelected = 0
local valueClick = {}
local valueSelected = 0
local valueList = {}
local settingPath = Vs.name .. '/' .. Vs.name .. '.settings'
local envMenu, backMenu, descriptions, menuSize, menuPos, descSize, envValues, backVal, valuesSize, barValues

local env = {}
local scrollIndex = 0
local setNames = { 'Inventories', 'IgnoreInv', 'Buffer', 'Columns', 'Monitor' }
local cardinal = { left = true, right = true, top = true, bottom = true, front = true, back = true }

--#endregion Locals--

--#region Functions--
local function createEnv()
    local setVal = { 'inventory', { 'left', 'right', 'top', 'bottom', 'front', 'back' }, 'none', '2', 'none' }
    for i, name in ipairs(setNames) do
        settings.set(Vs.name .. '.' .. name, setVal[i])
    end
    settings.save(settingPath)
end

local function loadEnv()
    local options = {
        { description = ' Inventory by type to store items', default = 'inventory', type = 'string' },
        { description = ' Inventories by name to ignore, like the buffer', default = { 'left', 'right', 'top', 'bottom', 'front', 'back' }, type = 'table' },
        { description = ' The inventory at the bottom that the turtle uses to manage items', default = 'none', type = 'string' },
        { description = ' Amount of columns to display information', default = '2', type = 'string' },
        { description = ' Monitor to output display information to', default = 'none', type = 'string' }
    }
    local newEnv = {}
    for i, name in ipairs(setNames) do
        newEnv[name] = settings.get(Vs.name .. '.' .. name)
        settings.define(Vs.name .. '.' .. name, options[i])
    end
    newEnv['Name'] = Vs.name
    Vs.setEnv(newEnv)
end

---Gathers all types of inventories attached to the network and returns a list of their names.<br>
---"inventory" means any inventory is acceptable for attached inventory types
---@return table InventoryTypes List of valid Inventory names
local function peripheralTypes()
    local list = {"inventory"}
    local foundSet = {}
    for _, inv in ipairs(peripheral.getNames()) do
        local type = { peripheral.getType(inv) }
        if type[2] == 'inventory' and not cardinal[inv] and not foundSet[type[1]] then
            foundSet[type[1]] = true
            table.insert(list, type[1])
        end
    end
    return list
end

local function findType(tp)
    local per = { peripheral.find(tp) }
    local list = {}
    for _, p in ipairs(per) do
        table.insert(list, peripheral.getName(p))
    end
    return list
end

local function lisVal(id)
    local switch = {
        ['Inventories'] = function()
            valueList = peripheralTypes()
            valueSelected = Vs.getEnv('Inventories')
        end,
        ['IgnoreInv'] = function()
            valueList = findType(Vs.getEnv('Inventories'))
            for i, p in pairs(valueList) do
                if cardinal[p] then
                    table.remove(valueList, i)
                end
            end
            valueSelected = Vs.getEnv('IgnoreInv')
        end,
        ['Buffer'] = function()
            valueList = findType('inventory')
            for i, p in pairs(valueList) do
                if cardinal[p] then
                    table.remove(valueList, i)
                end
            end
            valueSelected = Vs.getEnv('Buffer')
        end,
        ['Columns'] = function()
            valueList = { '1', '2', '3', '4' }
            valueSelected = Vs.getEnv('Columns')
        end,
        ['Monitor'] = function()
            valueList = findType('monitor')
            table.insert(valueList, 1, 'none')
            valueSelected = Vs.getEnv('Monitor')
        end
    }

    descriptions.clear()
    local desc = id and require 'cc.strings'.wrap(settings.getDetails(Vs.name .. '.' .. id).description, descSize[1] - 2) or ""
    for i = 1, #desc do
        descriptions.setCursorPos(1, i)
        descriptions.write(desc[i])
    end

    if type(switch[id]) == 'function' then
        switch[id]()
    else
        valueList = {}
    end
    valueClick = Um.Print(valueList, valueSelected, 0, barValues, envValues, 1)
end

local function valClicked(id)
    if menuSelected == nil then return end
    local selection
    if menuSelected == 'IgnoreInv' then
        local ignore = Vs.getEnv('IgnoreInv')
        local exist = false
        for i, l in pairs(ignore) do
            if l == id then
                table.remove(ignore, i) -------------
                exist = true
                break
            end
        end
        if not exist then table.insert(ignore, id) end
        selection = ignore
    elseif menuSelected == 'Buffer' then
        local oldBuffer = Vs.getEnv('Buffer')
        if oldBuffer ~= id then
            local ignore = Vs.getEnv('IgnoreInv')
            for i, l in ipairs(ignore) do
                if l == oldBuffer and l ~= id then
                    table.remove(ignore, i)
                    break
                end
            end
            table.insert(ignore, id)
            settings.set(Vs.name .. '.IgnoreInv', ignore)
            Vs.setKeyEnv(ignore, 'IgnoreInv')
        end
        selection = id
    else
        selection = id
    end
    if selection then
        settings.set(Vs.name .. '.' .. menuSelected, selection)
        Vs.setKeyEnv(selection, menuSelected)
        Um.Print(valueList, selection, scrollIndex, barValues, envValues, 1)
        settings.save(settingPath)
        os.queueEvent('Update_Env')
    end
end

local function loopPrint()
    while true do
        local event = { os.pullEvent() }
        if event[1] == 'mouse_scroll' and scrollIndex ~= math.min(math.max(scrollIndex + event[2], 0), math.max(#valueList - valuesSize[2], 0)) then
            scrollIndex = scrollIndex + event[2]
            valueClick = Um.Print(valueList, Vs.getEnv(setNames[menuSelected]), scrollIndex, barValues, envValues, 1)
        elseif event[1] == 'mouse_click' then
            if event[3] <= menuPos[1] + menuSize[1] + 2 then
                menuSelected = setNames[Um.Click(menuClick, event[3], event[4])]
                Um.Print(setNames, menuSelected, 0, nil, envMenu, 1)
                valueSelected = -1
                scrollIndex = 0
                lisVal(menuSelected)
            else
                valueSelected = valueList[Um.Click(valueClick, event[3], event[4]) or valueSelected]
                valClicked(valueSelected)
            end
        end
    end
end

--#endregion Functions--

--#region Main--

if not settings.load(settingPath) then
    createEnv()
end
loadEnv()

local mainScreen = (env.Monitor == 'none' or env.Monitor == nil) and term.current() or peripheral.wrap(env.Monitor)
if mainScreen == nil then mainScreen = term.current() end
mainScreen.setBackgroundColor(colors.lightGray)
local ScreenSize = { mainScreen.getSize() }

local width = #setNames[1] + 1
local height = #setNames
local yOffset = math.floor((ScreenSize[2] - height) / 2)
envMenu = window.create(mainScreen, 3, yOffset, width, height)
backMenu = window.create(mainScreen, 2, yOffset - 1, 2 + width, height + 2)
descriptions = window.create(mainScreen, 2, yOffset + height + 2, ScreenSize[1] - 2, 2)
menuSize = { envMenu.getSize() }
menuPos = { envMenu.getPosition() }
descSize = { descriptions.getSize() }

envValues = window.create(mainScreen, menuPos[1] + menuSize[1] + 3, yOffset, ScreenSize[1] - (4 + menuPos[1] + menuSize[1]),
    height)
backVal = window.create(mainScreen, menuPos[1] + menuSize[1] + 2, yOffset - 1, ScreenSize[1] - (2 + menuPos[1] + menuSize[1]),
    height + 2)
valuesSize = { envValues.getSize() }
barValues = window.create(backVal, valuesSize[1] + 2, 1, 1, valuesSize[2] + 2)
barValues.setBackgroundColor(colors.gray)

mainScreen.clear()
backMenu.clear()
backVal.clear()
envMenu.clear()
envValues.clear()
barValues.clear()
descriptions.clear()

menuClick = Um.Print(setNames, 0, 0, nil, envMenu, 1)
parallel.waitForAll(loopPrint)
--#endregion Main--
