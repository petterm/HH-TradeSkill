local addonName = ...
local TS = LibStub("AceAddon-3.0"):NewAddon(
    addonName,
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceComm-3.0",
    "AceTimer-3.0",
    "AceSerializer-3.0"
)

local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
TS.L = L

TS.version = GetAddOnMetadata(addonName, "Version")
TS.commPrefix = 'HHTS'
TS.M = { -- Comm message types
    LOGIN_UPDATE = 'LOGIN_UPD_01',
    LOGIN_RESPONSE = 'LOGIN_RES_01',
    VERSION_QUERY = 'VER_QUERY_01',
    VERSION_RESPONSE = 'VER_RES_01',
    FULL_DB_REQUEST = 'DB_REQ_01',
    FULL_DB_RESPONSE = 'DB_RES_01',
    RECIPE_UPDATE = 'RECIPE_UPD_01',
}

local function colorYellow(string)
    return "|cffebd634"..(string or "nil").."|r"
end

local function colorBlue(string)
    return "|cff39c6ed"..(string or "nil").."|r"
end

local function colorRed(string)
    return "|cffed5139"..(string or 'nil').."|r"
end

local function filterCharacter(db, character)
    wipe(db[character])
    return db
end

local defaults = {
    profile = {
        debugPrint = false,
        printSyncRequests = false,
        disableSyncInRaid = true,
        lastGuildBroadcast = 0,
        guildBroadcastThrottle = 60*10,
        clearCharacter = 'EMPTY',
    },
    realm = {
        dbVersion = nil,
        localDB = {},
        sharedDB = {},
    },
}

local optionsTable = {
    type='group',
    name = "Held Hostile TradeSkill",
    desc = "Shared trade skill recipe database",
    args = {
        general = {
            type='group',
            name = "General",
            order = 1,
            args = {
                setCharacter = {
                    type = "select",
                    name = "Select the character to remove",
                    values = function() return select(1, TS:GetSharedDBCharacters()) end,
                    sorting = function() return select(2, TS:GetSharedDBCharacters()) end,
                    set = function(_, character) TS.db.profile.clearCharacter = character end,
                    get = function() return TS.db.profile.clearCharacter end,
                    order = 1,
                    width = 1.18,
                },
                clearCharacter = {
                    type = "execute",
                    name = "Clear character",
                    func = function()
                        local character = TS.db.profile.clearCharacter
                        if character ~= 'EMPTY' then
                            TS.db.realm.localDB = filterCharacter(TS.db.realm.localDB, character)
                            TS.db.realm.sharedDB = filterCharacter(TS.db.realm.sharedDB, character)
                            TS.db.profile.clearCharacter = nil
                            TS:Print("Data for character "..character.." removed.")
                        end
                    end,
                    order = 2,
                    width = 1.18,
                },
                clearLocal = {
                    type = "execute",
                    name = "Clear local data",
                    func = function()
                        wipe(TS.db.realm.localDB)
                        wipe(TS.db.realm.sharedDB)
                        TS:Print("Local data removed.")
                    end,
                    order = 3,
                    width = "full",
                },
                disableSyncInRaid = {
                    type = "toggle",
                    name = "Disable sync when in a raid",
                    desc = "...",
                    get = function() return TS.db.profile.disableSyncInRaid end,
                    set = function(_, v) TS.db.profile.disableSyncInRaid = v end,
                    order = 4,
                    width = "full",
                },
                requestFullSync = {
                    type = "input",
                    name = "Request full db sync",
                    desc = "Request the full shared db from a player.",
                    usage = "player",
                    set = function(_, player)
                        TS:SendRequestFull(player)
                    end,
                    order = 7,
                    width = "full",
                },
            },
        },
        debug = {
            type='group',
            name = "Debug",
            order = 3,
            args = {
                versionRequest = {
                    type = "execute",
                    name = "Request version information from guild members",
                    func = function()
                        TS:SendVersionRequest()
                    end,
                    order = 1,
                    width = "full",
                },
                toggleSyncLog = {
                    type = "toggle",
                    name = "Enable sync messages",
                    desc = "...",
                    get = function() return TS.db.profile.printSyncRequests end,
                    set = function(_, v) TS.db.profile.printSyncRequests = v end,
                    order = 2,
                    width = "full",
                },
                printDebug = {
                    type = "toggle",
                    name = "Enable debug messages",
                    desc = "...",
                    get = function() return TS.db.profile.debugPrint end,
                    set = function(_, v) TS.db.profile.debugPrint = v end,
                    order = 3,
                    width = "full",
                },
                testSendWhisper = {
                    type = "input",
                    name = "Test send whisper",
                    desc = "Test sending local db in whisper to player",
                    usage = "player",
                    set = function(_, player)
                        TS:SendLocalDB(TS.M.LOGIN_RESPONSE, 'WHISPER', player)
                    end,
                    order = 5,
                    width = "full",
                },
                testSendGuild = {
                    type = "input",
                    name = "Test send guild",
                    desc = "Test sending local db to guild",
                    set = function()
                        TS:SendLocalDB(TS.M.LOGIN_UPDATE, 'GUILD')
                    end,
                    order = 6,
                    width = "full",
                },
            },
        },
    }
}


