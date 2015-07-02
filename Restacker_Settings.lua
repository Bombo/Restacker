local lam = LibStub:GetLibrary("LibAddonMenu-2.0")
local optionsTable = {}
local index = 0
local savedVariables
local setEvents, unsetEvents
local Restacker = Restacker
local FENCE, TRADE, GUILD_BANK, MAIL = Restacker.FENCE, Restacker.TRADE, Restacker.GUILD_BANK, Restacker.MAIL

local FCOIsMarked = FCOIsMarked
local ItemSaver_IsItemSaved = ItemSaver_IsItemSaved
local FilterIt = FilterIt

local function registerLocals()
  savedVariables = Restacker.savedVariables
  setEvents = Restacker.setEvents
  unsetEvents = Restacker.unsetEvents
end

local function addField(field)
  index = index + 1
  optionsTable[index] = field
end

local function createHeaderData(name)
  return {
    type = "header",
    name = name,
    width = "full"
  }
end

local function createDescriptionData(text)
  return {
    type = "description",
    title = nil,
    text = text,
    width = "full"
  }
end

local function createCheckboxData(name, tooltip, callbacks, disabled)
  return {
    type = "checkbox",
    name = name,
    tooltip = tooltip,
    getFunc = callbacks.getFunc,
    setFunc = callbacks.setFunc,
    width = "full",
    disabled = disabled
  }
end

local function createEventCallbacks(varTable, savedVarName, eventConstant)
  return {
    getFunc = function()
      return varTable[savedVarName]
    end,
    setFunc = function(newValue)
      varTable[savedVarName] = newValue
      if newValue then
        setEvents(eventConstant)
      else
        unsetEvents(eventConstant)
      end
    end
  }
end

local function createSimpleCheckboxCallbacks(varTable, savedVarName)
  return {
    getFunc = function()
      return varTable[savedVarName]
    end,
    setFunc = function(newValue)
      varTable[savedVarName] = newValue
    end
  }
end

local function createEventsSectionData()
  addField(createHeaderData('Events'))

  addField(createDescriptionData('Set the events to trigger restacking.'))

  local eventsVars = savedVariables.events

  addField(createCheckboxData('On Laundering Items', 'Restacking gets triggered when leaving a fence', createEventCallbacks(eventsVars, 'onFence', FENCE)))
  addField(createCheckboxData('On Trading Items', 'Restacking gets triggered when successfully trading with another player', createEventCallbacks(eventsVars, 'onTrade', TRADE)))
  addField(createCheckboxData('On Withdrawing Items from Guild Bank', 'Restacking gets triggered when withdrawing items from guild bank', createEventCallbacks(eventsVars, 'onGuildBank', GUILD_BANK)))
  addField(createCheckboxData('On Taking Mail Attachements', 'Restacking gets triggered when taking stackable items from mails', createEventCallbacks(eventsVars, 'onMail', MAIL)))
end

local function createOutputData()
  addField(createHeaderData('Output'))

  addField(createDescriptionData('Tell restacker to shut up.'))

  addField(createCheckboxData('Shut Up', 'Hides the restacker chat output', createSimpleCheckboxCallbacks(savedVariables, 'hideStackInfo')))
end

local function createSubmenuData(name, tooltip, controls)
  return {
    type = "submenu",
    name = name,
    tooltip = tooltip,
    controls = controls
  }
end

local function createFCOData()
  local disabled = function() return not FCOIsMarked end

  local fcoVars = savedVariables.fco

  local controls = {
    createCheckboxData('Ignore locked items', nil, createSimpleCheckboxCallbacks(fcoVars, 'lock'), disabled),
    createCheckboxData('Ignore items marked for selling', nil, createSimpleCheckboxCallbacks(fcoVars, 'sell'), disabled),
    createCheckboxData('Ignore items marked for selling at guild store', 'Ignore items marked for selling at guild store', createSimpleCheckboxCallbacks(fcoVars, 'sellGuild'), disabled),
  }

  return createSubmenuData('FCO ItemSaver', 'Settings for FCO ItemSaver addon', controls)
end

local function createItemSaverData()
  local disabled = function() return not ItemSaver_IsItemSaved end

  local controls = {
    createCheckboxData('Ignore saved items', nil, createSimpleCheckboxCallbacks(savedVariables.itemSaver, 'lock'), disabled)
  }

  return createSubmenuData('Item Saver', 'Settings for Item Saver addon', controls)
end

local function createFilterItData()
  local disabled = function() return not FilterIt end

  local filterItVars = savedVariables.filterIt

  local controls = {
    createCheckboxData('Ignore saved items', nil, createSimpleCheckboxCallbacks(filterItVars, 'save'), disabled),
    createCheckboxData('Ignore tradehouse items', nil, createSimpleCheckboxCallbacks(filterItVars, 'tradeHouse'), disabled),
    createCheckboxData('Ignore trade items', nil, createSimpleCheckboxCallbacks(filterItVars, 'trade'), disabled),
    createCheckboxData('Ignore vendor items', nil, createSimpleCheckboxCallbacks(filterItVars, 'vendor'), disabled),
    createCheckboxData('Ignore mail items', nil, createSimpleCheckboxCallbacks(filterItVars, 'mail'), disabled),
    createCheckboxData('Ignore alchemy items', nil, createSimpleCheckboxCallbacks(filterItVars, 'alchemy'), disabled),
    createCheckboxData('Ignore enchantment items', nil, createSimpleCheckboxCallbacks(filterItVars, 'enchant'), disabled),
    createCheckboxData('Ignore provisioning items', nil, createSimpleCheckboxCallbacks(filterItVars, 'provision'), disabled)
  }

  return createSubmenuData('FilterIt', 'Settings for Circonians FilterIt addon', controls)
end

local function createAddonSupportData()
  addField(createHeaderData('Other Addons Support'))
  addField(createDescriptionData('Set how Restacker should behave in regards to other addons'))
  addField(createFCOData())
  addField(createItemSaverData())
  addField(createFilterItData())
end

local function createSettingsWindow()

  registerLocals()

  local panelData = {
    type = 'panel',
    name = 'Restacker',
    displayName = '|c81BAC7Restacker|r',
    author = 'Bombo',
    version = tostring(Restacker.version)
  }
  lam:RegisterAddonPanel('Restacker_SETTINGS', panelData)

  createEventsSectionData()
  createOutputData()
  createAddonSupportData();

  lam:RegisterOptionControls("Restacker_SETTINGS", optionsTable)
end

-- globals
Restacker.createSettingsWindow = createSettingsWindow