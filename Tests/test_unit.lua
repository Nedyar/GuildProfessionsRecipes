local H = ...

local GUILD = "Test Guild"
local BOB = "Player-1-000000B0"
local X, Y = "Player-1-000000C1", "Player-1-000000C2"

-- A single client gives access to the addon's modules.
local world = H.NewWorld({ seed = 1 })
local solo = world:NewClient("Solo", {})
world:Login(solo)
world:RunFor(2)
local ns = solo.ns
local Pack, Data = ns.Pack, ns.Data
local now = ns.Now()

H.section("Pack: numbers")
for _, value in ipairs({ 0, 1, 127, 128, 255, 16383, 16384, 2 ^ 21, 1306126, 2 ^ 31, 2 ^ 40, 2 ^ 53 - 1 }) do
    local writer = Pack.Writer()
    writer:UInt(value)
    local reader = Pack.Reader(writer:Result())
    H.eq(reader:UInt(), value, "uint round trip " .. value)
    H.check(reader:AtEnd(), "uint fully read " .. value)
end
local function Size(value)
    local writer = Pack.Writer()
    writer:UInt(value)
    return #writer:Result()
end
H.eq(Size(127), 1, "127 takes 1 byte")
H.eq(Size(128), 2, "128 takes 2 bytes")
H.eq(Size(1306126), 3, "a 7-digit recipe ID takes 3 bytes")
H.check(not pcall(function() Pack.Writer():UInt(-1) end), "negative numbers refused")
H.check(not pcall(function() Pack.Reader(""):UInt() end), "truncated number refused")
H.check(not pcall(function() Pack.Reader(("\128"):rep(9)):UInt() end), "overlong number refused")
H.check(not pcall(function() Pack.Reader("\5ab"):Str() end), "truncated text refused")
H.check(not pcall(function() Pack.Reader("\100" .. ("x"):rep(100)):Str() end), "text over the limit refused")

H.section("Pack: lists and records")
local list = { 2, 3, 10, 500, 1306126, 1306127 }
local writer = Pack.Writer()
Pack.WriteList(writer, list)
H.check(H.SameList(Pack.ReadList(Pack.Reader(writer:Result())), list), "list round trip")
writer = Pack.Writer()
Pack.WriteList(writer, {})
H.check(H.SameList(Pack.ReadList(Pack.Reader(writer:Result())), {}), "empty list round trip")
H.check(not pcall(Pack.ReadList, Pack.Reader("\2\5\0")), "unsorted list refused")
writer = Pack.Writer()
writer:UInt(2000)
H.check(not pcall(Pack.ReadList, Pack.Reader(writer:Result())), "list over the limit refused")

local record = {
    n = "Solo Name", t = now, av = 100,
    p = {
        [171] = { r = 150, m = 225, o = 1, lk = 2259, k = { 2330, 2331, 1306126 } },
        [182] = { r = 200, m = 225, o = 2, lk = 2366, k = false },
        [185] = { r = 10, m = 75, o = 5 },
    },
}
local key, back = Pack.ReadRecord(Pack.Reader(Pack.RecordString("Player-1-0000000A", record)))
H.eq(key, "Player-1-0000000A", "record key (the GUID)")
H.eq(back.t, record.t, "record time")
H.eq(back.n, "Solo Name", "record name, spaces included")
H.check(H.SameList(back.p[171].k, record.p[171].k), "record recipe list")
H.eq(back.p[182].k, false, "no-recipes state kept")
H.eq(back.p[185].k, nil, "unknown-recipes state kept")
H.eq(back.p[185].lk, nil, "missing spell stays missing")
H.eq(back.p[171].lk, 2259, "profession spell kept")
H.check(not pcall(Pack.ReadRecord, Pack.Reader(Pack.RecordString("Player-1-0000000A", record):sub(1, -3))), "truncated record refused")

H.section("Pack: Base64 and hashing")
for length = 0, 40 do
    local bytes = {}
    for i = 1, length do
        bytes[i] = string.char(math.random(0, 255))
    end
    local text = table.concat(bytes)
    H.eq(Pack.ToBase64(text), H.Enc64(text), "encode, length " .. length)
    H.eq(Pack.FromBase64(H.Enc64(text)), text, "decode, length " .. length)
end
for _, bad in ipairs({ "abc", "a=bc", "ab=c", "====", "ab==cd==", "a*bc" }) do
    H.eq(Pack.FromBase64(bad), nil, "invalid Base64 refused: " .. bad)