local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
AceConfig:RegisterOptionsTable(addonName, optionsTable, { "hhts" })
AceConfigDialog:AddToBlizOptions(addonName, "HH TradeSkill")


--[[========================================================
                        SETUP
========================================================]]--

local function GetConvertedDB(db)
    local newDb = {}
    for id, characters in pairs(db) do
        for name, class in pairs(characters) do
            local character = name..':'..class
            if newDb[character] == nil then newDb[character] = {} end
            newDb[character][id] = true
        end
    end
    return newDb
end


function TS:OnInitialize()
    TS:RegisterEvent("TRADE_SKILL_UPDATE", "TradeSkillEvent")
    TS:RegisterEvent("CRAFT_UPDATE", "TradeSkillEvent")

    TS.db = LibStub("AceDB-3.0"):New("HHTradeSkillDB", defaults)
    if TS.db.realm.dbVersion == nil or TS.db.realm.dbVersion < '1.1.0' then
        -- Old database
        TS:DPrint('Database version:', TS.db.realm.dbVersion, 'Addon version:', TS.version)
        TS:DPrint('Clearing sharedDB and localDB..')

        -- Update DB
        local newSharedDb = GetConvertedDB(TS.db.realm.sharedDB)
        wipe(TS.db.realm.sharedDB)
        TS.db.realm.sharedDB = newSharedDb
        local newLocalDb = GetConvertedDB(TS.db.realm.localDB)
        wipe(TS.db.realm.localDB)
        TS.db.realm.localDB = newLocalDb

        TS.db.realm.localNumTradeSkills = nil
        TS.db.profile.printSyncRequests = false
    end
    TS.db.realm.dbVersion = TS.version

    TS:RegisterComm(TS.commPrefix, 'OnCommMessage')

    -- Schedule sending guild update 1 min after login
    TS:ScheduleTimer(function()
        if IsInGuild() then
            TS:SendLocalDB(TS.M.LOGIN_UPDATE, 'GUILD')
        end
    end, 60)
end


function TS:DPrint(...)
    if TS.db.profile.debugPrint then
        TS:Print(...)
    end
end


function TS:Dump(...)
    if TS.db.profile.debugPrint then
        DevTools_Dump(...)
    end
end


--[[========================================================
                        Events
========================================================]]--


function TS:LogEvent(eventName)
    TS:DPrint(colorRed(eventName))
    -- local profession = GetTradeSkillLine() -- This is the localized name..

    -- -- Enchanting and Beast Training has a different UI..
    -- if profession == "UNKNOWN" then
    --     profession = GetCraftDisplaySkillLine() or "UNKNOWN"
    -- end

    -- TS:DPrint(colorRed(eventName), profession)
end


