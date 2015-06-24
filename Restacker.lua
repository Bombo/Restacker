Restacker = {}
Restacker.name = "Restacker"
Restacker.version = "0.6"

local lam = LibStub:GetLibrary("LibAddonMenu-2.0")
local FENCE, TRADE, GUILD_BANK, MAIL = 1, 2, 3, 4

local myButtonGroup = {
	{
		name = "Restack",
		keybind = "RESTACKER_RESTACK_BAG"
	},
	alignment = KEYBIND_STRIP_ALIGN_RIGHT,
}

Restacker.defaultSettings = {
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

function Restacker.DisplayStackResult(fromSlot, toSlot, fromStackSize, toStackSize, quantity)
    local itemLink = GetItemLink(BAG_BACKPACK, toSlot, LINK_STYLE_DEFAULT)
    local toStackSizeAfter = toStackSize + quantity
    local output = zo_strformat('Restacked <<5>><<t:1>>: [<<2>>][<<3>>] -> [<<4>>]', itemLink, toStackSize, fromStackSize, toStackSizeAfter, getIcon(toSlot))
    if fromStackSize - quantity > 0 then
        local fromStackSizeAfter = fromStackSize - quantity
        output = zo_strformat('<<1>>[<<2>>]', output, fromStackSizeAfter)
    end
    d(output)
end

function Restacker.CheckFCOLocks(instanceId)
    if (FCOIsMarked 
            and (Restacker.savedVariables.fcoLock
                or Restacker.savedVariables.fcoSell
                or Restacker.savedVariables.fcoSellGuild
            )
        ) then
        local _, flags = FCOIsMarked(instanceId, -1)
        return (Restacker.savedVariables.fcoLock and flags[1]) 
            or (Restacker.savedVariables.fcoSell and flags[5])
            or (Restacker.savedVariables.fcoSellGuild and flags[11])
    end
    return false
end

function Restacker.CheckItemSaverLock(bagSlot)
    if (ItemSaver_IsItemSaved and Restacker.savedVariables.itemSaverLock) then
        return ItemSaver_IsItemSaved(BAG_BACKPACK, bagSlot)
    end
    return false
end

function Restacker.CheckFilterItLocks(bagSlot)
    if FilterIt then
        local filter = PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK].slots[bagSlot].FilterIt_CurrentFilter
        if filter and filter ~= FILTERIT_NONE then
            local result = (Restacker.savedVariables.filterItSave and filter == FILTERIT_ALL
                or Restacker.savedVariables.filterItTradeHouse and filter == FILTERIT_TRADINGHOUSE
                or Restacker.savedVariables.filterItTrade and filter == FILTERIT_TRADE
                or Restacker.savedVariables.filterItVendor and filter == FILTERIT_VENDOR
                or Restacker.savedVariables.filterItMail and filter == FILTERIT_MAIL
                or Restacker.savedVariables.filterItAlchemy and filter == FILTERIT_ALCHEMY
                or Restacker.savedVariables.filterItEnchant and filter == FILTERIT_ENCHANTING
                or Restacker.savedVariables.filterItProvision and filter == FILTERIT_PROVISIONING)
            return result        
        end
    end
end

