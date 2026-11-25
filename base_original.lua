-- ====================================================================
-- ⚡ 7Z HUB v3.1
-- ====================================================================

-- Non-blocking game load check (safe on Delta & mobile)
pcall(function()
    if not game:IsLoaded() then
        local t = 0
        while not game:IsLoaded() and t < 5 do
            t = t + task.wait(0.5)
        end
    end
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    LocalPlayer = Players.LocalPlayer
    task.wait(0.1)
end

local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)

local function safeRequire(fn)
    local ok, res = pcall(fn)
    if ok and res then return res end
    return nil
end

local RaidsManager = nil
local EnemyManager = nil
local MapManager = nil
local AgentManager = nil
local BattleService = nil
local PlayerManager = nil
local UIManager = nil
local ProtocolManager = nil
local TipsManager = nil
local ConfigManager = nil
local PlayerEntityHelper = nil
local SoundManager = nil
local hookItemDropServices = nil
local hookTipsManager = nil
local hookUIManager = nil

local function ensureManagers()
    if not RaidsManager then RaidsManager = safeRequire(function() return require(ReplicatedStorage.Scripts.Client.Manager.RaidsManager) end) end
    if not EnemyManager then EnemyManager = safeRequire(function() return require(ReplicatedStorage.Scripts.Client.Manager.EnemyManager) end) end
    if not MapManager then MapManager = safeRequire(function() return require(ReplicatedStorage.Scripts.Client.Manager.MapManager) end) end
    if not AgentManager then AgentManager = safeRequire(function() return require(ReplicatedStorage.Scripts.Share.Manager.AgentManager) end) end
    if not BattleService then BattleService = safeRequire(function() return require(ReplicatedStorage.Scripts.Client.Services.BattleService) end) end
    if not PlayerManager then PlayerManager = safeRequire(function() return require(ReplicatedStorage.Scripts.Client.Manager.PlayerManager) end) end
    if not UIManager then UIManager = safeRequire(function() return require(ReplicatedStorage.Scripts.Client.Manager.UIManager) end) end
    if not ProtocolManager then ProtocolManager = safeRequire(function() return require(ReplicatedStorage.Scripts.Share.Manager.ProtocolManager) end) end
    if not TipsManager then TipsManager = safeRequire(function() return require(ReplicatedStorage.Scripts.Client.Manager.TipsManager) end) end
    if not ConfigManager then ConfigManager = safeRequire(function() return require(ReplicatedStorage.Scripts.Share.Manager.ConfigManager) end) end
    if not PlayerEntityHelper then PlayerEntityHelper = safeRequire(function() return require(ReplicatedStorage.Scripts.Share.PlayerEntityHelper) end) end
    if not SoundManager then SoundManager = safeRequire(function() return require(ReplicatedStorage.Scripts.Client.Manager.SoundManager) end) end
    if hookTipsManager then hookTipsManager() end
    if hookUIManager then hookUIManager() end
    if hookItemDropServices then hookItemDropServices() end
    return MapManager ~= nil and RaidsManager ~= nil
end

-- ไม่เรียก ensureManagers() ตรงนี้ เพื่อไม่ให้ require โมดูลเกมก่อนที่เกมจะโหลดเสร็จ (แก้ค้างหน้าโหลด 100%)

-- Forward declarations of GUI elements used across functions
local RaidStatusLabel = nil
local FarmStatusLabel = nil
local InfoText = nil
local TierSelector = nil
local MapSelector = nil
local TypeSelector = nil
local ToggleRaidBtn = nil
local ToggleFarmBtn = nil
local TierModal = nil

local OPT = {
    hideDamageEnabled = false,
    damageHooked = false,
    HideDamageBtn = nil,
    hideSkillEffectsEnabled = false,
    skillEffectsHooked = false,
    HideSkillEffectsBtn = nil,
    secConn = nil,
    isMinimized = false,
    currentTab = 1,
    MinimizeBtn = nil,
    minKeyConn = nil,
    redeemingCodes = false,
    CodesBtn = nil,
    db = {
        featureId = 900001,
        autoLoop = false,
        collecting = false,
        snap = nil,
        lastFetchAt = 0,
        lastCollectedRound = nil,
        retryAfter = 0,
        retryRound = nil,
        retryCount = 0,
        StatusLabel = nil,
        ListLabel = nil,
        ScanBtn = nil,
        CollectBtn = nil,
        AutoBtn = nil,
    },
}

-- ====================================================================
-- ระบบแจ้งเตือนดาเมจ 1% บนหัวตัวละคร (Boss 1% Indicator)
-- ====================================================================
local BossAlert = {
    enabled = true,
    targetGuid = nil,
    targetName = nil,
    targetMaxHp = nil,
    targetInitialHp = nil,
    reached1Pct = false,
    lastReachedGuid = nil,
    clearAt = 0,
    billboard = nil,
    mainFrame = nil,
    titleLabel = nil,
    pctLabel = nil,
    barFill = nil,
    stroke = nil,
    Button = nil,
}

-- ====================================================================
-- ข้อมูลเรดปกติ (Normal Raids: แมพ 1 Event, แมพ 13 - 22)
-- ====================================================================
local NORMAL_RAID_LIST = {
    { name = "Map 1: Vampire Event",      mapId = 50001, raidMapId = 50403, isEvent = true, eventRaidId = 937102 },
    { name = "Map 13: Lava Hell",          mapId = 50013, raidMapId = 50113, baseId = 930120, validRaidMin = 930121, validRaidMax = 930130 },
    { name = "Map 14: Illusory World",     mapId = 50014, raidMapId = 50114, baseId = 930130, validRaidMin = 930131, validRaidMax = 930140 },
    { name = "Map 15: Inferno Altar",      mapId = 50015, raidMapId = 50115, baseId = 930140, validRaidMin = 930141, validRaidMax = 930150 },
    { name = "Map 16: Shadow Throne",      mapId = 50016, raidMapId = 50116, baseId = 930150, validRaidMin = 930151, validRaidMax = 930160 },
    { name = "Map 17: Angel Holy",         mapId = 50017, raidMapId = 50117, baseId = 930160, validRaidMin = 930161, validRaidMax = 930170 },
    { name = "Map 18: Golden Throne",      mapId = 50018, raidMapId = 50118, baseId = 930170, validRaidMin = 930171, validRaidMax = 930180 },
    { name = "Map 19: Dragonball City",    mapId = 50019, raidMapId = 50119, baseId = 930180, validRaidMin = 930181, validRaidMax = 930190 },
    { name = "Map 20: DB Wasteland",       mapId = 50020, raidMapId = 50120, baseId = 930190, validRaidMin = 930191, validRaidMax = 930200 },
    { name = "Map 21: Cursed City",        mapId = 50021, raidMapId = 50121, baseId = 930200, validRaidMin = 930201, validRaidMax = 930210 },
    { name = "Map 22: Subway Station",     mapId = 50022, raidMapId = 50122, baseId = 930210, validRaidMin = 930211, validRaidMax = 930220 },
}

-- ====================================================================
-- ข้อมูลหอคอยไต่ระดับ (Ascension Tower Raids: ชั้น 1 - 21 แยกอิสระ 100%)
-- ====================================================================
local ASCENSION_BOSS_NAMES = {
    [1] = "Baran",
    [2] = "Baran+1",
    [3] = "Grendal",
    [4] = "Grendal+1",
    [5] = "Demon Lord",
    [6] = "Demon Lord+1",
    [7] = "Frost Monarch",
    [8] = "Frost Monarch+1",
    [9] = "Beast Monarch",
    [10] = "Beast Monarch+1",
    [11] = "Iron Monarch",
    [12] = "Iron Monarch+1",
    [13] = "Flame Monarch",
    [14] = "Flame Monarch+1",
    [15] = "Plague Monarch",
    [16] = "Plague Monarch+1",
    [17] = "Light Monarch",
    [18] = "Light Monarch+1",
    [19] = "Dominion",
    [20] = "Dominion+1",
    [21] = "Ashborn+1",
}

local ASCENSION_RAID_LIST = {}
for i = 1, 21 do
    local base = (i == 21) and 937200 or (935000 + i * 100)
    local bossName = ASCENSION_BOSS_NAMES[i] or ("Tower " .. i)
    table.insert(ASCENSION_RAID_LIST, {
        name = string.format("Asc %d: %s", i, bossName),
        mapNumber = i,
        mapId = 50000 + i,
        raidMapId = 50302,
        baseId = base,
        validRaidMin = base + 1,
        validRaidMax = base + 10,
        isAscension = true
    })
end

-- โหมด Rejoin / Server Hop เมื่อไม่พบเรดที่ต้องการ
local AUTO_REJOIN_MODES = {
    { name = "Auto Rejoin: OFF (ยืนรอในเซิร์ฟ)", mode = "OFF" },
    { name = "Auto Rejoin: Public Hop (ย้ายเซิร์ฟ)", mode = "HOP" },
}
local autoRejoinIndex = 1
local autoStartOnJoin = false -- รอให้ผู้ใช้กด Start หรือโหลดสถานะเดิม

-- สถานะการทำงาน
local raidTypeIndex = 1       -- 1 = ⚔️ Normal Raid, 2 = 🗼 Ascension Tower
local selectedNormalIndex = 10 -- เริ่มต้นที่ Normal Map 21: Cursed City
local selectedAscIndex = 21   -- เริ่มต้นที่ Asc 21: Ashborn+1
local farmFilterIndex = 1     -- All Mobs
local ATTACK_INTERVAL = 0.20  -- ความเร็วรอบฟันที่เสถียรที่สุด สอดคล้องกับคูลดาวน์เซิร์ฟเวอร์

local FARM_FILTER_MODES = {
    { name = "Target: All Mobs (ทั้งหมด)" },
    { name = "Target: Boss Only (เฉพาะบอส)" },
    { name = "Target: Normal Only (มอนทั่วไป)" }
}

local function getCurrentRaidList()
    if raidTypeIndex == 1 then
        return NORMAL_RAID_LIST
    else
        return ASCENSION_RAID_LIST
    end
end

local function getCurrentSelectedMapIndex()
    if raidTypeIndex == 1 then
        return selectedNormalIndex
    else
        return selectedAscIndex
    end
end

local function setCurrentSelectedMapIndex(idx)
    if raidTypeIndex == 1 then
        selectedNormalIndex = idx
    else
        selectedAscIndex = idx
    end
end

local function getCurrentMapConfig()
    local list = getCurrentRaidList()
    local idx = getCurrentSelectedMapIndex()
    return list[idx] or list[1]
end

-- ====================================================================
-- ระดับความยากเรดปกติ (Normal Raid: D ถึง ULT)
-- ====================================================================
local NORMAL_TIER_DEFINITIONS = {
    { name = "[D]",   offset = 1 },
    { name = "[B]",   offset = 2 },
    { name = "[S]",   offset = 3 },
    { name = "[SS]",  offset = 4 },
    { name = "[G]",   offset = 5 },
    { name = "[N]",   offset = 6 },
    { name = "[M+]",  offset = 7 },
    { name = "[M++]", offset = 8 },
    { name = "[XM]",  offset = 9 },
    { name = "[ULT]", offset = 10 },
}

-- ====================================================================
-- ระดับความยากหอคอยไต่ระดับ (Ascension Tower: E ถึง M)
-- ====================================================================
local ASCENSION_TIER_DEFINITIONS = {
    { name = "[E]",  offset = 1 },
    { name = "[D]",  offset = 2 },
    { name = "[C]",  offset = 3 },
    { name = "[B]",  offset = 4 },
    { name = "[A]",  offset = 5 },
    { name = "[S]",  offset = 6 },
    { name = "[SS]", offset = 7 },
    { name = "[G]",  offset = 8 },
    { name = "[N]",  offset = 9 },
    { name = "[M]",  offset = 10 },
}

local selectedNormalTiers = {
    [1] = true,  -- [D]
    [2] = true,  -- [B]
    [3] = true,  -- [S]
    [4] = true,  -- [SS]
    [5] = true,  -- [G]
    [6] = true,  -- [N]
    [7] = true,  -- [M+]
    [8] = true,  -- [M++]
    [9] = true,  -- [XM]
    [10] = true, -- [ULT]
}

local selectedAscTiers = {
    [1] = true,  -- [E]
    [2] = true,  -- [D]
    [3] = true,  -- [C]
    [4] = true,  -- [B]
    [5] = true,  -- [A]
    [6] = true,  -- [S]
    [7] = true,  -- [SS]
    [8] = true,  -- [G]
    [9] = true,  -- [N]
    [10] = true, -- [M]
}


-- ====================================================================
-- ข้อมูลระบบสุ่ม Quirk & Grade อัตโนมัติ (Hero Quirk, Weapon Quirk, Equip Grade & Locking)
-- ====================================================================
local HERO_QUIRK_SLOTS = {
    { slot = 1, drawId = 920001, itemId = 10030, name = "Slot 1 (Red Core)", short = "Red Core" },
    { slot = 2, drawId = 920002, itemId = 10031, name = "Slot 2 (Yellow Core)", short = "Yellow Core" },
    { slot = 3, drawId = 920003, itemId = 10032, name = "Slot 3 (Blue Core)", short = "Blue Core" },
}

local WEAPON_QUIRK_SLOTS = {
    { slot = 1, drawId = 960001, itemId = 10325, name = "Slot 1 (Stone 1)", short = "Wpn Stone 1" },
    { slot = 2, drawId = 960002, itemId = 10349, name = "Slot 2 (Stone 2)", short = "Wpn Stone 2" },
    { slot = 3, drawId = 960003, itemId = 10350, name = "Slot 3 (Stone 3)", short = "Wpn Stone 3" },
}

local EQUIP_GRADE_SLOTS = {
    { slot = 1, drawId = 980001, itemId = 10340, name = "Slot 1 (Weapon Equip)", short = "G-Stone 1" },
    { slot = 2, drawId = 980002, itemId = 10341, name = "Slot 2 (Armor Equip)", short = "G-Stone 2" },
    { slot = 3, drawId = 980003, itemId = 10342, name = "Slot 3 (Accessory Equip)", short = "G-Stone 3" },
}

local QUIRK_SPEED_MODES = {
    { name = "⚡ Speed: FAST (0.15s)", delay = 0.15 },
    { name = "⏱️ Speed: NORMAL (0.40s)", delay = 0.40 },
    { name = "🚀 Speed: TURBO (0.08s)", delay = 0.08 },
}

local QUIRK_PRESET_MODES = {
    { name = "🎯 Target: 🌟 Mythic Only (Q5+)", minScore = 5 },
    { name = "🎯 Target: ✨ Leg + Mythic (Q4+)", minScore = 4 },
    { name = "🎯 Target: 📝 Custom Locked Quirks", minScore = 0 },
}

local GRADE_PRESET_MODES = {
    { name = "🎯 Target: 👑 Primordial+ (G+)", minScore = 8 },
    { name = "🎯 Target: 🌟 Mythic+ (S+)", minScore = 6 },
    { name = "🎯 Target: ⚡ Transcendent (M)", minScore = 10 },
    { name = "🎯 Target: 📝 Custom Locked Grades", minScore = 0 },
}

local isQuirkRunning = false
local quirkTypeIndex = 1   -- 1 = 👤 Hero Quirk, 2 = ⚔️ Weapon Quirk, 3 = 🛡️ Equip Grade
local quirkSlotIndex = 1   -- 1 = Slot 1, 2 = Slot 2, 3 = Slot 3
local quirkSpeedIndex = 1  -- 1 = Fast (0.15s)
local quirkPresetIndex = 1 -- 1 = Mythic Only / Primordial+
local quirkCustomTargets = {} -- [targetId] = true
local quirkRollCount = 0

local STATIC_QUIRK_POOLS = {
    [920001] = {
        { Id = 99001, QuirksName = "Silver Purse", Score = 1, QuirksDes = "Gold drop +5%" },
        { Id = 99002, QuirksName = "Raw Strength", Score = 1, QuirksDes = "Attack +5%" },
        { Id = 99003, QuirksName = "Tiny Luck", Score = 1, QuirksDes = "Arise Luck +3%" },
        { Id = 99004, QuirksName = "Precise Strike", Score = 2, QuirksDes = "Attack +8%" },
        { Id = 99005, QuirksName = "Combo Rhythm", Score = 2, QuirksDes = "Attack Speed +7%" },
        { Id = 99006, QuirksName = "Lucky Charm", Score = 2, QuirksDes = "Arise Luck +5%" },
        { Id = 99007, QuirksName = "Gold Sense", Score = 3, QuirksDes = "Gold drop +12%" },
        { Id = 99008, QuirksName = "Berserker\'s Rage", Score = 3, QuirksDes = "Attack +12%" },
        { Id = 99009, QuirksName = "Rapid Slash", Score = 3, QuirksDes = "Attack Speed +10%" },
        { Id = 99010, QuirksName = "Godslayer", Score = 4, QuirksDes = "Attack +25%,Gold drop +20%" },
        { Id = 99011, QuirksName = "Phantom Rush", Score = 4, QuirksDes = "SPD +50%,Attack +20%" },
        { Id = 99012, QuirksName = "Legend Hunter", Score = 4, QuirksDes = "Equip Drop +20%,Arise Luck +15%" },
        { Id = 99013, QuirksName = "Midas Touch", Score = 5, QuirksDes = "Gold drop +50%,Equip Drop +20%" },
        { Id = 99014, QuirksName = "Hyper Sprint", Score = 5, QuirksDes = "Attack +50%,Attack Speed +20%" },
        { Id = 99015, QuirksName = "Time Skipper", Score = 5, QuirksDes = "SPD +150%,Attack +40%" },
        { Id = 99016, QuirksName = "Cosmic Luck", Score = 5, QuirksDes = "Gold drop +120%,Equip Drop +40%,Arise Luck +40%" },
        { Id = 99017, QuirksName = "Destiny Rewriter", Score = 5, QuirksDes = "SPD +300%,Attack +60%,Attack Speed +60%" },
        { Id = 99018, QuirksName = "Final Judgment", Score = 5, QuirksDes = "Attack +150%,Attack Speed +40%,SPD +100%" },
        { Id = 99109, QuirksName = "Golden Era", Score = 6, QuirksDes = "Gold drop +300%,Equip Drop +80%,Arise Luck +60%" },
        { Id = 99110, QuirksName = "The Chosen Singularity", Score = 6, QuirksDes = "SPD +450%,Attack +120%,Arise Luck +80%" },
        { Id = 99111, QuirksName = "Axiom of Value", Score = 6, QuirksDes = "Attack +300%,Gold drop +400%,SPD +200%" },
    },
    [920002] = {
        { Id = 99019, QuirksName = "Thrifty Novice", Score = 1, QuirksDes = "Upgrade Cost - 5%" },
        { Id = 99020, QuirksName = "Sharp Instinct", Score = 1, QuirksDes = "Crit Rate +5%" },
        { Id = 99021, QuirksName = "Mana Surge", Score = 1, QuirksDes = "Skill DMG +4%" },
        { Id = 99022, QuirksName = "Meticulous", Score = 2, QuirksDes = "Upgrade Cost - 8%" },
        { Id = 99023, QuirksName = "Keen Eyes", Score = 2, QuirksDes = "Crit Rate +7%" },
        { Id = 99024, QuirksName = "Elemental Affinity", Score = 2, QuirksDes = "Skill DMG +6%" },
        { Id = 99025, QuirksName = "Resource Master", Score = 3, QuirksDes = "Upgrade Cost - 12%" },
        { Id = 99026, QuirksName = "Killer Instinct", Score = 3, QuirksDes = "Crit Rate +10%" },
        { Id = 99027, QuirksName = "Arcane Mastery", Score = 3, QuirksDes = "Skill DMG +8%" },
        { Id = 99028, QuirksName = "Combat Optimization", Score = 4, QuirksDes = "All DMG +8%,Item Drop +5%" },
        { Id = 99029, QuirksName = "Efficient Destruction", Score = 4, QuirksDes = "Upgrade Cost - 20%,Skill DMG +20%" },
        { Id = 99030, QuirksName = "Savage Blow", Score = 4, QuirksDes = "Crit Rate +15%,Crit DMG +15%" },
        { Id = 99031, QuirksName = "Resource Conqueror", Score = 5, QuirksDes = "Item Drop +20%,Upgrade Cost - 30%" },
        { Id = 99032, QuirksName = "Elemental Overload", Score = 5, QuirksDes = "All DMG +10%,Skill DMG +50%" },
        { Id = 99033, QuirksName = "Crimson Executioner", Score = 5, QuirksDes = "Crit Rate +40%,Crit DMG +40%" },
        { Id = 99034, QuirksName = "God\'s Gift", Score = 5, QuirksDes = "All DMG +20%,Upgrade Cost - 50%,Item Drop +50%" },
        { Id = 99035, QuirksName = "Apocalypse Carnival", Score = 5, QuirksDes = "Skill DMG +100%,Crit Rate +50%,Crit DMG +50%" },
        { Id = 99036, QuirksName = "Divine Judgment", Score = 5, QuirksDes = "Crit Rate +60%,Crit DMG +60%,All DMG +15%" },
        { Id = 99112, QuirksName = "Celestial Benediction", Score = 6, QuirksDes = "All DMG +40%,Upgrade Cost - 90%,Item Drop +90%" },
        { Id = 99113, QuirksName = "Eclipse Masquerade", Score = 6, QuirksDes = "Skill DMG +200%,Crit Rate +80%,Crit DMG +80%" },
        { Id = 99114, QuirksName = "Sovereign Verdict", Score = 6, QuirksDes = "Crit Rate +90%,Crit DMG +90%,All DMG +35%" },
    },
    [920003] = {
        { Id = 99037, QuirksName = "Awakening Will", Score = 1, QuirksDes = "All ATK +1%" },
        { Id = 99038, QuirksName = "Omen of Doom", Score = 1, QuirksDes = "Divine Strike Chance +1%" },
        { Id = 99041, QuirksName = "Breath of the End", Score = 2, QuirksDes = "Divine Strike Chance +2%" },
        { Id = 99042, QuirksName = "Sharp Edge", Score = 2, QuirksDes = "All Crit Rate +2%" },
        { Id = 99043, QuirksName = "Boiling Fury", Score = 3, QuirksDes = "All ATK +3%" },
        { Id = 99045, QuirksName = "Breaking Power", Score = 3, QuirksDes = "All Crit Rate +3%" },
        { Id = 99047, QuirksName = "Whisper of Death", Score = 4, QuirksDes = "Divine Strike Chance +5%,Divine Strike DMG +5%" },
        { Id = 99048, QuirksName = "Annihilation Boost", Score = 4, QuirksDes = "All Crit Rate +6%,All Crit DMG +6%" },
        { Id = 99049, QuirksName = "Slayer\'s Instinct", Score = 5, QuirksDes = "All ATK +12%,Divine Strike Chance +6%" },
        { Id = 99050, QuirksName = "Harbinger of Ruin", Score = 5, QuirksDes = "Divine Strike Chance +10%,Divine Strike DMG +10%" },
        { Id = 99052, QuirksName = "Godslayer\'s Fury", Score = 5, QuirksDes = "All ATK +25%,Divine Strike Chance +8%,All Crit Rate +8%" },
        { Id = 99053, QuirksName = "Deicide\'s Endgame", Score = 5, QuirksDes = "Divine Strike Chance +20%,Divine Strike DMG +20%,All Crit Rate +10%" },
        { Id = 99054, QuirksName = "Final Arbiter", Score = 5, QuirksDes = "All Crit Rate +22%,All Crit DMG +22%,Divine Strike Chance +6%" },
        { Id = 99115, QuirksName = "Cosmic Cataclysm", Score = 6, QuirksDes = "All ATK +70%,Divine Strike Chance +12%,All Crit Rate +12%" },
        { Id = 99116, QuirksName = "Omega Oblivion", Score = 6, QuirksDes = "Divine Strike Chance +30%,Divine Strike DMG +40%,All Crit Rate +14%" },
        { Id = 99117, QuirksName = "Sovereign Axiom", Score = 6, QuirksDes = "All Crit Rate +30%,All Crit DMG +30%,Divine Strike Chance +10%" },
    },
    [960001] = {
        { Id = 99055, QuirksName = "Improved Drop Rate", Score = 1, QuirksDes = "Equip Drop +3%" },
        { Id = 99056, QuirksName = "Party ATK", Score = 1, QuirksDes = "All ATK +1%" },
        { Id = 99057, QuirksName = "Divine Proc Chance", Score = 1, QuirksDes = "Divine Strike Chance +1%" },
        { Id = 99058, QuirksName = "Team Crit Rate", Score = 2, QuirksDes = "All Crit Rate +2%" },
        { Id = 99059, QuirksName = "Group Skill DMG", Score = 2, QuirksDes = "All Skill DMG +3%" },
        { Id = 99060, QuirksName = "Serendipity", Score = 2, QuirksDes = "Arise Luck +6%" },
        { Id = 99061, QuirksName = "Master Looter", Score = 3, QuirksDes = "Equip Drop +7%" },
        { Id = 99062, QuirksName = "Gold Gain", Score = 3, QuirksDes = "Gold drop +15%" },
        { Id = 99063, QuirksName = "Divine Intervention", Score = 3, QuirksDes = "Divine Strike Chance +3%" },
        { Id = 99064, QuirksName = "Item Drop Rate", Score = 4, QuirksDes = "Item Drop +8%,Arise Luck +12%" },
        { Id = 99065, QuirksName = "Critical Resonance", Score = 4, QuirksDes = "All Crit Rate +5%,All Crit DMG +5%" },
        { Id = 99066, QuirksName = "Prosperous Hunter", Score = 4, QuirksDes = "Equip Drop +15%,Gold drop +20%" },
        { Id = 99067, QuirksName = "Celestial Onslaught", Score = 5, QuirksDes = "Divine Strike Chance +10%,Divine Strike DMG +10%" },
        { Id = 99068, QuirksName = "Lucky Scavenger", Score = 5, QuirksDes = "Gold drop +50%,Arise Luck +25%" },
        { Id = 99069, QuirksName = "Titan\'s Wrath", Score = 5, QuirksDes = "All ATK +10%,All Skill DMG +10%" },
        { Id = 99070, QuirksName = "Omnipotent Benefactor", Score = 5, QuirksDes = "Gold drop +120%,Equip Drop +40%,Item Drop +50%" },
        { Id = 99071, QuirksName = "Archangel\'s Judgment", Score = 5, QuirksDes = "All Skill DMG +25%,Divine Strike Chance +20%,Divine Strike DMG +20%" },
        { Id = 99072, QuirksName = "Avatar of Destruction", Score = 5, QuirksDes = "All ATK +15%,All Skill DMG +15%,All Crit Rate +15%" },
        { Id = 99118, QuirksName = "Eternal Sovereign", Score = 6, QuirksDes = "Gold drop +240%,Equip Drop +80%,Item Drop +80%" },
        { Id = 99119, QuirksName = "Seraphic Verdict", Score = 6, QuirksDes = "All Skill DMG +50%,Divine Strike Chance +40%,Divine Strike DMG +40%" },
        { Id = 99120, QuirksName = "Doombringer Ascendant", Score = 6, QuirksDes = "All ATK +30%,All Skill DMG +30%,All Crit Rate +30%" },
    },
    [960002] = {
        { Id = 99073, QuirksName = "Improved Drop Rate", Score = 1, QuirksDes = "Equip Drop +3%" },
        { Id = 99074, QuirksName = "Party ATK", Score = 1, QuirksDes = "All ATK +1%" },
        { Id = 99075, QuirksName = "Divine Proc Chance", Score = 1, QuirksDes = "Divine Strike Chance +1%" },
        { Id = 99076, QuirksName = "Team Crit Rate", Score = 2, QuirksDes = "All Crit Rate +2%" },
        { Id = 99077, QuirksName = "Group Skill DMG", Score = 2, QuirksDes = "All Skill DMG +3%" },
        { Id = 99078, QuirksName = "Serendipity", Score = 2, QuirksDes = "Arise Luck +6%" },
        { Id = 99079, QuirksName = "Master Looter", Score = 3, QuirksDes = "Equip Drop +7%" },
        { Id = 99080, QuirksName = "Gold Gain", Score = 3, QuirksDes = "Gold drop +15%" },
        { Id = 99081, QuirksName = "Divine Intervention", Score = 3, QuirksDes = "Divine Strike Chance +3%" },
        { Id = 99082, QuirksName = "Item Drop Rate", Score = 4, QuirksDes = "Item Drop +8%,Arise Luck +12%" },
        { Id = 99083, QuirksName = "Critical Resonance", Score = 4, QuirksDes = "All Crit Rate +5%,All Crit DMG +5%" },
        { Id = 99084, QuirksName = "Prosperous Hunter", Score = 4, QuirksDes = "Equip Drop +15%,Gold drop +20%" },
        { Id = 99085, QuirksName = "Celestial Onslaught", Score = 5, QuirksDes = "Divine Strike Chance +10%,Divine Strike DMG +10%" },
        { Id = 99086, QuirksName = "Lucky Scavenger", Score = 5, QuirksDes = "Gold drop +50%,Arise Luck +25%" },
        { Id = 99087, QuirksName = "Titan\'s Wrath", Score = 5, QuirksDes = "All ATK +10%,All Skill DMG +10%" },
        { Id = 99088, QuirksName = "Omnipotent Benefactor", Score = 5, QuirksDes = "Gold drop +120%,Equip Drop +40%,Item Drop +50%" },
        { Id = 99089, QuirksName = "Archangel\'s Judgment", Score = 5, QuirksDes = "All Skill DMG +25%,Divine Strike Chance +20%,Divine Strike DMG +20%" },
        { Id = 99090, QuirksName = "Avatar of Destruction", Score = 5, QuirksDes = "All ATK +15%,All Skill DMG +15%,All Crit Rate +15%" },
        { Id = 99121, QuirksName = "Eternal Sovereign", Score = 6, QuirksDes = "Gold drop +240%,Equip Drop +80%,Item Drop +80%" },
        { Id = 99122, QuirksName = "Seraphic Verdict", Score = 6, QuirksDes = "All Skill DMG +50%,Divine Strike Chance +40%,Divine Strike DMG +40%" },
        { Id = 99123, QuirksName = "Doombringer Ascendant", Score = 6, QuirksDes = "All ATK +30%,All Skill DMG +30%,All Crit Rate +30%" },
    },
    [960003] = {
        { Id = 99091, QuirksName = "Improved Drop Rate", Score = 1, QuirksDes = "Equip Drop +3%" },
        { Id = 99092, QuirksName = "Party ATK", Score = 1, QuirksDes = "All ATK +1%" },
        { Id = 99093, QuirksName = "Divine Proc Chance", Score = 1, QuirksDes = "Divine Strike Chance +1%" },
        { Id = 99094, QuirksName = "Team Crit Rate", Score = 2, QuirksDes = "All Crit Rate +2%" },
        { Id = 99095, QuirksName = "Group Skill DMG", Score = 2, QuirksDes = "All Skill DMG +3%" },
        { Id = 99096, QuirksName = "Serendipity", Score = 2, QuirksDes = "Arise Luck +6%" },
        { Id = 99097, QuirksName = "Master Looter", Score = 3, QuirksDes = "Equip Drop +7%" },
        { Id = 99098, QuirksName = "Gold Gain", Score = 3, QuirksDes = "Gold drop +15%" },
        { Id = 99099, QuirksName = "Divine Intervention", Score = 3, QuirksDes = "Divine Strike Chance +3%" },
        { Id = 99100, QuirksName = "Item Drop Rate", Score = 4, QuirksDes = "Item Drop +8%,Arise Luck +12%" },
        { Id = 99101, QuirksName = "Critical Resonance", Score = 4, QuirksDes = "All Crit Rate +5%,All Crit DMG +5%" },
        { Id = 99102, QuirksName = "Prosperous Hunter", Score = 4, QuirksDes = "Equip Drop +15%,Gold drop +20%" },
        { Id = 99103, QuirksName = "Celestial Onslaught", Score = 5, QuirksDes = "Divine Strike Chance +10%,Divine Strike DMG +10%" },
        { Id = 99104, QuirksName = "Lucky Scavenger", Score = 5, QuirksDes = "Gold drop +50%,Arise Luck +25%" },
        { Id = 99105, QuirksName = "Titan\'s Wrath", Score = 5, QuirksDes = "All ATK +10%,All Skill DMG +10%" },
        { Id = 99106, QuirksName = "Omnipotent Benefactor", Score = 5, QuirksDes = "Gold drop +120%,Equip Drop +40%,Item Drop +50%" },
        { Id = 99107, QuirksName = "Archangel\'s Judgment", Score = 5, QuirksDes = "All Skill DMG +25%,Divine Strike Chance +20%,Divine Strike DMG +20%" },
        { Id = 99108, QuirksName = "Avatar of Destruction", Score = 5, QuirksDes = "All ATK +15%,All Skill DMG +15%,All Crit Rate +15%" },
        { Id = 99124, QuirksName = "Eternal Sovereign", Score = 6, QuirksDes = "Gold drop +240%,Equip Drop +80%,Item Drop +80%" },
        { Id = 99125, QuirksName = "Seraphic Verdict", Score = 6, QuirksDes = "All Skill DMG +50%,Divine Strike Chance +40%,Divine Strike DMG +40%" },
        { Id = 99126, QuirksName = "Doombringer Ascendant", Score = 6, QuirksDes = "All ATK +30%,All Skill DMG +30%,All Crit Rate +30%" },
    },
}


