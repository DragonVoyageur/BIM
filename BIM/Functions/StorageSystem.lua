
local Vs

local SS = {}
SS.__index = SS

function SS:init(newVs)
    Vs = newVs
    self.storagePeripherals = { peripheral.find(Vs.getEnv("Inventories")) }
    local cardinal = { left = true, right = true, top = true, bottom = true, front = true, back = true }

    for i = #self.storagePeripherals, 1, -1 do
        local chestName = peripheral.getName(self.storagePeripherals[i])
        -- Storage should not include inventories adjacent to turtle or buffer inventory
        if cardinal[chestName] or chestName == Vs.getEnv("Buffer") then
            table.remove(self.storagePeripherals, i)
        end
    end

    self.buffer = peripheral.wrap(Vs.getEnv('Buffer'))
    assert(self.buffer, "Failed to wrap buffer")
end

function SS:scanStorage()
    local chestlist = {}
    local foundNewItemType = false
    local itemList = {}
    for _, chest in ipairs(self.storagePeripherals) do
        local items = chest.list()
        for slot, item in pairs(items) do
            local name = item.name -- i.e. minecraft:bone
            chestlist[name] = chestlist[name] or {}

            if Vs.setItemDetail(name, chest, slot, true) then
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
        table.insert(newItemList, { name = name, count = count })
    end
    self.list = newItemList

    self.chests = chestlist
    if foundNewItemType then
        Vs.saveItemDetails()
    end
end

function SS:sortStorage()

    for _, item in ipairs(self.list) do
        local maxCount = Vs.itemDetailsMap[item.name].maxCount
        local maxSlotsNeeded = math.ceil(item.count / maxCount)
        local itemChests = self.chests[item.name]
        if #itemChests > maxSlotsNeeded then
            local frontChest = 1
            while frontChest <= #itemChests do
                local frontSlotData = itemChests[frontChest]
                if frontSlotData.count < maxCount then
                    local frontChestPeripheral = peripheral.wrap(frontSlotData.side)
                    assert(frontChestPeripheral, "Peripheral not found.  Please report bug.")

                    -- Go from last chest with item and move it to front
                    for backChest = #itemChests, frontChest + 1, -1 do
                        local backSlotData = itemChests[backChest]
                        local backSide = backSlotData.side
                        local transferred = frontChestPeripheral.pullItems(
                            backSide,
                            backSlotData.slot,
                            64,
                            frontSlotData.slot
                        )
                        backSlotData.count = backSlotData.count - transferred
                        frontSlotData.count = frontSlotData.count + transferred
                        if backSlotData.count <= 0 then
                            table.remove(itemChests, backChest)
                        end
                        if frontSlotData.count == maxCount then
                            break
                        end
                    end
                end
                -- Only increment if we didn't remove the current frontChest
                if frontSlotData.count == maxCount or frontChest == #itemChests then
                    frontChest = frontChest + 1
                end
            end
        end
    end
end

function SS:pushBufferItemToStorage(chestName, fromSlotIndex, toSlotIndex, itemId)
    local pushed = self.buffer.pushItems(chestName, fromSlotIndex, 64, toSlotIndex)
    if pushed > 0 then
        -- Update self.chests
        self.chests[itemId] = self.chests[itemId] or {}
        table.insert(self.chests[itemId], {
            side = chestName,
            slot = toSlotIndex,
            count = pushed,
            name = itemId
        })
    end
    return pushed
end

function SS:storeBuffer()
    -- Get buffer inventory
    local bufferItems = self.buffer.list()
    for slot, item in pairs(bufferItems) do
        local itemId = item.name
        local itemCount = item.count
        Vs.setItemDetail(itemId, self.buffer, slot)

        local chestSlots = self.chests[itemId] or {}
        local remaining = itemCount
        -- Fill non-full stacks
        for _, chestSlot in ipairs(chestSlots) do
            if remaining <= 0 then break end
            local pushed = self.buffer.pushItems(chestSlot.side, slot, 64, chestSlot.slot)
            chestSlot.count = chestSlot.count + pushed
            remaining = remaining - pushed
        end

        -- Put remaining items in empty slots
        if remaining > 0 then
            for _, chest in ipairs(self.storagePeripherals) do
                local chestName = peripheral.getName(chest)
                local chestInv = chest.list()

                for chestSlotNum = 1, chest.size() do
                    if not chestInv[chestSlotNum] then
                        local pushed = self:pushBufferItemToStorage(chestName, slot, chestSlotNum, itemId)
                        remaining = remaining - pushed
                        if remaining <= 0 then break end
                    end
                end
                if remaining <= 0 then break end
            end
        end

        -- Update self.list
        local found = false
        for _, entry in ipairs(self.list) do
            if entry.name == itemId then
                entry.count = entry.count + itemCount
                found = true
                break
            end
        end
        if not found then
            table.insert(self.list, { count = itemCount, name = itemId })
        end
    end
end

function SS:retrieveItem(itemName, percentOfStack)
    local chestData = self.chests[itemName]
    if not chestData or #chestData == 0 then return false end

    -- Cache maxCount
    local maxCount = Vs.itemDetailsMap[itemName].maxCount
    local chest = peripheral.wrap(chestData[1].side)
    if chest then
        Vs.setItemDetail(itemName, chest, chestData[1].slot)
    end

    local amountToPull = math.ceil(maxCount * percentOfStack)
    local stack = 0
    local noMoreItemLeft = false

    for i = #chestData, 1, -1 do
        local data = chestData[i]
        if data.count > 0 and stack < amountToPull then
            local amount = math.min(amountToPull - stack, data.count)
            local transferred = self.buffer.pullItems(data.side, data.slot, amount)

            -- Remove from self.list to prevent items from re-appearing when sorting
            for l = #self.list, 1, -1 do
                local listItem = self.list[l]
                if listItem.name == itemName then
                    listItem.count = listItem.count - transferred
                end
                if listItem.count == 0 then
                    table.remove(self.list, l)
                    noMoreItemLeft = true
                    -- table.remove(filtered, id) -- instantly remove from viewed list if none left
                end
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

    return true, noMoreItemLeft
end

return setmetatable({
    chests = {},
    list = {},
    storagePeripherals = {},
    buffer = nil
}, SS)