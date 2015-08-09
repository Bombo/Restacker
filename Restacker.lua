-- creating local references of everything global to get the edge in performance ;)
local table, pairs = table, pairs
local BAG_BACKPACK, BAG_BANK, LINK_STYLE_DEFAULT, INVENTORY_BACKPACK, INVENTORY_BANK,  KEYBIND_STRIP_ALIGN_CENTER, KEYBIND_STRIP, SCENE_SHOWN, SCENE_HIDDEN = BAG_BACKPACK, BAG_BANK, LINK_STYLE_DEFAULT, INVENTORY_BACKPACK, INVENTORY_BANK, KEYBIND_STRIP_ALIGN_CENTER, KEYBIND_STRIP, SCENE_SHOWN, SCENE_HIDDEN
local EVENT_ADD_ON_LOADED, EVENT_CLOSE_STORE, EVENT_CLOSE_FENCE, EVENT_OPEN_FENCE, EVENT_TRADE_SUCCEEDED, EVENT_CLOSE_GUILD_BANK, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS = EVENT_ADD_ON_LOADED, EVENT_CLOSE_STORE, EVENT_CLOSE_FENCE, EVENT_OPEN_FENCE, EVENT_TRADE_SUCCEEDED, EVENT_CLOSE_GUILD_BANK, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS
local PLAYER_INVENTORY, SHARED_INVENTORY, EVENT_MANAGER, SCENE_MANAGER, SLASH_COMMANDS = PLAYER_INVENTORY, SHARED_INVENTORY, EVENT_MANAGER, SCENE_MANAGER, SLASH_COMMANDS
local GetItemInfo, GetItemLink, GetItemInstanceId, GetChatFontSize, GetSlotStackSize = GetItemInfo, GetItemLink, GetItemInstanceId, GetChatFontSize, GetSlotStackSize
local zo_iconFormat, zo_strformat, zo_min, zo_callLater, d, ZO_CreateStringId = zo_iconFormat, zo_strformat, zo_min, zo_callLater, d, ZO_CreateStringId
local IsProtectedFunction, CallSecureProtected = IsProtectedFunction, CallSecureProtected
local FCOIsMarked, ItemSaver_IsItemSaved = FCOIsMarked, ItemSaver_IsItemSaved
local FilterIt, FILTERIT_NONE, FILTERIT_ALL, FILTERIT_TRADINGHOUSE, FILTERIT_TRADE = FilterIt, FILTERIT_NONE, FILTERIT_ALL, FILTERIT_TRADINGHOUSE, FILTERIT_TRADE
local FILTERIT_VENDOR, FILTERIT_MAIL, FILTERIT_ALCHEMY, FILTERIT_ENCHANTING, FILTERIT_PROVISIONING = FILTERIT_VENDOR, FILTERIT_MAIL, FILTERIT_ALCHEMY, FILTERIT_ENCHANTING, FILTERIT_PROVISIONING

local Restacker = Restacker
local FENCE, TRADE, GUILD_BANK, MAIL = Restacker.FENCE, Restacker.TRADE, Restacker.GUILD_BANK, Restacker.MAIL

local savedVariables

-- storing if a manual restack with no result happened already
local triedAlready = {
  [BAG_BACKPACK] = false,
  [BAG_BANK] = false
}

-- get a chat icon for an item in a given bag slot
local function getIcon(bagId, slot)
  local icon = GetItemInfo(bagId, slot)
  local fontSize = GetChatFontSize();
  return icon and zo_iconFormat(icon, fontSize, fontSize) .. ' '
end

-- display a message, if restacking incomplete stacks was skipped because of some addon settings (reason == adoon name)
local function displaySkipMessage(bagId, slot)
  if not savedVariables.hideStackInfo then
    local itemLink = GetItemLink(bagId, slot, LINK_STYLE_DEFAULT)
    local output = zo_strformat('Skipped restacking of <<2>><<t:1>> because of addon locks', itemLink, getIcon(bagId, slot))
    d(output)
  end
end