local STATIC_EQUIP_GRADE_POOLS = {
    [980001] = {
        { Id = 990001, Name = "E", Desc = "Initial", Score = 1, Scale = 100 },
        { Id = 990002, Name = "D", Desc = "Uncommon", Score = 2, Scale = 115 },
        { Id = 990003, Name = "C", Desc = "Rare", Score = 3, Scale = 130 },
        { Id = 990004, Name = "B", Desc = "Epic", Score = 4, Scale = 150 },
        { Id = 990005, Name = "A", Desc = "Legendary", Score = 5, Scale = 200 },
        { Id = 990006, Name = "S", Desc = "Mythic", Score = 6, Scale = 300 },
        { Id = 990007, Name = "SS", Desc = "Celestial", Score = 7, Scale = 600 },
        { Id = 990008, Name = "G", Desc = "Primordial", Score = 8, Scale = 1100 },
        { Id = 990009, Name = "N", Desc = "Ethereal", Score = 9, Scale = 2100 },
        { Id = 990010, Name = "M", Desc = "Transcendent", Score = 10, Scale = 5100 },
    },
    [980002] = {
        { Id = 990011, Name = "E", Desc = "Initial", Score = 1, Scale = 100 },
        { Id = 990012, Name = "D", Desc = "Uncommon", Score = 2, Scale = 115 },
        { Id = 990013, Name = "C", Desc = "Rare", Score = 3, Scale = 130 },
        { Id = 990014, Name = "B", Desc = "Epic", Score = 4, Scale = 150 },
        { Id = 990015, Name = "A", Desc = "Legendary", Score = 5, Scale = 200 },
        { Id = 990016, Name = "S", Desc = "Mythic", Score = 6, Scale = 300 },
        { Id = 990017, Name = "SS", Desc = "Celestial", Score = 7, Scale = 600 },
        { Id = 990018, Name = "G", Desc = "Primordial", Score = 8, Scale = 1100 },
        { Id = 990019, Name = "N", Desc = "Ethereal", Score = 9, Scale = 2100 },
        { Id = 990020, Name = "M", Desc = "Transcendent", Score = 10, Scale = 5100 },
    },
    [980003] = {
        { Id = 990021, Name = "E", Desc = "Initial", Score = 1, Scale = 100 },
        { Id = 990022, Name = "D", Desc = "Uncommon", Score = 2, Scale = 115 },
        { Id = 990023, Name = "C", Desc = "Rare", Score = 3, Scale = 130 },
        { Id = 990024, Name = "B", Desc = "Epic", Score = 4, Scale = 150 },
        { Id = 990025, Name = "A", Desc = "Legendary", Score = 5, Scale = 200 },
        { Id = 990026, Name = "S", Desc = "Mythic", Score = 6, Scale = 300 },
        { Id = 990027, Name = "SS", Desc = "Celestial", Score = 7, Scale = 600 },
        { Id = 990028, Name = "G", Desc = "Primordial", Score = 8, Scale = 1100 },
        { Id = 990029, Name = "N", Desc = "Ethereal", Score = 9, Scale = 2100 },
        { Id = 990030, Name = "M", Desc = "Transcendent", Score = 10, Scale = 5100 },
    },
}

local function getQuirksForDraw(drawId)
    local list = {}
    if drawId >= 980001 and drawId <= 980003 then
        -- Equip Grade Pool
        pcall(function()
            if ConfigManager and ConfigManager.GetConfig then
                local gCfg = ConfigManager.GetConfig("HeroEquipGrade")
                if gCfg and gCfg.GetDatasByField then
                    local datas = gCfg:GetDatasByField("DrawId", drawId)
                    if datas and #datas > 0 then
                        list = datas
                    end
                end
            end
        end)
        if #list == 0 and STATIC_EQUIP_GRADE_POOLS[drawId] then
            list = STATIC_EQUIP_GRADE_POOLS[drawId]
        end
        for _, g in ipairs(list) do
            if not g.QuirksName then g.QuirksName = "Grade " .. (g.Name or "") end
            if not g.QuirksDes then g.QuirksDes = (g.Desc or "") .. string.format(" (x%d%%)", g.Scale or 100) end
            if not g.Score then g.Score = g.Order or 1 end
            g.Quality = g.Score
        end
        return list
    end

    pcall(function()
        if ConfigManager and ConfigManager.GetConfig then
            local qCfg = ConfigManager.GetConfig("QuirksNew")
            if qCfg and qCfg.GetDatasByField then
                local datas = qCfg:GetDatasByField("DrawId", drawId)
                if datas and #datas > 0 then
                    list = datas
                end
            end
        end
    end)
    if #list == 0 and STATIC_QUIRK_POOLS[drawId] then
        list = STATIC_QUIRK_POOLS[drawId]
    end
    return list
end

local function isTargetQuirk(qId, qCfg)
    if not qId then return false end
    local score = 1
    if qCfg then
        score = qCfg.Score or qCfg.Order or qCfg.Quality or 1
    end
    if quirkTypeIndex == 3 then
        -- โหมดสุ่ม Grade อุปกรณ์ (Score 1..10: E=1, D=2, C=3, B=4, A=5, S=6, SS=7, G=8, N=9, M=10)
        if quirkPresetIndex == 1 then
            return score >= 8 -- G, N, M (Primordial ขึ้นไป)
        elseif quirkPresetIndex == 2 then
            return score >= 6 -- S, SS, G, N, M (Mythic ขึ้นไป)
        elseif quirkPresetIndex == 3 then
            return score >= 10 -- M Only (Transcendent ระดับสูงสุด)
        elseif quirkPresetIndex == 4 then
            return quirkCustomTargets[qId] == true
        end
        return score >= 8
    else
        -- โหมดสุ่ม Quirk ตัวละคร & อาวุธ (Score 1..6)
        if quirkPresetIndex == 1 then
            return score >= 5
        elseif quirkPresetIndex == 2 then
            return score >= 4
        elseif quirkPresetIndex == 3 then
            return quirkCustomTargets[qId] == true
        end
        return score >= 5
    end
end

local function getCurrentQuirkEntity()
    ensureManagers()
    local entityGuid = nil
    local entityName = "None"
    local currentQuirkId = nil
    local currentQuirkName = "None"

    if quirkTypeIndex == 1 then
        -- Hero Quirk
        -- 1. ตรวจสอบจาก QuirkNewPanel ที่เปิดอยู่บนจอเกมก่อนเป็นอันดับแรก
        pcall(function()
            if UIManager and UIManager.panelDict then
                local qp = UIManager.panelDict["QuirkNewPanel"]
                if qp and qp.selectHeroGuid and PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.heros and PlayerManager.localPlayerData.heros[qp.selectHeroGuid] then
                    entityGuid = qp.selectHeroGuid
                end
            end
        end)

        -- 2. ถ้าไม่ได้เปิด ให้ค้นหาตัวที่ Equip อยู่
        if not entityGuid and PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.heros then
            for guid, h in pairs(PlayerManager.localPlayerData.heros) do
                if h.isEquip == true or h.isFight == true or h.isMain == true then
                    entityGuid = guid
                    break
                end
            end
            -- 3. ถ้าไม่มีตัว Equip ให้หยิบตัวแรกในกระเป๋า
            if not entityGuid then
                for guid, _ in pairs(PlayerManager.localPlayerData.heros) do
                    entityGuid = guid
                    break
                end
            end
        end

        if entityGuid and PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.heros then
            local h = PlayerManager.localPlayerData.heros[entityGuid]
            if h then
                local hId = h.id or h.heroId or h.ConfigId
                local cfg = nil
                pcall(function()
                    if ConfigManager and ConfigManager.GetConfig then
                        cfg = ConfigManager.GetConfig("HeroConfig"):GetDataById(hId)
                    end
                end)
                entityName = (cfg and cfg.RoleName) or (h.name or ("Hero " .. tostring(hId)))
                if h.quirks and h.quirks[quirkSlotIndex] then
                    currentQuirkId = h.quirks[quirkSlotIndex]
                end
            end
        end
    elseif quirkTypeIndex == 2 then
        -- Weapon Quirk
        pcall(function()
            if UIManager and UIManager.panelDict then
                local wp = UIManager.panelDict["QuirkWeaponPanel"]
                if wp and wp.selectWeaponGuid and PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.weapons and PlayerManager.localPlayerData.weapons[wp.selectWeaponGuid] then
                    entityGuid = wp.selectWeaponGuid
                end
            end
        end)

        if not entityGuid and PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.weapons then
            for guid, w in pairs(PlayerManager.localPlayerData.weapons) do
                if w.isEquip == true then
                    entityGuid = guid
                    break
                end
            end
            if not entityGuid then
                for guid, _ in pairs(PlayerManager.localPlayerData.weapons) do
                    entityGuid = guid
                    break
                end
            end
        end

        if entityGuid and PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.weapons then
            local w = PlayerManager.localPlayerData.weapons[entityGuid]
            if w then
                local wId = w.id or w.weaponId or w.ConfigId
                local cfg = nil
                pcall(function()
                    if ConfigManager and ConfigManager.GetConfig then
                        cfg = ConfigManager.GetConfig("Weapon"):GetDataById(wId)
                    end
                end)
                entityName = (cfg and cfg.Name) or (w.name or ("Weapon " .. tostring(wId)))
                if w.quirks and w.quirks[quirkSlotIndex] then
                    currentQuirkId = w.quirks[quirkSlotIndex]
                end
            end
        end
    elseif quirkTypeIndex == 3 then
        -- Equip Grade
        pcall(function()
            if UIManager and UIManager.panelDict then
                local hp = UIManager.panelDict["HeroEquipGradePanel"]
                if hp and hp.selectHeroEquipGuid and PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.heroEquips and PlayerManager.localPlayerData.heroEquips[hp.selectHeroEquipGuid] then
                    entityGuid = hp.selectHeroEquipGuid
                end
            end
        end)

        if not entityGuid and PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.heroEquips then
            for guid, eq in pairs(PlayerManager.localPlayerData.heroEquips) do
                if eq.isEquip == true and (eq.type == quirkSlotIndex or eq.HeroEquipType == quirkSlotIndex) then
                    entityGuid = guid
                    break
                end
            end
            if not entityGuid then
                for guid, eq in pairs(PlayerManager.localPlayerData.heroEquips) do
                    if eq.type == quirkSlotIndex or eq.HeroEquipType == quirkSlotIndex then
                        entityGuid = guid
                        break
                    end
                end
            end
            if not entityGuid then
                for guid, _ in pairs(PlayerManager.localPlayerData.heroEquips) do
                    entityGuid = guid
                    break
                end
            end
        end

        if entityGuid and PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.heroEquips then
            local eq = PlayerManager.localPlayerData.heroEquips[entityGuid]
            if eq then
                local typeNames = { [1] = "Weapon Equip", [2] = "Armor Equip", [3] = "Acc Equip" }
                local tName = typeNames[eq.type or quirkSlotIndex] or ("Equip " .. tostring(eq.type or quirkSlotIndex))
                entityName = tName
                currentQuirkId = eq.grade
            end
        end
    end

    if currentQuirkId and currentQuirkId ~= 0 then
        if quirkTypeIndex == 3 then
            pcall(function()
                if ConfigManager and ConfigManager.GetConfig then
                    local gCfg = ConfigManager.GetConfig("HeroEquipGrade"):GetDataById(currentQuirkId)
                    if gCfg then
                        currentQuirkName = "Grade " .. (gCfg.Name or "") .. " (" .. (gCfg.Desc or "") .. ")"
                    end
                end
            end)
            if currentQuirkName == "None" and STATIC_EQUIP_GRADE_POOLS then
                local slots = EQUIP_GRADE_SLOTS
                local drawId = slots[quirkSlotIndex].drawId
                if STATIC_EQUIP_GRADE_POOLS[drawId] then
                    for _, sg in ipairs(STATIC_EQUIP_GRADE_POOLS[drawId]) do
                        if sg.Id == currentQuirkId then
                            currentQuirkName = "Grade " .. sg.Name .. " (" .. sg.Desc .. ")"
                            break
                        end
                    end
                end
            end
        else
            pcall(function()
                if ConfigManager and ConfigManager.GetConfig then
                    local qCfg = ConfigManager.GetConfig("QuirksNew"):GetDataById(currentQuirkId)
                    if qCfg then
                        currentQuirkName = qCfg.QuirksName or ("Quirk " .. tostring(currentQuirkId))
                    end
                end
            end)
            if currentQuirkName == "None" then
                local slots = (quirkTypeIndex == 1) and HERO_QUIRK_SLOTS or WEAPON_QUIRK_SLOTS
                local drawId = slots[quirkSlotIndex].drawId
                if STATIC_QUIRK_POOLS[drawId] then
                    for _, sq in ipairs(STATIC_QUIRK_POOLS[drawId]) do
                        if sq.Id == currentQuirkId then
                            currentQuirkName = sq.QuirksName
                            break
                        end
                    end
                end
            end
        end
    end

    return entityGuid, entityName, currentQuirkId, currentQuirkName
end

local function getQuirkCoreCount()
    ensureManagers()
    local slots = (quirkTypeIndex == 1 and HERO_QUIRK_SLOTS) or (quirkTypeIndex == 2 and WEAPON_QUIRK_SLOTS) or EQUIP_GRADE_SLOTS
    local slotData = slots[quirkSlotIndex] or slots[1]
    local itemId = slotData.itemId
    local count = 0

    pcall(function()
        if PlayerEntityHelper and PlayerEntityHelper.GetItemCount and PlayerManager and PlayerManager.localPlayerData then
            count = PlayerEntityHelper.GetItemCount(PlayerManager.localPlayerData, itemId)
        end
    end)

    if count <= 0 then
        pcall(function()
            if PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.items then
                for _, it in pairs(PlayerManager.localPlayerData.items) do
                    if it.itemId == itemId or it.id == itemId then
                        count = it.count or 0
                        break
                    end
                end
            end
        end)
    end

    -- Fallback: อ่านจาก UI ของตัวเกมโดยตรง (เช่น "1.5M")
    if count <= 0 then
        pcall(function()
            if UIManager and UIManager.panelDict then
                local panelName = (quirkTypeIndex == 3 and "HeroEquipGradePanel") or (quirkTypeIndex == 2 and "QuirkWeaponPanel") or "QuirkNewPanel"
                local panel = UIManager.panelDict[panelName]
                if panel and panel.itemFrame and panel.itemFrame.GoldText and panel.itemFrame.GoldText.Text ~= "" then
                    local txt = panel.itemFrame.GoldText.Text
                    if txt:find("M") then
                        local n = tonumber(txt:gsub("M", "")) or 1
                        count = math.floor(n * 1000000)
                    elseif txt:find("K") then
                        local n = tonumber(txt:gsub("K", "")) or 1
                        count = math.floor(n * 1000)
                    else
                        count = tonumber(txt) or 0
                    end
                end
            end
        end)
    end

    return count, slotData
end

local function getCurrentTierDefinitions()
    return (raidTypeIndex == 1) and NORMAL_TIER_DEFINITIONS or ASCENSION_TIER_DEFINITIONS
end

local function getCurrentSelectedTiers()
    return (raidTypeIndex == 1) and selectedNormalTiers or selectedAscTiers
end

local function getSelectedTiersText()
    local curMap = getCurrentMapConfig()
    if curMap and curMap.isEvent then
        return "Tier: Event Only"
    end

    local defs = getCurrentTierDefinitions()
    local tiers = getCurrentSelectedTiers()

    local names = {}
    local count = 0
    for i = 1, 10 do
        if tiers[i] and defs[i] then
            count = count + 1
            table.insert(names, defs[i].name)
        end
    end

    if count == 10 then
        return (raidTypeIndex == 1) and "Tier: All [D-ULT]" or "Tier: All [E-M]"
    elseif count == 0 then
        return "Tier: None (คลิกเพื่อเลือก)"
    elseif count <= 3 then
        return "Tier: " .. table.concat(names, ", ")
    else
        return string.format("Tier: %s, %s + %d more", names[1], names[2], count - 2)
    end
end

local isRaidRunning = false
local isFarmRunning = false
local antiAfkEnabled = true
local combatGroundMode = true -- ยืนบนพื้น (ไม่ลอยฟ้า) ตามที่ต้องการ
local bossPriorityEnabled = true
local hideDropsEnabled = false -- false = แสดงผลปกติ, true = ซ่อนของดรอปและป๊อปอัปบนหน้าจอ
local lastMainMapId = 50001 -- แมพหลักล่าสุดที่ผู้เล่นยืนอยู่จริง (ปลอดภัยเสมอ 100%)
local safePlatform = nil

local raidWinCount = 0
local mobKillCount = 0

local function getRootPart()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ====================================================================
-- Anti-AFK
-- ====================================================================
pcall(function()
    LocalPlayer.Idled:Connect(function()
        if antiAfkEnabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end)

-- ====================================================================
-- ====================================================================
-- ระบบ Noclip ขณะเปิดฟาร์มหรือลงเรด (แก้บัคตัวละครชนมอนสเตอร์แล้วกระตุก/ค้าง)
-- [แก้ไข] ปิด CanCollide ที่ตัวมอนสเตอร์ เพื่อไม่ให้ดันตัวผู้เล่น และไม่ทำให้ผู้เล่นตกแมพ/ตก Void
-- ====================================================================
local findTargetRaidEnemy
local findChestInRaid

RunService.Stepped:Connect(function()
    if isFarmRunning or isRaidRunning then
        local enemysFolder = Workspace:FindFirstChild("Enemys")
        if enemysFolder then
            for _, enemy in pairs(enemysFolder:GetChildren()) do
                for _, part in pairs(enemy:GetChildren()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end

        -- ป้องกันตกเหว / Void ในหอคอย Ascension (50302) เฉพาะขณะกำลังต่อสู้หรือเก็บของ
        local hrp = getRootPart()
        if hrp and isRaidRunning then
            local curMap = MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo and MapManager.currentMapData.mapSlotInfo.mapId
            if curMap == 50302 and (safePlatform ~= nil or findTargetRaidEnemy() ~= nil or findChestInRaid() ~= nil) then
                if hrp.AssemblyLinearVelocity.Y < -35 then
                    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
                end
            end
        end
    end
end)

-- ====================================================================
-- แท่นลอยตัวปลอดภัย (Safe Platform รองรับทั้ง Air Combat และหอคอย Ascension)
-- ====================================================================
local function updateSafePlatform(targetPosition)
    if not safePlatform or not safePlatform.Parent then
        safePlatform = Instance.new("Part")
        safePlatform.Name = "SafeRaidPlatform"
        safePlatform.Size = Vector3.new(25, 1, 25)
        safePlatform.Transparency = 1
        safePlatform.Anchored = true
        safePlatform.CanCollide = true
        safePlatform.Parent = Workspace
    end
    safePlatform.CFrame = CFrame.new(targetPosition - Vector3.new(0, 3.2, 0))
end

local function removeSafePlatform()
    if safePlatform then
        safePlatform:Destroy()
        safePlatform = nil
    end
end

-- ====================================================================
-- ฟังก์ชันจัดตำแหน่งตัวละคร (Ground vs Air - ไหลลื่น ไม่กระตุก ไม่หมุนสะบัด)
-- ====================================================================
local function positionAtTarget(targetModel, hrp, isNewTarget)
    if not targetModel or not hrp then return end
    local primary = targetModel.PrimaryPart or targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChildWhichIsA("BasePart")
    if not primary then return end
    if not targetModel.PrimaryPart then
        targetModel.PrimaryPart = primary
    end

    local targetPos = primary.Position
    local dist = (hrp.Position - targetPos).Magnitude

    local curMap = MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo and MapManager.currentMapData.mapSlotInfo.mapId
    local isAsc = (curMap == 50302) or (raidTypeIndex == 2)

    if combatGroundMode then
        -- ในหอคอย Ascension หรือเรดกลางอากาศ ให้มีแท่นกว้างรองรับใต้เท้าเสมอ ป้องกันตกแมพ 100%
        if isAsc then
            updateSafePlatform(hrp.Position)
        else
            removeSafePlatform()
        end

        -- วาปเฉพาะเมื่อเป็นเป้าหมายใหม่ หรือตัวละครหลุดระยะเกิน 7 studs
        if isNewTarget or dist > 7 then
            local offsetVec = Vector3.new(0, 0, 3.5)
            if primary then
                offsetVec = -primary.CFrame.LookVector * 3.5
            end
            local standPos = targetPos + offsetVec
            if isAsc then
                updateSafePlatform(standPos)
            end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            local newCF = CFrame.lookAt(standPos, Vector3.new(targetPos.X, standPos.Y, targetPos.Z))
            hrp.CFrame = newCF
            pcall(function()
                if LocalPlayer.Character then
                    LocalPlayer.Character:PivotTo(newCF)
                end
            end)
        else
            -- อยู่ระยะประชิดแล้ว: ล็อคความเร็วเป็น 0 และหันหน้าเข้าหาเป้าหมายอย่างนิ่ง ไม่สั่นกระตุก
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))
        end
    else
        -- โหมดลอยฟ้า (Air Combat): ลอยตัวเหนือเป้าหมาย 4.5 studs
        local hoverPos = targetPos + Vector3.new(0, 4.5, 0)
        updateSafePlatform(hoverPos)
        if isNewTarget or dist > 8 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            local newCF = CFrame.lookAt(hoverPos, targetPos)
            hrp.CFrame = newCF
            pcall(function()
                if LocalPlayer.Character then
                    LocalPlayer.Character:PivotTo(newCF)
                end
            end)
        end
    end
end

-- ====================================================================
-- ฟังก์ชันตรวจสอบว่าเป็นเรดอีเว้นแมพ 1 หรือไม่ (Event Raid Map 1 Detector)
-- ====================================================================
local function isEventRaidMap1()
    -- 1. เช็คจาก RaidsManager เมื่ออยู่ในดันเจี้ยนเรดอีเว้นแมพ 1 (Vampire Event: MapId 50001, RaidMapId 50403)
    if RaidsManager and RaidsManager.raidsMapInfo then
        local rMapId = RaidsManager.raidsMapInfo.mapId
        if rMapId == 50403 or rMapId == 50001 then
            return true
        end
    end

    -- 2. เช็คจาก MapManager
    if MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo then
        local mMapId = MapManager.currentMapData.mapSlotInfo.mapId
        if mMapId == 50403 or mMapId == 50001 then
            return true
        end
    end

    -- 3. เช็คจากตัวเลือกของ Hub (เมื่อตั้งค่าไว้ที่ Normal Raid แมพ 1: Vampire Event)
    if isRaidRunning and raidTypeIndex == 1 and selectedNormalIndex == 1 then
        return true
    end

    return false
end

-- ====================================================================
-- ระบบซ่อนของดรอปและป๊อปอัปบนหน้าจอ (Hide Drops & Screen Popups)
-- ====================================================================
local function setItemVisualHidden(inst, hidden)
    if not inst then return end
    pcall(function()
        if inst:IsA("BasePart") then
            inst.Transparency = hidden and 1 or 0
        end
        for _, desc in ipairs(inst:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.Transparency = hidden and 1 or 0
            elseif desc:IsA("Decal") or desc:IsA("Texture") then
                desc.Transparency = hidden and 1 or 0
            elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") or desc:IsA("ScreenGui") then
                desc.Enabled = not hidden
            elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Highlight") then
                desc.Enabled = not hidden
            end
        end
    end)
end

-- ====================================================================
-- ฟังก์ชันช่วยจำลองการคลิกปุ่มบนหน้าจอ GUI (ทั้ง firesignal และ getconnections)
-- ====================================================================
local function clickGuiButton(btn)
    if not btn then return end
    pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
        end
    end)
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
                pcall(function() c:Fire() end)
            end
            for _, c in ipairs(getconnections(btn.Activated)) do
                pcall(function() c:Fire() end)
            end
        end
    end)
end

-- ====================================================================
-- ฟังก์ชันปิดหน้าต่างของรางวัลทุกประเภทบนหน้าจอ (Reward & Tips Popups)
-- ปิดทั้ง TipsPanel.RewardsFrame, TipsFloatingPanel.RewardsFrame, RewardPanel ฯลฯ
-- ====================================================================
local function dismissAllRewardPopups()
    if not hideDropsEnabled then return end
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end

        -- 1. ปิดผ่าน UIManager (ทางการของเกม) และปิด BlurEffect
        if UIManager then
            pcall(function()
                if UIManager.HidePanel then
                    UIManager.HidePanel("TipsPanel")
                    UIManager.HidePanel("TipsFloatingPanel")
                    UIManager.HidePanel("RewardPanel")
                end
                if UIManager.blurEffect and UIManager.blurEffect.Enabled then
                    UIManager.blurEffect.Enabled = false
                end
            end)
            if UIManager.panelDict then
                for _, pName in ipairs({ "TipsPanel", "TipsFloatingPanel", "RewardPanel" }) do
                    local pInst = UIManager.panelDict[pName]
                    if pInst then
                        if pInst.rewardsFrame then
                            pInst.rewardsFrame.Visible = false
                        end
                        if pInst.panelInstance then
                            pInst.panelInstance.Enabled = false
                        end
                        if pInst.OnRewardConfirmBtnClick then
                            pcall(function() pInst:OnRewardConfirmBtnClick() end)
                        end
                        if pInst.HideSelf then
                            pcall(function() pInst:HideSelf() end)
                        end
                    end
                end
            end
        end

        -- 2. เคลียร์ RewardsFrame ใน TipsPanel, TipsFloatingPanel, RewardPanel บน PlayerGui จริง
        for _, pName in ipairs({ "TipsPanel", "TipsFloatingPanel", "RewardPanel", "GroupRewardPanel", "OnlineRewardPanel", "ReferralRewardPanel", "VipRewardPanel" }) do
            local panelGui = pg:FindFirstChild(pName)
            if panelGui then
                local rf = panelGui:FindFirstChild("RewardsFrame", true)
                if rf and rf:IsA("GuiObject") and rf.Visible then
                    rf.Visible = false
                    local confirmBtn = rf:FindFirstChild("ConfirmButton", true) or rf:FindFirstChild("CloseButton", true) or rf:FindFirstChildWhichIsA("GuiButton", true)
                    if confirmBtn then clickGuiButton(confirmBtn) end
                end
                local bf = panelGui:FindFirstChild("ButtonFrame", true)
                if bf then
                    local cb = bf:FindFirstChild("ConfirmButton", true) or bf:FindFirstChildWhichIsA("GuiButton", true)
                    if cb then clickGuiButton(cb) end
                end
                if panelGui:IsA("ScreenGui") then
                    panelGui.Enabled = false
                end
                local f = panelGui:FindFirstChild("Frame") or panelGui:FindFirstChildWhichIsA("Frame")
                if f then f.Visible = false end
            end
        end

        -- 3. Deep Search: ค้นหาข้อความ "close this window" หรือ "Click anywhere" ในทุก ScreenGui
        for _, gui in ipairs(pg:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui ~= ScreenGui and gui.Name ~= "AriseMasterHubGui" then
                local rf = gui:FindFirstChild("RewardsFrame", true)
                if rf and rf:IsA("GuiObject") and rf.Visible then
                    rf.Visible = false
                    gui.Enabled = false
                end
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("TextLabel") and (desc.Text:lower():find("close this window") or desc.Text:lower():find("click anywhere")) then
                        if desc.Parent and desc.Parent:IsA("GuiObject") then
                            desc.Parent.Visible = false
                        end
                        gui.Enabled = false
                        local btn = gui:FindFirstChildWhichIsA("GuiButton", true)
                        if btn then clickGuiButton(btn) end
                        break
                    end
                end
            end
        end
    end)
end

-- สร้าง Alias รองรับจุดอื่นๆ ในสคริปต์
local dismissRewardPopups = dismissAllRewardPopups

local function applyDropVisibility()
    -- 1. ปิด/เปิด Prefabs ใน ReplicatedStorage.Effect (เมื่อ clone ออกมาจะถูกซ่อนหรือแสดงทันที)
    pcall(function()
        local effectFolder = ReplicatedStorage:FindFirstChild("Effect")
        if effectFolder then
            local collectGui = effectFolder:FindFirstChild("CollectGui")
            if collectGui and collectGui:IsA("BillboardGui") then
                collectGui.Enabled = not hideDropsEnabled
            end
            local outGold = effectFolder:FindFirstChild("OutGold")
            if outGold then
                if outGold:IsA("BasePart") then
                    outGold.Transparency = hideDropsEnabled and 1 or 0
                end
                local outGui = outGold:FindFirstChild("OutGui")
                if outGui and outGui:IsA("BillboardGui") then
                    outGui.Enabled = not hideDropsEnabled
                end
            end
        end
    end)

    -- 2. ไอเทมที่ตกอยู่บนพื้นทั้งหมดใน Workspace.Golds
    pcall(function()
        local goldsFolder = Workspace:FindFirstChild("Golds")
        if goldsFolder then
            for _, item in ipairs(goldsFolder:GetChildren()) do
                setItemVisualHidden(item, hideDropsEnabled)
            end
        end
    end)

    -- 3. ไอเทมที่กำลังบินเข้าตัวผู้เล่นใน Workspace.Collects
    pcall(function()
        local collectsFolder = Workspace:FindFirstChild("Collects")
        if collectsFolder then
            for _, item in ipairs(collectsFolder:GetChildren()) do
                setItemVisualHidden(item, hideDropsEnabled)
            end
        end
    end)

    -- 4. ป๊อปอัป CollectGui เหนือหัวตัวละคร
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            for _, desc in ipairs(char:GetDescendants()) do
                if desc.Name == "CollectGui" or desc.Name == "OutGui" then
                    if desc:IsA("BillboardGui") or desc:IsA("GuiObject") then
                        desc.Enabled = not hideDropsEnabled
                    end
                end
            end
        end
    end)

    -- 5. ปิดหน้าต่างของรางวัลทุกชนิดบนหน้าจอทันที
    dismissAllRewardPopups()
end

-- ====================================================================
-- ฟังก์ชันหา MapId ที่ปลอดภัยสำหรับกลับเข้าแมพหลัก (Safe Return Map)
-- ป้องกันบัคส่ง toMapId เป็นแมพที่ยังไม่ได้ปลดล็อคในหอคอย Ascension
-- ====================================================================
local function getSafeReturnMapId()
    -- 1. จาก fromMapId ของ RaidsManager (ถ้ามีค่า ปลอดภัย และไม่ใช่แมพเรด)
    if RaidsManager and RaidsManager.raidsMapInfo then
        local fMap = RaidsManager.raidsMapInfo.fromMapId
        if fMap and fMap > 0 and fMap ~= 50302 and fMap ~= 50403 and (fMap < 50100 or fMap > 50200) then
            return fMap
        end
    end
    -- 2. จากแมพหลักล่าสุดที่ตัวละครเคยยืนอยู่จริง (lastMainMapId)
    if lastMainMapId and lastMainMapId >= 50001 and lastMainMapId <= 50030 then
        return lastMainMapId
    end
    -- 3. จาก spawnMap ของผู้เล่นในข้อมูลเซฟ
    if PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.saveData and PlayerManager.localPlayerData.saveData.spawnMap then
        local sMap = PlayerManager.localPlayerData.saveData.spawnMap
        if sMap and sMap >= 50001 and sMap <= 50030 then
            return sMap
        end
    end
    -- 4. Fallback สูงสุด: Map 1 (50001) ปลดล็อคเสมอ 100%
    return 50001
end

-- ====================================================================
-- ฟังก์ชันตรวจสอบและปิดหน้าต่างสรุปผลเรด (Settlement UI, Defeat UI & Close/Quit Buttons)
-- แก้บัคค้างหน้าจบเรด / Ascension Tower ไม่ยอมออกแมพ ทั้งตอนชนะและตอนแพ้
-- ====================================================================
local function isRaidSettlementVisible()
    -- 1. ตรวจสอบจาก UIManager ก่อน (แม่นยำที่สุด)
    if UIManager and UIManager.panelDict then
        for _, pName in ipairs({ "RaidsFightPanel", "CityFightPanel", "GuildFightPanel" }) do
            local panel = UIManager.panelDict[pName]
            if panel and panel.panelInstance and panel.panelInstance.Enabled then
                if panel.settlementFrame and panel.settlementFrame.Visible == true then
                    return true, panel.settlementFrame, panel, false
                end
                if panel.defeatFrame and panel.defeatFrame.Visible == true then
                    return true, panel.defeatFrame, panel, true
                end
            end
        end
    end

    -- 2. ตรวจสอบจาก PlayerGui ตรงๆ (เฉพาะ SettlementFrame หรือ Defeat ที่ตัว Frame มี Visible == true จริงๆ เท่านั้น)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, pName in ipairs({ "RaidsFightPanel", "CityFightPanel", "GuildFightPanel" }) do
            local p = pg:FindFirstChild(pName)
            if p and p.Enabled then
                local sf = p:FindFirstChild("SettlementFrame")
                if sf and sf:IsA("GuiObject") and sf.Visible == true then
                    return true, sf, p, false
                end
                local df = p:FindFirstChild("Defeat")
                if df and df:IsA("GuiObject") and df.Visible == true then
                    return true, df, p, true
                end
            end
        end
    end

    return false
end

local function dismissRaidSettlement()
    local isVis, frameObj, panel, isDefeat = isRaidSettlementVisible()
    if not isVis then return false end

    -- ทำงานเฉพาะเมื่อหน้าต่างสรุปผลหรือแพ้โผล่ขึ้นมาจริงๆ เท่านั้น!
    pcall(function()
        if panel then
            if isDefeat then
                if panel.OnQuitBtnClick then panel:OnQuitBtnClick() end
                if panel.OnDefeatCloseBtnClick then panel:OnDefeatCloseBtnClick() end
            else
                if panel.OnCloseBtnClick then panel:OnCloseBtnClick() end
                if panel.OnSuccessCloseBtnClick then panel:OnSuccessCloseBtnClick() end
            end
        end
    end)

    if frameObj then
        local btn = frameObj:FindFirstChild("CloseBtn", true) 
            or frameObj:FindFirstChild("ConfirmButton", true) 
            or frameObj:FindFirstChild("CloseButton", true)
        if btn and btn:IsA("GuiButton") and btn.Visible then 
            clickGuiButton(btn) 
        end
        pcall(function() frameObj.Visible = false end)
    end

    -- เรียก RaidsManager.QuitRaidMap() ของตัวเกม
    pcall(function()
        if RaidsManager and RaidsManager.QuitRaidMap and RaidsManager.raidsMapInfo then
            RaidsManager.QuitRaidMap()
        end
    end)
    return true
end

-- ====================================================================
-- ระบบ Hooks สกัดกั้นป๊อปอัปของรางวัลไม่ให้แสดงผล (ShowRewards & ShowPanel Hooks)
-- ====================================================================

-- Hook TipsManager.ShowRewards ป้องกันไม่ให้ส่งคำสั่งเปิด UI รางวัลตั้งแต่ต้นทาง
local tipsManagerHooked = false
hookTipsManager = function()
    if tipsManagerHooked then return end
    pcall(function()
        if not TipsManager then
            TipsManager = safeRequire(function()
                return require(ReplicatedStorage.Scripts.Client.Manager.TipsManager)
            end)
        end
        if TipsManager and type(TipsManager.ShowRewards) == "function" then
            local rawShowRewards = TipsManager.ShowRewards
            TipsManager.ShowRewards = function(...)
                if hideDropsEnabled then
                    return
                end
                return rawShowRewards(...)
            end
            tipsManagerHooked = true
        end

        -- Hook โดยตรงที่คลาส TipsPanel ใน ReplicatedStorage
        pcall(function()
            local UI2 = ReplicatedStorage:FindFirstChild("Scripts")
                and ReplicatedStorage.Scripts:FindFirstChild("Client")
                and ReplicatedStorage.Scripts.Client:FindFirstChild("UI")
            if UI2 and UI2:FindFirstChild("TipsPanel") then
                local tpClass = safeRequire(function() return require(UI2.TipsPanel) end)
                if tpClass and type(tpClass.ShowRewards) == "function" and not tpClass._hookedClassShowRewards then
                    local rawClassShowRewards = tpClass.ShowRewards
                    tpClass._hookedClassShowRewards = true
                    tpClass.ShowRewards = function(self, ...)
                        if hideDropsEnabled then
                            if self.rewardsFrame then self.rewardsFrame.Visible = false end
                            if self.OnRewardConfirmBtnClick then
                                pcall(function() self:OnRewardConfirmBtnClick() end)
                            end
                            return
                        end
                        return rawClassShowRewards(self, ...)
                    end
                end
            end
        end)
    end)