function TS:OnCommMessage(prefix, message, channel, sender)
    TS:DPrint(colorYellow('OnCommMessage'), prefix, channel, sender)
    if IsInRaid() and TS.db.profile.disableSyncInRaid then return end
    if sender == UnitName('player') then return end

    local success, data = TS:Deserialize(message)
    if success then
        TS:DPrint('- ', colorYellow('type:'), data.t, colorYellow('version:'), data.v)
        TS:VersionCheck(data.v, sender)

        if data.t == TS.M.VERSION_QUERY then
            TS:SendVersionResponse(sender)
            return
        end

        if data.t == TS.M.VERSION_RESPONSE then
            TS:PrintVersionResponse(data.v, sender)
            return
        end

        if data.t == TS.M.LOGIN_UPDATE then
            TS:UpdateSharedDB(data.db)
            TS:SendLocalDB(TS.M.LOGIN_RESPONSE, 'WHISPER', sender)
            return
        end

        if
            data.t == TS.M.LOGIN_RESPONSE or
            data.t == TS.M.RECIPE_UPDATE
        then
            TS:UpdateSharedDB(data.db)
            return
        end

        if data.t == TS.M.FULL_DB_REQUEST then
            TS:SendSharedDB(TS.M.FULL_DB_RESPONSE, sender)
            return
        end

        if data.t == TS.M.FULL_DB_RESPONSE then
            TS:UpdateSharedDB(data.db)
            return
        end

        TS:DPrint(colorRed('Unknown message!'))
    else
        TS:DPrint(colorRed('Serialization falied!'))
    end
end


--[[========================================================
                        Data
========================================================]]--


local function PackDB(db)
    local response = {}
    for character, idMap in pairs(db) do
        response[character] = {}
        for id, _ in pairs(idMap) do
            tinsert(response[character], id)
        end
    end
    return response
end


local function GetIdFromLink(link)
    if link ~= nil then
        local found, _, id = string.find(link, "^|c%x+|H([^:]+:[^:]+).*|h%[.*%]")
        if found then
            -- Seems enchants are called spells everywhere else..
            id = gsub(id, 'enchant', 'spell')
            return id
        end
    end
    return nil
end


function TS:TradeSkillEvent()
    local profession = GetTradeSkillLine() -- This is the localized name

    -- Enchanting and Beast Training has a different UI..
    if profession == "UNKNOWN" then
        profession = GetCraftDisplaySkillLine() or "UNKNOWN"
    end

    TS:UpdateLocalProfession(profession)
end


function TS:UpdateLocalProfession(profession)
    local character = TS:GetCurrentCharacter()

    if not TS:IsValidProfession(profession) then
        TS:DPrint(colorBlue('UpdateLocalProfession'), 'Invalid profession', profession)
        return
    end

    local GetNumTradeSkills = GetNumTradeSkills
    local GetTradeSkillInfo = GetTradeSkillInfo
    local GetTradeSkillItemLink = GetTradeSkillItemLink

    -- Enchanting uses the old Crafting UI
    if TS:ProfIsEnchanting(profession) then
        GetNumTradeSkills = GetNumCrafts
        GetTradeSkillItemLink = GetCraftItemLink
        GetTradeSkillInfo = function(i)
            local name, _, kind, num = GetCraftInfo(i)
            return name, kind, num
        end
    end

    TS:DPrint(colorBlue('UpdateLocalProfession'), 'Updating local profession data', colorYellow(profession))

    local newEntries = {}

    for i = 1,  GetNumTradeSkills() do
        local itemName, kind = GetTradeSkillInfo(i)
        if kind ~= nil and kind ~= 'header' and kind ~= 'subheader' then
            local link = GetTradeSkillItemLink(i)
            local id = GetIdFromLink(link)

            -- Local DB
            if TS.db.realm.localDB[character] == nil then
                TS.db.realm.localDB[character] = {}
            end
            if TS.db.realm.localDB[character][id] == nil then
                TS:DPrint(colorBlue(itemName), colorYellow(id), kind)
                TS.db.realm.localDB[character][id] = true
                tinsert(newEntries, id)
            end

            -- Shared DB
            if TS.db.realm.sharedDB[character] == nil then
                TS.db.realm.sharedDB[character] = {}
            end
            if TS.db.realm.sharedDB[character][id] == nil then
                TS.db.realm.sharedDB[character][id] = true
            end
        end
    end

    -- Broadcast new entries
    if getn(newEntries) > 0 then
        TS:SendLocalUpdates(newEntries, 'GUILD')
    end
