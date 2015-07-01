local _G, next, GetDisplayName, GetUnitName, ReloadUI = _G, next, GetDisplayName, GetUnitName, ReloadUI
local Restacker = Restacker

local defaultSettings = {
  hideStackInfo = false,
  events = {
    onFence = true,
    onTrade = false,
    onGuildBank = false,
    onMail = false
  },
  fco = {
    lock = false,
    sell = false,
    sellGuild = false
  },
  itemSaver = {
    lock = false
  },
  filterIt = {
    save = false,
    tradeHouse = false,
    trade = false,
    vendor = false,
    mail = false,
    alchemy = false,
    enchant = false,
    provision = false
  }
}

local function updateVariables(savedVariables, deprecatedVariables)
  savedVariables.hideStackInfo = not deprecatedVariables.displayStackInfo
  savedVariables.events.onFence = deprecatedVariables.onFence
  savedVariables.events.onTrade = deprecatedVariables.onTrade
  savedVariables.events.onGuildBank = deprecatedVariables.onGuildBank
  savedVariables.events.onMail = deprecatedVariables.onMail
  savedVariables.fco.lock = deprecatedVariables.fcoLock
  savedVariables.fco.sell = deprecatedVariables.fcoSell
  savedVariables.fco.sellGuild = deprecatedVariables.fcoSellGuild
  savedVariables.itemSaver.lock = deprecatedVariables.itemSaverLock
  savedVariables.filterIt.save = deprecatedVariables.filterItSave
  savedVariables.filterIt.tradeHouse = deprecatedVariables.filterItTradeHouse
  savedVariables.filterIt.trade = deprecatedVariables.filterItTrade
  savedVariables.filterIt.vendor = deprecatedVariables.filterItVendor
  savedVariables.filterIt.mail = deprecatedVariables.filterItMail
  savedVariables.filterIt.alchemy = deprecatedVariables.filterItAlchemy
  savedVariables.filterIt.enchant = deprecatedVariables.filterItEnchant
  savedVariables.filterIt.provision = deprecatedVariables.filterItProvision
end

local function getDeprecatedVariables()
  local currentSavedVariables = _G['RestackerVars']
  if next(currentSavedVariables) then
    currentSavedVariables = currentSavedVariables.Default[GetDisplayName()][GetUnitName("player")]
    return currentSavedVariables and currentSavedVariables.version == 0.2 and currentSavedVariables
  end
end

local function initializeSavedVariables()
  local deprecatedVariables = getDeprecatedVariables()
  local savedVariables = ZO_SavedVars:New("RestackerVars", 1, nil, defaultSettings)

  if deprecatedVariables then
    updateVariables(savedVariables, deprecatedVariables)
  end

  Restacker.savedVariables = savedVariables

  return savedVariables
end

-- globals
Restacker.initializeSavedVariables = initializeSavedVariables