end

-- Hook UIManager.ShowPanel ไม่ให้เปิด RewardPanel หรือ TipsPanel ชนิด Rewards
local uiManagerHooked = false
hookUIManager = function()
    if uiManagerHooked then return end
    pcall(function()
        if not UIManager then
            UIManager = safeRequire(function()
                return require(ReplicatedStorage.Scripts.Client.Manager.UIManager)
            end)
        end
        if UIManager and type(UIManager.ShowPanel) == "function" then
            local rawShowPanel = UIManager.ShowPanel
            UIManager.ShowPanel = function(panelName, pData, ...)
                if hideDropsEnabled then
                    if panelName == "RewardPanel" or (UIManager.UIPanelName and panelName == UIManager.UIPanelName.RewardPanel) then
                        return
                    end
                    local isTips = (panelName == "TipsPanel" or panelName == "TipsFloatingPanel")
                        or (UIManager.UIPanelName and (panelName == UIManager.UIPanelName.TipsPanel or panelName == UIManager.UIPanelName.TipsFloatingPanel))
                    if isTips and type(pData) == "table" and pData.tipsType == "Rewards" then
                        return
                    end
                end
                return rawShowPanel(panelName, pData, ...)
            end
            uiManagerHooked = true
        end
    end)
end

-- Hook instance methods ใน UIManager.panelDict
local function hookPanelMethods()
    pcall(function()
        if UIManager and UIManager.panelDict then
            for _, pName in ipairs({ "TipsPanel", "TipsFloatingPanel" }) do
                local panel = UIManager.panelDict[pName]
                if panel and type(panel.ShowRewards) == "function" and not panel._hookedShowRewards then
                    local rawSR = panel.ShowRewards
                    panel._hookedShowRewards = true
                    panel.ShowRewards = function(self, ...)
                        if hideDropsEnabled then
                            if self.rewardsFrame then
                                self.rewardsFrame.Visible = false
                            end
                            return
                        end
                        return rawSR(self, ...)
                    end
                end
            end
        end
    end)
end

-- สั่งเริ่ม Hook ทันที
pcall(hookTipsManager)
pcall(hookUIManager)

-- Hook PlayerGui ดักจับ RewardsFrame และ RewardPanel ทันทีที่มีการเปลี่ยนแปลง
pcall(function()
    local pg = LocalPlayer:WaitForChild("PlayerGui", 10)
    if pg then
        local function bindRewardsWatcher(pGui)
            if not pGui then return end
            local rf = pGui:FindFirstChild("RewardsFrame", true)
            if rf and rf:IsA("GuiObject") then
                rf:GetPropertyChangedSignal("Visible"):Connect(function()
                    if hideDropsEnabled and rf.Visible then
                        task.defer(dismissAllRewardPopups)
                    end
                end)
            end
            if pGui:IsA("ScreenGui") then
                pGui:GetPropertyChangedSignal("Enabled"):Connect(function()
                    if hideDropsEnabled and pGui.Enabled then
                        task.defer(dismissAllRewardPopups)
                    end
                end)
            end
        end

        for _, name in ipairs({ "TipsPanel", "TipsFloatingPanel", "RewardPanel", "GroupRewardPanel", "OnlineRewardPanel", "ReferralRewardPanel", "VipRewardPanel" }) do
            local existing = pg:FindFirstChild(name)
            if existing then
                bindRewardsWatcher(existing)
            end
        end

        pg.ChildAdded:Connect(function(child)
            bindRewardsWatcher(child)
            if hideDropsEnabled then
                for _, name in ipairs({ "TipsPanel", "TipsFloatingPanel", "RewardPanel" }) do
                    if child.Name == name then
                        task.defer(dismissAllRewardPopups)
                    end
                end
            end
        end)
    end
end)

-- Background Daemon Loop: เฝ้าระวังและปิดป๊อปอัปของรางวัลตลอดเวลาเมื่อเปิด Hide Drops
task.spawn(function()
    while true do
        task.wait(0.2)
        if hideDropsEnabled then
            dismissAllRewardPopups()
            hookPanelMethods()
        end
    end
end)

-- Hook ItemDropServices.AddCollectAnimation เพื่อป้องกันการ spawn CollectGui และ RenderStepped เมื่อเปิดซ่อนของ
local itemDropServicesHooked = false
hookItemDropServices = function()
    if itemDropServicesHooked then return end
    pcall(function()
        local ItemDropServices = safeRequire(function()
            return require(ReplicatedStorage.Scripts.Client.Services.ItemDropServices)
        end)
        if ItemDropServices and type(ItemDropServices.AddCollectAnimation) == "function" then
            local rawAddCollectAnimation = ItemDropServices.AddCollectAnimation
            ItemDropServices.AddCollectAnimation = function(guid, itemData)
                if hideDropsEnabled then
                    return
                end
                return rawAddCollectAnimation(guid, itemData)
            end
            itemDropServicesHooked = true
        end
    end)
end

-- Hook ดักจับโฟลเดอร์ Golds และ Collects แบบ Real-time
local hookedDropFolders = {}
local function hookDropFolder(folder)
    if not folder or hookedDropFolders[folder] then return end
    hookedDropFolders[folder] = true
    folder.ChildAdded:Connect(function(child)
        if hideDropsEnabled then
            task.defer(function()
                setItemVisualHidden(child, true)
            end)
        end
    end)
end

pcall(function()
    hookDropFolder(Workspace:FindFirstChild("Golds"))
    hookDropFolder(Workspace:FindFirstChild("Collects"))
    Workspace.ChildAdded:Connect(function(child)
        if child.Name == "Golds" or child.Name == "Collects" then
            hookDropFolder(child)
            if hideDropsEnabled then
                task.defer(function()
                    for _, item in ipairs(child:GetChildren()) do
                        setItemVisualHidden(item, true)
                    end
                end)
            end
        end
    end)
end)

-- Hook ดักจับ CollectGui ที่อาจถูกสร้างบนตัวละคร
local function hookCharacterDropPopups(char)
    if not char then return end
    char.DescendantAdded:Connect(function(desc)
        if hideDropsEnabled then
            if desc.Name == "CollectGui" or desc.Name == "OutGui" then
                if desc:IsA("BillboardGui") then
                    desc.Enabled = false
                end
            end
        end
    end)
end

pcall(function()
    LocalPlayer.CharacterAdded:Connect(function(char)
        if BossAlert and BossAlert.billboard then
            pcall(function() BossAlert.billboard:Destroy() end)
            BossAlert.billboard = nil
        end
        hookCharacterDropPopups(char)
        task.wait(1)
        if hideDropsEnabled then
            applyDropVisibility()
        end
        if OPT.hideDamageEnabled then
            OPT.ensureDamageHook()
            OPT.clearDamagePopups()
        end
        if OPT.hideSkillEffectsEnabled then
            OPT.ensureSkillEffectsHook()
            OPT.clearSkillEffects()
        end
    end)
    if LocalPlayer.Character then
        hookCharacterDropPopups(LocalPlayer.Character)
    end
end)

-- ====================================================================
-- ฟังก์ชันร่ายสกิลผู้เล่นบนหน้าจอ (Z, X, C, V, F + สกิลปราณ ในเรดอีเว้นแมพ 1)
-- ====================================================================
local function castScreenSkills(targetGuid)
    pcall(function()
        local mainPanel = UIManager and UIManager.panelDict and UIManager.panelDict[UIManager.UIPanelName.MainPanel]
        if mainPanel then
            -- [คำสั่งผู้ใช้] ไม่ต้องกดสกิล Z, X, C, V, F ให้อัตโนมัติ ยกเว้นในเรดอีเว้นแมพ 1 เท่านั้น!
            if isEventRaidMap1() and mainPanel.skills then
                for _, btn in pairs(mainPanel.skills:GetChildren()) do
                    if btn:IsA("GuiButton") and btn.Visible and btn:FindFirstChild("Lock") and not btn.Lock.Visible then
                        mainPanel:OnSkillBtnClick(btn)
                    end
                end
            end

            -- ปลดล็อคและกดใช้ Weapon Skill / Angry Skill ทันทีเมื่อเกจเต็ม
            if mainPanel.weaponSkillBtn and mainPanel.weaponSkillBtn.Visible then
                mainPanel.isCanClickWeaponSkillBtn = true
                if mainPanel.weaponSkillTimer then mainPanel.weaponSkillTimer = 0 end
                pcall(function() mainPanel:OnWeaponSkillBtnClick() end)
            end
        end

        -- ปล่อยสกิลปราณ (เฉพาะในเรดอีเว้นแมพ 1 เท่านั้น เพื่อไม่ให้ขัดจังหวะการฟันธรรมดาในโหมดอื่น)
        if isEventRaidMap1() and targetGuid and ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.PlayerRespirationSkillAttack then
            task.spawn(function()
                pcall(function()
                    local PlayerEntityHelper = safeRequire(function() return require(ReplicatedStorage.Scripts.Share.PlayerEntityHelper) end)
                    if PlayerEntityHelper and PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.saveData then
                        local respData = PlayerEntityHelper.GetCurrentRespirationData(PlayerManager.localPlayerData.saveData)
                        if respData and respData.respirationType and respData.skills then
                            for _, skillId in pairs(respData.skills) do
                                ProtocolManager.SendMessage(ProtocolManager.Protocols.PlayerRespirationSkillAttack.Name, {
                                    enemyGuid = targetGuid,
                                    respirationType = respData.respirationType,
                                    skillId = tonumber(skillId)
                                })
                            end
                        end
                    end
                end)
            end)
        end
    end)
end

-- ====================================================================
-- ฟังก์ชันวาปเงามาประกบเป้าหมายทันที และเริ่มโจมตี (Hero Fast-Deploy)
-- ====================================================================
local function deployHeroesToTarget(targetPos, targetGuid)
    pcall(function()
        -- 1. สั่งระบบเป้าหมายของเงาใน Client ก่อน
        if PlayerManager and targetGuid then
            PlayerManager.LocalClientSetAttackTarget(LocalPlayer.UserId, targetGuid)
        end

        -- 2. วาปเงาทุกตัวมาประกบรอบเป้าหมายด้วยความสูงเหนือพื้นจริง (ไม่ให้จมแมพลง Void) และเริ่มลูปโจมตี (HeroAttack)
        local playerInst = PlayerManager and PlayerManager.PlayerInstances and PlayerManager.PlayerInstances[LocalPlayer.UserId]
        if playerInst and playerInst.heros then
            if targetGuid then
                playerInst.attackTarget = targetGuid
            end

            local heroList = {}
            for _, hEnt in pairs(playerInst.heros) do
                if hEnt and hEnt.character and hEnt.character:FindFirstChild("HumanoidRootPart") then
                    table.insert(heroList, hEnt)
                end
            end

            local totalHeroes = #heroList
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.IgnoreWater = true
            local filter = {}
            local ef = Workspace:FindFirstChild("Enemys")
            local hf = Workspace:FindFirstChild("Heros")
            if ef then table.insert(filter, ef) end
            if hf then table.insert(filter, hf) end
            if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
            if safePlatform then table.insert(filter, safePlatform) end
            rayParams.FilterDescendantsInstances = filter

            for idx, heroEntity in ipairs(heroList) do
                local char = heroEntity.character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    -- ยกเลิกเธรดเดิน/หมุนตัวของเกมที่อาจแย่งสถานะและสั่งหยุดตีขณะใช้ Map Farm
                    if heroEntity.moveFunction then
                        pcall(task.cancel, heroEntity.moveFunction)
                        heroEntity.moveFunction = nil
                    end
                    if heroEntity.moveConnection then
                        pcall(function() heroEntity.moveConnection:Disconnect() end)
                        heroEntity.moveConnection = nil
                    end
                    if heroEntity.CancelRotate then
                        pcall(function() heroEntity:CancelRotate() end)
                    end
                    if heroEntity.StopMove then
                        pcall(function() heroEntity:StopMove() end)
                    end

                    for _, part in pairs(char:GetChildren()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end

                    local distXZ = Vector2.new(hrp.Position.X - targetPos.X, hrp.Position.Z - targetPos.Z).Magnitude
                    local fellUnder = (hrp.Position.Y < targetPos.Y - 2.5) or (hrp.Position.Y > targetPos.Y + 25)
                    local targetChanged = (heroEntity._lastTargetGuid ~= targetGuid)

                    if distXZ > 8 or fellUnder or targetChanged then
                        local angle = ((idx - 1) / math.max(1, totalHeroes)) * (math.pi * 2)
                        local offsetX = math.cos(angle) * 3.2
                        local offsetZ = math.sin(angle) * 3.2

                        local hum = char:FindFirstChildWhichIsA("Humanoid")
                        local hip = (hum and hum.HipHeight and hum.HipHeight > 0) and hum.HipHeight or 2.0
                        local rootHeight = math.clamp((hrp.Size.Y * 0.5) + hip + 1.5, 3.0, 6.5)

                        local standY = targetPos.Y + math.max(2.4, rootHeight - 1.5)
                        pcall(function()
                            local origin = Vector3.new(targetPos.X + offsetX, targetPos.Y + 25, targetPos.Z + offsetZ)
                            local hit = Workspace:Raycast(origin, Vector3.new(0, -80, 0), rayParams)
                            if hit and hit.Position then
                                standY = math.max(targetPos.Y + 1.8, hit.Position.Y + rootHeight)
                            end
                        end)

                        local heroPos = Vector3.new(targetPos.X + offsetX, standY, targetPos.Z + offsetZ)
                        local lookAtPos = Vector3.new(targetPos.X, standY, targetPos.Z)
                        if (lookAtPos - heroPos).Magnitude < 0.05 then
                            lookAtPos = heroPos + Vector3.new(0, 0, -1)
                        end
                        local safeCF = CFrame.lookAt(heroPos, lookAtPos)

                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                        hrp.CFrame = safeCF

                        if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.HeroReachedAttackPos then
                            pcall(function()
                                ProtocolManager.SendMessage(ProtocolManager.Protocols.HeroReachedAttackPos.Name, {
                                    masterId = LocalPlayer.UserId,
                                    guid = heroEntity.saveData and heroEntity.saveData.guid,
                                    cframe = safeCF
                                })
                            end)
                        end
                    else
                        if hrp.AssemblyLinearVelocity.Y < -10 then
                            hrp.AssemblyLinearVelocity = Vector3.zero
                        end
                        local lookTarget = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)
                        if (lookTarget - hrp.Position).Magnitude > 0.1 then
                            hrp.CFrame = CFrame.lookAt(hrp.Position, lookTarget)
                        end
                    end

                    heroEntity.isMove = false
                    heroEntity.enemyPos = targetPos
                    heroEntity.fightingPos = hrp.Position
                    heroEntity.isLookAtTarget = true
                    heroEntity.currentState = 2 -- HeroEntity.state.Attack

                    -- ตรวจสอบว่าเงากำลังโจมตีเป้าหมายนี้อยู่หรือไม่ ถ้ายังไม่ได้เริ่ม หรือเธรดตายแล้ว ให้สั่ง HeroAttack ทันที
                    local isDead = (not heroEntity.attackFunction) or (type(heroEntity.attackFunction) == "thread" and coroutine.status(heroEntity.attackFunction) == "dead")
                    if isDead or targetChanged then
                        heroEntity._lastTargetGuid = targetGuid
                        pcall(function()
                            if heroEntity.EnterBattleState then heroEntity:EnterBattleState() end
                            if heroEntity.HeroAttack then heroEntity:HeroAttack() end
                        end)
                    end
                end
            end
        end
    end)
end

-- ====================================================================
-- ฟังก์ชันค้นหามอนสเตอร์ทั้งหมดในแมพ (All Map Mobs Collector - ความเร็วสูง ไม่แล็ก ไม่ค้าง)
-- ====================================================================
local function getAllMapEnemies()
    local list = {}
    local addedGuids = {}

    -- 1. ดึงข้อมูลจาก EnemyManager.enemyEntitys ก่อน (แม่นยำและเรียลไทม์ที่สุด)
    if EnemyManager and EnemyManager.enemyEntitys then
        for guid, ent in pairs(EnemyManager.enemyEntitys) do
            local char = ent and (ent.character or ent.model or ent.entityModel)
            if char and char.Parent then
                local isAlive = true
                if ent.data and ent.data.hp and ent.data.hp <= 0 then isAlive = false end
                if ent.isLive == false or ent.isDeathEffectPlayed == true then isAlive = false end
                if char:GetAttribute("Died") == true then isAlive = false end
                local hum = char:FindFirstChildWhichIsA("Humanoid")
                if hum and hum.Health <= 0 then isAlive = false end

                if isAlive then
                    local primary = char.PrimaryPart 
                        or char:FindFirstChild("HumanoidRootPart") 
                        or char:FindFirstChild("Torso") 
                        or char:FindFirstChild("UpperTorso") 
                        or char:FindFirstChild("Head") 
                        or char:FindFirstChildWhichIsA("BasePart")
                    if primary then
                        if not char.PrimaryPart then char.PrimaryPart = primary end
                        local hp = (ent.data and ent.data.hp) or (hum and hum.Health) or 100
                        local maxHp = (ent.data and ent.data.maxHp) or (hum and hum.MaxHealth) or hp
                        local lvl = (ent.data and ent.data.enemyLevel) or 1
                        addedGuids[guid] = true
                        table.insert(list, {
                            guid = guid,
                            entity = ent,
                            model = char,
                            hp = hp,
                            maxHp = maxHp,
                            level = lvl,
                            name = char.Name,
                            pos = primary.Position
                        })
                    end
                end
            end
        end
    end

    -- 2. ดึงจากโฟลเดอร์มอนสเตอร์ทั้งหมดใน Workspace & Map
    local searchFolders = {}
    for _, fName in ipairs({ "Enemys", "RaidsEnemys", "Enemies", "Monsters", "Mobs", "Bosses" }) do
        local f = Workspace:FindFirstChild(fName)
        if f then table.insert(searchFolders, f) end
    end
    pcall(function()
        if MapManager and MapManager.currentMapData and MapManager.currentMapData.instance and MapManager.currentMapData.instance.Map then
            local m = MapManager.currentMapData.instance.Map
            for _, c in pairs(m:GetChildren()) do
                local cn = c.Name:lower()
                if cn:find("enem") or cn:find("mob") or cn:find("monster") or cn:find("boss") then
                    table.insert(searchFolders, c)
                end
            end
        end
    end)

    for _, folder in ipairs(searchFolders) do
        for _, model in pairs(folder:GetChildren()) do
            if model:IsA("Model") and model.Parent and not Players:GetPlayerFromCharacter(model) and model ~= LocalPlayer.Character then
                local guid = model:GetAttribute("EnemyGuid") or tostring(model)
                if not addedGuids[guid] then
                    local isAlive = true
                    if model:GetAttribute("Died") == true then isAlive = false end
                    local hum = model:FindFirstChildWhichIsA("Humanoid")
                    if hum and hum.Health <= 0 then isAlive = false end

                    local ent = guid and EnemyManager and EnemyManager.enemyEntitys and EnemyManager.enemyEntitys[guid]
                    if ent and ent.data and ent.data.hp and ent.data.hp <= 0 then isAlive = false end
                    if ent and (ent.isLive == false or ent.isDeathEffectPlayed == true) then isAlive = false end

                    if isAlive then
                        local primary = model.PrimaryPart 
                            or model:FindFirstChild("HumanoidRootPart") 
                            or model:FindFirstChild("Torso") 
                            or model:FindFirstChild("UpperTorso") 
                            or model:FindFirstChild("Head") 
                            or model:FindFirstChildWhichIsA("BasePart")
                        if primary then
                            if not model.PrimaryPart then model.PrimaryPart = primary end
                            local hp = (ent and ent.data and ent.data.hp) or (hum and hum.Health) or 100
                            local maxHp = (ent and ent.data and ent.data.maxHp) or (hum and hum.MaxHealth) or hp
                            local lvl = (ent and ent.data and ent.data.enemyLevel) or 1
                            addedGuids[guid] = true
                            table.insert(list, {
                                guid = guid,
                                entity = ent,
                                model = model,
                                hp = hp,
                                maxHp = maxHp,
                                level = lvl,
                                name = model.Name,
                                pos = primary.Position
                            })
                        end
                    end
                end
            end
        end
    end

    return list
end

-- ฟังก์ชันค้นหามอนในเรด (รองรับเรดปกติ, อีเว้นท์ และหอคอย Ascension)
findTargetRaidEnemy = function()
    local curMapCfg = getCurrentMapConfig()
    local curMapId = MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo and MapManager.currentMapData.mapSlotInfo.mapId
    local isAsc = (curMapCfg and curMapCfg.isAscension)
        or (raidTypeIndex == 2)
        or (curMapId == 50302)
        or (RaidsManager and RaidsManager.raidsMapInfo and RaidsManager.raidsMapInfo.mapId == 50302)

    -- หากหน้าต่างจบเรด (Settlement / Defeat) แสดงอยู่แล้วจริงๆ เท่านั้น ถึงจะหยุดเล็งบอส
    if isRaidSettlementVisible() then
        return nil, nil, false
    end

    -- 1. ค้นหาจาก EnemyManager.enemyEntitys ก่อน (รวดเร็วและแม่นยำที่สุด 100%)
    if EnemyManager and EnemyManager.enemyEntitys then
        local currentRaidLvl = (RaidsManager and RaidsManager.raidsMapInfo and RaidsManager.raidsMapInfo.currentLevel) or 1
        local highestFloorMob = nil
        local highestFloorEnt = nil
        local currentFloorMob = nil
        local currentFloorEnt = nil
        local maxLvl = -1

        for guid, ent in pairs(EnemyManager.enemyEntitys) do
            local char = ent and (ent.character or ent.model or ent.entityModel)
            if char and char.Parent then
                if ent.data and ent.data.hp and ent.data.hp <= 0 then
                    continue
                end
                if ent.isLive == false or ent.isDeathEffectPlayed == true then
                    continue
                end
                if char:GetAttribute("Died") == true then
                    continue
                end
                local hum = char:FindFirstChildWhichIsA("Humanoid")
                if hum and hum.Health <= 0 then
                    continue
                end
                local primary = char.PrimaryPart 
                    or char:FindFirstChild("HumanoidRootPart") 
                    or char:FindFirstChild("Torso") 
                    or char:FindFirstChild("UpperTorso") 
                    or char:FindFirstChild("Head") 
                    or char:FindFirstChildWhichIsA("BasePart")
                if primary then
                    if not char.PrimaryPart then char.PrimaryPart = primary end
                    local eLevel = (ent.data and ent.data.enemyLevel) or 1

                    if isAsc then
                        -- ใน Ascension Tower มีบอสตัวเดียวเสมอ ลุยทันที 100%
                        return char, ent, true
                    end

                    local name = char.Name:lower()
                    local isExplicitBoss = (eLevel == 99 
                        or name:find("boss") ~= nil 
                        or name:find("vampire") ~= nil 
                        or name:find("monarch") ~= nil 
                        or name:find("ashborn") ~= nil
                        or name:find("baran") ~= nil
                        or name:find("grendal") ~= nil
                        or name:find("demon") ~= nil
                        or name:find("dominion") ~= nil)

                    if isExplicitBoss then
                        return char, ent, true
                    end

                    if eLevel == currentRaidLvl then
                        currentFloorMob = char
                        currentFloorEnt = ent
                    end

                    if eLevel > maxLvl then
                        maxLvl = eLevel
                        highestFloorMob = char
                        highestFloorEnt = ent
                    end
                end
            end
        end

        if currentFloorMob then
            return currentFloorMob, currentFloorEnt, false
        end
        if highestFloorMob then
            return highestFloorMob, highestFloorEnt, (maxLvl == 99)
        end
    end

    -- 2. Fallback: ค้นหาจากโฟลเดอร์มอนสเตอร์ใน Workspace & Map
    local searchFolders = {}
    for _, fName in ipairs({ "Enemys", "RaidsEnemys", "Enemies", "RaidsEnemies", "RaidEnemys", "RaidEnemies", "Monsters", "Bosses" }) do
        local f = Workspace:FindFirstChild(fName)
        if f then table.insert(searchFolders, f) end
    end

    pcall(function()
        if MapManager and MapManager.currentMapData and MapManager.currentMapData.instance and MapManager.currentMapData.instance.Map then
            local mapObj = MapManager.currentMapData.instance.Map
            for _, c in pairs(mapObj:GetChildren()) do
                local cn = c.Name:lower()
                if cn:find("enemy") or cn:find("raid") or cn:find("mob") or cn:find("boss") then
                    local already = false
                    for _, sf in ipairs(searchFolders) do if sf == c then already = true break end end
                    if not already then table.insert(searchFolders, c) end
                end
            end
        end
    end)

    local highestMob = nil
    local highestEnt = nil
    local maxLvl = -1

    for _, folder in ipairs(searchFolders) do
        for _, enemyModel in pairs(folder:GetChildren()) do
            if enemyModel:IsA("Model") and enemyModel.Parent then
                local primary = enemyModel.PrimaryPart 
                    or enemyModel:FindFirstChild("HumanoidRootPart") 
                    or enemyModel:FindFirstChild("Torso") 
                    or enemyModel:FindFirstChild("UpperTorso") 
                    or enemyModel:FindFirstChild("Head") 
                    or enemyModel:FindFirstChildWhichIsA("BasePart")
                if primary then
                    if not enemyModel.PrimaryPart then
                        enemyModel.PrimaryPart = primary
                    end

                    local guid = enemyModel:GetAttribute("EnemyGuid")
                    local ent = guid and EnemyManager and EnemyManager.enemyEntitys and EnemyManager.enemyEntitys[guid]

                    local isAlive = true
                    local eLevel = 1
                    if ent and ent.data then
                        if ent.data.hp and ent.data.hp <= 0 then
                            isAlive = false
                        end
                        if ent.isLive == false or ent.isDeathEffectPlayed == true then
                            isAlive = false
                        end
                        eLevel = ent.data.enemyLevel or 1
                    end

                    if enemyModel:GetAttribute("Died") == true then
                        isAlive = false
                    end

                    local hum = enemyModel:FindFirstChildWhichIsA("Humanoid")
                    if hum and hum.Health <= 0 then
                        isAlive = false
                    end

                    if isAlive and enemyModel.Parent then
                        if isAsc then
                            return enemyModel, ent, true
                        end

                        local name = enemyModel.Name:lower()
                        local isExplicitBoss = (eLevel == 99 
                            or name:find("boss") ~= nil 
                            or name:find("vampire") ~= nil 
                            or name:find("monarch") ~= nil 
                            or name:find("ashborn") ~= nil 
                            or name:find("baran") ~= nil 
                            or name:find("grendal") ~= nil 
                            or name:find("demon") ~= nil 
                            or name:find("dominion") ~= nil)

                        if isExplicitBoss then
                            return enemyModel, ent, true
                        end

                        if eLevel > maxLvl then
                            maxLvl = eLevel
                            highestMob = enemyModel
                            highestEnt = ent
                        end
                    end
                end
            end
        end
    end

    if highestMob then
        return highestMob, highestEnt, (maxLvl == 99)
    end

    -- 3. Fallback สำหรับหอคอย Ascension โดยเฉพาะ: สแกน Model ใน Workspace โดยตรง ป้องกันหลุดทุกกรณี 100%
    if isAsc then
        for _, obj in pairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and obj.Parent and not Players:GetPlayerFromCharacter(obj) and obj ~= LocalPlayer.Character then
                local guid = obj:GetAttribute("EnemyGuid")
                local hasEnemyAttr = (guid ~= nil) or (obj:GetAttribute("EnemyId") ~= nil) or (obj:GetAttribute("EnemyType") ~= nil)
                local name = obj.Name:lower()
                local isBossName = name:find("boss") or name:find("baran") or name:find("grendal") or name:find("vampire") 
                    or name:find("monarch") or name:find("demon") or name:find("dominion") or name:find("ashborn") 
                    or name:find("tower") or name:find("asc") or name:find("king") or name:find("lord")

                if hasEnemyAttr or isBossName then
                    local primary = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                    local hum = obj:FindFirstChildWhichIsA("Humanoid")
                    if primary and (not hum or hum.Health > 0) and obj:GetAttribute("Died") ~= true then
                        local ent = guid and EnemyManager and EnemyManager.enemyEntitys and EnemyManager.enemyEntitys[guid]
                        return obj, ent, true
                    end
                end
            end
        end
    end

    return nil, nil, false
end

-- ฟังก์ชันค้นหากล่องสมบัติในเรด (ปลอดภัย 100% ไม่จับมั่วโดนเงาหรือโมเดลอื่น)
findChestInRaid = function()
    if RaidsManager and RaidsManager.raidsMapInfo and RaidsManager.raidsMapInfo.chest and RaidsManager.raidsMapInfo.chest.Parent then
        return RaidsManager.raidsMapInfo.chest
    end
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Model") then
            local n = obj.Name:lower()
            if n:find("chest") or n:find("enchantchest") or n:find("rewardchest") then
                return obj
            end
        end
    end
    return nil
end

local function getActiveRaidIdForMap(mapCfg)
    if not mapCfg then return nil end
    if RaidsManager and RaidsManager.currentRaidInfos then
        for _, info in pairs(RaidsManager.currentRaidInfos) do
            local rId = tonumber(info.raidId)
            local mId = tonumber(info.mapId)
            if rId and mId == mapCfg.mapId then
                if mapCfg.isEvent then
                    if rId == mapCfg.eventRaidId then return rId end
                elseif mapCfg.validRaidMin and mapCfg.validRaidMax then
                    if rId >= mapCfg.validRaidMin and rId <= mapCfg.validRaidMax then
                        return rId
                    end
                elseif mapCfg.baseId then
                    if rId >= (mapCfg.baseId + 1) and rId <= (mapCfg.baseId + 10) then
                        return rId
                    end
                end
            end
        end
    end
    return nil
end

local STATE_FILE = "arise_bot_state.json"

local function saveBotState(isAutoResume)
    local state = {
        autoResume = isAutoResume or false,
        raidTypeIndex = raidTypeIndex,
        selectedNormalIndex = selectedNormalIndex,
        selectedAscIndex = selectedAscIndex,
        autoRejoinIndex = autoRejoinIndex,
        selectedNormalTiers = selectedNormalTiers,
        selectedAscTiers = selectedAscTiers,
        farmFilterIndex = farmFilterIndex,
        combatGroundMode = combatGroundMode,
        autoStartOnJoin = autoStartOnJoin,
        hideDropsEnabled = hideDropsEnabled,
        hideDamageEnabled = OPT.hideDamageEnabled,
        hideSkillEffectsEnabled = OPT.hideSkillEffectsEnabled,
        boss1PctAlertEnabled = (BossAlert and BossAlert.enabled == true),
        dbAutoCollectEnabled = (OPT and OPT.db and OPT.db.autoLoop == true),
        quirkTypeIndex = quirkTypeIndex,
        quirkSlotIndex = quirkSlotIndex,
        quirkSpeedIndex = quirkSpeedIndex,
        quirkPresetIndex = quirkPresetIndex,
        quirkCustomTargets = quirkCustomTargets,
        timestamp = os.time()
    }
    _G.ariseBotState = state
    pcall(function()
        if writefile then
            writefile(STATE_FILE, HttpService:JSONEncode(state))
        end
    end)
end

local function loadBotState()
    local state = nil
    pcall(function()
        if readfile and isfile and isfile(STATE_FILE) then
            local content = readfile(STATE_FILE)
            state = HttpService:JSONDecode(content)
        end
    end)
    if not state and _G.ariseBotState then
        state = _G.ariseBotState
    end
    if state then
        if state.raidTypeIndex then raidTypeIndex = state.raidTypeIndex end
        if state.selectedNormalIndex then selectedNormalIndex = state.selectedNormalIndex end
        if state.selectedAscIndex then selectedAscIndex = state.selectedAscIndex end
        if state.autoRejoinIndex then autoRejoinIndex = state.autoRejoinIndex end
        if state.selectedNormalTiers then selectedNormalTiers = state.selectedNormalTiers end
        if state.selectedAscTiers then selectedAscTiers = state.selectedAscTiers end
        if state.farmFilterIndex then farmFilterIndex = state.farmFilterIndex end
        if state.combatGroundMode ~= nil then combatGroundMode = state.combatGroundMode end
        if state.autoStartOnJoin ~= nil then autoStartOnJoin = state.autoStartOnJoin end
        if state.hideDropsEnabled ~= nil then 
            hideDropsEnabled = state.hideDropsEnabled 
            if hideDropsEnabled then
                task.defer(applyDropVisibility)
                task.defer(dismissAllRewardPopups)
            end
        end
        if state.hideDamageEnabled ~= nil then
            OPT.hideDamageEnabled = (state.hideDamageEnabled == true)
        end
        if state.hideSkillEffectsEnabled ~= nil then
            OPT.hideSkillEffectsEnabled = (state.hideSkillEffectsEnabled == true)
        end
        if state.boss1PctAlertEnabled ~= nil and BossAlert then
            BossAlert.enabled = (state.boss1PctAlertEnabled == true)
        end
        if state.dbAutoCollectEnabled ~= nil and OPT and OPT.db then
            OPT.db.autoLoop = (state.dbAutoCollectEnabled == true)
        end
        if state.quirkTypeIndex then quirkTypeIndex = state.quirkTypeIndex end
        if state.quirkSlotIndex then quirkSlotIndex = state.quirkSlotIndex end
        if state.quirkSpeedIndex then quirkSpeedIndex = state.quirkSpeedIndex end
        if state.quirkPresetIndex then quirkPresetIndex = state.quirkPresetIndex end
        if state.quirkCustomTargets then quirkCustomTargets = state.quirkCustomTargets end

        local wasAutoResume = false
        if state.timestamp and (os.time() - state.timestamp < 3600) then
            wasAutoResume = (state.autoResume == true)
        end

        pcall(function()
            state.autoResume = false
            if writefile then
                writefile(STATE_FILE, HttpService:JSONEncode(state))
            end
        end)

        return wasAutoResume
    end
    return false
end

local function queueScriptReload()
    local reloadCmd = [[
        task.wait(2)
        if isfile and isfile("autoexec/arise_hub.lua") then return end
    ]]
    pcall(function()
        if queue_on_teleport then
            queue_on_teleport(reloadCmd)
        elseif syn and syn.queue_on_teleport then
            syn.queue_on_teleport(reloadCmd)
        end
    end)
end

