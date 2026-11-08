-- Pack.lua: the compact binary form records travel in, Base64, and hashing.
-- Plain Lua with no game API, so it can be tested outside the game.
local _, ns = ...

local Pack = {}
ns.Pack = Pack

local byte, char, floor, sub = string.byte, string.char, math.floor, string.sub
local concat = table.concat

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
    days = 30,         -- how long an order may stay open
    tip = 100000000,   -- copper: 10,000 gold
}

-- The record format this version writes: 3 adds crafting orders (0.8).
-- Format 2 (0.2 to 0.7) is still read.
Pack.FORMAT = 3

local TWO_32 = 4294967296
local TWO_53 = 9007199254740992

-- Writer ---------------------------------------------------------------------

local Writer = {}
Writer.__index = Writer

function Pack.Writer()
    return setmetatable({ n = 0 }, Writer)
end

function Writer:Byte(value)
    self.n = self.n + 1
    self[self.n] = char(value)
end

-- Unsigned integers take 7 bits per byte (LEB128): 1 byte below 128,
-- 3 bytes for recipe IDs above a million.
function Writer:UInt(value)
    value = floor(value)
    if value < 0 or value >= TWO_53 then
        error("number out of range: " .. tostring(value), 2)
    end
    while value >= 128 do
        self:Byte(value % 128 + 128)
        value = floor(value / 128)
    end
    self:Byte(value)
end

