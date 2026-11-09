-- Orders.lua: crafting orders between guild members.
--
-- Orders live in their members' records, so they travel and merge like the
-- rest of the data, and each record is only ever changed by its owner (see
-- Pack.lua for the fields):
--   - the requester's record holds the order (o); only the requester
--     creates, modifies, cancels or finishes it;
--   - a crafter's record holds their answer to it (a): accepted, denied,
--     materials received or completed, how many items they delivered and
--     how much of the tip they received. Releasing an accepted order
--     removes the answer.
-- An order with a tip cannot be finished until its crafter has the tip.
-- Every client works out an order's state from both, in the same way: when
-- two crafters accept an open order at once, the earlier acceptance wins
-- everywhere, and modifying an order voids the answers to its old version.
-- Orders do not expire: they stay until cancelled or finished. Deliveries
-- (Deliveries.lua) move them on by themselves, as the buttons do.
local _, ns = ...
local Data = ns.Data
local LIMITS = ns.Pack.LIMITS

local Orders = {}
ns.Orders = Orders

local DAY = 86400
local KEEP_CLOSED = 3 * DAY  -- finished and cancelled orders stay listed this long
-- The first version whose orders this one understands: older members
-- cannot see them, and theirs are left out.
Orders.MIN_VERSION = 900

-- The requester's side (order.s).
local ACTIVE, CANCELLED, FINISHED = 0, 1, 2
-- A crafter's side (answer.s). An accepted order whose requester provides
-- the materials waits for them until its crafter has received them.
local ACCEPTED, DENIED, COMPLETED, RECEIVED = 1, 2, 3, 4

-- States with a crafter, and states that are over.
local TAKEN = { materials = true, accepted = true, completed = true }
local CLOSED = { finished = true, cancelled = true }

function Orders.IsTaken(state)
    return TAKEN[state] == true
end

function Orders.IsClosed(state)
    return CLOSED[state] == true
end

function Orders.Key(requester, id)
    return requester .. ":" .. id
end

-- Whether a member runs a version that knows about orders as we do.
function Orders.CanUse(record)
    return record ~= nil and (record.av or 0) >= Orders.MIN_VERSION
end

-- Whose orders and answers count: members on a version like ours, and us
-- (before our record is first stamped with this version).
local function Counts(guid, record)
    return Orders.CanUse(record) or guid == ns.playerGUID
end