local isReconnecting = false
local function handleDisconnect(reason)
    if isReconnecting then return end
    isReconnecting = true

    task.spawn(function()
        print("[Auto-Reconnect] Triggered: " .. tostring(reason))
        if isRaidRunning then
            saveBotState(true)
        end
        queueScriptReload()

        local CoreGui = game:GetService("CoreGui")
        local promptOverlay = CoreGui:FindFirstChild("RobloxPromptGui") and CoreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
        local errorPrompt = promptOverlay and promptOverlay:FindFirstChild("ErrorPrompt")
        local messageArea = errorPrompt and errorPrompt:FindFirstChild("MessageArea", true)
        local errText = messageArea and messageArea:FindFirstChildOfClass("TextLabel")

        -- รอ 12 วินาทีเพื่อให้ Roblox Backend เคลียร์ session เก่าจนหมด (แก้ Error 267 100%)
        for sec = 12, 1, -1 do
            if errText then
                errText.Text = string.format("Session is closing / Disconnected.\nAuto-reconnecting in %d seconds...", sec)
            end
            task.wait(1)
        end

        if errText then
            errText.Text = "Reconnecting now..."
        end

        pcall(function()
            if game.PrivateServerId and game.PrivateServerId ~= "" then
                local opts = Instance.new("TeleportOptions")
                opts.VipServerId = game.PrivateServerId
                TeleportService:TeleportAsync(game.PlaceId, {LocalPlayer}, opts)
            elseif game.JobId and game.JobId ~= "" and autoRejoinIndex == 2 then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            else
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        end)

        task.wait(10)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)
end

-- ดักจับ Disconnect / Error 267
pcall(function()
    local GuiService = game:GetService("GuiService")
    GuiService.ErrorMessageChanged:Connect(function(msg)
        if msg and msg ~= "" then
            handleDisconnect("ErrorMessageChanged: " .. tostring(msg))
        end
    end)
end)

task.spawn(function()
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local promptGui = CoreGui:WaitForChild("RobloxPromptGui", 10)
        if promptGui then
            local overlay = promptGui:WaitForChild("promptOverlay", 10)
            if overlay then
                overlay.ChildAdded:Connect(function(child)
                    if child.Name == "ErrorPrompt" then
                        handleDisconnect("ChildAdded: ErrorPrompt")
                    end
                end)
                if overlay:FindFirstChild("ErrorPrompt") then
                    handleDisconnect("Existing ErrorPrompt")
                end
            end
        end
    end)
end)

-- ====================================================================
-- ฟังก์ชันวาปไปยังแมพเป้าหมายอย่างปลอดภัย (รองรับทั้งแมพปกติและดันเจี้ยนเรด)
-- ====================================================================
local function teleportToMap(targetMapId)
    ensureManagers()
    if MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo then
        local currentMapId = MapManager.currentMapData.mapSlotInfo.mapId
        if currentMapId and currentMapId >= 50001 and currentMapId <= 50030 and currentMapId ~= 50302 and currentMapId ~= 50403 and (currentMapId < 50100 or currentMapId > 50200) then
            lastMainMapId = currentMapId
        end

        local isInsideRaid = (currentMapId == 50302 or currentMapId == 50403 or (currentMapId >= 50100 and currentMapId <= 50200))
        if isInsideRaid and (not targetMapId or targetMapId == 0 or targetMapId == 50302 or targetMapId == 50403 or (targetMapId >= 50100 and targetMapId <= 50200)) then
            targetMapId = getSafeReturnMapId()
        end

        if currentMapId == targetMapId then return end

        -- หากอยู่ในเรด ส่งคำสั่งออกจากเรดทุกช่องทางและปิด UI สรุปผล
        local slotIdx = (RaidsManager and RaidsManager.raidsMapInfo and RaidsManager.raidsMapInfo.slotIndex)
            or (MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo and MapManager.currentMapData.mapSlotInfo.slotIndex)

        -- ตรวจสอบและซ่อมแซม fromMapId เพื่อป้องกัน QuitRaidMap ส่ง toMapId = 0 ไปยัง Server
        if RaidsManager and RaidsManager.raidsMapInfo then
            if not RaidsManager.raidsMapInfo.fromMapId or RaidsManager.raidsMapInfo.fromMapId == 0 or RaidsManager.raidsMapInfo.fromMapId == currentMapId then
                RaidsManager.raidsMapInfo.fromMapId = targetMapId
            end
        end

        dismissRaidSettlement()

        pcall(function()
            local fightPanel = UIManager and UIManager.panelDict and UIManager.panelDict[UIManager.UIPanelName.RaidsFightPanel]
            if fightPanel then
                if fightPanel.OnCloseBtnClick then
                    fightPanel:OnCloseBtnClick()
                elseif fightPanel.settlementFrame then
                    fightPanel.settlementFrame.Visible = false
                end
            end
        end)
        pcall(function()
            if RaidsManager and RaidsManager.QuitRaidMap and RaidsManager.raidsMapInfo then
                RaidsManager.QuitRaidMap()
            end
        end)
        pcall(function()
            if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.QuitRaidsMap then
                ProtocolManager.SendMessage(ProtocolManager.Protocols.QuitRaidsMap.Name, {
                    currentSlotIndex = slotIdx,
                    toMapId = targetMapId
                })
            end
        end)
        pcall(function()
            if Remotes and Remotes.QuitRaidsMap then
                Remotes.QuitRaidsMap:InvokeServer({
                    currentSlotIndex = slotIdx,
                    toMapId = targetMapId
                })
            end
        end)
        pcall(function()
            if UIManager and UIManager.HidePanel then
                UIManager.HidePanel(UIManager.UIPanelName.RaidsFightPanel)
            end
        end)
    end

    local sent = false
    if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.LocalPlayerTeleport then
        pcall(function()
            ProtocolManager.SendMessage(ProtocolManager.Protocols.LocalPlayerTeleport.Name, { mapId = targetMapId })
            sent = true
        end)
    end
    if not sent and Remotes and Remotes:FindFirstChild("LocalPlayerTeleport") then
        pcall(function()
            Remotes.LocalPlayerTeleport:FireServer({ mapId = targetMapId })
        end)
    end
end

_G.ariseVisitedServers = _G.ariseVisitedServers or {}

local function doPublicHop()
    if RaidStatusLabel then
        RaidStatusLabel.Text = "Searching for Different Public Server..."
    end
    task.wait(1)
    local hopped = false
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Desc&limit=100"
        local response = nil
        if game and game.HttpGet then
            pcall(function() response = game:HttpGet(url) end)
        end
        if not response and typeof(HttpGet) == "function" then
            pcall(function() response = HttpGet(url) end)
        end
        if not response and typeof(request) == "function" then
            pcall(function()
                local res = request({ Url = url, Method = "GET" })
                if res and res.Body then response = res.Body end
            end)
        end
        if not response and typeof(http_request) == "function" then
            pcall(function()
                local res = http_request({ Url = url, Method = "GET" })
                if res and res.Body then response = res.Body end
            end)
        end

        if response then
            local data = HttpService:JSONDecode(response)
            if data and data.data then
                local candidates = {}
                for _, srv in ipairs(data.data) do
                    if type(srv) == "table" and srv.id and srv.id ~= game.JobId and not _G.ariseVisitedServers[srv.id] and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers then
                        table.insert(candidates, srv.id)
                    end
                end
                -- หากเข้าเกือบครบทุกห้องแล้ว ให้ล้างประวัติแล้วเลือกห้องใหม่
                if #candidates == 0 then
                    _G.ariseVisitedServers = {}
                    for _, srv in ipairs(data.data) do
                        if type(srv) == "table" and srv.id and srv.id ~= game.JobId and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers then
                            table.insert(candidates, srv.id)
                        end
                    end
                end

                if #candidates > 0 then
                    local targetServer = candidates[math.random(1, #candidates)]
                    _G.ariseVisitedServers[targetServer] = os.time()
                    if RaidStatusLabel then RaidStatusLabel.Text = "Hopping to New Server..." end
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServer, LocalPlayer)
                    hopped = true
                    return
                end
            end
        end
    end)
    if not hopped then
        if RaidStatusLabel then RaidStatusLabel.Text = "Hop fallback: Random Matchmaking..." end
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end

local function doRejoinOrHop()
    local mode = AUTO_REJOIN_MODES[autoRejoinIndex].mode
    if mode == "OFF" then return end

    saveBotState(true)
    queueScriptReload()

    if mode == "HOP" then
        doPublicHop()
    end
end



-- ====================================================================
-- GUI Interface (เวอร์ชันดั้งเดิม 100% - รองรับการคลิกทุกปุ่มบน Mac)
-- ====================================================================
pcall(function()
    if gethui and gethui():FindFirstChild("AriseCompleteHubGUI") then
        gethui().AriseCompleteHubGUI:Destroy()
    end
end)
pcall(function()
    local cg = game:GetService("CoreGui")
    if cg and cg:FindFirstChild("AriseCompleteHubGUI") then
        cg.AriseCompleteHubGUI:Destroy()
    end
end)
pcall(function()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if pg and pg:FindFirstChild("AriseCompleteHubGUI") then
        pg.AriseCompleteHubGUI:Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AriseCompleteHubGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local targetParent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
if not targetParent then
    pcall(function()
        if gethui then targetParent = gethui() end
    end)
end
if not targetParent then
    pcall(function()
        targetParent = game:GetService("CoreGui")
    end)
end
ScreenGui.Parent = targetParent

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 290, 0, 260)
MainFrame.Position = UDim2.new(0.72, 0, 0.22, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 30)
Header.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -44, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ 7Z HUB"
Title.TextColor3 = Color3.fromRGB(255, 175, 0)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

do
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 24, 0, 22)
    minBtn.Position = UDim2.new(1, -28, 0, 4)
    minBtn.BackgroundColor3 = Color3.fromRGB(36, 38, 48)
    minBtn.Text = "—"
    minBtn.TextColor3 = Color3.fromRGB(235, 215, 150)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 13
    minBtn.Parent = Header
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)
    OPT.MinimizeBtn = minBtn
end

-- TabBar (5 Tabs)
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -16, 0, 26)
TabBar.Position = UDim2.new(0, 8, 0, 34)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame

local TabRaidBtn = Instance.new("TextButton")
TabRaidBtn.Size = UDim2.new(0.188, 0, 1, 0)
TabRaidBtn.Position = UDim2.new(0, 0, 0, 0)
TabRaidBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
TabRaidBtn.Text = "⚔️ Raid"
TabRaidBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TabRaidBtn.Font = Enum.Font.GothamBold
TabRaidBtn.TextSize = 10
TabRaidBtn.Parent = TabBar
Instance.new("UICorner", TabRaidBtn).CornerRadius = UDim.new(0, 5)

local TabFarmBtn = Instance.new("TextButton")
TabFarmBtn.Size = UDim2.new(0.188, 0, 1, 0)
TabFarmBtn.Position = UDim2.new(0.203, 0, 0, 0)
TabFarmBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TabFarmBtn.Text = "🌍 Farm"
TabFarmBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
TabFarmBtn.Font = Enum.Font.GothamBold
TabFarmBtn.TextSize = 10
TabFarmBtn.Parent = TabBar
Instance.new("UICorner", TabFarmBtn).CornerRadius = UDim.new(0, 5)

local TabQuirkBtn = Instance.new("TextButton")
TabQuirkBtn.Size = UDim2.new(0.188, 0, 1, 0)
TabQuirkBtn.Position = UDim2.new(0.406, 0, 0, 0)
TabQuirkBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TabQuirkBtn.Text = "🔮 Roll"
TabQuirkBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
TabQuirkBtn.Font = Enum.Font.GothamBold
TabQuirkBtn.TextSize = 10
TabQuirkBtn.Parent = TabBar
Instance.new("UICorner", TabQuirkBtn).CornerRadius = UDim.new(0, 5)

local TabSettingBtn = Instance.new("TextButton")
TabSettingBtn.Size = UDim2.new(0.188, 0, 1, 0)
TabSettingBtn.Position = UDim2.new(0.609, 0, 0, 0)
TabSettingBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TabSettingBtn.Text = "⚙️ Set"
TabSettingBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
TabSettingBtn.Font = Enum.Font.GothamBold
TabSettingBtn.TextSize = 10
TabSettingBtn.Parent = TabBar
Instance.new("UICorner", TabSettingBtn).CornerRadius = UDim.new(0, 5)

local TabInfoBtn = Instance.new("TextButton")
TabInfoBtn.Size = UDim2.new(0.188, 0, 1, 0)
TabInfoBtn.Position = UDim2.new(0.812, 0, 0, 0)
TabInfoBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TabInfoBtn.Text = "ℹ️ Info"
TabInfoBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
TabInfoBtn.Font = Enum.Font.GothamBold
TabInfoBtn.TextSize = 10
TabInfoBtn.Parent = TabBar
Instance.new("UICorner", TabInfoBtn).CornerRadius = UDim.new(0, 5)

-- ====================================================================
-- TAB 1: RAID PAGE
-- ====================================================================
local PageRaid = Instance.new("Frame")
PageRaid.Size = UDim2.new(1, -16, 0, 180)
PageRaid.Position = UDim2.new(0, 8, 0, 66)
PageRaid.BackgroundTransparency = 1
PageRaid.Visible = true
PageRaid.Parent = MainFrame

TypeSelector = Instance.new("TextButton")
TypeSelector.Size = UDim2.new(1, 0, 0, 24)
TypeSelector.Position = UDim2.new(0, 0, 0, 0)
TypeSelector.BackgroundColor3 = Color3.fromRGB(35, 42, 55)
TypeSelector.Text = "Mode: ⚔️ Normal Raid"
TypeSelector.TextColor3 = Color3.fromRGB(100, 210, 255)
TypeSelector.Font = Enum.Font.GothamBold
TypeSelector.TextSize = 11
TypeSelector.Parent = PageRaid
Instance.new("UICorner", TypeSelector).CornerRadius = UDim.new(0, 5)

MapSelector = Instance.new("TextButton")
MapSelector.Size = UDim2.new(1, 0, 0, 24)
MapSelector.Position = UDim2.new(0, 0, 0, 28)
MapSelector.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
MapSelector.Text = "Map: 21,Cursed City"
MapSelector.TextColor3 = Color3.fromRGB(100, 210, 255)
MapSelector.Font = Enum.Font.GothamBold
MapSelector.TextSize = 11
MapSelector.Parent = PageRaid
Instance.new("UICorner", MapSelector).CornerRadius = UDim.new(0, 5)

TierSelector = Instance.new("TextButton")
TierSelector.Size = UDim2.new(1, 0, 0, 24)
TierSelector.Position = UDim2.new(0, 0, 0, 56)
TierSelector.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TierSelector.Text = "Tier: Auto Detect"
TierSelector.TextColor3 = Color3.fromRGB(255, 215, 0)
TierSelector.Font = Enum.Font.GothamBold
TierSelector.TextSize = 10
TierSelector.Parent = PageRaid
Instance.new("UICorner", TierSelector).CornerRadius = UDim.new(0, 5)

RaidStatusLabel = Instance.new("TextLabel")
RaidStatusLabel.Size = UDim2.new(1, 0, 0, 20)
RaidStatusLabel.Position = UDim2.new(0, 0, 0, 84)
RaidStatusLabel.BackgroundTransparency = 1
RaidStatusLabel.Text = "Status: Idle"
RaidStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
RaidStatusLabel.Font = Enum.Font.Gotham
RaidStatusLabel.TextSize = 10
RaidStatusLabel.Parent = PageRaid

ToggleRaidBtn = Instance.new("TextButton")
ToggleRaidBtn.Size = UDim2.new(1, 0, 0, 36)
ToggleRaidBtn.Position = UDim2.new(0, 0, 0, 108)
ToggleRaidBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleRaidBtn.Text = "START AUTO RAID"
ToggleRaidBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleRaidBtn.Font = Enum.Font.GothamBold
ToggleRaidBtn.TextSize = 12
ToggleRaidBtn.Parent = PageRaid
Instance.new("UICorner", ToggleRaidBtn).CornerRadius = UDim.new(0, 6)

-- ====================================================================
-- TAB 2: FARM MAP PAGE (กวาดล้างมอนสเตอร์ทั้งแมพ)
-- ====================================================================
local PageFarm = Instance.new("ScrollingFrame")
PageFarm.Size = UDim2.new(1, -16, 0, 180)
PageFarm.Position = UDim2.new(0, 8, 0, 66)
PageFarm.BackgroundTransparency = 1
PageFarm.BorderSizePixel = 0
PageFarm.ScrollBarThickness = 3
PageFarm.CanvasSize = UDim2.new(0, 0, 0, 315)
PageFarm.Visible = false
PageFarm.Parent = MainFrame

local FarmFilterBtn = Instance.new("TextButton")
FarmFilterBtn.Size = UDim2.new(1, -6, 0, 26)
FarmFilterBtn.Position = UDim2.new(0, 0, 0, 0)
FarmFilterBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 55)
FarmFilterBtn.Text = "Target: All Mobs (ทั้งหมด)"
FarmFilterBtn.TextColor3 = Color3.fromRGB(110, 220, 160)
FarmFilterBtn.Font = Enum.Font.GothamBold
FarmFilterBtn.TextSize = 11
FarmFilterBtn.Parent = PageFarm
Instance.new("UICorner", FarmFilterBtn).CornerRadius = UDim.new(0, 5)

local MobCountLabel = Instance.new("TextLabel")
MobCountLabel.Size = UDim2.new(1, -6, 0, 20)
MobCountLabel.Position = UDim2.new(0, 0, 0, 30)
MobCountLabel.BackgroundTransparency = 1
MobCountLabel.Text = "Alive Mobs in Map: --"
MobCountLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
MobCountLabel.Font = Enum.Font.Gotham
MobCountLabel.TextSize = 10
MobCountLabel.Parent = PageFarm

FarmStatusLabel = Instance.new("TextLabel")
FarmStatusLabel.Size = UDim2.new(1, -6, 0, 20)
FarmStatusLabel.Position = UDim2.new(0, 0, 0, 54)
FarmStatusLabel.BackgroundTransparency = 1
FarmStatusLabel.Text = "Status: Idle"
FarmStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
FarmStatusLabel.Font = Enum.Font.Gotham
FarmStatusLabel.TextSize = 10
FarmStatusLabel.Parent = PageFarm

ToggleFarmBtn = Instance.new("TextButton")
ToggleFarmBtn.Size = UDim2.new(1, -6, 0, 36)
ToggleFarmBtn.Position = UDim2.new(0, 0, 0, 82)
ToggleFarmBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleFarmBtn.Text = "START ALL MAP FARM"
ToggleFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleFarmBtn.Font = Enum.Font.GothamBold
ToggleFarmBtn.TextSize = 12
ToggleFarmBtn.Parent = PageFarm
Instance.new("UICorner", ToggleFarmBtn).CornerRadius = UDim.new(0, 6)

do
    local dbDiv = Instance.new("Frame")
    dbDiv.Size = UDim2.new(1, -6, 0, 1)
    dbDiv.Position = UDim2.new(0, 0, 0, 124)
    dbDiv.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    dbDiv.BorderSizePixel = 0
    dbDiv.Parent = PageFarm

    local dbHdr = Instance.new("TextLabel")
    dbHdr.Size = UDim2.new(1, -6, 0, 16)
    dbHdr.Position = UDim2.new(0, 0, 0, 129)
    dbHdr.BackgroundTransparency = 1
    dbHdr.Text = "🐉 Dragon Ball Radar (Free 7-Ball)"
    dbHdr.TextColor3 = Color3.fromRGB(255, 200, 65)
    dbHdr.Font = Enum.Font.GothamBold
    dbHdr.TextSize = 10
    dbHdr.TextXAlignment = Enum.TextXAlignment.Left
    dbHdr.Parent = PageFarm

    local dbStat = Instance.new("TextLabel")
    dbStat.Size = UDim2.new(1, -6, 0, 16)
    dbStat.Position = UDim2.new(0, 0, 0, 146)
    dbStat.BackgroundTransparency = 1
    dbStat.Text = "Radar: กด Scan เพื่อเช็กลูกแก้ว 7 ลูก"
    dbStat.TextColor3 = Color3.fromRGB(190, 225, 255)
    dbStat.Font = Enum.Font.Gotham
    dbStat.TextSize = 9
    dbStat.TextXAlignment = Enum.TextXAlignment.Left
    dbStat.TextTruncate = Enum.TextTruncate.AtEnd
    dbStat.Parent = PageFarm
    OPT.db.StatusLabel = dbStat

    local dbBox = Instance.new("Frame")
    dbBox.Size = UDim2.new(1, -6, 0, 74)
    dbBox.Position = UDim2.new(0, 0, 0, 164)
    dbBox.BackgroundColor3 = Color3.fromRGB(24, 26, 35)
    dbBox.BorderSizePixel = 0
    dbBox.Parent = PageFarm
    Instance.new("UICorner", dbBox).CornerRadius = UDim.new(0, 5)

    local dbList = Instance.new("TextLabel")
    dbList.Size = UDim2.new(1, -10, 1, -6)
    dbList.Position = UDim2.new(0, 5, 0, 3)
    dbList.BackgroundTransparency = 1
    dbList.Text = "• ยังไม่ได้สแกน (กด 🔍 Scan Radar)"
    dbList.TextColor3 = Color3.fromRGB(235, 235, 240)
    dbList.Font = Enum.Font.Gotham
    dbList.TextSize = 9
    dbList.TextWrapped = true
    dbList.TextXAlignment = Enum.TextXAlignment.Left
    dbList.TextYAlignment = Enum.TextYAlignment.Top
    dbList.Parent = dbBox
    OPT.db.ListLabel = dbList

    local dbScan = Instance.new("TextButton")
    dbScan.Size = UDim2.new(0.47, 0, 0, 26)
    dbScan.Position = UDim2.new(0, 0, 0, 243)
    dbScan.BackgroundColor3 = Color3.fromRGB(40, 60, 90)
    dbScan.Text = "🔍 Scan Radar"
    dbScan.TextColor3 = Color3.fromRGB(210, 235, 255)
    dbScan.Font = Enum.Font.GothamBold
    dbScan.TextSize = 10
    dbScan.Parent = PageFarm
    Instance.new("UICorner", dbScan).CornerRadius = UDim.new(0, 5)
    OPT.db.ScanBtn = dbScan

    local dbCollect = Instance.new("TextButton")
    dbCollect.Size = UDim2.new(0.50, -6, 0, 26)
    dbCollect.Position = UDim2.new(0.50, 0, 0, 243)
    dbCollect.BackgroundColor3 = Color3.fromRGB(210, 120, 30)
    dbCollect.Text = "🚀 Auto เก็บทั้งหมด"
    dbCollect.TextColor3 = Color3.fromRGB(255, 255, 255)
    dbCollect.Font = Enum.Font.GothamBold
    dbCollect.TextSize = 10
    dbCollect.Parent = PageFarm
    Instance.new("UICorner", dbCollect).CornerRadius = UDim.new(0, 5)
    OPT.db.CollectBtn = dbCollect

    local dbAuto = Instance.new("TextButton")
    dbAuto.Size = UDim2.new(1, -6, 0, 26)
    dbAuto.Position = UDim2.new(0, 0, 0, 274)
    dbAuto.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    dbAuto.Text = "♻️ Auto Collect Loop: OFF (รอกดเอง)"
    dbAuto.TextColor3 = Color3.fromRGB(180, 180, 180)
    dbAuto.Font = Enum.Font.GothamBold
    dbAuto.TextSize = 10
    dbAuto.Parent = PageFarm
    Instance.new("UICorner", dbAuto).CornerRadius = UDim.new(0, 5)
    OPT.db.AutoBtn = dbAuto
end

-- ====================================================================
-- TAB 3: QUIRK AUTO-REROLL PAGE (สุ่ม Quirk อัตโนมัติ & ล็อคเป้าหมาย)
-- ====================================================================
local PageQuirk = Instance.new("ScrollingFrame")
PageQuirk.Size = UDim2.new(1, -16, 0, 180)
PageQuirk.Position = UDim2.new(0, 8, 0, 66)
PageQuirk.BackgroundTransparency = 1
PageQuirk.BorderSizePixel = 0
PageQuirk.ScrollBarThickness = 3
PageQuirk.CanvasSize = UDim2.new(0, 0, 0, 235)
PageQuirk.Visible = false
PageQuirk.Parent = MainFrame

local QuirkTypeBtn = Instance.new("TextButton")
QuirkTypeBtn.Size = UDim2.new(1, -6, 0, 24)
QuirkTypeBtn.Position = UDim2.new(0, 0, 0, 0)
QuirkTypeBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
QuirkTypeBtn.Text = "🔮 Mode: 👤 Hero Quirk"
QuirkTypeBtn.TextColor3 = Color3.fromRGB(220, 170, 255)
QuirkTypeBtn.Font = Enum.Font.GothamBold
QuirkTypeBtn.TextSize = 10
QuirkTypeBtn.Parent = PageQuirk
Instance.new("UICorner", QuirkTypeBtn).CornerRadius = UDim.new(0, 5)

local QuirkSlotBtn = Instance.new("TextButton")
QuirkSlotBtn.Size = UDim2.new(1, -6, 0, 24)
QuirkSlotBtn.Position = UDim2.new(0, 0, 0, 28)
QuirkSlotBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
QuirkSlotBtn.Text = "📍 Slot: Slot 1 (Red Core)"
QuirkSlotBtn.TextColor3 = Color3.fromRGB(150, 210, 255)
QuirkSlotBtn.Font = Enum.Font.GothamBold
QuirkSlotBtn.TextSize = 10
QuirkSlotBtn.Parent = PageQuirk
Instance.new("UICorner", QuirkSlotBtn).CornerRadius = UDim.new(0, 5)

local QuirkHeroLabel = Instance.new("TextLabel")
QuirkHeroLabel.Size = UDim2.new(1, -6, 0, 16)
QuirkHeroLabel.Position = UDim2.new(0, 0, 0, 56)
QuirkHeroLabel.BackgroundTransparency = 1
QuirkHeroLabel.Text = "Hero: Checking... | Cur Quirk: None"
QuirkHeroLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
QuirkHeroLabel.Font = Enum.Font.Gotham
QuirkHeroLabel.TextSize = 9
QuirkHeroLabel.TextXAlignment = Enum.TextXAlignment.Left
QuirkHeroLabel.Parent = PageQuirk

local QuirkCoreLabel = Instance.new("TextLabel")
QuirkCoreLabel.Size = UDim2.new(1, -6, 0, 16)
QuirkCoreLabel.Position = UDim2.new(0, 0, 0, 74)
QuirkCoreLabel.BackgroundTransparency = 1
QuirkCoreLabel.Text = "Available Cores: Red Core x0"
QuirkCoreLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
QuirkCoreLabel.Font = Enum.Font.Gotham
QuirkCoreLabel.TextSize = 9
QuirkCoreLabel.TextXAlignment = Enum.TextXAlignment.Left
QuirkCoreLabel.Parent = PageQuirk

local QuirkPresetBtn = Instance.new("TextButton")
QuirkPresetBtn.Size = UDim2.new(1, -6, 0, 24)
QuirkPresetBtn.Position = UDim2.new(0, 0, 0, 94)
QuirkPresetBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 35)
QuirkPresetBtn.Text = "🎯 Target: 🌟 Mythic Only (Q5+)"
QuirkPresetBtn.TextColor3 = Color3.fromRGB(255, 215, 100)
QuirkPresetBtn.Font = Enum.Font.GothamBold
QuirkPresetBtn.TextSize = 10
QuirkPresetBtn.Parent = PageQuirk
Instance.new("UICorner", QuirkPresetBtn).CornerRadius = UDim.new(0, 5)

local QuirkPickTargetBtn = Instance.new("TextButton")
QuirkPickTargetBtn.Size = UDim2.new(1, -6, 0, 24)
QuirkPickTargetBtn.Position = UDim2.new(0, 0, 0, 122)
QuirkPickTargetBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
QuirkPickTargetBtn.Text = "📝 Pick / Lock Specific Quirks (Modal)"
QuirkPickTargetBtn.TextColor3 = Color3.fromRGB(180, 200, 255)
QuirkPickTargetBtn.Font = Enum.Font.GothamBold
QuirkPickTargetBtn.TextSize = 10
QuirkPickTargetBtn.Parent = PageQuirk
Instance.new("UICorner", QuirkPickTargetBtn).CornerRadius = UDim.new(0, 5)

local QuirkSpeedBtn = Instance.new("TextButton")
QuirkSpeedBtn.Size = UDim2.new(1, -6, 0, 24)
QuirkSpeedBtn.Position = UDim2.new(0, 0, 0, 150)
QuirkSpeedBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
QuirkSpeedBtn.Text = "⚡ Speed: FAST (0.15s)"
QuirkSpeedBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
QuirkSpeedBtn.Font = Enum.Font.GothamBold
QuirkSpeedBtn.TextSize = 10
QuirkSpeedBtn.Parent = PageQuirk
Instance.new("UICorner", QuirkSpeedBtn).CornerRadius = UDim.new(0, 5)

local QuirkStatusLabel = Instance.new("TextLabel")
QuirkStatusLabel.Size = UDim2.new(1, -6, 0, 18)
QuirkStatusLabel.Position = UDim2.new(0, 0, 0, 178)
QuirkStatusLabel.BackgroundTransparency = 1
QuirkStatusLabel.Text = "Status: Idle"
QuirkStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
QuirkStatusLabel.Font = Enum.Font.Gotham
QuirkStatusLabel.TextSize = 10
QuirkStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
QuirkStatusLabel.Parent = PageQuirk

local ToggleQuirkBtn = Instance.new("TextButton")
ToggleQuirkBtn.Size = UDim2.new(1, -6, 0, 30)
ToggleQuirkBtn.Position = UDim2.new(0, 0, 0, 200)
ToggleQuirkBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
ToggleQuirkBtn.Text = "START AUTO REROLL"
ToggleQuirkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleQuirkBtn.Font = Enum.Font.GothamBold
ToggleQuirkBtn.TextSize = 11
ToggleQuirkBtn.Parent = PageQuirk
Instance.new("UICorner", ToggleQuirkBtn).CornerRadius = UDim.new(0, 6)

-- ====================================================================
-- TAB 4: SETTINGS PAGE
-- ====================================================================
local PageSettings = Instance.new("ScrollingFrame")
PageSettings.Size = UDim2.new(1, -16, 0, 180)
PageSettings.Position = UDim2.new(0, 8, 0, 66)
PageSettings.BackgroundTransparency = 1
PageSettings.BorderSizePixel = 0
PageSettings.ScrollBarThickness = 3
PageSettings.CanvasSize = UDim2.new(0, 0, 0, 306)
PageSettings.Visible = false
PageSettings.Parent = MainFrame

local CombatModeBtn = Instance.new("TextButton")
CombatModeBtn.Size = UDim2.new(1, -6, 0, 26)
CombatModeBtn.Position = UDim2.new(0, 0, 0, 0)
CombatModeBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 35)
CombatModeBtn.Text = "Combat Style: GROUND (บนพื้น) [ปกติ]"
CombatModeBtn.TextColor3 = Color3.fromRGB(120, 255, 120)
CombatModeBtn.Font = Enum.Font.GothamBold
CombatModeBtn.TextSize = 10
CombatModeBtn.Parent = PageSettings
Instance.new("UICorner", CombatModeBtn).CornerRadius = UDim.new(0, 5)

local AntiAfkBtn = Instance.new("TextButton")
AntiAfkBtn.Size = UDim2.new(1, -6, 0, 26)
AntiAfkBtn.Position = UDim2.new(0, 0, 0, 30)
AntiAfkBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 35)
AntiAfkBtn.Text = "Anti-AFK: ENABLED (ON)"
AntiAfkBtn.TextColor3 = Color3.fromRGB(120, 255, 120)
AntiAfkBtn.Font = Enum.Font.GothamBold
AntiAfkBtn.TextSize = 10
AntiAfkBtn.Parent = PageSettings
Instance.new("UICorner", AntiAfkBtn).CornerRadius = UDim.new(0, 5)

local BossPriorityBtn = Instance.new("TextButton")
BossPriorityBtn.Size = UDim2.new(1, -6, 0, 26)
BossPriorityBtn.Position = UDim2.new(0, 0, 0, 60)
BossPriorityBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 35)
BossPriorityBtn.Text = "Boss Priority (Lv.99): ON"
BossPriorityBtn.TextColor3 = Color3.fromRGB(120, 255, 120)
BossPriorityBtn.Font = Enum.Font.GothamBold
BossPriorityBtn.TextSize = 10
BossPriorityBtn.Parent = PageSettings
Instance.new("UICorner", BossPriorityBtn).CornerRadius = UDim.new(0, 5)

local AutoRejoinBtn = Instance.new("TextButton")
AutoRejoinBtn.Size = UDim2.new(1, -6, 0, 26)
AutoRejoinBtn.Position = UDim2.new(0, 0, 0, 90)
AutoRejoinBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
AutoRejoinBtn.Text = "Auto Rejoin: OFF (ยืนรอในเซิร์ฟ)"
AutoRejoinBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
AutoRejoinBtn.Font = Enum.Font.GothamBold
AutoRejoinBtn.TextSize = 10
AutoRejoinBtn.Parent = PageSettings
Instance.new("UICorner", AutoRejoinBtn).CornerRadius = UDim.new(0, 5)

local AutoStartBtn = Instance.new("TextButton")
AutoStartBtn.Size = UDim2.new(1, -6, 0, 26)
AutoStartBtn.Position = UDim2.new(0, 0, 0, 120)
AutoStartBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 40)
AutoStartBtn.Text = "Auto Start on Join: ENABLED (ON)"
AutoStartBtn.TextColor3 = Color3.fromRGB(120, 255, 150)
AutoStartBtn.Font = Enum.Font.GothamBold
AutoStartBtn.TextSize = 10
AutoStartBtn.Parent = PageSettings
Instance.new("UICorner", AutoStartBtn).CornerRadius = UDim.new(0, 5)

local HideDropsBtn = Instance.new("TextButton")
HideDropsBtn.Size = UDim2.new(1, -6, 0, 26)
HideDropsBtn.Position = UDim2.new(0, 0, 0, 150)
HideDropsBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
HideDropsBtn.Text = "Hide Drops: DISABLED (OFF - แสดงปกติ)"
HideDropsBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
HideDropsBtn.Font = Enum.Font.GothamBold
HideDropsBtn.TextSize = 10
HideDropsBtn.Parent = PageSettings
Instance.new("UICorner", HideDropsBtn).CornerRadius = UDim.new(0, 5)

