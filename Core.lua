-- Guild Professions & Recipes: shows the professions and recipes of every guild member.
-- Core.lua holds the shared helpers, the startup and the slash commands.
local ADDON_NAME, ns = ...
local L = ns.L

ns.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
ns.PREFIX = "GuildProfRecipes"

-- "1.2.3" -> 10203. Records carry it so a newer client in the guild is noticed.
function ns.VersionNumber(version)
    local major, minor, patch = tostring(version):match("^(%d+)%.(%d+)%.?(%d*)")
    if not major then
        return 0
    end
    return tonumber(major) * 10000 + tonumber(minor) * 100 + (tonumber(patch) or 0)
end

function ns.VersionString(number)
    return ("%d.%d.%d"):format(math.floor(number / 10000), math.floor(number / 100) % 100, number % 100)
end

ns.VERSION_NUM = ns.VersionNumber(ns.VERSION)

-- WoW Forever runs the Midnight addon API, where some results are "secret":
-- using one in a condition, or even comparing it with nil, raises an error.
-- Anything that might be secret goes through Plain() before it is looked at.
local issecretvalue = issecretvalue or function() return false end

function ns.Plain(value)
    if issecretvalue(value) then
        return nil
    end
    return value
end

-- Tables from the API can be secret as a whole during a lockdown, and
-- reading their fields then raises.
local canaccesstable = canaccesstable

function ns.CanRead(tbl)
    if type(tbl) ~= "table" then
        return false
    end
    -- Called directly: it answers for the function that calls it.
    return not canaccesstable or canaccesstable(tbl) ~= false
end

function ns.Print(message, ...)
    if select("#", ...) > 0 then
        message = message:format(...)
    end
    print("|cff33ccffGuild Professions & Recipes|r: " .. message)
end

-- RegisterEvent raises for an event this client does not have, which would
-- abort the rest of the file, so every registration is wrapped.
function ns.RegisterEvents(frame, ...)
    for i = 1, select("#", ...) do
        pcall(frame.RegisterEvent, frame, (select(i, ...)))
    end
end

-- Calls fn, returning nothing instead of raising when the client lacks it or
-- it fails. For the undocumented API the addon cannot be sure of.
function ns.Try(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local results = { pcall(fn, ...) }
    if not results[1] then
        ns.Debug("call failed: %s", tostring(results[2]))
        return nil
    end
    return unpack(results, 2, table.maxn(results))
end

function ns.Now()
    return GetServerTime()
end

-- Debug log: kept in memory only, printed while /grecipes debug is on.
ns.debugLog = {}

function ns.Debug(message, ...)
    if select("#", ...) > 0 then
        local ok, text = pcall(string.format, message, ...)
        message = ok and text or message
    end
    local line = date("%H:%M:%S ") .. message
    local log = ns.debugLog
    log[#log + 1] = line
    if #log > 300 then
        table.remove(log, 1)
    end
    if ns.debugEnabled then
        print("|cff888888GR|r " .. line)
    end
end

-- Calls fn(...), reporting an error as a normal Lua error instead of
-- stopping the caller. (Arguments are not passed through xpcall itself,
-- which plain Lua 5.1 does not support.)
function ns.SafeCall(fn, ...)
    local args, count = { ... }, select("#", ...)
    xpcall(function()
        fn(unpack(args, 1, count))
    end, geterrorhandler())
end

-- Callbacks between the parts of the addon. Each listener runs on its own,
-- so an error in one is reported without stopping the others.
local listeners = {}

function ns.On(event, callback)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], callback)
end

function ns.Fire(event, ...)
    for _, callback in ipairs(listeners[event] or {}) do
        ns.SafeCall(callback, ...)
    end
end

-- Runs fn once things have been quiet for delay seconds. With maxWait, it
-- runs at the latest maxWait seconds after the first call.
local debounced = {}

function ns.Debounce(key, delay, fn, maxWait)
    local now = GetTime()
    local entry = debounced[key]
    if entry then
        entry.timer:Cancel()
    else
        entry = { first = now }
        debounced[key] = entry
    end
    local wait = delay
    if maxWait then
        wait = math.min(delay, entry.first + maxWait - now)
    end
    entry.timer = C_Timer.NewTimer(math.max(wait, 0), function()
        debounced[key] = nil
        fn()
    end)