end
H.eq(Pack.Hash("abc"), Pack.Hash("abc"), "hash is stable")
H.check(Pack.Hash("abc") ~= Pack.Hash("abd"), "hash differs")
H.check(Pack.Hash(("x"):rep(10000)) < 2 ^ 32, "hash stays 32-bit")
H.eq(Pack.Digit(0), "A", "digit 0")
H.eq(Pack.DigitValue("/"), 63, "digit 63")

H.section("Data: checks")
local function Rec(t, professions)
    return { t = t, av = 100, p = professions }
end
H.check(Data.CleanRecord(Rec(now, {})) ~= nil, "valid empty record")
H.eq(Data.CleanRecord(Rec(now + 1000, {}), now), nil, "record from the future refused")
H.eq(Data.CleanRecord(Rec(100, {})), nil, "ancient record refused")
H.eq(Data.CleanRecord(Rec(0 / 0, {})), nil, "NaN time refused")
H.eq(Data.CleanRecord(Rec(now, { [171] = { r = 5000, m = 300 } })), nil, "rank too high refused")
H.eq(Data.CleanRecord(Rec(now, { [171] = { r = 5, m = 300, k = { 1, "x" } } })), nil, "bad recipe ID refused")
local many = {}
for i = 1, 1501 do
    many[i] = i
end
H.eq(Data.CleanRecord(Rec(now, { [171] = { r = 5, m = 300, k = many } })), nil, "too many recipes refused")
local cleaned = Data.CleanRecord(Rec(now, { [171] = { r = 5, m = 300, k = { 30, 10, 20, 10 } } }))
H.check(H.SameList(cleaned.p[171].k, { 10, 20, 30 }), "recipe list sorted and deduplicated")
local tooMany = {}
for i = 1, 11 do
    tooMany[i * 10] = { r = 1, m = 1 }
end
H.eq(Data.CleanRecord(Rec(now, tooMany)), nil, "too many professions refused")
H.eq(Data.CleanName("Alice Smith"), "Alice Smith", "names with spaces are fine")
H.eq(Data.CleanName(("x"):rep(80)), nil, "overlong names refused")
H.eq(Data.CleanName(""), nil, "empty names refused")
H.check(Data.IsGUID("Player-1-0000000A"), "player GUID accepted")
H.check(not Data.IsGUID("Creature-0-1"), "other GUIDs refused")

H.section("Data: merging")
local a = Data.CleanRecord(Rec(now, { [171] = { r = 1, m = 1, k = { 1, 2 } } }))
local b = Data.CleanRecord(Rec(now, { [171] = { r = 1, m = 1 } }))
local c = Data.CleanRecord(Rec(now + 1, { [171] = { r = 1, m = 1 } }))
H.eq(Data.Compare(a, b), 1, "same time: the copy with more lists wins")
H.eq(Data.Compare(c, a), 1, "the newer copy wins")
H.eq(Data.Compare(a, H.DeepCopy(a)), 0, "equal copies tie")

local guild = { members = {} }
H.check(Data.MergeRecord(guild, BOB, H.DeepCopy(a), false), "first copy stored")
H.check(Data.MergeRecord(guild, BOB, H.DeepCopy(c), false), "newer copy replaces")
H.check(H.SameList(guild.members[BOB].p[171].k, { 1, 2 }), "a newer copy without the list keeps the old list")
H.check(not Data.MergeRecord(guild, BOB, H.DeepCopy(a), false), "older relayed copy refused")
local reverse = { members = {} }
Data.MergeRecord(reverse, BOB, H.DeepCopy(c), false)
H.check(Data.MergeRecord(reverse, BOB, H.DeepCopy(a), false), "an older copy arriving later still gives its list")
H.check(H.SameList(reverse.members[BOB].p[171].k, { 1, 2 }), "list taken from the older copy")
H.eq(reverse.members[BOB].t, c.t, "the newer copy stays")
local firsthand = Data.CleanRecord(Rec(now + 1, { [171] = { r = 2, m = 1 } }))
H.check(Data.MergeRecord(guild, BOB, firsthand, true), "firsthand copy of the same time accepted")
H.eq(guild.members[BOB].p[171].r, 2, "firsthand copy applied")
H.check(guild.members[BOB].fh == true, "firsthand copy marked")