do
    local hdBtn = Instance.new("TextButton")
    hdBtn.Size = UDim2.new(1, -6, 0, 26)
    hdBtn.Position = UDim2.new(0, 0, 0, 180)
    hdBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    hdBtn.Text = "Hide Damage: DISABLED (OFF - แสดงดาเมจ)"
    hdBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    hdBtn.Font = Enum.Font.GothamBold
    hdBtn.TextSize = 10
    hdBtn.Parent = PageSettings
    Instance.new("UICorner", hdBtn).CornerRadius = UDim.new(0, 5)
    OPT.HideDamageBtn = hdBtn

    local hseBtn = Instance.new("TextButton")
    hseBtn.Size = UDim2.new(1, -6, 0, 26)
    hseBtn.Position = UDim2.new(0, 0, 0, 210)
    hseBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    hseBtn.Text = "Hide Skill VFX: DISABLED (OFF - แสดงเอฟเฟค)"
    hseBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    hseBtn.Font = Enum.Font.GothamBold
    hseBtn.TextSize = 10
    hseBtn.Parent = PageSettings
    Instance.new("UICorner", hseBtn).CornerRadius = UDim.new(0, 5)
    OPT.HideSkillEffectsBtn = hseBtn

    local alert1PctBtn = Instance.new("TextButton")
    alert1PctBtn.Size = UDim2.new(1, -6, 0, 26)
    alert1PctBtn.Position = UDim2.new(0, 0, 0, 240)
    alert1PctBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 40)
    alert1PctBtn.Text = "1% Boss Alert: ENABLED (ON - แสดงบนหัว)"
    alert1PctBtn.TextColor3 = Color3.fromRGB(120, 255, 150)
    alert1PctBtn.Font = Enum.Font.GothamBold
    alert1PctBtn.TextSize = 10
    alert1PctBtn.Parent = PageSettings
    Instance.new("UICorner", alert1PctBtn).CornerRadius = UDim.new(0, 5)
    BossAlert.Button = alert1PctBtn

    local codesBtn = Instance.new("TextButton")
    codesBtn.Size = UDim2.new(1, -6, 0, 26)
    codesBtn.Position = UDim2.new(0, 0, 0, 270)
    codesBtn.BackgroundColor3 = Color3.fromRGB(70, 52, 110)
    codesBtn.Text = "🎁 เคลมโค้ดทั้งหมด (Redeem All Codes)"
    codesBtn.TextColor3 = Color3.fromRGB(235, 220, 255)
    codesBtn.Font = Enum.Font.GothamBold
    codesBtn.TextSize = 10
    codesBtn.Parent = PageSettings
    Instance.new("UICorner", codesBtn).CornerRadius = UDim.new(0, 5)
    OPT.CodesBtn = codesBtn
end

-- ====================================================================
-- TAB 5: INFO PAGE
-- ====================================================================
local PageInfo = Instance.new("Frame")
PageInfo.Size = UDim2.new(1, -16, 0, 180)
PageInfo.Position = UDim2.new(0, 8, 0, 66)
PageInfo.BackgroundTransparency = 1
PageInfo.Visible = false
PageInfo.Parent = MainFrame

InfoText = Instance.new("TextLabel")
InfoText.Size = UDim2.new(1, 0, 1, 0)
InfoText.BackgroundTransparency = 1
InfoText.Text = "Total Raids Won: 0\nTotal Mobs Cleared: 0\nCombat Style: GROUND (บนพื้น)\nZero-Delay Angry: ON (5-Hits)\nAnti-AFK: Active 24/7"
InfoText.TextColor3 = Color3.fromRGB(200, 200, 200)
InfoText.Font = Enum.Font.Gotham
InfoText.TextSize = 10
InfoText.TextYAlignment = Enum.TextYAlignment.Top
InfoText.Parent = PageInfo

-- ====================================================================
-- MODAL: POPUP MULTI-TIER SELECTOR (เลือกหลายระดับพร้อมกัน เช่น [D], [B])
-- ====================================================================
TierModal = Instance.new("Frame")
TierModal.Size = UDim2.new(1, -16, 0, 184)
TierModal.Position = UDim2.new(0, 8, 0, 66)
TierModal.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
TierModal.BorderSizePixel = 0
TierModal.Visible = false
TierModal.Active = true
TierModal.ZIndex = 20
TierModal.Parent = MainFrame
Instance.new("UICorner", TierModal).CornerRadius = UDim.new(0, 8)

local ModalTitle = Instance.new("TextLabel")
ModalTitle.Size = UDim2.new(1, -16, 0, 22)
ModalTitle.Position = UDim2.new(0, 8, 0, 4)
ModalTitle.BackgroundTransparency = 1
ModalTitle.Text = "🎯 เลือกระดับเรด (ติ๊กได้หลายระดับ เช่น D, B)"
ModalTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
ModalTitle.Font = Enum.Font.GothamBold
ModalTitle.TextSize = 11
ModalTitle.TextXAlignment = Enum.TextXAlignment.Left
ModalTitle.ZIndex = 21
ModalTitle.Parent = TierModal

local tierButtons = {}

local function updateTierButtonVisuals()
    local defs = getCurrentTierDefinitions()
    local tiers = getCurrentSelectedTiers()
    for i = 1, 10 do
        local btn = tierButtons[i]
        if btn and defs[i] then
            btn.Text = defs[i].name
            if tiers[i] then
                btn.BackgroundColor3 = Color3.fromRGB(45, 140, 60)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
                btn.TextColor3 = Color3.fromRGB(140, 140, 150)
            end
        end
    end
    TierSelector.Text = getSelectedTiersText()
    local curMap = getCurrentMapConfig()
    if curMap.isEvent then
        TierSelector.TextColor3 = Color3.fromRGB(180, 180, 180)
    else
        TierSelector.TextColor3 = Color3.fromRGB(255, 215, 0)
    end
end

local btnW, btnH = 48, 26
local startX, startY = 8, 30
local gapX, gapY = 5, 5

for i = 1, 10 do
    local row = (i <= 5) and 0 or 1
    local col = (i <= 5) and (i - 1) or (i - 6)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, btnW, 0, btnH)
    btn.Position = UDim2.new(0, startX + col * (btnW + gapX), 0, startY + row * (btnH + gapY))
    btn.BackgroundColor3 = Color3.fromRGB(45, 140, 60)
    btn.Text = NORMAL_TIER_DEFINITIONS[i].name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.ZIndex = 21
    btn.Parent = TierModal
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    btn.MouseButton1Click:Connect(function()
        local tiers = getCurrentSelectedTiers()
        tiers[i] = not tiers[i]
        updateTierButtonVisuals()
        saveBotState(isRaidRunning)
    end)

    tierButtons[i] = btn
end

-- แถวล่าง: ปุ่ม Select All, Clear, Done
local SelectAllBtn = Instance.new("TextButton")
SelectAllBtn.Size = UDim2.new(0, 78, 0, 26)
SelectAllBtn.Position = UDim2.new(0, 8, 0, 96)
SelectAllBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
SelectAllBtn.Text = "Select All"
SelectAllBtn.TextColor3 = Color3.fromRGB(140, 200, 255)
SelectAllBtn.Font = Enum.Font.GothamBold
SelectAllBtn.TextSize = 10
SelectAllBtn.ZIndex = 21
SelectAllBtn.Parent = TierModal
Instance.new("UICorner", SelectAllBtn).CornerRadius = UDim.new(0, 5)

SelectAllBtn.MouseButton1Click:Connect(function()
    local tiers = getCurrentSelectedTiers()
    for i = 1, 10 do tiers[i] = true end
    updateTierButtonVisuals()
    saveBotState(isRaidRunning)
end)

local ClearBtn = Instance.new("TextButton")
ClearBtn.Size = UDim2.new(0, 58, 0, 26)
ClearBtn.Position = UDim2.new(0, 91, 0, 96)
ClearBtn.BackgroundColor3 = Color3.fromRGB(50, 35, 35)
ClearBtn.Text = "Clear"
ClearBtn.TextColor3 = Color3.fromRGB(255, 140, 140)
ClearBtn.Font = Enum.Font.GothamBold
ClearBtn.TextSize = 10
ClearBtn.ZIndex = 21
ClearBtn.Parent = TierModal
Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(0, 5)

ClearBtn.MouseButton1Click:Connect(function()
    local tiers = getCurrentSelectedTiers()
    for i = 1, 10 do tiers[i] = false end
    updateTierButtonVisuals()
    saveBotState(isRaidRunning)
end)

local DoneBtn = Instance.new("TextButton")
DoneBtn.Size = UDim2.new(0, 112, 0, 26)
DoneBtn.Position = UDim2.new(0, 154, 0, 96)
DoneBtn.BackgroundColor3 = Color3.fromRGB(35, 120, 50)
DoneBtn.Text = "Done (เสร็จสิ้น)"
DoneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DoneBtn.Font = Enum.Font.GothamBold
DoneBtn.TextSize = 10
DoneBtn.ZIndex = 21
DoneBtn.Parent = TierModal
Instance.new("UICorner", DoneBtn).CornerRadius = UDim.new(0, 5)

DoneBtn.MouseButton1Click:Connect(function()
    TierModal.Visible = false
end)

local SelectedSummary = Instance.new("TextLabel")
SelectedSummary.Size = UDim2.new(1, -16, 0, 48)
SelectedSummary.Position = UDim2.new(0, 8, 0, 128)
SelectedSummary.BackgroundTransparency = 1
SelectedSummary.Text = "💡 ติ๊กเลือกระดับที่ต้องการ (เช่น D, B) ระบบจะตรวจจับและเลือกลงประตูที่เปิดให้อัตโนมัติ"
SelectedSummary.TextColor3 = Color3.fromRGB(170, 170, 180)
SelectedSummary.Font = Enum.Font.Gotham
SelectedSummary.TextSize = 9
SelectedSummary.TextWrapped = true
SelectedSummary.ZIndex = 21
SelectedSummary.Parent = TierModal

local function updateInfoStats()
    local cStyle = combatGroundMode and "GROUND (บนพื้น)" or "AIR (ลอยฟ้า)"
    local hDrops = hideDropsEnabled and "ON (ซ่อน)" or "OFF (แสดง)"
    local hDmg = (OPT and OPT.hideDamageEnabled) and "ON (ซ่อน)" or "OFF (แสดง)"
    local hVfx = (OPT and OPT.hideSkillEffectsEnabled) and "ON (ซ่อน)" or "OFF (แสดง)"
    local bAlert = (BossAlert and BossAlert.enabled) and "ON" or "OFF"
    InfoText.Text = string.format("Total Raids Won: %d\nTotal Mobs Cleared: %d\nCombat Style: %s\nHide Drops: %s | Dmg: %s | VFX: %s\n1%% Boss Alert: %s | Anti-AFK: 24/7", raidWinCount, mobKillCount, cStyle, hDrops, hDmg, hVfx, bAlert)
end

-- ====================================================================
-- สลับหน้าแท็บ (Tab Switching)
-- ====================================================================

-- ====================================================================
-- MODAL: POPUP QUIRK TARGET SELECTOR (เลือกและล็อค Quirks เป้าหมาย)
-- ====================================================================
local QuirkTargetModal = Instance.new("Frame")
local QM = {}
QuirkTargetModal.Size = UDim2.new(0, 280, 0, 250)
QuirkTargetModal.Position = UDim2.new(0.5, -140, 0.5, -125)
QuirkTargetModal.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
QuirkTargetModal.BorderSizePixel = 1
QuirkTargetModal.BorderColor3 = Color3.fromRGB(90, 70, 130)
QuirkTargetModal.Visible = false
QuirkTargetModal.ZIndex = 25
QuirkTargetModal.Parent = ScreenGui
Instance.new("UICorner", QuirkTargetModal).CornerRadius = UDim.new(0, 8)

local QModalTitle = Instance.new("TextLabel")
QModalTitle.Size = UDim2.new(1, -16, 0, 20)
QModalTitle.Position = UDim2.new(0, 8, 0, 6)
QModalTitle.BackgroundTransparency = 1
QModalTitle.Text = "🎯 Select Target Quirks (Auto-Stop)"
QModalTitle.TextColor3 = Color3.fromRGB(255, 215, 100)
QModalTitle.Font = Enum.Font.GothamBold
QModalTitle.TextSize = 11
QModalTitle.ZIndex = 26
QModalTitle.Parent = QuirkTargetModal

local QModalSub = Instance.new("TextLabel")
QModalSub.Size = UDim2.new(1, -16, 0, 14)
QModalSub.Position = UDim2.new(0, 8, 0, 26)
QModalSub.BackgroundTransparency = 1
QModalSub.Text = "💡 ระบบจะสุ่มเร็ว และหยุดทันทีที่ได้ Quirk ที่เลือกไว้"
QModalSub.TextColor3 = Color3.fromRGB(170, 170, 190)
QModalSub.Font = Enum.Font.Gotham
QModalSub.TextSize = 9
QModalSub.ZIndex = 26
QModalSub.Parent = QuirkTargetModal

QM.ActionFrame = Instance.new("Frame")
QM.ActionFrame.Size = UDim2.new(1, -16, 0, 22)
QM.ActionFrame.Position = UDim2.new(0, 8, 0, 42)
QM.ActionFrame.BackgroundTransparency = 1
QM.ActionFrame.ZIndex = 26
QM.ActionFrame.Parent = QuirkTargetModal

QM.MythicBtn = Instance.new("TextButton")
QM.MythicBtn.Size = UDim2.new(0.24, 0, 1, 0)
QM.MythicBtn.Position = UDim2.new(0, 0, 0, 0)
QM.MythicBtn.BackgroundColor3 = Color3.fromRGB(60, 45, 25)
QM.MythicBtn.Text = "🌟 Q5+"
QM.MythicBtn.TextColor3 = Color3.fromRGB(255, 200, 80)
QM.MythicBtn.Font = Enum.Font.GothamBold
QM.MythicBtn.TextSize = 9
QM.MythicBtn.ZIndex = 26
QM.MythicBtn.Parent = QM.ActionFrame
Instance.new("UICorner", QM.MythicBtn).CornerRadius = UDim.new(0, 4)

QM.LegBtn = Instance.new("TextButton")
QM.LegBtn.Size = UDim2.new(0.24, 0, 1, 0)
QM.LegBtn.Position = UDim2.new(0.25, 0, 0, 0)
QM.LegBtn.BackgroundColor3 = Color3.fromRGB(50, 35, 60)
QM.LegBtn.Text = "✨ Q4+"
QM.LegBtn.TextColor3 = Color3.fromRGB(220, 160, 255)
QM.LegBtn.Font = Enum.Font.GothamBold
QM.LegBtn.TextSize = 9
QM.LegBtn.ZIndex = 26
QM.LegBtn.Parent = QM.ActionFrame
Instance.new("UICorner", QM.LegBtn).CornerRadius = UDim.new(0, 4)

QM.AllBtn = Instance.new("TextButton")
QM.AllBtn.Size = UDim2.new(0.24, 0, 1, 0)
QM.AllBtn.Position = UDim2.new(0.50, 0, 0, 0)
QM.AllBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 35)
QM.AllBtn.Text = "Select All"
QM.AllBtn.TextColor3 = Color3.fromRGB(150, 255, 150)
QM.AllBtn.Font = Enum.Font.GothamBold
QM.AllBtn.TextSize = 9
QM.AllBtn.ZIndex = 26
QM.AllBtn.Parent = QM.ActionFrame
Instance.new("UICorner", QM.AllBtn).CornerRadius = UDim.new(0, 4)

QM.ClearBtn = Instance.new("TextButton")
QM.ClearBtn.Size = UDim2.new(0.24, 0, 1, 0)
QM.ClearBtn.Position = UDim2.new(0.75, 0, 0, 0)
QM.ClearBtn.BackgroundColor3 = Color3.fromRGB(55, 35, 35)
QM.ClearBtn.Text = "Clear"
QM.ClearBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
QM.ClearBtn.Font = Enum.Font.GothamBold
QM.ClearBtn.TextSize = 9
QM.ClearBtn.ZIndex = 26
QM.ClearBtn.Parent = QM.ActionFrame
Instance.new("UICorner", QM.ClearBtn).CornerRadius = UDim.new(0, 4)

QM.Scroll = Instance.new("ScrollingFrame")
QM.Scroll.Size = UDim2.new(1, -16, 0, 145)
QM.Scroll.Position = UDim2.new(0, 8, 0, 68)
QM.Scroll.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
QM.Scroll.BorderSizePixel = 0
QM.Scroll.ScrollBarThickness = 3
QM.Scroll.ZIndex = 26
QM.Scroll.Parent = QuirkTargetModal
Instance.new("UICorner", QM.Scroll).CornerRadius = UDim.new(0, 6)

QM.DoneBtn = Instance.new("TextButton")
QM.DoneBtn.Size = UDim2.new(1, -16, 0, 24)
QM.DoneBtn.Position = UDim2.new(0, 8, 0, 218)
QM.DoneBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
QM.DoneBtn.Text = "DONE (บันทึกเป้าหมาย)"
QM.DoneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
QM.DoneBtn.Font = Enum.Font.GothamBold
QM.DoneBtn.TextSize = 10
QM.DoneBtn.ZIndex = 26
QM.DoneBtn.Parent = QuirkTargetModal
Instance.new("UICorner", QM.DoneBtn).CornerRadius = UDim.new(0, 5)

QM.DoneBtn.MouseButton1Click:Connect(function()
    QuirkTargetModal.Visible = false
end)

local function switchTab(tabIndex)
    OPT.currentTab = tabIndex
    PageRaid.Visible = (tabIndex == 1)
    PageFarm.Visible = (tabIndex == 2)
    PageQuirk.Visible = (tabIndex == 3)
    PageSettings.Visible = (tabIndex == 4)
    PageInfo.Visible = (tabIndex == 5)
    TierModal.Visible = false
    QuirkTargetModal.Visible = false

    local activeBg = Color3.fromRGB(50, 55, 75)
    local inactiveBg = Color3.fromRGB(30, 30, 38)
    local activeTxt = Color3.fromRGB(255, 255, 255)
    local inactiveTxt = Color3.fromRGB(180, 180, 180)

    TabRaidBtn.BackgroundColor3 = (tabIndex == 1) and activeBg or inactiveBg
    TabRaidBtn.TextColor3 = (tabIndex == 1) and activeTxt or inactiveTxt

    TabFarmBtn.BackgroundColor3 = (tabIndex == 2) and activeBg or inactiveBg
    TabFarmBtn.TextColor3 = (tabIndex == 2) and activeTxt or inactiveTxt

    TabQuirkBtn.BackgroundColor3 = (tabIndex == 3) and activeBg or inactiveBg
    TabQuirkBtn.TextColor3 = (tabIndex == 3) and activeTxt or inactiveTxt

    TabSettingBtn.BackgroundColor3 = (tabIndex == 4) and activeBg or inactiveBg
    TabSettingBtn.TextColor3 = (tabIndex == 4) and activeTxt or inactiveTxt

    TabInfoBtn.BackgroundColor3 = (tabIndex == 5) and activeBg or inactiveBg
    TabInfoBtn.TextColor3 = (tabIndex == 5) and activeTxt or inactiveTxt
end

function OPT.setMinimized(collapsed)
    OPT.isMinimized = (collapsed == true)
    if OPT.isMinimized then
        TabBar.Visible = false
        PageRaid.Visible = false
        PageFarm.Visible = false
        PageQuirk.Visible = false
        PageSettings.Visible = false
        PageInfo.Visible = false
        TierModal.Visible = false
        QuirkTargetModal.Visible = false
        MainFrame.Size = UDim2.new(0, 165, 0, 30)
        if OPT.MinimizeBtn then
            OPT.MinimizeBtn.Text = "+"
            OPT.MinimizeBtn.BackgroundColor3 = Color3.fromRGB(48, 56, 78)
        end
    else
        MainFrame.Size = UDim2.new(0, 290, 0, 260)
        TabBar.Visible = true
        if OPT.MinimizeBtn then
            OPT.MinimizeBtn.Text = "—"
            OPT.MinimizeBtn.BackgroundColor3 = Color3.fromRGB(36, 38, 48)
        end
        switchTab(OPT.currentTab or 1)
    end
end

if OPT.MinimizeBtn then
    OPT.MinimizeBtn.MouseButton1Click:Connect(function()
        OPT.setMinimized(not OPT.isMinimized)
    end)
end

if UserInputService and UserInputService.InputBegan then
    local myGui = ScreenGui
    OPT.minKeyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not (myGui and myGui.Parent) then return end
        if gameProcessed or UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            OPT.setMinimized(not OPT.isMinimized)
        end
    end)
end

TabRaidBtn.MouseButton1Click:Connect(function() switchTab(1) end)
TabFarmBtn.MouseButton1Click:Connect(function() switchTab(2) end)
TabQuirkBtn.MouseButton1Click:Connect(function() switchTab(3) end)
TabSettingBtn.MouseButton1Click:Connect(function() switchTab(4) end)
TabInfoBtn.MouseButton1Click:Connect(function() switchTab(5) end)

-- ====================================================================
-- ฟังก์ชันอัปเดตปุ่ม & Event การคลิก (Native MouseButton1Click)
-- ====================================================================
local function updateAutoRejoinButtonVisuals()
    AutoRejoinBtn.Text = AUTO_REJOIN_MODES[autoRejoinIndex].name
    local mode = AUTO_REJOIN_MODES[autoRejoinIndex].mode
    if mode == "OFF" then
        AutoRejoinBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        AutoRejoinBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    elseif mode == "HOP" then
        AutoRejoinBtn.BackgroundColor3 = Color3.fromRGB(45, 40, 65)
        AutoRejoinBtn.TextColor3 = Color3.fromRGB(200, 150, 255)
    end
end

local function updateSelectors()
    local curMap = getCurrentMapConfig()
    if raidTypeIndex == 1 then
        TypeSelector.Text = "Mode: ⚔️ Normal Raid"
        TypeSelector.TextColor3 = Color3.fromRGB(100, 210, 255)
        TypeSelector.BackgroundColor3 = Color3.fromRGB(35, 42, 55)
    else
        TypeSelector.Text = "Mode: 🗼 Ascension Tower"
        TypeSelector.TextColor3 = Color3.fromRGB(255, 175, 80)
        TypeSelector.BackgroundColor3 = Color3.fromRGB(50, 35, 45)
    end
    MapSelector.Text = "Map: " .. curMap.name
    TierSelector.Text = getSelectedTiersText()
    if curMap.isEvent then
        TierSelector.TextColor3 = Color3.fromRGB(180, 180, 180)
    else
        TierSelector.TextColor3 = Color3.fromRGB(255, 215, 0)
    end
    updateTierButtonVisuals()
    updateAutoRejoinButtonVisuals()
end

TypeSelector.MouseButton1Click:Connect(function()
    raidTypeIndex = (raidTypeIndex == 1) and 2 or 1
    TierModal.Visible = false
    updateSelectors()
    saveBotState(isRaidRunning)
end)

MapSelector.MouseButton1Click:Connect(function()
    local list = getCurrentRaidList()
    local idx = getCurrentSelectedMapIndex() + 1
    if idx > #list then idx = 1 end
    setCurrentSelectedMapIndex(idx)
    TierModal.Visible = false
    updateSelectors()
    saveBotState(isRaidRunning)
end)

TierSelector.MouseButton1Click:Connect(function()
    local curMap = getCurrentMapConfig()
    if curMap.isEvent then return end
    TierModal.Visible = not TierModal.Visible
    if TierModal.Visible then
        updateTierButtonVisuals()
    end
end)

FarmFilterBtn.MouseButton1Click:Connect(function()
    farmFilterIndex = farmFilterIndex + 1
    if farmFilterIndex > #FARM_FILTER_MODES then farmFilterIndex = 1 end
    FarmFilterBtn.Text = FARM_FILTER_MODES[farmFilterIndex].name
end)

CombatModeBtn.MouseButton1Click:Connect(function()
    combatGroundMode = not combatGroundMode
    if combatGroundMode then
        CombatModeBtn.Text = "Combat Style: GROUND (บนพื้น) [ปกติ]"
        CombatModeBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 35)
        CombatModeBtn.TextColor3 = Color3.fromRGB(120, 255, 120)
        removeSafePlatform()
    else
        CombatModeBtn.Text = "Combat Style: AIR (ลอยฟ้า 4.5m)"
        CombatModeBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 75)
        CombatModeBtn.TextColor3 = Color3.fromRGB(130, 200, 255)
    end
    updateInfoStats()
end)

AntiAfkBtn.MouseButton1Click:Connect(function()
    antiAfkEnabled = not antiAfkEnabled
    AntiAfkBtn.Text = "Anti-AFK: " .. (antiAfkEnabled and "ENABLED (ON)" or "DISABLED (OFF)")
    AntiAfkBtn.BackgroundColor3 = antiAfkEnabled and Color3.fromRGB(35, 60, 35) or Color3.fromRGB(60, 35, 35)
    AntiAfkBtn.TextColor3 = antiAfkEnabled and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 120, 120)
end)

BossPriorityBtn.MouseButton1Click:Connect(function()
    bossPriorityEnabled = not bossPriorityEnabled
    BossPriorityBtn.Text = "Boss Priority (Lv.99): " .. (bossPriorityEnabled and "ON" or "OFF")
    BossPriorityBtn.BackgroundColor3 = bossPriorityEnabled and Color3.fromRGB(35, 60, 35) or Color3.fromRGB(60, 35, 35)
    BossPriorityBtn.TextColor3 = bossPriorityEnabled and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 120, 120)
end)

AutoRejoinBtn.MouseButton1Click:Connect(function()
    autoRejoinIndex = autoRejoinIndex + 1
    if autoRejoinIndex > #AUTO_REJOIN_MODES then autoRejoinIndex = 1 end
    updateAutoRejoinButtonVisuals()
    saveBotState(isRaidRunning)
end)

AutoStartBtn.MouseButton1Click:Connect(function()
    autoStartOnJoin = not autoStartOnJoin
    if autoStartOnJoin then
        AutoStartBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 40)
        AutoStartBtn.Text = "Auto Start on Join: ENABLED (ON)"
        AutoStartBtn.TextColor3 = Color3.fromRGB(120, 255, 150)
    else
        AutoStartBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        AutoStartBtn.Text = "Auto Start on Join: DISABLED (OFF)"
        AutoStartBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    end
    saveBotState(isRaidRunning)
end)

local function updateHideDropsButtonVisuals()
    if hideDropsEnabled then
        HideDropsBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 35)
        HideDropsBtn.Text = "Hide Drops: ENABLED (ON - ซ่อนของ)"
        HideDropsBtn.TextColor3 = Color3.fromRGB(120, 255, 120)
    else
        HideDropsBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        HideDropsBtn.Text = "Hide Drops: DISABLED (OFF - แสดงปกติ)"
        HideDropsBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    end
end

HideDropsBtn.MouseButton1Click:Connect(function()
    hideDropsEnabled = not hideDropsEnabled
    updateHideDropsButtonVisuals()
    applyDropVisibility()
    updateInfoStats()
    saveBotState(isRaidRunning)
end)

do
    function OPT.updateHideDamageVisuals()
        if not OPT.HideDamageBtn then return end
        if OPT.hideDamageEnabled then
            OPT.HideDamageBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 35)
            OPT.HideDamageBtn.Text = "Hide Damage: ENABLED (ON - ซ่อนดาเมจ)"
            OPT.HideDamageBtn.TextColor3 = Color3.fromRGB(120, 255, 120)
        else
            OPT.HideDamageBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            OPT.HideDamageBtn.Text = "Hide Damage: DISABLED (OFF - แสดงดาเมจ)"
            OPT.HideDamageBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end

    function OPT.clearDamagePopups()
        pcall(function()
            for _, fName in ipairs({ "Enemys", "RaidsEnemys", "Monsters", "Mobs", "Bosses" }) do
                local f = Workspace:FindFirstChild(fName)
                if f then
                    for _, desc in ipairs(f:GetDescendants()) do
                        if desc.Name == "AttackNum" then
                            desc:Destroy()
                        end
                    end
                end
            end
            if EnemyManager and EnemyManager.enemyEntitys then
                for _, ent in pairs(EnemyManager.enemyEntitys) do
                    local ch = ent and (ent.character or ent.model)
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        for _, child in ipairs(hrp:GetChildren()) do
                            if child.Name == "AttackNum" then
                                child:Destroy()
                            end
                        end
                    end
                end
            end
        end)
    end

    function OPT.ensureDamageHook()
        if OPT.damageHooked then return end
        local ee = safeRequire(function() return require(ReplicatedStorage.Scripts.Client.Manager.EnemyManager.EnemyEntity) end)
        if ee and type(ee.PlayHarmFloatingAnimal) == "function" then
            local raw = _G.__ariseOrigPlayHarm or ee.PlayHarmFloatingAnimal
            _G.__ariseOrigPlayHarm = raw
            local myGui = ScreenGui
            local optRef = OPT
            ee.PlayHarmFloatingAnimal = function(self, ...)
                if myGui and myGui.Parent and optRef.hideDamageEnabled then
                    return
                end
                return raw(self, ...)
            end
            OPT.damageHooked = true
        end
    end

    if OPT.HideDamageBtn then
        OPT.HideDamageBtn.MouseButton1Click:Connect(function()
            OPT.hideDamageEnabled = not OPT.hideDamageEnabled
            if OPT.hideDamageEnabled then
                OPT.ensureDamageHook()
                OPT.clearDamagePopups()
            end
            OPT.updateHideDamageVisuals()
            updateInfoStats()
            saveBotState(isRaidRunning)
        end)
    end

    function OPT.updateHideSkillEffectsVisuals()
        if not OPT.HideSkillEffectsBtn then return end
        if OPT.hideSkillEffectsEnabled then
            OPT.HideSkillEffectsBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 35)
            OPT.HideSkillEffectsBtn.Text = "Hide Skill VFX: ENABLED (ON - ซ่อนเอฟเฟค)"
            OPT.HideSkillEffectsBtn.TextColor3 = Color3.fromRGB(120, 255, 120)
        else
            OPT.HideSkillEffectsBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            OPT.HideSkillEffectsBtn.Text = "Hide Skill VFX: DISABLED (OFF - แสดงเอฟเฟค)"
            OPT.HideSkillEffectsBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end

    function OPT.clearSkillEffects()
        pcall(function()
            local container = Workspace:FindFirstChild("SkillEffectContainer")
            if container then
                container:ClearAllChildren()
            end
            for _, fName in ipairs({ "Enemys", "RaidsEnemys", "Monsters", "Mobs", "Bosses" }) do
                local f = Workspace:FindFirstChild(fName)
                if f then
                    for _, desc in ipairs(f:GetDescendants()) do
                        if desc.Name == "HitEffect" or desc.Name == "ClickAttackEffect" then
                            desc:Destroy()
                        end
                    end
                end
            end
        end)
    end

    function OPT.ensureSkillEffectsHook()
        local myGui = ScreenGui
        local optRef = OPT

        if not OPT.skillEffectsHooked then
            local hookedAny = false
            local ec = safeRequire(function() return require(ReplicatedStorage.Scripts.Client.EffectCtrl) end)
            if ec then
                if type(ec.PlaySkillEffect) == "function" then
                    local raw1 = _G.__ariseOrigPlaySkillEff1 or ec.PlaySkillEffect
                    _G.__ariseOrigPlaySkillEff1 = raw1
                    ec.PlaySkillEffect = function(...)
                        if myGui and myGui.Parent and optRef.hideSkillEffectsEnabled then
                            return
                        end
                        return raw1(...)
                    end
                    hookedAny = true
                end
                if type(ec.PlaySkillEffect2) == "function" then
                    local raw2 = _G.__ariseOrigPlaySkillEff2 or ec.PlaySkillEffect2
                    _G.__ariseOrigPlaySkillEff2 = raw2
                    ec.PlaySkillEffect2 = function(...)
                        if myGui and myGui.Parent and optRef.hideSkillEffectsEnabled then
                            return
                        end
                        return raw2(...)
                    end
                    hookedAny = true
                end
            end

            local ee = safeRequire(function() return require(ReplicatedStorage.Scripts.Client.Manager.EnemyManager.EnemyEntity) end)
            if ee and type(ee.emit) == "function" then
                local rawEmit = _G.__ariseOrigEnemyEmit or ee.emit
                _G.__ariseOrigEnemyEmit = rawEmit
                ee.emit = function(self, ...)
                    if myGui and myGui.Parent and optRef.hideSkillEffectsEnabled then
                        return
                    end
                    return rawEmit(self, ...)
                end
                hookedAny = true
            end

            if hookedAny then
                OPT.skillEffectsHooked = true
            end
        end

        local container = Workspace:FindFirstChild("SkillEffectContainer")
        if container and not OPT.secConn then
            OPT.secConn = container.ChildAdded:Connect(function(ch)
                if myGui and myGui.Parent and optRef.hideSkillEffectsEnabled then
                    task.defer(function() pcall(ch.Destroy, ch) end)
                end
            end)
        end
    end

    if OPT.HideSkillEffectsBtn then
        OPT.HideSkillEffectsBtn.MouseButton1Click:Connect(function()
            OPT.hideSkillEffectsEnabled = not OPT.hideSkillEffectsEnabled
            if OPT.hideSkillEffectsEnabled then
                OPT.ensureSkillEffectsHook()
                OPT.clearSkillEffects()
            end
            OPT.updateHideSkillEffectsVisuals()
            updateInfoStats()
            saveBotState(isRaidRunning)
        end)
    end

    if OPT.CodesBtn then
        OPT.CodesBtn.MouseButton1Click:Connect(function()
            if OPT.redeemingCodes then return end
            OPT.redeemingCodes = true
            OPT.CodesBtn.BackgroundColor3 = Color3.fromRGB(95, 70, 35)
            OPT.CodesBtn.Text = "⏳ กำลังเช็กโค้ด..."

            task.spawn(function()
                local ok, err = pcall(function()
                    ensureManagers()
                    local codeCfg = ConfigManager and ConfigManager.GetConfig and ConfigManager.GetConfig("Code")
                    if not codeCfg or not codeCfg.data then
                        OPT.CodesBtn.Text = "❌ ไม่พบข้อมูลโค้ดในเกม"
                        task.wait(2.5)
                        return
                    end

                    local usedSet = {}
                    local gc = PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.giftCodes
                    if type(gc) == "table" then
                        for k, v in pairs(gc) do
                            if type(v) == "number" or type(v) == "string" then usedSet[v] = true end
                            if type(k) == "number" and v == true then usedSet[k] = true end
                        end
                    end

                    local todo = {}
                    for _, row in pairs(codeCfg.data) do
                        if type(row) == "table" and row.IsOpen == 1 and row.Id then
                            if not usedSet[row.Id] and not usedSet[row.Code] then
                                table.insert(todo, row)
                            end
                        end
                    end
                    table.sort(todo, function(a, b) return (a.Id or 0) < (b.Id or 0) end)

                    if #todo == 0 then
                        OPT.CodesBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 45)
                        OPT.CodesBtn.Text = "✅ เคลมโค้ดเปิดอยู่ครบแล้ว!"
                        task.wait(2.5)
                        return
                    end

                    local okCount, dupCount = 0, 0
                    for i, row in ipairs(todo) do
                        if not (ScreenGui and ScreenGui.Parent) then break end
                        if i == 1 or i % 5 == 0 or i == #todo then
                            OPT.CodesBtn.Text = string.format("🎁 เคลมโค้ด %d/%d...", i, #todo)
                        end
                        local res = nil
                        pcall(function()
                            if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.GiftCodeReceived then
                                res = ProtocolManager.SendMessage(ProtocolManager.Protocols.GiftCodeReceived.Name, row.Id)
                            elseif Remotes and Remotes:FindFirstChild("GiftCodeReceived") then
                                res = Remotes.GiftCodeReceived:InvokeServer(row.Id)
                            end
                        end)
                        if res == 200 then
                            okCount = okCount + 1
                        elseif res == 403 then
                            dupCount = dupCount + 1
                        end
                        task.wait(0.08)
                    end

                    pcall(function()
                        if UIManager and UIManager.HidePanel then
                            UIManager.HidePanel("RewardPanel")
                            UIManager.HidePanel("TipsPanel")
                            UIManager.HidePanel("TipsFloatingPanel")
                        end
                        if hideDropsEnabled then dismissAllRewardPopups() end
                    end)

                    OPT.CodesBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 45)
                    OPT.CodesBtn.Text = string.format("✅ เสร็จ: ใหม่ +%d (ซ้ำ %d)", okCount, dupCount)
                    task.wait(3.0)
                end)

                if not ok and OPT.CodesBtn then
                    OPT.CodesBtn.BackgroundColor3 = Color3.fromRGB(120, 45, 45)
                    OPT.CodesBtn.Text = "❌ Error: " .. tostring(err):sub(1, 25)
                    task.wait(2.5)
                end

                OPT.redeemingCodes = false
                if OPT.CodesBtn then
                    OPT.CodesBtn.BackgroundColor3 = Color3.fromRGB(70, 52, 110)
                    OPT.CodesBtn.Text = "🎁 เคลมโค้ดทั้งหมด (Redeem All Codes)"
                end
            end)
        end)
    end
