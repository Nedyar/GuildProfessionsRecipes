-- Deliveries.lua: what changes hands with guildmates, by trade or by mail,
-- counted towards the crafting orders between them. A count moves its
-- order on as the button would, from the client whose record it changes:
--   - a crafter counts the materials their requester gives them, until
--     there are enough for the order: they are then received;
--   - a crafter counts the order's items they give its requester, until
--     its quantity: it is then completed;
--   - a crafter counts the money their requester gives them towards the
--     order's tip, up to the tip;
--   - a requester counts the order's items their crafter gives them,
--     until its quantity: it is then finished, as soon as the crafter has
--     the tip too.
-- Deliveries in several goes add up, by trade and mail alike. Crafting the
-- recipe counts for nothing: the crafter may be making it for anyone. What
-- the game does not show (items handed over through another character)
-- is left to the buttons.
local _, ns = ...
local L = ns.L
local Data, Orders = ns.Data, ns.Orders

local Deliveries = {}
ns.Deliveries = Deliveries

local TRADE_SLOTS = 6               -- the slots that change hands (the 7th is not traded)
local TRADE_COMPLETE_WINDOW = 5     -- seconds from the window closing to the game's "Trade complete."

-- Counting --------------------------------------------------------------------------

-- What we counted so far, per order, saved per character:
-- [key] = { got = its items received, as its requester,
--           mats = { [itemID] = count } of materials received, as its crafter }
local function Tallies()
    local own = Data.OwnState()
    own.deliveries = own.deliveries or {}
    return own.deliveries
end

-- Takes up to wanted of an item from pool; returns how many it took.
local function Take(pool, itemID, wanted)
    local have = itemID and pool[itemID] or 0
    local taken = math.max(0, math.min(have, wanted))
    if taken > 0 then
        pool[itemID] = have - taken
    end
    return taken
end

local function Copy(items)
    local copy = {}
    for itemID, count in pairs(items or {}) do
        copy[itemID] = count
    end
    return copy
end

local function Name(guid)
    local guild = Data.CurrentGuild(false)
    return Data.NameOf(guid, guild and guild.members[guid])
end

local function ItemText(order)
    local name = ns.Viewer.RecipeOutput(order.r)
    return order.q > 1 and ("%s x%d"):format(name, order.q) or name
end

-- The materials an order takes: { [itemID] = count }, or nil when unknown.
local function Needed(order)
    local _, perCraft, reagents = ns.Viewer.OrderItems(order.r)
    if not reagents or #reagents == 0 then
        return nil
    end
    local crafts = math.ceil(order.q / perCraft)
    local needed = {}
    for _, reagent in ipairs(reagents) do
        needed[reagent.itemID] = (needed[reagent.itemID] or 0) + reagent.quantity * crafts
    end
    return needed
end

-- As its crafter: the materials of an order waiting for them that its
-- requester has yet to send us, { [itemID] = count } (MaterialsList.lua).
-- Empty when the order's materials are unknown.
function Deliveries.MaterialsOwed(view)
    local tally = Tallies()[view.key]
    local got = tally and tally.mats or {}
    local owed = {}
    for itemID, count in pairs(Needed(view.order) or {}) do
        if count > (got[itemID] or 0) then
            owed[itemID] = count - (got[itemID] or 0)
        end
    end
    return owed
end

-- As its crafter: materials from the requester of an order waiting for them.
local function CountMaterials(view, received, tally)
    local needed = Needed(view.order)
    if not needed then
        return
    end
    tally.mats = tally.mats or {}
    local took, missing = false, false
    for itemID, count in pairs(needed) do
        local got = tally.mats[itemID] or 0
        local taken = Take(received, itemID, count - got)
        if taken > 0 then
            tally.mats[itemID] = got + taken
            took = true
        end
        if (tally.mats[itemID] or 0) < count then
            missing = true
        end
    end
    if not took then
        return
    elseif missing then
        ns.Print(L["materials from %s counted, some are still missing: %s."], Name(view.requester), ItemText(view.order))
    elseif Orders.Receive(view.requester, view.id) then
        ns.Print(L["materials from %s received: %s."], Name(view.requester), ItemText(view.order))
    end
