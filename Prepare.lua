-- Prepare.lua: the Prepare button of the materials list (MaterialsList.lua)
-- keeps in our bags the materials the orders we accepted still lack, as
-- Guild Bank Alts gets a request ready. For each material, what they take
-- for the crafts they have left, but for what their requesters are still to
-- send us (MaterialsList.Totals: need - coming), is kept in the fewest
-- stacks: stacks of it already in the bags and kept for nothing, as they are
-- or split, and, with the bank open, stacks brought from it, each into an
-- empty slot; when no stack holds what one is to hold, several are put
-- together into one (onto one of the bags, as it is, or onto one already
-- kept that is not full). Without the bank, what the bags hold is kept,
-- and the rest waits for the bank (or the auction house). Before the first
-- move, the bags must have room for all it moves: else nothing moves. Once
-- nothing more can be kept (all is, or the rest is not to be had now), the
-- button is Release all instead: it lets go of every kept stack.
--
-- Kept stacks (OwnState().prepared = { [itemID] = { [stack] = count } })
-- are known by the item's GUID, which stays with a stack when it moves. A
-- kept stack shows a padlock in the bags (BagLocks.lua). It stays kept
-- while it is in the bags with the count it was kept with: moved to another
-- slot, it still is; split, added to (by hand, or by the game stacking loot
-- or mail onto it), used up by crafting or out of the bags, it is let go.
-- So are the stacks of a material no order we accepted takes any more and,
-- biggest first, those a material no longer needs (an order completed or
-- released) while the rest still covers what it takes.
--
-- Items move one at a time: a move is the server's, and the slots look as
-- they were until it answers (their locks may even clear before the items
-- show where they went). So each move says where the items are to end up,
-- and the next step waits until they show there. What each material lacks
-- is counted once, before the first move, and what each step keeps for it
-- is added up: the steps never bring more. Locked stacks are left alone. A
-- preparation the server does not answer in time stops.
local _, ns = ...
local L = ns.L

local Prepare = {}
ns.Prepare = Prepare

local STEP = 0.25      -- seconds between steps
local TIMEOUT = 15     -- seconds a preparation waits for the server to carry out a move
local MAX_STEPS = 2000
local MAX_BANK_TABS = 20

-- The preparation under way: { items (see Plan), index, ctx (the item being
-- prepared), withBank, ... }, and whether our bank is open.
local job
local bankOpen = false

-- Tells the materials list its button may have changed.
local function Changed()
    ns.Debounce("PrepareChanged", 0.2, function()
        ns.Fire("PrepareChanged")
    end)
end

-- Whether our bank is open (its items can be moved).
function Prepare.IsBankOpen()
    return bankOpen
end

-- Containers ---------------------------------------------------------------------------