end

do
    local DB = OPT.db
    local dbMgrCache = nil
    local mapLabelCache = {}
    local function getDbMgr()
        if dbMgrCache then return dbMgrCache end
        pcall(function()
            local mod = ReplicatedStorage.Scripts.Client.LimitedActivity.DragonBall.DragonBallSpawnManager
            if mod then dbMgrCache = require(mod) end
        end)
        return dbMgrCache
    end

    local function formatMMSS(sec)
        local s = math.max(0, math.floor(tonumber(sec) or 0))
        return string.format("%02d:%02d", math.floor(s / 60), s % 60)
    end

    local function getMapLabel(mapId)
        if mapLabelCache[mapId] then
            return mapLabelCache[mapId]
        end
        local rawName = nil
        pcall(function()
            ensureManagers()
            if ConfigManager and ConfigManager.GetConfig then
                local cfg = ConfigManager.GetConfig("Map")
                local row = cfg and (cfg.TryGetDataById and cfg:TryGetDataById(mapId) or cfg:GetDataById(mapId))
                if row and row.MapName then
                    rawName = tostring(row.MapName)
                end
            end
        end)
        local label = "Map " .. tostring(mapId)
        if rawName and rawName ~= "" then
            local num, title = rawName:match("^(%d+)%s*,%s*(.+)$")
            if num and title then
                label = "Map " .. num .. " (" .. title .. ")"
            else
                label = rawName
            end
        end
        mapLabelCache[mapId] = label
        return label
    end

    local function isMapUnlocked(mapId)
        local unlocked = true
        pcall(function()
            ensureManagers()
            if PlayerManager and PlayerManager.localPlayerData and PlayerManager.localPlayerData.mapDatas then
                unlocked = false
                for _, md in pairs(PlayerManager.localPlayerData.mapDatas) do
                    if md and md.mapId == mapId then
                        unlocked = true
                        break
                    end
                end
            end
        end)
        return unlocked
    end

    local function getNextSpawnInfo()
        local now = Workspace:GetServerTimeNow()
        local nextWait = nil
        pcall(function()
            ensureManagers()
            if ConfigManager and ConfigManager.GetConfig then
                local actCfg = ConfigManager.GetConfig("LimitedActivity")
                local spCfg = ConfigManager.GetConfig("DragonBallSpawn")
                local act = actCfg and actCfg:TryGetDataById(DB.featureId)
                local sp = spCfg and spCfg:TryGetDataById(DB.featureId)
                if act and sp and act.Enabled == 1 and sp.Interval and sp.Interval > 0 then
                    if now < act.StartTime then
                        nextWait = act.StartTime - now
                    elseif now < act.EndTime then
                        local roundIdx = math.floor((now - act.StartTime) / sp.Interval) + 1
                        local nextAt = act.StartTime + roundIdx * sp.Interval
                        if nextAt < act.EndTime then
                            nextWait = math.max(0, nextAt - now)
                        end
                    end
                end
            end
        end)
        return nextWait
    end

    local function getCurMapIdSafe()
        local curId = nil
        pcall(function()
            ensureManagers()
            if MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo then
                curId = MapManager.currentMapData.mapSlotInfo.mapId
            end
        end)
        return curId
    end

    local function isInRaidNow()
        if isRaidRunning then return true end
        if RaidsManager and RaidsManager.raidsMapInfo then return true end
        local curId = getCurMapIdSafe()
        if curId == 50302 or curId == 50403 or (curId and curId >= 50100 and curId <= 50200) then
            return true
        end
        return false
    end

    function DB.updateAutoBtnVisuals()
        if not DB.AutoBtn then return end
        if DB.autoLoop then
            DB.AutoBtn.BackgroundColor3 = Color3.fromRGB(35, 65, 45)
            DB.AutoBtn.Text = "♻️ Auto Collect Loop: ON (เก็บอัตโนมัติ)"
            DB.AutoBtn.TextColor3 = Color3.fromRGB(120, 255, 160)
        else
            DB.AutoBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            DB.AutoBtn.Text = "♻️ Auto Collect Loop: OFF (รอกดเอง)"
            DB.AutoBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end

    function DB.updateCollectBtnVisuals()
        if not DB.CollectBtn then return end
        if DB.collecting then
            DB.CollectBtn.BackgroundColor3 = Color3.fromRGB(190, 55, 55)
            DB.CollectBtn.Text = "⏹️ Stop Collect"
        else
            DB.CollectBtn.BackgroundColor3 = Color3.fromRGB(210, 120, 30)
            DB.CollectBtn.Text = "🚀 Auto เก็บทั้งหมด"
        end
    end

    function DB.fetchSnap(force)
        pcall(ensureManagers)
        local mgr = getDbMgr()
        local cached = mgr and mgr.snapshots and mgr.snapshots[tostring(DB.featureId)]
        if cached and typeof(cached) == "table" and cached.success == true then
            if not DB.snap or (cached.roundId or 0) > (DB.snap.roundId or 0) or ((cached.roundId == DB.snap.roundId) and (cached.revision or 0) >= (DB.snap.revision or 0)) then
                DB.snap = cached
            end
        end

        local nowClk = os.clock()
        if not force and DB.snap and (nowClk - (DB.lastFetchAt or 0) < 3) then
            return DB.snap
        end
        if nowClk - (DB.lastFetchAt or 0) < 0.7 then
            return DB.snap
        end
        DB.lastFetchAt = nowClk

        local res = nil
        pcall(function()
            if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.GetDragonBallSpawnState then
                res = ProtocolManager.SendMessage(ProtocolManager.Protocols.GetDragonBallSpawnState.Name, DB.featureId)
            elseif Remotes and Remotes:FindFirstChild("GetDragonBallSpawnState") then
                res = Remotes.GetDragonBallSpawnState:InvokeServer(DB.featureId)
            end
        end)
        if typeof(res) == "table" and res.success == true then
            DB.snap = res
            pcall(function()
                if mgr and mgr.ApplySnapshot then
                    mgr.ApplySnapshot(res)
                end
            end)
        end
        return DB.snap
    end

    function DB.renderUI(customStatus)
        if not DB.StatusLabel or not DB.ListLabel then return end
        local snap = DB.snap
        local mgr = getDbMgr()
        local mgrSnap = mgr and mgr.snapshots and mgr.snapshots[tostring(DB.featureId)]
        if mgrSnap and typeof(mgrSnap) == "table" and mgrSnap.success == true then
            if not snap or (mgrSnap.roundId or 0) > (snap.roundId or 0) or ((mgrSnap.roundId == snap.roundId) and (mgrSnap.revision or 0) >= (snap.revision or 0)) then
                snap = mgrSnap
                DB.snap = mgrSnap
            end
        end

        local now = Workspace:GetServerTimeNow()
        local entries = (snap and snap.entries) or {}
        local isLive = snap and snap.isVisible == true and snap.expireAt and now < snap.expireAt and #entries > 0

        if customStatus then
            DB.StatusLabel.Text = customStatus
            DB.StatusLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
        elseif isLive then
            DB.StatusLabel.Text = string.format("🐉 รอบ #%d | เหลือ %d ลูก (อีก %s)", snap.roundId or 0, #entries, formatMMSS(snap.expireAt - now))
            DB.StatusLabel.TextColor3 = Color3.fromRGB(125, 255, 165)
        else
            local nextWait = getNextSpawnInfo()
            if snap and snap.isVisible == true and snap.expireAt and now < snap.expireAt and #entries == 0 then
                DB.StatusLabel.Text = string.format("✅ รอบ #%d เก็บครบแล้ว! รอรอบใหม่ %s", snap.roundId or 0, nextWait and formatMMSS(nextWait) or "--:--")
                DB.StatusLabel.TextColor3 = Color3.fromRGB(150, 230, 255)
            elseif nextWait then
                DB.StatusLabel.Text = string.format("⏳ รอเกิดรอบถัดไป: %s", formatMMSS(nextWait))
                DB.StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 110)
            else
                DB.StatusLabel.Text = "Radar: กด 🔍 Scan เพื่อดึงข้อมูลลูกแก้ว"
                DB.StatusLabel.TextColor3 = Color3.fromRGB(190, 225, 255)
            end
        end

        if not isLive then
            if snap and snap.counts then
                local parts = {}
                for star = 1, 7 do
                    local c = snap.counts[tostring(star)] or 0
                    if c > 0 then
                        table.insert(parts, star .. "★x" .. c)
                    end
                end
                local bagTxt = #parts > 0 and table.concat(parts, " ") or "ยังไม่มี"
                DB.ListLabel.Text = "• รอบนี้ไม่มีลูกแก้วค้างบนแมพ\n• ในกระเป๋า: " .. bagTxt
            else
                DB.ListLabel.Text = "• ยังไม่มีลูกแก้วเกิด (หรือยังไม่สแกน)"
            end
            return
        end

        local byMap = {}
        local mapIds = {}
        for _, e in ipairs(entries) do
            if e and e.mapId then
                if not byMap[e.mapId] then
                    byMap[e.mapId] = {}
                    table.insert(mapIds, e.mapId)
                end
                table.insert(byMap[e.mapId], e.starId or "?")
            end
        end
        table.sort(mapIds)

        local lines = {}
        for _, mId in ipairs(mapIds) do
            table.sort(byMap[mId], function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
            local starStrs = {}
            for _, st in ipairs(byMap[mId]) do
                if st == 7 then
                    table.insert(starStrs, "🌟7★")
                else
                    table.insert(starStrs, tostring(st) .. "★")
                end
            end
            local lockTag = isMapUnlocked(mId) and "" or " [🔒]"
            table.insert(lines, "• " .. getMapLabel(mId) .. lockTag .. ": " .. table.concat(starStrs, ", "))
        end
        DB.ListLabel.Text = table.concat(lines, "\n")
    end

    function DB.collectAll(isAuto)
        if DB.collecting then return end
        local snap = DB.fetchSnap(true)
        local now = Workspace:GetServerTimeNow()
        if not snap or not snap.isVisible or not snap.expireAt or now >= snap.expireAt or not snap.entries or #snap.entries == 0 then
            DB.renderUI("⏳ ยังไม่มีลูกแก้วให้เก็บในรอบนี้")
            return
        end

        if isAuto and isInRaidNow() then
            return
        end

        DB.collecting = true
        DB.updateCollectBtnVisuals()

        local okRun, errRun = pcall(function()
            if isFarmRunning then
                isFarmRunning = false
                if ToggleFarmBtn then
                    ToggleFarmBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                    ToggleFarmBtn.Text = "START ALL MAP FARM"
                end
                removeSafePlatform()
                if FarmStatusLabel then FarmStatusLabel.Text = "Status: Paused (Dragon Ball)" end
            end

            local startMapId = getCurMapIdSafe()
            local totalBalls = #snap.entries
            local collectedCount = 0

            local byMap = {}
            local mapOrder = {}
            for _, e in ipairs(snap.entries) do
                if e and e.mapId then
                    if not byMap[e.mapId] then
                        byMap[e.mapId] = {}
                        table.insert(mapOrder, e.mapId)
                    end
                    table.insert(byMap[e.mapId], e)
                end
            end
            table.sort(mapOrder, function(a, b)
                if a == startMapId then return true end
                if b == startMapId then return false end
                return a < b
            end)

            local mgr = getDbMgr()

            for _, targetMapId in ipairs(mapOrder) do
                if not DB.collecting then break end
                if not isMapUnlocked(targetMapId) then
                    DB.renderUI("⚠️ ข้าม " .. getMapLabel(targetMapId) .. " (ยังไม่ปลดล็อก)")
                    task.wait(0.6)
                else
                    if getCurMapIdSafe() ~= targetMapId then
                        DB.renderUI("🚀 กำลังวาร์ปไป " .. getMapLabel(targetMapId) .. "...")
                        teleportToMap(targetMapId)
                        local t0 = os.clock()
                        repeat
                            task.wait(0.15)
                        until not DB.collecting
                            or (os.clock() - t0 > 12)
                            or (getCurMapIdSafe() == targetMapId
                                and MapManager and MapManager.IsLoadFinish == true
                                and MapManager.currentMapData and MapManager.currentMapData.instance
                                and MapManager.currentMapData.instance:IsDescendantOf(Workspace)
                                and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
                        task.wait(0.75)
                    end

                    if DB.collecting and getCurMapIdSafe() == targetMapId then
                        local curInst = MapManager and MapManager.currentMapData and MapManager.currentMapData.instance
                        if curInst then
                            for _, entry in ipairs(byMap[targetMapId]) do
                                if not DB.collecting then break end
                                DB.renderUI(string.format("🐉 กำลังเก็บ %s★ ที่ %s...", tostring(entry.starId or "?"), getMapLabel(targetMapId)))
                                local worldPos = curInst:GetPivot():PointToWorldSpace(Vector3.new(entry.x, entry.y, entry.z))
                                local cRes = nil
                                for attempt = 1, 2 do
                                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                    if hrp then
                                        pcall(function()
                                            hrp.AssemblyLinearVelocity = Vector3.zero
                                            hrp.CFrame = CFrame.new(worldPos + Vector3.new(0, 3.5, 0))
                                        end)
                                        task.wait(0.25)
                                        if (hrp.Position - worldPos).Magnitude > 12 then
                                            pcall(function()
                                                hrp.AssemblyLinearVelocity = Vector3.zero
                                                hrp.CFrame = CFrame.new(worldPos + Vector3.new(0, 3.5, 0))
                                            end)
                                            task.wait(0.2)
                                        end
                                    end

                                    cRes = nil
                                    pcall(function()
                                        local payload = {
                                            featureId = DB.featureId,
                                            roundId = snap.roundId,
                                            slotId = entry.slotId,
                                        }
                                        if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.CollectDragonBall then
                                            cRes = ProtocolManager.SendMessage(ProtocolManager.Protocols.CollectDragonBall.Name, payload)
                                        elseif Remotes and Remotes:FindFirstChild("CollectDragonBall") then
                                            cRes = Remotes.CollectDragonBall:InvokeServer(payload)
                                        end
                                    end)
                                    if typeof(cRes) == "table" and cRes.success == true then
                                        break
                                    end
                                    if attempt == 1 and DB.collecting then
                                        task.wait(0.35)
                                    end
                                end

                                if typeof(cRes) == "table" then
                                    if cRes.snapshot then
                                        DB.snap = cRes.snapshot
                                        pcall(function()
                                            if mgr and mgr.ApplySnapshot then mgr.ApplySnapshot(cRes.snapshot) end
                                        end)
                                    end
                                    if cRes.success == true then
                                        collectedCount = collectedCount + 1
                                    elseif cRes.message then
                                        DB.renderUI("⚠️ " .. tostring(cRes.message))
                                    end
                                end
                                if hideDropsEnabled then
                                    dismissRewardPopups()
                                end
                                task.wait(0.25)
                            end
                        end
                    end
                end
            end

            local finishedClean = DB.collecting

            if startMapId and startMapId >= 50001 and startMapId <= 50030 and getCurMapIdSafe() ~= startMapId then
                DB.renderUI("🔙 กำลังวาร์ปกลับแมพเดิม...")
                teleportToMap(startMapId)
                task.wait(0.8)
            end

            if not finishedClean then
                DB.renderUI("⏹️ หยุดเก็บกลางคัน (ได้ " .. collectedCount .. "/" .. totalBalls .. " ลูก)")
            else
                DB.collecting = false
                task.wait(0.75)
                local postSnap = DB.fetchSnap(true)
                local remainingUnlocked = 0
                if postSnap and postSnap.isVisible == true and postSnap.roundId == snap.roundId and postSnap.entries then
                    for _, re in ipairs(postSnap.entries) do
                        if re and re.mapId and isMapUnlocked(re.mapId) then
                            remainingUnlocked = remainingUnlocked + 1
                        end
                    end
                end
                if remainingUnlocked == 0 then
                    DB.lastCollectedRound = snap.roundId
                    DB.retryCount = 0
                    DB.retryAfter = 0
                    DB.renderUI(string.format("✅ เก็บเสร็จแล้ว %d/%d ลูก (รอบ #%d)", collectedCount, totalBalls, snap.roundId or 0))
                else
                    if DB.retryRound ~= snap.roundId then
                        DB.retryRound = snap.roundId
                        DB.retryCount = 0
                    end
                    DB.retryCount = (DB.retryCount or 0) + 1
                    DB.retryAfter = os.clock() + 15
                    if DB.retryCount >= 6 then
                        DB.lastCollectedRound = snap.roundId
                    end
                    DB.renderUI(string.format("⚠️ เหลืออีก %d ลูก จะลองเก็บใหม่ใน 15s", remainingUnlocked))
                end
            end
        end)

        DB.collecting = false
        DB.updateCollectBtnVisuals()
        if not okRun then
            DB.renderUI("❌ ผิดพลาด: " .. tostring(errRun):sub(1, 45))
        end
    end

    if DB.ScanBtn then
        DB.ScanBtn.MouseButton1Click:Connect(function()
            task.spawn(function()
                DB.renderUI("🔍 กำลังสแกนลูกแก้ว...")
                DB.fetchSnap(true)
                DB.renderUI()
            end)
        end)
    end

    if DB.CollectBtn then
        DB.CollectBtn.MouseButton1Click:Connect(function()
            if DB.collecting then
                DB.collecting = false
                DB.updateCollectBtnVisuals()
                return
            end
            task.spawn(function()
                DB.collectAll(false)
            end)
        end)
    end

    if DB.AutoBtn then
        DB.AutoBtn.MouseButton1Click:Connect(function()
            DB.autoLoop = not DB.autoLoop
            DB.updateAutoBtnVisuals()
            saveBotState(isRaidRunning)
        end)
    end

    function DB.startLoop()
        if DB.loopStarted then return end
        DB.loopStarted = true
        task.spawn(function()
            task.wait(2.5)
            pcall(function() DB.fetchSnap(true) end)
            DB.renderUI()
            local tickCnt = 0
            while ScreenGui and ScreenGui.Parent do
                task.wait(1)
                tickCnt = tickCnt + 1
                if not DB.collecting then
                    if DB.autoLoop then
                        local now = Workspace:GetServerTimeNow()
                        if tickCnt % 6 == 0 then
                            pcall(function() DB.fetchSnap(false) end)
                        end
                        local snap = DB.snap
                        if snap and snap.isVisible == true and snap.expireAt and now < snap.expireAt and snap.entries and #snap.entries > 0 then
                            if DB.lastCollectedRound ~= snap.roundId and os.clock() >= (DB.retryAfter or 0) and not isInRaidNow() then
                                DB.collectAll(true)
                            end
                        end
                    end
                    if PageFarm and PageFarm.Visible then
                        if tickCnt % 8 == 0 then
                            pcall(function() DB.fetchSnap(false) end)
                        end
                        DB.renderUI()
                    end
                end
            end
        end)
    end
end

do
    function BossAlert.updateVisuals()
        if not BossAlert.Button then return end
        if BossAlert.enabled then
            BossAlert.Button.BackgroundColor3 = Color3.fromRGB(35, 60, 40)
            BossAlert.Button.Text = "1% Boss Alert: ENABLED (ON - แสดงบนหัว)"
            BossAlert.Button.TextColor3 = Color3.fromRGB(120, 255, 150)
        else
            BossAlert.Button.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            BossAlert.Button.Text = "1% Boss Alert: DISABLED (OFF - ปิด)"
            BossAlert.Button.TextColor3 = Color3.fromRGB(180, 180, 180)
            if BossAlert.billboard and BossAlert.billboard.Enabled then
                BossAlert.billboard.Enabled = false
            end
        end
    end

    function BossAlert.ensureBillboard()
        local char = LocalPlayer.Character
        local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
        if not head then return nil end

        if BossAlert.billboard and BossAlert.billboard.Parent == head then
            return BossAlert.billboard
        end

        if BossAlert.billboard then
            pcall(function() BossAlert.billboard:Destroy() end)
            BossAlert.billboard = nil
        end

        local existing = head:FindFirstChild("AriseBoss1PctAlert")
        if existing then
            pcall(function() existing:Destroy() end)
        end

        local bb = Instance.new("BillboardGui")
        bb.Name = "AriseBoss1PctAlert"
        bb.Size = UDim2.new(0, 195, 0, 42)
        bb.StudsOffset = Vector3.new(0, 3.5, 0)
        bb.AlwaysOnTop = true
        bb.Active = false
        bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        bb.Enabled = false
        bb.Parent = head

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
        frame.BackgroundTransparency = 0.15
        frame.BorderSizePixel = 0
        frame.Parent = bb
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(60, 60, 80)
        stroke.Thickness = 1.2
        stroke.Parent = frame
        BossAlert.stroke = stroke

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, -78, 0, 18)
        titleLbl.Position = UDim2.new(0, 6, 0, 3)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = "🎯 Boss 1% Tracker"
        titleLbl.TextColor3 = Color3.fromRGB(220, 220, 230)
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 10
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
        titleLbl.Parent = frame
        BossAlert.titleLabel = titleLbl

        local pctLbl = Instance.new("TextLabel")
        pctLbl.Size = UDim2.new(0, 70, 0, 18)
        pctLbl.Position = UDim2.new(1, -74, 0, 3)
        pctLbl.BackgroundTransparency = 1
        pctLbl.Text = "0.00% / 1%"
        pctLbl.TextColor3 = Color3.fromRGB(255, 215, 100)
        pctLbl.Font = Enum.Font.GothamBold
        pctLbl.TextSize = 10
        pctLbl.TextXAlignment = Enum.TextXAlignment.Right
        pctLbl.Parent = frame
        BossAlert.pctLabel = pctLbl

        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(1, -12, 0, 10)
        barBg.Position = UDim2.new(0, 6, 0, 24)
        barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
        barBg.BorderSizePixel = 0
        barBg.Parent = frame
        Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 4)

        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new(0, 0, 1, 0)
        barFill.BackgroundColor3 = Color3.fromRGB(255, 185, 50)
        barFill.BorderSizePixel = 0
        barFill.Parent = barBg
        Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 4)
        BossAlert.barFill = barFill

        BossAlert.billboard = bb
        BossAlert.mainFrame = frame
        return bb
    end

    function BossAlert.startLoop()
        task.spawn(function()
            while ScreenGui and ScreenGui.Parent do
                task.wait(0.12)
                if not BossAlert.enabled then
                    if BossAlert.billboard and BossAlert.billboard.Enabled then
                        BossAlert.billboard.Enabled = false
                    end
                    continue
                end

                local bb = BossAlert.ensureBillboard()
                if not bb then continue end

                local curGuid = BattleService and BattleService.attackEnemyGUID
                if not curGuid then
                    local pInst = PlayerManager and PlayerManager.PlayerInstances and PlayerManager.PlayerInstances[LocalPlayer.UserId]
                    curGuid = pInst and pInst.attackTarget
                    if type(curGuid) == "table" then
                        curGuid = curGuid.guid or (curGuid.data and curGuid.data.guid)
                    end
                end

                local ent = curGuid and EnemyManager and EnemyManager.enemyEntitys and EnemyManager.enemyEntitys[curGuid]
                local now = tick()

                if ent and ent.data then
                    local hp = tonumber(ent.data.hp)
                    local maxHp = tonumber(ent.data.maxHp)
                    local name = ent.data.name or (ent.character and ent.character.Name) or "Boss"

                    if maxHp and maxHp >= 1e7 and hp and hp > 0 then
                        if BossAlert.targetGuid ~= curGuid then
                            BossAlert.targetGuid = curGuid
                            BossAlert.targetName = name
                            BossAlert.targetMaxHp = maxHp
                            BossAlert.targetInitialHp = hp
                            BossAlert.reached1Pct = false
                        end

                        local totalDmg = maxHp - hp
                        local sessionDmg = (BossAlert.targetInitialHp or maxHp) - hp
                        local usedDmg = math.max(totalDmg, sessionDmg, 0)
                        local pct = (usedDmg / maxHp) * 100

                        bb.Enabled = true

                        if pct >= 1.0 then
                            if not BossAlert.reached1Pct then
                                BossAlert.reached1Pct = true
                                BossAlert.lastReachedGuid = curGuid
                                pcall(function()
                                    if SoundManager and SoundManager.PlaySound then
                                        SoundManager.PlaySound(SoundManager.soundType.Sound2D, 160022)
                                    end
                                end)
                            end

                            BossAlert.titleLabel.Text = "🎉 1% REACHED! (" .. tostring(name) .. ")"
                            BossAlert.titleLabel.TextColor3 = Color3.fromRGB(130, 255, 170)
                            BossAlert.pctLabel.Text = string.format("%.2f%%", pct)
                            BossAlert.pctLabel.TextColor3 = Color3.fromRGB(130, 255, 170)
                            BossAlert.barFill.Size = UDim2.new(1, 0, 1, 0)
                            BossAlert.barFill.BackgroundColor3 = Color3.fromRGB(60, 255, 130)
                            if BossAlert.stroke then
                                BossAlert.stroke.Color = Color3.fromRGB(70, 230, 140)
                            end
                            BossAlert.clearAt = now + 4.0
                        else
                            BossAlert.titleLabel.Text = "🎯 " .. tostring(name)
                            BossAlert.titleLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
                            BossAlert.pctLabel.Text = string.format("%.2f%% / 1%%", pct)
                            BossAlert.pctLabel.TextColor3 = Color3.fromRGB(255, 215, 110)
                            BossAlert.barFill.Size = UDim2.new(math.clamp(pct / 1.0, 0, 1), 0, 1, 0)
                            BossAlert.barFill.BackgroundColor3 = Color3.fromRGB(255, 185, 50)
                            if BossAlert.stroke then
                                BossAlert.stroke.Color = Color3.fromRGB(70, 70, 95)
                            end
                        end
                    else
                        if BossAlert.reached1Pct and now < (BossAlert.clearAt or 0) then
                            bb.Enabled = true
                        else
                            bb.Enabled = false
                        end
                    end
                else
                    if BossAlert.reached1Pct and now < (BossAlert.clearAt or 0) then
                        bb.Enabled = true
                    else
                        bb.Enabled = false
                    end
                end
            end
        end)
    end

    if BossAlert.Button then
        BossAlert.Button.MouseButton1Click:Connect(function()
            BossAlert.enabled = not BossAlert.enabled
            BossAlert.updateVisuals()
            updateInfoStats()
            saveBotState(isRaidRunning)
        end)
    end
end

-- ====================================================================

-- ====================================================================
-- ฟังก์ชันและการทำงานของหน้า Quirk & Equip Grade Auto-Reroll
-- ====================================================================
local function getQualityColor(score)
    if quirkTypeIndex == 3 then
        if score >= 10 then
            return Color3.fromRGB(255, 60, 120) -- M Transcendent (Pink/Magenta)
        elseif score == 9 then
            return Color3.fromRGB(80, 240, 255)  -- N Ethereal (Cyan)
        elseif score == 8 then
            return Color3.fromRGB(255, 70, 70)   -- G Primordial (Red)
        elseif score == 7 then
            return Color3.fromRGB(255, 120, 180) -- SS Celestial
        elseif score == 6 then
            return Color3.fromRGB(255, 190, 50)  -- S Mythic Gold
        elseif score == 5 then
            return Color3.fromRGB(200, 120, 255) -- A Legendary Purple
        elseif score == 4 then
            return Color3.fromRGB(80, 180, 255)  -- B Epic Blue
        elseif score == 3 then
            return Color3.fromRGB(80, 230, 200)  -- C Rare Cyan
        elseif score == 2 then
            return Color3.fromRGB(100, 230, 100) -- D Uncommon Green
        else
            return Color3.fromRGB(200, 200, 200) -- E Common White
        end
    else
        if score >= 6 then
            return Color3.fromRGB(255, 80, 80) -- Q6 Red/Cosmic
        elseif score == 5 then
            return Color3.fromRGB(255, 185, 50) -- Q5 Gold/Mythic
        elseif score == 4 then
            return Color3.fromRGB(200, 120, 255) -- Q4 Purple/Legendary
        elseif score == 3 then
            return Color3.fromRGB(80, 180, 255) -- Q3 Blue/Epic
        elseif score == 2 then
            return Color3.fromRGB(100, 230, 100) -- Q2 Green/Rare
        else
            return Color3.fromRGB(200, 200, 200) -- Q1 Common
        end
    end
end

local function syncNativeQuirkPanel()
    pcall(function()
        if UIManager and UIManager.panelDict then
            local slots = (quirkTypeIndex == 1 and HERO_QUIRK_SLOTS) or (quirkTypeIndex == 2 and WEAPON_QUIRK_SLOTS) or EQUIP_GRADE_SLOTS
            local drawId = slots[quirkSlotIndex].drawId
            local qlist = getQuirksForDraw(drawId)

            local panelName = (quirkTypeIndex == 1 and "QuirkNewPanel") or (quirkTypeIndex == 2 and "QuirkWeaponPanel") or "HeroEquipGradePanel"
            local panel = UIManager.panelDict[panelName]
            if panel and panel.autoSelect then
                for _, q in ipairs(qlist) do
                    panel.autoSelect[q.Id] = isTargetQuirk(q.Id, q)
                end
            end
        end
    end)
end