end


function TS:ProfIsEnchanting(profession)
    return profession == TS.L['ENCHANTING']
end


function TS:IsValidProfession(profession)
    local validProfs = {
        'ALCHEMY',
        'BLACKSMITHING',
        'COOKING',
        'ENCHANTING',
        'ENGINEERING',
        'JEWELCRAFTING',
        'LEATHERWORKING',
        'TAILORING',
    }
    for _, profKey in ipairs(validProfs) do
        if profession == TS.L[profKey] then
            return true
        end
    end

    return false
end


function TS:UpdateSharedDB(packedDB)
    if TS.db.realm.sharedDB == nil then
        TS.db.realm.sharedDB = {}
    end

    local updates = 0
    for character, idList in ipairs(packedDB) do
        if TS.db.realm.sharedDB[character] == nil then
            TS.db.realm.sharedDB[character] = {}
        end
        for _, id in ipairs(idList) do
            if TS.db.realm.sharedDB[character][id] == nil then
                TS.db.realm.sharedDB[character][id] = true
                updates = updates + 1
            end
        end
    end
    TS:DPrint(colorYellow('UpdateSharedDB'), updates, 'entries updated')
end


function TS:GetSharedDBCharacters()
    local characters = {
        ['EMPTY'] = '- Select -'
    }
    local sortedKeys = {}
    for character, _ in pairs(TS.db.realm.sharedDB) do
        if characters[character] == nil then
            characters[character] = TS:GetCharName(character)
            tinsert(sortedKeys, character)
        end
    end
    sort(sortedKeys)
    tinsert(sortedKeys, 1, 'EMPTY')
    return characters, sortedKeys
end


function TS:GetCharName(character)
    return strmatch(character, '([^:]+)')
end


function TS:GetCharClass(character)
    return strmatch(character, ':([^:]+)')
end


function TS:GetCurrentCharacter()
    local character = UnitName('player')
    local _, class = UnitClass('player')
    return character..':'..class
end


local versionAnnounced = nil
function TS:VersionCheck(version, sender)
    if version and version > TS.version and (versionAnnounced == nil or version > versionAnnounced) then
        TS:Print(colorYellow('New version available!'), 'v'..version, sender)
        versionAnnounced = version
    end
end


function TS:PrintVersionResponse(version, sender)
    TS:Print('v'..version, sender)
end


--[[========================================================
                    Communication
========================================================]]--


function TS:SendLocalDB(messageType, channel, channelTarget)
    if IsInRaid() and TS.db.profile.disableSyncInRaid then return end
    if time() < TS.db.profile.lastGuildBroadcast + TS.db.profile.guildBroadcastThrottle then return end

    if TS.db.profile.printSyncRequests then
        TS:Print('Sent local data to', channel, channelTarget or '')
    else
        TS:DPrint(colorYellow('SendLocalDB'), channel, channelTarget)
    end

    local payload = {
        t = messageType,
        v = TS.version,
        db = PackDB(TS.db.realm.localDB),
    }

    local serializedPayload = TS:Serialize(payload)

    TS:SendCommMessage(
        TS.commPrefix,
        serializedPayload,
        channel,
        channelTarget
    )

    if channel == 'GUILD' then
        TS.db.profile.lastGuildBroadcast = time()
    end
end


function TS:SendLocalUpdates(idList, channel, channelTarget)
    if IsInRaid() and TS.db.profile.disableSyncInRaid then return end

    if TS.db.profile.printSyncRequests then
        TS:Print('Sent local updates to', channel, channelTarget or '')
    else
        TS:DPrint(colorYellow('SendLocalUpdates'), channel, channelTarget)
    end

    local payload = {
        t = TS.M.RECIPE_UPDATE,
        v = TS.version,
        db = {
            [TS:GetCurrentCharacter()] = idList,
        }
    }

    local serializedPayload = TS:Serialize(payload)

    TS:SendCommMessage(
        TS.commPrefix,
        serializedPayload,
        channel,
        channelTarget
    )