function Writer:Str(text)
    self:UInt(#text)
    self:Raw(text)
end

-- Appends bytes that are already packed.
function Writer:Raw(text)
    self.n = self.n + 1
    self[self.n] = text
end

function Writer:Size()
    local size = 0
    for i = 1, self.n do
        size = size + #self[i]
    end
    return size
end

function Writer:Result()
    return concat(self, "", 1, self.n)
end

-- Reader ---------------------------------------------------------------------

-- Every read raises on malformed input; callers read under pcall.
local Reader = {}
Reader.__index = Reader

function Pack.Reader(text)
    return setmetatable({ s = text, pos = 1, len = #text }, Reader)
end

function Reader:Byte()
    local value = byte(self.s, self.pos)
    if not value then
        error("truncated message", 0)
    end
    self.pos = self.pos + 1
    return value
end

function Reader:UInt()
    local value, scale = 0, 1
    for _ = 1, 8 do
        local b = self:Byte()
        if b < 128 then
            return value + b * scale
        end
        value = value + (b - 128) * scale
        scale = scale * 128
    end
    error("malformed number", 0)
end

function Reader:Str(maxLength)
    local length = self:UInt()
    if length > (maxLength or Pack.LIMITS.text) then
        error("text too long", 0)
    end
    if self.pos + length - 1 > self.len then
        error("truncated message", 0)
    end
    local text = sub(self.s, self.pos, self.pos + length - 1)
    self.pos = self.pos + length
    return text
end

function Reader:AtEnd()
    return self.pos > self.len
end

-- Recipe lists ---------------------------------------------------------------

-- A sorted list of distinct recipe IDs, stored as the gaps between them:
-- most gaps fit in one byte even where the IDs themselves need three.
function Pack.WriteList(writer, list)
    writer:UInt(#list)
    local previous = 0
    for i = 1, #list do
        writer:UInt(list[i] - previous)
        previous = list[i]
    end
end

function Pack.ReadList(reader, max)
    local count = reader:UInt()
    if count > (max or Pack.LIMITS.recipes) then
        error("too many recipes", 0)
    end
    local list, previous = {}, 0
    for i = 1, count do
        local gap = reader:UInt()
        if gap == 0 then
            error("recipe list not sorted", 0)
        end
        previous = previous + gap
        list[i] = previous
    end
    return list
end

-- Records --------------------------------------------------------------------

-- A record is what one member shares about themselves, under their GUID:
--   { n = their name, t = time of their last change, av = addon version,
--     p = { [skillLineID] = { r = rank, m = max rank, o = display order,
--                             lk = the profession's spell, k = recipes } },
--     o = the crafting orders they requested (format 3, see Orders.lua):
--         { [id] = { sl, r = recipe, q = quantity, d = GUID it is directed
--                    to or nil, m = they provide the materials, tip = copper,
--                    note, c = created, u = updated, e = days it lasts,
--                    s = state } },
--     a = their answers to others' orders (format 3):
--         { ["<requester GUID>:<id>"] = { s = state, u = time,
--                                         ou = the order's u answered } } }
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
local function WriteOrders(writer, record)
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
        writer:UInt(order.e)
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
    end
end

local function ReadOrders(reader, record)
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
        order.c, order.u, order.e, order.s = reader:UInt(), reader:UInt(), reader:UInt(), reader:Byte()
        record.o[id] = order
    end
    count = reader:UInt()
    if count > Pack.LIMITS.answers + 1 then
        error("too many answers", 0)
    end
    record.a = count > 0 and {} or nil
    for _ = 2, count do
        local key = reader:Str()
        record.a[key] = { s = reader:Byte(), u = reader:UInt(), ou = reader:UInt() }
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
    if (format or Pack.FORMAT) >= 3 then
        WriteOrders(writer, record)
    end
end

-- Returns guid, record. The record still has to be checked (Data.CleanRecord).
-- format: the one it was written in (Pack.FORMAT unless given). A format 2
-- record has no o and a: nothing is known of its owner's orders.
function Pack.ReadRecord(reader, format)
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
            prof.k = Pack.ReadList(reader)
        elseif state ~= K_UNKNOWN then
            error("bad recipe state", 0)
        end
        record.p[skillLine] = prof
    end
    if (format or Pack.FORMAT) >= 3 then
        ReadOrders(reader, record)
    end
    return guid, record
end

function Pack.RecordString(key, record, format)
    local writer = Pack.Writer()
    Pack.WriteRecord(writer, key, record, format)
    return writer:Result()
end

-- Hashing --------------------------------------------------------------------

-- djb2, kept to 32 bits. Exact with Lua's doubles, so no bit library is needed.
function Pack.Hash(text, seed)
    local hash = seed or 5381
    for i = 1, #text do
        hash = (hash * 33 + byte(text, i)) % TWO_32
    end
    return hash
end

function Pack.AddHash(a, b)
    return (a + b) % TWO_32
end

-- Base64 ---------------------------------------------------------------------

-- The client's C_EncodingUtil does this natively; this version is the
-- fallback, and the digits are reused for the message headers.
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DIGIT, VALUE = {}, {}
for i = 1, 64 do
    local c = sub(ALPHABET, i, i)
    DIGIT[i - 1] = c
    VALUE[c] = i - 1
end

-- A single Base64 digit: 0..63 <-> one character.
function Pack.Digit(value)
    return DIGIT[value]
end

function Pack.DigitValue(c)
    return VALUE[c]
end

function Pack.ToBase64(text)
    local out = {}
    for i = 1, #text, 3 do
        local a, b, c = byte(text, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        out[#out + 1] = DIGIT[floor(n / 262144)] .. DIGIT[floor(n / 4096) % 64]
            .. (b and DIGIT[floor(n / 64) % 64] or "=") .. (c and DIGIT[n % 64] or "=")
    end
    return concat(out)
end

function Pack.FromBase64(text)
    if #text % 4 ~= 0 then
        return nil
    end
    local out = {}
    for i = 1, #text, 4 do
        local c1, c2, c3, c4 = sub(text, i, i), sub(text, i + 1, i + 1), sub(text, i + 2, i + 2), sub(text, i + 3, i + 3)
        local v1, v2 = VALUE[c1], VALUE[c2]
        local v3, v4 = VALUE[c3], VALUE[c4]
        if not v1 or not v2 or (not v3 and c3 ~= "=") or (not v4 and c4 ~= "=") then
            return nil
        end
        -- Padding only at the very end, and "x=y" is never valid.
        if (not v4 and i + 3 < #text) or (not v3 and v4) then
            return nil
        end
        local n = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
        out[#out + 1] = char(floor(n / 65536))
        if v3 then
            out[#out + 1] = char(floor(n / 256) % 256)
        end
        if v4 then
            out[#out + 1] = char(n % 256)
        end
    end
    return concat(out)
end
