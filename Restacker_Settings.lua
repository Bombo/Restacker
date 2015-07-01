local lam = LibStub:GetLibrary("LibAddonMenu-2.0")

local function addField(field)

end

local function createDescriptionData(text)
    return {
        type = "description",
        title = nil,
        text = text,
        width = "full"
    }
end

local function createCheckboxData(name, tooltip, getFunc, setFunc)
    return {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        getFunc = getFunc,
        setFunc = setFunc,
        width = "full"
    }
end

local function createEventsSectionData(optionsTable)
    local propIndex = index
    optionsTable[propIndex] = {
        type = "header",
        name = "Events",
        width = "full"
    }

    optionsTable[propIndex + 1] = createDescriptionData('Set the events to trigger restacking.')
    optionsTable[propIndex + 2] =
end

function Restacker.CreateSettingsWindow(savedVariables)

    local panelData = {
        type = 'panel',
        name = 'Restacker'
    }
    lam:RegisterAddonPanel('Restacker_SETTINGS', panelData)

    local optionsTable = {}

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