end


function TS:SendSharedDB(messageType, target)
    if IsInRaid() and TS.db.profile.disableSyncInRaid then return end

    if TS.db.profile.printSyncRequests then
        TS:Print('Sent full database to', target)
    else
        TS:DPrint(colorYellow('SendSharedDB'), 'WHISPER', target)
    end

    local payload = {
        t = messageType,
        v = TS.version,
        db = PackDB(TS.db.realm.sharedDB),
    }

    local serializedPayload = TS:Serialize(payload)

    TS:SendCommMessage(
        TS.commPrefix,
        serializedPayload,
        'WHISPER',
        target
    )
end


function TS:SendRequestFull(target)
    if IsInRaid() and TS.db.profile.disableSyncInRaid then return end

    if TS.db.profile.printSyncRequests then
        TS:Print('Sent request for full database to', target)
    else
        TS:DPrint(colorYellow('SendRequestFull'), 'WHISPER', target)
    end

    local payload = {
        t = TS.M.FULL_DB_REQUEST,
        v = TS.version,
    }

    local serializedPayload = TS:Serialize(payload)

    TS:SendCommMessage(
        TS.commPrefix,
        serializedPayload,
        'WHISPER',
        target
    )
end


function TS:SendVersionRequest()
    local payload = {
        t = TS.M.VERSION_QUERY,
        v = TS.version,
    }

    local serializedPayload = TS:Serialize(payload)

    TS:Print('Requesting version information from guild..')
    TS:SendCommMessage(
        TS.commPrefix,
        serializedPayload,
        'GUILD'
    )
end


function TS:SendVersionResponse(target)
    local payload = {
        t = TS.M.VERSION_RESPONSE,
        v = TS.version,
    }

    local serializedPayload = TS:Serialize(payload)

    TS:SendCommMessage(
        TS.commPrefix,
        serializedPayload,
        'WHISPER',
        target
    )
end


--[[========================================================
                    Tooltip
========================================================]]--


local function ClassColor(text, class)
    if RAID_CLASS_COLORS[class] ~= nil then
        return strconcat('|c', RAID_CLASS_COLORS[class].colorStr, text, '|r')
    end
    return text
end


local makerLimit = 5
function TS:AddMakersToTooltip(tt, id)
    -- TS:DPrint(colorYellow('AddMakersToTooltip'), id)
    local makers = nil
    local count = 0
    for character, ids in pairs(TS.db.realm.sharedDB) do
        if ids[id] then
            if count < makerLimit or IsModifierKeyDown() then
                local name = TS:GetCharName(character)
                local class = TS:GetCharClass(character)
                if makers == nil then
                    makers = ClassColor(name, class)
                else
                    makers = makers .. ', ' .. ClassColor(name, class)
                end
            end
            count = count + 1
        end
    end

    if count > makerLimit and not IsModifierKeyDown() then
        makers = makers .. ' (+'..count-makerLimit..')'
    end

    if makers ~= nil then
        tt:AddLine('Craftable by:', 1, 0.5, 0)
        tt:AddLine(makers, 1, 1, 1, 1)

        tt:Show()
    end
end


hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
    local id = string.match(link, "(item:%d*)")
    if id then
        TS:AddMakersToTooltip(self, id)
    end
end)


GameTooltip:HookScript("OnTooltipSetItem", function(self)
    local link = select(2, self:GetItem())
    -- TS:DPrint(link)
    if link then
        local id = string.match(link, "(item:%d*)")
        if id then
            -- Look for id in database
            -- Add line with players for this item
            TS:AddMakersToTooltip(self, id)
        end
    end
end)


GameTooltip:HookScript("OnTooltipSetSpell", function(self)
    -- TS:DPrint('OnTooltipSetSpell')
    local id = select(2, self:GetSpell())
    if id then
        -- Look for id in database
        -- Add line with players for this item
        TS:AddMakersToTooltip(self, 'spell:'..id)
    end
end)

