-- Data.lua: what Guild Professions & Recipes adds to its database
-- (LibGuildSync's Store.lua keeps the database, merges the copies and works
-- out the digests).
--
-- GuildProfessionsRecipesDB = {
--   schema = 2,
--   guilds = { ["Guild Name"] = { seen = time, members = {
--       ["Player-1234-0ABCDEF0"] = record (see Pack.lua; on disk its recipe
--       lists are packed strings, see Data.SaveRecord) plus two local fields:
--           seen = last time the member was in the roster,
--           fh = true when the copy came from the member themselves } } },
--   cache = { recCat = { [recipeID] = categoryID },
--             cats = { [locale] = { [categoryID] = { n = name, u = order } } },
--             catalog = { [skillLine] = every recipe ID of the profession } },
--   settings = { locale, viewer = { point, x, y } },
--   own = { [GUID] = { sentFP, sentT, sentGuild, hinted = { [skillLine] = true } } },
-- }
--
-- The addon saved its records this way before it used LibGuildSync, so it
-- still does: every version reads what any other one saved.
local _, ns = ...
local Lib = LibGuildSync
local Pack = ns.Pack
local Data = ns.Data

Data.SCHEMA = 2
-- How complete a copy is: professions with a recipe list, then recipes.
Data.STATS = 2

local MIN_TIME = Lib.MIN_TIME
local FUTURE_SLACK = 300      -- how far an order's times may run ahead of ours
local MAX_CATALOG = 5000      -- recipes of one profession, learned or not
local LIMITS = Pack.LIMITS

local floor = math.floor
local IsCount, IsID = Lib.IsCount, Lib.IsID

-- Checks -------------------------------------------------------------------

-- Recipe lists are saved packed (see Data.SaveRecord): the client writes
-- each number of a plain list on its own line, ten times the size.
local function PackList(list)
    local writer = Pack.Writer()
    Pack.WriteList(writer, list)
    return Pack.ToBase64(writer:Result())
end

local function UnpackList(text)
    local raw = Pack.FromBase64(text)
    if not raw then
        return nil
    end
    local ok, list = pcall(Pack.ReadList, Pack.Reader(raw), MAX_CATALOG)
    return ok and list or nil
end

-- Sorted, distinct recipe IDs; nil when the list is unusable.
local function CleanList(list, max)
    if type(list) == "string" then
        list = UnpackList(list)
    end
    if type(list) ~= "table" then
        return nil
    end
    local ids, seen = {}, {}
    for _, id in pairs(list) do
        if not IsID(id) then
            return nil
        end
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    if #ids > (max or LIMITS.recipes) then
        return nil
    end
    table.sort(ids)
    return ids
end

local function IsTime(value, now)
    return type(value) == "number" and value == floor(value) and value >= MIN_TIME and value < 1e12
        and not (now and value > now + FUTURE_SLACK)
end

-- An order's note as given by another client, safe to show: no escape
-- sequences and no control characters but line breaks.
function Data.CleanNote(note)
    if type(note) ~= "string" then
        return nil
    end
    note = note:gsub("|", ""):gsub("[%z\1-\9\11-\31\127]", "")
    if #note > LIMITS.note then
        return nil
    end
    return note
end

-- Checked copies of a record's crafting orders and answers (format 3 and
-- later), or nil when they cannot be trusted. See Pack.lua and Orders.lua.
local function CleanOrders(orders, now)
    if type(orders) ~= "table" then
        return nil
    end
    local clean, count = {}, 0
    for id, order in pairs(orders) do
        if not IsCount(id, 999999) or id == 0 or type(order) ~= "table" then
            return nil
        end
        local note = Data.CleanNote(order.note or "")
        if not (IsID(order.sl) and IsID(order.r) and IsCount(order.q, LIMITS.quantity) and order.q > 0
                and (order.d == nil or Data.IsGUID(order.d)) and IsCount(order.tip or 0, LIMITS.tip) and note
                and IsTime(order.c, now) and IsTime(order.u, now) and order.u >= order.c
                and (order.e == nil or IsCount(order.e, LIMITS.days) and order.e > 0) and IsCount(order.s or 0, 2)) then
            return nil
        end
        -- e: the days an order of 0.8 lasted, kept until Orders upgrades it.
        clean[id] = { sl = order.sl, r = order.r, q = order.q, d = order.d, m = order.m == true, tip = order.tip or 0,
            note = note, c = order.c, u = order.u, e = order.e, s = order.s or 0 }
        count = count + 1
        if count > LIMITS.orders then
            return nil
        end
    end
    return clean
end

