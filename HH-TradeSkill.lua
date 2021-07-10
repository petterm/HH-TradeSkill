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
local COMM_UPDATE = strjoin('_', TS.commPrefix, 'UPD')
local COMM_UPDATE_FULL = strjoin('_', TS.commPrefix, 'UPD_FULL')
local COMM_REQUEST_FULL = strjoin('_', TS.commPrefix, 'REQ_FULL')


local function colorYellow(string)
    return "|cffebd634"..(string or "nil").."|r"
end

local function colorBlue(string)
    return "|cff39c6ed"..(string or "nil").."|r"
end

local function colorRed(string)
    return "|cffed5139"..string.."|r"
end


local defaults = {
    profile = {
        debugPrint = false,
        printSyncRequests = true,
        disableSyncInRaid = true,
        lastGuildBroadcast = 0,
        guildBroadcastThrottle = 60*15,
    },
    realm = {
        localNumTradeSkills = {},
        localDB = {},
        sharedDB = {},
    },
}

local optionsTable = {
    type='group',
    name = "Held Hostile TradeSkill",
    desc = "Shared trade skill recipe database",
    args = {
        clearLocal = {
            type = "execute",
            name = "Clear local data",
            func = function()
                TS.db.realm.localNumTradeSkills = {}
                TS.db.realm.localDB = {}
                TS.db.realm.sharedDB = {}
                TS.db.realm.localCharacterCache = nil
                TS:Print("Local data removed.")
            end,
            order = 1,
            width = "full",
        },
        disableSyncInRaid = {
            type = "toggle",
            name = "Disable sync when in a raid",
            desc = "...",
            get = function() return TS.db.profile.disableSyncInRaid end,
            set = function(_, v) TS.db.profile.disableSyncInRaid = v end,
            order = 2,
            width = "full",
        },
        debug = {
            type='group',
            name = "Debug",
            order = 3,
            args = {
                toggleSyncLog = {
                    type = "toggle",
                    name = "Enable sync messages",
                    desc = "...",
                    get = function() return TS.db.profile.printSyncRequests end,
                    set = function(_, v) TS.db.profile.printSyncRequests = v end,
                    order = 1,
                    width = "full",
                },
                print = {
                    type = "toggle",
                    name = "Enable debug messages",
                    desc = "...",
                    get = function() return TS.db.profile.debugPrint end,
                    set = function(_, v) TS.db.profile.debugPrint = v end,
                    order = 1,
                    width = "full",
                },
                testSendWhisper = {
                    type = "input",
                    name = "Test send whisper",
                    desc = "Test sending local db in whisper to player",
                    usage = "player",
                    set = function(_, player)
                        TS:SendLocalDB('WHISPER', player)
                    end,
                    order = 5,
                    width = "full",
                },
                testSendGuild = {
                    type = "input",
                    name = "Test send guild",
                    desc = "Test sending local db to guild",
                    set = function()
                        TS:SendLocalDB('GUILD')
                    end,
                    order = 6,
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
    }
}


local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
AceConfig:RegisterOptionsTable(addonName, optionsTable, { "hhts" })
AceConfigDialog:AddToBlizOptions(addonName, "HH TradeSkill")


--[[========================================================
                        SETUP
========================================================]]--


function TS:OnInitialize()
    -- Classic and retail
    self:RegisterEvent("TRADE_SKILL_SHOW", "LogEvent")
    self:RegisterEvent("TRADE_SKILL_CLOSE", "LogEvent")
    self:RegisterEvent("TRADE_SKILL_UPDATE", "TradeSkillEvent")

    -- Classic only
    self:RegisterEvent("CRAFT_SHOW", "LogEvent")
    self:RegisterEvent("CRAFT_CLOSE", "LogEvent")
    self:RegisterEvent("CRAFT_UPDATE", "TradeSkillEvent")

    -- Classic and retail
    self:RegisterEvent("TRADE_SKILL_LIST_UPDATE", "LogEvent")
    self:RegisterEvent("TRADE_SKILL_NAME_UPDATE", "LogEvent")
    self:RegisterEvent("TRADE_SKILL_DETAILS_UPDATE", "LogEvent")

    self.db = LibStub("AceDB-3.0"):New("HHTradeSkillDB", defaults)

    self:RegisterComm(COMM_UPDATE, 'OnCommUpdate')
    self:RegisterComm(COMM_UPDATE_FULL, 'OnCommUpdateFull')
    self:RegisterComm(COMM_REQUEST_FULL, 'OnCommRequestFull')

    -- Schedule sending guild update 1 min after login
    self:ScheduleTimer(function()
        if IsInGuild() then
            TS:SendLocalDB('GUILD')
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
    local profession = GetTradeSkillLine() -- This is the localized name..

    -- Enchanting and Beast Training has a different UI..
    if profession == "UNKNOWN" then
        profession = GetCraftDisplaySkillLine() or "UNKNOWN"
    end

    TS:DPrint(colorRed(eventName), profession)
end


function TS:OnCommUpdate(prefix, message, channel, sender)
    if IsInRaid() and TS.db.profile.disableSyncInRaid then return end
    if channel == 'GUILD' and sender == UnitName('player') then return end

    TS:DPrint(colorYellow('OnCommUpdate'), prefix, channel, sender)
    local success, data = TS:Deserialize(message)
    if success then
        TS:Dump(data)
        TS:UpdateSharedDB(data.db, data.character, data.class)
    else
        TS:DPrint(colorRed('Serialization falied!'))
    end
end


function TS:OnCommUpdateFull(prefix, message, channel, sender)
    if IsInRaid() and TS.db.profile.disableSyncInRaid then return end
    if channel == 'GUILD' and sender == UnitName('player') then return end

    TS:DPrint(colorYellow('OnCommUpdate'), prefix, channel, sender)
    local success, data = TS:Deserialize(message)
    if success then
        TS:DPrint(getn(data), 'rows received')
        TS:MergeSharedDB(data)
    else
        TS:DPrint(colorRed('Serialization falied!'))
    end
end


function TS:OnCommRequestFull(prefix, message, channel, sender)
    if IsInRaid() and TS.db.profile.disableSyncInRaid then return end

    TS:DPrint(colorYellow('OnCommRequestFull'), prefix, channel, sender)
    TS:SendSharedDB('WHISPER', sender)
end


--[[========================================================
                        Data
========================================================]]--


local function GetIdFromLink(link)
    if link ~= nil then
        local found, _, id = string.find(link, "^|c%x+|H([^:]+:[^:]+).*|h%[.*%]")
        if found then
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
    local character = UnitName('player')

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

    if TS.db.realm.localNumTradeSkills[character] == nil then
        TS.db.realm.localNumTradeSkills[character] = {}
    end

    local numTradeSkills = GetNumTradeSkills()
    if TS.db.realm.localNumTradeSkills[character][profession] == nil or
        TS.db.realm.localNumTradeSkills[character][profession] < numTradeSkills
    then
        TS:DPrint(colorBlue('UpdateLocalProfession'), 'Updating local profession data', colorYellow(profession))

        local newEntries = {}

        for i = 1, numTradeSkills do
            local itemName, kind = GetTradeSkillInfo(i)
            if kind ~= nil and kind ~= 'header' and kind ~= 'subheader' then
                local link = GetTradeSkillItemLink(i)
                local id = GetIdFromLink(link)
                TS:DPrint(colorBlue(itemName), colorYellow(id), kind)

                -- Local DB
                if TS.db.realm.localDB[id] == nil then
                    TS.db.realm.localDB[id] = {}
                end
                local _, class = UnitClass('player')
                if TS.db.realm.localDB[id][character] == nil then
                    TS.db.realm.localDB[id][character] = class
                    tinsert(newEntries, id)
                end

                -- Shared DB
                if TS.db.realm.sharedDB[id] == nil then
                    TS.db.realm.sharedDB[id] = {}
                end
                if TS.db.realm.sharedDB[id][character] == nil then
                    TS.db.realm.sharedDB[id][character] = class
                end
            end
        end

        -- Broadcast new entries
        if getn(newEntries) > 0 then
            TS:SendLocalUpdates(newEntries, 'GUILD')
        end

        TS.db.realm.localNumTradeSkills[character][profession] = numTradeSkills
    else
        TS:DPrint(colorBlue('UpdateLocalProfession'), 'Skipping update. No change detected.')
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


function TS:UpdateSharedDB(data, character, class)
    if TS.db.realm.sharedDB == nil then
        TS.db.realm.sharedDB = {}
    end

    local updates = 0
    for _, id in ipairs(data) do
        if TS.db.realm.sharedDB[id] == nil then
            TS.db.realm.sharedDB[id] = {}
        end
        if TS.db.realm.sharedDB[id][character] == nil then
            TS.db.realm.sharedDB[id][character] = class
            updates = updates + 1
        end
    end
    TS:DPrint(colorYellow('UpdateSharedDB'), updates, 'entries updated')
end


function TS:MergeSharedDB(data)
    if TS.db.realm.sharedDB == nil then
        TS.db.realm.sharedDB = data
        return
    end

    local updates = 0
    for id, characters in pairs(data) do
        if TS.db.realm.sharedDB[id] == nil then
            TS.db.realm.sharedDB[id] = {}
        end
        for character, class in ipairs(characters) do
            if TS.db.realm.sharedDB[id][character] == nil then
                TS.db.realm.sharedDB[id][character] = class
                updates = updates + 1
            end
        end
    end
end


--[[========================================================
                    Communication
========================================================]]--


function TS:SendLocalDB(channel, channelTarget)
    if IsInRaid() and TS.db.profile.disableSyncInRaid then return end
    if time() < TS.db.profile.lastGuildBroadcast + TS.db.profile.guildBroadcastThrottle then return end

    TS:DPrint(colorYellow('SendLocalDB'), channel, channelTarget)
    local character = UnitName('player')
    local _, class = UnitClass('player')
    local payload = {
        character = character,
        class = class,
        db = {},
    }

    for key, value in pairs(TS.db.realm.localDB) do
        if value[character] ~= nil then
            tinsert(payload.db, key)
        end
    end

    local serializedPayload = TS:Serialize(payload)
    -- TS:Dump(serializedPayload)

    TS:SendCommMessage(
        COMM_UPDATE,
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

    TS:DPrint(colorYellow('SendLocalUpdates'), channel, channelTarget)
    local character = UnitName('player')
    local _, class = UnitClass('player')
    local payload = {
        character = character,
        class = class,
        db = idList,
    }

    local serializedPayload = TS:Serialize(payload)

    TS:SendCommMessage(
        COMM_UPDATE,
        serializedPayload,
        channel,
        channelTarget
    )
end


function TS:SendSharedDB(channel, channelTarget)
    if channel ~= 'WHISPER' then return end

    TS:DPrint(colorYellow('SendSharedDB'), channel, channelTarget)
    local serializedPayload = TS:Serialize(TS.db.realm.sharedDB)
    TS:SendCommMessage(
        COMM_UPDATE_FULL,
        serializedPayload,
        channel,
        channelTarget
    )
end


function TS:SendRequestFull(channelTarget)
    TS:SendCommMessage(
        COMM_REQUEST_FULL,
        '',
        'WHISPER',
        channelTarget
    )
end
