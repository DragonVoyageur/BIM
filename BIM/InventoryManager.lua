--todo remember sorting preferences

--#region Locals--
local settingPath = Vs.name .. '/' .. Vs.name .. '.settings'
local sortIndex = 1 -- The index of which sort type is currently being used.
local listSort = {
    function(left, right) return left[2] < right[2] end,
    function(left, right) return left[2] > right[2] end,
    function(left, right) return left[1] < right[1] end,
    function(left, right) return left[1] > right[1] end,
}
local sortDisplay = {
    "Name ^",
    "Name v",
    "Amount ^",
    "Amount v"
}

local list = {}
local filtered = {} -- {... 4 values}
local clickList = {}
local sClickList = {}
local scrollIndex = 0
local selected = {}
local buffer
local chests = {}
local monitor = nil

local mainScreen = term.current()
local mainSize = { mainScreen.getSize() }
local secondScreen = window.create(mainScreen, 1, 1, 1, 1)
secondScreen.setVisible(false)
local screen, screenSize, scrollBar = Um.Create(mainScreen, 1, 2, mainSize[1], mainSize[2], colors.black, colors.white,
    true,
    colors.gray, colors.white)
local search, searchSize = Um.Create(mainScreen, 1, 1, mainSize[1], 1, colors.lightGray, colors.black)
local searchTitle = 'Search:'
local searching = false
local searchLength = (searchSize[1] / 2) - #searchTitle
local searchBar, sBSize = Um.Create(search, #searchTitle + 1, 1, #searchTitle + 1 + searchLength, 1, colors.lightGray,
    colors.black)
local searchText = ""
local colAmount
--#endregion Locals--

local function metaCall(table)
    local file = fs.open(".test3", 'w')
    if file then
        file.write(textutils.serialize(table))
        file.close()
    else
        error("Failed to open .test3 for writing") -- in case of read only / disk full etc.
    end
    local keylist = {}
    for i, v in ipairs(table) do
        keylist[v[2]:lower():gsub("%s+", "")] = i
    end
    return keylist
end

local function filter(fList)
    if #searchText < 1 then
        filtered = fList
        return
    end -- if no search query

    setmetatable(fList, { __call = metaCall })
    local searchtext = searchText:lower():gsub("%s+", "")
    local inverted = fList()
    local filtering = {}
    local results = textutils.complete(searchtext, inverted)

    for i, v in ipairs(results) do
        local value = inverted[searchtext .. v]
        if value then
            table.insert(filtering, Vs.list[value])
        end
    end

    filtered = filtering
end

local function sortList()
    table.sort(list, listSort[sortIndex])
    -- hacky way to clone Vs.list
    filter(textutils.unserialiseJSON(textutils.serialiseJSON(Vs.list)))
    table.sort(filtered, listSort[sortIndex])
end

--#region Functions--
---Maps out where items are
local function countChests()
    local chestlist = {}
    for i, chest in ipairs(chests) do
        local items = chest.list()
        for j, item in pairs(items) do
            local name = item.name
            if chestlist[name] == nil then chestlist[name] = {} end
            table.insert(
                chestlist[name],
                {
                    side = peripheral.getName(chest),
                    slot = j,
                    count = item.count,
                    name = name
                }
            )
        end
    end
    Vs.chests = chestlist
end

local function sortItems()
    local newList = {}
    local itemlist = {}
    for item, data in pairs(Vs.chests) do
        local count = 0
        local disName = nil
        for i, slot1 in ipairs(data) do
            if slot1.count ~= 0 then
                local chest = peripheral.wrap(slot1.side)
                assert(chest, "No chest found.")
                -- local limit=chest.getItemLimit(slot1.slot)
                -- if not disName then disName=chest.getItemDetail(slot1.slot).displayName end
                if not disName then
                    local detail = chest.getItemDetail(slot1.slot)
                    if detail and detail.displayName then
                        disName = detail.displayName
                    else
                        disName = "Unknown"
                    end
                end
                for j = i + 1, #data, 1 do
                    local transferd = chest.pullItems(data[j].side, data[j].slot, data[j].count, slot1.slot)
                    Vs.chests[item][j].count = data[j].count - transferd
                    Vs.chests[item][i].count = slot1.count + transferd
                end
                count = count + slot1.count
            end
        end
        if count > 0 then
            table.insert(itemlist, { count, disName, item })
            table.insert(newList, { count, disName, item })
        end
    end
    Vs.list = itemlist
    list = newList
    sortList()
end

