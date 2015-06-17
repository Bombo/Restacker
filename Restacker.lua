Restacker = {}
Restacker.name = "Restacker"
Restacker.version = "0.5"

local lam = LibStub:GetLibrary("LibAddonMenu-2.0")
local FENCE, TRADE, GUILD_BANK = 1, 2, 3

Restacker.defaultSettings = {
	onFence = true,
	onTrade = false,
	onGuildBank = false,
	displayStackInfo = true,
	fcoLock = false,
	fcoSell = false,
	fcoSellGuild = false,
	itemSaverLock = false
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

function Restacker.RestackBag()
	local bagCache  = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
	local stacks = {}
	
	for bagSlot, bagSlotData in pairs(bagCache) do
		local stackSize, maxStackSize = GetSlotStackSize(BAG_BACKPACK, bagSlot)
		local instanceId = GetItemInstanceId(BAG_BACKPACK, bagSlot)
		local skip = false
		
		if not skip and stackSize ~= maxStackSize and not bagSlotData.stolen then
			if stacks[instanceId] == nil and stackSize < maxStackSize then
				stacks[instanceId] = {
					slot = bagSlot,
					data = bagSlotData,
					stackSize = stackSize,
					fcoLocked = Restacker.CheckFCOLocks(instanceId),
					itemSaverLocked = Restacker.CheckItemSaverLock(bagSlot)
				}
			else
                local toSlot = stacks[instanceId].slot
                local toStackSize = stacks[instanceId].stackSize
                if stacks[instanceId].fcoLocked then
                    if Restacker.savedVariables.displayStackInfo then
                        displaySkipMessage(toSlot, stackSize, toStackSize, 'FCO ItemSaver')
                    end
				elseif stacks[instanceId].itemSaverLocked then
					if Restacker.savedVariables.displayStackInfo then
                        displaySkipMessage(toSlot, stackSize, toStackSize, 'Item Saver')
                    end
                else
                    local toSlot = stacks[instanceId].slot
                    local toStackSize = stacks[instanceId].stackSize
                    local quantity = zo_min(stackSize, maxStackSize - toStackSize)
                    if IsProtectedFunction("RequestMoveItem") then
                        CallSecureProtected("RequestMoveItem", BAG_BACKPACK, bagSlot, BAG_BACKPACK, toSlot, quantity)
                    else
                        RequestMoveItem(BAG_BACKPACK, bagSlot, BAG_BACKPACK, toSlot, quantity)
                    end
                    
                    local stackFilled = toStackSize + quantity == maxStackSize
                    if stackFilled then
                        stacks[instanceId] = nil
                    else
                        stacks[instanceId].stackSize = toStackSize + quantity
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
	end
end

function Restacker.UnsetEvents(type)
	if type == FENCE then
		EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_OPEN_FENCE)
	elseif type == TRADE then
		EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_TRADE_SUCCEEDED)
	elseif type == GUILD_BANK then
		EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_CLOSE_GUILD_BANK)
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
			type = "header",
			name = "Output",
			width = "full"
		},
		[7] = {
			type = "description",
			title = nil,
			text = 'Tell restacker to shut up.',
			width = "full"
		},
		[8] = {
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
		[9] = {
			type = "header",
			name = "Other Addons Support",
			width = "full"
		},
		[10] = {
			type = "description",
			title = nil,
			text = 'Set how Restacker should behave in regards to other addons',
			width = "full"
		},
		[11] = {
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
		[12] = {
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
		}
	}

	lam:RegisterOptionControls("Restacker_SETTINGS", optionsTable)
end

function Restacker:Initialize()
	Restacker.savedVariables = ZO_SavedVars:New("RestackerVars", 0.2, nil, Restacker.defaultSettings)
	-- remove unneeded setting from savedVars (I like them clean)
	Restacker.savedVariables.onMail = nil
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
	
	EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_ADD_ON_LOADED)
end

SLASH_COMMANDS["/restack"] = Restacker.RestackBag

EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_ADD_ON_LOADED, Restacker.OnAddOnLoaded)