local ownKey = ns.playerGUID
guild.members[ownKey] = { t = now, p = { [171] = { r = 1, m = 1 }, [164] = { r = 3, m = 3, k = { 5 } } } }
local theirs = Data.CleanRecord(Rec(now + 50, { [171] = { r = 9, m = 9, k = { 7, 8 } }, [164] = { r = 9, m = 9, k = { 99 } } }))
H.check(Data.MergeRecord(guild, ownKey, theirs, false), "own unknown list filled from the guild")
H.eq(guild.members[ownKey].p[171].r, 1, "own rank never replaced")
H.check(H.SameList(guild.members[ownKey].p[171].k, { 7, 8 }), "own unknown list taken")
H.check(H.SameList(guild.members[ownKey].p[164].k, { 5 }), "own known list kept")

-- Two copies of a member meet when version 0.1 data is migrated (the same
-- guild under two realm names): the newest is kept, with the other's list,
-- whichever comes first.
local function OldDB(order)
    local a = Rec(now, { [171] = { r = 1, m = 1, k = { 1 } } })
    local b = Rec(now + 5, { [171] = { r = 2, m = 2 } })
    a.guid, b.guid = X, X
    local first, second = a, b
    if order == 2 then
        first, second = b, a
    end
    return Data.Sanitize({ schema = 1, guilds = {
        ["Test Guild-RealmA"] = { seen = now, members = { ["Xavier-RealmA"] = first } },
        ["Test Guild-RealmB"] = { seen = now, members = { ["Xavier-RealmB"] = second } },
    } })
end
for order = 1, 2 do
    local member = OldDB(order).guilds[GUILD].members[X]
    H.eq(member and member.t, now + 5, "merging two copies keeps the newest (order " .. order .. ")")
    H.check(member and H.SameList(member.p[171].k, { 1 }), "and takes the other copy's list (order " .. order .. ")")
end

local junk = Data.Sanitize({
    schema = 2,
    guilds = { [5] = {}, ["G R"] = { members = { bad = {}, [X] = { t = "x" }, [Y] = Rec(now, {}) } } },
    cache = "x",
    own = { [X] = 5 },
})
H.check(junk.guilds["G R"].members[Y] ~= nil, "valid record kept from a damaged file")
H.eq(junk.guilds["G R"].members[X], nil, "damaged record dropped")
H.eq(junk.guilds["G R"].members.bad, nil, "a key that is not a GUID is dropped")
H.eq(junk.guilds[5], nil, "damaged guild dropped")
H.eq(junk.own[X], nil, "damaged own state dropped")
H.eq(Data.Sanitize(nil).schema, 2, "missing file gives a new database")

-- Version 0.1 (schema 1) kept guilds as "Name-Realm" and members by name.
local oldRecord = Rec(now, { [171] = { r = 1, m = 1, k = { 4, 5 } } })
oldRecord.guid = BOB
local migrated = Data.Sanitize({ schema = 1, guilds = { ["Test Guild-TestRealm"] = { seen = now, members = {
    ["Bob Smith-TestRealm"] = oldRecord,
    ["Nobody-TestRealm"] = Rec(now, {}),
} } }, own = { ["Bob Smith-TestRealm"] = { sentFP = 1 } } })
H.check(migrated.guilds[GUILD] ~= nil and migrated.guilds["Test Guild-TestRealm"] == nil, "schema 1: the guild is renamed to its name alone")
local bobMigrated = migrated.guilds[GUILD] and migrated.guilds[GUILD].members[BOB]
H.check(bobMigrated and H.SameList(bobMigrated.p[171].k, { 4, 5 }), "schema 1: members are re-keyed by GUID")
H.eq(bobMigrated and bobMigrated.n, "Bob Smith", "schema 1: the name is kept for display")
H.eq(next(migrated.own), nil, "schema 1: the old own states are dropped")
H.eq(Data.CleanName("Evil|cff00ff00Name"), "Evilcff00ff00Name", "names from other clients lose escape codes")

H.section("Data: digests")
ns.Roster.ready = false -- every key counts as a member
local g1, g2 = { members = {} }, { members = {} }
local keys = { "Player-9-00000001", "Player-9-00000002", "Player-9-00000003", "Player-9-00000004", "Player-9-00000005" }
for i, k in ipairs(keys) do
    g1.members[k] = Data.CleanRecord(Rec(now + i, { [171] = { r = i, m = 300, k = { i } } }))
end
for i = #keys, 1, -1 do
    g2.members[keys[i]] = Data.CleanRecord(Rec(now + i, { [171] = { r = i, m = 300, k = { i } } }))
