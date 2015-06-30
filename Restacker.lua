Restacker = {}
Restacker.name = "Restacker"
Restacker.version = "0.6.1"

local lam = LibStub:GetLibrary("LibAddonMenu-2.0")
local FENCE, TRADE, GUILD_BANK, MAIL = 1, 2, 3, 4

local restackButton = {
	name = "Restack Bag",
	keybind = "RESTACKER_RESTACK_BAG",
	callback = function() Restacker.RestackBag() end
}

local myButtonGroup = {
	restackButton,
	alignment = KEYBIND_STRIP_ALIGN_CENTER,
}

local defaultSettings = {
    onFence = true,
    onTrade = false,
    onGuildBank = false,
    onMail = false,
    displayStackInfo = true,
    fcoLock = false,
    fcoSell = false,
    fcoSellGuild = false,
    itemSaverLock = false,
    filterItSave = false,
    filterItTradeHouse = false,
    filterItTrade = false,
    filterItVendor = false,
    filterItMail = false,
    filterItAlchemy = false,
    filterItEnchant = false,
    filterItProvision = false
}

local savedVariables

local function getIcon(slot)
    local icon = GetItemInfo(BAG_BACKPACK, slot)
    if icon == nil then 
        return ''
    else
        local fontSize = GetChatFontSize();
        return zo_iconFormat(icon, fontSize, fontSize) .. ' '
    end
end

local function displaySkipMessage(slot, fromStackSize, toStackSize, reason)
    local itemLink = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
    local output = zo_strformat('Skipped restacking of <<5>><<t:1>> ([<<2>>][<<3>>]) because of <<4>> settings', itemLink, toStackSize, fromStackSize, reason, getIcon(slot))
    d(output)
end

local function displayStackResult(fromSlot, toSlot, fromStackSize, toStackSize, quantity)
    local itemLink = GetItemLink(BAG_BACKPACK, toSlot, LINK_STYLE_DEFAULT)
    local toStackSizeAfter = toStackSize + quantity
    local output = zo_strformat('Restacked <<5>><<t:1>>: [<<2>>][<<3>>] -> [<<4>>]', itemLink, toStackSize, fromStackSize, toStackSizeAfter, getIcon(toSlot))
    if fromStackSize - quantity > 0 then
        local fromStackSizeAfter = fromStackSize - quantity
        output = zo_strformat('<<1>>[<<2>>]', output, fromStackSizeAfter)
    end
    d(output)
end

local function checkFCOLocks(instanceId)
    if (FCOIsMarked 
            and (savedVariables.fcoLock
                or savedVariables.fcoSell
                or savedVariables.fcoSellGuild
            )
        ) then
        local _, flags = FCOIsMarked(instanceId, -1)
        return (savedVariables.fcoLock and flags[1])
            or (savedVariables.fcoSell and flags[5])
            or (savedVariables.fcoSellGuild and flags[11])
    end
    return false
end

local function checkItemSaverLock(bagSlot)
    if (ItemSaver_IsItemSaved and savedVariables.itemSaverLock) then
        return ItemSaver_IsItemSaved(BAG_BACKPACK, bagSlot)
    end
    return false
end

local function checkFilterItLocks(bagSlot)
    if FilterIt then
        local filter = PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK].slots[bagSlot].FilterIt_CurrentFilter
        if filter and filter ~= FILTERIT_NONE then
            local result = (savedVariables.filterItSave and filter == FILTERIT_ALL
                or savedVariables.filterItTradeHouse and filter == FILTERIT_TRADINGHOUSE
                or savedVariables.filterItTrade and filter == FILTERIT_TRADE
                or savedVariables.filterItVendor and filter == FILTERIT_VENDOR
                or savedVariables.filterItMail and filter == FILTERIT_MAIL
                or savedVariables.filterItAlchemy and filter == FILTERIT_ALCHEMY
                or savedVariables.filterItEnchant and filter == FILTERIT_ENCHANTING
                or savedVariables.filterItProvision and filter == FILTERIT_PROVISIONING)
            return result        
        end
    end
end

local function createFilterItOutput(filterItStack, slotData)
    for _, element in ipairs(filterItStack) do
        if savedVariables.displayStackInfo then
            displaySkipMessage(element.slot, slotData.stackSize, element.stackSize, 'FilterIt')
        end
    end
