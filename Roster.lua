-- Roster.lua: who is in the guild and who is online, from the guild roster.
--
-- Members are known by GUID. Addon messages only carry the sender's name
-- (WoW Forever gives "Alice Smith", with a space and no realm; other
-- clients add "-Realm"), and the roster gives names without a realm, so a
-- sender is matched to the roster by the name before any realm. A name two
-- members share is not trusted.
local _, ns = ...

local Roster = {}
ns.Roster = Roster

Roster.guildKey = nil  -- the current guild's name
Roster.members = {}    -- [GUID] = { name = roster name, online = bool, class = "MAGE" }
Roster.ready = false   -- the whole roster has been read at least once
Roster.total = 0

local REQUEST_INTERVAL = 10       -- the server ignores roster requests closer than this
local REFRESH_INTERVAL = 120
local FLAG_REQUEST_INTERVAL = 30  -- at most this often when the server says there is news
local lastRequest = -REQUEST_INTERVAL

local byName = {}  -- [name without realm] = GUID, or false when two members share it

function Roster.Request()
    if GetTime() - lastRequest < REQUEST_INTERVAL then
        return
    end
    lastRequest = GetTime()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

-- "Name-Realm" or "Name" -> "Name".
function Roster.BaseName(name)
    return name:match("^([^%-]+)") or name
end

-- The GUID of the member who sent an addon message, if the roster knows them.
function Roster.GUIDOfSender(sender)
    if type(sender) ~= "string" then
        return nil
    end
    return byName[sender] or byName[Roster.BaseName(sender)] or nil
end

-- Until the whole roster is known, everyone counts as a member (and as online).
function Roster.IsKnownSender(sender)
    return not Roster.ready or Roster.GUIDOfSender(sender) ~= nil
end

function Roster.IsKnownGUID(guid)
    return not Roster.ready or Roster.members[guid] ~= nil
end

function Roster.IsOnline(guid)
    local member = Roster.members[guid]
    if not member then
        return not Roster.ready
    end
    return member.online
end

function Roster.NameOf(guid)
    local member = guid and Roster.members[guid]
    return member and member.name
end

function Roster.OnlineCount()
    local count = 0
    for _, member in pairs(Roster.members) do
        if member.online then
            count = count + 1
        end
    end
    return count
end

local function UpdateGuildKey()
    local key
    if IsInGuild() then
        key = ns.Plain((GetGuildInfo("player")))
        if not key then
            -- Not loaded yet: keep what we had until it is.
            return Roster.guildKey ~= nil
        end
    end
    if key ~= Roster.guildKey then
        Roster.guildKey = key
        Roster.ready = false
        Roster.members, Roster.total = {}, 0
        byName = {}
        ns.Debug("guild: %s", tostring(key))
        ns.Fire("GuildChanged", key)
    end
    return key ~= nil
end

local function Read()
    if not UpdateGuildKey() then
        return
    end
    local total = ns.Plain((GetNumGuildMembers())) or 0
    if total == 0 and Roster.ready then
        -- Not loaded (or not readable right now): keep the last read.
        return
    end
    local members, names = {}, {}
    local complete = total > 0
    for i = 1, total do
        local name, _, _, _, _, _, _, _, online, _, class, _, _, isMobile, _, _, guid = GetGuildRosterInfo(i)
        name, guid = ns.Plain(name), ns.Plain(guid)
        if type(name) == "string" and ns.Data.IsGUID(guid) then
            members[guid] = {
                name = name,
                online = ns.Plain(online) == true and ns.Plain(isMobile) ~= true,
                class = ns.Plain(class),
            }
            for _, key in ipairs({ name, Roster.BaseName(name) }) do
                if names[key] == nil then
                    names[key] = guid
                elseif names[key] ~= guid then
                    names[key] = false
                end
            end
        else
            complete = false
        end
    end
    if total > 0 and not complete and Roster.ready then
        -- A partial read (data still arriving): keep the last complete one.
        return
    end
    Roster.members, Roster.total = members, total
    byName = names
    -- The roster spells our own name best (see ns.SetPlayerName).
    local me = ns.playerGUID and members[ns.playerGUID]
    if me and Roster.BaseName(me.name) ~= ns.playerName then
        ns.SetPlayerName(Roster.BaseName(me.name))
        ns.Debug("our name: %s", ns.playerName)
    end
    if complete then
        Roster.ready = true
        ns.Data.Prune(Roster.guildKey, members)
    end
    ns.Data.ForgetDigests()
    ns.Fire("RosterUpdated")
end

function Roster.Init()
    local events = CreateFrame("Frame")
    ns.RegisterEvents(events, "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE")
    events:SetScript("OnEvent", function(_, event, canRequest)
        if event == "PLAYER_GUILD_UPDATE" then
            UpdateGuildKey()
            Roster.Request()
        elseif ns.Plain(canRequest) == true and GetTime() - lastRequest >= FLAG_REQUEST_INTERVAL then
            -- The server has newer roster data (members logging in or out)
            -- to give on request; Blizzard's guild window asks for it too.
            Roster.Request()
        end
        ns.Debounce("RosterRead", 0.5, Read)
    end)
    UpdateGuildKey()
    Roster.Request()
    C_Timer.NewTicker(REFRESH_INTERVAL, function()
        if IsInGuild() then
            Roster.Request()
        end
    end)
end
