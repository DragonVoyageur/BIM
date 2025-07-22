--todo consider making clicked item bg flash instead of stay selected indefinitely
--todo test if thousands of items get rounded to the thousand
--todo consider allow clicking in the middle of sortString to add text in the center.
--todo add scrolling when dragging scroll bar
--todo work with itemGroups
--todo figure out if selected needs to be a table

--#region Locals--
local settingPath = Vs.name .. '/' .. Vs.name .. '.settings'
local sortIndex = 1 -- The index of which sort type is currently being used.
local listSort = {}
listSort[1] = function(left, right) return Vs.itemDetailsMap[left.name].displayName < Vs.itemDetailsMap[right.name].displayName end
listSort[2] = function(left, right) return Vs.itemDetailsMap[left.name].displayName > Vs.itemDetailsMap[right.name].displayName end
listSort[3] = function(left, right) return left.count == right.count and listSort[1](left, right) or left.count < right.count end
listSort[4] = function(left, right) return left.count == right.count and listSort[1](left, right) or left.count > right.count end

local sortDisplay = {
    "Name " .. string.char(0x1E),
    "Name " .. string.char(0x1F),
    "Amount " .. string.char(0x1E),
    "Amount " .. string.char(0x1F)
}

local filtered = {} -- Same structure as Storage.list, except filtered with search bar
local clickList = {}
local sClickList = {}
local scrollIndex = 0
local selected = {}
local buffer
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

local function trim(s) return s:match("^%s*(.-)%s*$") end

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
            if v.name:sub(1, #lowerSearchText) == lowerSearchText then
                table.insert(out, v)
            end
        end
        filtered = out
        return
    end

    local lowerSearchText = searchText:lower()
    local out = {}

    for _, v in ipairs(fList) do
        local name = Vs.itemDetailsMap[v.name].displayName:lower()
        if name:find(lowerSearchText, 1, true) then
            table.insert(out, v)
        end
    end

    filtered = out
end

local function sortList()
    filter(Storage.list)
    table.sort(filtered, listSort[sortIndex])
end

local function printScreen()
    searchBar.setCursorBlink(false)
    clickList = Um.Print(filtered, selected, scrollIndex, scrollBar, screen, colAmount)
    if searching then
        searchBar.setCursorBlink(true)
        searchBar.setCursorPos(math.min(#searchText, searchLength) + 1, 1)
    end
    if monitor then
        sClickList = Um.Print(filtered, selected, 0, nil, secondScreen, colAmount)
    end
end

local function storeAllFromTurtle()
    local notEmpty = true
    while notEmpty do
        notEmpty = false
        for i = 1, 16 do
            if turtle.getItemCount(i) > 0 then
                notEmpty = true
                turtle.select(i)
                if not turtle.dropDown() then
                    Storage:storeBuffer()
                end
            end
        end
    end

    Storage:storeBuffer()
end

local function storeItems()
    while true do
        if buffer then
            local event = { os.pullEvent() }
            if event[1] == 'turtle_inventory' and multishell.getCurrent() == multishell.getFocus() then
                os.queueEvent('click_ignore')

                -- Drop all items from turtle to buffer
                storeAllFromTurtle()
                filter(Storage.list)
                sortList()
                printScreen()
                os.queueEvent('click_start')
            elseif event[1] == 'turtle_inventory_ignore' then
                os.pullEvent('turtle_inventory_start')
            end
        else
            os.pullEvent('Updated_Env')
        end
    end
end

local function loopSort()
    while true do
        if buffer then
            Storage:sortStorage()

            scrollIndex = math.min(
                math.max(scrollIndex, 0),
                math.max(math.ceil(#filtered / colAmount) - screenSize[2], 0)
            )

            printScreen()
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
    selected = { filtered[id] }
    local itemName = filtered[id].name
    local _, droppedLastItem = Storage:retrieveItem(itemName, percentOfStack)
    if droppedLastItem then
        table.remove(filtered, id) -- instantly remove from viewed list if none left
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
    local keyscroll = {
        [keys.getName(keys.up)] = -1,
        [keys.getName(keys.down)] = 1
    }
    while true do
        if buffer then
            local event = { os.pullEvent() }
            if event[1] == 'mouse_scroll' then
                if scrollIndex ~= math.min(math.max(scrollIndex + event[2], 0), math.max(math.ceil(#filtered / colAmount) - screenSize[2], 0)) then
                    scrollIndex = scrollIndex + event[2]
                    printScreen()
                end
            elseif event[1] == "key" then
                -- local validKey = keyscroll[keys.getName(event[2])]
                -- if validKey then
                --     if scrollIndex ~= math.min(math.max(scrollIndex + validKey, 0), math.max(math.ceil(#filtered / colAmount) - screenSize[2], 0)) then
                --         scrollIndex = scrollIndex + event[2]
                --         printScreen()
                --     end
                -- end
                -- if event[2] == keys.getName(keys.up) then

                -- elseif event[2] == keys.getName(keys.down) then
                -- end
                -- printScreen()
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

    Storage:scanStorage()
    filtered = Storage.list
    sortList()
end

local function loopEnv()
    while true do
        os.pullEvent('Update_Env')
        loadEnv()
        selected = {}
        scrollIndex = 0
        printScreen()
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
    term.setTextColor(colors.white)
    print(success)
    print(result)
    print(debug.traceback())
    os.pullEvent("key")
end
--#endregion