function Restacker.CreateFilterItOutput(filterItStack, slotData)
    for _, element in ipairs(filterItStack) do
        if Restacker.savedVariables.displayStackInfo then
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
            if Restacker.CheckFilterItLocks(bagSlot) then
                local slotData = { slot = bagSlot, stackSize = stackSize }
                if filterItStacks[instanceId] then
                    Restacker.CreateFilterItOutput(filterItStacks[instanceId], slotData)
                    table.insert(filterItStacks[instanceId], slotData)
                else
                    filterItStacks[instanceId] = { slotData }
                end
            elseif stacks[stackId] == nil and stackSize < maxStackSize then
                stacks[stackId] = {
                    slot = bagSlot,
                    data = bagSlotData,
                    stackSize = stackSize,
                    fcoLocked = Restacker.CheckFCOLocks(instanceId),
                    itemSaverLocked = Restacker.CheckItemSaverLock(bagSlot)
                }
                if filterItStacks[instanceId] then
                    Restacker.CreateFilterItOutput(filterItStacks[instanceId], stacks[stackId])
                end
            else
                if filterItStacks[instanceId] then
                    Restacker.CreateFilterItOutput(filterItStacks[instanceId], stacks[stackId])
                end
                local toSlot = stacks[stackId].slot
                local toStackSize = stacks[stackId].stackSize
                if stacks[stackId].fcoLocked then
                    if Restacker.savedVariables.displayStackInfo then
                        displaySkipMessage(toSlot, stackSize, toStackSize, 'FCO ItemSaver')
                    end
                elseif stacks[stackId].itemSaverLocked then
                    if Restacker.savedVariables.displayStackInfo then
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
                    
                    if Restacker.savedVariables.displayStackInfo then
                        Restacker.DisplayStackResult(bagSlot, toSlot, stackSize, toStackSize, quantity)
                    end
                end
            end
        end
    end
end

function Restacker.StackAndUnhook()
    Restacker.RestackBag()
    EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_CLOSE_STORE)
    EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_CLOSE_FENCE)
end

function Restacker.OnFence()
    --[[ as EVENT_CLOSE_FENCE doesn't seem to work at the moment, we hook up for both
         that event and the currently firing EVENT_CLOSE_STORE.
    --]]
    EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_CLOSE_STORE, Restacker.StackAndUnhook)
    EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_CLOSE_FENCE, Restacker.StackAndUnhook)
end

function Restacker.SetEvents(type)
    if type == FENCE then
        EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_OPEN_FENCE, Restacker.OnFence)
    elseif type == TRADE then
        EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_TRADE_SUCCEEDED, Restacker.RestackBag)
    elseif type == GUILD_BANK then
        EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_CLOSE_GUILD_BANK, Restacker.RestackBag)
    elseif type == MAIL then
        EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, Restacker.RestackBag)
    end
end

function Restacker.UnsetEvents(type)
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