end

-- Names -------------------------------------------------------------------

-- Our name ("Alice Smith") and how our addon messages are signed
-- ("Alice Smith-Realm").
function ns.SetPlayerName(name)
    ns.playerName = name
    ns.playerKey = name .. "-" .. ns.realm
end

-- True when a message sender is ourselves ("Name Surname", or with a realm).
function ns.IsMe(sender)
    return sender == ns.playerName or sender == ns.playerKey
        or (ns.playerGUID ~= nil and ns.Roster.GUIDOfSender(sender) == ns.playerGUID)
end

-- Realm names as they appear in "Name-Realm": no spaces or dashes.
function ns.NormalizeRealm(realm)
    return (realm:gsub("[%s%-]", ""))
end

function ns.ShortName(fullName)
    return Ambiguate(fullName, "guild")
end

-- "3 days", "5 min"... in the client's language.
function ns.Ago(timestamp)
    local seconds = math.max(ns.Now() - timestamp, 0)
    if seconds < 60 then
        return L["a moment"]
    end
    -- Limited to one unit, SecondsToTime only uses a unit from 1.5 of it, so
    -- from 60 to 89 seconds it gives nothing.
    local text = SecondsToTime(seconds, true, true, 1)
    if text == "" then
        text = SecondsToTime(seconds, true, true, 2)
    end
    return text
end

-- Professions ----------------------------------------------------------------

-- The usual icon of each profession, for when the client has no better one.
local PROFESSION_ICONS = {
    [129] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", -- First Aid
    [164] = "Interface\\Icons\\Trade_BlackSmithing",
    [165] = "Interface\\Icons\\Trade_LeatherWorking",
    [171] = "Interface\\Icons\\Trade_Alchemy",
    [182] = "Interface\\Icons\\Trade_Herbalism",
    [185] = "Interface\\Icons\\INV_Misc_Food_15",           -- Cooking
    [186] = "Interface\\Icons\\Trade_Mining",
    [197] = "Interface\\Icons\\Trade_Tailoring",
    [202] = "Interface\\Icons\\Trade_Engineering",
    [333] = "Interface\\Icons\\Trade_Engraving",            -- Enchanting
    [356] = "Interface\\Icons\\Trade_Fishing",
    [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",      -- Skinning
    [40] = "Interface\\Icons\\Trade_BrewPoison",            -- Poisons
}

-- Name and icon of a skill line, in the client's language. spellID (the
-- profession's own spell) is the fallback when the client cannot name it.
function ns.ProfessionName(skillLine, spellID)
    local name = ns.Try(C_TradeSkillUI.GetTradeSkillDisplayName, skillLine)
    if not name or name == "" then
        local info = ns.Try(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLine)
        name = type(info) == "table" and info.professionName or nil
    end
    if (not name or name == "") and spellID then
        name = C_Spell.GetSpellName(spellID)
    end
    return (name and name ~= "") and name or ("#" .. skillLine)
end

function ns.ProfessionIcon(skillLine, spellID)
    local icon = ns.Try(C_TradeSkillUI.GetTradeSkillTexture, skillLine)
    if not icon and spellID then
        icon = C_Spell.GetSpellTexture(spellID)
    end
    return icon or PROFESSION_ICONS[skillLine] or 134400 -- question mark
end

-- Startup ------------------------------------------------------------------

local events = CreateFrame("Frame")
ns.RegisterEvents(events, "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT")
events:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGOUT" then
        ns.Data.PackForSave(ns.db)
    elseif event == "ADDON_LOADED" and name == ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")
        ns.Data.Load()
        if ns.db.settings.locale then
            ns.SetLocale(ns.db.settings.locale)
        end
    elseif event == "PLAYER_LOGIN" then
        ns.realm = ns.Plain(GetNormalizedRealmName()) or ns.NormalizeRealm(GetRealmName())
        ns.playerGUID = ns.Plain(UnitGUID("player"))
        -- WoW Forever names have two parts, and UnitName gives them apart
        -- ("Alice", "Smith"). The roster's spelling replaces this once it
        -- is read (see Roster.lua).
        local first, second = UnitName("player")
        first, second = ns.Plain(first), ns.Plain(second)
        ns.SetPlayerName(second and second ~= "" and (first .. " " .. second) or first)
        ns.loginTime = GetTime()
        -- Each part starts on its own, so a failure in one (reported as a normal
        -- Lua error) does not stop the others.
        for _, init in ipairs({ ns.Comm.Init, ns.Roster.Init, ns.Scanner.Init, ns.Sync.Init, ns.RosterColumn.Init, ns.Viewer.Init }) do
            xpcall(init, geterrorhandler())
        end
    end
end)

