local H = ...

local DAY = 86400

-- A guild where Alice and Bob know Tailoring recipe 21, only Alice knows 22,
-- and Carol cooks.
local function TailorsWorld(seed, withGuildWindow)
    local w = H.NewWorld({ seed = seed, communities = withGuildWindow and H.FakeCommunities or nil })
    local alice = w:NewClient("Alice", { professions = { { sl = 197, r = 100, m = 150, spell = 3908, hasRecipes = true } } })
    local bob = w:NewClient("Bob", { professions = { { sl = 197, r = 60, m = 75, spell = 3908, hasRecipes = true } } })
    local carol = w:NewClient("Carol", { professions = { { sl = 185, r = 40, m = 75, spell = 2550, hasRecipes = true } } })
    for _, client in ipairs({ alice, bob, carol }) do
        w:Login(client)
    end
    w:RunFor(5)
    w:OpenProfession(alice, 197, { 21, 22 }, { 21, 22 })
    w:RunFor(1)
    w:CloseProfession(alice)
    w:OpenProfession(bob, 197, { 21, 22 }, { 21 })
    w:RunFor(1)
    w:CloseProfession(bob)
    w:OpenProfession(carol, 185, { 31 }, { 31 })
    w:RunFor(1)
    w:CloseProfession(carol)
    w:RunFor(200)
    return w, alice, bob, carol
end

local function Guild(client)
    return client.ns.Data.CurrentGuild(false)
end

local function ViewOf(client, requester, id)
    return client.ns.Orders.Find(Guild(client), requester.guid, id)
end

local function StateOf(client, requester, id)
    local view = ViewOf(client, requester, id)
    return view and view.state, view and view.crafter
end

H.section("Orders: the record format")
do
    local w = H.NewWorld({ seed = 81 })
    local solo = w:NewClient("Solo", {})
    w:Login(solo)
    local Pack, Data = solo.ns.Pack, solo.ns.Data
    local now = solo.env.GetServerTime()
    local guid = "Player-1-000000A1"
    local record = { t = now, av = 900, n = "Solo", p = { [197] = { r = 1, m = 75, o = 1, k = { 21 } } },
        o = { [3] = { sl = 197, r = 21, q = 2, d = "Player-1-000000B2", m = true, tip = 12345, note = "Two, please", c = now - 10, u = now - 5, s = 0 } },
        a = { ["Player-1-000000C3:4"] = { s = 4, u = now - 2, ou = now - 3, n = 2, p = 3000 }, ["Player-1-000000C3:5"] = { s = 1, u = now - 2, ou = now - 3 } } }
    local key, copy = Pack.ReadRecord(Pack.Reader(Pack.RecordString(guid, record)))
    H.eq(key, guid, "a record with orders reads back")
    H.check(copy.o and copy.o[3] and copy.o[3].d == "Player-1-000000B2" and copy.o[3].m == true and copy.o[3].tip == 12345
        and copy.o[3].note == "Two, please" and copy.o[3].e == nil, "with its orders, which do not expire")
    local answer, plain = copy.a and copy.a["Player-1-000000C3:4"], copy.a and copy.a["Player-1-000000C3:5"]
    H.check(answer and answer.ou == now - 3 and answer.s == 4 and answer.n == 2 and answer.p == 3000 and plain and plain.n == nil
        and plain.p == nil, "and its answers, with the items delivered and the tip received")
    H.check(Data.CleanRecord(copy, now) ~= nil, "and passes the checks")

    -- 0.8 wrote the days an order lasted, and no deliveries.
    record.o[3].e = 7
    local _, eight = Pack.ReadRecord(Pack.Reader(Pack.RecordString(guid, record, 3)), 3)
    H.check(eight.o[3].e == 7 and eight.o[3].note == "Two, please" and eight.a["Player-1-000000C3:4"].n == nil
        and eight.a["Player-1-000000C3:4"].ou == now - 3, "format 3 (0.8) still reads, with its days")
    H.check(Data.CleanRecord(eight, now) ~= nil, "and passes the checks")
    record.o[3].e = nil

    local _, old = Pack.ReadRecord(Pack.Reader(Pack.RecordString(guid, record, 2)), 2)
    H.check(old.o == nil and old.a == nil and old.p[197] ~= nil, "format 2 (0.7) has professions, no orders")
    record.o, record.a = nil, nil
    local _, unknown = Pack.ReadRecord(Pack.Reader(Pack.RecordString(guid, record)))
    H.check(unknown.o == nil and unknown.a == nil, "unknown orders stay unknown, not none")
    record.o, record.a = {}, {}
    local _, none = Pack.ReadRecord(Pack.Reader(Pack.RecordString(guid, record)))
    H.check(none.o ~= nil and next(none.o) == nil, "no orders reads as none")

    local function With(field, value)
        local order = { sl = 197, r = 21, q = 1, m = false, tip = 0, note = "", c = now, u = now, s = 0 }
        order[field] = value
        return Data.CleanRecord({ t = now, p = {}, o = { [1] = order } }, now)
    end
    H.check(With("q", 0) == nil and With("q", 1000) == nil, "quantities from 1 to 999")
    H.check(With("e", 7) ~= nil and With("e", 0) == nil and With("e", 31) == nil, "0.8's days, when given, from 1 to 30")
    H.check(With("d", "Bob") == nil and With("s", 3) == nil and With("note", ("x"):rep(201)) == nil, "a GUID, a known state, a short note")
    H.check(With("u", now - 10) == nil and With("c", now + 3600) == nil, "and sensible times")
    local cleaned = With("note", "|cffff0000red|r\1bell\nline")
    H.eq(cleaned and cleaned.o[1].note, "cffff0000redrbell\nline", "notes lose escape sequences and control characters, not line breaks")
    H.check(Data.CleanRecord({ t = now, p = {}, a = { ["Bob:1"] = { s = 1, u = now, ou = now } } }, now) == nil, "answers are keyed by GUID and id")
    local function Answered(s, n, tip)
        return Data.CleanRecord({ t = now, p = {}, a = { [guid .. ":1"] = { s = s, u = now, ou = now, n = n, p = tip } } }, now)
    end
    H.check(Answered(4, 3) ~= nil and Answered(5) == nil and Answered(0) == nil, "answers have a known state")
    H.check(Answered(1, 999) ~= nil and Answered(1, 1000) == nil and Answered(1, -1) == nil, "and deliver up to 999 items")
    H.check(Answered(1, 0, 100000000) ~= nil and Answered(1, 0, 100000001) == nil and Answered(1, 0, 1.5) == nil,
        "and receive up to the largest tip")

    -- Our own record: lost orders come back from the guild's copy, and a
    -- newer copy that knows nothing of them does not wipe them.
    local guild = { members = {} }
    guild.members[solo.guid] = { t = now, p = {} }
    Data.MergeRecord(guild, solo.guid, { t = now - 50, p = {}, o = { [1] = { sl = 1, r = 2, q = 1, c = now, u = now, s = 0 } }, a = {} })
    H.check(guild.members[solo.guid].o and guild.members[solo.guid].o[1] ~= nil, "our lost orders are adopted from the guild's copy")
    guild.members[guid] = { t = now - 10, p = {}, o = { [9] = { sl = 1, r = 2, q = 1, c = now, u = now, s = 0 } } }
    Data.MergeRecord(guild, guid, { t = now, p = {} })
    H.check(guild.members[guid].t == now and guild.members[guid].o and guild.members[guid].o[9] ~= nil,
        "a newer copy without orders keeps the ones known")
end

H.section("Orders: states")
do
    local w = H.NewWorld({ seed = 82 })
    local solo = w:NewClient("Solo", {})
    w:Login(solo)
    local Orders = solo.ns.Orders
    local now = 1800000000
    local order = { sl = 197, r = 21, q = 3, c = now - 100, u = now - 50, s = 0 }
    local function Answer(guid, s, u, ou, n)
        return { guid = guid, answer = { s = s, u = u, ou = ou or order.u, n = n } }
    end
    H.eq(Orders.State(order, "R", nil), "pending", "nobody answered: pending")
    local state, crafter = Orders.State(order, "R", { Answer("B", 1, now - 10), Answer("A", 1, now - 20) })
    H.check(state == "accepted" and crafter == "A", "two acceptances: the earlier one wins")
    state, crafter = Orders.State(order, "R", { Answer("B", 1, now - 10), Answer("A", 1, now - 10) })
    H.check(crafter == "A", "at the same second, the same one on every client")
    local delivered
    state, _, delivered = Orders.State(order, "R", { Answer("A", 1, now - 20, nil, 2) })
    H.check(state == "accepted" and delivered == 2, "with the items delivered so far")
    H.eq(Orders.State(order, "R", { Answer("A", 3, now - 20) }), "completed", "completed")
    H.eq(Orders.State(order, "R", { Answer("A", 1, now - 20, order.u - 1) }), "pending", "an answer to an older version does not count")
    H.eq(Orders.State(order, "R", { Answer("R", 1, now - 20) }), "pending", "nor the requester's own")
    order.m = true
    H.eq(Orders.State(order, "R", { Answer("A", 1, now - 20) }), "materials", "the requester provides the materials: accepted, it waits for them")
    H.eq(Orders.State(order, "R", { Answer("A", 4, now - 20) }), "accepted", "once received, it is accepted")
    H.eq(Orders.State(order, "R", { Answer("A", 3, now - 20) }), "completed", "and then completed")
    order.m = false
    H.eq(Orders.State(order, "R", nil, now + 365 * DAY), "pending", "a year later it is still pending: orders do not expire")
    order.d = "B"
    H.eq(Orders.State(order, "R", { Answer("A", 1, now - 20) }), "pending", "a directed order: only its member's answer counts")
    H.eq(Orders.State(order, "R", { Answer("B", 2, now - 20) }), "denied", "denied")
    -- A release: a refusal stamped with the order's own time.
    local releaser
    state, crafter, _, _, releaser = Orders.State(order, "R", { Answer("B", 2, order.u) })
    H.check(state == "released" and releaser == "B" and crafter == nil, "released by its member, who is no longer its crafter")
    H.eq(Orders.State(order, "R", { Answer("A", 2, order.u) }), "pending", "a directed order: only its member's release counts")
    order.d = nil
    state, _, _, _, releaser = Orders.State(order, "R", { Answer("B", 2, order.u), Answer("A", 2, order.u) })
    local _, _, _, _, again = Orders.State(order, "R", { Answer("A", 2, order.u), Answer("B", 2, order.u) })
    H.check(state == "released" and releaser == "A" and again == "A",
        "an open order: released by anyone, the same one named on every client")
    H.eq(Orders.State(order, "R", { Answer("B", 2, now - 20) }), "pending", "an open order is never declined")
    H.eq(Orders.State(order, "R", { Answer("B", 2, order.u), Answer("A", 1, now - 10) }), "accepted",
        "released by one, accepted by another (on an older version): accepted")
    H.eq(Orders.State(order, "R", { Answer("B", 2, order.u - 1, order.u - 1) }), "pending", "the release of an older version does not count")
    H.eq(Orders.State(order, "R", { Answer("R", 2, order.u) }), "pending", "nor the requester's own")
    order.d = "B"
    order.s = 1
    H.eq(Orders.State(order, "R", { Answer("B", 1, now - 20) }), "cancelled", "cancelled")
    order.s = 2
    H.eq(Orders.State(order, "R", nil), "finished", "finished")
end

