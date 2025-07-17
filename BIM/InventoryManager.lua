--#region Locals--
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

local sortFunction = { 1, listSort[1] }

local list = {}
local filtered = {} -- {... 4 values}
local clickList = {}
local sClickList = {}
local scrollIndex = 0
local selected = 0
local buffer = nil
local chests = {}
local monitor = nil

local mainScreen = term.current()
local mainSize = { mainScreen.getSize() }
local secondScreen = window.create(mainScreen, 1, 1, 1, 1)
secondScreen.setVisible(false)
local screen, screenSize, scrollBar = Um.Create(mainScreen, 1, 2, mainSize[1], mainSize[2], colors.black, colors.white, true,
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

local function Error(where, ...) -- debug tool
    local errMonitor = peripheral.wrap("right")
    assert(errMonitor, "Couldn't find monitor")
    errMonitor.clear()
    errMonitor.setCursorPos(1, 1)
    errMonitor.write("Error at: " .. where)

    local args = {...}
    for i = 1, #args do
        errMonitor.setCursorPos(1, i + 2)
        errMonitor.write(args[i])
    end
    error("encountered an error.")
end
do
    local errMonitor = peripheral.wrap("right")
    if errMonitor then
        errMonitor.clear()
        errMonitor.setCursorPos(1, 1)
    end
end

local function SortList()
    table.sort(list, sortFunction[2])
    Filter(textutils.unserialiseJSON(textutils.serialiseJSON(Vs.list)))
    table.sort(filtered, sortFunction[2])
end

--#region Functions--
---Maps out where items are
function CountChests()
    local chestlist={}
    for i,chest in ipairs(chests) do
        local items=chest.list()
        for j,item in pairs(items) do
            local name=item.name
            if chestlist[name]==nil then chestlist[name]={} end
            table.insert(
                chestlist[name],
                {
                    side=peripheral.getName(chest),
                    slot=j,
                    count=item.count,
                    name=name
                }
            )
        end
    end
    Vs.chests= chestlist
end

function SortItems()
    local newList={}
    local itemlist={}
    for item,data in pairs(Vs.chests) do
        local count=0
        local disName=nil
        for i,slot1 in ipairs(data)do
            if slot1.count~=0 then
                local chest=peripheral.wrap(slot1.side)
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
                for j=i+1,#data,1 do
                    local transferd=chest.pullItems(data[j].side,data[j].slot,data[j].count,slot1.slot)
                    Vs.chests[item][j].count=data[j].count-transferd
                    Vs.chests[item][i].count=slot1.count+transferd
                end
                count=count+slot1.count
            end
        end
        table.insert(itemlist,{count,disName})
        table.insert(newList,{count,disName,item})
    end
    Vs.list=itemlist
    list=newList
    SortList()
end

function StoreItems()
    while true do
        if buffer then
            local  event={os.pullEvent()}
            if event[1]=='turtle_inventory' and multishell.getCurrent()==multishell.getFocus() then
                os.queueEvent('click_ignore')
                local id=0
                repeat
                    os.cancelTimer(id)
                    id =os.startTimer(1)
                    local timer={os.pullEvent()}
                until timer[2]==id
                for i=1,16 do
                    if turtle.getItemCount(i) > 0 then
                        turtle.select(i)
                        turtle.dropDown()
                    end
                end
                for i,item in pairs(buffer.list()) do
                    for _,chest in pairs(chests)do
                        if item.count==0 then break end
                        buffer.pushItems(peripheral.getName(chest),i)
                    end
                end
                os.queueEvent('click_start')
            elseif event[1]=='turtle_inventory_ignore' then
                os.pullEvent('turtle_inventory_start')
            end
        else
            os.pullEvent('Updated_Env')
        end
    end
end

function LoopSort()
    while true do
        if buffer then
            CountChests()
            SortItems()
            scrollIndex=math.min(math.max(scrollIndex,0),math.max(math.ceil(#filtered/colAmount)-screenSize[2],0))
            PrintScreen()
            if monitor then sClickList=Um.Print(filtered,selected,0,nil,secondScreen,colAmount) end
            sleep(10)
        else
            screen.clear()
            screen.setCursorPos(1,1)
            screen.write("No Buffer selected")
            os.pullEvent('Updated_Env')
            screen.clear()
            screen.setCursorPos(1,1)
            screen.write('Sorting...')
        end
    end
end

---Grab an item from storage and drop it to the player
---@param id integer the index that the player clicks
function DropItem(id)

    -- filtered[id] == {int:count, string:displayName}; int keys

    if id==nil or list[id]==nil then return nil end
    local stack = 0
    selected={filtered[id]}
    if not list[id] then
        Error("Drop Item", Vs.chests[list[id][3]], "DONE")
    end
    -- List[id].id = Item name i.e. minecraft:andesite
    -- for i, data in ipairs(Vs.chests[List[id].id]) do -- attempt to index nil value
    for i, data in ipairs(Vs.chests[list[id][3]]) do
        if data.count>0 then
            local transferd= buffer.pullItems(data.side, data.slot, 64 - stack)
            stack = stack + transferd
            Vs.list[id][1] = Vs.list[id][1] - transferd
            filtered[id][1] = filtered[id][1] - transferd
            Vs.chests[data.name][i].count=Vs.chests[data.name][i].count-transferd
            if stack >= 64 then
                break
            end
        end
    end
    Um.Print(filtered,selected,scrollIndex,scrollBar,screen,colAmount)
    if monitor then Um.Print(filtered,selected,0,nil,secondScreen,colAmount) end
    turtle.drop()
    repeat
        os.queueEvent('turtle_inventory_ignore')
        turtle.select(16)
        turtle.suckDown()
        turtle.drop()
    until table.maxn(buffer.list())==0
    os.queueEvent('turtle_inventory_start')
end

function PrintScreen()
    searchBar.setCursorBlink(false)
    clickList=Um.Print(filtered,selected,scrollIndex,scrollBar,screen,colAmount)
    if searching then
        searchBar.setCursorBlink(true)
        searchBar.setCursorPos(math.min(#searchText,searchLength)+1,1)
    end
end

function LoopPrint()
    while true do
        if buffer then
            local event = { os.pullEvent() }
            if event[1] == 'mouse_scroll'  and scrollIndex ~=math.min(math.max(scrollIndex + event[2],0),math.max(math.ceil(#filtered/colAmount)-screenSize[2],0)) then
                scrollIndex = scrollIndex + event[2]
                PrintScreen()
                if monitor then sClickList=Um.Print(filtered,selected,0,nil,secondScreen,colAmount) end
            elseif event[1] == 'mouse_click' and event[4]>=2 and event[3] < select(2, term.getSize()) then
                DropItem(Um.Click(clickList, event[3], event[4]))
            elseif event[1] =='monitor_touch' and monitor then
                DropItem(Um.Click(sClickList, event[3], event[4]))
            elseif event[1]=='click_ignore' then
                os.pullEvent('click_start')
            end
        else
            os.pullEvent('Updated_Env')
        end
    end
end

function LoopEnv()
    while true do
        os.pullEvent('Update_Env')
        LoadEnv()
        selected=0
        scrollIndex=0
        PrintScreen()
        if monitor then sClickList=Um.Print(filtered,selected,0,nil,secondScreen,colAmount) end
        os.queueEvent('Updated_Env')
    end
end

function LoadEnv()
    buffer=peripheral.wrap(Vs.getEnv('Buffer'))

    local ignore={}
    for _,ig in pairs(Vs.getEnv('IgnoreInv'))do
        ignore[ig]=true
    end
    chests={peripheral.find(Vs.getEnv('Inventories'), function(name,type)
        return not (ignore[name]) or false
    end)}

    colAmount = tonumber(Vs.getEnv('Columns'))

    monitor=peripheral.wrap(Vs.getEnv('Monitor'))
    if monitor then
        local monitorSize={monitor.getSize()}
        secondScreen.reposition(1,1,monitorSize[1],monitorSize[2],monitor)
        secondScreen.setVisible(true)
    else
        secondScreen.setVisible(false)
    end
end

function LoopTopBar()
    while true do
        local event = { os.pullEvent("mouse_click") }

        if event[4] == 1 then -- only when clicked on top bar
            if event[3] > (#searchTitle) and event[3] < (sBSize[1]+#searchTitle) then
                BeginSearch()
            elseif event[3] > (searchSize[1] - #sortDisplay[sortFunction[1]]) then
                if sortFunction[1] + 1 <= 4 then
                    sortFunction = { sortFunction[1] + 1, listSort[sortFunction[1] + 1] }
                else
                    sortFunction = { 1, listSort[1] }
                end
                search.setCursorPos(searchSize[1] - #sortDisplay[sortFunction[1]] - 3, 1)
                search.write("   " .. sortDisplay[sortFunction[1]])
                SortList()
                PrintScreen()
            end
        end
    end
end

function BeginSearch()
    searchBar.setCursorPos(math.min(#searchText+1,searchLength-1),1)
    searchBar.setCursorBlink(true)
    searching=true
    while true do
        local event = { os.pullEvent() }
        if  event[1] == 'mouse_click' and not (event[4]==1 and event[3]>(#searchTitle) and event[3]<(sBSize[1]+#searchTitle)) then
            break
        elseif  event[1] == 'char' then
            if searchLength<=#searchText+3 then
                searchBar.setCursorPos(1,1)
                searchBar.write(searchText:sub(#searchText-searchLength+3, -1))
            end
            searchBar.write(event[2])
            searchText=searchText..event[2]
        elseif event[1] == 'key'  and #searchText>0 then
            local k= keys.getName(event[2])
            if k == 'backspace' then
                if searchLength<=#searchText then
                    searchBar.setCursorPos(1,1)
                    searchBar.write(searchText:sub(#searchText+1-searchLength, -2))
                    searchBar.write(' ')
                else
                    searchBar.setCursorPos(#searchText,1)
                    searchBar.write(' ')
                end
                searchText=searchText:sub(1, -2)
            end
        end
        if  event[1] == 'char' or event[1] == 'key' then
        SortList()
        PrintScreen()
        end
    end
    searchBar.setCursorBlink(false)
    searching=false
end

function MetaCall(table)
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

function Filter(list)
    if #searchText<1 then filtered=list return end -- if no search query

    setmetatable(list,{__call=MetaCall})
    local searchtext=searchText:lower():gsub("%s+", "")
    local inverted=list()
    local filtering={}
    local results=textutils.complete(searchtext,inverted)

    for i,v in ipairs(results) do
        local value=inverted[searchtext..v]
        if value then
            table.insert(filtering,Vs.list[value])
        end
    end

    filtered=filtering

end

--#endregion Functions--

--#region Main--


repeat
    sleep(0.1)
until Vs.getEnv()~=nil
LoadEnv()


screen.setCursorPos(1,1)
screen.write('Sorting...')
search.setCursorPos(1,1)
search.write(searchTitle..string.rep(' ',(searchLength)+1)..'|')
search.setCursorPos(searchSize[1]-#sortDisplay[sortFunction[1]],1)
search.write(sortDisplay[sortFunction[1]])
searchBar.clear()
local success, result = pcall(function()
    parallel.waitForAll(LoopSort,LoopPrint,StoreItems, LoopEnv,LoopTopBar)
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