-- Slash commands -------------------------------------------------------------

local function PrintHelp()
    ns.Print(L["/grecipes - your own professions"])
    ns.Print(L["/grecipes <name> - the professions of a guild member"])
    ns.Print(L["/grecipes status - what the addon knows and is doing"])
    ns.Print(L["/grecipes sync - ask the guild for missing data now"])
    ns.Print(L["/grecipes probe - test report for the addon's author"])
    ns.Print(L["/grecipes language [code|auto] - language of the addon's texts"])
    ns.Print(L["/grecipes debug - show the sync log in the chat"])
    ns.Print(L["/grecipes reset - forget the data of your current guild"])
end

local function PrintStatus()
    ns.Print(L["version %s. Saved data loaded by the client: %s."], ns.VERSION, ns.loadInfo.native and YES or NO)

    local guildKey = ns.Roster.guildKey
    if not guildKey then
        ns.Print(L["you are not in a guild (or the guild has not loaded yet)."])
        return
    end
    local guild = ns.Data.GetGuild(guildKey)
    local members, withRecipes = 0, 0
    for _, record in pairs(guild and guild.members or {}) do
        members = members + 1
        if ns.Data.Stats(record) > 0 then
            withRecipes = withRecipes + 1
        end
    end
    ns.Print(L["guild %s: data on %d |4member:members;, %d of them with recipes."], guildKey, members, withRecipes)

    local own = ns.Data.GetOwnRecord(false)
    for _, prof in ipairs(ns.Data.SortedProfessions(own)) do
        local state
        if prof.k == false then
            state = L["no recipes"]
        elseif prof.k == nil then
            state = L["recipes not read yet: open the profession once"]
        else
            state = L["%d |4recipe:recipes;"]:format(#prof.k)
        end
        ns.Print("  %s (%d/%d): %s", ns.ProfessionName(prof.sl, prof.lk), prof.r, prof.m, state)
    end
    ns.Print(L["sync: %s"], ns.Sync.Describe())
end

SLASH_GUILDPROFESSIONSRECIPES1 = "/grecipes"
SLASH_GUILDPROFESSIONSRECIPES2 = "/gprecipes"
SlashCmdList.GUILDPROFESSIONSRECIPES = function(message)
    message = strtrim(message or "")
    local command, rest = message:match("^(%S*)%s*(.-)$")
    local lower = command:lower()
    if lower == "" then
        ns.Viewer.Open(nil)
    elseif lower == "status" then
        PrintStatus()
    elseif lower == "sync" then
        ns.Sync.SendHello(true)
    elseif lower == "probe" then
        ns.Probe.Run(rest:lower() == "burst")
    elseif lower == "debug" then
        ns.debugEnabled = not ns.debugEnabled
        ns.Print(ns.debugEnabled and L["sync log on."] or L["sync log off."])
    elseif lower == "language" or lower == "lang" then
        -- A language code in any case ("dede" is deDE), or auto.
        local code
        for _, known in ipairs(ns.LOCALES) do
            if known:lower() == rest:lower() then
                code = known
            end
        end
        if not code and rest:lower() ~= "auto" then
            ns.Print(L["languages: %s, or auto for the client's."], table.concat(ns.LOCALES, ", "))
            return
        end
        ns.db.settings.locale = code
        ns.SetLocale(code)
        ns.Print(L["language set to %s. Type /reload to update every window."], ns.LOCALE)
    elseif lower == "reset" then
        if rest:lower() ~= "confirm" then
            ns.Print(L["this forgets what you know about your current guild. Type /grecipes reset confirm to do it."])
        else
            ns.Data.ResetGuild(ns.Roster.guildKey)
            ns.Print(L["data of your current guild forgotten."])
        end
    elseif lower == "help" or lower == "?" then
        PrintHelp()
    else
        -- Anything else is a member's name (WoW Forever names have spaces).
        ns.Viewer.Open(message)
    end
end
