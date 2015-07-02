-- creating local references of everything global to get the edge in performance ;)
local table, ipairs, pairs = table, ipairs, pairs
local BAG_BACKPACK, BAG_BANK, LINK_STYLE_DEFAULT, INVENTORY_BACKPACK, KEYBIND_STRIP_ALIGN_CENTER, KEYBIND_STRIP, SCENE_SHOWN, SCENE_HIDDEN = BAG_BACKPACK, BAG_BANK, LINK_STYLE_DEFAULT, INVENTORY_BACKPACK, KEYBIND_STRIP_ALIGN_CENTER, KEYBIND_STRIP, SCENE_SHOWN, SCENE_HIDDEN
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

local triedAlready = {
  [BAG_BACKPACK] = false,
  [BAG_BANK] = false
}

local function getIcon(bagId, slot)
  local icon = GetItemInfo(bagId, slot)
  if icon == nil then
    return ''
  else
    local fontSize = GetChatFontSize();
    return zo_iconFormat(icon, fontSize, fontSize) .. ' '
  end
end

local function displaySkipMessage(bagId, slot, fromStackSize, toStackSize, reason)
  if not savedVariables.hideStackInfo then
    local itemLink = GetItemLink(bagId, slot, LINK_STYLE_DEFAULT)
    local output = zo_strformat('Skipped restacking of <<5>><<t:1>> ([<<2>>][<<3>>]) because of <<4>> settings', itemLink, toStackSize, fromStackSize, reason, getIcon(bagId, slot))
    d(output)
  end
end

local function displayStackResult(bagId, toSlot, fromStackSize, toStackSize, quantity)
  if not savedVariables.hideStackInfo then
    local itemLink = GetItemLink(bagId, toSlot, LINK_STYLE_DEFAULT)
    local toStackSizeAfter = toStackSize + quantity
    local output = zo_strformat('Restacked <<5>><<t:1>>: [<<2>>][<<3>>] -> [<<4>>]', itemLink, toStackSize, fromStackSize, toStackSizeAfter, getIcon(bagId, toSlot))
    if fromStackSize - quantity > 0 then
      local fromStackSizeAfter = fromStackSize - quantity
      output = zo_strformat('<<1>>[<<2>>]', output, fromStackSizeAfter)
    end
    d(output)
  end
end

local function checkFCOLocks(instanceId)
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

local function checkItemSaverLock(bagId, bagSlot)
  if (ItemSaver_IsItemSaved and savedVariables.itemSaver.lock) then
    return ItemSaver_IsItemSaved(bagId, bagSlot)
  end
  return false
end

local function checkFilterItLocks(bagSlot)
  if FilterIt then
    local filter = PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK].slots[bagSlot].FilterIt_CurrentFilter
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

local function createFilterItOutput(filterItStack, bagId, slotData)
  if not savedVariables.hideStackInfo then
    for _, element in ipairs(filterItStack) do
      displaySkipMessage(bagId, element.slot, slotData.stackSize, element.stackSize, 'FilterIt')
    end
  end
end

local function moveItem(fromBagId, fromSlot, toBagId, toSlot, quantity)
  if IsProtectedFunction("RequestMoveItem") then
    CallSecureProtected("RequestMoveItem", fromBagId, fromSlot, toBagId, toSlot, quantity)
  else
    RequestMoveItem(fromBagId, fromSlot, toBagId, toSlot, quantity)
  end
end

local function createSlotData(bagId, bagSlot, bagSlotData, stackSize, instanceId)
    return {
      slot = bagSlot,
      data = bagSlotData,
      stackSize = stackSize,
      fcoLocked = checkFCOLocks(instanceId),
      itemSaverLocked = checkItemSaverLock(bagId, bagSlot)
    }
end

local function restackBag(bagId)
  bagId = bagId or BAG_BACKPACK

  local didRestack = false
  local bagCache = SHARED_INVENTORY:GenerateFullSlotData(nil, bagId)
  local stacks = {}
  local filterItStacks = {}

  for bagSlot, bagSlotData in pairs(bagCache) do
    local stackSize, maxStackSize = GetSlotStackSize(bagId, bagSlot)
    local instanceId = GetItemInstanceId(bagId, bagSlot)
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
          createFilterItOutput(filterItStacks[instanceId], bagId, slotData)
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
          itemSaverLocked = checkItemSaverLock(bagId, bagSlot)
        }
        if filterItStacks[instanceId] then
          createFilterItOutput(filterItStacks[instanceId], bagId, stacks[stackId])
        end
      else
        if filterItStacks[instanceId] then
          createFilterItOutput(filterItStacks[instanceId], bagId, stacks[stackId])
        end
        local toSlot = stacks[stackId].slot
        local toStackSize = stacks[stackId].stackSize
        if stacks[stackId].fcoLocked then
          displaySkipMessage(bagId, toSlot, stackSize, toStackSize, 'FCO ItemSaver')
        elseif stacks[stackId].itemSaverLocked then
          displaySkipMessage(bagId, toSlot, stackSize, toStackSize, 'Item Saver')
        else
          local toSlot = stacks[stackId].slot
          local toStackSize = stacks[stackId].stackSize
          local quantity = zo_min(stackSize, maxStackSize - toStackSize)
          if IsProtectedFunction("RequestMoveItem") then
            CallSecureProtected("RequestMoveItem", bagId, bagSlot, bagId, toSlot, quantity)
          else
            RequestMoveItem(bagId, bagSlot, bagId, toSlot, quantity)
          end

          didRestack = true
          triedAlready[bagId] = false

          local stackFilled = toStackSize + quantity == maxStackSize
          if stackFilled then
            stacks[stackId] = nil
          else
            stacks[stackId].stackSize = toStackSize + quantity
          end

          if not savedVariables.hideStackInfo then
            displayStackResult(bagId, toSlot, stackSize, toStackSize, quantity)
          end
        end
      end
    end
  end
  return didRestack
end

local function manualRestack(bagId)
  bagId = bagId or BAG_BACKPACK
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

local function stackAndUnhook()
  restackBag()
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

local eventMap = {
  [FENCE] = { EVENT_OPEN_FENCE, onFence },
  [TRADE] = { EVENT_TRADE_SUCCEEDED, restackBag },
  [GUILD_BANK] = { EVENT_CLOSE_GUILD_BANK, restackBag },
  [MAIL] = { EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, restackBag }
}

local function setEvents(type)
  local eventData = eventMap[type]
  if (eventData) then
    EVENT_MANAGER:RegisterForEvent(Restacker.name, eventData[1], eventData[2])
  end
end

local function unsetEvents(type)
  local eventData = eventMap[type]
  if (eventData) then
    EVENT_MANAGER:UnregisterForEvent(Restacker.name, eventData[1])
  end
end

local restackButton = {
  name = "Restack Bag",
  keybind = "RESTACKER_RESTACK_BAG",
  callback = function() manualRestack() end
}

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

local myButtonGroup = {
  restackButton,
  alignment = KEYBIND_STRIP_ALIGN_CENTER,
}

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