end

function Restacker.RestackBag()
    local bagCache  = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    local stacks = {}
    local filterItStacks = {}
    
    for bagSlot, bagSlotData in pairs(bagCache) do
        local stackSize, maxStackSize = GetSlotStackSize(BAG_BACKPACK, bagSlot)
        local instanceId = GetItemInstanceId(BAG_BACKPACK, bagSlot)
		local stackId = instanceId
		
		if bagSlotData.stolen then
			stackId = stackId .. 1
		else
			stackId = stackId .. 0
		end
        
        if stackSize ~= maxStackSize then
            if checkFilterItLocks(bagSlot) then
                local slotData = { slot = bagSlot, stackSize = stackSize }
                if filterItStacks[instanceId] then
                    createFilterItOutput(filterItStacks[instanceId], slotData)
                    table.insert(filterItStacks[instanceId], slotData)
                else
                    filterItStacks[instanceId] = { slotData }
                end
            elseif stacks[stackId] == nil and stackSize < maxStackSize then
                stacks[stackId] = {
                    slot = bagSlot,
                    data = bagSlotData,
                    stackSize = stackSize,
                    fcoLocked = checkFCOLocks(instanceId),
                    itemSaverLocked = checkItemSaverLock(bagSlot)
                }
                if filterItStacks[instanceId] then
                    createFilterItOutput(filterItStacks[instanceId], stacks[stackId])
                end
            else
                if filterItStacks[instanceId] then
                    createFilterItOutput(filterItStacks[instanceId], stacks[stackId])
                end
                local toSlot = stacks[stackId].slot
                local toStackSize = stacks[stackId].stackSize
                if stacks[stackId].fcoLocked then
                    if savedVariables.displayStackInfo then
                        displaySkipMessage(toSlot, stackSize, toStackSize, 'FCO ItemSaver')
                    end
                elseif stacks[stackId].itemSaverLocked then
                    if savedVariables.displayStackInfo then
                        displaySkipMessage(toSlot, stackSize, toStackSize, 'Item Saver')
                    end
                else
                    local toSlot = stacks[stackId].slot
                    local toStackSize = stacks[stackId].stackSize
                    local quantity = zo_min(stackSize, maxStackSize - toStackSize)
                    if IsProtectedFunction("RequestMoveItem") then
                        CallSecureProtected("RequestMoveItem", BAG_BACKPACK, bagSlot, BAG_BACKPACK, toSlot, quantity)
                    else
                        RequestMoveItem(BAG_BACKPACK, bagSlot, BAG_BACKPACK, toSlot, quantity)
                    end
                    
                    local stackFilled = toStackSize + quantity == maxStackSize
                    if stackFilled then
                        stacks[stackId] = nil
                    else
                        stacks[stackId].stackSize = toStackSize + quantity
                    end
                    
                    if savedVariables.displayStackInfo then
                        displayStackResult(bagSlot, toSlot, stackSize, toStackSize, quantity)
                    end
                end
            end
        end
    end
end

local function stackAndUnhook()
    Restacker.RestackBag()
    EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_CLOSE_STORE)
    EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_CLOSE_FENCE)
end

local function onFence()
    --[[ as EVENT_CLOSE_FENCE doesn't seem to work at the moment, we hook up for both
         that event and the currently firing EVENT_CLOSE_STORE.
    --]]
    EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_CLOSE_STORE, stackAndUnhook)
    EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_CLOSE_FENCE, stackAndUnhook)
end

local function setEvents(type)
    if type == FENCE then
        EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_OPEN_FENCE, onFence)
    elseif type == TRADE then
        EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_TRADE_SUCCEEDED, Restacker.RestackBag)
    elseif type == GUILD_BANK then
        EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_CLOSE_GUILD_BANK, Restacker.RestackBag)
    elseif type == MAIL then
        EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, Restacker.RestackBag)
    end
end

local function unsetEvents(type)
    if type == FENCE then
        EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_OPEN_FENCE)
    elseif type == TRADE then
        EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_TRADE_SUCCEEDED)
    elseif type == GUILD_BANK then
        EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_CLOSE_GUILD_BANK)
    elseif type == MAIL then
        EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS)
    end
