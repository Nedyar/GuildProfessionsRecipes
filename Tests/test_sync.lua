local H = ...

local GUILD = "Test Guild"

local function Recipes(count, base)
    local list, seen = {}, {}
    while #list < count do
        local id = base + math.random(1, count * 20)
        if math.random() < 0.1 then
            id = 1300000 + math.random(1, 5000)
        end
        if not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    table.sort(list)
    return list
end

local function Take(list, count)
    local out = {}
    for i = 1, math.min(count, #list) do
        out[i] = list[i]
    end
    return out
end

local function RecordOf(viewer, owner)
    local db = viewer.env.GuildProfessionsRecipesDB
    local guild = db and db.guilds[GUILD]
    return guild and guild.members[owner.guid]
end

local function Digests(client)
    local ns = client.ns
    local guild = ns.Data.CurrentGuild(false)
    return guild and table.concat((ns.Data.Digests(guild)), ",") or "none"
end

local function HasList(viewer, owner, skillLine, expected)
    local record = RecordOf(viewer, owner)
    local prof = record and record.p[skillLine]
    if not prof or type(prof.k) ~= "table" then
        return false
    end
    return expected == nil or H.SameList(prof.k, expected)
end

-- The message type of a logged single-part chunk.
local function TypeOf(world, text)
    if text:sub(1, 1) ~= "2" or text:sub(5, 6) ~= "AA" then
        return nil
    end
    local raw = H.Dec64(text:sub(7))
    if text:sub(2, 2) == "z" then
        raw = world.dict[raw]
    end
    return raw and raw:sub(1, 1)
end

local function CountTypes(world, from)
    local counts = {}
    for i = from or 1, #world.log do
        local entry = world.log[i]
        local kind = TypeOf(world, entry.text) or "multi"
        counts[kind] = (counts[kind] or 0) + 1
    end
    return counts
end

local function ReportErrors(world, label)
    H.eq(#world.errors, 0, label .. ": no Lua errors")
    H.eq(#world.systemShown, 0, label .. ": no system lines in the chat")
    for i = 1, math.min(#world.systemShown, 3) do
        print("  " .. world.systemShown[i])
    end
    for i = 1, math.min(#world.errors, 5) do
        print(world.errors[i])
    end
end

local ALCHEMY = { sl = 171, r = 150, m = 225, spell = 2259, hasRecipes = true }
local HERBALISM = { sl = 182, r = 200, m = 225, spell = 2366, hasRecipes = false }
local BLACKSMITHING = { sl = 164, r = 100, m = 150, spell = 2018, hasRecipes = true }

local function Copy(prof)
    return H.DeepCopy(prof)
end

-- Two members ---------------------------------------------------------------------

local function TwoMembers(options, label)
    H.section("Sync: two members (" .. label .. ")")
    local world = H.NewWorld(options)
    local alchemy = Recipes(60, 2000)
    local learnedA = Take(alchemy, 40)
    local A = world:NewClient("Alice", { professions = { Copy(ALCHEMY), Copy(HERBALISM) } })
    local B = world:NewClient("Bob", { professions = { Copy(BLACKSMITHING) } })
    world:Login(A)
    world:RunFor(5)
    world:OpenProfession(A, 171, alchemy, learnedA)
    world:RunFor(2)
    world:CloseProfession(A)
    local own = RecordOf(A, A)
    H.check(own and H.SameList(own.p[171].k, learnedA), "Alice read her recipes")
    H.eq(own and own.p[182].k, false, "Herbalism has no recipes")
    world:RunFor(60)
    world:Login(B)
    local done = world:RunUntil(function()
        return HasList(B, A, 171, learnedA) and RecordOf(A, B) ~= nil
    end, 180)
    H.check(done, "Bob got Alice's recipes and Alice got Bob's record")
    world:RunFor(60)
    H.eq(Digests(A), Digests(B), "both hold the same data")
    ReportErrors(world, label)
    return world, A, B
end

TwoMembers({ seed = 2 }, "compressed, full sender names")
TwoMembers({ seed = 3, senderFormat = "short" }, "sender names without realm")
TwoMembers({ seed = 4, encoding = "none" }, "no C_EncodingUtil")
TwoMembers({ seed = 5, compress = false }, "Base64 only")
TwoMembers({ seed = 6, senderFormat = "short", strictWhispers = true }, "WoW Forever: senders without realm, whispers by name only")

-- A guild that logs in one by one, then a newcomer -----------------------------------

H.section("Sync: login wave and a newcomer")
local world = H.NewWorld({ seed = 7 })
local members = {}
local lists = {}
local alchemyAll = Recipes(120, 2000)
for i = 1, 8 do
    local learned = Take(alchemyAll, 20 + i * 10)
    lists[i] = learned
    members[i] = world:NewClient("Member" .. i, { professions = { { sl = 171, r = 100 + i, m = 225, spell = 2259, hasRecipes = true }, Copy(HERBALISM) } })
end
world:AddMember("NoAddon")
for i, client in ipairs(members) do
    world:Login(client)
    world:RunFor(3)
    world:OpenProfession(client, 171, alchemyAll, lists[i])
    world:RunFor(1)
    world:CloseProfession(client)
    world:RunFor(15)
end
world:RunFor(600)
local reference = Digests(members[1])
local agree = true
for i = 2, #members do
    agree = agree and Digests(members[i]) == reference
end
H.check(agree, "everyone who logged in during the wave holds the same data")
local everything = true
for _, viewer in ipairs(members) do
    for i, owner in ipairs(members) do
        everything = everything and HasList(viewer, owner, 171, lists[i])
    end
end
H.check(everything, "everyone has everyone's recipes")

local newcomer = world:NewClient("Newcomer", { professions = {} })
local mark = #world.log + 1
world:Login(newcomer)
world:RunFor(180)
local counts = CountTypes(world, mark)
H.check((counts.O or 0) >= 1 and (counts.O or 0) <= 2, "one or two members offered to sync (" .. tostring(counts.O) .. ")")
local gotAll = true
for i, owner in ipairs(members) do
    gotAll = gotAll and HasList(newcomer, owner, 171, lists[i])
end
H.check(gotAll, "the newcomer received every member's recipes")
H.eq(Digests(newcomer), reference, "the newcomer holds the same data")

H.section("Sync: steady state")
world:RunFor(60)
local veteran = members[3]
world:Logout(veteran)
world:RunFor(30)
mark = #world.log + 1
world:Login(veteran)
world:RunFor(120)
counts = CountTypes(world, mark)
H.eq(counts.H or 0, 1, "a returning member sends one hello")
H.eq((counts.O or 0) + (counts.U or 0) + (counts.multi or 0), 0, "and nothing else is needed")

H.section("Sync: a member who lost their saved data")
local forgetful = members[5]
world:Logout(forgetful)
world:RunFor(30)
forgetful.saved = nil
world:Login(forgetful, { brokenSavedVariables = true })
world:RunUntil(function()
    return HasList(forgetful, forgetful, 171, lists[5])
end, 240)
H.check(HasList(forgetful, forgetful, 171, lists[5]), "their recipe list came back from the guild")
world:RunFor(120)
local kept = true
for _, viewer in ipairs(members) do
    kept = kept and HasList(viewer, forgetful, 171, lists[5])
end
H.check(kept, "nobody lost that member's recipes")
local stillAgree = true
for i = 2, #members do
    stillAgree = stillAgree and Digests(members[i]) == Digests(members[1])
end
H.check(stillAgree, "everyone agrees again")

H.section("Sync: changes while online")
local learner = members[2]
local newRecipe = alchemyAll[#alchemyAll]
world.recipeSkill[newRecipe] = 171
world:FireEvent(learner, "NEW_RECIPE_LEARNED", newRecipe)
world:RunFor(1)
local ownList = RecordOf(learner, learner).p[171].k
H.eq(ownList[#ownList], newRecipe, "a recipe learned with the window closed is added")
world:RunFor(130)
local spread = true
for _, viewer in ipairs(members) do
    local list = RecordOf(viewer, learner).p[171].k
    spread = spread and list[#list] == newRecipe
end
H.check(spread, "the new recipe reached everyone within two minutes")

learner.professions[1].r = learner.professions[1].r + 5
world:FireEvent(learner, "SKILL_LINES_CHANGED")
mark = #world.log + 1
world:RunFor(130)
counts = CountTypes(world, mark)
H.eq(counts.S or 0, 1, "a skill-up is announced with one short message")
local rankSpread = true
for _, viewer in ipairs(members) do
    local record = RecordOf(viewer, learner)
    rankSpread = rankSpread and record.p[171].r == learner.professions[1].r and record.t == RecordOf(learner, learner).t
end
H.check(rankSpread, "everyone has the new skill level")

H.section("Sync: messaging locked down")
local raider = members[4]
raider.lockdown = true
world.recipeSkill[alchemyAll[#alchemyAll - 1]] = 171
world:FireEvent(raider, "NEW_RECIPE_LEARNED", alchemyAll[#alchemyAll - 1])
mark = #world.log + 1
world:RunFor(150)
local fromRaider = 0
for i = mark, #world.log do
    if world.log[i].from == raider.name then
        fromRaider = fromRaider + 1
    end
end
H.eq(fromRaider, 0, "nothing is sent during a lockdown")
raider.lockdown = false
world:RunFor(10)
fromRaider = 0
for i = mark, #world.log do
    if world.log[i].from == raider.name then
        fromRaider = fromRaider + 1
    end
end
H.check(fromRaider >= 1, "the queued message goes out after it")

H.section("Sync: forged and foreign data")
local forger = members[6]
local victim = members[7]
local fake = forger.ns.Pack.Writer()
fake:Byte(string.byte("U"))
fake:UInt(forger.ns.Pack.Hash(GUILD))
forger.ns.Pack.WriteRecord(fake, victim.guid, { t = forger.ns.Now() + 100, p = { [171] = { r = 1, m = 1, k = { 1 } } } })
forger.ns.Comm.Send(fake:Result(), "GUILD", nil, "own")
world:RunFor(10)
H.check(HasList(members[1], victim, 171, lists[7]), "a member cannot announce someone else's data")

H.section("Sync: members who leave")
local leaver = members[8]
world:Logout(leaver)
world:RemoveMember(leaver.key)
world:RunFor(10)
H.check(RecordOf(members[1], leaver) ~= nil, "a member who just left is kept for a while")
world.base = world.base + 31 * 86400
for _, client in ipairs(members) do
    if client.loggedIn then
        world:FireEvent(client, "GUILD_ROSTER_UPDATE", true)
    end
end
world:RunFor(5)
H.eq(RecordOf(members[1], leaver), nil, "after a month away they are dropped")
ReportErrors(world, "wave")

-- A large guild ------------------------------------------------------------------------

H.section("Sync: a large guild and an empty newcomer")
local big = H.NewWorld({ seed = 11, compress = false })
local crowd = {}
local tailoring, cooking = Recipes(200, 3000), Recipes(80, 8000)
for i = 1, 40 do
    crowd[i] = big:NewClient("Crowd" .. i, { professions = {
        { sl = 197, r = 200, m = 300, spell = 3908, hasRecipes = true },
        { sl = 182, r = 300, m = 300, spell = 2366, hasRecipes = false },
        nil, nil,
        { sl = 185, r = 150, m = 300, spell = 2550, hasRecipes = true },
    } })
end
for i = 1, 20 do
    big:AddMember("Silent" .. i)
end
for i, client in ipairs(crowd) do
    big:Login(client)
    big:RunFor(1)
    big:OpenProfession(client, 197, tailoring, Take(tailoring, 100 + i * 2))
    big:RunFor(1)
    big:OpenProfession(client, 185, cooking, Take(cooking, 40 + i))
    big:RunFor(1)
    big:CloseProfession(client)
    big:RunFor(4)
end
big:RunFor(900)
local bigReference = Digests(crowd[1])
local bigAgree = 0
for _, client in ipairs(crowd) do
    if Digests(client) == bigReference then
        bigAgree = bigAgree + 1
    end
end
H.eq(bigAgree, #crowd, "all 40 members converge after the login wave")
local empty = big:NewClient("Fresh", { professions = {} })
local start = big.now
local logStart = #big.log + 1
big:Login(empty)
local complete = big:RunUntil(function()
    for _, owner in ipairs(crowd) do
        if not HasList(empty, owner, 197) then
            return false
        end
    end
    return true
end, 900)
H.check(complete, "the newcomer receives all 40 records")
local whispers = 0
for i = logStart, #big.log do
    if big.log[i].channel == "WHISPER" then
        whispers = whispers + 1
    end
end
print(("  info: full sync of 40 members took %d s and %d whisper chunks; %d throttle answers overall"):format(big.now - start, whispers, big.stats.throttled))
ReportErrors(big, "large guild")

-- Throttled whispers, a responder that leaves, two newcomers at once -----------------

local function SmallGuild(options, count)
    local w = H.NewWorld(options)
    local clients, owned = {}, {}
    local all = Recipes(150, 2000)
    for i = 1, count do
        clients[i] = w:NewClient("Peer" .. i, { professions = { { sl = 171, r = 200, m = 300, spell = 2259, hasRecipes = true } } })
        owned[i] = Take(all, 60 + i * 5)
    end
    for i, client in ipairs(clients) do
        w:Login(client)
        w:RunFor(2)
        w:OpenProfession(client, 171, all, owned[i])
        w:RunFor(1)
        w:CloseProfession(client)
        w:RunFor(5)
    end
    w:RunFor(600)
    return w, clients, owned
end

local function HasEveryone(viewer, clients, owned)
    for i, owner in ipairs(clients) do
        if not HasList(viewer, owner, 171, owned[i]) then
            return false
        end
    end
    return true
end

H.section("Sync: the server also throttles whispers")
do
    local w, clients, owned = SmallGuild({ seed = 21, compress = false, whisperLimit = { cap = 3, rate = 1 } }, 10)
    local fresh = w:NewClient("Late", { professions = {} })
    w:Login(fresh)
    local ok = w:RunUntil(function()
        return HasEveryone(fresh, clients, owned)
    end, 900)
    H.check(ok, "the sync completes despite whisper throttling")
    H.check(w.stats.throttled > 0, "the server did throttle (" .. w.stats.throttled .. " answers)")
    ReportErrors(w, "throttled whispers")
end

H.section("Sync: the responder logs out mid-sync")
do
    local w, clients, owned = SmallGuild({ seed = 22, compress = false, whisperLimit = { cap = 2, rate = 0.5 } }, 6)
    local fresh = w:NewClient("Unlucky", { professions = {} })
    local mark = #w.log + 1
    w:Login(fresh)
    -- Wait for the first record batch, then log the responder out.
    local responder
    w:RunUntil(function()
        for i = mark, #w.log do
            local entry = w.log[i]
            if entry.channel == "WHISPER" and entry.target == fresh.key then
                responder = w:FindClient(entry.from)
                return true
            end
        end
        return false
    end, 120)
    H.check(responder ~= nil, "someone started sending")
    if responder then
        w:Logout(responder)
    end
    local ok = w:RunUntil(function()
        for i, owner in ipairs(clients) do
            if owner ~= responder and not HasList(fresh, owner, 171, owned[i]) then
                return false
            end
        end
        return true
    end, 900)
    H.check(ok, "another member finishes the sync")
    ReportErrors(w, "responder leaves")
end

H.section("Sync: two newcomers at once")
do
    local w, clients, owned = SmallGuild({ seed = 23, compress = false }, 6)
    local first = w:NewClient("Twin1", { professions = {} })
    local second = w:NewClient("Twin2", { professions = {} })
    w:Login(first)
    w:Login(second)
    local ok = w:RunUntil(function()
        return HasEveryone(first, clients, owned) and HasEveryone(second, clients, owned)
    end, 600)
    H.check(ok, "both newcomers get everything")
    ReportErrors(w, "two newcomers")
end

-- Fixes found in review -----------------------------------------------------------

H.section("Sync: the guild is renamed")
do
    local w, clients, owned = SmallGuild({ seed = 31, compress = false }, 4)
    w.guildName = "Renamed Guild"
    for _, client in ipairs(clients) do
        w:FireEvent(client, "PLAYER_GUILD_UPDATE")
    end
    local newKey = "Renamed Guild"
    local function RecordIn(viewer, owner)
        local guild = viewer.env.GuildProfessionsRecipesDB.guilds[newKey]
        return guild and guild.members[owner.guid]
    end
    local ok = w:RunUntil(function()
        for _, viewer in ipairs(clients) do
            for i, owner in ipairs(clients) do
                local record = RecordIn(viewer, owner)
                if not record or not H.SameList(record.p[171].k, owned[i]) then
                    return false
                end
            end
        end
        return true
    end, 600)
    H.check(ok, "everyone's records, recipes included, are shared again under the new name")
    ReportErrors(w, "rename")
end

H.section("Scanner: only the filtered list is available")
do
    local w = H.NewWorld({ seed = 32 })
    local client = w:NewClient("Filter", { professions = { { sl = 171, r = 100, m = 300, spell = 2259, hasRecipes = true } } })
    client.noAllRecipeIDs = true
    w:Login(client)
    w:RunFor(5)
    local all = { 11, 22, 33, 44, 55 }
    w:OpenProfession(client, 171, all, all)
    w:RunFor(2)
    H.check(H.SameList(RecordOf(client, client).p[171].k, all), "the filtered list is read when it is all there is")
    client.session.filtered = { 22 }
    w:FireEvent(client, "TRADE_SKILL_LIST_UPDATE")
    w:RunFor(2)
    H.check(H.SameList(RecordOf(client, client).p[171].k, all), "a search in the window does not cut the list")
    client.session.all = { 11, 22, 33, 44, 55, 66 }
    client.session.learned[66] = true
    client.session.filtered = { 66 }
    w:FireEvent(client, "TRADE_SKILL_LIST_UPDATE")
    w:RunFor(2)
    H.check(H.SameList(RecordOf(client, client).p[171].k, { 11, 22, 33, 44, 55, 66 }), "new recipes are still added")
    ReportErrors(w, "filtered list")
end

H.section("Scanner: a passing 'no recipes' answer at login")
do
    local w = H.NewWorld({ seed = 33 })
    local client = w:NewClient("Flaky", { professions = { { sl = 171, r = 100, m = 300, spell = 2259, hasRecipes = true } } })
    w:Login(client)
    w:RunFor(5)
    w:OpenProfession(client, 171, { 5, 6, 7 }, { 5, 6, 7 })
    w:RunFor(2)
    w:CloseProfession(client)
    w:RunFor(60)
    w:Logout(client)
    client.professions[1].hasRecipes = false
    w:Login(client)
    w:RunFor(3)
    client.professions[1].hasRecipes = true
    w:RunFor(30)
    H.check(H.SameList(RecordOf(client, client).p[171].k, { 5, 6, 7 }), "the known list survives")
    ReportErrors(w, "flaky login")
end

H.section("Roster: an empty read and strangers")
do
    local w, clients, owned = SmallGuild({ seed = 34, compress = false }, 3)
    local viewer = clients[1]
    local saved = w.roster
    w.roster = {}
    w:FireEvent(viewer, "GUILD_ROSTER_UPDATE", false)
    w:RunFor(2)
    H.check(viewer.ns.Roster.IsKnownGUID(clients[2].guid), "an empty roster read keeps the last one")
    w.roster = saved
    local stranger = w:NewClient("Stranger", { professions = { { sl = 171, r = 1, m = 75, spell = 2259, hasRecipes = true } } })
    w:RemoveMember(stranger.key)
    w:Login(stranger)
    w:RunFor(5)
    local fake = stranger.ns.Pack.Writer()
    fake:Byte(string.byte("U"))
    fake:UInt(stranger.ns.Pack.Hash(GUILD))
    stranger.ns.Pack.WriteRecord(fake, stranger.guid, { t = stranger.ns.Now(), p = { [171] = { r = 1, m = 1, k = { 1 } } } })
    stranger.ns.Comm.Send(fake:Result(), "WHISPER", viewer.key, "own")
    w:RunFor(10)
    H.eq(RecordOf(viewer, stranger), nil, "whispers from outside the guild are ignored")
    ReportErrors(w, "roster")
end

H.section("Scanner: one reminder for every unread profession")
do
    local w = H.NewWorld({ seed = 35 })
    local client = w:NewClient("Busy", { professions = {
        { sl = 171, r = 1, m = 75, spell = 2259, hasRecipes = true },
        { sl = 164, r = 1, m = 75, spell = 2018, hasRecipes = true },
        { sl = 182, r = 1, m = 75, spell = 2366, hasRecipes = false },
    } })
    w:Login(client)
    w:RunFor(40)
    local reminders = {}
    for _, line in ipairs(client.printed) do
        if line:find("open these profession windows", 1, true) then
            reminders[#reminders + 1] = line
        end
    end
    H.eq(#reminders, 1, "a single reminder line")
    H.check(reminders[1] and reminders[1]:find("Skill171, Skill164", 1, true) ~= nil, "it names both crafting professions, not Herbalism")
    w:Logout(client)
    w:Login(client)
    w:RunFor(40)
    local again = 0
    for _, line in ipairs(client.printed) do
        if line:find("open these profession windows", 1, true) then
            again = again + 1
        end
    end
    H.eq(again, 0, "and it is not repeated at the next login")
    ReportErrors(w, "reminder")
end

-- WoW Forever: names with spaces, several realms, a roster without realms ------------

H.section("Forever: a guild on two realms")
do
    local w = H.NewWorld({ seed = 41, guildRealm = "RealmOne", senderFormat = "short", strictWhispers = true })
    local all = Recipes(80, 2000)
    local people = {
        w:NewClient("Alice Smith", { realm = "RealmTwo", professions = { { sl = 165, r = 112, m = 150, spell = 3104, hasRecipes = true } } }),
        w:NewClient("Bob Jones", { realm = "RealmOne", professions = { { sl = 165, r = 50, m = 75, spell = 3104, hasRecipes = true } } }),
        w:NewClient("Carol White", { realm = "RealmOne", professions = { { sl = 197, r = 20, m = 75, spell = 3908, hasRecipes = true } } }),
    }
    local owned = { Take(all, 40), Take(all, 20), Take(all, 10) }
    for i, client in ipairs(people) do
        w:Login(client)
        w:RunFor(2)
        w:OpenProfession(client, client.professions[1].sl, all, owned[i])
        w:RunFor(1)
        w:CloseProfession(client)
        w:RunFor(10)
    end
    w:RunFor(300)
    local everyone = true
    for _, viewer in ipairs(people) do
        H.eq(viewer.ns.Roster.guildKey, GUILD, viewer.name .. " knows the guild by its name alone")
        for i, owner in ipairs(people) do
            everyone = everyone and HasList(viewer, owner, owner.professions[1].sl, owned[i])
        end
    end
    H.check(everyone, "members on both realms share their recipes")
    local record = RecordOf(people[2], people[1])
    H.eq(record and record.n, "Alice Smith", "the name with its space travels with the record")
    H.eq(people[1].ns.Roster.GUIDOfSender("Bob Jones-RealmOne"), people[2].guid, "a sender is matched to the roster without its realm")
    ReportErrors(w, "two realms")
end

H.section("Forever: two members with the same name")
do
    local w = H.NewWorld({ seed = 42 })
    local all = Recipes(40, 2000)
    local first = w:NewClient("John Smith", { realm = "RealmA", professions = { { sl = 171, r = 10, m = 75, spell = 2259, hasRecipes = true } } })
    local second = w:NewClient("John Smith", { realm = "RealmB", professions = { { sl = 171, r = 20, m = 75, spell = 2259, hasRecipes = true } } })
    local other = w:NewClient("Jane Doe", { professions = { { sl = 171, r = 30, m = 75, spell = 2259, hasRecipes = true } } })
    for _, client in ipairs({ first, second, other }) do
        w:Login(client)
        w:RunFor(2)
        w:OpenProfession(client, 171, all, Take(all, 10))
        w:RunFor(1)
        w:CloseProfession(client)
        w:RunFor(5)
    end
    w:RunFor(300)
    H.eq(RecordOf(other, first), nil, "a name shared by two members is not trusted")
    H.check(HasList(first, other, 171), "the others still sync")
    ReportErrors(w, "same name")
end

H.section("Scanner: an alt reads its recipes from the catalog")
do
    local w = H.NewWorld({ seed = 43 })
    local all = Recipes(60, 2000)
    local main = w:NewClient("Main Char", { professions = { { sl = 165, r = 100, m = 150, spell = 3104, hasRecipes = true } } })
    w:Login(main)
    w:RunFor(5)
    w:OpenProfession(main, 165, all, Take(all, 30))
    w:RunFor(2)
    w:CloseProfession(main)
    w:Logout(main)
    -- Same account: the alt starts from the account's saved file.
    local alt = w:NewClient("Alt Char", { saved = main.saved, professions = { { sl = 165, r = 40, m = 75, spell = 3104, hasRecipes = true } } })
    alt.knownSpells = {}
    local learned = Take(all, 12)
    for _, id in ipairs(learned) do
        alt.knownSpells[id] = true
    end
    w:Login(alt)
    w:RunFor(40)
    H.check(HasList(alt, alt, 165, learned), "the alt knows its recipes without opening the window")
    local reminded = false
    for _, line in ipairs(alt.printed) do
        reminded = reminded or line:find("open these profession windows", 1, true) ~= nil
    end
    H.check(not reminded, "and is not asked to open it")
    ReportErrors(w, "catalog")
end

H.section("Forever: our own two-part name")
do
    local w = H.NewWorld({ seed = 45, senderFormat = "short", strictWhispers = true })
    local me = w:NewClient("Alice Smith", { realm = "RealmTwo", professions = { { sl = 165, r = 112, m = 150, spell = 3104, hasRecipes = true } } })
    local mate = w:NewClient("Bob Jones", { realm = "RealmOne", professions = { { sl = 165, r = 50, m = 75, spell = 3104, hasRecipes = true } } })
    w:Login(mate)
    w:RunFor(3)
    w:OpenProfession(mate, 165, { 1, 2, 3 }, { 1, 2 })
    w:RunFor(1)
    w:CloseProfession(mate)
    w:RunFor(60)
    w:Login(me)
    w:RunFor(1)
    H.eq(me.ns.playerKey, "Alice Smith-RealmTwo", "both parts of our name sign our messages")
    w:RunFor(120)
    H.check(HasList(me, mate, 165, { 1, 2 }), "the login sync accepts the offer made to us")
    H.eq((RecordOf(mate, me) or {}).n, "Alice Smith", "our full name is shared")
    local echoes = 0
    for _, line in ipairs(me.ns.debugLog) do
        if line:find("rejected", 1, true) or line:find("bad message", 1, true) then
            echoes = echoes + 1
        end
    end
    H.eq(echoes, 0, "no confusion with our own messages")
    ReportErrors(w, "two-part name")
end

H.section("Comm: the 'No player named' line after a failed whisper")
do
    local w = H.NewWorld({ seed = 46, senderFormat = "short", strictWhispers = true })
    local a = w:NewClient("Ana Lopez", {})
    w:Login(a)
    w:RunFor(15)
    a.ns.Comm.Send(a.ns.Pack.Writer():Result() .. "x", "WHISPER", a.key, "control")
    w:RunFor(2)
    H.eq(#w.systemShown, 0, "a whisper that cannot arrive leaves no line in the chat")
    ReportErrors(w, "offline filter")
end

H.section("Fresh install")
do
    local w = H.NewWorld({ seed = 47, senderFormat = "short", strictWhispers = true })
    local fresh = w:NewClient("Nuevo Miembro", { professions = {
        { sl = 165, r = 1, m = 75, spell = 3104, hasRecipes = true },
        { sl = 393, r = 1, m = 75, spell = 1278068, hasRecipes = true },
    } })
    w:Login(fresh)
    w:RunFor(60)
    H.eq(#fresh.printed, 1, "a fresh install says one thing in the chat")
    H.check((fresh.printed[1] or ""):find("open these profession windows", 1, true) ~= nil, "the reminder to open the profession windows")
    w:OpenProfession(fresh, 165, { 1, 2, 3 }, { 1 })
    w:RunFor(2)
    w:CloseProfession(fresh)
    w:RunFor(60)
    H.eq(#fresh.printed, 1, "nothing more after opening a window")
    ReportErrors(w, "fresh install")
end

H.section("Scanner: known spells the window does not count as recipes")
do
    local w = H.NewWorld({ seed = 48, senderFormat = "short", strictWhispers = true })
    local all = { 101, 102, 103, 104, 105 }
    local learned = { 101, 102 }
    local phantom = 105 -- a spell the character knows, not a learned recipe
    local main = w:NewClient("Main Char", { professions = { { sl = 393, r = 196, m = 225, spell = 1278068, hasRecipes = true } } })
    main.knownSpells = { [101] = true, [102] = true, [phantom] = true }
    w:Login(main)
    w:RunFor(5)
    w:OpenProfession(main, 393, all, learned)
    w:RunFor(2)
    w:CloseProfession(main)
    w:RunFor(60)
    H.check(HasList(main, main, 393, learned), "the window's list is the reference")
    w:Logout(main)
    local mark = #w.log + 1
    w:Login(main)
    w:RunFor(60)
    H.check(HasList(main, main, 393, learned), "the spell book does not add the phantom at the next login")
    local sent = 0
    for i = mark, #w.log do
        if w.log[i].from == main.name and w.log[i].channel == "GUILD" then
            sent = sent + 1
        end
    end
    H.eq(sent, 1, "so logging in announces nothing new (just the hello)")
    w:Logout(main)
    local alt = w:NewClient("Alt Char", { saved = main.saved, professions = { { sl = 393, r = 50, m = 75, spell = 1278068, hasRecipes = true } } })
    alt.knownSpells = { [103] = true, [phantom] = true }
    w:Login(alt)
    w:RunFor(40)
    H.check(HasList(alt, alt, 393, { 103 }), "an alt reading the catalog skips the phantom too")
    ReportErrors(w, "phantoms")
end