-- display the result of restacking (outputs "Restacked [ICON] ITEM_NAME: [toStackSize][fromStackSize] -> [toStackSizeAfter]
local function displayStackResult(bagId, toSlot, beforeValues, afterValues)
  if not savedVariables.hideStackInfo then
    local itemLink = GetItemLink(bagId, toSlot, LINK_STYLE_DEFAULT)
    local output = zo_strformat('Restacked <<4>><<t:1>>: <<2>> -> <<3>>', itemLink, beforeValues, afterValues, getIcon(bagId, toSlot))
    d(output)
  end
end

-- check an item by instanceId for FCO ItemSaver locks
local function checkFCOLocks(bagId, bagSlot)
  local instanceId = GetItemInstanceId(bagId, bagSlot)
  local fcoSettings = savedVariables.fco
  if (FCOIsMarked
      and (fcoSettings.lock
      or fcoSettings.sell
      or fcoSettings.sellGuild)) then
    local _, flags = FCOIsMarked(instanceId, -1)
    return (fcoSettings.lock and flags[1])
        or (fcoSettings.sell and flags[5])
        or (fcoSettings.sellGuild and flags[11])
  end
  return false
end

-- check an item by location for Item Saver locks
local function checkItemSaverLock(bagId, bagSlot)
  if (ItemSaver_IsItemSaved and savedVariables.itemSaver.lock) then
    return ItemSaver_IsItemSaved(bagId, bagSlot)
  end
  return false
end

-- check an item by location for FilterIt locks
local function checkFilterItLocks(bagId, bagSlot)
  local inventoryId = bagId == BAG_BANK and INVENTORY_BANK or INVENTORY_BACKPACK
  if FilterIt then
    local filter = PLAYER_INVENTORY.inventories[inventoryId].slots[bagSlot].FilterIt_CurrentFilter
    local filterItSettings = savedVariables.filterIt
    if filter and filter ~= FILTERIT_NONE then
      local result = (filterItSettings.save and filter == FILTERIT_ALL
          or filterItSettings.tradeHouse and filter == FILTERIT_TRADINGHOUSE
          or filterItSettings.trade and filter == FILTERIT_TRADE
          or filterItSettings.vendor and filter == FILTERIT_VENDOR
          or filterItSettings.mail and filter == FILTERIT_MAIL
          or filterItSettings.alchemy and filter == FILTERIT_ALCHEMY
          or filterItSettings.enchant and filter == FILTERIT_ENCHANTING
          or filterItSettings.provision and filter == FILTERIT_PROVISIONING)
      return result
    end
  end
end

-- wraps the RequestMoveItem call for convenience
local function moveItem(fromBagId, fromSlot, toBagId, toSlot, quantity)
  if IsProtectedFunction("RequestMoveItem") then
    CallSecureProtected("RequestMoveItem", fromBagId, fromSlot, toBagId, toSlot, quantity)
  else
    RequestMoveItem(fromBagId, fromSlot, toBagId, toSlot, quantity)
  end
end

-- create a table containing meta information for a slot
local function createSlotData(bagId, bagSlot, bagSlotData, stackSize)
    return {
      bagId = bagId,
      slot = bagSlot,
      data = bagSlotData,
      stackSize = stackSize
    }
end

local function checkIsAddonLocked(bagId, bagSlot)
  return checkFCOLocks(bagId, bagSlot)
    or checkItemSaverLock(bagId, bagSlot)
    or checkFilterItLocks(bagId, bagSlot)
end

local function toStackOutputFormat(stackSize)
  return zo_strformat('[<<1>>]', stackSize)
end

--[[ restack the bag by a given bagId (defaults to BAG_BACKPACK) by iterating over every bag slot of that bag and
-- looking for the same item (identified by instanceId and stolen information) in different, incomplete stacks
--]]
local function restackBag(bagId)
  bagId = bagId or BAG_BACKPACK

  local didRestack = false
  local bagCache = SHARED_INVENTORY:GenerateFullSlotData(nil, bagId)
  local unfinishedStacks = {}
  local restackCandidates = {}

  for bagSlot, bagSlotData in pairs(bagCache) do
    local stackSize, maxStackSize = GetSlotStackSize(bagId, bagSlot)
    local instanceId = GetItemInstanceId(bagId, bagSlot)
    local stackId = instanceId

    stackId = stackId .. (bagSlotData.stolen and 1 or 0)

    if stackSize < maxStackSize then -- only look for unfinished stacks
      local stacksForCurrentId = unfinishedStacks[stackId]

      local slotData = createSlotData(bagId, bagSlot, bagSlotData, stackSize)

      local locked = checkIsAddonLocked(bagId, bagSlot)

      if stacksForCurrentId then
        local firstStack = stacksForCurrentId[1]
        local candidateInfo = restackCandidates[stackId]

        if not candidateInfo then
          candidateInfo = { stacks = {}, lockedStackInfo = nil, maxStackSize = maxStackSize }
          if (firstStack.locked) then
            candidateInfo.lockedStackInfo = firstStack
          else
            table.insert(candidateInfo.stacks, firstStack)
          end
        end
        if locked then
          candidateInfo.lockedStackInfo = candidateInfo.lockedStackInfo or slotData;
        else
          table.insert(candidateInfo.stacks, slotData)
        end

        restackCandidates[stackId] = candidateInfo
      else
        stacksForCurrentId = { locked = locked }
        unfinishedStacks[stackId] = stacksForCurrentId
        table.insert(stacksForCurrentId, slotData)
      end
    end
  end

  for _, restackCandidate in pairs(restackCandidates) do
    if restackCandidate.lockedStackInfo then
      displaySkipMessage(bagId, restackCandidate.lockedStackInfo.slot)
    end

    local numberOfStacks = table.getn(restackCandidate.stacks)
    if numberOfStacks > 1 then
      local currentStack = restackCandidate.stacks[1]
      local toSlot = currentStack.slot
      local toStackSize = currentStack.stackSize
      local beforeValues = toStackOutputFormat(toStackSize)
      local afterValues = ''
      local maxStackSize = restackCandidate.maxStackSize
      for i = 2, numberOfStacks, 1 do
        currentStack = restackCandidate.stacks[i]
        local fromSlot = currentStack.slot
        local fromStackSize = currentStack.stackSize
        beforeValues = beforeValues .. toStackOutputFormat(fromStackSize)
        local currentDifference = maxStackSize - toStackSize
        local quantity = zo_min(fromStackSize, currentDifference)

        moveItem(bagId, fromSlot, bagId, toSlot, quantity)
        didRestack = true
        triedAlready[bagId] = false

        toStackSize = toStackSize + quantity
        if toStackSize == maxStackSize then
          afterValues = afterValues .. toStackOutputFormat(toStackSize)
          if (fromStackSize ~= quantity) then
            toSlot = fromSlot
            toStackSize = fromStackSize - quantity
            if i == numberOfStacks then
              afterValues = afterValues .. toStackOutputFormat(toStackSize)
            end
          elseif i < numberOfStacks then
            i = i + 1
            currentStack = restackCandidate.stacks[i]
            toSlot = currentStack.slot
            toStackSize = currentStack.stackSize
          end
        elseif i == numberOfStacks then
          afterValues = afterValues .. toStackOutputFormat(toStackSize)
        end
      end
      displayStackResult(bagId, toSlot, beforeValues, afterValues)
    end
  end

  return didRestack
end

-- restack function to be called by slash commands of buttons / key binds
local function manualRestack(bagId)
  bagId = bagId ~= '' and bagId or BAG_BACKPACK
  local somethingChanged = restackBag(bagId);
  if not somethingChanged then
    if triedAlready[bagId] then
      d('Still nothing to restack.')
    else
      triedAlready[bagId] = true
      d('Nothing to restack')
    end
  end
end

-- event handler for closing the fence, where we restack and unhook from the close event
local function onCloseFence()
  restackBag()
  EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_CLOSE_STORE)
  EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_CLOSE_FENCE)