-- Our bags' containers: the backpack, the bag slots and the reagent bag.
local function BagIDs()
    local ids = {}
    for bag = BACKPACK_CONTAINER or 0, (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0) do
        ids[#ids + 1] = bag
    end
    return ids
end

-- The bank's containers that hold items, while it is open: on WoW Forever,
-- its first tab (its own slots) and each bank bag slot bought (as Guild
-- Bank Alts reads them).
local function BankIDs()
    local bankType = Enum.BankType and Enum.BankType.Character or 0
    local bought = {}
    local tabs = C_Bank and ns.Try(C_Bank.FetchPurchasedBankTabData, bankType)
    if ns.CanRead(tabs) then
        for index, tab in ipairs(tabs) do
            bought[index] = ns.CanRead(tab) and ns.Number(tab.ID) or nil
        end
    end
    local first = (ITEM_INVENTORY_BANK_BAG_OFFSET or 5) + 1
    local maxTabs = C_Bank and ns.Number(ns.Try(C_Bank.FetchMaxNumBankTabs, bankType)) or NUM_CHARACTER_BANK_SLOTS or 9
    local ids = {}
    for index = 1, math.min(maxTabs, MAX_BANK_TABS) do
        if index == 1 or bought[index] then
            ids[#ids + 1] = bought[index] or (first + index - 1)
        end
    end
    return ids
end

-- Items ---------------------------------------------------------------------------------

-- A stack of the bags as kept stacks know it: the item's GUID; without it
-- (an older client), its slot.
local function Identity(bag, slot)
    local location = ItemLocation and ns.Try(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
    local guid = location and C_Item and ns.Plain(ns.Try(C_Item.GetItemGUID, location))
    if type(guid) == "string" and guid ~= "" then
        return guid
    end
    return "@" .. bag .. ":" .. slot
end

-- The stacks of an item in the containers given: { bag, slot, count,
-- locked, id (with identities) }.
local function Stacks(bags, itemID, identities)
    local list = {}
    for _, bag in ipairs(bags) do
        local size = ns.Number(ns.Try(C_Container.GetContainerNumSlots, bag)) or 0
        for slot = 1, size do
            local info = ns.Try(C_Container.GetContainerItemInfo, bag, slot)
            if ns.CanRead(info) and ns.Number(info.itemID) == itemID then
                list[#list + 1] = {
                    bag = bag, slot = slot, count = ns.Number(info.stackCount) or 0, locked = ns.Plain(info.isLocked) == true,
                    id = identities and Identity(bag, slot) or nil,
                }
            end
        end
    end
    return list
end

local function Total(stacks)
    local total = 0
    for _, stack in ipairs(stacks) do
        total = total + stack.count
    end
    return total
end

-- The stacks a step may move: not locked.
local function Usable(stacks)
    local list = {}
    for _, stack in ipairs(stacks) do
        if not stack.locked then
            list[#list + 1] = stack
        end
    end
    return list
end

-- Smallest first; of the same count, those kept first, then those in the
-- bags, then the bank's.
local function Rank(stack)
    return stack.own and 0 or stack.inBags and 1 or 2
end

local function BySize(stacks)
    table.sort(stacks, function(a, b)
        if a.count ~= b.count then
            return a.count < b.count
        elseif Rank(a) ~= Rank(b) then
            return Rank(a) < Rank(b)
        elseif a.bag ~= b.bag then
            return a.bag < b.bag
        end
        return a.slot < b.slot
    end)
    return stacks
end

local function MaxStack(itemID, seen)
    local size = ns.Number(ns.Try(C_Item.GetItemMaxStackSizeByID, itemID))
    if not size then
        size = ns.Number((select(8, ns.Try(C_Item.GetItemInfo, itemID))))
    end
    return size and size > 0 and size or math.max(seen, 1)
end

-- The bags items may be put in: not the reagent bag, nor a bag only for
-- some kind of items the item is not. Those only for its kind first (an
-- herb bag for herbs), keeping the others' slots for what only they take.
local function TargetBags(itemID)
    local special, general = {}, {}
    local family = ns.Number(ns.Try(C_Item.GetItemFamily, itemID)) or 0
    for bag = BACKPACK_CONTAINER or 0, NUM_BAG_SLOTS or 4 do
        local _, bagFamily = ns.Try(C_Container.GetContainerNumFreeSlots, bag)
        bagFamily = ns.Number(bagFamily) or 0
        if bagFamily == 0 then
            general[#general + 1] = bag
        elseif bit and bit.band(family, bagFamily) ~= 0 then
            special[#special + 1] = bag
        end
    end
    for _, bag in ipairs(general) do
        special[#special + 1] = bag
    end
    return special
end

-- The empty slots of our bags the item may go in: each material's items go
-- in stacks of their own, never onto another stack.
local function EmptySlots(itemID)
    local slots = {}
    for _, bag in ipairs(TargetBags(itemID)) do
        for slot = 1, ns.Number(ns.Try(C_Container.GetContainerNumSlots, bag)) or 0 do
            if not ns.Try(C_Container.GetContainerItemInfo, bag, slot) then
                slots[#slots + 1] = { bag = bag, slot = slot }
            end
        end
    end
    return slots
end

-- How many stacks count of the item takes at least.
local function StacksFor(count, size)
    return math.ceil(math.max(count, 0) / size)
end

-- Up to need of the item, from stacks sorted BySize: the stack, and how
-- many of it (fewer than it holds: split). A stack of just that many; else
-- that many split off the smallest bigger one; else the biggest there is,
-- whole.
local function Pick(stacks, need)
    for _, stack in ipairs(stacks) do
        if stack.count == need then
            return stack, need
        end
    end
    for _, stack in ipairs(stacks) do
        if stack.count > need then
            return stack, need
        end
    end
    local biggest = stacks[#stacks].count
    for _, stack in ipairs(stacks) do
        if stack.count == biggest then
            return stack, biggest
        end
    end
end

-- The next move, in the fewest stacks: from the stacks it may take, sorted
-- BySize, towards left, the count the material still lacks, with base the
-- stack being made up for it, if one is ({ count, target }). Returns the
-- stack, how many of it, and how:
--   "take": a stack of its own: kept where it is (a whole stack of the
--     bags), or moved or split off into an empty slot. Of the size of a
--     full one, or of what is left; else the biggest there is, if the rest
--     takes no more stacks than it would anyway;
--   "start": no stack will do on its own: one is made up of several,
--     starting with this one, whole (the biggest of the bags, kept where
--     it is; else the biggest, moved into an empty slot), to hold target
--     (the 4th value);
--   "onto": put onto the base, whole or split off.
local function NextMove(stacks, left, size, base)
    if base then
        local stack, count = Pick(stacks, math.min(left, base.target - base.count))
        return stack, count, "onto"
    end
    local want = math.min(left, size)
    local stack, count = Pick(stacks, want)
    if count == want or StacksFor(left - count, size) < StacksFor(left, size) then
        return stack, count, "take"
    end
    local start = stacks[#stacks]
    for _, other in ipairs(stacks) do
        if other.inBags then
            start = other
        end
    end
    return start, start.count, "start", want
end

-- Whether taking count of a stack keeps it as it is (no move).
local function InPlace(stack, count)
    return stack.inBags and count == stack.count
end

-- Whether a move takes an empty slot: a stack of its own, moved or split
-- off, or the start of one moved.
local function TakesSlot(stack, count, how)
    return how == "take" and not InPlace(stack, count) or how == "start" and not stack.inBags
end

-- The stack being made up when Prepare starts: the biggest kept one not
-- full (kept before, as when Prepare ran without the bank), to be filled up
-- with what is missing, if that takes fewer stacks than what is missing
-- would on its own; or nil.
local function OwnBase(own, missing, size)
    local base
    for _, stack in ipairs(own) do
        if stack.count < size and (not base or stack.count > base.count) then
            base = stack
        end
    end
    if not base or StacksFor(missing - (size - base.count), size) >= StacksFor(missing, size) then
        return nil
    end
    return { bag = base.bag, slot = base.slot, count = base.count, target = math.min(size, base.count + missing) }
end

-- How many empty slots getting what is missing takes, step by step as the
-- prepare step will (NextMove).
local function SlotsNeeded(stacks, missing, size, base)
    local copies = {}
    for index, stack in ipairs(stacks) do
        copies[index] = { count = stack.count, inBags = stack.inBags, bag = stack.bag, slot = stack.slot }
    end
    base = base and { count = base.count, target = base.target }
    local slots = 0
    while missing > 0 and #copies > 0 do
        BySize(copies)
        local stack, count, how, target = NextMove(copies, missing, size, base)
        if TakesSlot(stack, count, how) then
            slots = slots + 1
        end
        if how == "start" then
            base = { count = count, target = target }
        elseif how == "onto" then
            base.count = base.count + count
            if base.count >= base.target then
                base = nil
            end
        end
        stack.count = stack.count - count
        if stack.count <= 0 then
            for index, other in ipairs(copies) do
                if other == stack then
                    table.remove(copies, index)
                    break
                end
            end
        end
        missing = missing - count
    end
    return slots
end

-- Kept stacks -----------------------------------------------------------------------------

local function Prepared()
    local own = ns.Data.OwnState()
    own.prepared = own.prepared or {}
    return own.prepared
end

-- Keeps a stack of the bags for a material.
local function Keep(itemID, id, count)
    local prepared = Prepared()
    if type(prepared[itemID]) ~= "table" then
        prepared[itemID] = {}
    end
    prepared[itemID][id] = count
    ns.Fire("KeptChanged")
    Changed()
end

-- Which material keeps each stack: identity -> itemID.
local function Keepers()
    local keepers = {}
    for itemID, stacks in pairs(Prepared()) do
        if type(stacks) == "table" then
            for id in pairs(stacks) do
                keepers[id] = itemID
            end
        end
    end
    return keepers
end

-- What each material is to keep: { { itemID, target } } in the list's
-- order, and by item; nil while the guild is not known.
local function Targets()
    if not ns.Data.CurrentGuild(false) or not ns.playerGUID then
        return nil
    end
    local list, byItem = {}, {}
    for _, entry in ipairs((ns.MaterialsList.Totals())) do
        local target = math.max(entry.need - entry.coming, 0)
        list[#list + 1] = { itemID = entry.itemID, target = target }
        byItem[entry.itemID] = target
    end
    return list, byItem
end

-- Lets go of the stacks no longer kept: those gone from the bags or of
-- another count than they were kept with, those of materials no longer
-- needed, and, biggest first, those a material no longer needs (see the
-- top of this file).
function Prepare.Validate()
    if not ns.playerGUID or not ns.db then
        return
    end
    local prepared = Prepared()
    if next(prepared) == nil then
        return
    end
    local _, targets = Targets()
    if not targets then
        return
    end
    local held, any = {}, false
    for _, bag in ipairs(BagIDs()) do
        for slot = 1, ns.Number(ns.Try(C_Container.GetContainerNumSlots, bag)) or 0 do
            local info = ns.Try(C_Container.GetContainerItemInfo, bag, slot)
            if ns.CanRead(info) then
                any = true
                held[Identity(bag, slot)] = { count = ns.Number(info.stackCount), itemID = ns.Number(info.itemID) }
            end
        end
    end
    if not any then
        -- The bags not read yet (at login): nothing to tell.
        return
    end
    local changed, seen = false, {}
    for itemID, stacks in pairs(prepared) do
        local target = targets[itemID]
        if type(stacks) ~= "table" or not target or target <= 0 then
            prepared[itemID], changed = nil, true
        else
            local list, kept = {}, 0
            for id, count in pairs(stacks) do
                local stack = held[id]
                if not stack or stack.count ~= count or stack.itemID ~= itemID or seen[id] then
                    stacks[id], changed = nil, true
                else
                    seen[id] = true
                    kept = kept + count
                    list[#list + 1] = { id = id, count = count }
                end
            end
            table.sort(list, function(a, b)
                if a.count ~= b.count then
                    return a.count > b.count
                end
                return a.id < b.id
            end)
            for _, stack in ipairs(list) do
                if kept - stack.count >= target then
                    stacks[stack.id], changed = nil, true
                    kept = kept - stack.count
                end
            end
            if next(stacks) == nil then
                prepared[itemID] = nil
            end
        end
    end
    if changed then
        ns.Fire("KeptChanged")
    end
end

-- The material a stack of our bags is kept for (its item ID), or nil.
function Prepare.KeptAt(bag, slot)
    if not ns.playerGUID or not ns.db then
        return nil
    end
    local prepared = Prepared()
    if next(prepared) == nil then
        return nil
    end
    local info = ns.Try(C_Container.GetContainerItemInfo, bag, slot)
    if not ns.CanRead(info) then
        return nil
    end
    local itemID = ns.Number(info.itemID)
    local stacks = itemID and prepared[itemID]
    local count = ns.Number(info.stackCount)
    if type(stacks) == "table" and count and stacks[Identity(bag, slot)] == count then
        return itemID
    end
    return nil
end

-- The stacks of an item in the bags kept for it.
local function OwnStacks(itemID)
    local kept = Prepared()[itemID]
    local list = {}
    if type(kept) == "table" then
        for _, stack in ipairs(Usable(Stacks(BagIDs(), itemID, true))) do
            if kept[stack.id] == stack.count then
                stack.own = true
                list[#list + 1] = stack
            end
        end
    end
    return list
end

-- How many of an item our bags keep for the orders.
function Prepare.Kept(itemID)
    local kept = Prepared()[itemID]
    local count = 0
    if type(kept) == "table" then
        for _, stack in ipairs(Stacks(BagIDs(), itemID, true)) do
            if kept[stack.id] == stack.count then
                count = count + stack.count
            end
        end
    end
    return count
end

-- The stacks of an item that may be kept: in the bags, those kept for
-- nothing; with withBank, the bank's too.
local function FreeStacks(itemID, withBank)
    local keepers = Keepers()
    local list = {}
    for _, stack in ipairs(Usable(Stacks(BagIDs(), itemID, true))) do
        if not keepers[stack.id] then
            stack.inBags = true
            list[#list + 1] = stack
        end
    end
    if withBank then
        for _, stack in ipairs(Usable(Stacks(BankIDs(), itemID))) do
            list[#list + 1] = stack
        end
    end
    return list
end

-- The plan --------------------------------------------------------------------------------

-- What Prepare would do now: { items = { { itemID, size, missing, base,
-- slots } } for the materials it can add to, missing (in all), available
-- (of it, to be had now), kept (in all), slots (the empty slots it takes),
-- room (whether the bags have them), lacking = { [itemID] = count } (not to
-- be had now) }.
local function Plan(withBank)
    local plan = { items = {}, missing = 0, available = 0, kept = 0, slots = 0, room = true, lacking = {}, order = {} }
    for _, entry in ipairs(Targets() or {}) do
        local itemID = entry.itemID
        local own = OwnStacks(itemID)
        local kept = Total(own)
        local missing = math.max(entry.target - kept, 0)
        plan.kept = plan.kept + kept
        if missing > 0 then
            plan.missing = plan.missing + missing
            plan.order[#plan.order + 1] = itemID
            local free = FreeStacks(itemID, withBank)
            local held = Total(free)
            if held < missing then
                plan.lacking[itemID] = missing - held
            end
            if held > 0 then
                local seen = 0
                for _, stack in ipairs(Stacks(BagIDs(), itemID)) do
                    seen = math.max(seen, stack.count)
                end
                local size = MaxStack(itemID, seen)
                local base = OwnBase(own, missing, size)
                plan.items[#plan.items + 1] = {
                    itemID = itemID, size = size, missing = missing, base = base, brought = 0,
                    slots = SlotsNeeded(free, missing, size, base),
                }
                plan.available = plan.available + math.min(held, missing)
            end
        end
    end
    -- The bags' empty slots, each given to one material: those of the bags
    -- only for its kind first (TargetBags).
    local taken = {}
    for _, item in ipairs(plan.items) do
        plan.slots = plan.slots + item.slots
        local got = 0
        for _, empty in ipairs(EmptySlots(item.itemID)) do
            if got >= item.slots then
                break
            end
            local place = empty.bag .. ":" .. empty.slot
            if not taken[place] then
                taken[place], got = true, got + 1
            end
        end
        if got < item.slots then
            plan.room = false
        end
    end
    return plan
end

-- Waiting for the server ---------------------------------------------------------------

-- Where the last move is to leave the item: { bag, slot, count, keep } (0:
-- none left there; keep: the stack there is to be kept).
local function Expect(...)
    job.expected = { ... }
end

local function Shows(place)
    local info = ns.Try(C_Container.GetContainerItemInfo, place.bag, place.slot)
    if not info then
        return place.count == 0
    elseif not ns.CanRead(info) then
        return false
    elseif ns.Number(info.itemID) ~= job.ctx.itemID then
        return place.count == 0
    end
    return ns.Number(info.stackCount) == place.count and ns.Plain(info.isLocked) ~= true
end

-- Whether the last move shows done (the server carried it out). The stacks
-- it brought are then kept.
local function Arrived()
    for _, place in ipairs(job.expected or {}) do
        if not Shows(place) then
            return false
        end
    end
    for _, place in ipairs(job.expected or {}) do
        if place.keep and place.count > 0 then
            Keep(job.ctx.itemID, Identity(place.bag, place.slot), place.count)
        end
    end
    job.expected, job.since = nil, GetTime()
    return true
end

-- Moves ------------------------------------------------------------------------------------

-- A whole stack into an empty slot.
local function MoveTo(stack, empty)
    C_Container.PickupContainerItem(stack.bag, stack.slot)
    C_Container.PickupContainerItem(empty.bag, empty.slot)
    Expect({ bag = empty.bag, slot = empty.slot, count = stack.count, keep = true },
        { bag = stack.bag, slot = stack.slot, count = 0 })
end

-- One stack onto another, as much as fits.
local function Merge(from, to)
    local moved = math.min(from.count, job.ctx.size - to.count)
    C_Container.PickupContainerItem(from.bag, from.slot)
    C_Container.PickupContainerItem(to.bag, to.slot)
    Expect({ bag = to.bag, slot = to.slot, count = to.count + moved, keep = true },
        { bag = from.bag, slot = from.slot, count = from.count - moved, keep = from.own })
end

-- Part of a stack, into an empty slot or onto a stack of the item (to,
-- with its count): split off now, put down next step.
local function Split(stack, count, to)
    C_Container.SplitContainerItem(stack.bag, stack.slot, count)
    job.cursor = { from = stack, to = to, count = count }
end

local function PutDown()
    local split = job.cursor
    job.cursor = nil
    C_Container.PickupContainerItem(split.to.bag, split.to.slot)
    Expect({ bag = split.to.bag, slot = split.to.slot, count = (split.to.count or 0) + split.count, keep = true },
        { bag = split.from.bag, slot = split.from.slot, count = split.from.count - split.count, keep = split.from.own })
end

-- One step for the material being prepared (job.ctx): what it lacks, kept
-- in the bags in the fewest stacks (NextMove). Returns true when it moved
-- something or waits, nil when the material is done.
local function PrepareStep(ctx)
    if not Arrived() then
        return true
    elseif job.cursor then
        PutDown()
        return true
    end
    local left = ctx.missing - ctx.brought
    if left <= 0 then
        return nil
    end
    local base = ctx.base
    if base and not Shows({ bag = base.bag, slot = base.slot, count = base.count }) then
        -- The stack being made up is no longer as it was left (moved by
        -- hand): the rest goes in stacks of its own.
        ctx.base, base = nil, nil
    end
    local stacks = BySize(FreeStacks(ctx.itemID, job.withBank))
    if #stacks == 0 then
        return nil
    end
    local stack, count, how, target = NextMove(stacks, left, ctx.size, base)
    if how == "onto" then
        if count < stack.count then
            Split(stack, count, { bag = base.bag, slot = base.slot, count = base.count })
        else
            Merge(stack, base)
        end
        base.count = base.count + count
        if base.count >= base.target then
            ctx.base = nil
        end
    elseif InPlace(stack, count) then
        Keep(ctx.itemID, stack.id, count)
        if how == "start" then
            ctx.base = { bag = stack.bag, slot = stack.slot, count = count, target = target }
        end
    else
        local empty = EmptySlots(ctx.itemID)[1]
        if not empty then
            job.full = true
            return nil
        elseif count < stack.count then
            Split(stack, count, empty)
        else
            MoveTo(stack, empty)
        end
        if how == "start" then
            ctx.base = { bag = empty.bag, slot = empty.slot, count = count, target = target }
        end
    end
    ctx.brought = ctx.brought + count
    return true
end

-- Running --------------------------------------------------------------------------------

local Advance

local function Stop(message, ...)
    if job and job.cursor then
        ClearCursor()
    end
    job = nil
    if message then
        ns.Print(message, ...)
    end
    Changed()
end

local function Continue()
    job.steps = job.steps + 1
    C_Timer.After(STEP, Advance)
end

local function NoRoom(slots)
    ns.Print(L["not enough room in your bags: %d free |4slot:slots; needed. Free some and try again."], slots)
end

-- An item for the chat: its link, else its name.
local function ItemText(itemID, count)
    local link = select(2, ns.Try(C_Item.GetItemInfo, itemID))
    local text = ns.Plain(link) or C_Item.GetItemNameByID(itemID) or ("item:" .. itemID)
    return count > 1 and ("%s x%d"):format(text, count) or text
end

-- One line: all is kept, or what is still missing.
local function Done()
    if job.full then
        NoRoom(job.slots)
        return
    end
    local byItem = {}
    for _, item in ipairs(job.items) do
        byItem[item.itemID] = item
    end
    local missing = {}
    for _, itemID in ipairs(job.order) do
        local item = byItem[itemID]
        local lacking = item and item.missing - item.brought or job.lacking[itemID] or 0
        if lacking > 0 then
            missing[#missing + 1] = ItemText(itemID, lacking)
        end
    end
    if #missing == 0 then
        ns.Print(L["materials ready in your bags."])
    else
        ns.Print(L["materials kept in your bags; still missing: %s."], table.concat(missing, ", "))
    end
end

Advance = function()
    if not job then
        return
    end
    -- The server too slow, or the bank closed before the end.
    if GetTime() - job.since > TIMEOUT or job.steps > MAX_STEPS or (job.withBank and not bankOpen) then
        ns.Debug("prepare: stopped (%d steps, expecting %d places)", job.steps, #(job.expected or {}))
        Stop(L["the items did not move in time: try again."])
        return
    end
    while job.ctx do
        if PrepareStep(job.ctx) then
            Continue()
            return
        elseif job.full then
            break
        end
        job.index = job.index + 1
        job.ctx = job.items[job.index]
    end
    Done()
    Stop()
end

-- The button ---------------------------------------------------------------------------------

-- The materials list's button: { action, text, enabled, tip }. Prepare;
-- or, once something is kept and Prepare can add no more to it (all is,
-- or the rest is not to be had now), Release all.
function Prepare.Action()
    local action = { action = "prepare", text = L["Prepare"] }
    if job then
        action.tip = L["The materials are being prepared: wait a moment."]
        return action
    end
    local withBank = bankOpen
    local plan = Plan(withBank)
    if plan.available > 0 then
        if not plan.room then
            action.tip = L["Not enough room in your bags: %d free |4slot:slots; needed."]:format(plan.slots)
        else
            action.enabled = true
            action.tip = withBank and L["Keeps in your bags the materials still missing: from your bags' stacks not kept yet, and from your bank."]
                or L["Keeps in your bags the materials still missing, from your bags' stacks not kept yet."]
            if plan.available < plan.missing then
                action.tip = action.tip .. "\n" .. (withBank and L["Your bank and bags hold only part of them."]
                    or L["Your bags hold only part of them: open your bank to bring the rest."])
            end
        end
    elseif plan.missing > 0 then
        action.tip = withBank and L["Your bank and bags hold none of the materials still missing."]
            or L["Your bags hold none of the materials still missing: open your bank to bring them."]
    elseif plan.kept == 0 then
        action.tip = #ns.MaterialsList.Orders() > 0 and L["Their requesters are to send all the materials still missing."]
            or L["You have no accepted orders to make."]
    end
    if action.enabled or plan.kept == 0 then
        return action
    end
    local release = { action = "release", text = L["Release all"], enabled = true, tip = L["Lets go of the materials kept in your bags."] }
    if action.tip then
        -- Not all of them: why Prepare cannot get the rest.
        release.tip = release.tip .. "\n" .. action.tip
    end
    return release
end

function Prepare.Busy()
    return job ~= nil
end

-- Lets go of every kept stack.
local function Release()
    Prepare.Validate()
    local prepared = Prepared()
    local any = next(prepared) ~= nil
    wipe(prepared)
    ns.Fire("KeptChanged")
    Changed()
    if any then
        ns.Print(L["materials no longer kept in your bags."])
    end
end

-- Runs the button's action ("prepare" or "release"). Returns true if it
-- started (or, Release all, was done).
function Prepare.Run(action)
    if job then
        ns.Print(L["still preparing the materials."])
        return false
    elseif action == "release" then
        Release()
        return true
    elseif CursorHasItem() then
        ns.Print(L["put down what you hold on the cursor first."])
        return false
    end
    Prepare.Validate()
    local withBank = bankOpen
    local plan = Plan(withBank)
    if plan.available == 0 then
        return false
    elseif not plan.room then
        NoRoom(plan.slots)
        return false
    end
    job = {
        items = plan.items, order = plan.order, lacking = plan.lacking, slots = plan.slots, index = 1, ctx = plan.items[1],
        withBank = withBank, since = GetTime(), steps = 0,
    }
    ns.Debug("prepare: %d materials, %d of %d missing to be had%s", #plan.items, plan.available, plan.missing,
        withBank and ", with the bank" or "")
    Changed()
    Advance()
    return true
end

-- Init -----------------------------------------------------------------------------------------

-- The windows the game opens through its player interactions (on WoW
-- Forever, as on Retail, the bank opens this way; BANKFRAME_* too).
local INTERACTION = Enum.PlayerInteractionType or {}
local BANKERS = { [INTERACTION.Banker or 8] = true, [INTERACTION.CharacterBanker or 67] = true }

-- Kept stacks are checked again whenever the bags change, and when orders
-- may have changed. The button changes with the bags and the bank.
function Prepare.Init()
    local events = CreateFrame("Frame")
    ns.RegisterEvents(events, "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
        "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    events:SetScript("OnEvent", function(_, event, kind)
        kind = ns.Plain(kind)
        if event == "BAG_UPDATE_DELAYED" then
            Prepare.Validate()
        elseif event == "BANKFRAME_OPENED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and BANKERS[kind]) then
            bankOpen = true
        elseif event == "BANKFRAME_CLOSED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and BANKERS[kind]) then
            bankOpen = false
        end
        Changed()
    end)
    ns.On("DataChanged", function()
        ns.Debounce("PrepareValidate", 2, Prepare.Validate)
    end)
    ns.On("KeptChanged", Changed)
end