end

-- As its crafter: the order's items given to its requester.
local function CountDelivered(view, given)
    local itemID = ns.Viewer.OrderItems(view.order.r)
    local count = Take(given, itemID, view.order.q - (view.delivered or 0))
    if count == 0 then
        return
    end
    local delivered, completed = Orders.Deliver(view.requester, view.id, count)
    if completed then
        ns.Print(L["delivered to %s, order completed: %s."], Name(view.requester), ItemText(view.order))
    elseif delivered then
        ns.Print(L["%d of %d delivered to %s: %s."], delivered, view.order.q, Name(view.requester), ItemText(view.order))
    end
end

-- As its requester: the order's items received from its crafter.
local function CountReceived(view, received, tally)
    local itemID = ns.Viewer.OrderItems(view.order.r)
    local got = tally.got or 0
    local count = Take(received, itemID, view.order.q - got)
    if count == 0 then
        return
    end
    tally.got = got + count
    if tally.got < view.order.q then
        ns.Print(L["%d of %d received from %s: %s."], tally.got, view.order.q, Name(view.crafter), ItemText(view.order))
    elseif Orders.TipMissing(view) > 0 then
        ns.Print(L["everything received from %s: %s. It is finished once they confirm the tip."], Name(view.crafter), ItemText(view.order))
    elseif Orders.Finish(view.id) then
        ns.Print(L["received from %s, order finished: %s."], Name(view.crafter), ItemText(view.order))
    end
end

-- As its crafter: money from the requester towards the order's tip, taken
-- from money.left.
local function CountTip(view, money)
    local copper = math.min(money.left, Orders.TipMissing(view))
    if copper <= 0 then
        return
    end
    money.left = money.left - copper
    local paid, all = Orders.TipReceived(view.requester, view.id, copper)
    if all then
        ns.Print(L["tip from %s paid: %s."], Name(view.requester), ItemText(view.order))
    elseif paid then
        ns.Print(L["tip from %s counted, %s still missing: %s."], Name(view.requester),
            ns.OrderList.Money(view.order.tip - paid), ItemText(view.order))
    end
end

-- Our orders whose items we all have, once their crafters have the tip
-- too (they may confirm it later than the items came).
function Deliveries.FinishReady()
    local guild = Data.CurrentGuild(false)
    local tallies = ns.playerGUID and Data.OwnState().deliveries
    if not guild or not tallies then
        return
    end
    for _, view in ipairs(Orders.Mine(guild)) do
        local tally = tallies[view.key]
        if tally and (tally.got or 0) >= view.order.q and Orders.IsTaken(view.state) and Orders.TipMissing(view) == 0
                and Orders.Finish(view.id) then
            ns.Print(L["received from %s, order finished: %s."], Name(view.crafter), ItemText(view.order))
        end
    end
end

-- What changed hands with a guildmate (partner, a GUID): given and
-- received are { [itemID] = count }, money the copper they gave us. Each
-- item and copper counts towards one order only, the oldest first.
function Deliveries.Exchanged(partner, given, received, money)
    local guild = Data.CurrentGuild(false)
    if not guild or not partner or partner == ns.playerGUID then
        return
    end
    given, received = Copy(given), Copy(received)
    money = { left = type(money) == "number" and money or 0 }
    local tallies = Tallies()
    local current = {}
    local views = Orders.List(guild)
    table.sort(views, function(a, b)
        if a.order.c ~= b.order.c then
            return a.order.c < b.order.c
        elseif a.requester ~= b.requester then
            return a.requester < b.requester
        end
        return a.id < b.id
    end)
    for _, view in ipairs(views) do
        local ours, mine = view.crafter == ns.playerGUID, view.requester == ns.playerGUID
        if Orders.IsTaken(view.state) and (ours or mine) then
            current[view.key] = true
            local tally = tallies[view.key] or {}
            if ours and view.requester == partner then
                if view.state == "materials" then
                    CountMaterials(view, received, tally)
                end
                if view.state ~= "completed" then
                    CountDelivered(view, given)
                end
                CountTip(view, money)
            elseif mine and view.crafter == partner then
                CountReceived(view, received, tally)
            end
            if next(tally) ~= nil then
                tallies[view.key] = tally
            end
        end
    end
    -- Counts of orders no longer taken by or from us are of no more use.
    for key in pairs(tallies) do
        if not current[key] then
            tallies[key] = nil
        end
    end