end

-- event handler for opening a fence window, where we hook up handlers for the close event
local function onFence()
  --[[ as EVENT_CLOSE_FENCE doesn't seem to work at the moment, we hook up for both
       that event and the currently firing EVENT_CLOSE_STORE.
  --]]
  EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_CLOSE_STORE, onCloseFence)
  EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_CLOSE_FENCE, onCloseFence)
end

-- local table to store what event to listen to and what handler to call for the respective Restacker event types
local eventMap = {
  [FENCE] = { EVENT_OPEN_FENCE, onFence },
  [TRADE] = { EVENT_TRADE_SUCCEEDED, restackBag },
  [GUILD_BANK] = { EVENT_CLOSE_GUILD_BANK, restackBag },
  [MAIL] = { EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, restackBag }
}

-- hook up for the respective event by given Restacker event type
local function setEvents(type)
  local eventData = eventMap[type]
  if (eventData) then
    EVENT_MANAGER:RegisterForEvent(Restacker.name, eventData[1], eventData[2])
  end
end

-- remove event hooks for the respective event by given Restacker event type
local function unsetEvents(type)
  local eventData = eventMap[type]
  if (eventData) then
    EVENT_MANAGER:UnregisterForEvent(Restacker.name, eventData[1])
  end
end

-- meta information for the restack button placed on the keybind strip
local restackButton = {
  name = "Restack Bag",
  keybind = "RESTACKER_RESTACK_BAG",
  callback = function() manualRestack() end
}

