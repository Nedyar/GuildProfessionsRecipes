-- Pack.lua: the packed form of the addon's records (LibGuildSync's Pack.lua
-- has the numbers, texts, lists, Base64 and hashing they are made of).
-- Plain Lua with no game API, so it can be tested outside the game.
local _, ns = ...

local Pack = ns.Pack

-- The most a record may hold. Anything bigger is refused when read.
Pack.LIMITS = {
    professions = 10,
    recipes = 1500,
    rank = 1000,
    text = 64,
    orders = 20,       -- crafting orders a member has requested
    answers = 60,      -- answers a member has given to others' orders
    note = 200,        -- bytes of an order's note
    quantity = 999,
    days = 30,         -- how long an order of 0.8 (format 3) lasted
    tip = 100000000,   -- copper: 10,000 gold
}

-- The record format this version writes: 3 added crafting orders (0.8), 4
-- drops their expiry and counts deliveries (0.9). Formats 2 (0.2 to 0.7)
-- and 3 are still read.
Pack.FORMAT = 4

-- Records --------------------------------------------------------------------

-- A record is what one member shares about themselves, under their GUID:
--   { n = their name, t = time of their last change, av = addon version,
--     p = { [skillLineID] = { r = rank, m = max rank, o = display order,
--                             lk = the profession's spell, k = recipes } },
--     o = the crafting orders they requested (from format 3, see Orders.lua):
--         { [id] = { sl, r = recipe, q = quantity, d = GUID it is directed
--                    to or nil, m = they provide the materials, tip = copper,
--                    note, c = created, u = updated, s = state,
--                    e = days it lasted, in format 3 only } },
--     a = their answers to others' orders (from format 3):
--         { ["<requester GUID>:<id>"] = { s = state, u = time,
--                                         ou = the order's u answered,
--                                         n = items delivered, p = copper
--                                         of the tip received (format 4) } } }
-- k is a sorted list of recipe IDs, false for professions without recipes,
-- or nil while the owner's recipes have not been read.
local K_UNKNOWN, K_NONE, K_LIST = 0, 1, 2

local function SortedKeys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

-- Each list starts with its count plus one, or 0 when unknown (nil): a
-- client that lost its data does not tell the guild it has no orders.
local function WriteOrders(writer, record, format)
    local orders = record.o or {}
    local ids = SortedKeys(orders)
    writer:UInt(record.o and #ids + 1 or 0)
    for _, id in ipairs(ids) do
        local order = orders[id]
        writer:UInt(id)
        writer:UInt(order.sl)
        writer:UInt(order.r)
        writer:UInt(order.q)
        writer:Str(order.d or "")
        writer:Byte(order.m and 1 or 0)
        writer:UInt(order.tip or 0)
        writer:Str(order.note or "")
        writer:UInt(order.c)
        writer:UInt(order.u)
        if format == 3 then
            writer:UInt(order.e or Pack.LIMITS.days)
        end
        writer:Byte(order.s or 0)
    end
    local answers = record.a or {}
    local keys = SortedKeys(answers)
    writer:UInt(record.a and #keys + 1 or 0)
    for _, key in ipairs(keys) do
        local answer = answers[key]
        writer:Str(key)
        writer:Byte(answer.s)
        writer:UInt(answer.u)
        writer:UInt(answer.ou)
        if format >= 4 then
            writer:UInt(answer.n or 0)
            writer:UInt(answer.p or 0)
        end
    end
end

local function ReadOrders(reader, record, format)
    local count = reader:UInt()
    if count > Pack.LIMITS.orders + 1 then
        error("too many orders", 0)
    end
    record.o = count > 0 and {} or nil
    for _ = 2, count do
        local id = reader:UInt()
        local order = { sl = reader:UInt(), r = reader:UInt(), q = reader:UInt() }
        local target = reader:Str()
        order.d = target ~= "" and target or nil
        order.m = reader:Byte() == 1
        order.tip = reader:UInt()
        order.note = reader:Str(Pack.LIMITS.note)
        order.c, order.u = reader:UInt(), reader:UInt()
        if format == 3 then
            order.e = reader:UInt()
        end
        order.s = reader:Byte()
        record.o[id] = order
    end
    count = reader:UInt()
    if count > Pack.LIMITS.answers + 1 then
        error("too many answers", 0)
    end
    record.a = count > 0 and {} or nil
    for _ = 2, count do
        local key = reader:Str()
        local answer = { s = reader:Byte(), u = reader:UInt(), ou = reader:UInt() }
        if format >= 4 then
            local delivered, tip = reader:UInt(), reader:UInt()
            answer.n = delivered > 0 and delivered or nil
            answer.p = tip > 0 and tip or nil
        end
        record.a[key] = answer
    end
end

-- format: the one to write (Pack.FORMAT unless given; 2 has no orders).
function Pack.WriteRecord(writer, guid, record, format)
    writer:Str(guid)
    writer:Str(record.n or "")
    writer:UInt(record.t)
    writer:UInt(record.av or 0)
    local skillLines = SortedKeys(record.p)
    writer:UInt(#skillLines)
    for _, skillLine in ipairs(skillLines) do
        local prof = record.p[skillLine]
        writer:UInt(skillLine)
        writer:UInt(prof.r)
        writer:UInt(prof.m)
        writer:UInt(prof.o or 0)
        writer:UInt(prof.lk or 0)
        if prof.k == nil then
            writer:Byte(K_UNKNOWN)
        elseif prof.k == false then
            writer:Byte(K_NONE)
        else
            writer:Byte(K_LIST)
            Pack.WriteList(writer, prof.k)
        end
    end
    format = format or Pack.FORMAT
    if format >= 3 then
        WriteOrders(writer, record, format)
    end
end

-- Returns guid, record. The record still has to be checked (Data.CleanRecord).
-- format: the one it was written in (Pack.FORMAT unless given; LibGuildSync
-- gives the protocol a message came in, as text). A format 2
-- record has no o and a: nothing is known of its owner's orders.
function Pack.ReadRecord(reader, format)
    format = tonumber(format) or Pack.FORMAT
    local guid = reader:Str()
    local name = reader:Str()
    local record = { t = reader:UInt(), av = reader:UInt(), p = {} }
    if name ~= "" then
        record.n = name
    end
    local count = reader:UInt()
    if count > Pack.LIMITS.professions then
        error("too many professions", 0)
    end
    for _ = 1, count do
        local skillLine = reader:UInt()
        local prof = { r = reader:UInt(), m = reader:UInt(), o = reader:UInt(), lk = reader:UInt() }
        if prof.lk == 0 then
            prof.lk = nil
        end
        local state = reader:Byte()
        if state == K_NONE then
            prof.k = false
        elseif state == K_LIST then
            prof.k = Pack.ReadList(reader, Pack.LIMITS.recipes)
        elseif state ~= K_UNKNOWN then
            error("bad recipe state", 0)
        end
        record.p[skillLine] = prof
    end
    if format >= 3 then
        ReadOrders(reader, record, format)
    end
    return guid, record
end