function Restacker.OnAddOnLoaded(event, addonName)
    if addonName ~= Restacker.name then return end
    Restacker:Initialize()
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
                return Restacker.savedVariables.onFence
            end,
            setFunc = function(newValue)
                Restacker.savedVariables.onFence = (newValue)
                if newValue then 
                    Restacker.SetEvents(FENCE)
                else 
                    Restacker.UnsetEvents(FENCE)
                end
            end,
            width = "full"
        },
        [4] = {
            type = "checkbox",
            name = "On Trading Items",
            tooltip = "Restacking gets triggered when successfully trading with another player",
            getFunc = function() 
                return Restacker.savedVariables.onTrade
            end,
            setFunc = function(newValue)
                Restacker.savedVariables.onTrade = (newValue)
                if newValue then 
                    Restacker.SetEvents(TRADE)
                else
                    Restacker.UnsetEvents(TRADE)
                end
            end,
            width = "full"
        },
        [5] = {
            type = "checkbox",
            name = "On Withdrawing Items from Guild Bank",
            tooltip = "Restacking gets triggered when withdrawing items from guild bank",
            getFunc = function() 
                return Restacker.savedVariables.onGuildBank
            end,
            setFunc = function(newValue)
                Restacker.savedVariables.onGuildBank = (newValue)
                if newValue then 
                    Restacker.SetEvents(GUILD_BANK)
                else
                    Restacker.UnsetEvents(GUILD_BANK)
                end
            end,
            width = "full"
        },
        [6] = {
            type = "checkbox",
            name = "On Taking Mail Attachements",
            tooltip = "Restacking gets triggered when taking stackable items from mails",
            getFunc = function() 
                return Restacker.savedVariables.onMail
            end,
            setFunc = function(newValue)
                Restacker.savedVariables.onMail = (newValue)
                if newValue then 
                    Restacker.SetEvents(MAIL)
                else
                    Restacker.UnsetEvents(MAIL)
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
                return not Restacker.savedVariables.displayStackInfo
            end,
            setFunc = function(newValue)
                Restacker.savedVariables.displayStackInfo = (not newValue)
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
                    getFunc = function() return Restacker.savedVariables.fcoLock end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.fcoLock = newValue
                    end,
                    disabled = function() return not(FCOIsMarked) end,
                },
                [2] = {
                    type = "checkbox",
                    name = "Ignore items marked for selling",
                    getFunc = function() return Restacker.savedVariables.fcoSell end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.fcoSell = newValue
                    end,
                    disabled = function() return not(FCOIsMarked) end,
                },
                [3] = {
                    type = "checkbox",
                    name = "Ignore items marked for selling at guild store",
                    tooltip = "Ignore items marked for selling at guild store",
                    getFunc = function() return Restacker.savedVariables.fcoSellGuild end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.fcoSellGuild = newValue
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
                    getFunc = function() return Restacker.savedVariables.itemSaverLock end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.itemSaverLock = newValue
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
                    getFunc = function() return Restacker.savedVariables.filterItSave end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.filterItSave = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [2] = {
                    type = "checkbox",
                    name = "Ignore tradehouse items",
                    getFunc = function() return Restacker.savedVariables.filterItTradeHouse end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.filterItTradeHouse = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [3] = {
                    type = "checkbox",
                    name = "Ignore trade items",
                    getFunc = function() return Restacker.savedVariables.filterItTrade end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.filterItTrade = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [4] = {
                    type = "checkbox",
                    name = "Ignore vendor items",
                    getFunc = function() return Restacker.savedVariables.filterItVendor end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.filterItVendor = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [5] = {
                    type = "checkbox",
                    name = "Ignore mail items",
                    getFunc = function() return Restacker.savedVariables.filterItMail end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.filterItMail = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [6] = {
                    type = "checkbox",
                    name = "Ignore alchemy items",
                    getFunc = function() return Restacker.savedVariables.filterItAlchemy end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.filterItAlchemy = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [7] = {
                    type = "checkbox",
                    name = "Ignore enchantment items",
                    getFunc = function() return Restacker.savedVariables.filterItEnchant end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.filterItEnchant = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                },
                [8] = {
                    type = "checkbox",
                    name = "Ignore provisioning items",
                    getFunc = function() return Restacker.savedVariables.filterItProvision end,
                    setFunc = function(newValue)
                        Restacker.savedVariables.filterItProvision = newValue
                    end,
                    disabled = function() return not(FilterIt) end,
                }
            }
        }
    }

    lam:RegisterOptionControls("Restacker_SETTINGS", optionsTable)
end

local function handleKeybindStrip()
	local inventoryScene = ZO_Scene:New("inventory", SCENE_MANAGER)
	inventoryScene:RegisterCallback("StateChange", function(oldState, newState)
		-- d(newState)
	end)
	-- local bar = INVENTORY_MENU_BAR.modeBar:Add(SI_INVENTORY_MODE_INVENTORY, { INVENTORY_FRAGMENT, BACKPACK_MENU_BAR_LAYOUT_FRAGMENT }, {}, myButtonGroup)
end

function Restacker:Initialize()
    Restacker.savedVariables = ZO_SavedVars:New("RestackerVars", 0.2, nil, Restacker.defaultSettings)
    Restacker.CreateSettingsWindow()

    if Restacker.savedVariables.onFence then
        Restacker.SetEvents(FENCE)
    end
    
    if Restacker.savedVariables.onTrade then
        Restacker.SetEvents(TRADE)
    end

    if Restacker.savedVariables.onGuildBank then
        Restacker.SetEvents(GUILD_BANK)
    end
	
    if Restacker.savedVariables.onMail then
        Restacker.SetEvents(MAIL)
    end

	handleKeybindStrip()
    
    EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_ADD_ON_LOADED)
	
	ZO_CreateStringId("SI_BINDING_NAME_RESTACKER_RESTACK_BAG", "Restack Bag")
end

SLASH_COMMANDS["/restack"] = Restacker.RestackBag

EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_ADD_ON_LOADED, Restacker.OnAddOnLoaded)