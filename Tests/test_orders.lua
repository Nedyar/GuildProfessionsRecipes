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
    local record = { t = now, av = 800, n = "Solo", p = { [197] = { r = 1, m = 75, o = 1, k = { 21 } } },
        o = { [3] = { sl = 197, r = 21, q = 2, d = "Player-1-000000B2", m = true, tip = 12345, note = "Two, please", c = now - 10, u = now - 5, e = 7, s = 0 } },
        a = { ["Player-1-000000C3:4"] = { s = 1, u = now - 2, ou = now - 3 } } }
    local key, copy = Pack.ReadRecord(Pack.Reader(Pack.RecordString(guid, record)))
    H.eq(key, guid, "a record with orders reads back")
    H.check(copy.o and copy.o[3] and copy.o[3].d == "Player-1-000000B2" and copy.o[3].m == true and copy.o[3].tip == 12345
        and copy.o[3].note == "Two, please" and copy.o[3].e == 7, "with its orders")
    H.check(copy.a and copy.a["Player-1-000000C3:4"] and copy.a["Player-1-000000C3:4"].ou == now - 3, "and its answers")
    H.check(Data.CleanRecord(copy, now) ~= nil, "and passes the checks")

    local _, old = Pack.ReadRecord(Pack.Reader(Pack.RecordString(guid, record, 2)), 2)
    H.check(old.o == nil and old.a == nil and old.p[197] ~= nil, "format 2 (0.7) has professions, no orders")
    record.o, record.a = nil, nil
    local _, unknown = Pack.ReadRecord(Pack.Reader(Pack.RecordString(guid, record)))
    H.check(unknown.o == nil and unknown.a == nil, "unknown orders stay unknown, not none")
    record.o, record.a = {}, {}
    local _, none = Pack.ReadRecord(Pack.Reader(Pack.RecordString(guid, record)))
    H.check(none.o ~= nil and next(none.o) == nil, "no orders reads as none")

    local function With(field, value)
        local order = { sl = 197, r = 21, q = 1, m = false, tip = 0, note = "", c = now, u = now, e = 7, s = 0 }
        order[field] = value
        return Data.CleanRecord({ t = now, p = {}, o = { [1] = order } }, now)
    end
    H.check(With("q", 0) == nil and With("q", 1000) == nil, "quantities from 1 to 999")
    H.check(With("e", 0) == nil and With("e", 31) == nil, "from 1 to 30 days")
    H.check(With("d", "Bob") == nil and With("s", 3) == nil and With("note", ("x"):rep(201)) == nil, "a GUID, a known state, a short note")
    H.check(With("u", now - 10) == nil and With("c", now + 3600) == nil, "and sensible times")
    local cleaned = With("note", "|cffff0000red|r\1bell\nline")
    H.eq(cleaned and cleaned.o[1].note, "cffff0000redrbell\nline", "notes lose escape sequences and control characters, not line breaks")
    H.check(Data.CleanRecord({ t = now, p = {}, a = { ["Bob:1"] = { s = 1, u = now, ou = now } } }, now) == nil, "answers are keyed by GUID and id")

    -- Our own record: lost orders come back from the guild's copy, and a
    -- newer copy that knows nothing of them does not wipe them.
    local guild = { members = {} }
    guild.members[solo.guid] = { t = now, p = {} }
    Data.MergeRecord(guild, solo.guid, { t = now - 50, p = {}, o = { [1] = { sl = 1, r = 2, q = 1, c = now, u = now, e = 7, s = 0 } }, a = {} })
    H.check(guild.members[solo.guid].o and guild.members[solo.guid].o[1] ~= nil, "our lost orders are adopted from the guild's copy")
    guild.members[guid] = { t = now - 10, p = {}, o = { [9] = { sl = 1, r = 2, q = 1, c = now, u = now, e = 7, s = 0 } } }
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
    local order = { sl = 197, r = 21, q = 1, c = now - 100, u = now - 50, e = 7, s = 0 }
    local function Answer(guid, s, u, ou)
        return { guid = guid, answer = { s = s, u = u, ou = ou or order.u } }
    end
    H.eq(Orders.State(order, "R", nil, now), "pending", "nobody answered: pending")
    local state, crafter = Orders.State(order, "R", { Answer("B", 1, now - 10), Answer("A", 1, now - 20) }, now)
    H.check(state == "accepted" and crafter == "A", "two acceptances: the earlier one wins")
    state, crafter = Orders.State(order, "R", { Answer("B", 1, now - 10), Answer("A", 1, now - 10) }, now)
    H.check(crafter == "A", "at the same second, the same one on every client")
    H.eq(Orders.State(order, "R", { Answer("A", 3, now - 20) }, now), "completed", "completed")
    H.eq(Orders.State(order, "R", { Answer("A", 1, now - 20, order.u - 1) }, now), "pending", "an answer to an older version does not count")
    H.eq(Orders.State(order, "R", { Answer("R", 1, now - 20) }, now), "pending", "nor the requester's own")
    order.d = "B"
    H.eq(Orders.State(order, "R", { Answer("A", 1, now - 20) }, now), "pending", "a directed order: only its member's answer counts")
    H.eq(Orders.State(order, "R", { Answer("B", 2, now - 20) }, now), "denied", "denied")
    H.eq(Orders.State(order, "R", nil, order.c + 7 * DAY), "expired", "expired after its days")
    order.s = 1
    H.eq(Orders.State(order, "R", { Answer("B", 1, now - 20) }, now), "cancelled", "cancelled")
    order.s = 2
    H.eq(Orders.State(order, "R", nil, now), "finished", "finished")
