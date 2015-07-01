local FENCE, TRADE, GUILD_BANK, MAIL = Restacker.FENCE, Restacker.TRADE, Restacker.GUILD_BANK, Restacker.MAIL

local savedVariables

local triedAlready = false

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

local function displayStackResult(toSlot, fromStackSize, toStackSize, quantity)
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

local function checkItemSaverLock(bagSlot)
  if (ItemSaver_IsItemSaved and savedVariables.itemSaver.lock) then
    return ItemSaver_IsItemSaved(BAG_BACKPACK, bagSlot)
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

local function createFilterItOutput(filterItStack, slotData)
  for _, element in ipairs(filterItStack) do
    if not savedVariables.hideStackInfo then
      displaySkipMessage(element.slot, slotData.stackSize, element.stackSize, 'FilterIt')
    end
  end
end

local function restackBag()
  local didRestack = false
  local bagCache = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
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
          if not savedVariables.hideStackInfo then
            displaySkipMessage(toSlot, stackSize, toStackSize, 'FCO ItemSaver')
          end
        elseif stacks[stackId].itemSaverLocked then
          if not savedVariables.hideStackInfo then
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

          didRestack = true
          triedAlready = false

          local stackFilled = toStackSize + quantity == maxStackSize
          if stackFilled then
            stacks[stackId] = nil
          else
            stacks[stackId].stackSize = toStackSize + quantity
          end

          if not savedVariables.hideStackInfo then
            displayStackResult(toSlot, stackSize, toStackSize, quantity)
          end
        end
      end
    end
  end
  return didRestack
end

local function manualRestack()
  local somethingChanged = restackBag();
  if not somethingChanged then
    if triedAlready then
      d('Still nothing to restack.')
    else
      triedAlready = true
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

local function setEvents(type)
  if type == FENCE then
    EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_OPEN_FENCE, onFence)
  elseif type == TRADE then
    EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_TRADE_SUCCEEDED, restackBag)
  elseif type == GUILD_BANK then
    EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_CLOSE_GUILD_BANK, restackBag)
  elseif type == MAIL then
    EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, restackBag)
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

local restackButton = {
  name = "Restack Bag",
  keybind = "RESTACKER_RESTACK_BAG",
  callback = function() manualRestack() end
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

  ZO_CreateStringId("SI_BINDING_NAME_RESTACKER_RESTACK_BAG", "Restack Bag")
end

local function onAddOnLoaded(_, addonName)
  if addonName ~= Restacker.name then return end
  initialize()
end

-- globals
Restacker.setEvents = setEvents
Restacker.unsetEvents = unsetEvents

-- create slash command
SLASH_COMMANDS["/restack"] = manualRestack

-- register addon load
EVENT_MANAGER:RegisterForEvent(Restacker.name, EVENT_ADD_ON_LOADED, onAddOnLoaded)