end
local d1, count1 = Data.Digests(g1)
local d2 = Data.Digests(g2)
H.eq(table.concat(d1, ","), table.concat(d2, ","), "digests do not depend on order")
H.eq(count1, 5, "digest count")
g2.members[keys[3]].t = g2.members[keys[3]].t + 1
Data.ForgetDigests()
H.check(table.concat(Data.Digests(g2), ",") ~= table.concat(d1, ","), "a changed record changes the digests")
ns.Roster.ready = true

H.section("Loader")
local w2 = H.NewWorld({ seed = 5 })
local alt = w2:NewClient("Alt", {})
w2:Login(alt)
H.eq(alt.ns.loadInfo.native, false, "a first login has no saved data")
w2:RunFor(30)
w2:Logout(alt)
alt.saved.settings.locale = "esES"
alt.saved.guilds["Other Guild"] = { seen = now, members = {} }
w2:Login(alt)
H.eq(alt.ns.loadInfo.native, true, "saved data loaded")
H.check(alt.env.GuildRecipesDB.guilds["Other Guild"] ~= nil, "saved guilds kept")
H.eq(alt.ns.LOCALE, "esES", "saved language applied")
H.eq(alt.ns.L["Professions"], "Profesiones", "texts follow the saved language")
H.section("Loader: packed recipe lists")
local big = {}
for i = 1, 300 do
    big[i] = 2000 + i * 7