end

H.section("Orders: an open order")
do
    local w, alice, bob, carol = TailorsWorld(83)
    local id = carol.ns.Orders.Create({ sl = 197, r = 21, q = 3, m = true, tip = 5000, note = "For my alt", e = 7 })
    H.eq(id, 1, "Carol places an order")
    w:RunFor(10)
    H.eq(StateOf(alice, carol, 1), "pending", "it reaches the guild within seconds")
    H.eq(#alice.ns.Orders.Open(Guild(alice), true), 1, "in Alice's list of orders she can make")
    H.eq(#carol.ns.Orders.Open(Guild(carol)), 0, "not in Carol's own open list")
    H.eq(#carol.ns.Orders.Mine(Guild(carol)), 1, "but in her requested orders")
    H.check(carol.ns.Orders.Accept(carol.guid, 1) == nil, "Carol cannot take her own order")

    -- Alice and Bob accept before hearing of each other.
    H.check(alice.ns.Orders.Accept(carol.guid, 1) and bob.ns.Orders.Accept(carol.guid, 1), "Alice and Bob both accept")
    w:RunFor(10)
    local _, a = StateOf(alice, carol, 1)
    local _, b = StateOf(bob, carol, 1)
    local state, c = StateOf(carol, carol, 1)
    H.check(state == "accepted" and a == b and b == c and (c == alice.guid or c == bob.guid), "every client agrees on one crafter")
    local crafter = c == alice.guid and alice or bob
    local other = crafter == alice and bob or alice
    H.check(#crafter.ns.Orders.ForMe(Guild(crafter)) == 1 and #other.ns.Orders.ForMe(Guild(other)) == 0, "it is pending for its crafter only")
    H.check(carol.ns.Orders.Modify(1, { sl = 197, r = 21, q = 1 }) == nil and carol.ns.Orders.Cancel(1) == nil, "once taken, Carol can neither modify nor cancel it")
    H.check(other.ns.Orders.Complete(carol.guid, 1) == nil, "only its crafter completes it")

    H.check(crafter.ns.Orders.Complete(carol.guid, 1), "the crafter marks it completed")
    w:RunFor(10)
    H.eq(StateOf(carol, carol, 1), "completed", "Carol sees it completed")
    H.check(carol.ns.Orders.Finish(1), "and finishes it")
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
    H.eq(StateOf(carol, carol, 1), "pending", "pending again")
    H.check(carol.ns.Orders.Cancel(1), "Carol cancels it")
    w:RunFor(10)
    H.eq(StateOf(alice, carol, 1), "cancelled", "cancelled everywhere")
    H.eq(#w.errors, 0, "directed order: no Lua errors")
end

H.section("Orders: expiry and clean-up")
do
    local w, alice, _, carol = TailorsWorld(85)
    carol.ns.Orders.Create({ sl = 197, r = 21, e = 1 })
    carol.ns.Orders.Create({ sl = 197, r = 21, e = 30 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 2)
    w:RunFor(10)
    w:RunFor(DAY + 60, 60)
    H.eq(StateOf(alice, carol, 1), "expired", "an order expires after its days")
    H.eq(StateOf(alice, carol, 2), "accepted", "the other one is still on")
    H.check(alice.ns.Orders.Accept(carol.guid, 1) == nil, "an expired order cannot be accepted")
    H.check(carol.ns.Orders.Remove(2) == nil, "an order still on cannot be deleted")
    w:RunFor(3 * DAY + 600, 600)
    H.eq(ViewOf(carol, carol, 1), nil, "three days later it is gone")
    H.check(ViewOf(alice, carol, 2) ~= nil, "the open one stays")
    carol.ns.Orders.Create({ sl = 197, r = 21 })
    H.eq(carol.ns.Data.GetOwnRecord(false).o[3] ~= nil and 3, 3, "ids are never reused")
    H.eq(#w.errors, 0, "expiry: no Lua errors")
end

H.section("Orders: members on 0.7")
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
    w:FireEvent(alice, "CHAT_MSG_ADDON", alice.ns.PREFIX, "2pAAAA" .. body, "GUILD", oldKey, alice.name)
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
    local function Hello(protocol, id)
        local hello = Pack.Writer()
        hello:Byte(string.byte("H"))
        hello:UInt(Pack.Hash(alice.ns.Roster.guildKey))
        hello:UInt(0)
        hello:UInt(701)
        for _ = 1, alice.ns.Data.BUCKETS do
            hello:UInt(0)
        end
        w:FireEvent(alice, "CHAT_MSG_ADDON", alice.ns.PREFIX, protocol .. "p" .. id .. "AA" .. H.Enc64(hello:Result()), "GUILD", oldKey, alice.name)
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
    H.eq(OffersSince(before), 1, "the same hello from a 0.8 client gets an offer")
    H.eq(#w.errors, 0, "0.7 members: no Lua errors")
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
    H.check(form.Quantity._text == "1" and form.Days._text == "7" and form.Submit._text == "Request", "1 of it, for 7 days")
    local insets = true
    for _, box in ipairs({ form.Gold, form.Silver, form.Copper, form.Quantity, form.Days }) do
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
    H.check(order and order.d == bob.guid and order.q == 3 and order.tip == 10200 and order.m and order.note == "Thanks!",
        "the order is placed as filled in")
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
    -- Only Alice knows recipe 22: were she still on 0.7, the reason would be her version.
    local aliceRecord = Guild(carol).members[alice.guid]
    local version = aliceRecord.av
    aliceRecord.av = 701
    carol.ns.OrderForm.Open(197, 22)
    H.check(form.Personal._enabled == false and form.Personal.tooltipText:find("0.8 or later", 1, true) ~= nil,
        "someone knows it but runs 0.7: the tooltip says so")
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
    H.check(alicePanel.Orders._shown and not alicePanel.Professions._shown and alicePanel.Craftable._shown, "the order list, with its filter")
    local rows = Rows(alice, alicePanel)
    H.check(Count(rows) == 2 and rows[1] and rows[3], "Alice's list: the two open orders, not Bob's personal one")
    H.eq(Buttons(rows[1]), "Accept", "she can accept them")
    H.check(rows[1].Title._text:find("x2", 1, true) and rows[1].State._text:find("From Carol", 1, true)
        and rows[1].Payment._text:find("Materials provided", 1, true) and rows[1].Payment._text:find("Soon if you can", 1, true),
        "a row says what, how many, from whom and how it is paid")

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
    H.check(rows[1] and Buttons(rows[1]) == "Complete, Release", "Alice's pending orders: hers to complete or release")

    local carolPanel = Panel(carol)
    Select(carolPanel, 4)
    rows = Rows(carol, carolPanel)
    H.check(Count(rows) == 3, "Carol's requested orders: all three")
    H.check(rows[1].State._text == "Accepted by Alice" and Buttons(rows[1]) == "", "taken: no changes")
    H.check(rows[2].State._text == "Denied by Bob" and Buttons(rows[2]) == "Modify, Cancel", "denied: she may change or cancel it")
    H.eq(Buttons(rows[3]), "Modify, Cancel", "open and untaken: the same")
    Click(rows[3], "Modify")
    local form = carol.env.GuildProfessionsRecipesOrderForm
    H.check(form._shown and form.Submit._text == "Save", "Modify opens the form on the order")
    form.Cancel._scripts.OnClick(form.Cancel)

    Click(Rows(alice, alicePanel)[1], "Complete")
    w:RunFor(10)
    rows = Rows(carol, carolPanel)
    H.check(rows[1].State._text == "Completed by Alice" and Buttons(rows[1]) == "Finish", "completed: Carol finishes it")
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
            if client.printed[i]:find(text, 1, true) then
                return true
            end
        end
        return false
    end
    local function Badge(client)
        return client.env.GuildProfessionsRecipesGuildTab.Badge._shown
    end
    H.check(not Badge(bob) and not Badge(carol), "no marks while nothing waits")

    carol.ns.Orders.Create({ sl = 197, r = 21, d = bob.guid, q = 2 })
    w:RunFor(10)
    H.check(Told(bob, "Carol asks you for a personal order:") and Told(bob, "x2"), "Bob is told of the personal order")
    H.check(Badge(bob), "and his tab shows Blizzard's mark")
    bob.ns.Orders.Accept(carol.guid, 1)
    w:RunFor(10)
    H.check(Told(carol, "Bob accepted your order:"), "Carol is told it was accepted")
    H.check(Badge(bob), "an accepted order still waits for Bob")
    bob.ns.Orders.Complete(carol.guid, 1)
    w:RunFor(10)
    H.check(Told(carol, "Bob completed your order:") and Badge(carol) and not Badge(bob), "then completed: now it waits for Carol")
    carol.ns.Orders.Finish(1)
    w:RunFor(10)
    H.check(not Badge(carol), "finished: no more mark")

    carol.ns.Orders.Create({ sl = 197, r = 21 })
    w:RunFor(10)
    alice.ns.Orders.Accept(carol.guid, 2)
    w:RunFor(10)
    alice.ns.Orders.Release(carol.guid, 2)
    w:RunFor(10)
    H.check(Told(carol, "your order is open again:"), "a released order is told")

    -- Told at login what changed while away.
    w:Logout(alice)
    w:RunFor(15)
    carol.ns.Orders.Create({ sl = 197, r = 22, d = alice.guid })
    w:RunFor(10)
    w:Login(alice)
    w:RunUntil(function()
        return Told(alice, "Carol asks you for a personal order:")
    end, 120)
    H.check(Told(alice, "Carol asks you for a personal order:"), "a personal order placed while away is told at login")
    H.eq(#w.errors, 0, "notices: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end