end

function Restacker.CreateSettingsWindow()
    local panelData = {
        type = 'panel',
        name = 'Restacker'
    }

    lam:RegisterAddonPanel('Restacker_SETTINGS', panelData)
    
    local optionsTable = {
        [1] = {
            type = "header",
            name = "Events",
            width = "full"
        },
        [2] = {
            type = "description",
            title = nil,
            text = 'Set the events to trigger restacking.',
            width = "full"
        },
        [3] = {
            type = "checkbox",
            name = "On Laundering Items",
            tooltip = "Restacking gets triggered when leaving a fence",
            getFunc = function() 
                return savedVariables.onFence
            end,
            setFunc = function(newValue)
                savedVariables.onFence = (newValue)
                if newValue then 
                    setEvents(FENCE)
                else 
                    unsetEvents(FENCE)
                end
            end,
            width = "full"
        },
        [4] = {
            type = "checkbox",
            name = "On Trading Items",
            tooltip = "Restacking gets triggered when successfully trading with another player",
            getFunc = function() 
                return savedVariables.onTrade
            end,
            setFunc = function(newValue)
                savedVariables.onTrade = (newValue)
                if newValue then 
                    setEvents(TRADE)
                else
                    unsetEvents(TRADE)
                end
            end,
            width = "full"
        },
        [5] = {
            type = "checkbox",
            name = "On Withdrawing Items from Guild Bank",
            tooltip = "Restacking gets triggered when withdrawing items from guild bank",
            getFunc = function() 
                return savedVariables.onGuildBank
            end,
            setFunc = function(newValue)
                savedVariables.onGuildBank = (newValue)
                if newValue then 
                    setEvents(GUILD_BANK)
                else
                    unsetEvents(GUILD_BANK)
                end
            end,
            width = "full"
        },
        [6] = {
            type = "checkbox",
            name = "On Taking Mail Attachements",
            tooltip = "Restacking gets triggered when taking stackable items from mails",
            getFunc = function() 
                return savedVariables.onMail
            end,
            setFunc = function(newValue)
                savedVariables.onMail = (newValue)
                if newValue then 
                    setEvents(MAIL)
                else
                    unsetEvents(MAIL)
                end
            end,
            width = "full"
        },
        [7] = {
            type = "header",
            name = "Output",
            width = "full"
        },
        [8] = {
            type = "description",
            title = nil,
            text = 'Tell restacker to shut up.',
            width = "full"
        },
        [9] = {
            type = "checkbox",
            name = "Shut Up",
            tooltip = "Hides the restacker chat output",
            getFunc = function() 
                return not savedVariables.displayStackInfo
            end,
            setFunc = function(newValue)
                savedVariables.displayStackInfo = (not newValue)
            end,
            width = "full"
        },
        [10] = {
            type = "header",
            name = "Other Addons Support",
            width = "full"
        },
        [11] = {
            type = "description",
            title = nil,
            text = 'Set how Restacker should behave in regards to other addons',
            width = "full"
        },
        [12] = {
            type = "submenu",
            name = "FCO ItemSaver",
            tooltip = "Settings for FCO ItemSaver addon",
            controls = {
                [1] = {
                    type = "checkbox",
                    name = "Ignore locked items",
                    getFunc = function() return savedVariables.fcoLock end,
                    setFunc = function(newValue)
                        savedVariables.fcoLock = newValue
                    end,
                    disabled = function() return not(FCOIsMarked) end,
                },
                [2] = {
                    type = "checkbox",
                    name = "Ignore items marked for selling",
                    getFunc = function() return savedVariables.fcoSell end,
                    setFunc = function(newValue)
                        savedVariables.fcoSell = newValue
                    end,
                    disabled = function() return not(FCOIsMarked) end,
                },
                [3] = {
                    type = "checkbox",
                    name = "Ignore items marked for selling at guild store",
                    tooltip = "Ignore items marked for selling at guild store",
                    getFunc = function() return savedVariables.fcoSellGuild end,
                    setFunc = function(newValue)
                        savedVariables.fcoSellGuild = newValue
                    end,
                    disabled = function() return not(FCOIsMarked) end,
                }
            }
        },
        [13] = {
            type = "submenu",
            name = "Item Saver",
            tooltip = "Settings for Item Saver addon",
            controls = {
                [1] = {
                    type = "checkbox",
                    name = "Ignore saved items",
                    getFunc = function() return savedVariables.itemSaverLock end,
                    setFunc = function(newValue)
                        savedVariables.itemSaverLock = newValue
                    end,
                    disabled = function() return not(ItemSaver_IsItemSaved) end,
                }
            }
        },
        [14] = {
            type = "submenu",
            name = "FilterIt",
            tooltip = "Settings for Circonians FilterIt addon",
            controls = {
                [1] = {
                    type = "checkbox",
                    name = "Ignore saved items",
                    getFunc = function() return savedVariables.filterItSave end,
                    setFunc = function(newValue)
                        savedVariables.filterItSave = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [2] = {
                    type = "checkbox",
                    name = "Ignore tradehouse items",
                    getFunc = function() return savedVariables.filterItTradeHouse end,
                    setFunc = function(newValue)
                        savedVariables.filterItTradeHouse = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [3] = {
                    type = "checkbox",
                    name = "Ignore trade items",
                    getFunc = function() return savedVariables.filterItTrade end,
                    setFunc = function(newValue)
                        savedVariables.filterItTrade = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [4] = {
                    type = "checkbox",
                    name = "Ignore vendor items",
                    getFunc = function() return savedVariables.filterItVendor end,
                    setFunc = function(newValue)
                        savedVariables.filterItVendor = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [5] = {
                    type = "checkbox",
                    name = "Ignore mail items",
                    getFunc = function() return savedVariables.filterItMail end,
                    setFunc = function(newValue)
                        savedVariables.filterItMail = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [6] = {
                    type = "checkbox",
                    name = "Ignore alchemy items",
                    getFunc = function() return savedVariables.filterItAlchemy end,
                    setFunc = function(newValue)
                        savedVariables.filterItAlchemy = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [7] = {
                    type = "checkbox",
                    name = "Ignore enchantment items",
                    getFunc = function() return savedVariables.filterItEnchant end,
                    setFunc = function(newValue)
                        savedVariables.filterItEnchant = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [8] = {
                    type = "checkbox",
                    name = "Ignore provisioning items",
                    getFunc = function() return savedVariables.filterItProvision end,
                    setFunc = function(newValue)
                        savedVariables.filterItProvision = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                }
            }
        }
    }

    lam:RegisterOptionControls("Restacker_SETTINGS", optionsTable)
end

local function handleKeybindStrip()
	local inventoryScene = SCENE_MANAGER:GetScene("inventory")
	inventoryScene:RegisterCallback("StateChange", function(oldState, newState)
		zo_callLater(function () 
			if newState == SCENE_SHOWN then
				KEYBIND_STRIP:AddKeybindButtonGroup(myButtonGroup)
			elseif newState == SCENE_HIDDEN then
				KEYBIND_STRIP:RemoveKeybindButtonGroup(myButtonGroup)
			end
		end, 100)
	end)
	
	table.insert(PLAYER_INVENTORY.bankDepositTabKeybindButtonGroup, restackButton)
	KEYBIND_STRIP:UpdateKeybindButtonGroup(PLAYER_INVENTORY.bankDepositTabKeybindButtonGroup)
end

local function initialize()
    savedVariables = ZO_SavedVars:New("RestackerVars", 0.2, nil, defaultSettings)
    Restacker.CreateSettingsWindow()

    if savedVariables.onFence then
        setEvents(FENCE)
    end
    
    if savedVariables.onTrade then
        setEvents(TRADE)
    end

    if savedVariables.onGuildBank then
        setEvents(GUILD_BANK)
    end
	
    if savedVariables.onMail then
        setEvents(MAIL)
    end

	handleKeybindStrip()
    
    EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_ADD_ON_LOADED)
	
	ZO_CreateStringId("SI_BINDING_NAME_RESTACKER_RESTACK_BAG", "Restack Bag")
end

local function onAddOnLoaded(_, addonName)
    if addonName ~= Restacker.name then return end
    initialize()
end

SLASH_COMMANDS["/restack"] = Restacker.RestackBag

EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_ADD_ON_LOADED, onAddOnLoaded)