-- meta information for the restack bank button placed on the keybind strip
local restackBankButton = {
  name = "Restack Bank",
  keybind = "RESTACKER_RESTACK_BANK",
  callback = function()
    local bankScene = SCENE_MANAGER:GetScene("bank")
    if (SCENE_MANAGER.currentScene == bankScene) then
      manualRestack(BAG_BANK)
    end
  end
}

-- button group for the inventory keybind strip
local myButtonGroup = {
  restackButton,
  alignment = KEYBIND_STRIP_ALIGN_CENTER,
}

-- add a button to the inventory keybind strip, and each of the bank keybind strips
local function handleKeybindStrip()
  local inventoryScene = SCENE_MANAGER:GetScene("inventory")
  inventoryScene:RegisterCallback("StateChange", function(_, newState)
    zo_callLater(function()
      if newState == SCENE_SHOWN then
        KEYBIND_STRIP:AddKeybindButtonGroup(myButtonGroup)
      elseif newState == SCENE_HIDDEN then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(myButtonGroup)
      end
    end, 100)
  end)

  table.insert(PLAYER_INVENTORY.bankDepositTabKeybindButtonGroup, restackButton)
  KEYBIND_STRIP:UpdateKeybindButtonGroup(PLAYER_INVENTORY.bankDepositTabKeybindButtonGroup)

  table.insert(PLAYER_INVENTORY.bankWithdrawTabKeybindButtonGroup, restackBankButton)
  KEYBIND_STRIP:UpdateKeybindButtonGroup(PLAYER_INVENTORY.bankWithdrawTabKeybindButtonGroup)
end

--[[ initialize the addon by getting/creating saved variables, setting up the LAM2 window, hooking up to set events,
-- adding buttons to keybind strips, and creating key bindings.
--]]
local function initialize()
  savedVariables = Restacker.initializeSavedVariables()

  Restacker.createSettingsWindow()

  if savedVariables.events.onFence then
    setEvents(FENCE)
  end

  if savedVariables.events.onTrade then
    setEvents(TRADE)
  end

  if savedVariables.events.onGuildBank then
    setEvents(GUILD_BANK)
  end

  if savedVariables.events.onMail then
    setEvents(MAIL)
  end

  handleKeybindStrip()

  EVENT_MANAGER:UnregisterForEvent(Restacker.name, EVENT_ADD_ON_LOADED)

  ZO_CreateStringId("SI_BINDING_NAME_RESTACKER_RESTACK_BANK", "Restack Bank")
  ZO_CreateStringId("SI_BINDING_NAME_RESTACKER_RESTACK_BAG", "Restack Bag")
end

-- event handler for addon initialization
local function onAddOnLoaded(_, addonName)
  if addonName ~= Restacker.name then return end
  initialize()
end

-- globals
Restacker.setEvents = setEvents
Restacker.unsetEvents = unsetEvents
Restacker.restackBag = restackButton.callback
Restacker.restackBank = restackBankButton.callback

-- create slash command
SLASH_COMMANDS["/restack"] = manualRestack

-- register addon load
EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_ADD_ON_LOADED, onAddOnLoaded)