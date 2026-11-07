-- GuildTab.lua: a "Recipes & Orders" tab on the guild window, under
-- Blizzard's own side tabs (Chat, Roster, Guild Info...). For now it is shown
-- disabled; its panel comes in a later version.
--
-- Like the roster column, it only hooks and reads Blizzard's frames: it never
-- changes the guild window's display mode, so the window's own actions stay
-- untouched.
local _, ns = ...
local L = ns.L

local GuildTab = {}
ns.GuildTab = GuildTab

local ICON = "Interface\\Icons\\INV_Scroll_03"
local TAB_GAP = 20       -- between Blizzard's tabs
local TAB_LEVEL = 510    -- Blizzard's tabs' frame level
-- Blizzard's tabs, top to bottom.
local BLIZZARD_TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }

local tab

-- Runs after Blizzard lays out its tabs. Ours goes under the lowest one,
-- and only while Guild Info shows: on the guild, in the views with tabs.
local function Update(communities)
    local last
    for _, key in ipairs(BLIZZARD_TABS) do
        local other = communities[key]
        if other and other:IsShown() then
            last = other
        end
    end
    local guildInfo = communities.GuildInfoTab
    local show = last ~= nil and guildInfo ~= nil and guildInfo:IsShown()
    tab:SetShown(show)
    if show then
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -TAB_GAP)
    end
end

local function Setup()
    local communities = CommunitiesFrame
    if tab or not (communities and communities.UpdateCommunitiesTabs) then
        return
    end
    tab = CreateFrame("CheckButton", "GuildProfessionsRecipesGuildTab", communities, "RightSideTabTemplate")
    tab:SetFrameLevel(TAB_LEVEL)
    tab.Icon:SetTexture(ICON)
    tab.tooltip = L["Recipes & Orders (coming soon)"]
    -- As the game shows its Chat tab when chat is unavailable: a dark icon,
    -- with the tooltip still shown.
    tab.IconOverlay:Show()
    tab:SetMotionScriptsWhileDisabled(true)
    tab:SetEnabled(false)
    tab:Hide()
    hooksecurefunc(communities, "UpdateCommunitiesTabs", Update)
    Update(communities)
end

function GuildTab.Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", Setup)
end