local function rebuildQuirkModalList()
    for _, ch in ipairs(QM.Scroll:GetChildren()) do
        if ch:IsA("GuiObject") then ch:Destroy() end
    end

    if quirkTypeIndex == 3 then
        QModalTitle.Text = "🛡️ Select Target Equip Grades (Auto-Stop)"
        QModalSub.Text = "💡 ระบบจะสุ่มเร็ว และหยุดทันทีที่ได้ Grade ที่เลือกไว้"
        QM.MythicBtn.Text = "👑 G+"
        QM.LegBtn.Text = "🌟 S+"
    else
        local typeName = (quirkTypeIndex == 1) and "Hero Quirks" or "Weapon Quirks"
        QModalTitle.Text = string.format("🎯 Select Target %s (Auto-Stop)", typeName)
        QModalSub.Text = "💡 ระบบจะสุ่มเร็ว และหยุดทันทีที่ได้ Quirk ที่เลือกไว้"
        QM.MythicBtn.Text = "🌟 Q5+"
        QM.LegBtn.Text = "✨ Q4+"
    end

    local slots = (quirkTypeIndex == 1 and HERO_QUIRK_SLOTS) or (quirkTypeIndex == 2 and WEAPON_QUIRK_SLOTS) or EQUIP_GRADE_SLOTS
    local drawId = slots[quirkSlotIndex].drawId
    local qlist = getQuirksForDraw(drawId)

    local rowH = 24
    local pad = 2
    for idx, q in ipairs(qlist) do
        local qId = q.Id
        local score = q.Score or q.Order or q.Quality or 1
        local isSelected = isTargetQuirk(qId, q)

        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -6, 0, rowH)
        row.Position = UDim2.new(0, 0, 0, (idx - 1) * (rowH + pad))
        row.BackgroundColor3 = isSelected and Color3.fromRGB(35, 50, 40) or Color3.fromRGB(24, 24, 30)
        row.Text = ""
        row.AutoButtonColor = false
        row.ZIndex = 27
        row.Parent = QM.Scroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

        local checkLbl = Instance.new("TextLabel")
        checkLbl.Size = UDim2.new(0, 22, 1, 0)
        checkLbl.Position = UDim2.new(0, 4, 0, 0)
        checkLbl.BackgroundTransparency = 1
        checkLbl.Text = isSelected and "[✓]" or "[  ]"
        checkLbl.TextColor3 = isSelected and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(140, 140, 140)
        checkLbl.Font = Enum.Font.GothamBold
        checkLbl.TextSize = 10
        checkLbl.ZIndex = 28
        checkLbl.Parent = row

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -30, 1, 0)
        nameLbl.Position = UDim2.new(0, 28, 0, 0)
        nameLbl.BackgroundTransparency = 1
        if quirkTypeIndex == 3 then
            nameLbl.Text = string.format("[%s] Grade %s (%s)", q.Name or "G", q.Name or "", q.Desc or "")
        else
            nameLbl.Text = string.format("[Q%d] %s (%s)", score, q.QuirksName or "", q.QuirksDes or "")
        end
        nameLbl.TextColor3 = getQualityColor(score)
        nameLbl.Font = Enum.Font.Gotham
        nameLbl.TextSize = 9
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.ZIndex = 28
        nameLbl.Parent = row

        row.MouseButton1Click:Connect(function()
            quirkPresetIndex = (quirkTypeIndex == 3) and 4 or 3 -- Switch to Custom
            quirkCustomTargets[qId] = not isSelected
            rebuildQuirkModalList()
            updateQuirkButtonVisuals()
            syncNativeQuirkPanel()
            saveBotState(isRaidRunning)
        end)
    end

    QM.Scroll.CanvasSize = UDim2.new(0, 0, 0, #qlist * (rowH + pad) + 4)
end

QM.MythicBtn.MouseButton1Click:Connect(function()
    quirkPresetIndex = (quirkTypeIndex == 3) and 4 or 3
    local slots = (quirkTypeIndex == 1 and HERO_QUIRK_SLOTS) or (quirkTypeIndex == 2 and WEAPON_QUIRK_SLOTS) or EQUIP_GRADE_SLOTS
    local drawId = slots[quirkSlotIndex].drawId
    local qlist = getQuirksForDraw(drawId)
    quirkCustomTargets = {}
    local threshold = (quirkTypeIndex == 3) and 8 or 5
    for _, q in ipairs(qlist) do
        local sc = q.Score or q.Order or q.Quality or 1
        if sc >= threshold then quirkCustomTargets[q.Id] = true end
    end
    rebuildQuirkModalList()
    updateQuirkButtonVisuals()
    syncNativeQuirkPanel()
    saveBotState(isRaidRunning)
end)

QM.LegBtn.MouseButton1Click:Connect(function()
    quirkPresetIndex = (quirkTypeIndex == 3) and 4 or 3
    local slots = (quirkTypeIndex == 1 and HERO_QUIRK_SLOTS) or (quirkTypeIndex == 2 and WEAPON_QUIRK_SLOTS) or EQUIP_GRADE_SLOTS
    local drawId = slots[quirkSlotIndex].drawId
    local qlist = getQuirksForDraw(drawId)
    quirkCustomTargets = {}
    local threshold = (quirkTypeIndex == 3) and 6 or 4
    for _, q in ipairs(qlist) do
        local sc = q.Score or q.Order or q.Quality or 1
        if sc >= threshold then quirkCustomTargets[q.Id] = true end
    end
    rebuildQuirkModalList()
    updateQuirkButtonVisuals()
    syncNativeQuirkPanel()
    saveBotState(isRaidRunning)
end)

QM.AllBtn.MouseButton1Click:Connect(function()
    quirkPresetIndex = (quirkTypeIndex == 3) and 4 or 3
    local slots = (quirkTypeIndex == 1 and HERO_QUIRK_SLOTS) or (quirkTypeIndex == 2 and WEAPON_QUIRK_SLOTS) or EQUIP_GRADE_SLOTS
    local drawId = slots[quirkSlotIndex].drawId
    local qlist = getQuirksForDraw(drawId)
    quirkCustomTargets = {}
    for _, q in ipairs(qlist) do
        quirkCustomTargets[q.Id] = true
    end
    rebuildQuirkModalList()
    updateQuirkButtonVisuals()
    syncNativeQuirkPanel()
    saveBotState(isRaidRunning)
end)

QM.ClearBtn.MouseButton1Click:Connect(function()
    quirkPresetIndex = (quirkTypeIndex == 3) and 4 or 3
    quirkCustomTargets = {}
    rebuildQuirkModalList()
    updateQuirkButtonVisuals()
    syncNativeQuirkPanel()
    saveBotState(isRaidRunning)
end)

function updateQuirkStatusLabels()
    local guid, entityName, curQId, curQName = getCurrentQuirkEntity()
    local count, slotData = getQuirkCoreCount()

    local countStr = tostring(count)
    if count >= 1000000 then
        countStr = string.format("%.1fM", count / 1000000)
    elseif count >= 1000 then
        countStr = string.format("%.1fK", count / 1000)
    end

    local typeName = (quirkTypeIndex == 1) and "Hero" or (quirkTypeIndex == 2 and "Weapon" or "Equip")
    QuirkHeroLabel.Text = string.format("%s: %s | Cur: %s", typeName, entityName, curQName)
    QuirkCoreLabel.Text = string.format("Available: %s x%s", slotData.short, countStr)
end

function updateQuirkButtonVisuals()
    if quirkTypeIndex == 1 then
        QuirkTypeBtn.Text = "🔮 Mode: 👤 Hero Quirk"
        QuirkTypeBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
        QuirkTypeBtn.TextColor3 = Color3.fromRGB(220, 170, 255)
    elseif quirkTypeIndex == 2 then
        QuirkTypeBtn.Text = "🔮 Mode: ⚔️ Weapon Quirk"
        QuirkTypeBtn.BackgroundColor3 = Color3.fromRGB(35, 50, 60)
        QuirkTypeBtn.TextColor3 = Color3.fromRGB(150, 220, 255)
    else
        QuirkTypeBtn.Text = "🔮 Mode: 🛡️ Equip Grade"
        QuirkTypeBtn.BackgroundColor3 = Color3.fromRGB(60, 45, 30)
        QuirkTypeBtn.TextColor3 = Color3.fromRGB(255, 205, 120)
    end

    local slots = (quirkTypeIndex == 1 and HERO_QUIRK_SLOTS) or (quirkTypeIndex == 2 and WEAPON_QUIRK_SLOTS) or EQUIP_GRADE_SLOTS
    local slotData = slots[quirkSlotIndex] or slots[1]
    QuirkSlotBtn.Text = "📍 Slot: " .. slotData.name
    
    local presets = (quirkTypeIndex == 3) and GRADE_PRESET_MODES or QUIRK_PRESET_MODES
    local curPreset = presets[quirkPresetIndex] or presets[1]
    QuirkPresetBtn.Text = curPreset.name
    QuirkSpeedBtn.Text = QUIRK_SPEED_MODES[quirkSpeedIndex].name

    if isQuirkRunning then
        ToggleQuirkBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        ToggleQuirkBtn.Text = "STOP AUTO REROLL"
    else
        ToggleQuirkBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        ToggleQuirkBtn.Text = "START AUTO REROLL"
    end

    updateQuirkStatusLabels()
end

QuirkTypeBtn.MouseButton1Click:Connect(function()
    quirkTypeIndex = quirkTypeIndex + 1
    if quirkTypeIndex > 3 then quirkTypeIndex = 1 end
    quirkSlotIndex = 1
    quirkPresetIndex = 1
    quirkCustomTargets = {}
    updateQuirkButtonVisuals()
    syncNativeQuirkPanel()
    saveBotState(isRaidRunning)
end)

QuirkSlotBtn.MouseButton1Click:Connect(function()
    quirkSlotIndex = quirkSlotIndex + 1
    if quirkSlotIndex > 3 then quirkSlotIndex = 1 end
    updateQuirkButtonVisuals()
    syncNativeQuirkPanel()
    saveBotState(isRaidRunning)
end)

QuirkPresetBtn.MouseButton1Click:Connect(function()
    local presets = (quirkTypeIndex == 3) and GRADE_PRESET_MODES or QUIRK_PRESET_MODES
    quirkPresetIndex = quirkPresetIndex + 1
    if quirkPresetIndex > #presets then quirkPresetIndex = 1 end
    updateQuirkButtonVisuals()
    syncNativeQuirkPanel()
    saveBotState(isRaidRunning)
end)

QuirkSpeedBtn.MouseButton1Click:Connect(function()
    quirkSpeedIndex = quirkSpeedIndex + 1
    if quirkSpeedIndex > #QUIRK_SPEED_MODES then quirkSpeedIndex = 1 end
    updateQuirkButtonVisuals()
    saveBotState(isRaidRunning)
end)

QuirkPickTargetBtn.MouseButton1Click:Connect(function()
    rebuildQuirkModalList()
    QuirkTargetModal.Visible = not QuirkTargetModal.Visible
end)

local function autoQuirkLoop()
    quirkRollCount = 0
    QuirkStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    local modeTitle = (quirkTypeIndex == 3 and "Equip Grade" or (quirkTypeIndex == 2 and "Weapon Quirk" or "Hero Quirk"))
    QuirkStatusLabel.Text = string.format("Status: Starting %s Auto-Reroll...", modeTitle)

    while isQuirkRunning do
        ensureManagers()
        local entityGuid, entityName, curQId, curQName = getCurrentQuirkEntity()
        if not entityGuid then
            QuirkStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            if quirkTypeIndex == 3 then
                QuirkStatusLabel.Text = "Status: ❌ Please select Hero Equip in Grade Menu!"
            else
                QuirkStatusLabel.Text = "Status: ❌ Please select Hero/Weapon in Quirk Menu!"
            end
            isQuirkRunning = false
            updateQuirkButtonVisuals()
            break
        end

        local coreCount, slotData = getQuirkCoreCount()
        if coreCount < 1 then
            QuirkStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            QuirkStatusLabel.Text = string.format("Status: ❌ Out of %s! Stopped.", slotData.short)
            pcall(function()
                if SoundManager and SoundManager.PlaySound then
                    SoundManager.PlaySound(SoundManager.soundType.Sound2D, 160022)
                end
            end)
            isQuirkRunning = false
            updateQuirkButtonVisuals()
            break
        end

        local drawId = slotData.drawId

        -- ตรวจสอบ Gamepass การสุ่ม 100x (AutoRandomHeroQuirk / AutoRandomWeaponQuirk / AutoRandomHeroEquipGrade)
        local multiCount = 1
        pcall(function()
            if PlayerManager and PlayerManager.propSystem and PlayerManager.propSystem.GetPropValue then
                local propId = (quirkTypeIndex == 1 and 30) or (quirkTypeIndex == 2 and 32) or 34
                multiCount = math.floor(PlayerManager.propSystem:GetPropValue(propId) or 1)
            end
        end)
        local isBatch100 = (multiCount > 1)

        -- รวบรวม Quirk / Grade เป้าหมายที่เลือกไว้ เพื่อส่งเป็น stopQuirkIds / stopGradeIds ให้ Server
        local stopQuirkIds = {}
        local qlist = getQuirksForDraw(drawId)
        for _, q in ipairs(qlist) do
            if isTargetQuirk(q.Id, q) then
                table.insert(stopQuirkIds, q.Id)
            end
        end
        if #stopQuirkIds == 0 then
            for _, q in ipairs(qlist) do
                local sc = q.Score or q.Order or q.Quality or 1
                local th = (quirkTypeIndex == 3) and 8 or 5
                if sc >= th then table.insert(stopQuirkIds, q.Id) end
            end
        end

        local rolledResult = nil

        -- ยิงคำสั่งสุ่ม Quirk / Grade
        pcall(function()
            if isBatch100 then
                -- โหมด 100x Gamepass: สุ่มทีละ 100 อันผ่าน AutoRandom Server API
                if quirkTypeIndex == 1 then
                    if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.AutoRandomHeroQuirk then
                        rolledResult = ProtocolManager.SendMessage(ProtocolManager.Protocols.AutoRandomHeroQuirk.Name, {
                            heroGuid = entityGuid,
                            drawId = drawId,
                            stopQuirkIds = stopQuirkIds
                        })
                    elseif Remotes and Remotes.AutoRandomHeroQuirk then
                        rolledResult = Remotes.AutoRandomHeroQuirk:InvokeServer({
                            heroGuid = entityGuid,
                            drawId = drawId,
                            stopQuirkIds = stopQuirkIds
                        })
                    end
                elseif quirkTypeIndex == 2 then
                    if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.AutoRandomWeaponQuirk then
                        rolledResult = ProtocolManager.SendMessage(ProtocolManager.Protocols.AutoRandomWeaponQuirk.Name, {
                            guid = entityGuid,
                            drawId = drawId,
                            stopQuirkIds = stopQuirkIds
                        })
                    elseif Remotes and Remotes.AutoRandomWeaponQuirk then
                        rolledResult = Remotes.AutoRandomWeaponQuirk:InvokeServer({
                            guid = entityGuid,
                            drawId = drawId,
                            stopQuirkIds = stopQuirkIds
                        })
                    end
                else
                    -- Equip Grade (AutoRandomHeroEquipGrade)
                    if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.AutoRandomHeroEquipGrade then
                        rolledResult = ProtocolManager.SendMessage(ProtocolManager.Protocols.AutoRandomHeroEquipGrade.Name, {
                            guid = entityGuid,
                            drawId = drawId,
                            stopGradeIds = stopQuirkIds
                        })
                    elseif Remotes and Remotes.AutoRandomHeroEquipGrade then
                        rolledResult = Remotes.AutoRandomHeroEquipGrade:InvokeServer({
                            guid = entityGuid,
                            drawId = drawId,
                            stopGradeIds = stopQuirkIds
                        })
                    end
                end
            else
                -- โหมดสุ่มทีละ 1 ชิ้นปกติ
                if quirkTypeIndex == 1 then
                    if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.RandomHeroQuirk then
                        rolledResult = ProtocolManager.SendMessage(ProtocolManager.Protocols.RandomHeroQuirk.Name, {
                            heroGuid = entityGuid,
                            drawId = drawId
                        })
                    elseif Remotes and Remotes.RandomHeroQuirk then
                        rolledResult = Remotes.RandomHeroQuirk:InvokeServer({
                            heroGuid = entityGuid,
                            drawId = drawId
                        })
                    end
                elseif quirkTypeIndex == 2 then
                    if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.RandomWeaponQuirk then
                        rolledResult = ProtocolManager.SendMessage(ProtocolManager.Protocols.RandomWeaponQuirk.Name, {
                            guid = entityGuid,
                            drawId = drawId
                        })
                    elseif Remotes and Remotes.RandomWeaponQuirk then
                        rolledResult = Remotes.RandomWeaponQuirk:InvokeServer({
                            guid = entityGuid,
                            drawId = drawId
                        })
                    end
                else
                    -- Equip Grade (RandomHeroEquipGrade)
                    if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.RandomHeroEquipGrade then
                        rolledResult = ProtocolManager.SendMessage(ProtocolManager.Protocols.RandomHeroEquipGrade.Name, {
                            guid = entityGuid,
                            drawId = drawId
                        })
                    elseif Remotes and Remotes.RandomHeroEquipGrade then
                        rolledResult = Remotes.RandomHeroEquipGrade:InvokeServer({
                            guid = entityGuid,
                            drawId = drawId
                        })
                    end
                end
            end
        end)

        local rolledId = rolledResult and ((rolledResult.data and rolledResult.data.grade) or rolledResult.finalResultId or rolledResult.quirkId)

        if rolledResult and rolledId then
            local countThisBatch = (rolledResult.gradeIds and #rolledResult.gradeIds) or (rolledResult.quirkIds and #rolledResult.quirkIds) or 1
            quirkRollCount = quirkRollCount + countThisBatch

            -- อัปเดตข้อมูลตัวละครและ Quirk / Grade ใน Client ทันที
            pcall(function()
                if quirkTypeIndex == 1 then
                    if PlayerManager.localPlayerData and PlayerManager.localPlayerData.heros and PlayerManager.localPlayerData.heros[entityGuid] then
                        local heroData = PlayerManager.localPlayerData.heros[entityGuid]
                        if not heroData.quirks then heroData.quirks = {} end
                        heroData.quirks[quirkSlotIndex] = rolledId
                        if heroData.isEquip and PlayerManager.UpdateProp then
                            PlayerManager.UpdateProp("heroQuirk", nil, true)
                        end
                    end
                elseif quirkTypeIndex == 2 then
                    if PlayerManager.localPlayerData and PlayerManager.localPlayerData.weapons and PlayerManager.localPlayerData.weapons[entityGuid] then
                        local wData = PlayerManager.localPlayerData.weapons[entityGuid]
                        if not wData.quirks then wData.quirks = {} end
                        wData.quirks[quirkSlotIndex] = rolledId
                        if wData.isEquip and PlayerManager.UpdateProp then
                            PlayerManager.UpdateProp("weaponQuirk", nil, true)
                        end
                    end
                else
                    if PlayerManager.localPlayerData and PlayerManager.localPlayerData.heroEquips and PlayerManager.localPlayerData.heroEquips[entityGuid] then
                        if rolledResult.data then
                            PlayerManager.localPlayerData.heroEquips[entityGuid] = rolledResult.data
                        else
                            PlayerManager.localPlayerData.heroEquips[entityGuid].grade = rolledId
                        end
                        if PlayerManager.UpdateProp then
                            PlayerManager.UpdateProp("heroEquip", nil, true)
                        end
                    end
                end

                -- อัปเดต Pity / Fallbacks
                if rolledResult.fallbacks and PlayerManager.localPlayerData and PlayerManager.localPlayerData.fallbacks then
                    for k, v in pairs(rolledResult.fallbacks) do
                        PlayerManager.localPlayerData.fallbacks[k] = v
                    end
                end

                -- อัปเดต Panel เกมถ้าเปิดอยู่บนจอ ให้แสดง Quirk, Pity และจำนวน Core/Stone ล่าสุดทันที
                if UIManager and UIManager.panelDict then
                    local qp = UIManager.panelDict["QuirkNewPanel"]
                    if qp and qp.panelInstance and qp.panelInstance.Enabled then
                        if qp.UpdateHeroCell and qp.selectHeroBtn then
                            pcall(function() qp:UpdateHeroCell(qp.selectHeroBtn.HeroFrame, PlayerManager.localPlayerData.heros[entityGuid]) end)
                        end
                        if qp.UpdateProgressFrame then pcall(function() qp:UpdateProgressFrame() end) end
                        if qp.UpdateItemFrame then pcall(function() qp:UpdateItemFrame() end) end
                    end
                    local wp = UIManager.panelDict["QuirkWeaponPanel"]
                    if wp and wp.panelInstance and wp.panelInstance.Enabled then
                        if wp.UpdateWeaponCell and wp.selectWeaponBtn then
                            pcall(function() wp:UpdateWeaponCell(wp.selectWeaponBtn.WeaponFrame, PlayerManager.localPlayerData.weapons[entityGuid]) end)
                        end
                        if wp.UpdateProgressFrame then pcall(function() wp:UpdateProgressFrame() end) end
                        if wp.UpdateItemFrame then pcall(function() wp:UpdateItemFrame() end) end
                    end
                    local hp = UIManager.panelDict["HeroEquipGradePanel"]
                    if hp and hp.panelInstance and hp.panelInstance.Enabled then
                        if hp.UpdateSelectFrame then pcall(function() hp:UpdateSelectFrame() end) end
                        if hp.UpdateHeroEquipList then pcall(function() hp:UpdateHeroEquipList() end) end
                        if hp.UpdateItemFrame then pcall(function() hp:UpdateItemFrame() end) end
                        if hp.UpdateProgressFrame then pcall(function() hp:UpdateProgressFrame() end) end
                    end
                end
            end)

            -- ค้นหาข้อมูล Quirk / Grade ที่สุ่มได้
            local qCfg = nil
            if quirkTypeIndex == 3 then
                pcall(function()
                    if ConfigManager and ConfigManager.GetConfig then
                        qCfg = ConfigManager.GetConfig("HeroEquipGrade"):GetDataById(rolledId)
                    end
                end)
                if not qCfg and STATIC_EQUIP_GRADE_POOLS[drawId] then
                    for _, sg in ipairs(STATIC_EQUIP_GRADE_POOLS[drawId]) do
                        if sg.Id == rolledId then qCfg = sg break end
                    end
                end
            else
                pcall(function()
                    if ConfigManager and ConfigManager.GetConfig then
                        qCfg = ConfigManager.GetConfig("QuirksNew"):GetDataById(rolledId)
                    end
                end)
                if not qCfg and STATIC_QUIRK_POOLS[drawId] then
                    for _, sq in ipairs(STATIC_QUIRK_POOLS[drawId]) do
                        if sq.Id == rolledId then qCfg = sq break end
                    end
                end
            end

            local qName = ""
            local qScore = (qCfg and (qCfg.Score or qCfg.Order or qCfg.Quality)) or 1
            if quirkTypeIndex == 3 then
                qName = (qCfg and qCfg.Name) and ("Grade " .. qCfg.Name .. string.format(" (x%d%%)", qCfg.Scale or 100)) or ("Grade " .. tostring(rolledId))
            else
                qName = (qCfg and qCfg.QuirksName) or ("Quirk " .. tostring(rolledId))
            end

            -- ตรวจสอบเงื่อนไขว่าตรงกับ Quirk / Grade ที่ล็อคไว้หรือไม่
            local isHitTarget = isTargetQuirk(rolledId, qCfg)

            updateQuirkStatusLabels()

            if isHitTarget then
                -- สำเร็จ! ได้เป้าหมาย หยุดทันที 100% ไม่สุ่มต่อ
                isQuirkRunning = false
                QuirkStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                if quirkTypeIndex == 3 then
                    QuirkStatusLabel.Text = string.format("🎉 WON: %s! [Total Rolls: %d]", qName, quirkRollCount)
                else
                    QuirkStatusLabel.Text = string.format("🎉 WON: %s (Q%d)! [Total Rolls: %d]", qName, qScore, quirkRollCount)
                end
                pcall(function()
                    if SoundManager and SoundManager.PlaySound then
                        SoundManager.PlaySound(SoundManager.soundType.Sound2D, 160021)
                    end
                end)
                updateQuirkButtonVisuals()
                break
            else
                QuirkStatusLabel.TextColor3 = Color3.fromRGB(220, 220, 150)
                if isBatch100 then
                    QuirkStatusLabel.Text = string.format("Rolling [100x] (#%d): %s...", quirkRollCount, qName)
                else
                    QuirkStatusLabel.Text = string.format("Rolling (#%d): %s...", quirkRollCount, qName)
                end
            end
        else
            task.wait(0.2)
        end

        local delaySec = QUIRK_SPEED_MODES[quirkSpeedIndex] and QUIRK_SPEED_MODES[quirkSpeedIndex].delay or 0.15
        task.wait(delaySec)
    end

    if not isQuirkRunning and not QuirkStatusLabel.Text:find("WON") and not QuirkStatusLabel.Text:find("Out of") then
        QuirkStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        QuirkStatusLabel.Text = "Status: Stopped"
    end
    updateQuirkButtonVisuals()
end

ToggleQuirkBtn.MouseButton1Click:Connect(function()
    isQuirkRunning = not isQuirkRunning
    if isQuirkRunning then
        if isRaidRunning then
            isRaidRunning = false
            ToggleRaidBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            ToggleRaidBtn.Text = "START AUTO RAID"
            RaidStatusLabel.Text = "Status: Idle"
        end
        if isFarmRunning then
            isFarmRunning = false
            ToggleFarmBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            ToggleFarmBtn.Text = "START ALL MAP FARM"
            FarmStatusLabel.Text = "Status: Idle"
        end
        syncNativeQuirkPanel()
        updateQuirkButtonVisuals()
        task.spawn(autoQuirkLoop)
    else
        updateQuirkButtonVisuals()
    end
end)

-- ลูปทำงาน: ตีมอนทั้งแมพ (Auto Farm All Mobs Loop)
-- ====================================================================
local function autoFarmMapLoop()
    removeSafePlatform()
    local lastSeenGuids = {}
    local candidateIndex = 1
    local lockedFarmGuid = nil
    local lockedFarmLastHp = nil
    local lockedFarmLastHpDropAt = 0
    local farmDeadGhostGuids = {}
    local farmStuckCooldownUntil = {}
    local farmStuckFailCount = {}
    local serverConfirmedAlive = {}
    local lastServerAcceptedClickGuid = nil

    while isFarmRunning do
        ensureManagers()
        if hideDropsEnabled then applyDropVisibility() end
        local hrp = getRootPart()
        if not hrp then
            FarmStatusLabel.Text = "Status: Waiting for Character..."
            task.wait(0.5)
            continue
        end

        local now = tick()
        local rawEnemies = getAllMapEnemies()
        local allEnemies = {}
        local bySpawnName = {}

        -- กรองศพค้าง (DeathM1) และตรวจสอบกรณีมอนซ้อนจุดเกิดเดียวกัน (spawnName ซ้ำกันใน Infinity Tower 50301/50303)
        for _, enemy in ipairs(rawEnemies) do
            local guid = enemy.guid
            local m = enemy.model
            local ent = enemy.entity or (EnemyManager and EnemyManager.enemyEntitys and EnemyManager.enemyEntitys[guid])
            local hasDeathM1 = m and m:FindFirstChild("DeathM1", true) ~= nil
            local isGhost = farmDeadGhostGuids[guid] == true

            if not hasDeathM1 and not isGhost and ent and ent.isLive ~= false and ent.isDeathEffectPlayed ~= true then
                local sName = ent.data and ent.data.spawnName and tostring(ent.data.spawnName) or nil
                enemy.spawnName = sName
                if sName then
                    local prev = bySpawnName[sName]
                    if prev then
                        local prevFails = farmStuckFailCount[prev.guid] or 0
                        local curFails = farmStuckFailCount[guid] or 0
                        if curFails < prevFails then
                            bySpawnName[sName] = enemy
                        end
                    else
                        bySpawnName[sName] = enemy
                    end
                end
                table.insert(allEnemies, enemy)
            end
        end

        -- คำนวณสถานะติดบัคซ้อนกัน (isStuckCooldown) และรวบรวม GUID มอนที่ยืนทับพิกัดเดียวกัน (ระยะ <= 8.5 studs)
        for i = 1, #allEnemies do
            local a = allEnemies[i]
            local sKey = a.spawnName
            local preferred = sKey and bySpawnName[sKey]
            local isDupSpawn = (preferred ~= nil and preferred.guid ~= a.guid)
            local stuckUntil = farmStuckCooldownUntil[a.guid] or 0
            a.isStuckCooldown = (now < stuckUntil) or isDupSpawn
            a.stuckFails = farmStuckFailCount[a.guid] or 0

            local stacks = {}
            for j = 1, #allEnemies do
                if i ~= j then
                    local b = allEnemies[j]
                    if a.pos and b.pos and (a.pos - b.pos).Magnitude <= 8.5 then
                        table.insert(stacks, b.guid)
                    end
                end
            end
            a.stackedGuids = stacks
        end

        MobCountLabel.Text = "Alive Mobs in Map: " .. #allEnemies

        if #allEnemies == 0 then
            local deadCount = 0
            for _ in pairs(lastSeenGuids) do
                deadCount = deadCount + 1
            end
            if deadCount > 0 then
                mobKillCount = mobKillCount + deadCount
                updateInfoStats()
            end
            lastSeenGuids = {}
            candidateIndex = 1
            lockedFarmGuid = nil
            FarmStatusLabel.Text = "Status: Map Cleared! Waiting..."
            task.wait(0.35)
            continue
        end

        -- คัดกรองตาม Filter (All, Boss Only, Normal Only) และตัดเฉพาะ Dummy จริงหรือค่า HP ผิดปกติออก (ไม่ตัดมอนเลือด > 1e30 ใน Infinity Tower ชั้น 60+ / Gojo)
        local candidates = {}
        local candidateByGuid = {}
        local currentAliveGuids = {}
        for _, enemy in ipairs(allEnemies) do
            local lowerName = tostring(enemy.name or ""):lower()
            local hpInvalid = (enemy.hp and (enemy.hp == math.huge or enemy.hp ~= enemy.hp))
                or (enemy.maxHp and (enemy.maxHp == math.huge or enemy.maxHp ~= enemy.maxHp))
            local isDummy = (lowerName:find("dummy") ~= nil) or hpInvalid
            if not isDummy then
                local isBoss = (enemy.level == 99 or enemy.name:lower():find("boss") ~= nil)
                local match = false
                if farmFilterIndex == 1 then
                    match = true
                elseif farmFilterIndex == 2 and isBoss then
                    match = true
                elseif farmFilterIndex == 3 and not isBoss then
                    match = true
                end

                if match then
                    table.insert(candidates, enemy)
                    candidateByGuid[enemy.guid] = enemy
                    currentAliveGuids[enemy.guid] = true
                end
            end
        end

        -- อัปเดตสถิติ Kill Count สำหรับมอนสเตอร์ที่ตายไปแล้ว
        local killedThisTick = 0
        for prevGuid, _ in pairs(lastSeenGuids) do
            if not currentAliveGuids[prevGuid] then
                killedThisTick = killedThisTick + 1
            end
        end
        if killedThisTick > 0 then
            mobKillCount = mobKillCount + killedThisTick
            updateInfoStats()
        end
        lastSeenGuids = currentAliveGuids

        if #candidates == 0 then
            candidateIndex = 1
            lockedFarmGuid = nil
            FarmStatusLabel.Text = "Status: Waiting for target type..."
            task.wait(0.4)
            continue
        end

        -- จัดลำดับ: ตัวที่ไม่ติดคูลดาวน์บัคซ้อนกันมาก่อนเสมอ -> ตัวที่จำนวนครั้งค้างน้อยกว่า -> Boss Priority -> ระยะใกล้สุด
        local myPos = hrp.Position
        table.sort(candidates, function(a, b)
            if a.isStuckCooldown ~= b.isStuckCooldown then
                return not a.isStuckCooldown
            end
            if (a.stuckFails or 0) ~= (b.stuckFails or 0) then
                return (a.stuckFails or 0) < (b.stuckFails or 0)
            end
            if bossPriorityEnabled then
                local aIsBoss = (a.level == 99 or a.name:lower():find("boss") ~= nil)
                local bIsBoss = (b.level == 99 or b.name:lower():find("boss") ~= nil)
                if aIsBoss and not bIsBoss then return true end
                if not aIsBoss and bIsBoss then return false end
            end
            return (a.pos - myPos).Magnitude < (b.pos - myPos).Magnitude
        end)

        -- [คำสั่งผู้ใช้] ยืนอยู่กับที่ ไม่วาป ไม่ขยับตำแหน่ง
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)

        -- ล็อคตีเป้าหมายเดิมจนกว่าจะตายหรือเลือดไม่ลดเกิน ~1 วินาที (ป้องกันสลับเป้าทุก 0.4s จนสกิลเงาโดนยกเลิกกลางคัน)
        local target = nil
        if lockedFarmGuid and candidateByGuid[lockedFarmGuid] and not candidateByGuid[lockedFarmGuid].isStuckCooldown then
            target = candidateByGuid[lockedFarmGuid]
        else
            if candidateIndex > #candidates then candidateIndex = 1 end
            target = candidates[candidateIndex]
            if target and target.isStuckCooldown and not candidates[1].isStuckCooldown then
                target = candidates[1]
                candidateIndex = 1
            end
            lockedFarmGuid = target and target.guid or nil
            lockedFarmLastHp = target and tonumber(target.hp) or nil
            lockedFarmLastHpDropAt = tick()
        end

        local guid = target.guid
        local pos = target.pos
        local model = target.model
        local stackedGuids = target.stackedGuids or {}

        if pos then
            -- หันหน้าเข้าหาเป้าหมายเพื่อให้ท่าทางการโจมตีดูเป็นธรรมชาติ
            pcall(function()
                local lookTarget = Vector3.new(pos.X, hrp.Position.Y, pos.Z)
                if (lookTarget - hrp.Position).Magnitude > 0.1 then
                    hrp.CFrame = CFrame.lookAt(hrp.Position, lookTarget)
                end
            end)

            -- แจ้งเป้าหมายไปยังเซิร์ฟเวอร์แบบไม่ซ้ำซ้อน (ลดการชนกันระหว่าง Remotes.ClickEnemy กับ AgentManager จนถูกเข้าใจผิดว่าเป็นมอนผี)
            if Remotes and Remotes.ClickEnemy then
                if lastServerAcceptedClickGuid ~= guid then
                    local clickGuid = guid
                    local clickPos = pos
                    local wasAlreadyTargeted = (BattleService and BattleService.attackEnemyGUID == clickGuid)
                    lastServerAcceptedClickGuid = clickGuid
                    task.spawn(function()
                        local ok, res = pcall(function()
                            return Remotes.ClickEnemy:InvokeServer({ enemyGuid = clickGuid, enemyPos = clickPos })
                        end)
                        if ok then
                            local cEnt = EnemyManager and EnemyManager.enemyEntitys and EnemyManager.enemyEntitys[clickGuid]
                            if res == true then
                                serverConfirmedAlive[clickGuid] = true
                                if cEnt and cEnt.ShowHpBar then
                                    pcall(cEnt.ShowHpBar, cEnt)
                                end
                            elseif res == false then
                                if wasAlreadyTargeted and cEnt and cEnt.isLive ~= false and not (cEnt.data and cEnt.data.hp and cEnt.data.hp <= 0) then
                                    serverConfirmedAlive[clickGuid] = true
                                else
                                    if lastServerAcceptedClickGuid == clickGuid then
                                        lastServerAcceptedClickGuid = nil
                                    end
                                    if not serverConfirmedAlive[clickGuid] then
                                        farmStuckFailCount[clickGuid] = (farmStuckFailCount[clickGuid] or 0) + 1
                                        farmStuckCooldownUntil[clickGuid] = tick() + 4.0
                                        if farmStuckFailCount[clickGuid] >= 3 and EnemyManager and EnemyManager.DestroyEnemy then
                                            farmDeadGhostGuids[clickGuid] = true
                                            pcall(EnemyManager.DestroyEnemy, clickGuid)
                                        end
                                    end
                                end
                            end
                        else
                            if lastServerAcceptedClickGuid == clickGuid then
                                lastServerAcceptedClickGuid = nil
                            end
                        end
                    end)
                end
            else
                pcall(function()
                    AgentManager.SendEvent(AgentManager.EventNames.ClickEnemy, { enemyGuid = guid, enemyCharacter = model })
                end)
            end

            -- สั่งกองทัพเงาเข้าประกบเป้าหมายและโจมตี (ใช้ความสูงเหนือพื้นจริง ไม่จมแมพ)
            deployHeroesToTarget(pos, guid)

            if BattleService then
                BattleService.attackEnemyGUID = guid
                BattleService.attackDebounce = false
            end
        end

        -- ส่ง Packet โจมตีของผู้เล่นไปยังเป้าหมายหลัก และหากมีมอนซ้อนกัน (stackedGuids ใน Infinity Tower) ให้กวาดตีทุกตัวในกองพร้อมกัน
        local function sendPlayerAttackToGuid(tGuid)
            local attackPacket = { attackEnemyGUID = tGuid, autoClickEnemyGUID = tGuid }
            pcall(function()
                if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.PlayerClickAttack then
                    ProtocolManager.SendMessage(ProtocolManager.Protocols.PlayerClickAttack.Name, attackPacket)
                elseif Remotes and Remotes.PlayerClickAttack then
                    Remotes.PlayerClickAttack:FireServer(attackPacket)
                end
            end)
        end

        sendPlayerAttackToGuid(guid)
        if #stackedGuids > 0 then
            for sIdx = 1, math.min(4, #stackedGuids) do
                sendPlayerAttackToGuid(stackedGuids[sIdx])
            end
        end

        -- ปลดปล่อย Weapon Skill / ตีธรรมดาผ่านหน้า UI
        local mainPanel = UIManager and UIManager.panelDict and UIManager.panelDict[UIManager.UIPanelName.MainPanel]
        if mainPanel then
            if mainPanel.weaponSkillBtn and mainPanel.weaponSkillBtn.Visible then
                mainPanel.isCanClickWeaponSkillBtn = true
                if mainPanel.weaponSkillTimer then mainPanel.weaponSkillTimer = 0 end
                pcall(function() mainPanel:OnWeaponSkillBtnClick() end)
            else
                mainPanel.isCanClick = true
                pcall(function() mainPanel:OnPlayerAttackBtnClick() end)
            end
        end

        local ent = EnemyManager and EnemyManager.enemyEntitys and EnemyManager.enemyEntitys[guid]
        local curHp = (ent and ent.data and ent.data.hp) or target.hp or "--"
        local stackTag = (#stackedGuids > 0) and string.format(" [Stack:%d]", #stackedGuids + 1) or ""
        FarmStatusLabel.Text = string.format("Farming: %s (HP: %s)%s [%d/%d]", target.name, tostring(curHp), stackTag, candidateIndex, #candidates)

        if hideDropsEnabled then
            dismissRewardPopups()
        end

        -- ตรวจสอบการตายและตรวจจับมอนบัคซ้อนกันที่ตีไม่เข้า (Fast Kill + Overlap Stall Detector)
        local targetDied = false
        for checkTick = 1, 5 do
            task.wait(0.1)
            local checkEnt = EnemyManager and EnemyManager.enemyEntitys and EnemyManager.enemyEntitys[guid]
            local hpNow = checkEnt and checkEnt.data and tonumber(checkEnt.data.hp)
            local hasDeathM1 = model and model:FindFirstChild("DeathM1", true) ~= nil

            if not checkEnt or checkEnt.isLive == false or checkEnt.isDeathEffectPlayed == true or (hpNow and hpNow <= 0) or hasDeathM1 then
                targetDied = true
                break
            end

            if hpNow then
                if not lockedFarmLastHp or hpNow < lockedFarmLastHp then
                    lockedFarmLastHp = hpNow
                    lockedFarmLastHpDropAt = tick()
                    farmStuckFailCount[guid] = 0
                end
            end

            if checkTick == 3 and pos then
                deployHeroesToTarget(pos, guid)
            end
        end

        if targetDied then
            mobKillCount = mobKillCount + 1
            updateInfoStats()
            lockedFarmGuid = nil
            farmStuckCooldownUntil[guid] = nil
            farmStuckFailCount[guid] = nil
            serverConfirmedAlive[guid] = nil
        else
            local stallElapsed = tick() - (lockedFarmLastHpDropAt or 0)
            local stallLimit = (#stackedGuids > 0) and 1.5 or 2.5
            if stallElapsed >= stallLimit then
                local fails = (farmStuckFailCount[guid] or 0) + 1
                farmStuckFailCount[guid] = fails
                farmStuckCooldownUntil[guid] = tick() + 4.5
                lockedFarmGuid = nil
                candidateIndex = candidateIndex + 1

                if fails >= 5 and #stackedGuids > 0 and not serverConfirmedAlive[guid] and EnemyManager and EnemyManager.DestroyEnemy then
                    farmDeadGhostGuids[guid] = true
                    pcall(EnemyManager.DestroyEnemy, guid)
                end
            end
        end
    end

    removeSafePlatform()
    FarmStatusLabel.Text = "Status: Farm Stopped"
end

-- ====================================================================
-- ลูปทำงาน: ลงเรดอัตโนมัติ (Auto Raid Loop)
-- ====================================================================
local function autoRaidLoop()
    while isRaidRunning do
        task.wait(0.1)
        ensureManagers()

        local root = getRootPart()
        if not root then
            RaidStatusLabel.Text = "Status: Waiting for Character..."
            task.wait(0.5)
            continue
        end

        if not MapManager or not MapManager.currentMapData or not MapManager.currentMapData.mapSlotInfo or not MapManager.IsLoadFinish then
            RaidStatusLabel.Text = "Status: Waiting for Map Load..."
            task.wait(0.5)
            continue
        end

        local mapCfg = getCurrentMapConfig()
        local currentMap = MapManager.currentMapData.mapSlotInfo.mapId

        -- ตรวจสอบว่าขณะนี้อยู่ในดันเจี้ยนเรดหรือไม่
        local isInsideRaidNow = (currentMap == mapCfg.raidMapId) 
            or (currentMap == 50302) 
            or (currentMap == 50403) 
            or (currentMap and currentMap >= 50100 and currentMap <= 50200) 
            or (RaidsManager and RaidsManager.raidsMapInfo and RaidsManager.raidsMapInfo.mapId and RaidsManager.raidsMapInfo.mapId > 0)

        if not isInsideRaidNow then
            -- [Step 1 & 2] อยู่ในแมพหลัก: ตรวจหาเรด วาปไปแมพที่มีเรด และเข้าเรดทันที
            removeSafePlatform()

            -- 1. ดึงข้อมูลประตูเรดที่เปิดอยู่ทั้งหมด (ตรวจจากทั้ง Client และ Server แบบ Real-time)
            local openGates = {}

            if RaidsManager and RaidsManager.currentRaidInfos then
                for _, info in pairs(RaidsManager.currentRaidInfos) do
                    local rId = tonumber(info.raidId)
                    local mId = tonumber(info.mapId)
                    if rId then
                        table.insert(openGates, { raidId = rId, mapId = mId })
                    end
                end
            end

            pcall(function()
                local notifyData = nil
                if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.GetRaidNotifyData then
                    notifyData = ProtocolManager.SendMessage(ProtocolManager.Protocols.GetRaidNotifyData.Name)
                elseif Remotes and Remotes.GetRaidNotifyData then
                    notifyData = Remotes.GetRaidNotifyData:InvokeServer()
                end

                if notifyData and notifyData.raids then
                    for _, r in ipairs(notifyData.raids) do
                        local rId = tonumber(r.raidId)
                        local mId = tonumber(r.mapId)
                        if rId then
                            local exists = false
                            for _, g in ipairs(openGates) do
                                if g.raidId == rId then
                                    exists = true
                                    break
                                end
                            end
                            if not exists then
                                table.insert(openGates, { raidId = rId, mapId = mId })
                            end
                        end
                    end
                end
            end)

            -- 2. ค้นหาประตูเรดเป้าหมาย และแมพที่มีประตูเรดนั้น
            local targetRaidId = nil
            local targetMapId = nil
            local activeTiers = getCurrentSelectedTiers()

            if mapCfg.isEvent then
                for _, g in ipairs(openGates) do
                    if g.raidId == mapCfg.eventRaidId then
                        targetRaidId = g.raidId
                        targetMapId = g.mapId or 50001
                        break
                    end
                end
                if not targetRaidId then
                    targetRaidId = mapCfg.eventRaidId
                    targetMapId = 50001
                end
            elseif mapCfg.isAscension then
                -- สำหรับเรด Ascension: ค้นหาเฉพาะประตูหอคอยของชั้นที่เลือกไว้ (mapCfg.baseId) ใน openGates เท่านั้น (ไม่ข้ามไปเข้าแมพ Asc อื่น หรือ Event Raid)
                for offset = 10, 1, -1 do
                    if activeTiers[offset] then
                        local checkRaidId = (mapCfg.baseId or 935000) + offset
                        for _, g in ipairs(openGates) do
                            if g.raidId == checkRaidId then
                                targetRaidId = g.raidId
                                targetMapId = (g.mapId and g.mapId > 0) and g.mapId or mapCfg.mapId
                                break
                            end
                        end
                        if targetRaidId then break end
                    end
                end

                -- หากใน openGates ไม่มีข้อมูล แต่ต้องการท้าทายชั้นที่เลือกไว้โดยตรง (ใช้เฉพาะ mapCfg ของชั้นนั้นๆ)
                if not targetRaidId then
                    for offset = 10, 1, -1 do
                        if activeTiers[offset] then
                            targetRaidId = (mapCfg.baseId or 935000) + offset
                            targetMapId = mapCfg.mapId
                            break
                        end
                    end
                end
                if not targetRaidId then
                    RaidStatusLabel.Text = "Status: Please Select at least 1 Tier!"
                    task.wait(1.0)
                    continue
                end
            else
                -- เรดปกติ (Normal Raids)
                for offset = 10, 1, -1 do
                    if activeTiers[offset] then
                        local checkRaidId = (mapCfg.baseId or 930200) + offset
                        for _, g in ipairs(openGates) do
                            if g.raidId == checkRaidId then
                                targetRaidId = checkRaidId
                                targetMapId = g.mapId or mapCfg.mapId
                                break
                            end
                        end
                        if targetRaidId then break end
                    end
                end

                -- หากไม่พบประตูระดับที่ต้องการในเซิร์ฟเวอร์
                if not targetRaidId then
                    local mode = AUTO_REJOIN_MODES[autoRejoinIndex].mode
                    if mode == "HOP" then
                        RaidStatusLabel.Text = "Desired Gate Not Found! Hopping to New Server..."
                        doRejoinOrHop()
                        task.wait(15)
                        continue
                    else
                        local anyGate = false
                        for _, g in ipairs(openGates) do
                            if mapCfg.validRaidMin and mapCfg.validRaidMax then
                                if g.raidId >= mapCfg.validRaidMin and g.raidId <= mapCfg.validRaidMax then
                                    anyGate = true
                                    break
                                end
                            end
                        end
                        if anyGate then
                            RaidStatusLabel.Text = "Gate open (Different Tier). Waiting for Next..."
                        else
                            RaidStatusLabel.Text = "Waiting for Next Raid Gate to Spawn..."
                        end
                        task.wait(1.0)
                        continue
                    end
                end
            end

            -- 3. พอมีเรดแล้ว: ถ้ายังไม่ได้อยู่ที่แมพที่มีประตูเรด ให้วาปไปแมพนั้นทันที ("วาปไปเเมพที่มี")
            if targetMapId and currentMap ~= targetMapId then
                RaidStatusLabel.Text = string.format("Status: Raid Found! Going to Map %d...", targetMapId)
                removeSafePlatform()
                teleportToMap(targetMapId)
                task.wait(2.5)
                continue
            end

            -- 4. เมื่ออยู่ในแมพที่มีเรดแล้ว: เข้าเรดทันที! ("เเละเข้า")
            RaidStatusLabel.Text = "Status: Entering Dungeon..."

            if RaidsManager and RaidsManager.currentTeamInfo and RaidsManager.currentTeamInfo.raidId ~= targetRaidId then
                pcall(function()
                    if RaidsManager.LeaveTeam then
                        RaidsManager.LeaveTeam()
                    elseif Remotes and Remotes.LeaveRaidTeam then
                        Remotes.LeaveRaidTeam:FireServer(RaidsManager.currentTeamInfo.id)
                    end
                end)
                task.wait(0.05)
            end

            local teamInfo = nil
            pcall(function()
                if RaidsManager and RaidsManager.CreateTeam then
                    teamInfo = RaidsManager.CreateTeam(targetRaidId)
                end
            end)
            if not teamInfo then
                pcall(function()
                    teamInfo = Remotes.CreateRaidTeam:InvokeServer(targetRaidId)
                    if teamInfo and RaidsManager and RaidsManager.SetCurrentTeamInfo then
                        RaidsManager.SetCurrentTeamInfo(teamInfo)
                    end
                end)
            end

            task.wait(0.05)

            pcall(function()
                if RaidsManager and RaidsManager.StartRaid then
                    RaidsManager.StartRaid()
                end
            end)
            pcall(function()
                Remotes.StartChallengeRaidMap:FireServer()
            end)
            pcall(function()
                if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.StartChallengeRaidMap then
                    ProtocolManager.SendMessage(ProtocolManager.Protocols.StartChallengeRaidMap.Name)
                end
            end)

            -- รอโหลดเข้าแมพเรด
            local enterTimeout = 0
            while isRaidRunning and enterTimeout < 8 do
                task.wait(0.15)
                enterTimeout = enterTimeout + 0.15
                local mapNow = MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo and MapManager.currentMapData.mapSlotInfo.mapId
                local inRaid = (mapNow == mapCfg.raidMapId) 
                    or (mapNow == 50302) 
                    or (mapNow == 50403) 
                    or (mapNow and mapNow >= 50100 and mapNow <= 50200) 
                    or (RaidsManager and RaidsManager.raidsMapInfo and RaidsManager.raidsMapInfo.mapId and RaidsManager.raidsMapInfo.mapId > 0)
                if inRaid and MapManager.IsLoadFinish then
                    break
                end
            end
        else
            -- [Step 3] อยู่ในดันเจี้ยนเรด (Normal, Event หรือ Ascension): ลุยตีบอสทันที
            if hideDropsEnabled then applyDropVisibility() end
            RaidStatusLabel.Text = "Status: Locating Boss / Enemies..."

            -- รอให้โมเดลบอสหรือมอนสเตอร์เกิดในแมพ (สำหรับเรดชั้นใหม่ที่ไม่เคยเข้า ให้เวลาระบบโหลด Asset นานขึ้นถึง 16 วินาที)
            local isAscEntry = (mapCfg and mapCfg.isAscension) or (raidTypeIndex == 2) or (currentMap == 50302)
            local maxWaitBossTime = isAscEntry and 16.0 or 8.0
            local waitBossTimeout = 0
            while isRaidRunning and waitBossTimeout < maxWaitBossTime do
                local bModel = findTargetRaidEnemy()
                local isSettlement = isRaidSettlementVisible()
                if bModel or isSettlement then break end
                task.wait(0.2)
                waitBossTimeout = waitBossTimeout + 0.2
            end

            if not isRaidRunning then break end

            -- หากรอจนครบเวลาแล้วยังไม่พบศัตรู และไม่มีหน้าต่างผลสรุป แสดงว่าเป็นดันเจี้ยนที่จบไปแล้วหรือว่างเปล่า ให้ออก
            local isSettlementInit = isRaidSettlementVisible()
            if not findTargetRaidEnemy() and not isSettlementInit then
                RaidStatusLabel.Text = "Status: Dungeon Empty! Returning to Main Map..."
                removeSafePlatform()
                dismissRaidSettlement()
                teleportToMap(getSafeReturnMapId())
                task.wait(2.5)
                continue
            end

            -- ยืนรอ 5 วินาทีก่อนเริ่มวาปไปตีบอส (ตามคำสั่งผู้ใช้: ปรับเป็นรอ 5 วิ)
            for countdown = 5, 1, -1 do
                if not isRaidRunning then break end
                RaidStatusLabel.Text = string.format("Status: Waiting %ds before attacking boss...", countdown)
                task.wait(1.0)
            end
            if not isRaidRunning then break end

            RaidStatusLabel.Text = "Status: Hunting Boss..."

            local bossEngaged = false
            local bossDefeated = false
            local currentBossGuid = nil
            local lastNotifiedGuid = nil
            local noTargetCount = 0

            while isRaidRunning do
                task.wait(ATTACK_INTERVAL)

                local hrp = getRootPart()
                if not hrp then break end

                -- ตรวจสอบว่ายังอยู่ในแมพเรดหรือไม่ (ไม่หลุดหรือออกจากเรดก่อนกำหนด)
                local currentMapNow = MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo and MapManager.currentMapData.mapSlotInfo.mapId
                if currentMapNow ~= mapCfg.raidMapId then
                    break
                end

                -- ตรวจสอบว่าบอสที่เคยสู้ตายแล้วหรือไม่
                local isAscRaid = (mapCfg and mapCfg.isAscension) or (raidTypeIndex == 2) or (currentMapNow == 50302)

                -- 1. ตรวจสอบว่าผู้เล่นตายหรือไม่ (ถ้าผู้เล่นตายในเรด จบเรดและออกทันที)
                local myHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
                if myHum and myHum.Health <= 0 then
                    bossDefeated = true
                    dismissRaidSettlement()
                end

                -- 2. ตรวจสอบบอสที่เคยต่อสู้ว่าตายแล้วหรือไม่ (เฉพาะเมื่อเคยเริ่มสู้แล้ว bossEngaged == true)
                if bossEngaged and not bossDefeated and currentBossGuid then
                    local bossEnt = EnemyManager and EnemyManager.enemyEntitys and EnemyManager.enemyEntitys[currentBossGuid]
                    if not bossEnt or not bossEnt.data or (bossEnt.data.hp and bossEnt.data.hp <= 0) then
                        bossDefeated = true
                    elseif bossEnt.isLive == false or bossEnt.isDeathEffectPlayed == true then
                        bossDefeated = true
                    elseif bossEnt.character and not bossEnt.character.Parent then
                        bossDefeated = true
                    end
                end

                -- 3. ตรวจสอบกล่องสมบัติจริงจาก RaidsManager (เฉพาะเมื่อบอสเริ่มสู้แล้ว)
                local hasOfficialChest = (RaidsManager and RaidsManager.raidsMapInfo and RaidsManager.raidsMapInfo.chest and RaidsManager.raidsMapInfo.chest.Parent ~= nil)
                if bossEngaged and hasOfficialChest then
                    bossDefeated = true
                end

                -- 4. ตรวจสอบหน้าต่างสรุปผลรางวัลหรือหน้าต่างแพ้ (SettlementFrame, Defeat, CloseBtn)
                local isSettlementOpen = isRaidSettlementVisible()
                if isSettlementOpen then
                    bossDefeated = true
                    dismissRaidSettlement()
                end

                -- 5. ตรวจสอบ MonsterCount ใน RaidsFightPanel ถ้ากลายเป็น 0 แสดงว่าเคลียร์มอนหมดแล้ว (เฉพาะเมื่อเคยเริ่มสู้แล้ว)
                if bossEngaged then
                    pcall(function()
                        local pg = LocalPlayer:FindFirstChild("PlayerGui")
                        local rfp = pg and pg:FindFirstChild("RaidsFightPanel")
                        if rfp then
                            local mc = rfp:FindFirstChild("MonsterCount", true)
                            if mc and mc:IsA("TextLabel") and mc.Text == "0" then
                                bossDefeated = true
                            end
                        end
                    end)
                end

                -- 6. ตรวจสอบเวลาเรดหมด (Timeout) จาก raidsMapInfo.closeTime
                if RaidsManager and RaidsManager.raidsMapInfo and RaidsManager.raidsMapInfo.closeTime then
                    if RaidsManager.raidsMapInfo.closeTime <= os.time() then
                        bossDefeated = true
                    end
                end

                -- 7. ในหอคอย Ascension หากเคยพบบอสแล้ว (bossEngaged == true) และบอสหายไปจากแมพเกิน 1 วินาที ถือว่าชนะ
                -- ป้องกันบัคเข้าเรดชั้นใหม่เป็นครั้งแรก แล้วบอสยังโหลดไม่เสร็จ เผลอคิดว่าชนะจนออกเรดทันที!
                if isAscRaid and not bossDefeated then
                    if bossEngaged then
                        local anyAscMob = findTargetRaidEnemy()
                        if not anyAscMob then
                            noTargetCount = noTargetCount + 1
                            if noTargetCount >= 5 then -- 5 ticks = 1.0 วินาที
                                bossDefeated = true
                            end
                        else
                            noTargetCount = 0
                        end
                    end
                    if hasOfficialChest or isSettlementOpen then
                        bossDefeated = true
                    end
                end

                if bossDefeated then
                    local isSettlementNow = isRaidSettlementVisible()
                    if not isSettlementNow then
                        RaidStatusLabel.Text = "Status: Boss Defeated! Teleporting to Chest..."
                        local waitChestStart = tick()
                        while isRaidRunning and (tick() - waitChestStart) < 4.0 do
                            if isRaidSettlementVisible() then
                                break
                            end
                            local chestObj = findChestInRaid()
                            if chestObj then
                                local chestPos = chestObj:GetPivot().Position
                                updateSafePlatform(chestPos)
                                hrp.AssemblyLinearVelocity = Vector3.zero
                                hrp.AssemblyAngularVelocity = Vector3.zero
                                hrp.CFrame = CFrame.new(chestPos + Vector3.new(0, 1.5, 0))

                                -- สัมผัส Touch cylinder ของกล่อง
                                if firetouchinterest and chestObj:FindFirstChild("Part") then
                                    pcall(function()
                                        firetouchinterest(hrp, chestObj.Part, 0)
                                        task.wait(0.05)
                                        firetouchinterest(hrp, chestObj.Part, 1)
                                    end)
                                end

                                -- กด ProximityPrompt หากมี
                                for _, desc in pairs(chestObj:GetDescendants()) do
                                    if desc:IsA("ProximityPrompt") then
                                        pcall(function() fireproximityprompt(desc) end)
                                    end
                                end

                                -- ยิงคำสั่งรับของรางวัลเรด
                                pcall(function()
                                    local slotIdx = (RaidsManager and RaidsManager.raidsMapInfo and RaidsManager.raidsMapInfo.slotIndex)
                                        or (MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo and MapManager.currentMapData.mapSlotInfo.slotIndex)
                                    if slotIdx then
                                        if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.GainRaidsRewards then
                                            ProtocolManager.SendMessage(ProtocolManager.Protocols.GainRaidsRewards.Name, slotIdx)
                                        elseif Remotes and Remotes.GainRaidsRewards then
                                            Remotes.GainRaidsRewards:InvokeServer(slotIdx)
                                        end
                                    end
                                end)

                                task.wait(0.2)
                                if not chestObj.Parent or not findChestInRaid() or isRaidSettlementVisible() then
                                    break
                                end
                            end
                            task.wait(0.15)
                        end
                    end

                    raidWinCount = raidWinCount + 1
                    updateInfoStats()

                    RaidStatusLabel.Text = "Status: Exiting to Main Map..."
                    removeSafePlatform()

                    -- [แก้บัคสำคัญ] ใช้ getSafeReturnMapId() ป้องกันส่ง toMapId เป็นแมพที่ยังไม่ได้ปลดล็อคในหอคอย Ascension
                    local cachedSlotIdx = (RaidsManager and RaidsManager.raidsMapInfo and RaidsManager.raidsMapInfo.slotIndex)
                        or (MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo and MapManager.currentMapData.mapSlotInfo.slotIndex)
                    local cachedReturnMap = getSafeReturnMapId()

                    -- ซ่อมแซม fromMapId ใน raidsMapInfo ป้องกัน QuitRaidMap ส่ง toMapId = 0 หรือแมพติดล็อค
                    if RaidsManager and RaidsManager.raidsMapInfo then
                        RaidsManager.raidsMapInfo.fromMapId = cachedReturnMap
                    end

                    -- 1. ปิดหน้าต่างสรุปผลรางวัล (Settlement UI / Defeat UI) และกด CloseBtn บน PlayerGui จริง
                    dismissRaidSettlement()

                    -- 2. ออกจากเรดผ่าน RaidsManager ของตัวเกม
                    pcall(function()
                        if RaidsManager and RaidsManager.QuitRaidMap and RaidsManager.raidsMapInfo then
                            RaidsManager.QuitRaidMap()
                        end
                    end)

                    -- 3. ส่งคำสั่ง QuitRaidsMap ไปยัง Server ทุกช่องทางโดยใช้ cachedSlotIdx และ cachedReturnMap
                    pcall(function()
                        if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.QuitRaidsMap then
                            ProtocolManager.SendMessage(ProtocolManager.Protocols.QuitRaidsMap.Name, {
                                currentSlotIndex = cachedSlotIdx,
                                toMapId = cachedReturnMap
                            })
                        end
                    end)
                    pcall(function()
                        if Remotes and Remotes.QuitRaidsMap then
                            Remotes.QuitRaidsMap:InvokeServer({
                                currentSlotIndex = cachedSlotIdx,
                                toMapId = cachedReturnMap
                            })
                        end
                    end)

                    -- 4. สั่งซ่อนหน้าต่าง UI เรด
                    pcall(function()
                        if UIManager and UIManager.HidePanel then
                            UIManager.HidePanel(UIManager.UIPanelName.RaidsFightPanel)
                        end
                    end)

                    -- 5. ตรวจสอบการกลับเข้าแมพหลักแบบ Real-time (รอจนกว่าตัวละครจะหลุดออกจากแมพเรดจริง)
                    local exitAttempts = 0
                    while isRaidRunning do
                        local nowMap = MapManager and MapManager.currentMapData and MapManager.currentMapData.mapSlotInfo and MapManager.currentMapData.mapSlotInfo.mapId
                        if nowMap ~= mapCfg.raidMapId and MapManager and MapManager.IsLoadFinish then
                            break
                        end

                        exitAttempts = exitAttempts + 1
                        if exitAttempts >= 16 then -- ~8 วินาที
                            RaidStatusLabel.Text = "Status: Exit Timeout! Teleporting to Safe Map..."
                            teleportToMap(cachedReturnMap)
                            task.wait(2)
                            break
                        end

                        -- ยิงคำสั่งออกจากเรดซ้ำทุกๆ 1 วินาทีหากยังไม่ออก
                        if exitAttempts % 2 == 0 then
                            dismissRaidSettlement()
                            pcall(function()
                                if RaidsManager and RaidsManager.QuitRaidMap then
                                    RaidsManager.QuitRaidMap()
                                end
                            end)
                            pcall(function()
                                if Remotes and Remotes.QuitRaidsMap then
                                    Remotes.QuitRaidsMap:InvokeServer({
                                        currentSlotIndex = cachedSlotIdx,
                                        toMapId = cachedReturnMap
                                    })
                                end
                            end)
                            pcall(function()
                                if ProtocolManager and ProtocolManager.Protocols and ProtocolManager.Protocols.QuitRaidsMap then
                                    ProtocolManager.SendMessage(ProtocolManager.Protocols.QuitRaidsMap.Name, {
                                        currentSlotIndex = cachedSlotIdx,
                                        toMapId = cachedReturnMap
                                    })
                                end
                            end)
                        end

                        -- หากส่งไป 8 รอบ (~4 วินาที) ยังไม่ออก ให้พยายาม teleportToMap ตรงๆ
                        if exitAttempts == 8 then
                            pcall(function()
                                teleportToMap(cachedReturnMap)
                            end)
                        end

                        task.wait(0.15)
                    end

                    break -- จบรอบเรดนี้ เข้าสู่การตรวจหาเรดใหม่ทันที
                end

                -- โจมตีเป้าหมาย (หากเคยเจอบอสแล้ว จะไม่เล็งมอนสเตอร์ตัวเล็กอีก)
                local targetModel, targetEntity, isBoss = findTargetRaidEnemy()

                if targetModel and targetModel.PrimaryPart then
                    noTargetCount = 0
                    local targetPos = targetModel.PrimaryPart.Position
                    local guid = targetModel:GetAttribute("EnemyGuid") 
                        or (targetEntity and (targetEntity.guid or (targetEntity.data and targetEntity.data.guid))) 
                        or targetModel.Name

                    if isBoss then
                        bossEngaged = true
                        currentBossGuid = guid
                    end

                    -- จัดตำแหน่งตัวละคร (ยืนบนพื้น ไม่ลอยฟ้า หรือลอยฟ้าถ้าเปิดโหมด Air - นิ่ง ไม่สั่น)
                    local isNewRaidTarget = (lastNotifiedGuid ~= guid)
                    positionAtTarget(targetModel, hrp, isNewRaidTarget)

                    RaidStatusLabel.Text = isBoss and "Status: ATTACKING BOSS!" or "Status: Clearing Floor..."

                    -- 1. วาปเงาทุกตัวมาประกบบอสทันที และเริ่มโจมตี
                    deployHeroesToTarget(targetPos, guid)

                    -- 2. กดสกิลผู้เล่นบนหน้าจออัตโนมัติ (เฉพาะในเรดอีเว้นแมพ 1) (Non-blocking)
                    castScreenSkills(guid)

                    -- 3. แจ้งเป้าหมายให้เซิร์ฟเวอร์ (ยิงเฉพาะตอนเปลี่ยนตัวแบบ Asynchronous ป้องกันเน็ตค้าง)
                    if lastNotifiedGuid ~= guid then
                        lastNotifiedGuid = guid
                        task.spawn(function()
                            pcall(function()
                                Remotes.ClickEnemy:InvokeServer({ enemyGuid = guid, enemyPos = targetPos })
                            end)
                            pcall(function()
                                AgentManager.SendEvent(AgentManager.EventNames.ClickEnemy, { enemyGuid = guid, enemyCharacter = targetModel })
                            end)
                        end)
                    end

                    -- 4. ส่ง Packet ดาเมจอาวุธของผู้เล่นและกดตีพื้นฐาน / ปล่อย Angry Skill ทันใจ
                    local attackPacket = { attackEnemyGUID = guid, autoClickEnemyGUID = guid }
                    if Remotes and Remotes.PlayerClickAttack then
                        Remotes.PlayerClickAttack:FireServer(attackPacket)
                    end
                    if Remotes and Remotes.PlayerClickAttackSkill then
                        Remotes.PlayerClickAttackSkill:FireServer(attackPacket)
                    end
                    pcall(function()
                        if ProtocolManager and ProtocolManager.Protocols then
                            if ProtocolManager.Protocols.PlayerClickAttack then
                                ProtocolManager.SendMessage(ProtocolManager.Protocols.PlayerClickAttack.Name, attackPacket)
                            end
                            if ProtocolManager.Protocols.PlayerClickAttackSkill then
                                ProtocolManager.SendMessage(ProtocolManager.Protocols.PlayerClickAttackSkill.Name, attackPacket)
                            end
                        end
                    end)

                    -- บังคับฟันดาบและกดปล่อย Weapon Skill / Angry Skill ทันทีเมื่อเกจครบ 5 ฮิต
                    local mainPanel = UIManager and UIManager.panelDict and UIManager.panelDict[UIManager.UIPanelName.MainPanel]
                    if mainPanel then
                        if mainPanel.weaponSkillBtn and mainPanel.weaponSkillBtn.Visible then
                            mainPanel.isCanClickWeaponSkillBtn = true
                            if mainPanel.weaponSkillTimer then mainPanel.weaponSkillTimer = 0 end
                            pcall(function() mainPanel:OnWeaponSkillBtnClick() end)
                        else
                            mainPanel.isCanClick = true
                            pcall(function() mainPanel:OnPlayerAttackBtnClick() end)
                        end
                    end

                    if BattleService then
                        BattleService.attackEnemyGUID = guid
                        BattleService.attackDebounce = false
                    end
                    if hideDropsEnabled then
                        dismissRewardPopups()
                    end
                else
                    noTargetCount = noTargetCount + 1
                    local isSettlement = isRaidSettlementVisible()
                    local hasChest = (RaidsManager and RaidsManager.raidsMapInfo and RaidsManager.raidsMapInfo.chest and RaidsManager.raidsMapInfo.chest.Parent ~= nil)

                    -- ใน Ascension Tower:
                    -- 1. ถ้ายังไม่เคยเจอบอสเลย (bossEngaged == false) ห้ามตัดจบเรดเด็ดขาด! ให้รอนานถึง 16 วินาที เพื่อรองรับการโหลด Asset ของชั้นใหม่
                    -- 2. ถ้าเคยเจอบอสแล้ว (bossEngaged == true) ให้รอ ~3.6 วินาที หรือรอจนกว่าจะมีกล่อง/หน้าต่างจบเรด
                    local maxWaitTicks
                    if isAscRaid then
                        if bossEngaged then
                            maxWaitTicks = 18 -- ~3.6 วินาทีหลังจากบอสตาย
                        else
                            maxWaitTicks = 80 -- ~16 วินาทีสำหรับชั้นใหม่ที่ไม่เคยเข้ามาก่อน
                        end
                    else
                        maxWaitTicks = 35
                    end

                    if noTargetCount >= maxWaitTicks then
                        if bossEngaged or isSettlement or hasChest then
                            RaidStatusLabel.Text = "Status: Raid Cleared! Exiting..."
                            removeSafePlatform()
                            dismissRaidSettlement()
                            teleportToMap(getSafeReturnMapId())
                            task.wait(1.5)
                            break
                        else
                            -- รอนานเกิน 16 วินาทีแล้วไม่มีมอนสเตอร์จริงๆ
                            RaidStatusLabel.Text = "Status: Dungeon Empty! Exiting..."
                            removeSafePlatform()
                            dismissRaidSettlement()
                            teleportToMap(getSafeReturnMapId())
                            task.wait(1.5)
                            break
                        end
                    else
                        if isAscRaid and not bossEngaged then
                            RaidStatusLabel.Text = string.format("Status: Loading Floor Boss (%ds)...", math.floor(noTargetCount * 0.2))
                        else
                            RaidStatusLabel.Text = isAscRaid and "Status: Boss Defeated! Waiting exit..." or "Status: Waiting for Next Wave / Target..."
                        end
                        task.wait(0.20)
                    end
                end
            end
        end
    end

    removeSafePlatform()
    RaidStatusLabel.Text = "Status: Stopped"
end

-- ====================================================================
-- Event ปุ่มเริ่ม/หยุด (Raid & Farm)
-- ====================================================================
ToggleRaidBtn.MouseButton1Click:Connect(function()
    isRaidRunning = not isRaidRunning
    if isRaidRunning then
        if isFarmRunning then
            isFarmRunning = false
            ToggleFarmBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            ToggleFarmBtn.Text = "START ALL MAP FARM"
            FarmStatusLabel.Text = "Status: Idle"
        end
        ToggleRaidBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        ToggleRaidBtn.Text = "STOP AUTO RAID"
        saveBotState(true)
        task.spawn(autoRaidLoop)
    else
        ToggleRaidBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        ToggleRaidBtn.Text = "START AUTO RAID"
        saveBotState(false)
        removeSafePlatform()
        RaidStatusLabel.Text = "Status: Idle"
    end
end)

ToggleFarmBtn.MouseButton1Click:Connect(function()
    isFarmRunning = not isFarmRunning
    if isFarmRunning then
        if isRaidRunning then
            isRaidRunning = false
            ToggleRaidBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            ToggleRaidBtn.Text = "START AUTO RAID"
            RaidStatusLabel.Text = "Status: Idle"
            saveBotState(false)
        end
        ToggleFarmBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        ToggleFarmBtn.Text = "STOP ALL MAP FARM"
        task.spawn(autoFarmMapLoop)
    else
        ToggleFarmBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        ToggleFarmBtn.Text = "START ALL MAP FARM"
        removeSafePlatform()
        FarmStatusLabel.Text = "Status: Idle"
    end
end)

local shouldAutoResume = loadBotState()
updateSelectors()
updateInfoStats()
updateAutoRejoinButtonVisuals()
updateHideDropsButtonVisuals()
updateQuirkButtonVisuals()
if OPT and OPT.updateHideDamageVisuals then OPT.updateHideDamageVisuals() end
if OPT and OPT.updateHideSkillEffectsVisuals then OPT.updateHideSkillEffectsVisuals() end
if OPT and OPT.db and OPT.db.updateAutoBtnVisuals then OPT.db.updateAutoBtnVisuals() end
if OPT and OPT.db and OPT.db.startLoop then OPT.db.startLoop() end
if BossAlert and BossAlert.updateVisuals then BossAlert.updateVisuals() end
if BossAlert and BossAlert.startLoop then BossAlert.startLoop() end

if autoStartOnJoin then
    AutoStartBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 40)
    AutoStartBtn.Text = "Auto Start on Join: ENABLED (ON)"
    AutoStartBtn.TextColor3 = Color3.fromRGB(120, 255, 150)
else
    AutoStartBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    AutoStartBtn.Text = "Auto Start on Join: DISABLED (OFF)"
    AutoStartBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
end

if hideDropsEnabled then
    applyDropVisibility()
    dismissAllRewardPopups()
end

if OPT and (OPT.hideDamageEnabled or OPT.hideSkillEffectsEnabled) then
    task.spawn(function()
        if not LocalPlayer.Character then
            LocalPlayer.CharacterAdded:Wait()
        end
        if OPT and OPT.hideDamageEnabled then
            OPT.ensureDamageHook()
            OPT.clearDamagePopups()
        end
        if OPT and OPT.hideSkillEffectsEnabled then
            OPT.ensureSkillEffectsHook()
            OPT.clearSkillEffects()
        end
    end)
end

if shouldAutoResume or (autoStartOnJoin and not (OPT and OPT.db and OPT.db.autoLoop)) then
    task.spawn(function()
        repeat task.wait(1) until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        task.wait(2)
        if not isRaidRunning and not isFarmRunning then
            isRaidRunning = true
            ToggleRaidBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
            ToggleRaidBtn.Text = "STOP AUTO RAID"
            saveBotState(true)
            task.spawn(autoRaidLoop)
        end
    end)
end

