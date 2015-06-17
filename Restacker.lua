Restacker = {}
Restacker.name = "Restacker"
Restacker.version = "0.3"

local lam = LibStub:GetLibrary("LibAddonMenu-2.0")

Restacker.defaultSettings = {
	onFence = true,
	onMail = false,
	onTrade = false,
	displayStackInfo = true,
	fcoLock = false,
	fcoSell = false,
	fcoSellGuild = false
}

function getIcon(slot)
    local icon = GetItemInfo(BAG_BACKPACK, slot)
    if icon == nil then 
        return ''
    else
        return zo_iconFormat(icon, 16, 16)
    end
end

function displaySkipMessage(slot, fromStackSize, toStackSize, reason)
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
    if (FCOIsMarked) then
        local _, flags = FCOIsMarked(instanceId, -1)
        return (Restacker.savedVariables.fcoLock and flags[1]) or (Restacker.savedVariables.fcoSell and flags[5]) or (Restacker.savedVariables.fcoSellGuild and flags[11])
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
		
		if not skip and stackSize ~= maxStackSize then
			if stacks[instanceId] == nil and stackSize < maxStackSize then
				stacks[instanceId] = {slot = bagSlot, data = bagSlotData, stackSize = stackSize, fcoLocked = Restacker.CheckFCOLocks(instanceId)}
			else
                local toSlot = stacks[instanceId].slot
                local toStackSize = stacks[instanceId].stackSize
                if stacks[instanceId].fcoLocked then
                    if Restacker.savedVariables.displayStackInfo then
                        displaySkipMessage(toSlot, stackSize, toStackSize, 'FCO ItemSaver')
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

function Restacker.HookupListener()
	--[[ as EVENT_CLOSE_FENCE doesn't seem to work at the moment, we hook up for both
	     that event and the currently firing EVENT_CLOSE_STORE.
	--]]
	if Restacker.savedVariables.onFence then
		EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_CLOSE_STORE, Restacker.StackAndUnhook)
		EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_CLOSE_FENCE, Restacker.StackAndUnhook)
	end
	
	if Restacker.savedVariables.onTrade then
		EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_TRADE_SUCCEEDED, Restacker.RestackBag)
	end
	
	if Restacker.savedVariables.onMail then
		EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, Restacker.RestackBag)
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
			end,
			width = "full"
		},
		[5] = {
			type = "checkbox",
			name = "On Taking Mail Attachments",
			tooltip = "Restacking gets triggered when taking mail attachments",
			getFunc = function() 
				return Restacker.savedVariables.onMail
			end,
			setFunc = function(newValue)
				Restacker.savedVariables.onMail = (newValue)
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
			tooltip = "Settings for FCO Item Saver addon",
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
		}
	}

	lam:RegisterOptionControls("Restacker_SETTINGS", optionsTable)
end

function Restacker:Initialize()
	Restacker.savedVariables = ZO_SavedVars:New("RestackerVars", 0.2, nil, Restacker.defaultSettings)
	Restacker.CreateSettingsWindow()

	EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_OPEN_FENCE, Restacker.HookupListener)
	EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_ADD_ON_LOADED)
end

SLASH_COMMANDS["/restack"] = Restacker.RestackBag

EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_ADD_ON_LOADED, Restacker.OnAddOnLoaded)