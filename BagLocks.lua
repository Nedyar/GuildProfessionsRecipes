-- BagLocks.lua: a padlock in the top right corner of each stack of the bags
-- kept for the orders we accepted (Prepare.lua), in the game's bag
-- windows, so the player does not split or move it out by mistake, as
-- Guild Bank Alts shows the stacks it keeps. The padlock's own tooltip says
-- what it is kept for and what lets it go; it goes away once the stack is
-- no longer kept.
--
-- The game redraws a bag window's item buttons in its UpdateItems method
-- (each of ContainerFrame1..N, and ContainerFrameCombinedBags): the
-- padlocks follow it, and are redrawn when kept stacks change.
local _, ns = ...
local L = ns.L

local BagLocks = {}
ns.BagLocks = BagLocks

local ATLAS = "Bags-padlock-authenticator"
-- Within the item's icon (37 x 37), in its top right corner, clear of the
-- stack count at the bottom.
local WIDTH, HEIGHT, INSET = 18, 22, 2

local locks = setmetatable({}, { __mode = "k" })  -- item button -> its padlock
local frames = {}                                  -- the bag windows followed

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Kept for your crafting orders"])
    GameTooltip:AddLine(L["Moving it within your bags keeps it. Splitting it, adding to it or taking it out of your bags lets it go."],
        nil, nil, nil, true)
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

local function Lock(button)
    local lock = locks[button]
    if not lock then
        lock = CreateFrame("Frame", nil, button)
        lock:SetSize(WIDTH, HEIGHT)
        lock:SetPoint("TOPRIGHT", button, "TOPRIGHT", -INSET, -INSET)
        lock:SetFrameLevel(button:GetFrameLevel() + 5)
        local icon = lock:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        icon:SetAtlas(ATLAS)
        lock:EnableMouse(true)
        lock:SetScript("OnEnter", OnEnter)
        lock:SetScript("OnLeave", OnLeave)
        locks[button] = lock
    end
    return lock
end

local function UpdateButton(button)
    local bag, slot = button.GetBagID and button:GetBagID(), button:GetID()
    if bag and slot and ns.Prepare.KeptAt(bag, slot) then
        Lock(button):Show()
    elseif locks[button] then
        locks[button]:Hide()
    end
end

local function UpdateFrame(frame)
    if not frame.EnumerateValidItems then
        return
    end
    for _, button in frame:EnumerateValidItems() do
        UpdateButton(button)
    end
end

-- Redraws the padlocks of the bag windows shown.
function BagLocks.Refresh()
    for frame in pairs(frames) do
        if frame:IsShown() then
            UpdateFrame(frame)
        end
    end
end

-- The padlock of an item button, if it ever had one (for the tests).
function BagLocks.LockOf(button)
    return locks[button]
end

function BagLocks.Init()
    local list = { ContainerFrameCombinedBags }
    for index = 1, math.max(NUM_CONTAINER_FRAMES or 0, 13) do
        list[#list + 1] = _G["ContainerFrame" .. index]
    end
    for _, frame in pairs(list) do
        if type(frame) == "table" and frame.UpdateItems and not frames[frame] then
            frames[frame] = true
            hooksecurefunc(frame, "UpdateItems", UpdateFrame)
        end
    end
    if not BagLocks.listening then
        BagLocks.listening = true
        ns.On("KeptChanged", BagLocks.Refresh)
    end
end
