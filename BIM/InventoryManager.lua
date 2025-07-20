--todo figure out why this sometimes swaps some items with the same count when searching and hitting shift

--#region Locals--
local settingPath = Vs.name .. '/' .. Vs.name .. '.settings'
local sortIndex = 1 -- The index of which sort type is currently being used.
local listSort = {
    function(left, right) return Vs.itemDetailsMap[left.id].displayName < Vs.itemDetailsMap[right.id].displayName end,
    function(left, right) return Vs.itemDetailsMap[left.id].displayName > Vs.itemDetailsMap[right.id].displayName end,
    function(left, right) return left.count < right.count end,
    function(left, right) return left.count > right.count end,
}
local sortDisplay = {
    "Name " .. string.char(0x1E),
    "Name " .. string.char(0x1F),
    "Amount " .. string.char(0x1E),
    "Amount " .. string.char(0x1F)
}

local filtered = {} -- Same structure as Vs.list
local clickList = {}
local sClickList = {}
local scrollIndex = 0
local selected = {}
local buffer
local chests = {} --- A list of all chest peripherals in the system
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

--- Call when adding a new item or on first construction
local function saveTable(table, where)
    local file = fs.open(where, "w")
    assert(file, "Unable to open ".. where .. " for writing.")

    file.write("return " .. textutils.serialise(table))
    file:close()
end

local function trim(s) return s:match("^%s*(.-)%s*$") end

local function setItemDetail(name, chest, slot, suppressSave)
    if not Vs.itemDetailsMap[name] then
        local detail = chest.getItemDetail(slot)
        if detail and detail.displayName then
            -- details.itemGroups is apparently deprecated and the wiki says it's no longer available. but I see it in mc 1.21.7
            Vs.itemDetailsMap[name] = {
                tags = detail.tags,
                maxCount = detail.maxCount,
                displayName = detail.displayName
            }
            if not suppressSave then
                saveTable(Vs.itemDetailsMap, Vs.itemDetailsMapLocation)
            end
            return true
        end
    end
    return false
end

