local H = ...

-- Members on the last release and members on this version share one guild:
-- both must keep talking. The release is taken from its git tag
-- (H.Release).
local RELEASE = "v0.9.1"

H.section("Versions: against " .. RELEASE)
local old = H.Release(RELEASE)
if not old then
    print("   NOTE: " .. RELEASE .. " could not be extracted with git: skipped")
    return
end
local OLD = { old }

local function Errors(world, label)
    H.eq(#world.errors, 0, "no errors: " .. label)
    for _, err in ipairs(world.errors) do
        print("   " .. err)
    end
    world.errors = {}
end

local function RecordOf(viewer, owner)
    local guild = viewer.ns.Data.GetGuild("Test Guild")
    return guild and guild.members[owner.guid]
end

local function StateOf(client, requester, id)
    local view = client.ns.Orders.Find(client.ns.Data.CurrentGuild(false), requester.guid, id)
    return view and view.state
end

for _, case in ipairs({
    { "a tailor on this version, a cook on " .. RELEASE, nil, OLD },
    { "a tailor on " .. RELEASE .. ", a cook on this version", OLD, nil },
}) do
    local label, tailorAddons, cookAddons = case[1], case[2], case[3]
    local world = H.NewWorld({ seed = #label, senderFormat = "short", strictWhispers = true })
    local tailor = world:NewClient("Tailor Member", {
        addons = tailorAddons, professions = { { sl = 197, r = 100, m = 150, spell = 3908, hasRecipes = true } },
    })
    local cook = world:NewClient("Cook Member", {
        addons = cookAddons, professions = { { sl = 185, r = 40, m = 75, spell = 2550, hasRecipes = true } },
    })
    world:Login(tailor)
    world:RunFor(5)
    world:OpenProfession(tailor, 197, { 21, 22 }, { 21, 22 })
    world:RunFor(1)
    world:CloseProfession(tailor)
    world:Login(cook)
    world:RunFor(5)
    world:OpenProfession(cook, 185, { 31 }, { 31 })
    world:RunFor(1)
    world:CloseProfession(cook)
    world:RunFor(240)
    local record = RecordOf(cook, tailor)
    H.check(record ~= nil and record.p[197] ~= nil and H.SameList(record.p[197].k, { 21, 22 }), label .. ": the cook has the tailor's recipes")
    record = RecordOf(tailor, cook)
    H.check(record ~= nil and record.p[185] ~= nil and H.SameList(record.p[185].k, { 31 }), label .. ": and the tailor the cook's")

    -- A skill-up goes out as a short message.
    tailor.professions[1].r = 105
    world:FireEvent(tailor, "SKILL_LINES_CHANGED")
    world:RunFor(130)
    record = RecordOf(cook, tailor)
    H.check(record ~= nil and record.p[197].r == 105 and record.t == RecordOf(tailor, tailor).t,
        label .. ": a skill-up reaches the cook, at the same version")

    -- An order goes out within seconds, and its answer too.
    local id = cook.ns.Orders.Create({ sl = 197, r = 21, q = 2 })
    H.check(id ~= nil, label .. ": the cook places an order")
    world:RunFor(10)
    H.eq(StateOf(tailor, cook, id), "pending", label .. ": the tailor sees it within seconds")
    H.check(tailor.ns.Orders.Accept(cook.guid, id) ~= nil, label .. ": and accepts it")
    world:RunFor(10)
    H.eq(StateOf(cook, cook, id), "accepted", label .. ": the cook sees it accepted")
    Errors(world, label)
end