local function CleanAnswers(answers, now)
    if type(answers) ~= "table" then
        return nil
    end
    local clean, count = {}, 0
    for key, answer in pairs(answers) do
        local requester, id
        if type(key) == "string" then
            requester, id = key:match("^(.+):(%d+)$")
        end
        if not (requester and Data.IsGUID(requester) and type(answer) == "table" and IsCount(answer.s, 4) and answer.s > 0
                and IsTime(answer.u, now) and IsTime(answer.ou, now) and IsCount(answer.n or 0, LIMITS.quantity)
                and IsCount(answer.p or 0, LIMITS.tip)) then
            return nil
        end
        clean[requester .. ":" .. tonumber(id)] = { s = answer.s, u = answer.u, ou = answer.ou,
            n = answer.n ~= 0 and answer.n or nil, p = answer.p ~= 0 and answer.p or nil }
        count = count + 1
        if count > LIMITS.answers then
            return nil
        end
    end
    return clean
end

-- A checked copy of a record, or nil when it cannot be trusted. now is given
-- for records from other clients, which may not be dated in the future.
function Data.CleanRecord(record, now)
    local clean = Data.CleanBase(record, now)
    if not clean or type(record.p) ~= "table" then
        return nil
    end
    clean.p = {}
    local count = 0
    for skillLine, prof in pairs(record.p) do
        if not IsID(skillLine) or type(prof) ~= "table" or not IsCount(prof.r, LIMITS.rank) or not IsCount(prof.m, LIMITS.rank) then
            return nil
        end
        local cleanProf = { r = prof.r, m = prof.m, o = IsCount(prof.o, 50) and prof.o or 0 }
        if IsID(prof.lk) then
            cleanProf.lk = prof.lk
        end
        if prof.k == false then
            cleanProf.k = false
        elseif prof.k ~= nil then
            cleanProf.k = CleanList(prof.k)
            if not cleanProf.k then
                return nil
            end
        end
        clean.p[skillLine] = cleanProf
        count = count + 1
        if count > LIMITS.professions then
            return nil
        end
    end
    -- Absent (nil) in records of format 2: nothing known of their orders.
    if record.o ~= nil then
        clean.o = CleanOrders(record.o, now)
        if not clean.o then
            return nil
        end
    end
    if record.a ~= nil then
        clean.a = CleanAnswers(record.a, now)
        if not clean.a then
            return nil
        end
    end
    return clean
end

-- Comparing and merging --------------------------------------------------------

-- How complete a record is: professions with a recipe list, recipes in all.
function Data.Stats(record)
    local lists, recipes = 0, 0
    for _, prof in pairs(record.p) do
        if type(prof.k) == "table" then
            lists = lists + 1
            recipes = recipes + #prof.k
        end
    end
    return lists, recipes
end

-- The copy kept of a member takes, for each profession whose recipes it
-- does not know (k == nil), the list of the other copy: a character whose
-- own data was lost shares its levels again without wiping its recipes
-- everywhere, whichever copy arrives first. Orders and answers unknown in
-- the kept copy (its owner lost them, or it came from a 0.7 client) are not
-- wiped either. Returns true if it took any.
function Data.CarryMissing(kept, other)
    local changed = false
    for skillLine, prof in pairs(kept.p) do
        local otherProf = other.p[skillLine]
        if prof.k == nil and otherProf and type(otherProf.k) == "table" then
            prof.k = otherProf.k
            changed = true
        end
    end
    if kept.o == nil and other.o ~= nil then
        kept.o = other.o
        changed = true
    end
    if kept.a == nil and other.a ~= nil then
        kept.a = other.a
        changed = true
    end
    return changed
end

-- Our own record is only ever changed by us, but if we lost a profession's
-- recipe list, or our crafting orders and answers (o and a never known on
-- this client), a copy coming back from the guild fills them in.
function Data.AdoptOwn(own, record)
    return Data.CarryMissing(own, record)
end

-- The saved database -----------------------------------------------------------

-- Schema 1 (version 0.1) knew guilds as "Name-Realm" and members by name,
-- with their GUID inside the record.
function Data.UpgradeSaved(db)
    if (tonumber(db.schema) or 1) >= 2 or type(db.guilds) ~= "table" then
        return
    end
    local guilds = {}
    for oldKey, guild in pairs(db.guilds) do
        if type(oldKey) == "string" and type(guild) == "table" then
            local key = oldKey:match("^(.+)%-[^%-]+$") or oldKey
            local upgraded = guilds[key] or { seen = 0, members = {} }
            upgraded.seen = math.max(upgraded.seen, type(guild.seen) == "number" and guild.seen or 0)
            for name, record in pairs(type(guild.members) == "table" and guild.members or {}) do
                if type(record) == "table" and type(record.guid) == "string" then
                    record.n = record.n or (type(name) == "string" and name:match("^([^%-]+)") or nil)
                    -- Two copies of a member (the guild under two realms): the
                    -- better one is kept and takes what only the other knew.
                    local kept, other = record, upgraded.members[record.guid]
                    if other then
                        local ok, better = pcall(Data.Compare, record, other)
                        if not ok or better <= 0 then
                            kept, other = other, record
                        end
                        pcall(Data.CarryMissing, kept, other)
                    end
                    upgraded.members[record.guid] = kept
                end
            end
            guilds[key] = upgraded
        end
    end
    db.guilds = guilds
    -- What schema 1 kept for our own characters is not used any more.
    db.own = nil