H.section("Orders: an open order")
do
    local w, alice, bob, carol = TailorsWorld(83)
    local id = carol.ns.Orders.Create({ sl = 197, r = 21, q = 3, m = true, tip = 5000, note = "For my alt" })
    H.eq(id, 1, "Carol places an order")
    w:RunFor(10)
    H.eq(StateOf(alice, carol, 1), "pending", "it reaches the guild within seconds")
    H.eq(#alice.ns.Orders.Open(Guild(alice), true), 1, "in Alice's list of orders she can make")
    H.eq(#carol.ns.Orders.Open(Guild(carol)), 0, "not in Carol's own open list")
    H.eq(#carol.ns.Orders.Open(Guild(carol), false, true), 1, "unless she asks to see hers")
    H.eq(#carol.ns.Orders.Mine(Guild(carol)), 1, "but in her requested orders")
    H.check(carol.ns.Orders.Accept(carol.guid, 1) == nil, "Carol cannot take her own order")

    -- Alice and Bob accept before hearing of each other.
    H.check(alice.ns.Orders.Accept(carol.guid, 1) and bob.ns.Orders.Accept(carol.guid, 1), "Alice and Bob both accept")
    w:RunFor(10)
    local _, a = StateOf(alice, carol, 1)
    local _, b = StateOf(bob, carol, 1)
    local state, c = StateOf(carol, carol, 1)
    H.check(state == "materials" and a == b and b == c and (c == alice.guid or c == bob.guid),
        "every client agrees on one crafter, who waits for Carol's materials")
    local crafter = c == alice.guid and alice or bob
    local other = crafter == alice and bob or alice
    H.check(#crafter.ns.Orders.ForMe(Guild(crafter)) == 1 and #other.ns.Orders.ForMe(Guild(other)) == 0, "it is pending for its crafter only")
    H.check(carol.ns.Orders.Modify(1, { sl = 197, r = 21, q = 1 }) == nil, "once taken, Carol cannot modify it")
    H.check(other.ns.Orders.Receive(carol.guid, 1) == nil and other.ns.Orders.Complete(carol.guid, 1) == nil,
        "only its crafter receives the materials or completes it")
    H.check(crafter.ns.Orders.Receive(carol.guid, 1), "the crafter marks the materials received")
    w:RunFor(10)
    H.eq(StateOf(carol, carol, 1), "accepted", "Carol sees it accepted")
    H.check(crafter.ns.Orders.Receive(carol.guid, 1) == nil, "materials are received once")

    H.check(crafter.ns.Orders.Complete(carol.guid, 1), "the crafter marks it completed")
    w:RunFor(10)
    H.eq(StateOf(carol, carol, 1), "completed", "Carol sees it completed")
    H.eq(select(2, carol.ns.Orders.Finish(1)), "tip", "she cannot finish it before its crafter has the tip")
    H.check(other.ns.Orders.ConfirmTip(carol.guid, 1) == nil, "only its crafter confirms the tip")
    H.check(crafter.ns.Orders.ConfirmTip(carol.guid, 1), "the crafter confirms it")
    H.check(crafter.ns.Orders.ConfirmTip(carol.guid, 1) == nil, "once")
    w:RunFor(10)
    H.check(carol.ns.Orders.Finish(1), "and Carol finishes it")
    w:RunFor(10)
    H.eq(StateOf(alice, carol, 1), "finished", "finished everywhere")
    H.eq(#w.errors, 0, "open order: no Lua errors")
end

H.section("Orders: a directed order")
do
    local w, alice, bob, carol = TailorsWorld(84)
    local Orders = carol.ns.Orders
    H.eq(#Orders.Crafters(Guild(carol), 197, 22), 1, "only Alice knows recipe 22")
    local crafters = Orders.Crafters(Guild(carol), 197, 21, "bO")
    H.check(#crafters == 1 and crafters[1].guid == bob.guid, "the member search matches part of a name, in any case")

    w:Logout(bob)
    w:RunFor(15)
    H.eq(Orders.Create({ sl = 197, r = 21, d = bob.guid, note = "" }), 1, "Carol directs an order to Bob, who is offline")
    w:RunFor(10)
    w:Logout(carol)
    w:RunFor(15)
    w:Login(bob)
    w:RunUntil(function()
        return StateOf(bob, carol, 1) ~= nil
    end, 120)
    H.eq(StateOf(bob, carol, 1), "pending", "Bob gets it at login from Alice, Carol being offline")
    H.eq(#bob.ns.Orders.ForMe(Guild(bob)), 1, "among his pending orders")
    H.eq(#alice.ns.Orders.Open(Guild(alice)), 0, "not in the open list")
    H.check(alice.ns.Orders.Accept(carol.guid, 1) == nil, "nobody else can accept it")
    H.check(bob.ns.Orders.Deny(carol.guid, 1), "Bob turns it down")
    w:RunFor(10)
    w:Login(carol)
    w:RunUntil(function()
        return StateOf(carol, carol, 1) == "denied"
    end, 120)
    H.eq(StateOf(carol, carol, 1), "denied", "Carol sees it denied")

    H.check(carol.ns.Orders.Modify(1, { sl = 197, r = 21, d = alice.guid }), "she sends it to Alice instead")
    w:RunFor(10)
    H.check(StateOf(alice, carol, 1) == "pending" and #alice.ns.Orders.ForMe(Guild(alice)) == 1, "Alice has it")
    H.check(alice.ns.Orders.Accept(carol.guid, 1), "Alice accepts")
    w:RunFor(10)
    H.eq(select(2, StateOf(carol, carol, 1)), alice.guid, "Carol sees Alice as its crafter")
    H.check(alice.ns.Orders.Release(carol.guid, 1), "Alice gives it back")
    w:RunFor(10)
    H.eq(StateOf(carol, carol, 1), "released", "released: it waits for Carol")
    H.eq(ViewOf(carol, carol, 1).releaser, alice.guid, "who sees Alice released it")
    H.eq(StateOf(bob, carol, 1), "released", "and so does the guild")
    H.check(#alice.ns.Orders.ForMe(Guild(alice)) == 0 and alice.ns.Orders.Accept(carol.guid, 1) == nil
        and alice.ns.Orders.Deny(carol.guid, 1) == nil, "no longer Alice's, who cannot take it again as it is")
    H.check(carol.ns.Orders.Modify(1, { sl = 197, r = 21, d = alice.guid, q = 2 }), "Carol may modify it")
    w:RunFor(10)
    H.check(StateOf(alice, carol, 1) == "pending" and #alice.ns.Orders.ForMe(Guild(alice)) == 1, "a new request for Alice")
    H.check(carol.ns.Orders.Cancel(1), "Carol cancels it")
    w:RunFor(10)
    H.eq(StateOf(alice, carol, 1), "cancelled", "cancelled everywhere")

    -- A decline in the very second the order was last changed is still a
    -- decline, never taken for a release.
    H.eq(carol.ns.Orders.Create({ sl = 197, r = 21, d = bob.guid }), 2, "another order for Bob")
    w:RunFor(10)
    H.eq(StateOf(bob, carol, 2), "pending", "Bob has it")
    ViewOf(bob, carol, 2).order.u = bob.ns.Now()
    H.check(bob.ns.Orders.Deny(carol.guid, 2), "Bob turns it down at once")
    H.eq(StateOf(bob, carol, 2), "denied", "a decline in the order's own second")
    H.eq(#w.errors, 0, "directed order: no Lua errors")
end

H.section("Orders: no expiry, and clean-up")
do
    local w, alice, _, carol = TailorsWorld(85)
    carol.ns.Orders.Create({ sl = 197, r = 21 })
    carol.ns.Orders.Create({ sl = 197, r = 21 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 2)
    w:RunFor(10)
    w:RunFor(40 * DAY, 3600)
    H.check(StateOf(alice, carol, 1) == "pending" and StateOf(alice, carol, 2) == "accepted", "forty days later both are still on")
    H.check(carol.ns.Orders.Remove(2) == nil, "an order still on cannot be deleted")
    H.check(carol.ns.Orders.Cancel(1) and carol.ns.Orders.Cancel(2), "Carol cancels both, the accepted one too")
    w:RunFor(10)
    local key = carol.ns.Orders.Key(carol.guid, 2)
    H.check(StateOf(alice, carol, 2) == "cancelled" and alice.ns.Data.GetOwnRecord(false).a[key] ~= nil,
        "Alice sees it cancelled, and keeps her answer a while")
    w:RunFor(3 * DAY + 2 * 3600, 600)
    w:RunFor(60)
    H.check(ViewOf(carol, carol, 1) == nil and ViewOf(alice, carol, 2) == nil, "three days later they are gone")
    H.eq(alice.ns.Data.GetOwnRecord(false).a[key], nil, "and so is Alice's answer")
    carol.ns.Orders.Create({ sl = 197, r = 21 })
    H.eq(carol.ns.Data.GetOwnRecord(false).o[3] ~= nil and 3, 3, "ids are never reused")

    -- An answer to an order whose requester left the guild goes.
    carol.ns.Orders.Create({ sl = 197, r = 21 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 4)
    w:RunFor(10)
    w:Logout(carol)
    w:RemoveMember(carol.key)
    w:RosterChanged()
    w:RunFor(20)
    alice.ns.Orders.Prune()
    H.eq(alice.ns.Data.GetOwnRecord(false).a[carol.ns.Orders.Key(carol.guid, 4)], nil, "an answer to a member who left goes")
    H.eq(#w.errors, 0, "clean-up: no Lua errors")
end

H.section("Orders: our record as 0.8 left it")
do
    local w, alice, _, carol = TailorsWorld(90)
    carol.ns.Orders.Create({ sl = 197, r = 21 })
    carol.ns.Orders.Create({ sl = 197, r = 21 })
    w:RunFor(10)
    -- As 0.8 saved it: order 1 lasted 7 days and ran out; order 2 still has days.
    local record = carol.ns.Data.GetOwnRecord(false)
    local now = carol.env.GetServerTime()
    record.av = 802
    record.o[1].c, record.o[1].u, record.o[1].e = now - 9 * DAY, now - 9 * DAY, 7
    record.o[2].e = 30
    local changed = carol.ns.Orders.Prune()
    -- The version the client tells the guild it runs (ANNOUNCE_AS, while set).
    H.check(changed and record.av == carol.ns.VERSION_NUM and record.av > 802, "the record is stamped with this version")
    H.check(record.o[1].s == 1 and record.o[1].u == now - 2 * DAY and record.o[1].e == nil,
        "an order that had expired is cancelled as of then")
    H.check(record.o[2].s == 0 and record.o[2].e == nil, "one still on stays, without its days")
    w:RunFor(40)
    H.check(StateOf(alice, carol, 1) == "cancelled" and StateOf(alice, carol, 2) == "pending", "and the guild sees it so")
    H.check(not carol.ns.Orders.Prune(), "it is done once")
    H.eq(#w.errors, 0, "0.8 record: no Lua errors")
end

H.section("Orders: members on older versions")
do
    local w, alice = TailorsWorld(86)
    local oldKey, oldGUID = w:AddMember("Oldie")
    w:RosterChanged()
    w:RunFor(5)
    local Pack = alice.ns.Pack
    local now = alice.env.GetServerTime()
    -- A 0.7 client announces its record (protocol 2, format 2).
    local writer = Pack.Writer()
    writer:Byte(string.byte("U"))
    writer:UInt(Pack.Hash(alice.ns.Roster.guildKey))
    Pack.WriteRecord(writer, oldGUID, { t = now, av = 701, n = "Oldie", p = { [164] = { r = 10, m = 75, o = 1, k = { 2663 } } } }, 2)
    local body = H.Enc64(writer:Result())
    w:FireEvent(alice, "CHAT_MSG_ADDON", "GuildProfRecipes", "2pAAAA" .. body, "GUILD", oldKey, alice.name)
    w:RunFor(2)
    local record = Guild(alice).members[oldGUID]
    H.check(record and record.p[164] and record.o == nil, "its record is read, with no orders")
    H.eq(#alice.ns.Orders.Crafters(Guild(alice), 164, 2663), 0, "orders cannot be directed to it")
    -- Unless it is one of our own characters: it loads this same addon.
    alice.ns.db.own[oldGUID] = { hinted = {} }
    H.eq(#alice.ns.Orders.Crafters(Guild(alice), 164, 2663), 1, "our own other character on 0.7 can get personal orders")
    alice.ns.db.own[oldGUID] = nil
    -- Its hello goes unanswered (it could not read our offer), though it
    -- lacks everything: no records, empty digests.
    local function Hello(protocol, id, prefix)
        local hello = Pack.Writer()
        hello:Byte(string.byte("H"))
        hello:UInt(Pack.Hash(alice.ns.Roster.guildKey))
        hello:UInt(0)
        hello:UInt(701)
        for _ = 1, alice.ns.Data.BUCKETS do
            hello:UInt(0)
        end
        w:FireEvent(alice, "CHAT_MSG_ADDON", prefix or "GuildProfRecipes", protocol .. "p" .. id .. "AA" .. H.Enc64(hello:Result()), "GUILD", oldKey, alice.name)
    end
    local function OffersSince(from)
        local offers = 0
        for i = from + 1, #w.log do
            local entry = w.log[i]
            if entry.from == alice.name and entry.text:sub(5, 6) == "AA" then
                local raw = H.Dec64(entry.text:sub(7))
                if entry.text:sub(2, 2) == "z" then
                    raw = w.dict[raw]
                end
                if raw and raw:sub(1, 1) == "O" then
                    offers = offers + 1
                end
            end
        end
        return offers
    end
    local before = #w.log
    Hello("2", "AB")
    w:RunFor(60)
    H.eq(OffersSince(before), 0, "a 0.7 hello gets no answer")
    before = #w.log
    Hello("3", "AC")
    w:RunFor(60)
    H.eq(OffersSince(before), 0, "nor does a 0.8 hello")
    before = #w.log
    Hello("4", "AD", alice.ns.PREFIX)
    w:RunFor(60)
    H.eq(OffersSince(before), 1, "the same hello from a 0.9 client gets an offer")
    -- A trial build (Core.lua) talks on a prefix of its own, which members
    -- on the released version do not hear, and still hears theirs.
    H.check(alice.ns.LISTEN["GuildProfRecipes"] and alice.ns.LISTEN[alice.ns.PREFIX], "the usual prefix is heard, and ours")
    if alice.ns.TRIAL then
        H.check(alice.ns.PREFIX ~= "GuildProfRecipes" and #alice.ns.PREFIX <= 16, "a trial build talks on a prefix of its own")
    end

    -- A 0.8 client announces its record (protocol 3, format 3), with an
    -- open order and its days.
    local eightKey, eightGUID = w:AddMember("Eight")
    w:RosterChanged()
    w:RunFor(5)
    writer = Pack.Writer()
    writer:Byte(string.byte("U"))
    writer:UInt(Pack.Hash(alice.ns.Roster.guildKey))
    Pack.WriteRecord(writer, eightGUID, { t = now, av = 802, n = "Eight", p = { [197] = { r = 10, m = 75, o = 1, k = { 21 } } },
        o = { [1] = { sl = 197, r = 21, q = 1, m = false, tip = 0, note = "", c = now - 60, u = now - 60, e = 7, s = 0 } }, a = {} }, 3)
    w:FireEvent(alice, "CHAT_MSG_ADDON", "GuildProfRecipes", "3pAAAA" .. H.Enc64(writer:Result()), "GUILD", eightKey, alice.name)
    w:RunFor(2)
    record = Guild(alice).members[eightGUID]
    H.check(record and record.p[197] and record.o and record.o[1], "a 0.8 record is read, orders and all")
    H.eq(alice.ns.Orders.Find(Guild(alice), eightGUID, 1), nil, "but its orders are not listed: it could not see ours")
    H.check(#alice.ns.Orders.Crafters(Guild(alice), 197, 21) == 1, "nor can orders be directed to it (only Bob)")
    H.eq(#w.errors, 0, "older members: no Lua errors")
end

H.section("Orders: the request form")
do
    local w, alice, bob, carol = TailorsWorld(87)
    -- Carol looks at Bob's Tailoring and asks for its selected recipe.
    carol.ns.Viewer.OpenMember(bob.guid, 197)
    local viewer = carol.env.GuildProfessionsRecipesViewer
    viewer.OrderButton._scripts.OnClick(viewer.OrderButton)
    local form = carol.env.GuildProfessionsRecipesOrderForm
    H.check(form ~= nil and form._shown, "the recipe window's button opens the form")
    H.check(form.Personal._checked and not form.Open._checked and form.Target._text == "Bob", "for a personal order to the member we were looking at")
    H.check(form.Quantity._text == "1" and form.Days == nil and form.Submit._text == "Request", "1 of it, with no expiry to choose")
    local insets = true
    for _, box in ipairs({ form.Gold, form.Silver, form.Copper, form.Quantity }) do
        insets = insets and box._insets ~= nil and box._insets[2] > 0
    end
    H.check(insets, "the numbers keep off the boxes' right border")

    local function Type(box, text)
        box._text = text
        if box._scripts.OnTextChanged then
            box._scripts.OnTextChanged(box, true)
        end
    end
    Type(form.Quantity, "3")
    Type(form.Gold, "1")
    Type(form.Silver, "2")
    H.check(form.Tip._checked, "typing a tip ticks it")
    form.Materials:SetChecked(true)
    form.Note.EditBox._text = "Thanks!"
    form.Submit._scripts.OnClick(form.Submit)
    local order = carol.ns.Data.GetOwnRecord(false).o[1]
    H.check(order and order.d == bob.guid and order.q == 3 and order.tip == 10200 and order.m and order.note == "Thanks!"
        and order.e == nil, "the order is placed as filled in")
    H.check(not form._shown and carol.printed[#carol.printed]:find("order requested", 1, true) ~= nil, "the form closes, with a line in the chat")

    -- A personal order needs its member.
    carol.ns.OrderForm.Open(197, 21)
    H.check(form.Open._checked, "opened anywhere else, an open order")
    -- The item ordered: its tooltip, and shift-click links it.
    local tooltipItem
    rawset(carol.env.GameTooltip, "SetItemByID", function(_, itemID)
        tooltipItem = itemID
    end)
    form.Item._scripts.OnEnter(form.Item)
    H.eq(tooltipItem, 100021, "pointing at the item shows its tooltip")
    carol.linked = nil
    carol.shiftDown = true
    form.Item._scripts.OnClick(form.Item)
    carol.shiftDown = false
    H.check(carol.linked ~= nil, "shift-click on the item links it in chat")
    form.Personal._scripts.OnClick(form.Personal)
    Type(form.Target, "x")
    form.Submit._scripts.OnClick(form.Submit)
    H.check(form._shown and form.Error._text == "Choose who the order is for.", "without a member chosen, it says so")
    Type(form.Target, "AL")
    local suggestion = form.Suggestions.buttons[1]
    H.check(form.Suggestions._shown and suggestion._shown and suggestion.Text._text == "Alice" and not form.Suggestions.buttons[2]._shown,
        "typing shows the members who know the recipe")
    suggestion._scripts.OnClick(suggestion)
    form.Submit._scripts.OnClick(form.Submit)
    H.eq(carol.ns.Data.GetOwnRecord(false).o[2].d, alice.guid, "a suggestion picks the member")

    -- Changing an order.
    carol.ns.OrderForm.Open(197, 21, 1)
    H.check(form.Submit._text == "Save" and form.Quantity._text == "3" and form.Gold._text == "1" and form.Silver._text == "2"
        and form.Note.EditBox._text == "Thanks!", "an order of ours opens filled in")
    local before = carol.ns.Data.GetOwnRecord(false).o[1].u
    form.Open._scripts.OnClick(form.Open)
    w:RunFor(1)
    form.Submit._scripts.OnClick(form.Submit)
    order = carol.ns.Data.GetOwnRecord(false).o[1]
    H.check(order.d == nil and order.u > before and order.q == 3, "saved as an open order, a new version")

    carol.ns.OrderForm.Open(197, 99)
    H.check(form.Personal._enabled == false, "nobody else knows the recipe: no personal order")
    H.check(form.Personal._motionWhileDisabled and form.Personal._scripts.OnEnter ~= nil
        and form.Personal.tooltipText == "Nobody else in the guild knows this recipe.", "and pointing at it says why")
    -- Only Alice knows recipe 22: were she still on 0.8, the reason would be her version.
    local aliceRecord = Guild(carol).members[alice.guid]
    local version = aliceRecord.av
    aliceRecord.av = 802
    carol.ns.OrderForm.Open(197, 22)
    H.check(form.Personal._enabled == false and form.Personal.tooltipText:find("version 0.9 or later", 1, true) ~= nil,
        "someone knows it but runs 0.8: the tooltip says so")
    aliceRecord.av = version
    H.eq(#w.errors, 0, "request form: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

H.section("Orders: the lists in the guild window")
do
    local w, alice, bob, carol = TailorsWorld(88, true)
    -- Carol: an open order Alice and Bob can make, a personal one for Bob,
    -- and an open one only Alice can make.
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 2, tip = 15000, m = true, note = "Soon if you can" })
    carol.ns.Orders.Create({ sl = 197, r = 21, d = bob.guid })
    carol.ns.Orders.Create({ sl = 197, r = 22 })
    w:RunFor(10)

    local function Panel(client)
        local tab = client.env.GuildProfessionsRecipesGuildTab
        tab._scripts.OnClick(tab)
        return client.env.GuildProfessionsRecipesGuildPanel
    end
    local function Select(panel, index)
        local subtab = panel.SubTabs.Tabs[index]
        subtab._scripts.OnClick(subtab)
    end
    -- The rows of the list shown, by order id, drawn as the game would.
    local function Rows(client, panel)
        local rows = {}
        for _, element in ipairs(panel.Orders.ScrollBox._provider.elements) do
            local row = H.NewObject(client, "Frame")
            panel.Orders.ScrollBox._view.init(row, element)
            rows[element.view.id] = row
        end
        return rows
    end
    local function Count(rows)
        local count = 0
        for _ in pairs(rows) do
            count = count + 1
        end
        return count
    end
    local function Buttons(row)
        local texts = {}
        for i = #row.buttons, 1, -1 do
            local button = row.buttons[i]
            if button._shown then
                texts[#texts + 1] = button._text .. (button._enabled == false and " (off)" or "")
            end
        end
        return table.concat(texts, ", ")
    end
    local function Click(row, text)
        for _, button in ipairs(row.buttons) do
            if button._shown and button._text == text then
                button._scripts.OnClick(button)
                return
            end
        end
        error("no button " .. text)
    end

    local alicePanel = Panel(alice)
    H.eq(#alicePanel.SubTabs.Tabs, 4, "four subtabs")
    H.check(alicePanel.Professions._shown and not alicePanel.Orders._shown, "Professions first")
    Select(alicePanel, 3)
    H.check(alicePanel.Orders._shown and not alicePanel.Professions._shown and alicePanel.Craftable._shown
        and alicePanel.HideMine._shown and alicePanel.HideMine._checked, "the order list, with its two filters, both ticked")
    local rows = Rows(alice, alicePanel)
    H.check(Count(rows) == 2 and rows[1] and rows[3], "Alice's list: the two open orders, not Bob's personal one")
    H.eq(Buttons(rows[1]), "Accept", "she can accept them")
    H.check(rows[1].Title._text:find("x2", 1, true) and rows[1].State._text:find("From Carol", 1, true)
        and rows[1].Payment._text:find("Materials provided", 1, true) and rows[1].Payment._text:find("Soon if you can", 1, true),
        "a row says what, how many, from whom and how it is paid")

    -- A click on a row, or on its icon, shows its recipe among the guild's:
    -- selected and scrolled to, its group opened even if it was closed.
    alice.ns.Viewer.OpenGuild(197)
    local viewer = alice.env.GuildProfessionsRecipesViewer
    for _, element in ipairs(viewer.ScrollBox._provider.elements) do
        if element.header then
            local header = H.NewObject(alice, "Button")
            viewer.ScrollBox._view.init(header, element)
            header._scripts.OnClick(header)
        end
    end
    rows[3]._scripts.OnMouseUp(rows[3], "LeftButton")
    local scrolled = viewer.ScrollBox._scrolledTo
    H.check(viewer._shown and scrolled and scrolled.recipeID == 22 and (viewer.Detail.Name._text or ""):find("Item100022", 1, true),
        "a click on an order shows its recipe, selected and scrolled to")
    rows[1].Item._scripts.OnClick(rows[1].Item)
    H.eq(viewer.ScrollBox._scrolledTo and viewer.ScrollBox._scrolledTo.recipeID, 21, "so does a click on its icon")

    local bobPanel = Panel(bob)
    Select(bobPanel, 3)
    H.eq(Count(Rows(bob, bobPanel)), 1, "Bob's list, filtered: only what he can make")
    bobPanel.Craftable:SetChecked(false)
    bobPanel.Craftable._scripts.OnClick(bobPanel.Craftable)
    rows = Rows(bob, bobPanel)
    H.check(Count(rows) == 2 and Buttons(rows[3]) == "Accept (off)", "unfiltered, the one he cannot make has its button off")
    H.eq(rows[3].buttons[1].reason, "You don't know this recipe.", "saying why")
    H.eq(bobPanel.SubTabs.Tabs[2]._text, "Pending orders (1)", "his Pending orders count Carol's personal order")
    Select(bobPanel, 2)
    rows = Rows(bob, bobPanel)
    H.eq(Buttons(rows[2]), "Accept, Decline", "which he can accept or decline")
    Click(rows[2], "Decline")
    H.check(not bobPanel.SubTabs.Tabs[2]._text:find("(1)", 1, true), "declined, it leaves his count")

    Click(Rows(alice, alicePanel)[1], "Accept")
    w:RunFor(10)
    Select(alicePanel, 2)
    rows = Rows(alice, alicePanel)
    H.check(rows[1] and rows[1].State._text:find("Accepted by you: waiting for the materials", 1, true)
        and Buttons(rows[1]) == "Received, Release", "Alice's pending orders: hers, waiting for Carol's materials")
    H.eq(rows[1].buttons[2].reason, "Mark the materials as received.", "the button says what it does")

    local carolPanel = Panel(carol)
    Select(carolPanel, 4)
    rows = Rows(carol, carolPanel)
    H.check(Count(rows) == 3, "Carol's requested orders: all three")
    H.check(rows[1].State._text == "Accepted by Alice: waiting for your materials" and Buttons(rows[1]) == "Finish (off), Cancel",
        "taken: no changes, but she may cancel it, and finish it once Alice has the tip")
    H.eq(rows[1].buttons[2].reason, "Waiting for Alice to confirm the tip.", "the Finish button says why it is off")
    H.check(rows[1].Payment._text:find("Tip: 1g 50s 0c (1g 50s 0c missing)", 1, true), "the row says the tip is missing")
    H.check(rows[2].State._text == "Denied by Bob" and Buttons(rows[2]) == "Modify, Cancel", "denied: she may change or cancel it")
    H.eq(Buttons(rows[3]), "Modify, Cancel", "open and untaken: the same")
    Click(rows[3], "Modify")
    local form = carol.env.GuildProfessionsRecipesOrderForm
    H.check(form._shown and form.Submit._text == "Save", "Modify opens the form on the order")
    form.Cancel._scripts.OnClick(form.Cancel)

    -- In her pending orders, a click opens the recipe in her own profession
    -- window, to craft it.
    local pending = Rows(alice, alicePanel)[1]
    alice.openedRecipe = nil
    pending._scripts.OnMouseUp(pending, "LeftButton")
    H.eq(alice.openedRecipe, 21, "a click on a pending order opens it in the game's profession window")
    alice.openedRecipe = nil
    pending.Item._scripts.OnClick(pending.Item)
    H.eq(alice.openedRecipe, 21, "so does a click on its icon")
    -- Without the game's way to open a recipe, its profession at least.
    local openedLine
    local tradeSkill = alice.env.C_TradeSkillUI
    local openTradeSkill = tradeSkill.OpenTradeSkill
    rawset(alice.env, "ProfessionsUtil", false)
    rawset(tradeSkill, "OpenTradeSkill", function(skillLine)
        openedLine = skillLine
        return true
    end)
    pending._scripts.OnMouseUp(pending, "LeftButton")
    H.eq(openedLine, 197, "or else its profession")
    rawset(alice.env, "ProfessionsUtil", nil)
    rawset(tradeSkill, "OpenTradeSkill", openTradeSkill)
    Click(Rows(alice, alicePanel)[1], "Received")
    w:RunFor(10)
    rows = Rows(alice, alicePanel)
    H.check(rows[1].State._text:find("Accepted by you", 1, true) and Buttons(rows[1]) == "Complete, Release",
        "with the materials, hers to complete or release")
    rows = Rows(carol, carolPanel)
    H.check(rows[1].State._text == "Accepted by Alice" and Buttons(rows[1]) == "Finish (off), Cancel", "Carol sees it accepted")
    alice.ns.Orders.Deliver(carol.guid, 1, 1)
    w:RunFor(10)
    rows = Rows(carol, carolPanel)
    H.eq(rows[1].State._text, "Accepted by Alice · 1/2 delivered", "with how many items are delivered")
    Click(Rows(alice, alicePanel)[1], "Complete")
    w:RunFor(10)
    rows = Rows(carol, carolPanel)
    H.check(rows[1].State._text == "Completed by Alice" and Buttons(rows[1]) == "Finish (off), Cancel", "completed, still waiting for the tip")
    rows = Rows(alice, alicePanel)
    H.check(Buttons(rows[1]) == "Tip paid" and rows[1].buttons[1].reason == "Mark the tip as paid, or forgive it.",
        "Alice's completed order: hers to mark the tip paid")
    Click(rows[1], "Tip paid")
    w:RunFor(10)
    H.eq(Buttons(Rows(alice, alicePanel)[1]), "", "then nothing is left for her to do")
    rows = Rows(carol, carolPanel)
    H.check(Buttons(rows[1]) == "Finish, Cancel" and rows[1].Payment._text:find("Tip: 1g 50s 0c (paid)", 1, true),
        "the tip paid, Carol finishes it")
    Click(rows[1], "Finish")
    Click(rows[2], "Cancel")
    w:RunFor(10)
    rows = Rows(carol, carolPanel)
    H.check(rows[1].State._text == "Finished" and rows[2].State._text == "Cancelled" and rows[1].Icon._desaturated ~= false,
        "finished and cancelled orders stay listed, dimmed")
    H.check(Buttons(rows[1]) == "Delete" and Buttons(rows[2]) == "Delete", "both can be deleted")
    local cancelledID = rows[2].view.id
    Click(rows[2], "Delete")
    w:RunFor(10)
    rows = Rows(carol, carolPanel)
    H.check(Count(rows) == 2 and rows[1].State._text == "Finished", "the cancelled one leaves Carol's list")
    H.check(ViewOf(alice, carol, cancelledID) == nil and ViewOf(bob, carol, cancelledID) == nil, "and everyone else's")

    -- Hide my orders, in the order list.
    Select(carolPanel, 3)
    carolPanel.Craftable:SetChecked(false)
    carolPanel.Craftable._scripts.OnClick(carolPanel.Craftable)
    H.eq(Count(Rows(carol, carolPanel)), 0, "Carol's own open order is hidden")
    carolPanel.HideMine:SetChecked(false)
    carolPanel.HideMine._scripts.OnClick(carolPanel.HideMine)
    rows = Rows(carol, carolPanel)
    H.check(Count(rows) == 1 and Buttons(rows[3]) == "Accept (off)" and rows[3].buttons[1].reason == "This is your own order.",
        "unticked, it shows, and she cannot accept it")
    -- Were Carol another character of Alice's account, Alice's list would
    -- hide it too, and let her take it once unticked.
    alice.ns.db.own[carol.guid] = { hinted = {} }
    Select(alicePanel, 3)
    H.eq(Count(Rows(alice, alicePanel)), 0, "an order of another of our characters is hidden too")
    alicePanel.HideMine:SetChecked(false)
    alicePanel.HideMine._scripts.OnClick(alicePanel.HideMine)
    rows = Rows(alice, alicePanel)
    H.check(Count(rows) == 1 and Buttons(rows[3]) == "Accept", "unticked, that character can take it")
    alice.ns.db.own[carol.guid] = nil

    -- Delete finished and cancelled, under Requested orders.
    local deleteButton = carolPanel.DeleteClosed
    H.eq(deleteButton._shown, false, "the order list has no Delete finished and cancelled button")
    Select(carolPanel, 4)
    H.check(deleteButton._shown ~= false and deleteButton._enabled ~= false and deleteButton._text == "Delete finished and cancelled",
        "Requested orders has it, on with a finished order")
    H.check(carol.ns.Orders.Cancel(3), "(her open order cancelled)")
    local open = carol.ns.Orders.Create({ sl = 197, r = 21 })
    w:RunFor(10)
    Select(carolPanel, 4)
    deleteButton._scripts.OnEnter(deleteButton)
    local tip = table.concat(carol.env.GameTooltip._lines, "\n")
    H.check(tip:find("Deletes your finished and cancelled orders (2).", 1, true) and tip:find("| Finished", 1, true)
        and tip:find("| Cancelled", 1, true), "its tooltip says how many, and lists them: " .. tip)
    deleteButton._scripts.OnClick(deleteButton)
    w:RunFor(10)
    rows = Rows(carol, carolPanel)
    H.check(Count(rows) == 1 and rows[open] and deleteButton._enabled == false,
        "both deleted at once, not her open order; then the button is off")
    H.check(carol.printed[#carol.printed]:find("finished and cancelled orders deleted: 2.", 1, true), "it says how many")
    H.check(ViewOf(alice, carol, 1) == nil and ViewOf(alice, carol, 3) == nil, "gone for everyone")
    deleteButton._scripts.OnEnter(deleteButton)
    H.check(table.concat(carol.env.GameTooltip._lines, "\n"):find("You have no finished or cancelled orders.", 1, true),
        "off, its tooltip says why")
    -- More than the tooltip names: the rest are counted.
    for _ = 1, 12 do
        carol.ns.Orders.Cancel(carol.ns.Orders.Create({ sl = 197, r = 21 }))
    end
    w:RunFor(10)
    Select(carolPanel, 4)
    deleteButton._scripts.OnEnter(deleteButton)
    tip = table.concat(carol.env.GameTooltip._lines, "\n")
    H.check(tip:find("(12)", 1, true) and tip:find("and 2 more |4order:orders;", 1, true), "ten named, the other two counted")
    deleteButton._scripts.OnClick(deleteButton)
    w:RunFor(10)
    H.eq(Count(Rows(carol, carolPanel)), 1, "all twelve deleted")
    H.eq(#w.errors, 0, "lists: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

H.section("Orders: notices")
do
    local w, alice, bob, carol = TailorsWorld(89, true)
    local function Told(client, text)
        for i = #client.printed, 1, -1 do
            -- Without the item names' colors.
            local line = client.printed[i]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if line:find(text, 1, true) then
                return true
            end
        end
        return false
    end
    local function Badge(client)
        return client.env.GuildProfessionsRecipesGuildTab.Badge._shown
    end
    -- The mark on a client's micro menu button that opens the guild window:
    -- of the game's template for it, on that button. The last one made: the
    -- frames of earlier sessions stay in client.created.
    local function MicroMark(client)
        for i = #client.created, 1, -1 do
            local frame = client.created[i]
            if frame._template == "MainMenuBarMicroButtonNotificationTemplate" and frame._parent == client.env.GuildMicroButton then
                return frame
            end
        end
    end
    -- A client's subtabs, its panel open.
    local function SubTabs(client)
        local tab = client.env.GuildProfessionsRecipesGuildTab
        tab._scripts.OnClick(tab)
        return client.env.GuildProfessionsRecipesGuildPanel.SubTabs.Tabs
    end
    -- A row of the order list a client's panel shows, on its order id.
    local function RowOf(client, id)
        local orders = client.env.GuildProfessionsRecipesGuildPanel.Orders
        for _, element in ipairs(orders.ScrollBox._provider.elements) do
            if element.view.id == id then
                local row = H.NewObject(client, "Frame")
                orders.ScrollBox._view.init(row, element)
                return row, element
            end
        end
    end
    H.check(not Badge(bob) and not Badge(carol), "no marks while nothing waits")
    H.check(MicroMark(bob) and not MicroMark(bob):IsShown(), "nor on the micro menu's guild button")
    H.check(bob.env.GuildProfessionsRecipesGuildTab.Badge._parent == bob.env.GuildProfessionsRecipesGuildTab
        and bob.env.GuildProfessionsRecipesGuildTab.Badge.Icon ~= nil, "over the tab, so its selection glow does not cover it")

    carol.ns.Orders.Create({ sl = 197, r = 21, d = bob.guid, q = 2 })
    w:RunFor(10)
    H.check(Told(bob, "Carol asks you for a personal order:") and Told(bob, "x2"), "Bob is told of the personal order")
    H.check(Badge(bob), "and his tab shows Blizzard's mark")
    H.check(MicroMark(bob):IsShown() and not MicroMark(carol):IsShown(), "so does his micro menu's guild button, not Carol's")
    local subtabs = SubTabs(bob)
    H.check(subtabs[2].Mark:IsShown() and not subtabs[3].Mark:IsShown() and not subtabs[4].Mark:IsShown(),
        "and his Pending orders subtab")
    H.check(subtabs[2].Mark._point[2] == subtabs[2].Middle and subtabs[2].Mark._point[3] == "TOPRIGHT", "on its art's corner")
    subtabs[2]._scripts.OnClick(subtabs[2])
    H.eq(subtabs[2].Mark._point[2], subtabs[2].MiddleActive, "the taller art's once selected")
    local orders = bob.env.GuildProfessionsRecipesGuildPanel.Orders
    local row = H.NewObject(bob, "Frame")
    orders.ScrollBox._view.init(row, orders.ScrollBox._provider.elements[1])
    H.check(row.Mark:IsShown() and row.Mark._parent == row.Item, "and the order's row, on its icon")
    bob.ns.Orders.Accept(carol.guid, 1)
    w:RunFor(10)
    H.check(Told(carol, "Bob accepted your order:"), "Carol is told it was accepted")
    -- Its acceptance is a notice for Carol until she points at its row.
    H.check(Badge(carol) and MicroMark(carol):IsShown(), "on her tab and her micro menu's button")
    subtabs = SubTabs(carol)
    subtabs[4]._scripts.OnClick(subtabs[4])
    H.check(subtabs[4].Mark:IsShown() and subtabs[4]:GetText() == "Requested orders (1)", "on her Requested orders subtab")
    local element
    row, element = RowOf(carol, 1)
    H.check(row.Mark:IsShown(), "and on its row")
    row._scripts.OnEnter(row)
    H.check(not row.Mark:IsShown() and not subtabs[4].Mark:IsShown() and not Badge(carol) and not MicroMark(carol):IsShown(),
        "pointing at the row, she has seen it: every mark goes")
    H.eq(subtabs[4]:GetText(), "Requested orders", "and the subtab no longer counts it")
    carol.ns.OrderList.CheckNotices()
    carol.ns.GuildTab.UpdateMarks()
    carol.env.GuildProfessionsRecipesGuildPanel.Orders.ScrollBox._view.init(row, element)
    H.check(not row.Mark:IsShown() and not Badge(carol), "for good")
    H.check(Badge(bob), "an accepted order still waits for Bob")
    bob.ns.Orders.Complete(carol.guid, 1)
    w:RunFor(10)
    H.check(Told(carol, "Bob completed your order:") and Badge(carol) and not Badge(bob), "then completed: now it waits for Carol")
    H.check(MicroMark(carol):IsShown() and not MicroMark(bob):IsShown(), "on her micro menu's button, no longer on Bob's")
    subtabs = SubTabs(carol)
    H.check(subtabs[4].Mark:IsShown() and not subtabs[2].Mark:IsShown(), "and on her Requested orders subtab")
    subtabs[4]._scripts.OnClick(subtabs[4])
    orders = carol.env.GuildProfessionsRecipesGuildPanel.Orders
    row = H.NewObject(carol, "Frame")
    orders.ScrollBox._view.init(row, orders.ScrollBox._provider.elements[1])
    H.check(row.Mark:IsShown(), "and her order's row")
    carol.ns.Orders.Finish(1)
    w:RunFor(10)
    H.check(not Badge(carol) and not MicroMark(carol):IsShown() and not subtabs[4].Mark:IsShown(), "finished: no more mark")
    orders.ScrollBox._view.init(row, orders.ScrollBox._provider.elements[1])
    H.check(not row.Mark:IsShown(), "nor on its row")

    carol.ns.Orders.Create({ sl = 197, r = 21 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 2)
    w:RunFor(10)
    H.check(Badge(carol), "another acceptance, another notice")
    row = RowOf(carol, 2)
    row._scripts.OnEnter(row)
    H.check(not Badge(carol), "seen")
    alice.ns.Orders.Release(carol.guid, 2)
    w:RunFor(10)
    H.check(Told(carol, "Alice released your order: Item100021. Modify or cancel it."), "a released order is told")
    -- Released, it waits for Carol: its mark stays until she modifies or
    -- cancels it, and its text says who released it.
    row = RowOf(carol, 2)
    H.check(Badge(carol) and MicroMark(carol):IsShown() and row.Mark:IsShown(), "and marked")
    H.check(subtabs[4].Mark:IsShown() and subtabs[4]:GetText() == "Requested orders (1)", "on her Requested orders subtab too")
    H.eq(row.State:GetText(), "Released by Alice", "its text says who released it")
    H.check(row.buttons[1]:IsShown() and row.buttons[1].action == "cancel" and row.buttons[2]:IsShown()
        and row.buttons[2].action == "modify", "with its Modify and Cancel buttons")
    row._scripts.OnEnter(row)
    row.Item._scripts.OnEnter(row.Item)
    carol.ns.OrderList.CheckNotices()
    carol.ns.GuildTab.UpdateMarks()
    H.check(Badge(carol) and RowOf(carol, 2).Mark:IsShown(), "pointing at it does not take its mark away")
    H.eq(#bob.ns.Orders.Open(Guild(bob), true), 0, "nobody may take it as it is")
    -- Modified, it is a new order: open again, with its own text, and no
    -- mark.
    carol.ns.Orders.Modify(2, { sl = 197, r = 21, q = 2 })
    w:RunFor(10)
    row = RowOf(carol, 2)
    H.check(row.State:GetText() == "Open order" and not row.Mark:IsShown() and not Badge(carol),
        "modified, it is an open order again, and its mark goes")
    H.eq(#bob.ns.Orders.Open(Guild(bob), true), 1, "which Bob may take")
    bob.ns.Orders.Accept(carol.guid, 2)
    w:RunFor(10)
    H.check(Badge(carol) and RowOf(carol, 2).Mark:IsShown(), "accepted again, by another crafter: a new notice")
    H.eq(RowOf(carol, 2).State:GetText(), "Accepted by Bob", "its text, Bob's acceptance")
    row = RowOf(carol, 2)
    row._scripts.OnEnter(row)
    H.check(not Badge(carol), "seen too")
    -- Noted with its crafter: another's acceptance is new even if no
    -- notice check saw the release in between.
    local seen = carol.ns.Data.OwnState().acceptedSeen
    H.eq(seen[row.view.key], bob.guid, "noted as Bob's acceptance")
    seen[row.view.key] = alice.guid
    H.check(carol.ns.OrderList.WaitsForUs(row.view), "Alice's acceptance seen is not Bob's")
    seen[row.view.key] = bob.guid
    bob.ns.Orders.Release(carol.guid, 2)
    w:RunFor(10)
    H.check(Badge(carol) and RowOf(carol, 2).State:GetText() == "Released by Bob", "released again, by Bob now")
    carol.ns.Orders.Modify(2, { sl = 197, r = 21, q = 3 })
    w:RunFor(10)
    bob.ns.Orders.Accept(carol.guid, 2)
    w:RunFor(10)
    H.check(Badge(carol), "modified and accepted again by the same crafter: a new notice as well")
    row = RowOf(carol, 2)
    row._scripts.OnEnter(row)
    -- Released once more, and cancelled: its mark goes too.
    bob.ns.Orders.Release(carol.guid, 2)
    w:RunFor(10)
    H.check(Badge(carol), "released once more")
    carol.ns.Orders.Cancel(2)
    w:RunFor(10)
    H.check(not Badge(carol) and not RowOf(carol, 2).Mark:IsShown(), "cancelled, its mark goes")

    -- An order with Carol's materials: she is asked for them.
    carol.ns.Orders.Create({ sl = 197, r = 21, m = true })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 3)
    w:RunFor(10)
    H.check(Told(carol, "Alice accepted your order: Item100021. Send them the materials."), "Carol is asked for the materials")
    H.check(Badge(carol), "which waits for her")
    alice.ns.Orders.Receive(carol.guid, 3)
    w:RunFor(10)
    H.check(Told(carol, "Alice received your materials:"), "and told once Alice has them")
    H.check(Badge(carol) and RowOf(carol, 3).Mark:IsShown(), "its notice, until she points at it")
    row = RowOf(carol, 3)
    row.Item._scripts.OnEnter(row.Item)
    H.check(not row.Mark:IsShown() and not Badge(carol), "pointing at its icon is seeing it too")
    -- Cancelled once taken: its crafter is told.
    local before = #alice.printed
    carol.ns.Orders.Cancel(3)
    w:RunFor(10)
    H.check(#alice.printed > before and Told(alice, "Carol cancelled the order you accepted:"), "Alice is told it was cancelled")
    H.check(not Told(bob, "cancelled the order you accepted"), "nobody else is")
    -- Nor is the member a personal order was for, if they had declined it.
    carol.ns.Orders.Create({ sl = 197, r = 21, d = bob.guid })
    w:RunFor(10)
    bob.ns.Orders.Deny(carol.guid, 4)
    w:RunFor(10)
    carol.ns.Orders.Cancel(4)
    w:RunFor(10)
    H.check(not Told(bob, "cancelled the order you accepted"), "a declined order cancelled is not told")

    -- Told at login what changed while away.
    w:Logout(alice)
    w:RunFor(15)
    local away = carol.ns.Orders.Create({ sl = 197, r = 22, d = alice.guid })
    w:RunFor(10)
    w:Login(alice)
    w:RunUntil(function()
        return Told(alice, "Carol asks you for a personal order:")
    end, 120)
    H.check(Told(alice, "Carol asks you for a personal order:"), "a personal order placed while away is told at login")

    -- Released while Carol is away by another character of her account,
    -- whose saved data is hers too: at login nothing new arrives. She is
    -- still told, and her marks show, once the guild is known (in game,
    -- after login), though she never saw it accepted.
    w:Logout(carol)
    w:RunFor(15)
    alice.ns.Orders.Accept(carol.guid, away)
    w:RunFor(10)
    alice.ns.Orders.Release(carol.guid, away)
    w:RunFor(10)
    w:Logout(bob)
    w:Logout(alice)
    w:RunFor(15)
    local DB = "GuildProfessionsRecipesDB"
    for key, guild in pairs(carol.saved[DB].guilds) do
        guild.members[alice.guid] = H.DeepCopy(alice.saved[DB].guilds[key].members[alice.guid])
    end
    local guildInfo, late = carol.env.GetGuildInfo, true
    carol.globals = {
        GetGuildInfo = function()
            if not late then
                return guildInfo()
            end
        end,
    }
    w:Login(carol)
    w:RunFor(5)
    H.check(not Badge(carol) and not MicroMark(carol):IsShown(), "no marks while the guild is not known")
    late = false
    w:FireEvent(carol, "PLAYER_GUILD_UPDATE")
    w:RunFor(5)
    H.check(Told(carol, "Alice released your order: Item100022. Modify or cancel it."), "once it is, she is told of the release")
    H.check(Badge(carol) and MicroMark(carol):IsShown(), "and its marks show, though she never saw it accepted")
    carol.globals = nil
    H.eq(#w.errors, 0, "notices: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

H.section("Orders: deliveries by trade and mail")
do
    local w, alice, bob, carol = TailorsWorld(91)
    -- Recipe 21 makes item 100021 from 3 linen (2589) and 1 thread (2320).
    w.reagents[21] = { { 2589, 3 }, { 2320, 1 } }
    local function Told(client, text)
        for i = #client.printed, 1, -1 do
            -- Without the item names' colors.
            local line = client.printed[i]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if line:find(text, 1, true) then
                return true
            end
        end
        return false
    end
    local function Delivered(client, id)
        local view = ViewOf(client, carol, id)
        return view and view.delivered
    end

    -- Three of it, with Carol's materials: 9 linen and 3 thread.
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 3, m = true })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 1)
    w:RunFor(10)
    H.eq(StateOf(carol, carol, 1), "materials", "Alice accepted: it waits for Carol's materials")

    -- Materials in two goes: a trade, then a mail.
    w:Trade(carol, alice, { { 2589, 5 } }, {})
    H.eq(StateOf(alice, carol, 1), "materials", "part of them by trade: still waiting")
    H.check(Told(alice, "materials from Carol counted, some are still missing: Item100021 x3."), "Alice is told what was counted")
    w:Mail(carol, "Alice", { { 2589, 4 }, { 2320, 2 } })
    w:TakeMail(alice, 1)
    H.eq(StateOf(alice, carol, 1), "materials", "a mail with more, still short of thread")
    w:Mail(carol, "Alice", { { 2320, 1 }, { 2447, 7 } })
    w:TakeMail(alice, 1)
    H.eq(StateOf(alice, carol, 1), "accepted", "the last thread by mail: the materials are received")
    H.check(Told(alice, "materials from Carol received: Item100021 x3."), "and Alice is told")
    w:RunFor(10)
    H.check(Told(carol, "Alice received your materials:"), "so is Carol")

    -- Items that do not count: given to someone else, a cancelled trade, a
    -- mail the game refused.
    w:Trade(alice, bob, { { 100021, 1 } }, {})
    w:Trade(alice, carol, { { 100021, 1 } }, {}, { cancel = true })
    w:Mail(alice, "Carol", { { 100021, 1 } }, { fail = true })
    H.eq(Delivered(alice, 1), 0, "nothing counted yet")

    -- The items in two goes: one by mail, two by trade.
    w:Mail(alice, "Carol", { { 100021, 1 } })
    H.check(Delivered(alice, 1) == 1 and StateOf(alice, carol, 1) == "accepted", "one delivered by mail")
    H.check(Told(alice, "1 of 3 delivered to Carol: Item100021 x3."), "Alice is told")
    w:RunFor(10)
    H.eq(Delivered(carol, 1), 1, "Carol sees it delivered")
    carol.bagsFull = true
    w:TakeMail(carol, 1)
    H.check(#carol.inbox == 1 and not Told(carol, "received from Alice"), "her bags full, taking it fails and counts for nothing")
    carol.bagsFull = false
    w:TakeMail(carol, 1, 1)
    H.check(#carol.inbox == 0 and Told(carol, "1 of 3 received from Alice: Item100021 x3."), "taken, it counts")
    H.eq(carol.ns.Data.OwnState().deliveries[carol.ns.Orders.Key(carol.guid, 1)].got, 1, "once, not with the failed try")
    H.eq(StateOf(carol, carol, 1), "accepted", "still one short of finished")
    w:Trade(alice, carol, { { 100021, 2 }, { 2447, 1 } }, {})
    H.eq(StateOf(carol, carol, 1), "finished", "the last two by trade: finished at once")
    H.check(Told(alice, "delivered to Carol, order completed: Item100021 x3."), "Alice completed it")
    H.check(Told(carol, "received from Alice, order finished: Item100021 x3."), "Carol finished it")
    w:RunFor(10)
    H.eq(StateOf(bob, carol, 1), "finished", "finished everywhere")

    -- Two orders of the same item: the oldest is served first.
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 1 })
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 2 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 2)
    alice.ns.Orders.Accept(carol.guid, 3)
    w:RunFor(10)
    H.eq(StateOf(carol, carol, 2), "accepted", "without Carol's materials, accepted at once")
    -- A mail of Carol's that came back from Alice is not a delivery.
    carol.inbox[#carol.inbox + 1] = { from = "Alice", items = { { 100021, 1 } }, returned = true }
    w:TakeMail(carol, #carol.inbox)
    H.eq(StateOf(carol, carol, 2), "accepted", "a returned mail counts for nothing")
    w:Trade(alice, carol, { { 100021, 2 } }, {})
    H.check(StateOf(carol, carol, 2) == "finished" and Delivered(alice, 3) == 1, "two items: the first order, then one of the second")
    -- The buttons still work: the crafter completes the second by hand.
    H.check(alice.ns.Orders.Complete(carol.guid, 3), "Alice completes the second by hand")
    w:RunFor(10)
    H.eq(StateOf(carol, carol, 3), "completed", "Carol sees it completed")
    w:Mail(alice, "Carol", { { 100021, 1 } })
    H.eq(Delivered(alice, 3), 1, "once completed, deliveries are no longer counted by the crafter")
    w:TakeMail(carol, 1)
    H.eq(StateOf(carol, carol, 3), "finished", "but its requester still finishes it on receipt")
    H.eq(next(carol.ns.Data.OwnState().deliveries or {}) and carol.ns.Data.OwnState().deliveries[carol.ns.Orders.Key(carol.guid, 1)], nil,
        "counts of finished orders are let go")
    H.eq(#w.errors, 0, "deliveries: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

H.section("Orders: the materials list")
do
    local w, alice, bob, carol = TailorsWorld(92, true)
    -- Recipe 21 takes 3 linen (2589) and 1 thread (2320); the game gives no
    -- materials for recipe 22.
    w.reagents[21] = { { 2589, 3 }, { 2320, 1 } }
    w.reagents[22] = {}
    local tab = alice.env.GuildProfessionsRecipesGuildTab
    tab._scripts.OnClick(tab)
    local panel = alice.env.GuildProfessionsRecipesGuildPanel
    local function Select(index)
        local subtab = panel.SubTabs.Tabs[index]
        subtab._scripts.OnClick(subtab)
    end
    local button = panel.Materials
    local function Window()
        return alice.env.GuildProfessionsRecipesMaterials
    end
    -- The window's rows, drawn as the game would: "text [still to come]",
    -- and whether the text is white (enough) or grey.
    local function Rows()
        local rows = {}
        for _, element in ipairs(Window().ScrollBox._provider.elements) do
            local row = H.NewObject(alice, "Frame")
            Window().ScrollBox._view.init(row, element)
            local text = row.Text._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if row.Coming._shown ~= false and row.Coming._text ~= "" then
                text = text .. " [" .. row.Coming._text .. "]"
            end
            rows[#rows + 1] = { text = text, white = row.Text._text:sub(1, 10) == "|cffffffff", row = row }
        end
        return rows
    end
    local function Texts()
        local texts = {}
        for _, row in ipairs(Rows()) do
            texts[#texts + 1] = row.text
        end
        return table.concat(texts, " | ")
    end
    local function Bags(bags)
        alice.bags = bags
        w:FireEvent(alice, "BAG_UPDATE_DELAYED")
        w:RunFor(1)
    end

    -- Carol orders: two of recipe 21 with her materials, one without, one
    -- of recipe 22, one only Bob may take, and one nobody takes.
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 2, m = true })
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 1 })
    carol.ns.Orders.Create({ sl = 197, r = 22, q = 1 })
    carol.ns.Orders.Create({ sl = 197, r = 21, d = bob.guid })
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 5 })
    w:RunFor(10)
    Select(2)
    H.check(button._shown ~= false and button._enabled == false, "Pending orders has the Materials list button, off without accepted orders")
    H.eq(button.reason, "You have no accepted orders to make.", "saying why")
    for id = 1, 3 do
        alice.ns.Orders.Accept(carol.guid, id)
    end
    bob.ns.Orders.Accept(carol.guid, 4)
    w:RunFor(10)
    H.check(button._enabled ~= false and button.reason == nil, "with accepted orders, it is on")
    Select(3)
    H.eq(button._shown, false, "the other subtabs do not have it")
    Select(2)

    button._scripts.OnClick(button)
    H.check(Window() and Window()._shown, "it opens the materials window")
    H.eq(Window().Summary._text, "For 3 accepted |4order:orders;", "for the three orders Alice accepted")
    H.eq(Texts(), "0/3 Item2320 [2 still to be received] | 0/9 Item2589 [6 still to be received] | Item100022: materials unknown",
        "every material summed over them, by name, with what Carol still has to send; then the order whose materials are unknown")
    local rows = Rows()
    H.check(not rows[1].white and not rows[2].white, "grey: not enough, even with what is to come")

    -- What she carries counts, and follows her bags.
    Bags({ [2320] = 1 })
    rows = Rows()
    H.check(rows[1].text == "1/3 Item2320 [2 still to be received]" and rows[1].white,
        "one thread in her bags and two to come: enough, white")
    -- Part of Carol's materials, by trade: less to come.
    w:Trade(carol, alice, { { 2589, 4 } }, {})
    Bags({ [2320] = 1, [2589] = 4 })
    H.eq(Texts(), "1/3 Item2320 [2 still to be received] | 4/9 Item2589 [2 still to be received] | Item100022: materials unknown",
        "four linen received: in her bags, two still to come")
    -- An order completed, items delivered, and an order released no longer
    -- take anything.
    alice.ns.Orders.Deliver(carol.guid, 2, 1)
    alice.ns.Orders.Deliver(carol.guid, 1, 1)
    alice.ns.Orders.Release(carol.guid, 3)
    w:RunFor(10)
    H.eq(Window().Summary._text, "For 1 accepted |4order:orders;", "one order left")
    H.eq(Texts(), "1/1 Item2320 [1 still to be received] | 4/3 Item2589 [2 still to be received]",
        "for the one craft it has left; what is to come no more than it takes")
    -- The material's item: its tooltip, and shift-click links it.
    rows = Rows()
    alice.shiftDown = true
    rows[2].row.Button._scripts.OnClick(rows[2].row.Button)
    alice.shiftDown = false
    H.check(alice.linked and alice.linked:find("item:2589", 1, true), "shift-click links the material")

    button._scripts.OnClick(button)
    H.eq(Window()._shown, false, "the button closes the window too")
    button._scripts.OnClick(button)
    H.check(Window()._shown and Window().Empty._shown == false, "and opens it again")

    -- Every material in, and the last one completed: nothing left.
    w:Trade(carol, alice, { { 2589, 2 }, { 2320, 2 } }, {})
    w:RunFor(10)
    H.eq(StateOf(alice, carol, 1), "accepted", "Carol's materials received")
    H.eq(Texts(), "1/1 Item2320 | 4/3 Item2589", "nothing to come")
    alice.ns.Orders.Complete(carol.guid, 1)
    w:RunFor(10)
    H.check(Window().Empty._shown ~= false and #Window().ScrollBox._provider.elements == 0, "completed: the window says there is nothing to make")
    H.eq(button._enabled, false, "and the button is off again")
    H.eq(#w.errors, 0, "materials list: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

H.section("Orders: the materials list as orders are made")
do
    local w, alice, _, carol = TailorsWorld(94, true)
    local LINEN, THREAD, SHIRT = 2589, 2320, 100021
    -- Recipe 21 makes a shirt from 3 linen and 1 thread; recipe 22 takes 2
    -- linen and a shirt.
    w.reagents[21] = { { LINEN, 3 }, { THREAD, 1 } }
    w.reagents[22] = { { LINEN, 2 }, { SHIRT, 1 } }
    alice.bags = { [LINEN] = 20, [THREAD] = 4 }
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 3 })
    w:RunFor(2)
    carol.ns.Orders.Create({ sl = 197, r = 22, q = 2 })
    w:RunFor(2)
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 1 })
    w:RunFor(10)
    for id = 1, 3 do
        alice.ns.Orders.Accept(carol.guid, id)
    end
    w:RunFor(10)
    local tab = alice.env.GuildProfessionsRecipesGuildTab
    tab._scripts.OnClick(tab)
    local panel = alice.env.GuildProfessionsRecipesGuildPanel
    panel.SubTabs.Tabs[2]._scripts.OnClick(panel.SubTabs.Tabs[2])
    panel.Materials._scripts.OnClick(panel.Materials)
    local window = alice.env.GuildProfessionsRecipesMaterials
    local function Texts()
        w:RunFor(1)
        local texts = {}
        for _, element in ipairs(window.ScrollBox._provider.elements) do
            local row = H.NewObject(alice, "Frame")
            window.ScrollBox._view.init(row, element)
            texts[#texts + 1] = (row.Text._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
        end
        return table.concat(texts, " | ")
    end
    -- Alice crafts: the materials go, the items come.
    local function Craft(bags)
        alice.bags = bags
        w:FireEvent(alice, "BAG_UPDATE_DELAYED")
    end

    H.eq(Texts(), "0/2 Item100021 | 4/4 Item2320 | 20/16 Item2589", "three orders: 16 linen, 4 thread and 2 shirts")
    -- The last order released: what it took is no longer counted.
    H.check(alice.ns.Orders.Release(carol.guid, 3), "(the last order released)")
    w:RunFor(10)
    H.eq(Texts(), "0/2 Item100021 | 4/3 Item2320 | 20/13 Item2589", "an order released: its linen and thread no longer counted")
    H.eq(window.Summary._text, "For 2 accepted |4order:orders;", "two orders left")
    -- Two shirts made: one left to make for the first order.
    Craft({ [LINEN] = 14, [THREAD] = 2, [SHIRT] = 2 })
    H.eq(Texts(), "0/2 Item100021 | 2/1 Item2320 | 14/7 Item2589",
        "two shirts made: the first order takes one more; the shirts made are for it, not for the second")
    -- The third: the first order is made, and takes no thread any more.
    Craft({ [LINEN] = 11, [THREAD] = 1, [SHIRT] = 3 })
    H.eq(Texts(), "0/2 Item100021 | 11/4 Item2589", "the first order made: no thread needed any more, its row goes")
    -- Two more, for the second order to take.
    Craft({ [LINEN] = 5, [SHIRT] = 5 })
    H.eq(Texts(), "2/2 Item100021 | 5/4 Item2589", "two shirts more than the first order takes: the second has them")
    H.check(window.Empty._shown == false, "(rows shown)")
    -- The second made too: nothing to make, only to deliver.
    Craft({ [LINEN] = 1, [SHIRT] = 3, [100022] = 2 })
    H.check(Texts() == "" and window.Empty._shown ~= false and window.Empty._text == "All of it is made: it only remains to deliver it.",
        "all made: the window says only delivering is left")
    H.eq(window.Summary._text, "For 2 accepted |4order:orders;", "the orders are still to deliver")
    -- A shirt sold: the first order takes one more again.
    Craft({ [LINEN] = 1, [SHIRT] = 2, [100022] = 2 })
    H.eq(Texts(), "0/1 Item2320 | 1/3 Item2589", "an item made gone from the bags is to be made again")
    -- Two orders of a shirt, the older one with Carol's materials still to
    -- come: the one shirt made is for the older one.
    alice.ns.Orders.Complete(carol.guid, 1)
    alice.ns.Orders.Complete(carol.guid, 2)
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 1, m = true })
    w:RunFor(2)
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 1 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 4)
    alice.ns.Orders.Accept(carol.guid, 5)
    w:RunFor(10)
    Craft({ [LINEN] = 1, [SHIRT] = 1 })
    H.eq(Texts(), "0/1 Item2320 | 1/3 Item2589", "one shirt made of two: one more to make")
    local coming = 0
    for _, element in ipairs(window.ScrollBox._provider.elements) do
        coming = coming + (element.coming or 0)
    end
    H.eq(coming, 0, "the shirt made is the older order's, whose materials are to come: the one left takes none from Carol")
    H.eq(#w.errors, 0, "made: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

H.section("Orders: preparing the materials")
do
    local w, alice, _, carol = TailorsWorld(93, true)
    local LINEN, THREAD, ORE = 2589, 2320, 2771
    -- Recipe 21 takes 3 linen and 1 thread; stacks of 20. Alice's bags hold
    -- linen in two stacks and some thread; her bank, more of both.
    w.reagents[21] = { { LINEN, 3 }, { THREAD, 1 } }
    w:SetContainer(alice, 0, { size = 16, [1] = { LINEN, 8 }, [2] = { LINEN, 4 }, [3] = { THREAD, 2 }, [4] = { ORE, 7 } })
    w:SetContainer(alice, 6, { size = 28, [1] = { LINEN, 20 }, [2] = { THREAD, 20 } })
    local env, ns = alice.env, alice.ns
    -- The stacks of an item in a container, smallest first: "4 8".
    local function Stacks(bag, itemID)
        local list = {}
        for slot, item in pairs(alice.containers[bag] or {}) do
            if type(slot) == "number" and item[1] == itemID then
                list[#list + 1] = item[2]
            end
        end
        table.sort(list)
        return table.concat(list, " ")
    end
    -- The counts of the stacks kept for a material, smallest first.
    local function Kept(itemID)
        local prepared = ns.Data.OwnState().prepared or {}
        local list = {}
        for _, count in pairs(prepared[itemID] or {}) do
            list[#list + 1] = count
        end
        table.sort(list)
        return table.concat(list, " ")
    end
    local function Told(text, since)
        for i = (since or 0) + 1, #alice.printed do
            if alice.printed[i]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):find(text, 1, true) then
                return true
            end
        end
        return false
    end

    -- Carol orders five without materials, and two with hers: they take 21
    -- linen and 7 thread, 6 and 2 of them to come from her.
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 5 })
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 2, m = true })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 1)
    alice.ns.Orders.Accept(carol.guid, 2)
    w:RunFor(10)
    local tab = env.GuildProfessionsRecipesGuildTab
    tab._scripts.OnClick(tab)
    local panel = env.GuildProfessionsRecipesGuildPanel
    panel.SubTabs.Tabs[2]._scripts.OnClick(panel.SubTabs.Tabs[2])
    panel.Materials._scripts.OnClick(panel.Materials)
    local window = env.GuildProfessionsRecipesMaterials
    local button = window.Prepare
    local function Texts()
        w:RunFor(1)
        local texts = {}
        for _, element in ipairs(window.ScrollBox._provider.elements) do
            local row = H.NewObject(alice, "Frame")
            window.ScrollBox._view.init(row, element)
            local text = row.Text._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if row.Coming._shown ~= false and row.Coming._text ~= "" then
                text = text .. " [" .. row.Coming._text:gsub("|A.-|a ", "") .. "]"
            end
            texts[#texts + 1] = text
        end
        return table.concat(texts, " | ")
    end
    local function Tip()
        w:RunFor(1)
        button._scripts.OnEnter(button)
        return table.concat(env.GameTooltip._lines, "\n")
    end
    -- Presses the button, if it is on, and waits for it to finish.
    local function Press()
        w:RunFor(1)
        if not button:IsShown() or not button:IsEnabled() then
            return false
        end
        button._scripts.OnClick(button)
        for _ = 1, 60 do
            w:RunFor(1)
            if not ns.Prepare.Busy() then
                break
            end
        end
        w:RunFor(1)
        return true
    end

    H.eq(Texts(), "2/7 Item2320 [2 still to be received] | 12/21 Item2589 [6 still to be received]", "the list counts the bags' stacks")
    H.check(button._text == "Prepare" and button:IsEnabled(), "the window has a Prepare button, on with something to keep")
    local tip = Tip()
    H.check(tip:find("Keeps in your bags the materials still missing, from your bags' stacks not kept yet.", 1, true)
        and tip:find("Your bags hold only part of them: open your bank to bring the rest.", 1, true),
        "without the bank, it keeps what the bags hold, and says the rest is in the bank: " .. tip)

    -- Without the bank: the bags' linen made one stack, the thread kept as it is.
    local printed, moves = #alice.printed, alice.moves or 0
    H.check(Press(), "Prepare runs without the bank")
    H.check(Stacks(0, LINEN) == "12" and Stacks(0, THREAD) == "2", "the linen's two stacks made one; the thread stays as it is")
    H.check(Kept(LINEN) == "12" and Kept(THREAD) == "2", "both kept")
    H.eq((alice.moves or 0) - moves, 1, "one move: the 4 onto the 8")
    H.check(Told("materials kept in your bags; still missing: ", printed) and Told("item:2589|h[Item]|h x3", printed)
        and Told("item:2320|h[Item]|h x3", printed), "it says what is still missing, as items")
    H.eq(Texts(), "2/7 Item2320 [2 kept · 2 still to be received] | 12/21 Item2589 [12 kept · 6 still to be received]",
        "each row says how many are kept")
    tip = Tip()
    H.check(button._text == "Release all" and button:IsEnabled() and tip:find("Lets go of the materials kept in your bags.", 1, true)
        and tip:find("Your bags hold none of the materials still missing: open your bank to bring them.", 1, true),
        "nothing more to keep from the bags: the button lets go, and says why it cannot keep more: " .. tip)

    -- At the bank: the rest, split off its stacks onto the kept ones.
    w:OpenBank(alice)
    tip = Tip()
    H.check(button._text == "Prepare" and button:IsEnabled() and tip:find("and from your bank.", 1, true),
        "with the bank open, Prepare again, from the bank too")
    printed = #alice.printed
    Press()
    H.check(Stacks(0, LINEN) == "15" and Stacks(6, LINEN) == "17", "3 linen split off the bank's 20 onto the kept 12")
    H.check(Stacks(0, THREAD) == "5" and Stacks(6, THREAD) == "17", "3 thread onto the kept 2")
    H.check(Kept(LINEN) == "15" and Kept(THREAD) == "5", "all of it kept")
    H.check(Told("materials ready in your bags.", printed), "it says so")
    H.check(button._text == "Release all" and Tip():find("Lets go of the materials kept in your bags.", 1, true), "ready: Release all")

    -- The padlocks in the game's backpack window.
    local buttons = {}
    for slot = 1, 16 do
        local item = H.NewObject(alice, "ItemButton")
        item.GetBagID = function()
            return 0
        end
        item.GetID = function()
            return slot
        end
        buttons[slot] = item
    end
    env.ContainerFrame1 = H.NewObject(alice, "Frame")
    env.ContainerFrame1.UpdateItems = function() end
    env.ContainerFrame1.EnumerateValidItems = function()
        return ipairs(buttons)
    end
    ns.BagLocks.Init()
    local function Padlocks()
        env.ContainerFrame1:UpdateItems()
        local list = {}
        for slot, item in ipairs(buttons) do
            local lock = ns.BagLocks.LockOf(item)
            if lock and lock:IsShown() then
                list[#list + 1] = slot
            end
        end
        return table.concat(list, " ")
    end
    H.eq(Padlocks(), "1 3", "a padlock on each kept stack")
    local lock = ns.BagLocks.LockOf(buttons[1])
    lock._scripts.OnEnter(lock)
    tip = table.concat(env.GameTooltip._lines, "\n")
    H.check(tip:find("Kept for your crafting orders", 1, true) and tip:find("lets it go", 1, true),
        "its tooltip says what for, and what lets it go")

    -- Release all, then Prepare again: the stacks are where they were.
    printed, moves = #alice.printed, alice.moves or 0
    H.check(Press(), "Release all can be pressed")
    H.check(Kept(LINEN) == "" and Kept(THREAD) == "" and Padlocks() == "", "nothing kept, no padlocks")
    H.check(Told("materials no longer kept in your bags.", printed), "it says so")
    H.eq(button._text, "Prepare", "the button is Prepare again")
    Press()
    H.check(Kept(LINEN) == "15" and Kept(THREAD) == "5" and (alice.moves or 0) == moves, "kept again as they are: no move")

    -- Carol's materials arrive: no longer to come, they are to be kept too.
    w:Trade(carol, alice, { { LINEN, 6 }, { THREAD, 2 } }, {})
    alice.containers[0][5] = { LINEN, 6 }
    alice.containers[0][6] = { THREAD, 2 }
    w:FireEvent(alice, "BAG_UPDATE_DELAYED")
    w:RunFor(10)
    H.eq(Texts(), "7/7 Item2320 [5 kept] | 21/21 Item2589 [15 kept]", "nothing to come")
    H.check(button._text == "Prepare" and button:IsEnabled(), "Prepare, for what came")
    Press()
    H.check(Kept(LINEN) == "6 15" and Stacks(0, LINEN) == "6 15", "her 6 linen kept as they are: a stack of their own fits best")
    H.check(Kept(THREAD) == "7" and Stacks(0, THREAD) == "7", "her 2 thread onto the kept 5")
    H.eq(Padlocks(), "1 3 5", "with their padlocks")

    -- The order of five completed: what it took is no longer kept, the
    -- biggest stacks first, while the rest covers the other order.
    H.check(alice.ns.Orders.Complete(carol.guid, 1), "(the order of five completed)")
    w:RunFor(10)
    H.check(Kept(LINEN) == "6" and Kept(THREAD) == "7", "the 15 linen let go, the 6 still kept; the thread still covers the 2")
    -- Split by hand: let go.
    env.C_Container.SplitContainerItem(0, 5, 2)
    env.C_Container.PickupContainerItem(0, 9)
    w:RunFor(2)
    H.check(Kept(LINEN) == "" and Padlocks() == "3", "a kept stack split by hand is let go")
    -- The other order released: no order takes the materials any more.
    H.check(alice.ns.Orders.Release(carol.guid, 2), "(the other order released)")
    w:RunFor(10)
    H.check(Kept(THREAD) == "" and Padlocks() == "", "no order takes them any more: all let go")

    -- Two more orders: two of recipe 21, and two of recipe 22, which takes
    -- linen and a dye nobody has.
    local DYE = 2324
    w.reagents[22] = { { LINEN, 1 }, { DYE, 1 } }
    carol.ns.Orders.Create({ sl = 197, r = 21, q = 2 })
    carol.ns.Orders.Create({ sl = 197, r = 22, q = 2 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 3)
    alice.ns.Orders.Accept(carol.guid, 4)
    w:RunFor(10)

    -- No room in the bags: nothing moves.
    w:SetContainer(alice, 0, { size = 2, [1] = { ORE, 5 }, [2] = { ORE, 5 } })
    w:RunFor(1)
    tip = Tip()
    H.check(button._text == "Prepare" and not button:IsEnabled() and tip:find("Not enough room in your bags: 2 free |4slot:slots; needed.", 1, true),
        "without room for it all, Prepare is off, and says how much room it takes: " .. tip)
    -- Something on the cursor: it waits.
    w:SetContainer(alice, 0, { size = 16, [1] = { ORE, 5 } })
    env.C_Container.PickupContainerItem(0, 1)
    printed = #alice.printed
    H.check(not ns.Prepare.Run("prepare") and Told("put down what you hold on the cursor first.", printed), "not with something on the cursor")
    env.ClearCursor()
    -- The bank closed while a move from it is under way: it stops.
    w.moveDelay = 30
    w:RunFor(1)
    button._scripts.OnClick(button)
    w:RunFor(1)
    H.check(ns.Prepare.Busy(), "(preparing, a move from the bank under way)")
    w:CloseBank(alice)
    w:RunFor(2)
    H.check(not ns.Prepare.Busy(), "the bank closed, it stops")
    w:RunFor(40)
    w:OpenBank(alice)
    -- The server too slow: it stops.
    printed = #alice.printed
    Press()
    H.check(Told("the items did not move in time: try again.", printed) and not ns.Prepare.Busy(), "a move the server does not carry out in time stops it")
    w.moveDelay = nil
    w:RunFor(40)
    -- What nobody has is said to be missing.
    printed = #alice.printed
    Press()
    H.check(Kept(LINEN) == "8" and Kept(THREAD) == "2", "the linen and thread kept")
    H.check(Told("still missing: ", printed) and Told("item:2324|h[Item]|h x2", printed) and not Told("item:2589", printed),
        "the dye, found nowhere, is said to be missing")
    w:CloseBank(alice)
    H.eq(#w.errors, 0, "preparing: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

H.section("Orders: the tip")
do
    local w, alice, bob, carol = TailorsWorld(92)
    local function Told(client, text)
        for i = #client.printed, 1, -1 do
            local line = client.printed[i]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if line:find(text, 1, true) then
                return true
            end
        end
        return false
    end
    local function TipPaid(client, id)
        local view = ViewOf(client, carol, id)
        return view and view.tipPaid
    end

    -- One of it, with a tip of 5 gold.
    carol.ns.Orders.Create({ sl = 197, r = 21, tip = 50000 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 1)
    w:RunFor(10)
    H.check(alice.ns.Orders.TipReceived(carol.guid, 1, 0) == nil and bob.ns.Orders.TipReceived(carol.guid, 1, 100) == nil,
        "only its crafter counts its tip, and something")

    -- The item and 3 gold in one trade: completed, but 2 gold short.
    w:Trade(alice, carol, { { 100021, 1 } }, {}, { bMoney = 30000 })
    H.check(StateOf(alice, carol, 1) == "completed" and TipPaid(alice, 1) == 30000, "Alice counts the item and 3 gold")
    H.check(Told(alice, "tip from Carol counted, 2g 0s 0c still missing: Item100021."), "and says what is missing")
    H.check(Told(carol, "everything received from Alice: Item100021. It is finished once they confirm the tip."),
        "Carol has everything, but it waits for the tip")
    w:RunFor(10)
    H.check(StateOf(carol, carol, 1) == "completed" and select(2, carol.ns.Orders.Finish(1)) == "tip", "so she cannot finish it yet")

    -- The rest by mail, with more than missing: only the tip counts.
    w:Mail(carol, "Alice", {}, { money = 25000 })
    w:TakeMail(alice, 1, "money")
    H.check(TipPaid(alice, 1) == 50000 and Told(alice, "tip from Carol paid: Item100021."), "2 more gold by mail: paid, never above it")
    w:RunFor(10)
    H.eq(StateOf(carol, carol, 1), "finished", "Carol's client finishes it as soon as Alice has the tip")
    H.check(Told(carol, "received from Alice, order finished: Item100021."), "and says so")
    H.check(not Told(carol, "confirmed your tip"), "with one line, not two")

    -- Paid where the addon cannot see: Alice confirms it by hand.
    carol.ns.Orders.Create({ sl = 197, r = 21, tip = 10000 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 2)
    w:RunFor(10)
    alice.ns.Orders.Complete(carol.guid, 2)
    w:RunFor(10)
    H.eq(select(2, carol.ns.Orders.Finish(2)), "tip", "completed by hand, it still waits for the tip")
    H.check(alice.ns.Orders.ConfirmTip(carol.guid, 2), "Alice marks the tip paid")
    w:RunFor(10)
    H.check(Told(carol, "Alice confirmed your tip: Item100021."), "Carol is told")
    H.eq(StateOf(carol, carol, 2), "completed", "without the item in hand, she finishes it herself")
    H.check(carol.ns.Orders.Finish(2), "which she can now")

    -- Two orders with tips, one trade: the oldest is paid first.
    carol.ns.Orders.Create({ sl = 197, r = 21, tip = 10000 })
    carol.ns.Orders.Create({ sl = 197, r = 21, tip = 10000 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 3)
    alice.ns.Orders.Accept(carol.guid, 4)
    w:RunFor(10)
    w:Trade(alice, carol, {}, {}, { bMoney = 15000 })
    H.check(TipPaid(alice, 3) == 10000 and TipPaid(alice, 4) == 5000, "15 silver short of both: the first paid, half the second")
    -- Orders without a tip finish as before.
    carol.ns.Orders.Create({ sl = 197, r = 21 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 5)
    w:RunFor(10)
    w:Trade(alice, carol, { { 100021, 1 } }, {})
    H.eq(StateOf(carol, carol, 3), "finished", "the item for the paid one: finished at once")
    H.eq(#w.errors, 0, "tip: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end