local function storeItems()
    while true do
        if buffer then
            local event = { os.pullEvent() }
            if event[1] == 'turtle_inventory' and multishell.getCurrent() == multishell.getFocus() then
                os.queueEvent('click_ignore')
                local id = 0
                repeat
                    os.cancelTimer(id)
                    id = os.startTimer(1)
                    local timer = { os.pullEvent() }
                until timer[2] == id
                for i = 1, 16 do
                    if turtle.getItemCount(i) > 0 then
                        turtle.select(i)
                        turtle.dropDown()
                    end
                end
                for i, item in pairs(buffer.list()) do
                    for _, chest in pairs(chests) do
                        if item.count == 0 then break end
                        buffer.pushItems(peripheral.getName(chest), i)
                    end
                end
                os.queueEvent('click_start')
            elseif event[1] == 'turtle_inventory_ignore' then
                os.pullEvent('turtle_inventory_start')
            end
        else
            os.pullEvent('Updated_Env')
        end
    end
end

local function printScreen()
    searchBar.setCursorBlink(false)
    clickList = Um.Print(filtered, selected, scrollIndex, scrollBar, screen, colAmount)
    if searching then
        searchBar.setCursorBlink(true)
        searchBar.setCursorPos(math.min(#searchText, searchLength) + 1, 1)
    end
end

local function loopSort()
    while true do
        if buffer then
            countChests()
            sortItems()

            scrollIndex = math.min(
                math.max(scrollIndex, 0),
                math.max(math.ceil(#filtered / colAmount) - screenSize[2], 0)
            )

            printScreen()
            if monitor then sClickList = Um.Print(filtered, selected, 0, nil, secondScreen, colAmount) end
            sleep(10)
        else
            screen.clear()
            screen.setCursorPos(1, 1)
            screen.write("No Buffer selected")
            os.pullEvent('Updated_Env')
            screen.clear()
            screen.setCursorPos(1, 1)
            screen.write('Sorting...')
        end
    end
end

---Grab an item from storage and drop it to the player
---@param id integer the index that the player clicks
local function dropItem(id)
    -- filtered[id] == {int:count, string:displayName, string:itemID}; int keys

    if id == nil or filtered[id] == nil then return nil end
    local stack = 0
    selected = { filtered[id] }
    local itemName = filtered[id][3]
    for i, data in ipairs(Vs.chests[itemName]) do
        if data.count > 0 then
            local transferd = buffer.pullItems(data.side, data.slot, 64 - stack)
            stack = stack + transferd
            Vs.list[id][1] = Vs.list[id][1] - transferd
            filtered[id][1] = filtered[id][1] - transferd
            Vs.chests[data.name][i].count = Vs.chests[data.name][i].count - transferd
            if stack >= 64 then
                break
            end
        end
    end
    Um.Print(filtered, selected, scrollIndex, scrollBar, screen, colAmount)
    if monitor then Um.Print(filtered, selected, 0, nil, secondScreen, colAmount) end
    turtle.drop()
    repeat
        os.queueEvent('turtle_inventory_ignore')
        turtle.select(16)
        turtle.suckDown()
        turtle.drop()
    until not next(buffer.list())
    os.queueEvent('turtle_inventory_start')
end

local function loopPrint()
    while true do
        if buffer then
            local event = { os.pullEvent() }
            if event[1] == 'mouse_scroll' then
                if scrollIndex ~= math.min(math.max(scrollIndex + event[2], 0), math.max(math.ceil(#filtered / colAmount) - screenSize[2], 0)) then
                    scrollIndex = scrollIndex + event[2]
                    printScreen()
                    if monitor then sClickList = Um.Print(filtered, selected, 0, nil, secondScreen, colAmount) end
                end
            elseif event[1] == 'mouse_click' and event[4] >= 2 and event[3] < select(1, term.getSize()) then
                dropItem(Um.Click(clickList, event[3], event[4]))
            elseif event[1] == 'monitor_touch' and monitor then
                dropItem(Um.Click(sClickList, event[3], event[4]))
            elseif event[1] == 'click_ignore' then
                os.pullEvent('click_start')
            end
        else
            os.pullEvent('Updated_Env')
        end
    end
end

local function loadEnv()
    buffer = peripheral.wrap(Vs.getEnv('Buffer'))

    local ignore = {}
    for _, ig in pairs(Vs.getEnv('IgnoreInv')) do
        ignore[ig] = true
    end
    chests = { peripheral.find(Vs.getEnv('Inventories'), function(name, type)
        return not (ignore[name]) or false
    end) }

    colAmount = tonumber(Vs.getEnv('Columns'))

    monitor = peripheral.wrap(Vs.getEnv('Monitor'))
    if monitor then
        local monitorSize = { monitor.getSize() }
        secondScreen.reposition(1, 1, monitorSize[1], monitorSize[2], monitor)
        secondScreen.setVisible(true)
    else
        secondScreen.setVisible(false)
    end

    settings.load(settingPath)
    local otherSettingNames = { "sortIndex" }
    local otherOptions = {
        { description = ' The last used sort type.', default = 1, type = 'number' }
    }
    for i, name in ipairs(otherSettingNames) do
        settings.define(Vs.name .. '.' .. name, otherOptions[i])
    end
    sortIndex = settings.get(Vs.name .. ".sortIndex") or 1
    settings.set(Vs.name .. ".sortIndex", sortIndex)
    settings.save(settingPath)

end

local function loopEnv()
    while true do
        os.pullEvent('Update_Env')
        loadEnv()
        selected = {}
        scrollIndex = 0
        printScreen()
        if monitor then sClickList = Um.Print(filtered, selected, 0, nil, secondScreen, colAmount) end
        os.queueEvent('Updated_Env')
    end
end

local function beginSearch()
    searchBar.setCursorPos(math.min(#searchText + 1, searchLength - 1), 1)
    searchBar.setCursorBlink(true)
    searching = true
    while true do
        local event = { os.pullEvent() }
        local mouseInSearchBox = (event[4] == 1 and event[3] > (#searchTitle) and event[3] < (sBSize[1] + #searchTitle))
        if event[1] == 'mouse_click' and not mouseInSearchBox then
            break
        elseif event[1] == "mouse_click" and event[2] == 2 and mouseInSearchBox then
            -- if right clicked on search bar to clear
            searchText = ""
            search.setCursorPos(#searchTitle + 1, 1)
            search.write(string.rep(' ', (searchLength) + 1) .. '|')
            search.setCursorPos(#searchTitle + 1, 1)
            sortList()
            printScreen()
        elseif event[1] == 'char' then
            searchText = searchText .. event[2]
            searchBar.setCursorPos(1, 1)
            searchBar.clear()
            local displayText = searchText
            if #searchText > searchLength then
                displayText = searchText:sub(-searchLength)
            end
            searchBar.write(displayText)
        elseif event[1] == 'key' and #searchText > 0 then
            local k = keys.getName(event[2])
            if k == 'backspace' then
                if searchLength <= #searchText then
                    searchBar.setCursorPos(1, 1)
                    searchBar.write(searchText:sub(#searchText + 1 - searchLength, -2))
                    searchBar.write(' ')
                else
                    searchBar.setCursorPos(#searchText, 1)
                    searchBar.write(' ')
                end
                searchText = searchText:sub(1, -2)
            end
        end
        if event[1] == 'char' or event[1] == 'key' then
            sortList()
            printScreen()
        end
    end
    searchBar.setCursorBlink(false)
    searching = false
end

local function loopTopBar()
    while true do
        local event = { os.pullEvent("mouse_click") }

        if event[4] == 1 then -- only when clicked on top bar
            if event[3] > (#searchTitle) and event[3] < (sBSize[1] + #searchTitle) then
                -- Clicked on search bar
                if event[2] == 1 then
                    beginSearch()
                elseif event[2] == 2 then -- if right clicked on search bar to clear
                    searchText = ""
                    search.setCursorPos(#searchTitle + 1, 1)
                    search.write(string.rep(' ', (searchLength) + 1) .. '|')
                    sortList()
                    printScreen()
                    beginSearch()
                end
            elseif event[3] > (searchSize[1] - #sortDisplay[sortIndex]) then
                -- Changing sort type
                sortIndex = (sortIndex % 4) + 1 -- wrap result
                settings.set(Vs.name .. ".sortIndex", sortIndex)
                settings.save(settingPath)

                search.setCursorPos(searchSize[1] - #sortDisplay[sortIndex] - 3, 1)
                search.write("   " .. sortDisplay[sortIndex])
                sortList()
                printScreen()
            end
        end
    end
end

--#endregion Functions--

--#region Main--


repeat
    sleep(0.1)
until Vs.getEnv() ~= nil
loadEnv()


screen.setCursorPos(1, 1)
screen.write('Sorting...')
search.setCursorPos(1, 1)
search.write(searchTitle .. string.rep(' ', (searchLength) + 1) .. '|')
search.setCursorPos(searchSize[1] - #sortDisplay[sortIndex], 1)
search.write(sortDisplay[sortIndex])
searchBar.clear()
local success, result = pcall(function()
    parallel.waitForAll(loopSort, loopPrint, storeItems, loopEnv, loopTopBar)
end)

if not success then
    term.clear()
    term.setCursorPos(1, 1)
    print(success)
    print(result)
    print(debug.traceback())
    os.pullEvent("key")
end
--#endregion