end

-- A record is saved as it is, with its recipe lists packed.
function Data.SaveRecord(_, record)
    for _, prof in pairs(record.p) do
        if type(prof.k) == "table" then
            prof.k = PackList(prof.k)
        end
    end
    return record
end

-- Data.CleanRecord unpacks the lists.
function Data.LoadRecord(saved, key)
    return key, saved
end

-- What the library leaves to us when the database is read from disk: the
-- caches of recipe categories and catalogs, and the professions we were
-- told about.
function Data.SanitizeExtra(clean, db)
    clean.cache = { recCat = {}, cats = {}, catalog = {} }
    local cache = type(db.cache) == "table" and db.cache or {}
    if type(cache.recCat) == "table" then
        for recipeID, categoryID in pairs(cache.recCat) do
            if IsID(recipeID) and IsID(categoryID) then
                clean.cache.recCat[recipeID] = categoryID
            end
        end
    end
    if type(cache.cats) == "table" then
        for locale, categories in pairs(cache.cats) do
            if type(locale) == "string" and type(categories) == "table" then
                local cleanCategories = {}
                for categoryID, category in pairs(categories) do
                    if IsID(categoryID) and type(category) == "table" and type(category.n) == "string" then
                        cleanCategories[categoryID] = { n = category.n, u = type(category.u) == "number" and category.u or nil }
                    end
                end
                clean.cache.cats[locale] = cleanCategories
            end
        end
    end
    if type(cache.catalog) == "table" then
        for skillLine, list in pairs(cache.catalog) do
            clean.cache.catalog[skillLine] = IsID(skillLine) and CleanList(list, MAX_CATALOG) or nil
        end
    end
    for _, state in pairs(clean.own) do
        if type(state.hinted) ~= "table" then
            state.hinted = {}
        end
    end
end

function Data.PackExtra(db)
    for skillLine, list in pairs(db.cache.catalog) do
        if type(list) == "table" then
            db.cache.catalog[skillLine] = PackList(list)
        end
    end
end

-- Our own record ----------------------------------------------------------------

local function CopyProfessions(professions)
    local copy = {}
    for skillLine, prof in pairs(professions) do
        copy[skillLine] = { r = prof.r, m = prof.m, o = prof.o, lk = prof.lk, k = prof.k }
    end
    return copy
end

-- Our record in a guild where we have none yet starts from the copy kept in
-- another guild, if any.
function Data.NewOwnRecord()
    local best
    for _, other in pairs(ns.db.guilds) do
        local copy = other.members[ns.playerGUID]
        if copy and (not best or copy.t > best.t) then
            best = copy
        end
    end
    return { t = 0, p = best and CopyProfessions(best.p) or {} }
end

local LibOwnState = Data.OwnState
function Data.OwnState()
    local state = LibOwnState()
    state.hinted = state.hinted or {}
    return state
end

-- A record's professions as a list ordered like the character sheet:
-- { sl = skillLine, r, m, o, lk, k }.
function Data.SortedProfessions(record)
    local list = {}
    if record then
        for skillLine, prof in pairs(record.p) do
            list[#list + 1] = { sl = skillLine, r = prof.r, m = prof.m, o = prof.o, lk = prof.lk, k = prof.k }
        end
    end
    table.sort(list, function(a, b)
        if a.o ~= b.o then
            return a.o < b.o
        end
        return a.sl < b.sl
    end)
    return list
end

-- Every recipe the guild's members have shared, by profession:
-- [skillLine] = { sl, k = sorted recipe IDs, members = how many members
-- shared recipes of it, lk = the profession's spell }. Professions nobody
-- shared recipes of are left out.
function Data.GuildRecipes(guild)
    local byLine = {}
    for _, record in pairs(guild and guild.members or {}) do
        if Data.IsShareable(record) then
            for skillLine, prof in pairs(record.p) do
                if type(prof.k) == "table" and #prof.k > 0 then
                    local entry = byLine[skillLine]
                    if not entry then
                        entry = { sl = skillLine, members = 0, set = {} }
                        byLine[skillLine] = entry
                    end
                    entry.members = entry.members + 1
                    entry.lk = entry.lk or prof.lk
                    for _, recipeID in ipairs(prof.k) do
                        entry.set[recipeID] = true
                    end
                end
            end
        end
    end
    for _, entry in pairs(byLine) do
        local list = {}
        for recipeID in pairs(entry.set) do
            list[#list + 1] = recipeID
        end
        table.sort(list)
        entry.k, entry.set = list, nil
    end
    return byLine
end

-- The list of every recipe of a profession, as seen in a profession window
-- by any character of this WoW account.
function Data.Catalog(skillLine)
    return ns.db.cache.catalog[skillLine]
end

function Data.SetCatalog(skillLine, ids)
    local list = CleanList(ids, MAX_CATALOG)
    if list and #list > 0 then
        ns.db.cache.catalog[skillLine] = list
    end
end