end
big[301] = 1306126
local w4 = H.NewWorld({ seed = 8 })
local packer = w4:NewClient("Packer", { professions = { { sl = 171, r = 300, m = 300, spell = 2259, hasRecipes = true } } })
w4:Login(packer)
w4:RunFor(5)
w4:OpenProfession(packer, 171, big, big)
w4:RunFor(2)
w4:CloseProfession(packer)
w4:Logout(packer)
local savedList = packer.saved.guilds[GUILD].members[packer.guid].p[171].k
H.eq(type(savedList), "string", "recipe lists are saved packed")
H.check(#savedList < #big * 3, "packed list is small (" .. #savedList .. " bytes for " .. #big .. " recipes)")
w4:Login(packer)
w4:RunFor(2)
local reloaded = packer.env.GuildRecipesDB.guilds[GUILD].members[packer.guid].p[171].k
H.check(H.SameList(reloaded, big), "packed list read back on login")
local damaged = Data.Sanitize({ schema = 2, guilds = { [GUILD] = { members = { [X] = { t = now, p = { [171] = { r = 1, m = 1, k = "@@@@" } } } } } } })
H.eq(damaged.guilds[GUILD].members[X], nil, "a damaged packed list drops the record")
H.eq(#w4.errors, 0, "packed lists: no Lua errors")
for _, err in ipairs(w4.errors) do
    print(err)
end

H.eq(#w2.errors, 0, "loader: no Lua errors")

H.section("Ages")
-- "Updated ... ago" always says how long.
for _, seconds in ipairs({ -30, 0, 59, 60, 75, 89, 90, 3599, 3600, 5399, 86400, 129599, 3000000 }) do
    local text = ns.Ago(ns.Now() - seconds)
    H.check(type(text) == "string" and text ~= "", ("age of %d s is shown (%s)"):format(seconds, tostring(text)))
end
H.eq(ns.Ago(ns.Now() - 30), "a moment", "under a minute: a moment")
H.check(ns.Ago(ns.Now() - 75):find("^1 Minute") ~= nil, "75 s: 1 minute")

H.section("TOC")
-- The game reports an error for every listed file that does not exist.
local toc = assert(io.open(H.ADDON .. "/GuildRecipes.toc", "r"))
local listed, missing = 0, 0
for line in toc:lines() do
    line = line:gsub("\r$", "")
    if line ~= "" and not line:find("^#") then
        listed = listed + 1
        local file = io.open(H.ADDON .. "/" .. line:gsub("\\", "/"), "r")
        if file then
            file:close()
        else
            missing = missing + 1
            print("  missing: " .. line)
        end
    end
end
toc:close()
H.eq(listed, #H.FILES, "the TOC lists every file the tests load")
H.eq(missing, 0, "every file the TOC lists exists")
local loaded = {}
for _, path in ipairs(H.FILES) do
    loaded[path] = true
end
H.check(loaded["Core.lua"] and loaded["Probe.lua"], "the tests load the addon's files")

H.section("Locales")
local w3 = H.NewWorld({ seed = 6 })
local mx = w3:NewClient("Mex", { locale = "esMX" })
local es = w3:NewClient("Esp", { locale = "esES" })
local en = w3:NewClient("Eng", { locale = "enGB" })
local pt = w3:NewClient("Por", { locale = "ptPT" })
local ru = w3:NewClient("Rus", { locale = "ruRU" })
w3:Login(mx)
w3:Login(es)
w3:Login(en)
w3:Login(pt)
w3:Login(ru)
H.eq(mx.ns.L["View live"], "Ver en vivo", "esMX overrides")
H.eq(mx.ns.L["Professions"], "Profesiones", "esMX inherits esES")
H.eq(es.ns.L["View live"], "Ver en directo", "esES text")
H.eq(en.ns.L["View live"], "View live", "enGB uses English")
H.eq(en.ns.LOCALE, "enUS", "enGB counts as enUS")
H.eq(pt.ns.LOCALE, "ptBR", "ptPT counts as ptBR")
H.eq(pt.ns.L["Professions"], "Profissões", "ptPT uses the Brazilian texts")
H.eq(ru.ns.L["Professions"], "Профессии", "ruRU text")
es.ns.SetLocale("enUS")
H.eq(es.ns.L["Professions"], "Professions", "language switched at run time")
es.ns.SetLocale(nil)
H.eq(es.ns.L["Professions"], "Profesiones", "back to the client's language")

-- The texts the code asks for: every L["..."] outside the language files.
local used, usedCount = {}, 0
for _, path in ipairs(H.FILES) do
    if not path:find("^Locales/") then
        local file = assert(io.open(H.ADDON .. "/" .. path, "r"))
        for key in file:read("*a"):gmatch('L%["(.-)"%]') do
            if not used[key] then
                used[key] = true
                usedCount = usedCount + 1
            end
        end
        file:close()
    end
end
H.check(usedCount > 50, "the code's texts found (" .. usedCount .. ")")

local function Formats(text)
    local list = {}
    for f in text:gmatch("%%[%a]") do
        list[#list + 1] = f
    end
    return table.concat(list)
end
-- Plural markup is "|4one:other;", and Russian's "|4one:few:many;".
local function PluralsOK(text, forms)
    local position = 1
    while true do
        local start = text:find("|4", position, true)
        if not start then
            return true
        end
        local body = text:match("^|4([^;|]+);", start)
        if not body then
            return false
        end
        local _, colons = body:gsub(":", "")
        if colons ~= forms - 1 then
            return false
        end
        position = start + 2
    end
end
local englishPlurals = 0
for key in pairs(used) do
    if not PluralsOK(key, 2) then
        englishPlurals = englishPlurals + 1
        print("  bad plural: " .. key)
    end
end
H.eq(englishPlurals, 0, "English plurals are well formed")

-- Every language translates exactly the texts the code uses.
local languages = 0
for _, code in ipairs(es.ns.LOCALES) do
    if code ~= "enUS" then
        languages = languages + 1
        es.ns.SetLocale(code)
        local L = es.ns.L
        local missing, unused, formats, plurals = 0, 0, 0, 0
        for key in pairs(used) do
            if rawget(L, key) == nil then
                missing = missing + 1
                print("  " .. code .. " lacks: " .. key)
            end
        end
        for key, text in pairs(L) do
            if not used[key] then
                unused = unused + 1
                print("  " .. code .. " has an unused text: " .. key)
            elseif Formats(key) ~= Formats(text) then
                formats = formats + 1
                print("  " .. code .. " format mismatch: " .. key)
            end
            if not PluralsOK(text, code == "ruRU" and 3 or 2) then
                plurals = plurals + 1
                print("  " .. code .. " bad plural: " .. text)
            end
        end
        H.eq(missing, 0, code .. ": every text translated")
        H.eq(unused, 0, code .. ": no unused texts")
        H.eq(formats, 0, code .. ": the same %-formats in the same order")
        H.eq(plurals, 0, code .. ": plurals well formed")
    end
end
es.ns.SetLocale(nil)
H.eq(languages, 10, "ten languages besides English")
H.eq(#w3.errors, 0, "locales: no Lua errors")

H.eq(#world.errors, 0, "unit tests: no Lua errors")
for _, err in ipairs(world.errors) do
    print(err)
end
for _, err in ipairs(w2.errors) do
    print(err)
end