--#region Functions--
local function filter(fList)
    if #searchText < 1 then
        filtered = fList
        return
    end

    --todo work with item tags using "#"
    local trimmedSearch = trim(searchText)
    if trimmedSearch:sub(1, 1) == "@" then -- search by mod
        local lowerSearchText = trimmedSearch:sub(2) -- exclude '@'
        local out = {}

        for _, v in ipairs(fList) do
            if v.id:sub(1, #lowerSearchText) == lowerSearchText then
                table.insert(out, v)
            end
        end
        filtered = out
        return
    end

    local lowerSearchText = searchText:lower()
    local out = {}

    for _, v in ipairs(fList) do
        local name = Vs.itemDetailsMap[v.id].displayName:lower()
        if name:find(lowerSearchText, 1, true) then
            table.insert(out, v)
        end
    end

    filtered = out
end

local function sortList()
    filter(Vs.list)
    table.sort(filtered, listSort[sortIndex])
end

---Maps out where items are
local function scanStorage()
    local chestlist = {}
    local foundNewItemType = false
    local itemList = {}
    for _, chest in ipairs(chests) do
        local items = chest.list()
        for slot, item in pairs(items) do
            local name = item.name -- i.e. minecraft:bone
            chestlist[name] = chestlist[name] or {}

            if setItemDetail(name, chest, slot, true) then
                foundNewItemType = true
            end

            table.insert(chestlist[name],
                {
                    side = peripheral.getName(chest),
                    slot = slot,
                    count = item.count,
                    name = name, -- same as id
                }
            )

            itemList[name] = itemList[name] or 0
            itemList[name] = itemList[name] + item.count
        end
    end

    local newItemList = {}
    for name, count in pairs(itemList) do
        table.insert(newItemList, {id = name, count = count})
    end
    Vs.list = newItemList
    filtered = newItemList
    sortList()

    Vs.chests = chestlist
    if foundNewItemType then
        saveTable(Vs.itemDetailsMap, Vs.itemDetailsMapLocation)
    end

end

-- this is now unused, but I'm keeping it in for the moment
-- todo refactor this to only sort items if it would result in fewer slots used
local function sortItems()
    local itemlist = {}
    for item, data in pairs(Vs.chests) do
        local count = 0
        for i, slot1 in ipairs(data) do
            if slot1.count ~= 0 then
                local chest = peripheral.wrap(slot1.side)
                assert(chest, "No chest found.")
                setItemDetail(item, chest, slot1.slot)
                for j = i + 1, #data, 1 do
                    local transferred = chest.pullItems(data[j].side, data[j].slot, data[j].count, slot1.slot)
                    Vs.chests[item][j].count = data[j].count - transferred
                    Vs.chests[item][i].count = slot1.count + transferred
                end
                count = count + slot1.count
            end
        end
        if count > 0 then
            table.insert(itemlist, {
                count = count,
                id = item
            })
        end
    end
    Vs.list = itemlist
    sortList()
end

local function pushBufferItemToStorage(chestName, fromSlotIndex, toSlotIndex, itemId)
    local pushed = buffer.pushItems(chestName, fromSlotIndex, 64, toSlotIndex)
    if pushed > 0 then
        -- Update Vs.chests
        Vs.chests[itemId] = Vs.chests[itemId] or {}
        table.insert(Vs.chests[itemId], {
            side = chestName,
            slot = toSlotIndex,
            count = pushed,
            name = itemId
        })
    end
    return pushed
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

                -- Drop all items from turtle to buffer
                for i = 1, 16 do
                    if turtle.getItemCount(i) > 0 then
                        turtle.select(i)
                        turtle.dropDown()
                    end
                end

                -- Get buffer inventory
                local bufferItems = buffer.list()
                for slot, item in pairs(bufferItems) do
                    local itemId = item.name
                    local itemCount = item.count

                    local chestSlots = Vs.chests[itemId] or {}
                    local remaining = itemCount
                    -- Fill non-full stacks
                    for _, chestSlot in ipairs(chestSlots) do
                        if remaining <= 0 then break end
                        local pushed = buffer.pushItems(chestSlot.side, slot, 64, chestSlot.slot)
                        chestSlot.count = chestSlot.count + pushed
                        remaining = remaining - pushed
                    end

                    -- Put remaining items in empty slots
                    if remaining > 0 then
                        for _, chest in ipairs(chests) do
                            local chestName = peripheral.getName(chest)
                            local chestInv = chest.list()

                            for chestSlotNum = 1, chest.size() do
                                if not chestInv[chestSlotNum] then
                                    local pushed = pushBufferItemToStorage(chestName, slot, chestSlotNum, itemId)
                                    remaining = remaining - pushed
                                    if remaining <= 0 then break end
                                end
                            end
                            if remaining <= 0 then break end
                        end
                    end

                    -- Update Vs.list
                    local found = false
                    for _, entry in ipairs(Vs.list) do
                        if entry.id == itemId then
                            entry.count = entry.count + itemCount
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(Vs.list, { count = itemCount, id = itemId })
                    end
                end
                filter(Vs.list)
                Um.Print(filtered, selected, scrollIndex, scrollBar, screen, colAmount)
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

--todo consider if this is even needed now; At least if it needs to loop
local function loopSort()
    while true do
        if buffer then
            -- sortItems()

            scrollIndex = math.min(
                math.max(scrollIndex, 0),
                math.max(math.ceil(#filtered / colAmount) - screenSize[2], 0)
            )

            printScreen()
            if monitor then
                sClickList = Um.Print(filtered, selected, 0, nil, secondScreen, colAmount)
            end
            sleep(1000)
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
---@param percentOfStack number 0-1 how much of a stack to pull
local function dropItem(id, percentOfStack)
    if id == nil or filtered[id] == nil then return nil end
    local itemName = filtered[id].id
    local chestData = Vs.chests[itemName]
    if not chestData or #chestData == 0 then return nil end

    -- Cache maxCount
    local maxCount = 64
    local chest = peripheral.wrap(chestData[1].side)
    if chest then
        setItemDetail(itemName, chest, chestData[1].slot)
    end

    local amountToPull = math.ceil(maxCount * percentOfStack)
    local stack = 0
    selected = { filtered[id] }

    for i = #chestData, 1, -1 do
        local data = chestData[i]
        if data.count > 0 and stack < amountToPull then
            local amount = math.min(amountToPull - stack, data.count)
            local transferred = buffer.pullItems(data.side, data.slot, amount)

            -- Remove from Vs.list to prevent items from re-appearing when sorting
            -- todo O(n) check if this can ba faster; may not need to after refactoring to stop need for sorting
            for l = #Vs.list, 1, -1 do
                if Vs.list[l].count == 0 then
                    table.remove(Vs.list, l)
                end
            end

            -- remove from filtered list to instantly disappear from list instead of showing item with 0 count
            filtered[id].count = filtered[id].count - transferred
            if filtered[id].count == 0 then
                table.remove(filtered, id)
            end

            -- update variable storage chests
            data.count = data.count - transferred
            if data.count == 0 then
                table.remove(chestData, i)
            end

            stack = stack + transferred
            if stack >= amountToPull then
                break
            end
        end
    end
    Um.Print(filtered, selected, scrollIndex, scrollBar, screen, colAmount)
    if monitor then Um.Print(filtered, selected, 0, nil, secondScreen, colAmount) end
    turtle.select(16)
    repeat
        os.queueEvent('turtle_inventory_ignore')
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
                    --todo update monitor when storing/retrieving items
                    if monitor then sClickList = Um.Print(filtered, selected, 0, nil, secondScreen, colAmount) end
                end
            elseif event[1] == 'mouse_click' and event[4] >= 2 and event[3] < select(1, term.getSize()) then
                local dropAmount = { 1, 0.5, 0.01 }
                dropItem(Um.Click(clickList, event[3], event[4]), dropAmount[event[2]])
            elseif event[1] == 'monitor_touch' and monitor then
                dropItem(Um.Click(sClickList, event[3], event[4]), 1)
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
    chests = {peripheral.find(Vs.getEnv("Inventories"))}
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
        { description = " The last used sort type.", default = 1, type = "number" },
    }
    for i, name in ipairs(otherSettingNames) do
        settings.define(Vs.name .. '.' .. name, otherOptions[i])
    end
    sortIndex = settings.get(Vs.name .. ".sortIndex") or 1
    settings.set(Vs.name .. ".sortIndex", sortIndex)
    settings.save(settingPath)

    scanStorage()
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