end

-- The game ---------------------------------------------------------------------------

local function ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local function Add(items, itemID, count)
    itemID, count = ns.Plain(itemID), ns.Plain(count)
    if type(itemID) == "number" and type(count) == "number" and count > 0 then
        items[itemID] = (items[itemID] or 0) + count
    end
end

local function Describe(items)
    local parts = {}
    for itemID, count in pairs(items or {}) do
        parts[#parts + 1] = count .. "x" .. itemID
    end
    return #parts > 0 and table.concat(parts, " ") or "-"
end

-- A guildmate by name, as mail gives it ("Name Surname", maybe with a realm).
local function ByName(name)
    name = ns.Plain(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return Data.FindByName(Data.CurrentGuild(false), name)
end

local function Exchanged(how, partner, given, received, money)
    ns.Debug("%s, %s: gave %s, got %s and %d copper", how, tostring(partner), Describe(given), Describe(received), money or 0)
    ns.SafeCall(Deliveries.Exchanged, partner, given, received, money)
end

local function Copper(value)
    value = ns.Plain(value)
    return type(value) == "number" and value > 0 and math.floor(value) or 0
end

-- Trade: what each side put in is read as it changes, since the window is
-- empty by the time the game says the trade is complete.
local trade

local function TradePartner()
    local guid = ns.Plain(UnitGUID("NPC"))
    if Data.IsGUID(guid) then
        return guid
    end
    local first, second = UnitName("NPC")
    first, second = ns.Plain(first), ns.Plain(second)
    return ByName(second and second ~= "" and first and (first .. " " .. second) or first)
end

local function ReadTrade()
    if not trade or trade.closed then
        return
    end
    local given, received = {}, {}
    for slot = 1, TRADE_SLOTS do
        Add(given, ItemID(ns.Plain(GetTradePlayerItemLink(slot))), (select(3, GetTradePlayerItemInfo(slot))))
        Add(received, ItemID(ns.Plain(GetTradeTargetItemLink(slot))), (select(3, GetTradeTargetItemInfo(slot))))
    end
    trade.given, trade.received = given, received
    trade.money = Copper(GetTargetTradeMoney and GetTargetTradeMoney())
end

local function TradeComplete(message)
    if not trade or not ERR_TRADE_COMPLETE or message ~= ERR_TRADE_COMPLETE then
        return
    end
    if trade.closed and GetTime() - trade.closedAt > TRADE_COMPLETE_WINDOW then
        trade = nil
        return
    end
    local done = trade
    trade = nil
    Exchanged("trade", done.partner, done.given, done.received, done.money)
end

-- Mail sent: what is attached when it goes, counted once the game says it
-- went. Attachments are also read as they change, in case the game has
-- emptied them by then.
local attached, outgoing = {}, nil

local function Attached()
    local items = {}
    for slot = 1, ATTACHMENTS_MAX_SEND or 12 do
        local _, itemID, _, count = GetSendMailItem(slot)
        itemID = ns.Plain(itemID)
        if type(itemID) ~= "number" and GetSendMailItemLink then
            itemID = ItemID(ns.Plain(GetSendMailItemLink(slot)))
        end
        Add(items, itemID, count)
    end
    return items
end

local function OnSendMail(recipient)
    local items = Attached()
    if next(items) == nil then
        items = attached
    end
    outgoing = { to = recipient, items = items }
end

-- Mail taken: the items and money of a mail as they are taken from it,
-- counted once the inbox changes, or dropped if the game refuses (bags
-- full...).
local taking = {}
local TAKE_ERRORS = { "ERR_INV_FULL", "ERR_ITEM_MAX_COUNT", "ERR_MAIL_DATABASE_ERROR" }

-- what: "item" (one slot), "money", or "all" (items and money).
local function OnTake(index, slot, what)
    index, slot = ns.Plain(index), ns.Plain(slot)
    if type(index) ~= "number" then
        return
    end
    -- The same thing taken twice before the game answers counts once.
    for _, take in ipairs(taking) do
        if take.index == index and (take.what == "all" or what == "all" or take.what == what and take.slot == slot) then
            return
        end
    end
    local _, _, sender, _, money, _, _, _, _, wasReturned = GetInboxHeaderInfo(index)
    if ns.Plain(wasReturned) then
        return
    end
    local items = {}
    if what ~= "money" then
        for i = slot or 1, slot or ATTACHMENTS_MAX_RECEIVE or 16 do
            local _, itemID, _, count = GetInboxItem(index, i)
            itemID = ns.Plain(itemID)
            if type(itemID) ~= "number" and GetInboxItemLink then
                itemID = ItemID(ns.Plain(GetInboxItemLink(index, i)))
            end
            Add(items, itemID, count)
        end
    end
    local copper = what ~= "item" and Copper(money) or 0
    if next(items) ~= nil or copper > 0 then
        taking[#taking + 1] = { index = index, slot = slot, what = what, from = ns.Plain(sender), items = items, money = copper }
    end
end

-- UI_INFO_MESSAGE and UI_ERROR_MESSAGE give (type, message).
local function MessageOf(...)
    local first, second = ...
    second = ns.Plain(second)
    if type(second) == "string" then
        return second
    end
    return ns.Plain(first)
end

local function OnEvent(_, event, ...)
    if event == "TRADE_SHOW" then
        trade = { partner = TradePartner(), given = {}, received = {} }
    elseif event == "TRADE_CLOSED" then
        if trade and not trade.closed then
            trade.closed, trade.closedAt = true, GetTime()
        end
    elseif event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_TARGET_ITEM_CHANGED" or event == "TRADE_ACCEPT_UPDATE"
            or event == "TRADE_MONEY_CHANGED" then
        ReadTrade()
    elseif event == "UI_INFO_MESSAGE" then
        TradeComplete(MessageOf(...))
    elseif event == "MAIL_SEND_INFO_UPDATE" then
        attached = Attached()
    elseif event == "MAIL_SEND_SUCCESS" then
        local sent = outgoing
        outgoing, attached = nil, {}
        if sent then
            Exchanged("mail to " .. tostring(sent.to), ByName(sent.to), sent.items, nil)
        end
    elseif event == "MAIL_FAILED" then
        outgoing = nil
    elseif event == "MAIL_INBOX_UPDATE" then
        local taken = taking
        taking = {}
        for _, take in ipairs(taken) do
            Exchanged("mail from " .. tostring(take.from), ByName(take.from), nil, take.items, take.money)
        end
    elseif event == "UI_ERROR_MESSAGE" then
        local message = MessageOf(...)
        for _, name in ipairs(TAKE_ERRORS) do
            if message ~= nil and message == _G[name] then
                taking = {}
            end
        end
    end
end

local function Hook(target, name, fn)
    local safe = function(...)
        ns.SafeCall(fn, ...)
    end
    if target and type(target[name]) == "function" then
        hooksecurefunc(target, name, safe)
    end
end

function Deliveries.Init()
    local frame = CreateFrame("Frame")
    ns.RegisterEvents(frame, "TRADE_SHOW", "TRADE_CLOSED", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "TRADE_MONEY_CHANGED",
        "TRADE_ACCEPT_UPDATE", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE", "MAIL_SEND_INFO_UPDATE", "MAIL_SEND_SUCCESS",
        "MAIL_FAILED", "MAIL_INBOX_UPDATE")
    frame:SetScript("OnEvent", OnEvent)
    Hook(_G, "SendMail", OnSendMail)
    Hook(C_Mail, "SendMail", OnSendMail)
    Hook(_G, "TakeInboxItem", function(index, slot)
        OnTake(index, slot, "item")
    end)
    Hook(_G, "TakeInboxMoney", function(index)
        OnTake(index, nil, "money")
    end)
    Hook(_G, "AutoLootMailItem", function(index)
        OnTake(index, nil, "all")
    end)
    -- A tip confirmed by the crafter may finish an order whose items we have.
    ns.On("DataChanged", function()
        ns.Debounce("DeliveriesReady", 0.5, Deliveries.FinishReady)
    end)
end