-- Every answer given to each order: [key] = { { guid, answer }... }.
local function AnswersByKey(guild)
    local byKey = {}
    for guid, record in pairs(guild and guild.members or {}) do
        if Counts(guid, record) then
            for key, answer in pairs(record.a or {}) do
                local list = byKey[key]
                if not list then
                    list = {}
                    byKey[key] = list
                end
                list[#list + 1] = { guid = guid, answer = answer }
            end
        end
    end
    return byKey
end

-- An order's state, worked out the same way on every client: "pending",
-- "denied", "materials" (accepted, waiting for the requester's materials),
-- "accepted", "completed", "cancelled" or "finished". While it is taken,
-- also returns its crafter's GUID, how many items they delivered and how
-- much of the tip they received.
function Orders.State(order, requester, answers)
    if order.s == CANCELLED then
        return "cancelled"
    elseif order.s == FINISHED then
        return "finished"
    end
    local crafter, chosen
    for _, entry in ipairs(answers or {}) do
        local answer = entry.answer
        if (answer.s == ACCEPTED or answer.s == RECEIVED or answer.s == COMPLETED) and answer.ou == order.u
                and entry.guid ~= requester and (order.d == nil or entry.guid == order.d) then
            if not chosen or answer.u < chosen.u or (answer.u == chosen.u and entry.guid < crafter) then
                crafter, chosen = entry.guid, answer
            end
        end
    end
    if chosen then
        local state = "accepted"
        if chosen.s == COMPLETED then
            state = "completed"
        elseif chosen.s == ACCEPTED and order.m then
            state = "materials"
        end
        return state, crafter, chosen.n or 0, chosen.p or 0
    end
    for _, entry in ipairs(answers or {}) do
        if entry.guid == order.d and entry.answer.s == DENIED and entry.answer.ou == order.u then
            return "denied"
        end
    end
    return "pending"
end

-- Every order of the guild's members, newest first, as views:
-- { key, requester, id, order, state, crafter, delivered, tipPaid }.
function Orders.List(guild)
    local answers = AnswersByKey(guild)
    local list = {}
    for guid, record in pairs(guild and guild.members or {}) do
        if record.o and Data.IsShareable(record) and Counts(guid, record) and ns.Roster.IsKnownGUID(guid) then
            for id, order in pairs(record.o) do
                local key = Orders.Key(guid, id)
                local state, crafter, delivered, tipPaid = Orders.State(order, guid, answers[key])
                list[#list + 1] = { key = key, requester = guid, id = id, order = order, state = state,
                    crafter = crafter, delivered = delivered, tipPaid = tipPaid }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.order.c ~= b.order.c then
            return a.order.c > b.order.c
        end
        return a.key < b.key
    end)
    return list
end

-- How much of a taken order's tip its crafter has yet to receive (copper).
function Orders.TipMissing(view)
    if not TAKEN[view.state] then
        return 0
    end
    return math.max(0, (view.order.tip or 0) - (view.tipPaid or 0))
end

-- One order's view, or nil.
function Orders.Find(guild, requester, id)
    for _, view in ipairs(Orders.List(guild)) do
        if view.requester == requester and view.id == id then
            return view
        end
    end
end

local function Knows(record, skillLine, recipeID)
    local prof = record and record.p[skillLine]
    if not prof or type(prof.k) ~= "table" then
        return false
    end
    for _, known in ipairs(prof.k) do
        if known == recipeID then
            return true
        end
    end
    return false
end

-- Whether we know the recipe an order asks for.
function Orders.CanCraft(order)
    return Knows(Data.GetOwnRecord(false), order.sl, order.r)
end

-- Whether a character is one of our account's: this one, or another that
-- has run the addon (the saved data is the account's).
function Orders.IsOurs(guid)
    return guid == ns.playerGUID or ns.db.own[guid] ~= nil
end

-- The members an order can be directed to: those who know the recipe and
-- run a version with orders, but us. Our account's other characters count
-- even before they log in again: they load this same addon. Sorted by
-- name; text (optional) keeps those whose name contains it, in any case.
-- { { guid, name }... }
function Orders.Crafters(guild, skillLine, recipeID, text)
    local wanted = text and strtrim(text):lower() or ""
    local list = {}
    for guid, record in pairs(guild and guild.members or {}) do
        if guid ~= ns.playerGUID and Data.IsShareable(record) and (Orders.CanUse(record) or Orders.IsOurs(guid))
                and Knows(record, skillLine, recipeID) then
            local name = Data.NameOf(guid, record)
            if wanted == "" or name:lower():find(wanted, 1, true) then
                list[#list + 1] = { guid = guid, name = name }
            end
        end
    end
    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    return list
end

-- Whether anyone in the guild but us knows a recipe, whatever their version.
function Orders.KnownByOthers(guild, skillLine, recipeID)
    for guid, record in pairs(guild and guild.members or {}) do
        if guid ~= ns.playerGUID and Data.IsShareable(record) and Knows(record, skillLine, recipeID) then
            return true
        end
    end
    return false
end

-- What the subtabs list ---------------------------------------------------------

-- Ours to act on: taken by us, or directed to us and waiting.
function Orders.ForMe(guild)
    local list = {}
    for _, view in ipairs(Orders.List(guild)) do
        if view.crafter == ns.playerGUID or view.order.d == ns.playerGUID and view.state == "pending" then
            list[#list + 1] = view
        end
    end
    return list
end

-- Open orders anyone may take. craftable: only those we know the recipe
-- of; showMine: also those of our account's characters, this one included.
function Orders.Open(guild, craftable, showMine)
    local list = {}
    for _, view in ipairs(Orders.List(guild)) do
        if view.state == "pending" and view.order.d == nil and (showMine or not Orders.IsOurs(view.requester))
                and (not craftable or Orders.CanCraft(view.order)) then
            list[#list + 1] = view
        end
    end
    return list
end

-- The orders we requested.
function Orders.Mine(guild)
    local list = {}
    for _, view in ipairs(Orders.List(guild)) do
        if view.requester == ns.playerGUID then
            list[#list + 1] = view
        end
    end
    return list
end

-- Our own changes ------------------------------------------------------------------

-- The fields of an order as the form gives them, checked and limited:
-- { sl, r, q, d, m, tip, note }. Returns nil and a reason when unusable.
local function Checked(fields)
    local q, tip = tonumber(fields.q) or 1, tonumber(fields.tip) or 0
    if type(fields.sl) ~= "number" or type(fields.r) ~= "number" then
        return nil, "recipe"
    end
    if fields.d ~= nil and not Data.IsGUID(fields.d) then
        return nil, "target"
    end
    local note = Data.CleanNote(fields.note or "")
    if not note then
        return nil, "note"
    end
    return {
        sl = fields.sl, r = fields.r, d = fields.d, m = fields.m == true, note = note,
        q = math.max(1, math.min(LIMITS.quantity, math.floor(q))),
        tip = math.max(0, math.min(LIMITS.tip, math.floor(tip))),
    }
end

local function Commit(record)
    Data.TouchOwn(record, "O")
end

-- Places an order. Returns its id, or nil and a reason.
function Orders.Create(fields)
    local record = Data.GetOwnRecord(true)
    if not record then
        return nil, "guild"
    end
    local order, reason = Checked(fields)
    if not order then
        return nil, reason
    end
    record.o = record.o or {}
    local count, last = 0, 0
    for id in pairs(record.o) do
        count = count + 1
        last = math.max(last, id)
    end
    if count >= LIMITS.orders then
        return nil, "full"
    end
    -- Never reused, so an old answer cannot fall on a new order.
    local state = Data.OwnState()
    local id = math.max(last, state.lastOrder or 0) + 1
    state.lastOrder = id
    local now = ns.Now()
    order.c, order.u, order.s = now, now, ACTIVE
    record.o[id] = order
    Commit(record)
    return id
end

-- Our order and its view, while nobody has it: pending or denied.
local function OwnFree(id)
    local view = Orders.Find(Data.CurrentGuild(false), ns.playerGUID, id)
    if view and (view.state == "pending" or view.state == "denied") then
        return Data.GetOwnRecord(false), view
    end
end

-- A modified order is a new version: answers to the old one no longer count.
local function Bump(order)
    order.u = math.max(ns.Now(), order.u + 1)
end

function Orders.Modify(id, fields)
    local record, view = OwnFree(id)
    if not record then
        return nil, "taken"
    end
    local order, reason = Checked(fields)
    if not order then
        return nil, reason
    end
    local old = view.order
    order.c, order.u, order.s = old.c, old.u, ACTIVE
    Bump(order)
    record.o[id] = order
    Commit(record)
    return true
end

-- Cancels one of our orders that is not over, even once taken: its
-- crafter is told (OrderList.lua).
function Orders.Cancel(id)
    local view = Orders.Find(Data.CurrentGuild(false), ns.playerGUID, id)
    if not view or CLOSED[view.state] then
        return nil, "state"
    end
    view.order.s = CANCELLED
    Bump(view.order)
    Commit(Data.GetOwnRecord(false))
    return true
end

-- Marks one of our taken orders finished: once its crafter completed it,
-- or before, when we already have what we asked for. Not while its
-- crafter has yet to receive the tip.
function Orders.Finish(id)
    local view = Orders.Find(Data.CurrentGuild(false), ns.playerGUID, id)
    if not view or not TAKEN[view.state] then
        return nil, "state"
    elseif Orders.TipMissing(view) > 0 then
        return nil, "tip"
    end
    view.order.s = FINISHED
    Bump(view.order)
    Commit(Data.GetOwnRecord(false))
    return true
end

-- Deletes one of our closed orders (finished or cancelled) now, rather
-- than three days later. Gone from our record, it is gone for everyone,
-- and crafters drop their answers to it.
function Orders.Remove(id)
    local view = Orders.Find(Data.CurrentGuild(false), ns.playerGUID, id)
    if not view or not CLOSED[view.state] then
        return nil, "state"
    end
    local record = Data.GetOwnRecord(false)
    record.o[id] = nil
    Commit(record)
    return true
end

local function Answer(view, state)
    local record = Data.GetOwnRecord(true)
    record.a = record.a or {}
    if state then
        record.a[view.key] = { s = state, u = ns.Now(), ou = view.order.u }
    else
        record.a[view.key] = nil
    end
    Commit(record)
    return true
end

-- An order we took, and our answer to it, while it is in one of states.
local function OwnTaken(requester, id, states)
    local view = Orders.Find(Data.CurrentGuild(false), requester, id)
    if view and view.crafter == ns.playerGUID and states[view.state] then
        local record = Data.GetOwnRecord(false)
        return view, record, record.a[view.key]
    end
end

local WORKING = { materials = true, accepted = true }

-- Accepts an order: an open one whose recipe we know, or one directed to us.
function Orders.Accept(requester, id)
    local view = Orders.Find(Data.CurrentGuild(false), requester, id)
    if not view or view.state ~= "pending" or requester == ns.playerGUID then
        return nil, "state"
    end
    if view.order.d and view.order.d ~= ns.playerGUID or not view.order.d and not Orders.CanCraft(view.order) then
        return nil, "recipe"
    end
    return Answer(view, ACCEPTED)
end

-- Turns down an order directed to us.
function Orders.Deny(requester, id)
    local view = Orders.Find(Data.CurrentGuild(false), requester, id)
    if not view or view.state ~= "pending" or view.order.d ~= ns.playerGUID then
        return nil, "state"
    end
    return Answer(view, DENIED)
end

-- Marks the materials of an order we accepted as received.
function Orders.Receive(requester, id)
    local _, record, answer = OwnTaken(requester, id, { materials = true })
    if not answer then
        return nil, "state"
    end
    answer.s = RECEIVED
    Commit(record)
    return true
end

-- Marks an order we accepted as completed; its requester then finishes it.
function Orders.Complete(requester, id)
    local _, record, answer = OwnTaken(requester, id, WORKING)
    if not answer then
        return nil, "state"
    end
    answer.s = COMPLETED
    Commit(record)
    return true
end

-- Counts items of an order we accepted as delivered to its requester; with
-- all of them, it is completed. Returns how many are delivered now, and
-- whether that completed it.
function Orders.Deliver(requester, id, count)
    local view, record, answer = OwnTaken(requester, id, WORKING)
    if not answer or not count or count < 1 then
        return nil, "state"
    end
    answer.n = math.min(view.order.q, (answer.n or 0) + math.floor(count))
    local completed = answer.n >= view.order.q
    if completed then
        answer.s = COMPLETED
    end
    Commit(record)
    return answer.n, completed
end

-- Counts copper received from the requester of an order we took towards
-- its tip, up to the tip. Returns how much of it we have now, and whether
-- that is all of it.
function Orders.TipReceived(requester, id, copper)
    local view, record, answer = OwnTaken(requester, id, TAKEN)
    if not answer or not copper or copper < 1 or Orders.TipMissing(view) == 0 then
        return nil, "state"
    end
    answer.p = math.min(view.order.tip, (answer.p or 0) + math.floor(copper))
    Commit(record)
    return answer.p, answer.p >= view.order.tip
end

-- Marks the tip of an order we took as received: paid in a way the addon
-- could not see, or forgiven.
function Orders.ConfirmTip(requester, id)
    local view, record, answer = OwnTaken(requester, id, TAKEN)
    if not answer or Orders.TipMissing(view) == 0 then
        return nil, "state"
    end
    answer.p = view.order.tip
    Commit(record)
    return true
end

-- Gives back an order we accepted: it is pending again.
function Orders.Release(requester, id)
    local view = OwnTaken(requester, id, WORKING)
    if not view then
        return nil, "state"
    end
    return Answer(view, nil)
end

-- Clean-up ------------------------------------------------------------------------

-- Our record as 0.8 left it: each order lasted some days (e), and expired
-- after them. With no expiry those would open again, so they are cancelled
-- as of then. Returns true when the record has to be stamped again, which
-- also tells the guild we run a version with orders like theirs.
local function Upgrade(record)
    local changed = (record.av or 0) < Orders.MIN_VERSION and ns.VERSION_NUM >= Orders.MIN_VERSION
        and Data.IsShareable(record)
    for _, order in pairs(record.o or {}) do
        if order.e then
            local deadline = order.c + order.e * DAY
            if order.s == ACTIVE and deadline <= ns.Now() then
                order.s = CANCELLED
                order.u = math.max(order.u, deadline)
            end
            order.e = nil
            changed = true
        end
    end
    return changed
end

-- Upgrades our record, drops our orders closed for a while, and our
-- answers to orders that are gone, closed for a while, or whose requester
-- left the guild. Returns true when anything changed.
function Orders.Prune(now)
    now = now or ns.Now()
    local guild = Data.CurrentGuild(false)
    local record = Data.GetOwnRecord(false)
    if not guild or not record then
        return false
    end
    local changed = Upgrade(record)
    for id, order in pairs(record.o or {}) do
        if order.s ~= ACTIVE and order.u + KEEP_CLOSED < now then
            record.o[id] = nil
            changed = true
        end
    end
    local views = {}
    for _, view in ipairs(Orders.List(guild)) do
        views[view.key] = view
    end
    for key in pairs(record.a or {}) do
        local requester, id = key:match("^(.+):(%d+)$")
        local owner = guild.members[requester]
        local view = views[key]
        local gone = owner and owner.o ~= nil and owner.o[tonumber(id)] == nil
        local closed = view and CLOSED[view.state] and view.order.u + KEEP_CLOSED < now
        local left = not ns.Roster.IsKnownGUID(requester)
        if gone or closed or left then
            record.a[key] = nil
            changed = true
        end
    end
    if changed then
        Data.TouchOwn(record, "U")
    end
    return changed
end

local PRUNE_INTERVAL = 3600

function Orders.Init()
    -- After changes, and now and then: closed orders go after a few days.
    ns.On("DataChanged", function()
        ns.Debounce("OrdersPrune", 5, function()
            Orders.Prune()
        end)
    end)
    C_Timer.NewTicker(PRUNE_INTERVAL, function()
        Orders.Prune()
    end)
end
