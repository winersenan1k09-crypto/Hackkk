--[[
    Duckk Hub — Pet Simulator 99 Kaitun Engine (Update 103: Pumpkin Patch Tycoon & Turkey Hunt)
    Architecture: Shared Core Head & Tail + Custom Duckk Event State Machine (by moon)
]]

-- ============================================================================
-- 0. USER CONFIGURATION (Set getgenv().Config before loadstring, or edit here)
-- ============================================================================
getgenv().Config = getgenv().Config or {
    FPSCap = 60, -- FPScap
    CPUSaver = true,
    Enchants = {}, -- // Auto Equip Enchants
    AutoOpen = { "Charm Stone", "Large Gift Bag", "Gift Bag", "Potion Bundle", "Enchant Bundle", "Toy Bundle", "Fruit Bundle", "Flag Bundle", "Large Enchant Bundle", "Large Potion Bundle", "Mini Chest" }, -- // Opening Gifts
    Potions = {"Diamonds", "Damage", "Treasure Hunter", "Lucky", "Walkspeed", "Coins", "The Cocktail"}, -- // Using Best Tier of Potion
    AutoBoosts = {"Island Luck Boost", "Patch Coin Boost", "Pumpkin Damage Boost"}, -- "Island Luck Boost", "Patch Coin Boost", "Pumpkin Damage Boost"
    PumpkinTycoon = {
        AutoClaimPass = true,
        AutoBuyMerchant = true,
        AutoBuyNetsMerchant = true,
        AutoHunt = {Enable = true, UltraOnHuges = true, Min = 4, VariantOnly = false},
        MaxRebirths = 0,
        AutoTurkey = true,
        UseUltraForHugeAfterTurkey = false
    },
    Upgrades = {
        ["PumpkinTycoonSpawnLuck"] = 99,
        ["PumpkinTycoonPumpkinCoins"] = 99,
        ["PumpkinTycoonPumpkinDamage"] = 99,
        ["PumpkinTycoonRespawnSpeed"] = 99,
        ["PumpkinTycoonStockSlots"] = 99,
        ["PumpkinTycoonChaseOdds"] = 99,
        ["PumpkinTycoonEggLuck"] = 99,
        ["PumpkinTycoonMerchantLuck"] = 99,
    },
    Lootbox = {"Flannel Gift"},
    AutoMail = {
        Enable = false, -- true/false
        User = { "" }, -- Your User for mail
        Items = {
            -- ["Name"] = { Class = "Classitem", Amount = Number },
        }
    },
    Webhook = {
        Enable = true, -- true/false
        HugeWebhookURL = "",
        TitanicWebhookURL = "",
        GargantuanWebhookURL = "",
        DiscordID  = "" -- Discord ID
    }
}

-- ============================================================================
-- 1. RE-EXECUTION TEARDOWN GUARD
-- ============================================================================
local GEN_KEY = "_DuckkKaitun"
for _, k in ipairs({ "_DuckkKaitun", "_PumpkinTycoonKaitun" }) do
    local prevEnv = getgenv()[k]
    if type(prevEnv) == "table" and type(prevEnv.Teardown) == "function" then
        pcall(prevEnv.Teardown)
        getgenv()[k] = nil
        task.wait(0.12)
    end
end

-- ============================================================================
-- 1B. INTERNAL DEFAULT CONFIGURATION (All keys can be overridden via getgenv().Config)
-- ============================================================================
local DEFAULT_CONFIG = {
    Enabled = true,
    Debug = "auto",

    -- Instance & Onboarding
    AutoJoin = true,
    AutoTutorial = true,

    -- Anti-AFK (Roblox 20m + PS99 Idle Tracking)
    AntiAFK = true,
    AntiAfkMode = "auto",           -- "auto" ("safe" on Mobile/Delta or when Idle Tracking disables cleanly), "safe", "hook"
    AntiAFKRoblox = true,           -- Periodic VirtualUser pulse (< 120s) + LocalPlayer.Idled fallback against 20m kick
    AntiAFKRobloxPulseInterval = 45,-- Seconds between proactive VirtualUser & Idle Tracking reset pulses
    AntiAFKP99 = true,              -- Disables PS99 Scripts.Core["Idle Tracking"] + resets server idle timer
    AntiAFKP99PulseInterval = 6.5,  -- Seconds between desktop F15 pulses when hook fallback is active
    BlockNativeMoveServer = true,   -- Suppress "Move Server", "Idle Tracking: Engine Idle", "Idle Tracking: Update Timer"
    SpoofIdleFocusTrue = true,      -- Force "Idle Tracking: Focus Changed" arg1 = true when unfocused

    -- Phase Progression (A1 - Part 1 + Part 2)
    RushButtonsFirst = true,        -- Hold Coins purely for Buttons + Completion before spending on Eggs/Merchant/Cocoa
    AutoBuyButtons = true,
    AutoCompleteTycoon = true,      -- Invokes BT_Settle on 100% completion for 20x Flannel Gift
    AutoCompletePart2 = true,       -- Invokes MH_Conclude on 100% Part 2 completion
    BuyOptionalPart2Buttons = false,-- Optional Zone8_Cannon (14.5T) & Zone8_RebirthShrine (15.3T) after required buttons
    TargetRebirths = 0,             -- 0 = Off (default); 3 = max 1.0x Huge/Titanic egg odds; 20 = max +400% Coins; -1 = infinite

    -- Farm & Combat Speed
    AutoFarm = true,
    AutoTap = true,
    AutoPetFocus = true,
    AutoSpreadZoneBreakables = true, -- Spread each pet onto its own highest-zone breakable; focus all pets on BonusChest/Pedestal
    AutoTeleportToTarget = true,
    AutoBuffPetSpeed = true,        -- Overrides LocalPlayer CalculateSpeedMultiplier() -> PetSpeedMultiplier
    PetSpeedMultiplier = 999,       -- Target speedMult (PetRendering multiplies petSpeed * petSpeedMult)
    FarmOrchardAndHay = true,
    AutoCollectOrbs = true,         -- Collects both Orbs and Lootbags from __THINGS.Orbs via "Orbs: Collect"
    TapInterval = 0.065,            -- Matches PS99 Swift Taps 8..16/s cap without 25 Hz overhead
    TapSendAutoClickerSignal = false, -- Skip AutoClicker_Nearby UI tween/coroutine FX spam; keep Breakables_PlayerDealDamage
    FarmLoopInterval = 0.10,        -- Pet & movement target refresh interval
    OrbSweepInterval = 0.50,        -- Sparse fallback sweep for delayed Lootbags alongside Orbs: Create event
    PedestalLowRungSweepIntervalSec = 20, -- In Zone 6-8, throttle 700-stud trips for R1-R2 pedestals to once every 20s

    -- Keep / Lock / Stock / Merchant (A2)
    KeepRung = 0,                   -- Ladder: 2=Rare..8=Secret manual; 0=Off in Part 1 (auto EarnRate Lock in Part 2 Zone 6+)
    AutoKeepPart2Pedestals = true,  -- In Part 2 Zone 6+, automatically lock top EarnRate pedestals for passive Ref[6..8] Coins/s
    PostCompleteSmartLuckLock = true, -- After 117/117, trim locked pedestals to minimum high-Rung slots needed for full +100% PumpkinLuck (opens 5-7 slots for Token farming)
    Part2KeepMinRung = 4,           -- Minimum base rung equivalent (4=Legendary / 0.25x Ref) for Part 2 auto-lock
    Part2MinFarmPedestals = 1,      -- Keep 1 open pedestal for Token farming & Merchant placement in Part 2 (locks 5/6 -> 7/8)
    LockMinRung = 0,                -- 0 = follow KeepRung; or set >= 2 to override
    MinFarmPedestals = nil,         -- nil = adaptive; or set integer >= 1
    AutoLockUpgradeSwap = true,     -- Swap weakest locked pedestal by EarnRate (Cps * VariantMult) when a stronger pumpkin spawns
    AutoPlaceStock = true,          -- Enable auto-place ("next") + allocate held stock onto free pedestals
    AutoBuyMerchant = true,         -- Buy Merchant Mythical+/Exotic+/Legendary+ bands (gated by <= 5% Coins in Part 2 Rush)
    MerchantRequireButtonsComplete = false,
    MerchantRushRequireZone6 = true,-- Only buy Merchant during Rush once Zone 6+ (Ref=14.17M/s) is unlocked
    MerchantRushMaxCoinShare = 0.05,-- During Rush, buy Merchant band only if price <= 5% of current Coins
    MerchantActivateCoins = 100000000, -- Start buying Merchant bands at >= 100M Patch Coins (post-complete)
    MerchantMinSpareCoins = 50000000,  -- Keep at least 50M Patch Coins spare after a Merchant purchase (post-complete)
    KeepServerAutoMerchantOff = true, -- Prevent server HM_Sustain from buying low tiers into stock slots
    MerchantBandOrder = { "ExoticPlus", "MythicalPlus", "LegendaryPlus" },
    AllowedMerchantBands = {
        ExoticPlus = true,
        MythicalPlus = true,
        LegendaryPlus = true,
        EpicPlus = false,
        RarePlus = false,
    },

    -- Upgrades with PumpkinTokens (A3)
    AutoUpgrades = true,
    UpgradeTier1CheapFirst = true,  -- Buy all Tier 1 upgrades <= UpgradeCheapTier1MaxBaseCost before Priority Tier 2+
    UpgradeCheapTier1MaxBaseCost = 50,
    UpgradePriority = {
        "PumpkinCoins",
        "PumpkinDamage",
        "RespawnSpeed",
        "SpawnLuck",
        "ChaseOdds",
        "EggLuck",
        "StockSlots",
        "MerchantLuck",
    },
    UpgradePriorityPostComplete = {
        "EggLuck",
        "ChaseOdds",
        "RespawnSpeed",
        "SpawnLuck",
        "MerchantLuck",
        "StockSlots",
        "PumpkinDamage",
        "PumpkinCoins",
    },
    UpgradeCheapCatchupRatio = 0.40, -- Buy lower-priority track if cost <= 40% of blocked top priority (0 = strict linear)

    -- Boosts, Fruits, Hot Cocoa Stand & Flannel Gifts (A2/A4)
    AutoConsumeBoosts = true,
    BoostRefreshSeconds = 15,
    AllowedConsumableBoosts = {
        ["Patch Coin Boost"]     = { Tier1 = true, Tier2 = true, Tier3 = false },
        ["Pumpkin Damage Boost"] = { Tier1 = true, Tier2 = true, Tier3 = false },
        ["Island Luck Boost"]    = { Tier1 = true, Tier2 = true, Tier3 = false },
    },

    AutoConsumeFruits = true,
    FruitTargetStack = 20,          -- Keep up to 20x stacked fruits (e.g. Apple = +30% Pet Damage)
    FruitMinRefillMissing = 4,      -- Batch refill when >= 4 queue slots open (or immediately when 0 active)
    FruitConsumeCooldownSec = 6,
    AllowedFruits = {
        Apple = true,
    },

    AutoCocoaStand = true,
    CocoaRequireButtonsComplete = false, -- During Rush, gated by CocoaMinIncomePerSec (>= 3.5M/s); set true to block until Part 1 done
    CocoaMinIncomePerSec = 3500000,      -- Tier 1 Cocoa costs 100M/min (1.67M/s) for +50% Coins -> profitable above 3.33M/s
    CocoaRushDamageMinIncomePerSec = 15000000, -- Add Damage Cocoa (+50% dmg) during Rush once income >= 15M/s
    CocoaRushLuckMinIncomePerSec = 30000000,   -- Add IslandLuck Cocoa (+25% luck) during Rush once income >= 30M/s
    CocoaIncomeMinSampleSec = 45,        -- Require >= 45s sustained rate samples before turning on during Rush
    CocoaActivateCoins = 300000000,      -- Activate Hot Cocoa Stand at >= 300M Patch Coins
    CocoaMaintainMinutes = 2,
    CocoaBuyStepMinutes = 2,             -- Buy 1-2 minutes per refresh cycle while maintaining >= CocoaMinSpareCoins
    CocoaPostCompleteMaintainMinutes = 30, -- Post-complete (rich Coins): refill when axis timer drops below 30m
    CocoaPostCompleteBatchMinutes = 120,   -- Post-complete (rich Coins): buy 120m (2h) per trip so character rarely leaves Zone 8 Egg
    CocoaMinSpareCoins = 150000000,      -- Keep at least 150M Patch Coins spare after Cocoa purchase
    CocoaRushAxes = { "Coins" },         -- During Rush with KeepRung=0, only Coins Cocoa is net-positive near ~3.5M/s
    CocoaAxes = { "Coins", "Damage", "IslandLuck" },

    AutoOpenGifts = true,
    GiftBatchAmount = 8,            -- Server clamp [1, 8]

    -- Egg Hatching (Smart Early Bootstrap + Post-Buttons Zone 8 Golden Ridge)
    AutoHatch = true,
    AutoEarlyHatchForDamage = true,      -- Hatch unlocked eggs during rush when team EventDamage is below target
    EarlyHatchMaxPerEgg = 8,             -- Minimum basic hatch cap before Gold/Rainbow craft upgrade mode (scales up with maxEquip)
    EarlyHatchBasicMaxCap = 25,          -- Max basic-only hatches on Zone 1-2 before Gold/Rainbow machine unlocks
    EarlyHatchUpgradeWithCraft = true,   -- Hatch past basic cap during Rush when Gold/Rainbow machine is unlocked
    EarlyHatchMaxCoinsPerEgg = 35000000, -- Base upgrade hatch cap (auto-scales to full Rainbow team budget for Part 2 Eggs 6-8)
    EarlyHatchLowHatchMaxEggs = 300,     -- Early craft hatch egg cap on Part 1 Eggs for low-hatch (maxHatch < 4) accounts
    EarlyHatchPart2RainbowMinEggs = 1300,-- Minimum egg cap on Part 2 Eggs 6-8 so low/mid-hatch accounts reach full Rainbow team
    EarlyHatchTargetVariantMult = 4,     -- Target Rainbow tier (4x common EventDamage, or 2x when only Gold is unlocked)
    EarlyHatchTargetBestMult = 5.5,      -- Stop early once weakest >= Rainbow AND best non-Huge >= 5.5x
    EarlyHatchMaxShareOfNextButton = 0.25, -- Pause early upgrade hatch once Coins >= 75% of next critical button
    EarlyHatchMinBalanceRatio = 20,      -- Require Coins >= eggCost * 20 before spending on craft upgrade hatches
    EarlyHatchReserveCoins = true,       -- Temporarily reserve 1x egg cost during early bootstrap before buying buttons
    AutoEquipBestPets = true,            -- Ensure AutoEquipPets / EquipBest equips newly hatched stronger pets immediately
    TargetEggName = "Golden Ridge Egg",
    HatchStartZone = 8,                  -- 0 = wait for 117/117 buttons | 1..8 (or "8") = hatch continuously once Zone N & its Egg unlock, yielding 1 beat when Coins >= next button
    FallbackHighestUnlockedEgg = true,
    HatchDisableAnimation = true,
    HatchMinBatchMultiplier = 1,    -- Start hatching when Coins >= cost * maxBatch * mult (or >= cost * 1)
    HatchMoveMaxDist = 30,          -- Server allows CustomEggs_Hatch up to ~36 studs; <=30 overlaps Zone 5 breakables
    HatchCooldown = 0.02,

    -- Pet Crafting (Gold & Rainbow Machine)
    AutoMakeGold = true,                -- Automatically craft Normal pets -> Golden at plot GoldMachine
    AutoMakeRainbow = true,             -- Automatically craft Golden pets -> Rainbow at plot RainbowMachine
    CraftEventPetsOnly = true,          -- Restrict crafting to PumpkinTycoon event pets
    CraftProtectShiny = true,           -- Skip Shiny pets (sh == true)
    CraftProtectLocked = true,          -- Skip locked pets (_lk == true / IsLocked())
    CraftProtectEquipped = true,        -- Subtract currently equipped stack counts via PetCmds.GetEquipped()
    CraftReserveMinTeamSlots = true,    -- Preserve at least PetCmds.GetMaxEquipped() total pets across inventory
    CraftRequireButtonComplete = true,  -- Require plot GoldMachine / RainbowMachine button to be owned before crafting
    CraftMinBatch = 1,                  -- Minimum crafted output pets per stack before triggering a machine trip
    CraftPostCompleteMinBatch = 5,      -- Minimum crafted output pets per stack to trigger a craft trip while AFK post-complete hatching
    CraftMaxBatchPerInvoke = 25,        -- Max crafted pets per single Network.Invoke call (chunks larger stacks)
    CraftCheckIntervalSec = 1.0,        -- Seconds between craft eligibility scans
    CraftEarlyHatchYieldIntervalSec = 8.0, -- Yield early bootstrap hatching every 8s to batch 5-7x Gold -> Rainbow crafts with minimal travel overhead
    CraftHatchYieldIntervalSec = 30.0,  -- Post-complete AFK hatch yield interval (30s) to maximize Huge/Titanic hatch uptime
    CraftFailCooldownSec = 10,          -- Cooldown backoff after a failed machine invoke

    -- Wild Hunt, Sighting & Pet Net Store (Part 2)
    AutoHuntWild = true,                -- Scan all owned zones & catch wild pets via RU_Ensnare (3s cooldown)
    AutoCatchSighting = true,           -- Catch Boss Turkey Sightings (Huge/Titanic/Gargantuan) via PV_Glimpse
    HuntMinTier = 4,                    -- 0=Any, 1=Uncommon+, 2=Rare+, 3=Epic+, 4=Huges only
    HuntVariantsOnly = false,           -- Only catch Golden/Rainbow/Shiny wild pets
    HuntAlwaysCatchHuges = true,        -- Always allow Huge wild pets even when HuntVariantsOnly=true
    HuntUltraOnHuge = true,             -- Use Ultra Pet Net first on Huges/Sightings and save it exclusively for them
    HuntUseNormalNetOnHuge = true,      -- Fallback to Pet Net on Huges/Sightings when 0 Ultra Pet Nets remain
    HuntMinCatchChance = 0,             -- Optional minimum catch probability (0..1)
    HuntRerollWild = true,              -- Burn spare normal Pet Nets in HuntRerollZone to reroll Wild Huge spawns immediately
    HuntRerollZone = 1,                 -- Reroll zone (1 = Huge Cocoa Husky 1/237 highest odds; 5 = Huge Gobble Axolotl 1/381)
    HuntRerollKeepNets = 15,            -- Minimum normal Pet Net reserve to keep for real Huge/Sighting catches
    HuntRerollRequireButtonsComplete = true, -- Only burn spare Pet Nets after 117/117 buttons complete
    DisableServerAutoHunt = true,       -- Turn off server 80-stud/6s Auto Hunt when AutoHuntWild is active
    AutoBuyNetStore = true,             -- Auto buy Pet Net Store via Merchant_RequestPurchase
    KeepServerAutoNetsOff = true,       -- Turn off server AutoBuyNets so Rush Coins budget is respected
    NetStoreBuyUltra = true,            -- Always buy Ultra Pet Net whenever affordable (even during Rush)
    NetStoreBuyNormal = true,           -- Buy Pet Net post-buttons or during Rush when price <= NetStoreMaxRushCoinShare * Coins
    NetStoreMaxRushCoinShare = 0.05,    -- During Rush, buy normal Pet Net only if price <= 5% of current Coins (0 = post-buttons only)
    NetStoreMinSpareCoins = 0,          -- Minimum Coins to keep after Net Store purchase (post-buttons)
    NetStoreCheckIntervalSec = 4.0,     -- Seconds between Net Store shelf checks

    -- Server-Wide Turkey Boss (Part 2 TurkeyArena)
    AutoTurkeyBoss = true,              -- Fly to TurkeyArena and fight Turkey Boss whenever TurkeyAlive == true
    TurkeyBossRequireCannon = false,    -- false = attempt direct fly even without Zone8_Cannon; true = require Cannon / Rebirth >= 1
    TurkeyBossSmartKillCheck = true,    -- Avoid wasting 15m on unkillable solo/low-DPS bosses; monitor TurkeyTop passively to rejoin if help arrives
    TurkeyBossSoloProbeSec = 25,        -- Seconds to probe a fresh boss solo before returning to island if no other player joins
    TurkeyBossLowDpsWarmupSec = 60,     -- Warmup seconds while fighting with others before allowing low_dps abort (prevents multi-acc race)
    TurkeyBossKillMargin = 0.85,        -- Require projected (serverDps * secLeft) >= health * margin to stay/engage
    TurkeyBossMinShareStop = 0,         -- 0 = stay until boss dies/despawns; > 0 (e.g. 0.015) = leave once PumpkinTurkeyShare >= threshold
    TurkeyBossNoDamageTimeoutSec = 25,  -- Abort spawn if 0 share after 25s attacking without Cannon so farm is never stalled
    TurkeyBossStandOffset = 18,         -- Horizontal stand distance (studs) from boss center (inside 20-stud TapReach & 150-stud TurkeyReach)

    -- Optional Event Pass (disabled by default; enable when desired)
    AutoEventPass = false,

    -- Map & Render Optimization
    UltraLowRAM = "auto",               -- "auto" (enabled on Mobile/Delta) | true | false (PotatoMode + PS99 low-RAM settings + child-cleared Eggs/ShinyRelics/ZoneEggs + slower intervals)
    FPSCap = 0,                         -- 0 = auto (PC uncapped; Mobile uses MobileFPSCap3dOff/On); > 0 forces FPS cap everywhere
    MobileFPSCap3dOff = 15,             -- Mobile/Delta FPS cap while 3D rendering is disabled
    MobileFPSCap3dOn = 25,              -- Mobile/Delta FPS cap while 3D rendering is enabled
    ClearTerrainVoxels = "auto",        -- "auto" (false on Mobile, true on PC); only calls terrain:Clear() if voxel cells > 0
    OptimizeMap = true,                 -- Master toggle for world cleanup + visual hiding + lighting/FX reduction
    StripWorldClutter = true,           -- Destroy unused world maps/props (PSX Portal, Border, Ornaments, __DEBRIS)
    HideIslandVisuals = true,           -- Make PumpkinTycoonIslands, __THINGS.Plots, Pads, Pumpkins invisible + strip decals/FX (when 3D is active)
    HideEntityVisuals = true,           -- Make Breakables, CustomEggs, Pets, Orbs & other players invisible (when 3D is active)
    OptimizeLightingAndEffects = true,  -- Disable Shadows/Sky/Bloom/Atmosphere/PostEffects/Particles and Terrain decoration
    SafeFloorEnabled = true,            -- Maintain invisible backup Baseplate under own plot to prevent void falls
    OptimizeScanInterval = 15.0,        -- Seconds between low-cost sweeps for newly streamed clutter/containers

    -- Dashboard UI
    ShowKaitunUI = true,                -- Full-screen black dashboard overlay + Set3dRenderingEnabled(false)

    -- Discord Pet Drop Webhook (Huge / Titanic / Gargantuan; runs alongside fixed global webhook)
    WebhookEnabled = true,              -- Enables optional personal WebhookUrl (does not disable built-in global webhook)
    WebhookUrl = "",                    -- Personal Discord Webhook URL (https://discord.com/api/webhooks/...)
    WebhookCategories = {
        Huge = true,
        Titanic = true,
        Gargantuan = true,
    },
    WebhookPollInterval = 1.0,          -- Snapshot poll interval (seconds)

    -- Auto Mail (Send Only; continuous via EF_Relay, no fee cap by default)
    AutoMail = false,                   -- Master toggle for Auto Send
    MailUsernames = {},                 -- Recipient username(s): { "Acc1" } or "Acc1" (self-username auto-skipped)
    MailItems = {},                     -- Whitelist: ["Name"] = Amount | "Max" | { Class, Amount, MinAmount, Keep } or "Class:Name"
    MailMinDiamondsReserve = 100000,    -- Diamonds kept on account when sending Currency:Diamonds (actual fee added on top)
    MailMaxFee = 0,                     -- 0 = unlimited (VIP or up to 5M cap); > 0 = pause send if current fee exceeds cap
    MailMessage = "",                   -- "" avoids PS99's 60s server message cooldown (GUIs.Mailbox L592)
    MailSendDelay = 2.2,                -- Delay (seconds) between consecutive EF_Relay sends
    MailScanInterval = 10.0,            -- Inventory scan interval (seconds)
    MailSkipLocked = true,              -- Skip locked items/pets (_lk / IsLocked)
    MailSkipEquippedPets = false,        -- Subtract equipped pet counts (PetCmds.GetEquipped) & skip Daycare pets
    MailRoundRobin = false,             -- false = send to first valid recipient; true = rotate recipient per send
    MailWebhookEnabled = false,         -- Optional Discord webhook on sent mail (uses MailWebhookUrl or WebhookUrl)
    MailWebhookUrl = "",                -- Optional dedicated Discord webhook URL for Mail logs
}

local function ApplyConfigDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                local clone = {}
                ApplyConfigDefaults(clone, v)
                dst[k] = clone
            else
                dst[k] = v
            end
        elseif type(v) == "table" and type(dst[k]) == "table" and #v == 0 then
            ApplyConfigDefaults(dst[k], v)
        end
    end
end

local Config = {}
do
    local userConfig = type(getgenv().Config) == "table" and getgenv().Config or {}
    local userSet = {
        ShowKaitunUI = (userConfig.ShowKaitunUI ~= nil or userConfig.CPUSaver ~= nil),
        FarmLoopInterval = userConfig.FarmLoopInterval ~= nil,
        HatchCooldown = userConfig.HatchCooldown ~= nil,
        TapInterval = userConfig.TapInterval ~= nil,
        WebhookPollInterval = userConfig.WebhookPollInterval ~= nil,
        CraftCheckIntervalSec = userConfig.CraftCheckIntervalSec ~= nil,
        OptimizeScanInterval = userConfig.OptimizeScanInterval ~= nil,
    }

    -- Normalize structured getgenv().Config keys before merging flat defaults
    if userConfig.CPUSaver ~= nil then
        if userConfig.ShowKaitunUI == nil then
            Config.ShowKaitunUI = (userConfig.CPUSaver == true)
        end
        if userConfig.OptimizeMap == nil then
            Config.OptimizeMap = (userConfig.CPUSaver == true)
        end
    end
    if type(userConfig.FPSCap) == "number" then
        Config.FPSCap = userConfig.FPSCap
    end
    if type(userConfig.Enchants) == "table" then
        Config.Enchants = userConfig.Enchants
    end
    if type(userConfig.AutoOpen) == "table" then
        Config.AutoOpen = userConfig.AutoOpen
    end
    if type(userConfig.Potions) == "table" then
        Config.Potions = userConfig.Potions
    end
    if type(userConfig.AutoBoosts) == "table" then
        local boostMap = {
            ["Patch Coin Boost"] = false,
            ["Pumpkin Damage Boost"] = false,
            ["Island Luck Boost"] = false,
        }
        local anyBoost = false
        for k, v in pairs(userConfig.AutoBoosts) do
            if type(k) == "number" and type(v) == "string" and v ~= "" then
                boostMap[v] = { Tier1 = true, Tier2 = true, Tier3 = true }
                anyBoost = true
            elseif type(k) == "string" and v then
                boostMap[k] = (type(v) == "table") and v or { Tier1 = true, Tier2 = true, Tier3 = true }
                anyBoost = true
            end
        end
        if userConfig.AutoConsumeBoosts == nil then
            Config.AutoConsumeBoosts = anyBoost
        end
        if userConfig.AllowedConsumableBoosts == nil then
            Config.AllowedConsumableBoosts = boostMap
        end
    end
    if type(userConfig.PumpkinTycoon) == "table" then
        local pt = userConfig.PumpkinTycoon
        if pt.AutoClaimPass ~= nil then Config.AutoEventPass = (pt.AutoClaimPass == true) end
        if pt.AutoBuyMerchant ~= nil then Config.AutoBuyMerchant = (pt.AutoBuyMerchant == true) end
        if pt.AutoBuyNetsMerchant ~= nil then Config.AutoBuyNetStore = (pt.AutoBuyNetsMerchant == true) end
        if type(pt.AutoHunt) == "table" then
            local ah = pt.AutoHunt
            if ah.Enable ~= nil then Config.AutoHuntWild = (ah.Enable == true) end
            if ah.UltraOnHuges ~= nil then Config.HuntUltraOnHuge = (ah.UltraOnHuges == true) end
            if ah.Min ~= nil then Config.HuntMinTier = tonumber(ah.Min) or 4 end
            if ah.VariantOnly ~= nil then Config.HuntVariantsOnly = (ah.VariantOnly == true) end
        end
        if pt.MaxRebirths ~= nil then
            Config.TargetRebirths = tonumber(pt.MaxRebirths) or 0
            if Config.TargetRebirths ~= 0 and userConfig.BuyOptionalPart2Buttons == nil then
                Config.BuyOptionalPart2Buttons = true
            end
        end
        if pt.AutoTurkey ~= nil then Config.AutoTurkeyBoss = (pt.AutoTurkey == true) end
        if pt.UseUltraForHugeAfterTurkey ~= nil then
            Config.UseUltraForHugeAfterTurkey = (pt.UseUltraForHugeAfterTurkey == true)
        end
    end
    if type(userConfig.Upgrades) == "table" then
        local maxTiers = {}
        local anyUpgrade = false
        for rawKey, maxVal in pairs(userConfig.Upgrades) do
            local cap = math.max(0, math.floor(tonumber(maxVal) or 0))
            local cleanKey = tostring(rawKey):gsub("^PumpkinTycoon", "")
            maxTiers[cleanKey] = cap
            maxTiers[tostring(rawKey)] = cap
            if cap > 0 then anyUpgrade = true end
        end
        Config.UpgradeMaxTiers = maxTiers
        if userConfig.AutoUpgrades == nil then
            Config.AutoUpgrades = anyUpgrade
        end
    end
    if type(userConfig.Lootbox) == "table" then
        Config.Lootbox = userConfig.Lootbox
        if userConfig.AutoOpenGifts == nil then
            Config.AutoOpenGifts = next(userConfig.Lootbox) ~= nil
        end
    end
    if type(userConfig.AutoMail) == "table" then
        local am = userConfig.AutoMail
        Config.AutoMail = (am.Enable == true)
        if am.User ~= nil then
            Config.MailUsernames = am.User
        elseif am.Users ~= nil then
            Config.MailUsernames = am.Users
        end
        if type(am.Items) == "table" then
            Config.MailItems = am.Items
        end
    end
    if type(userConfig.Webhook) == "table" then
        local wh = userConfig.Webhook
        Config.WebhookEnabled = (wh.Enable ~= false)
        Config.HugeWebhookURL = tostring(wh.HugeWebhookURL or "")
        Config.TitanicWebhookURL = tostring(wh.TitanicWebhookURL or "")
        Config.GargantuanWebhookURL = tostring(wh.GargantuanWebhookURL or "")
        Config.DiscordID = tostring(wh.DiscordID or "")
        if (Config.WebhookUrl == nil or Config.WebhookUrl == "") and Config.HugeWebhookURL ~= "" then
            Config.WebhookUrl = Config.HugeWebhookURL
        end
    end

    ApplyConfigDefaults(Config, userConfig)
    ApplyConfigDefaults(Config, DEFAULT_CONFIG)

    local isMobileEnv = false
    pcall(function()
        if type(Delta) == "table" then
            if type(Delta.is_android) == "function" then
                local okA, resA = pcall(Delta.is_android)
                if okA and resA == true then isMobileEnv = true end
            end
            if not isMobileEnv and type(Delta.is_ios) == "function" then
                local okI, resI = pcall(Delta.is_ios)
                if okI and resI == true then isMobileEnv = true end
            end
            if not isMobileEnv and type(Delta.get_platform) == "function" then
                local okP, platStr = pcall(Delta.get_platform)
                if okP and type(platStr) == "string" then
                    local lp = string.lower(platStr)
                    if string.find(lp, "android", 1, true) or string.find(lp, "ios", 1, true) then
                        isMobileEnv = true
                    end
                end
            end
        end
    end)
    if not isMobileEnv then
        pcall(function()
            local uis = game:GetService("UserInputService")
            if uis then
                local okP, plat = pcall(uis.GetPlatform, uis)
                if okP and (plat == Enum.Platform.Android or plat == Enum.Platform.IOS) then
                    isMobileEnv = true
                elseif uis.TouchEnabled == true and uis.KeyboardEnabled ~= true then
                    isMobileEnv = true
                end
            end
        end)
    end
    if not isMobileEnv then
        pcall(function()
            local execName = ""
            if type(identifyexecutor) == "function" then
                execName = tostring(identifyexecutor() or "")
            elseif type(getexecutorname) == "function" then
                execName = tostring(getexecutorname() or "")
            end
            local lowerExec = string.lower(execName)
            for _, marker in ipairs({ "delta", "arceus", "codex", "fluxus", "hydrogen", "vegax", "cryptic" }) do
                if string.find(lowerExec, marker, 1, true) then
                    isMobileEnv = true
                    break
                end
            end
        end)
    end

    if type(Config.UltraLowRAM) == "string" then
        Config.UltraLowRAM = (string.lower(Config.UltraLowRAM) == "auto") and isMobileEnv or (string.lower(Config.UltraLowRAM) == "true")
    else
        Config.UltraLowRAM = (Config.UltraLowRAM == true)
    end
    if type(Config.Debug) == "string" then
        Config.Debug = (string.lower(Config.Debug) == "auto") and (not isMobileEnv) or (string.lower(Config.Debug) == "true")
    else
        Config.Debug = (Config.Debug ~= false)
    end
    if type(Config.ClearTerrainVoxels) == "string" then
        Config.ClearTerrainVoxels = (string.lower(Config.ClearTerrainVoxels) == "auto") and (not isMobileEnv) or (string.lower(Config.ClearTerrainVoxels) == "true")
    else
        Config.ClearTerrainVoxels = (Config.ClearTerrainVoxels == true)
    end

    if Config.UltraLowRAM then
        if not userSet.ShowKaitunUI then
            Config.ShowKaitunUI = true
        end
        if not userSet.FarmLoopInterval then
            Config.FarmLoopInterval = math.max(tonumber(Config.FarmLoopInterval) or 0.10, 0.18)
        end
        if not userSet.HatchCooldown then
            Config.HatchCooldown = math.max(tonumber(Config.HatchCooldown) or 0.02, 0.06)
        end
        if not userSet.TapInterval then
            Config.TapInterval = math.max(tonumber(Config.TapInterval) or 0.065, 0.085)
        end
        if not userSet.WebhookPollInterval then
            Config.WebhookPollInterval = math.max(tonumber(Config.WebhookPollInterval) or 1.0, 3.0)
        end
        if not userSet.CraftCheckIntervalSec then
            Config.CraftCheckIntervalSec = math.max(tonumber(Config.CraftCheckIntervalSec) or 1.0, 2.5)
        end
        if not userSet.OptimizeScanInterval then
            Config.OptimizeScanInterval = math.max(tonumber(Config.OptimizeScanInterval) or 15.0, 20.0)
        end
    end
end
if not Config.Enabled then return end

-- ============================================================================
-- 2. SERVICES & RUNTIME STATE
-- ============================================================================
if not game:IsLoaded() then
    pcall(function()
        game.Loaded:Wait()
    end)
end
while Config.Enabled and not game:IsLoaded() do
    task.wait(0.1)
end
if not Config.Enabled then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = nil
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
while Config.Enabled and not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end
if not Config.Enabled then return end

local SessionToken = HttpService:GenerateGUID(false)
local Connections = {}

local Runtime = {
    Token = SessionToken,
    Running = true,
    Stats = {
        StartTime = os.time(),
        Phase = "Initializing",
        Coins = 0,
        CoinsPerSec = 0,
        Tokens = 0,
        ButtonsDone = 0,
        ButtonsTotal = 0,
        Part1Complete = false,
        Part2Complete = false,
        TycoonComplete = false,
        CompletedClaimed = false,
        Completed2Claimed = false,
        Rebirths = 0,
        IslandLuck = 0,
        ActiveTargetUid = nil,
        ActiveTargetDesc = "None",
        IsHatching = false,
        EggsHatched = 0,
        EarlyEggsHatched = 0,
        GoldCrafted = 0,
        RainbowCrafted = 0,
        ShinyCrafted = 0,
        LockedPedestals = 0,
        MaxKeepSlots = 0,
        TeamPowerWeakest = 0,
        TeamPowerBest = 0,
        GiftsOpened = 0,
        NetsBought = 0,
        WildThrows = 0,
        WildCaught = 0,
        WildHugesCaught = 0,
        SightingsCaught = 0,
        CatchesRank = nil,
        CatchesScore = 0,
        FightingTurkeyBoss = false,
        TurkeyBossShare = 0,
        TurkeyBossHealth = 0,
        TurkeyBossMaxHealth = 0,
        TurkeyBossFights = 0,
        TurkeyBossKills = 0,
        PetSpeedMult = 1,
        AfkPulsesRoblox = 0,
        AfkPulsesP99 = 0,
        BlockedMoveServer = 0,
        BlockedIdleTelemetry = 0,
        MapDestroyedCount = 0,
        VisualsHiddenCount = 0,
        WebhookSent = 0,
        MailSentCount = 0,
        MailFailedCount = 0,
        MailLastFee = 0,
    },
    Cache = {
        IslandBox = nil,
        IslandBoxAt = 0,
        Buttons = nil,
        ButtonsAt = 0,
        CriticalButtons = nil,
        CriticalButtonsPart2 = nil,
        LastComplete2FailAt = 0,
        Complete2Unsupported = false,
        LastRebirthFailAt = 0,
        EggCostCache = {},
        EggEventDmgCache = {},
        EarlyHatchedByEgg = {},
        EarlyCoinsSpentByEgg = {},
        ReserveEarlyEggCost = 0,
        TrackedCoinsSpent = 0,
        CoinRateSamples = {},
        LastCoinRateSampleAt = 0,
        LastGrossCoins = nil,
        CumulativeCoinsEarned = 0,
        LastEquipBestAt = 0,
        TeamPowerSnapshot = nil,
        TeamPowerSnapshotAt = 0,
        BoostConsumeCooldown = {},
        FruitConsumeCooldown = {},
        FruitRejectBackoff = {},
        LastEarlyHatchLogAt = 0,
        LastAutoPlace = nil,
        PetSpeedHookActive = false,
        PetSpeedHookWrapper = nil,
        PetSpeedCreatedConnBound = false,
        PetSpeedLastTargetMult = nil,
        LastPetSpeedRefreshAt = 0,
        AntiAfkHookActive = false,
        AntiAfkEnv = nil,
        IdleTrackingDisabled = false,
        IdleTrackingScript = nil,
        IdleTrackingWatchBound = false,
        NetFireHookTarget = nil,
        LastRobloxAfkPulseAt = 0,
        LastP99AfkPulseAt = 0,
        LastP99SafeResetAt = 0,
        LastMoveServerBlockLogAt = 0,
        SavedLightingState = nil,
        SafeFloorPart = nil,
        MapOptimizerInitialized = false,
        MapClutterClearedInEvent = false,
        Is3dRenderingEnabled = (Config.ShowKaitunUI == false),
        PrevFpsCap = nil,
        PrevTargetFramerate = nil,
        ActiveFpsCap = nil,
        KaitunGuiUsedCoreGui = false,
        PrevNotificationsGuiEnabled = nil,
        PrevEggOpenGuiEnabled = nil,
        EggOpenGuiConnBound = false,
        OrbCreateBatch = {},
        TurkeyRaycastParams = nil,
        TurkeyRaycastFilter = nil,
        TurkeyRaycastShared = nil,
        PlayerCharConns = setmetatable({}, { __mode = "k" }),
        VisualStripQueue = {
            head = 1,
            tail = 0,
            items = {},
            cols = {},
            queued = setmetatable({}, { __mode = "k" }),
            maxSize = 2500,
        },
        VisualStripHbBound = false,
        LastDebrisSweepAt = 0,
        LastConnPruneAt = 0,
        MyIslandResweepToken = 0,
        UltraLowRamApplied = false,
        PrevPotatoMode = nil,
        LastOptimizeScanAt = 0,
        LastButtonsDoneForDecor = -1,
        PlotSavePlot = nil,
        PlotSaveEntries = {},
        PlotSaveConnsBound = {},
        PedInfoVer = -1,
        PedInfoCache = nil,
        TapReachVal = nil,
        TapReachAt = 0,
        TargetEggCache = {},
        TargetEggSig = nil,
        TargetsBufA = {},
        TargetsBufB = {},
        TargetsUseB = false,
        EntryPoolA = {},
        EntryPoolB = {},
        EmergencyScratch = {},
        AllByClassScratch = {},
        LockedPedScratch = {},
        ZonePoolScratch = {},
        PoolByModelScratch = {},
        ClaimedCountScratch = {},
        NeedAssignScratch = {},
        ActiveTargetCopy = {},
        OrbSweepIds = {},
        OrbSweepSeen = {},
        CachedOrbRemote = nil,
        OrbsCreateConnBound = false,
        ItemsUpdateConnBound = false,
        TutorialDonePlot = nil,
        AllUpgradesMaxed = false,
        AllUpgradesMaxedAt = 0,
        GiftEmptyBoxesRef = nil,
        GiftBagDirty = true,
        WebhookInvDirty = true,
        WebhookLastSnapshot = nil,
        WebhookLastContainer = nil,
        WebhookLastInvRef = nil,
        WebhookLastReadAt = 0,
        LastJoinAttemptAt = 0,
        LastTutorialInvokeAt = 0,
        LastPolicyInvokeAt = 0,
        LastCocoaCheckAt = 0,
        LastGiftAttemptAt = 0,
        LastPassCheckAt = 0,
        LastButtonsStepAt = 0,
        ButtonBuyRequestedAt = 0,
        LastButtonBuyFailAt = 0,
        LastKeepLockStepAt = 0,
        LastUpgradesStepAt = 0,
        LastBoostsStepAt = 0,
        LastFruitsStepAt = 0,
        LastGiftsStepAt = 0,
        LastNetStoreStepAt = 0,
        LastNetStoreFailAt = 0,
        LastNetStoreShelfFetchAt = 0,
        LastNetStoreAutoSyncAt = 0,
        LastNetStoreRefreshIn = nil,
        ForceNetStoreShelfFetch = false,
        NetStoreForcePadUntil = 0,
        WarnThrottle = {},
        LastWildStepAt = 0,
        LastWildThrowAt = 0,
        LastWildFailAt = 0,
        LastHuntAutoSyncAt = 0,
        SightingHookBound = false,
        ActiveSighting = nil,
        WildSpeciesMap = nil,
        WildSlotCooldown = {},
        WildRerollActive = false,
        WildRerollSoldOutLogged = false,
        NetStoreShelfCache = nil,
        TurkeyBossActiveEndsAt = 0,
        TurkeyBossEngagedAt = 0,
        TurkeyBossSkippedEndsAt = 0,
        TurkeyBossReturnPos = nil,
        TurkeyBossLastHealth = nil,
        TurkeyBossWatchedWindow = 0,
        TurkeyBossProbedWindow = 0,
        TurkeyBossLastMyDps = 0,
        TurkeyBossTopRaw = nil,
        TurkeyBossTopParsed = nil,
        TurkeyBossOtherShareSum = 0,
        TurkeyBossOtherActiveAt = 0,
        TurkeyBossOtherLiveDps = 0,
        TurkeyBossHpSampleAt = 0,
        TurkeyBossHpSampleVal = nil,
        TurkeyBossRejoinAfterAt = 0,
        TurkeyBossLastPassiveLogAt = 0,
        TurkeyBossLastPassiveLogKey = nil,
        MoveLockUntil = 0,
        MachineSessionDepth = 0,
        HatchYieldUntil = 0,
        HatchInFlight = false,
        LastTeleportAt = 0,
        LastCocoaFailAt = 0,
        LastMerchantFailAt = 0,
        LastCraftCheckAt = 0,
        LastCraftTripAt = 0,
        PendingCraftReadySince = 0,
        CraftFailUntil = { Gold = 0, Rainbow = 0 },
        CraftEventPetSet = nil,
        KaitunGui = nil,
        KaitunUiToken = nil,
        WebhookThumbnails = {},
        WebhookWarnedState = nil,
        MailRecipientIdx = 0,
        MailMessageCooldownUntil = 0,
        MailFailCooldownByKey = {},
        MailPetFirstSeen = {},
        MailLastSkipLogAt = 0,
        MailLastNoRecipientLogAt = 0,
        MailInvDirty = true,
    },
    Helpers = {},
}

local KAITUN_GUI_NAME = "Kaitun_Dashboard_UI"

function Runtime.Helpers.DetectMobileAntiAfk()
    if Runtime.Cache.AntiAfkEnv then return Runtime.Cache.AntiAfkEnv end
    local isTouchOnly = false
    local isMobilePlatform = false
    local platformName = ""
    pcall(function()
        if UserInputService then
            isTouchOnly = (UserInputService.TouchEnabled == true) and (UserInputService.KeyboardEnabled ~= true)
            local okP, plat = pcall(UserInputService.GetPlatform, UserInputService)
            if okP and plat ~= nil then
                platformName = tostring(plat)
                if plat == Enum.Platform.Android or plat == Enum.Platform.IOS then
                    isMobilePlatform = true
                end
            end
        end
    end)
    local isDeltaMobile = false
    pcall(function()
        if type(Delta) == "table" then
            if type(Delta.is_android) == "function" then
                local okA, resA = pcall(Delta.is_android)
                if okA and resA == true then isDeltaMobile = true end
            end
            if not isDeltaMobile and type(Delta.is_ios) == "function" then
                local okI, resI = pcall(Delta.is_ios)
                if okI and resI == true then isDeltaMobile = true end
            end
            if not isDeltaMobile and type(Delta.get_platform) == "function" then
                local okP, platStr = pcall(Delta.get_platform)
                if okP and type(platStr) == "string" then
                    local lp = string.lower(platStr)
                    if string.find(lp, "android", 1, true) or string.find(lp, "ios", 1, true) then
                        isDeltaMobile = true
                    end
                end
            end
        end
    end)
    local execName = ""
    pcall(function()
        if type(identifyexecutor) == "function" then
            execName = tostring(identifyexecutor() or "")
        elseif type(getexecutorname) == "function" then
            execName = tostring(getexecutorname() or "")
        end
    end)
    local lowerExec = string.lower(execName)
    local isMobileExec = false
    for _, marker in ipairs({ "delta", "arceus", "codex", "fluxus", "hydrogen", "vegax", "cryptic" }) do
        if string.find(lowerExec, marker, 1, true) then
            isMobileExec = true
            break
        end
    end
    local envInfo = {
        isTouchOnly = isTouchOnly,
        isMobilePlatform = isMobilePlatform,
        isDeltaMobile = isDeltaMobile,
        isMobileExec = isMobileExec,
        platformName = platformName,
        execName = execName,
        isMobile = isTouchOnly or isMobilePlatform or isDeltaMobile or isMobileExec,
    }
    Runtime.Cache.AntiAfkEnv = envInfo
    return envInfo
end

function Runtime.Helpers.ApplyFpsCap(targetFps)
    local cap = tonumber(targetFps)
    if not cap or cap <= 0 then return false end
    cap = math.clamp(math.floor(cap + 0.5), 5, 240)
    if Runtime.Cache.ActiveFpsCap == cap then return true end
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    if Runtime.Cache.PrevFpsCap == nil then
        local getCapFn = genv.getfpscap or genv.get_fps_cap or getfpscap
        if type(getCapFn) == "function" then
            local okPrev, prevCap = pcall(getCapFn)
            if okPrev and type(prevCap) == "number" and prevCap > 0 then
                Runtime.Cache.PrevFpsCap = prevCap
            end
        end
    end
    local applied = false
    local setCapFn = genv.setfpscap or genv.set_fps_cap or setfpscap
    if type(setCapFn) == "function" then
        local okSet = pcall(setCapFn, cap)
        if okSet then applied = true end
    end
    pcall(function()
        local userSettings = UserSettings and UserSettings()
        local ugs = userSettings and userSettings:GetService("UserGameSettings")
        if ugs and ugs.TargetFramerate ~= nil then
            if Runtime.Cache.PrevTargetFramerate == nil then
                Runtime.Cache.PrevTargetFramerate = ugs.TargetFramerate
            end
            ugs.TargetFramerate = cap
            applied = true
        end
    end)
    if applied then
        Runtime.Cache.ActiveFpsCap = cap
    end
    return applied
end

function Runtime.Helpers.SyncFpsCapFor3d(is3dOn)
    local explicitCap = tonumber(Config.FPSCap) or 0
    if explicitCap > 0 then
        Runtime.Helpers.ApplyFpsCap(explicitCap)
        return
    end
    local envInfo = Runtime.Helpers.DetectMobileAntiAfk()
    if envInfo and envInfo.isMobile then
        local mobileCap = is3dOn
            and (tonumber(Config.MobileFPSCap3dOn) or 25)
            or (tonumber(Config.MobileFPSCap3dOff) or 15)
        if mobileCap > 0 then
            Runtime.Helpers.ApplyFpsCap(mobileCap)
        end
    end
end

function Runtime.Helpers.RestoreFpsCap()
    local prevCap = Runtime.Cache.PrevFpsCap
    local prevTf = Runtime.Cache.PrevTargetFramerate
    Runtime.Cache.ActiveFpsCap = nil
    if type(prevCap) == "number" and prevCap > 0 then
        local genv = (type(getgenv) == "function" and getgenv()) or _G
        local setCapFn = genv.setfpscap or genv.set_fps_cap or setfpscap
        if type(setCapFn) == "function" then
            pcall(setCapFn, prevCap)
        end
        Runtime.Cache.PrevFpsCap = nil
    end
    if prevTf ~= nil then
        pcall(function()
            local userSettings = UserSettings and UserSettings()
            local ugs = userSettings and userSettings:GetService("UserGameSettings")
            if ugs then
                ugs.TargetFramerate = prevTf
            end
        end)
        Runtime.Cache.PrevTargetFramerate = nil
    end
end

local function Set3dRenderingSafe(enabled)
    local active = (enabled == true)
    if Runtime.Cache then
        Runtime.Cache.Is3dRenderingEnabled = active
    end
    pcall(function()
        (RunService :: any):Set3dRenderingEnabled(active)
    end)
    if Runtime.Helpers and Runtime.Helpers.SyncFpsCapFor3d then
        Runtime.Helpers.SyncFpsCapFor3d(active)
    end
    if Runtime.Helpers and Runtime.Helpers.On3dRenderingChanged then
        Runtime.Helpers.On3dRenderingChanged(active)
    end
end

local function DestroyExistingKaitunGui(targetParent)
    if not targetParent then return end
    local existing = targetParent:FindFirstChild(KAITUN_GUI_NAME)
    if existing then
        pcall(existing.Destroy, existing)
    end
end

local function CleanupKaitunDashboard()
    local activeGui = Runtime.Cache and Runtime.Cache.KaitunGui
    if activeGui then
        Runtime.Cache.KaitunGui = nil
        if activeGui.Parent then
            pcall(activeGui.Destroy, activeGui)
        end
    end
    if Runtime.Cache then
        Runtime.Cache.KaitunUiToken = nil
    end
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        DestroyExistingKaitunGui(pg)
    end
    Set3dRenderingSafe(true)
    if Runtime.Helpers and Runtime.Helpers.RestoreFpsCap then
        Runtime.Helpers.RestoreFpsCap()
    end
end

local function IsRunning()
    return Runtime.Running and Config.Enabled and Runtime.Token == SessionToken
end

-- Register an early teardown guard so re-executing during cold boot cancels this waiter.
Runtime.Teardown = function()
    Runtime.Running = false
    for _, conn in ipairs(Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(Connections)
    CleanupKaitunDashboard()
end
getgenv()[GEN_KEY] = Runtime

local function Log(level, fmt, ...)
    if level == "DEBUG" and not Config.Debug then return end
    local ok, text = pcall(string.format, fmt, ...)
    print(string.format("[PumpkinKaitun][%s] %s", level, ok and text or tostring(fmt)))
end

local function LogWarnThrottled(key, cooldownSec, fmt, ...)
    local now = os.clock()
    local bucket = Runtime.Cache and Runtime.Cache.WarnThrottle
    if type(bucket) == "table" and key ~= nil then
        local lastAt = bucket[key] or 0
        if (now - lastAt) < (tonumber(cooldownSec) or 15) then
            Log("DEBUG", fmt, ...)
            return
        end
        bucket[key] = now
    end
    Log("WARN", fmt, ...)
end

local function BindConn(signal, fn)
    if not signal then return nil end
    local conn = signal:Connect(fn)
    table.insert(Connections, conn)
    return conn
end

function Runtime.Helpers.PruneConnections()
    local n = #Connections
    if n == 0 then return 0 end
    local write = 1
    local removed = 0
    for i = 1, n do
        local conn = Connections[i]
        local keep = false
        if conn ~= nil then
            if typeof(conn) == "RBXScriptConnection" then
                keep = conn.Connected
            else
                keep = true
            end
        end
        if keep then
            if write ~= i then
                Connections[write] = conn
            end
            write = write + 1
        else
            removed = removed + 1
        end
    end
    for i = write, n do
        Connections[i] = nil
    end
    return removed
end

-- ============================================================================
-- 3. MODULE RESOLUTION (AUTOEXEC BOOT WAIT)
-- ============================================================================
local function requireModule(inst: Instance): any
    return (require :: any)(inst)
end

local function callWithSavedIdentity(fn: (...any) -> ...any, ...: any): (boolean, any)
    local env = getfenv() :: any
    local getId = env.getthreadidentity or env.getidentity or env.getthreadcontext
    local setId = env.setthreadidentity or env.setidentity or env.setthreadcontext
    local oldId = nil
    if type(getId) == "function" then
        local ok, id = pcall(getId)
        if ok then oldId = id end
    end
    local okCall, result = pcall(fn, ...)
    if oldId ~= nil and type(setId) == "function" then
        pcall(setId, oldId)
    end
    return okCall, result
end

local function GetBootReadiness()
    local lib = ReplicatedStorage:FindFirstChild("Library")
    if not lib then return false, "Library" end
    if lib:GetAttribute("IsLoaded") ~= true then return false, "Library.IsLoaded" end
    if not ReplicatedStorage:FindFirstChild("Assets") then return false, "Assets" end
    local things = Workspace:FindFirstChild("__THINGS")
    if not things or not things:FindFirstChild("Instances") or not things:FindFirstChild("__INSTANCE_CONTAINER") then return false, "Workspace.__THINGS" end
    if LocalPlayer:GetAttribute("__LOADED") ~= true then return false, "LocalPlayer.__LOADED" end
    if not LocalPlayer:FindFirstChild("PlayerGui") then return false, "PlayerGui" end
    local clientFolder = lib:FindFirstChild("Client")
    local saveInst = clientFolder and clientFolder:FindFirstChild("Save")
    if not saveInst then return false, "SaveModule" end
    local okReq, saveMod = pcall(requireModule, saveInst)
    if not okReq or type(saveMod) ~= "table" or type(saveMod.Get) ~= "function" then return false, "SaveApi" end
    local okData, saveData = callWithSavedIdentity(saveMod.Get)
    if not okData or type(saveData) ~= "table" then return false, "SaveData" end
    return true, "Ready"
end

local function WaitBootReady()
    local startAt = os.clock()
    local lastLogAt = 0
    local didWait = false

    while IsRunning() do
        local ready, stage = GetBootReadiness()
        if ready then
            if didWait then
                Log("INFO", "PS99 boot ready in %.1fs; resolving modules.", os.clock() - startAt)
            end
            return true
        end

        didWait = true
        local elapsed = os.clock() - startAt
        if (lastLogAt == 0 and elapsed >= 1.5) or (lastLogAt > 0 and elapsed - lastLogAt >= 15) then
            lastLogAt = elapsed
            Log("INFO", "Waiting for PS99 boot (stage=%s, elapsed=%.1fs)...", tostring(stage), elapsed)
        end
        task.wait(0.25)
    end

    return false
end

if not WaitBootReady() then return end

local Library = ReplicatedStorage:FindFirstChild("Library") or ReplicatedStorage:WaitForChild("Library", 30)

local function SafeRequire(parent, ...)
    local cur = parent
    for _, childName in ipairs({ ... }) do
        if not cur then return nil end
        cur = cur:FindFirstChild(childName) or cur:WaitForChild(childName, 10)
    end
    if not cur then return nil end
    local ok, mod = pcall(requireModule, cur)
    return ok and mod or nil
end

local Modules = {
    -- Core Client & Util
    Network = SafeRequire(Library, "Client", "Network"),
    Signal = SafeRequire(Library, "Signal"),
    Save = SafeRequire(Library, "Client", "Save"),
    FFlags = SafeRequire(Library, "Client", "FFlags") or SafeRequire(Library, "Universal", "FFlags"),
    Variables = SafeRequire(Library, "Variables") or SafeRequire(Library, "Client", "Variables"),
    SettingsCmds = SafeRequire(Library, "Client", "SettingsCmds"),
    CurrencyCmds = SafeRequire(Library, "Client", "CurrencyCmds"),
    BoostCmds = SafeRequire(Library, "Client", "BoostCmds"),
    FruitCmds = SafeRequire(Library, "Client", "FruitCmds"),
    PotionCmds = SafeRequire(Library, "Client", "PotionCmds"),
    EnchantCmds = SafeRequire(Library, "Client", "EnchantCmds"),
    LootboxCmds = SafeRequire(Library, "Client", "LootboxCmds"),
    PresentCmds = SafeRequire(Library, "Client", "PresentCmds"),
    InstancingCmds = SafeRequire(Library, "Client", "InstancingCmds"),
    ClientPlot = SafeRequire(Library, "Client", "PlotCmds", "ClientPlot"),
    BreakableFrontend = SafeRequire(Library, "Client", "BreakableFrontend"),
    AutoFarmCmds = SafeRequire(Library, "Client", "AutoFarmCmds"),
    PlayerPet = SafeRequire(Library, "Client", "PlayerPet"),
    PetCmds = SafeRequire(Library, "Client", "PetCmds"),
    MasteryCmds = SafeRequire(Library, "Client", "MasteryCmds"),
    MachineCmds = SafeRequire(Library, "Client", "MachineCmds"),
    DaycareCmds = SafeRequire(Library, "Client", "DaycareCmds"),
    ExclusiveDaycareCmds = SafeRequire(Library, "Client", "ExclusiveDaycareCmds"),
    TabController = SafeRequire(Library, "Client", "TabController"),
    CustomEggsCmds = SafeRequire(Library, "Client", "CustomEggsCmds"),
    EggCmds = SafeRequire(Library, "Client", "EggCmds"),
    EventUpgradeCmds = SafeRequire(Library, "Client", "EventUpgradeCmds"),
    LootboxLocation = SafeRequire(Library, "Client", "LootboxCmds", "LocationFinder"),
    InventoryCmds = SafeRequire(Library, "Client", "InventoryCmds"),
    GlobalExistCmds = SafeRequire(Library, "Client", "GlobalExistCmds"),
    RAPCmds = SafeRequire(Library, "Client", "RAPCmds"),
    LeaderboardCmds = SafeRequire(Library, "Client", "LeaderboardCmds"),
    Directory = SafeRequire(Library, "Directory"),
    AbstractItem = SafeRequire(Library, "Items", "AbstractItem"),
    PetItem = SafeRequire(Library, "Items", "PetItem"),
    MiscItem = SafeRequire(Library, "Items", "MiscItem"),
    BalancingConstants = SafeRequire(Library, "Balancing", "Constants"),
    MailboxTypes = SafeRequire(Library, "Types", "Mailbox"),

    -- PumpkinTycoon Types & Utils
    PumpkinTycoon = SafeRequire(Library, "Types", "PumpkinTycoon"),
    ButtonsTypes = SafeRequire(Library, "Types", "PumpkinTycoon", "Buttons"),
    ChaseTypes = SafeRequire(Library, "Types", "PumpkinTycoon", "Chase"),
    MerchantTypes = SafeRequire(Library, "Types", "PumpkinTycoon", "Merchant"),
    UpgradesTypes = SafeRequire(Library, "Types", "PumpkinTycoon", "Upgrades"),
    WildTypes = SafeRequire(Library, "Types", "PumpkinTycoon", "Wild"),
    LootboxTypes = SafeRequire(Library, "Types", "Lootboxes"),

    PumpkinButtonsUtil = SafeRequire(Library, "Util", "PumpkinTycoonButtons"),
    PumpkinUpgradesUtil = SafeRequire(Library, "Util", "PumpkinTycoonUpgrades"),
    PumpkinBoostsUtil = SafeRequire(Library, "Util", "PumpkinTycoonBoosts"),
    PumpkinCocoaUtil = SafeRequire(Library, "Util", "PumpkinTycoonCocoa"),
    PumpkinDamageUtil = SafeRequire(Library, "Util", "PumpkinTycoonDamage"),
    PumpkinEarnUtil = SafeRequire(Library, "Util", "PumpkinTycoonEarn"),
    PumpkinGiftUtil = SafeRequire(Library, "Util", "PumpkinTycoonGift"),
    PumpkinWildUtil = SafeRequire(Library, "Util", "PumpkinTycoonWild"),
    PumpkinStoreUtil = SafeRequire(Library, "Util", "PumpkinTycoonStore"),
    PumpkinSightingUtil = SafeRequire(Library, "Util", "PumpkinTycoonSighting"),
    PumpkinTurkeyUtil = SafeRequire(Library, "Util", "PumpkinTycoonTurkey"),
    PumpkinContestsUtil = SafeRequire(Library, "Util", "PumpkinTycoonContests"),
    PumpkinIslandCmds = SafeRequire(Library, "Client", "PumpkinTycoonCmds", "Island"),
    PumpkinTurkeyCmds = SafeRequire(Library, "Client", "PumpkinTycoonCmds", "Turkey"),

    -- Optional Event Pass
    EventPassTypes = SafeRequire(Library, "Types", "EventPass"),
    EventPassUtil = SafeRequire(Library, "Util", "EventPassUtil"),
}

-- EventCmds submodules (loaded via PumpkinTycoonCmds if available)
local PT_Cmds = SafeRequire(Library, "Client", "PumpkinTycoonCmds")
local PT_Buttons = PT_Cmds and SafeRequire(Library, "Client", "PumpkinTycoonCmds", "Buttons")
local PT_AutoBreak = PT_Cmds and SafeRequire(Library, "Client", "PumpkinTycoonCmds", "AutoBreak")

local CRITICAL_MODULE_PATHS = {
    Network = { "Client", "Network" },
    Save = { "Client", "Save" },
    FFlags = { "Client", "FFlags" },
    Directory = { "Directory" },
    InstancingCmds = { "Client", "InstancingCmds" },
    ClientPlot = { "Client", "PlotCmds", "ClientPlot" },
    MachineCmds = { "Client", "MachineCmds" },
    PetCmds = { "Client", "PetCmds" },
    PetItem = { "Items", "PetItem" },
    PumpkinTycoon = { "Types", "PumpkinTycoon" },
    PumpkinButtonsUtil = { "Util", "PumpkinTycoonButtons" },
    PumpkinDamageUtil = { "Util", "PumpkinTycoonDamage" },
    PumpkinStoreUtil = { "Util", "PumpkinTycoonStore" },
}

local function ResolveEventCmdsSubmodules()
    if not PT_Cmds then
        PT_Cmds = SafeRequire(Library, "Client", "PumpkinTycoonCmds")
    end
    if PT_Cmds and not PT_Buttons then
        PT_Buttons = SafeRequire(Library, "Client", "PumpkinTycoonCmds", "Buttons")
    end
    if PT_Cmds and not PT_AutoBreak then
        PT_AutoBreak = SafeRequire(Library, "Client", "PumpkinTycoonCmds", "AutoBreak")
    end
end

local function CollectMissingCriticalModules()
    local missing = {}
    for key, path in pairs(CRITICAL_MODULE_PATHS) do
        if not Modules[key] then
            Modules[key] = SafeRequire(Library, table.unpack(path))
            if not Modules[key] and key == "FFlags" then
                Modules[key] = SafeRequire(Library, "Universal", "FFlags")
            end
        end
        if not Modules[key] then
            table.insert(missing, key)
        end
    end
    ResolveEventCmdsSubmodules()
    if not PT_Cmds then
        table.insert(missing, "PumpkinTycoonCmds")
    end
    return missing
end

local function WaitForFFlagsLoaded(timeoutSec)
    local ff = Modules.FFlags
    if not ff or type(ff.IsLoaded) ~= "function" then return end
    local deadline = os.clock() + (tonumber(timeoutSec) or 6.0)
    while IsRunning() and os.clock() < deadline do
        local ok, loaded = pcall(ff.IsLoaded)
        if ok and loaded == true then return end
        task.wait(0.15)
    end
end

local function EnsureCriticalModules()
    local missing = CollectMissingCriticalModules()
    if #missing == 0 then
        WaitForFFlagsLoaded(6.0)
        return true
    end

    for _ = 1, 6 do
        if not IsRunning() then return false end
        task.wait(0.5)
        missing = CollectMissingCriticalModules()
        if #missing == 0 then
            WaitForFFlagsLoaded(6.0)
            return true
        end
    end

    table.sort(missing)
    Log("WARN", "Some modules failed to resolve after boot: %s", table.concat(missing, ", "))
    WaitForFFlagsLoaded(3.0)
    return false
end

EnsureCriticalModules()
if not IsRunning() then return end

local NET_FIRE_HOOK_KEY = "_PumpkinTycoonKaitun_NetFireHookTarget"

function Runtime.Helpers.GetEffectiveAntiAfkStrategy()
    local envInfo = Runtime.Helpers.DetectMobileAntiAfk()
    local mode = string.lower(tostring(Config.AntiAfkMode or "auto"))
    if mode ~= "safe" and mode ~= "hook" then
        mode = "auto"
    end
    if not Config.AntiAFK or not Config.AntiAFKP99 then return mode, envInfo, false end
    local idleDisabled = (Runtime.Cache.IdleTrackingDisabled == true)
    local useHookFallback = (mode == "hook") or (mode == "auto" and not envInfo.isMobile and not idleDisabled)
    return mode, envInfo, useHookFallback
end

local function PulseRobloxAntiAfk()
    if not VirtualUser then return false end
    local ok = pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)
    if ok then
        Runtime.Cache.LastRobloxAfkPulseAt = os.clock()
        Runtime.Stats.AfkPulsesRoblox = (Runtime.Stats.AfkPulsesRoblox or 0) + 1
    end
    return ok
end

local function PulseP99AntiAfk()
    local _, _, useHookFallback = Runtime.Helpers.GetEffectiveAntiAfkStrategy()
    if not useHookFallback then return false end
    if not VirtualInputManager then
        local okVim, svc = pcall(game.GetService, game, "VirtualInputManager")
        if okVim and svc then
            VirtualInputManager = svc
        end
    end
    if not VirtualInputManager or not VirtualInputManager.SendKeyEvent then return false end
    if UserInputService and UserInputService.GetFocusedTextBox then
        local okTb, focusedBox = pcall(UserInputService.GetFocusedTextBox, UserInputService)
        if okTb and focusedBox ~= nil then return false end
    end
    local ok = pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
    end)
    if ok then
        Runtime.Cache.LastP99AfkPulseAt = os.clock()
        Runtime.Stats.AfkPulsesP99 = (Runtime.Stats.AfkPulsesP99 or 0) + 1
    end
    return ok
end

function Runtime.Helpers.PulseP99SafeIdleReset(isMobile)
    local net = Modules.Network
    if not net or type(net.Fire) ~= "function" then return false end
    local inputVal = isMobile and 7 or 0
    if Config.SpoofIdleFocusTrue then
        pcall(net.Fire, "Idle Tracking: Focus Changed", true)
    end
    local okStop = pcall(net.Fire, "Idle Tracking: Stop Timer", inputVal)
    if okStop then
        Runtime.Cache.LastP99SafeResetAt = os.clock()
        Runtime.Stats.AfkPulsesP99 = (Runtime.Stats.AfkPulsesP99 or 0) + 1
    end
    return okStop
end

local function RestoreAntiAfkNetworkHook()
    local rec = getgenv()[NET_FIRE_HOOK_KEY]
    if type(rec) == "table" then
        rec.enabled = false
        rec.runtime = nil
        rec.token = nil
        rec.config = nil
        rec.log = nil
        local hookedTarget = rec.target or Runtime.Cache.NetFireHookTarget
        local unhooked = false
        if hookedTarget and type(restorefunction) == "function" then
            local shouldRestore = true
            if type(isfunctionhooked) == "function" then
                local okH, hooked = pcall(isfunctionhooked, hookedTarget)
                shouldRestore = okH and (hooked == true)
            end
            if shouldRestore then
                local okR = pcall(restorefunction, hookedTarget)
                if okR then
                    if type(isfunctionhooked) == "function" then
                        local okH2, stillHooked = pcall(isfunctionhooked, hookedTarget)
                        unhooked = (not okH2) or (stillHooked ~= true)
                    else
                        unhooked = true
                    end
                end
            else
                unhooked = true
            end
        end
        if unhooked then
            getgenv()[NET_FIRE_HOOK_KEY] = nil
        end
    elseif rec then
        if type(restorefunction) == "function" then
            pcall(restorefunction, rec)
        end
        getgenv()[NET_FIRE_HOOK_KEY] = nil
    elseif Runtime.Cache.NetFireHookTarget and type(restorefunction) == "function" then
        pcall(restorefunction, Runtime.Cache.NetFireHookTarget)
    end
    Runtime.Cache.AntiAfkHookActive = false
    Runtime.Cache.NetFireHookTarget = nil
end

function Runtime.Helpers.DisableIdleScriptInstance(idleScript)
    if not idleScript or not (idleScript:IsA("LocalScript") or idleScript:IsA("Script")) then return false end
    pcall(function()
        idleScript.Disabled = true
    end)
    pcall(function()
        idleScript.Enabled = false
    end)
    local isDisabled = false
    local okCheck, resCheck = pcall(function()
        return idleScript.Disabled == true or idleScript.Enabled == false
    end)
    if okCheck then
        isDisabled = (resCheck == true)
    end
    if isDisabled then
        if Runtime.Cache.IdleTrackingScript ~= idleScript then
            Runtime.Cache.IdleTrackingScript = idleScript
            BindConn(idleScript:GetPropertyChangedSignal("Enabled"), function()
                if IsRunning() and Config.AntiAFK and Config.AntiAFKP99 and idleScript.Enabled then
                    pcall(function()
                        idleScript.Disabled = true
                        idleScript.Enabled = false
                    end)
                end
            end)
        end
        Runtime.Cache.IdleTrackingDisabled = true
        local mode = Runtime.Helpers.GetEffectiveAntiAfkStrategy()
        if mode == "auto" and Runtime.Cache.AntiAfkHookActive then
            RestoreAntiAfkNetworkHook()
        end
    end
    return isDisabled
end

function Runtime.Helpers.TryDisableIdleTracking()
    local ps = LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
    local scriptsFolder = ps and ps:FindFirstChild("Scripts")
    local coreFolder = scriptsFolder and scriptsFolder:FindFirstChild("Core")
    local idleScript = coreFolder and coreFolder:FindFirstChild("Idle Tracking")
    if idleScript and Runtime.Helpers.DisableIdleScriptInstance(idleScript) then return true end

    if not Runtime.Cache.IdleTrackingWatchBound and LocalPlayer then
        Runtime.Cache.IdleTrackingWatchBound = true
        local function attachCoreWatcher(core)
            if not core then return end
            BindConn(core.ChildAdded, function(child)
                if IsRunning() and Config.AntiAFK and Config.AntiAFKP99 and child and child.Name == "Idle Tracking" then
                    if Runtime.Helpers.DisableIdleScriptInstance(child) then
                        Log("INFO", "Disabled late-loaded Idle Tracking script.")
                    end
                end
            end)
        end
        local function attachScriptsWatcher(scripts)
            if not scripts then return end
            local c = scripts:FindFirstChild("Core")
            if c then
                attachCoreWatcher(c)
                local idle = c:FindFirstChild("Idle Tracking")
                if idle then
                    Runtime.Helpers.DisableIdleScriptInstance(idle)
                end
            else
                BindConn(scripts.ChildAdded, function(child)
                    if IsRunning() and child and child.Name == "Core" then
                        attachCoreWatcher(child)
                        local idle = child:FindFirstChild("Idle Tracking")
                        if idle then
                            Runtime.Helpers.DisableIdleScriptInstance(idle)
                        end
                    end
                end)
            end
        end
        local function attachPlayerScriptsWatcher(playerScripts)
            if not playerScripts then return end
            local s = playerScripts:FindFirstChild("Scripts")
            if s then
                attachScriptsWatcher(s)
            else
                BindConn(playerScripts.ChildAdded, function(child)
                    if IsRunning() and child and child.Name == "Scripts" then
                        attachScriptsWatcher(child)
                    end
                end)
            end
        end
        if ps then
            attachPlayerScriptsWatcher(ps)
        else
            BindConn(LocalPlayer.ChildAdded, function(child)
                if IsRunning() and child and child.Name == "PlayerScripts" then
                    attachPlayerScriptsWatcher(child)
                end
            end)
        end
    end
    return Runtime.Cache.IdleTrackingDisabled == true
end

local function EnsureAntiAfkNetworkHook()
    local _, envInfo, useHookFallback = Runtime.Helpers.GetEffectiveAntiAfkStrategy()
    if not useHookFallback then
        if Runtime.Cache.AntiAfkHookActive then
            RestoreAntiAfkNetworkHook()
        end
        return
    end
    if not envInfo.isMobile and type(getconnections) == "function" then
        pcall(function()
            for _, conn in ipairs(getconnections(RunService.RenderStepped)) do
                local fn = conn and conn.Function
                if fn and debug and debug.getinfo then
                    local okInfo, info = pcall(debug.getinfo, fn)
                    local src = (okInfo and info and info.source) or ""
                    if string.find(src, "Idle Tracking", 1, true) then
                        if conn.Disable then
                            conn:Disable()
                        elseif conn.Disconnect then
                            conn:Disconnect()
                        end
                    end
                end
            end
        end)
    end
    local net = Modules.Network
    if not net or type(net.Fire) ~= "function" or type(hookfunction) ~= "function" then return end
    if Runtime.Cache.AntiAfkHookActive and Runtime.Cache.NetFireHookTarget == net.Fire then return end

    local existingRec = getgenv()[NET_FIRE_HOOK_KEY]
    if type(existingRec) == "table" and existingRec.installed == true and type(existingRec.orig) == "function" and existingRec.target == net.Fire then
        existingRec.runtime = Runtime
        existingRec.token = SessionToken
        existingRec.config = Config
        existingRec.log = Log
        existingRec.enabled = true
        Runtime.Cache.NetFireHookTarget = net.Fire
        Runtime.Cache.AntiAfkHookActive = true
        Log("INFO", "PS99 Anti-AFK fallback hook re-armed.")
        return
    end

    if type(isfunctionhooked) == "function" and type(restorefunction) == "function" then
        local okH, hooked = pcall(isfunctionhooked, net.Fire)
        if okH and hooked then
            pcall(restorefunction, net.Fire)
        end
    end

    local hookRec = {
        installed = false,
        enabled = true,
        runtime = Runtime,
        token = SessionToken,
        config = Config,
        log = Log,
        target = net.Fire,
        orig = nil,
    }
    local wrapper = function(eventName, ...)
        local origFire = hookRec.orig
        local rt = hookRec.runtime
        local cfg = hookRec.config
        local logFn = hookRec.log
        if hookRec.enabled and rt and rt.Running and rt.Token == hookRec.token and cfg and cfg.AntiAFK and cfg.AntiAFKP99 then
            if cfg.BlockNativeMoveServer and eventName == "Move Server" then
                rt.Stats.BlockedMoveServer = (rt.Stats.BlockedMoveServer or 0) + 1
                local now = os.clock()
                if now - (rt.Cache.LastMoveServerBlockLogAt or 0) >= 15 then
                    rt.Cache.LastMoveServerBlockLogAt = now
                    if logFn then
                        logFn("INFO", "Blocked PS99 AFK Move Server (#%d).", rt.Stats.BlockedMoveServer)
                    end
                end
                return
            elseif cfg.BlockNativeMoveServer and (eventName == "Idle Tracking: Engine Idle" or eventName == "Idle Tracking: Update Timer") then
                rt.Stats.BlockedIdleTelemetry = (rt.Stats.BlockedIdleTelemetry or 0) + 1
                return
            elseif cfg.SpoofIdleFocusTrue and eventName == "Idle Tracking: Focus Changed" then
                return origFire(eventName, true)
            end
        end
        return origFire(eventName, ...)
    end

    local hookedClosure = type(newcclosure) == "function" and newcclosure(wrapper) or wrapper
    local ok, prev = pcall(hookfunction, net.Fire, hookedClosure)
    if ok and type(prev) == "function" then
        hookRec.orig = prev
        hookRec.installed = true
        Runtime.Cache.NetFireHookTarget = net.Fire
        Runtime.Cache.AntiAfkHookActive = true
        getgenv()[NET_FIRE_HOOK_KEY] = hookRec
        Log("INFO", "PS99 Idle Tracking & Move Server PC fallback hook enabled.")
    else
        Log("DEBUG", "Failed to hook Network.Fire for PS99 Anti-AFK: %s", tostring(prev))
    end
end

local function SetupAntiAfk()
    if not Config.AntiAFK then
        RestoreAntiAfkNetworkHook()
        return
    end

    local mode, envInfo = Runtime.Helpers.GetEffectiveAntiAfkStrategy()
    local idleDisabled = Runtime.Helpers.TryDisableIdleTracking()
    local _, _, useHookFallback = Runtime.Helpers.GetEffectiveAntiAfkStrategy()

    if useHookFallback then
        EnsureAntiAfkNetworkHook()
    else
        RestoreAntiAfkNetworkHook()
    end

    Log("INFO", "Anti-AFK ready (mode=%s, mobile=%s, idleDisabled=%s, hookFallback=%s).",
        tostring(mode),
        tostring(envInfo.isMobile),
        tostring(idleDisabled),
        tostring(useHookFallback))

    BindConn(LocalPlayer.Idled, function()
        if not IsRunning() or not Config.AntiAFK then return end
        if Config.AntiAFKRoblox then
            PulseRobloxAntiAfk()
        end
        if Config.AntiAFKP99 then
            Runtime.Helpers.PulseP99SafeIdleReset(envInfo.isMobile)
        end
    end)

    task.spawn(function()
        if Config.AntiAFKRoblox then
            PulseRobloxAntiAfk()
        end
        if Config.AntiAFKP99 then
            Runtime.Helpers.PulseP99SafeIdleReset(envInfo.isMobile)
            if useHookFallback then
                PulseP99AntiAfk()
            end
        end

        while IsRunning() do
            local _, curEnv, curHookFallback = Runtime.Helpers.GetEffectiveAntiAfkStrategy()
            task.wait(curHookFallback and 1 or 5)
            if not IsRunning() then break end
            if not Runtime.Cache.IdleTrackingDisabled then
                Runtime.Helpers.TryDisableIdleTracking()
            end
            _, curEnv, curHookFallback = Runtime.Helpers.GetEffectiveAntiAfkStrategy()
            if curHookFallback then
                EnsureAntiAfkNetworkHook()
            elseif Runtime.Cache.AntiAfkHookActive then
                RestoreAntiAfkNetworkHook()
            end

            local now = os.clock()
            if Config.AntiAFK and Config.AntiAFKP99 and curHookFallback then
                local p99Interval = math.max(1, tonumber(Config.AntiAFKP99PulseInterval) or 6.5)
                if now - (Runtime.Cache.LastP99AfkPulseAt or 0) >= p99Interval then
                    PulseP99AntiAfk()
                end
            end
            if Config.AntiAFK then
                local rbxInterval = math.max(10, tonumber(Config.AntiAFKRobloxPulseInterval) or 45)
                if Config.AntiAFKRoblox and (now - (Runtime.Cache.LastRobloxAfkPulseAt or 0)) >= rbxInterval then
                    PulseRobloxAntiAfk()
                end
                if Config.AntiAFKP99 and (now - (Runtime.Cache.LastP99SafeResetAt or 0)) >= rbxInterval then
                    Runtime.Helpers.PulseP99SafeIdleReset(curEnv.isMobile)
                end
            end
        end
    end)
end

local function DisableNativeAutoFarmOnce()
    local af = Modules.AutoFarmCmds
    if af and af.IsEnabled and af.Disable then
        local okE, enabled = pcall(af.IsEnabled)
        if okE and enabled == true then
            pcall(af.Disable)
        end
    end
end

local function ReleaseHeldPets()
    if not Modules.PlayerPet or not Modules.PlayerPet.GetByPlayer then return end
    local releasedAny = false
    pcall(function()
        for _, pet in pairs(Modules.PlayerPet.GetByPlayer(LocalPlayer)) do
            if pet and pet.AIHold == "PumpkinKaitun" then
                pet.AIHold = nil
                releasedAny = true
            end
        end
    end)
    if releasedAny and Modules.Signal and Modules.Signal.Fire then
        pcall(Modules.Signal.Fire, "PetAI_Reset")
    end
end

local ORIG_PET_SPEED_KEY = "_PumpkinTycoonKaitun_OrigCalcPetSpeed"
local HOOK_PET_SPEED_KEY = "_PumpkinTycoonKaitun_HookCalcPetSpeed"

local function RefreshLocalPetSpeeds(useOriginalCalc)
    local pp = Modules.PlayerPet
    if not pp or not pp.GetByPlayer then return 0 end
    local okPets, pets = pcall(pp.GetByPlayer, LocalPlayer)
    if not okPets or type(pets) ~= "table" then return 0 end

    local updated = 0
    local sampleMult = nil
    local targetMult = (not useOriginalCalc and Config.AutoBuffPetSpeed)
        and math.max(1, tonumber(Config.PetSpeedMultiplier) or 999)
        or nil

    for _, pet in pairs(pets) do
        if pet and not pet.destroyed then
            local mult = targetMult
            if not mult and type(pet.CalculateSpeedMultiplier) == "function" then
                local okM, calc = pcall(pet.CalculateSpeedMultiplier, pet)
                if okM and type(calc) == "number" and calc > 0 then
                    mult = calc
                end
            end
            if type(mult) == "number" and mult > 0 then
                sampleMult = mult
                if pet.speedMult ~= mult then
                    pet.speedMult = mult
                    updated = updated + 1
                end
                if pet.cpet and type(pet.cpet.Broadcast) == "function" then
                    local curIn = type(pet.cpet.parallelIn) == "table" and pet.cpet.parallelIn.petSpeedMult or nil
                    if curIn ~= mult then
                        pcall(pet.cpet.Broadcast, pet.cpet, "petSpeedMult", mult)
                    end
                end
            end
        end
    end
    if sampleMult ~= nil then
        Runtime.Stats.PetSpeedMult = sampleMult
    elseif targetMult ~= nil then
        Runtime.Stats.PetSpeedMult = targetMult
    end
    Runtime.Cache.LastPetSpeedRefreshAt = os.clock()
    return updated
end

local function RestorePetSpeedBuff()
    local pp = Modules.PlayerPet
    local env = getgenv()
    local orig = env[ORIG_PET_SPEED_KEY]
    local myWrapper = Runtime.Cache.PetSpeedHookWrapper
    if pp and type(orig) == "function" and (pp.CalculateSpeedMultiplier == myWrapper or pp.CalculateSpeedMultiplier == env[HOOK_PET_SPEED_KEY]) then
        local wasFrozen = type(table.isfrozen) == "function" and table.isfrozen(pp)
        if wasFrozen and type(setreadonly) == "function" then
            pcall(setreadonly, pp, false)
        end
        pcall(function()
            pp.CalculateSpeedMultiplier = orig
        end)
        if wasFrozen and type(setreadonly) == "function" then
            pcall(setreadonly, pp, true)
        end
    end
    if myWrapper ~= nil and env[HOOK_PET_SPEED_KEY] == myWrapper then
        env[HOOK_PET_SPEED_KEY] = nil
    end
    Runtime.Cache.PetSpeedHookActive = false
    Runtime.Cache.PetSpeedHookWrapper = nil
    Runtime.Cache.PetSpeedLastTargetMult = nil
    RefreshLocalPetSpeeds(true)
end

local function StepPetSpeedBuff()
    local pp = Modules.PlayerPet
    if not pp or type(pp.CalculateSpeedMultiplier) ~= "function" then return end
    local env = getgenv()
    local orig = env[ORIG_PET_SPEED_KEY]
    if type(orig) ~= "function" and pp.CalculateSpeedMultiplier ~= env[HOOK_PET_SPEED_KEY] then
        orig = pp.CalculateSpeedMultiplier
        env[ORIG_PET_SPEED_KEY] = orig
    end
    if type(orig) ~= "function" then return end

    if not Config.AutoBuffPetSpeed then
        if Runtime.Cache.PetSpeedHookActive or pp.CalculateSpeedMultiplier == env[HOOK_PET_SPEED_KEY] then
            RestorePetSpeedBuff()
        end
        return
    end

    if not Runtime.Cache.PetSpeedCreatedConnBound and pp.Created and pp.Created.Connect then
        Runtime.Cache.PetSpeedCreatedConnBound = true
        BindConn(pp.Created, function(pet)
            if not IsRunning() or not Config.AutoBuffPetSpeed then return end
            task.defer(function()
                if not IsRunning() or not Config.AutoBuffPetSpeed or not pet or pet.destroyed or pet.owner ~= LocalPlayer then return end
                local targetMult = math.max(1, tonumber(Config.PetSpeedMultiplier) or 999)
                if pet.speedMult ~= targetMult then
                    pet.speedMult = targetMult
                end
                if pet.cpet and type(pet.cpet.Broadcast) == "function" then
                    local curIn = type(pet.cpet.parallelIn) == "table" and pet.cpet.parallelIn.petSpeedMult or nil
                    if curIn ~= targetMult then
                        pcall(pet.cpet.Broadcast, pet.cpet, "petSpeedMult", targetMult)
                    end
                end
                Runtime.Stats.PetSpeedMult = targetMult
            end)
        end)
    end

    local targetMult = math.max(1, tonumber(Config.PetSpeedMultiplier) or 999)
    local myWrapper = Runtime.Cache.PetSpeedHookWrapper
    local needAttach = (type(myWrapper) ~= "function")
        or (pp.CalculateSpeedMultiplier ~= myWrapper)
        or (not Runtime.Cache.PetSpeedHookActive)
    if needAttach then
        myWrapper = function(petSelf, ...)
            if IsRunning() and Config.AutoBuffPetSpeed and petSelf and petSelf.owner == LocalPlayer then
                local cfgMult = tonumber(Config.PetSpeedMultiplier)
                if cfgMult and cfgMult > 0 then return cfgMult end
            end
            return orig(petSelf, ...)
        end
        env[HOOK_PET_SPEED_KEY] = myWrapper
        local wasFrozen = type(table.isfrozen) == "function" and table.isfrozen(pp)
        if wasFrozen and type(setreadonly) == "function" then
            pcall(setreadonly, pp, false)
        end
        local okSet = pcall(function()
            pp.CalculateSpeedMultiplier = myWrapper
        end)
        if wasFrozen and type(setreadonly) == "function" then
            pcall(setreadonly, pp, true)
        end
        if okSet then
            Runtime.Cache.PetSpeedHookWrapper = myWrapper
            Runtime.Cache.PetSpeedHookActive = true
            Runtime.Cache.PetSpeedLastTargetMult = targetMult
            Log("INFO", "Pet speed buff hook enabled (mult=%s).", tostring(targetMult))
            RefreshLocalPetSpeeds(false)
        end
        return
    end

    local now = os.clock()
    if Runtime.Cache.PetSpeedLastTargetMult ~= targetMult or (now - (Runtime.Cache.LastPetSpeedRefreshAt or 0)) >= 3.0 then
        Runtime.Cache.PetSpeedLastTargetMult = targetMult
        RefreshLocalPetSpeeds(false)
    end
end

-- ============================================================================
-- 3C. MAP & RENDER OPTIMIZER (METHOD B STRUCTURAL + CONDITIONAL BOUNDED 3D QUEUE)
-- ============================================================================
local SAFE_FLOOR_NAME = "_PumpkinKaitun_SafeFloor"
local OPTIMIZER_EVENT_ID = "PumpkinTycoon"
local WORLD_CLUTTER_NAMES = {
    ["PSX Portal"] = true,
    ["Border"] = true,
    ["PSX Hall"] = true,
    ["FlyBorder"] = true,
    ["GREYBOX_WIP"] = true,
    ["Tiles"] = true,
    ["__INSTANCE_SCENERY"] = true,
}
local DEBRIS_PRESERVE_NAMES = {
    PERSISTENT = true,
    TravelingMerchant = true,
    Currency = true,
    GREYBOX_WIP = true,
    Ragdolls = true,
    ASSETS = true,
    TurkeyTag = true,
}
local THINGS_CLEAR_FOLDERS = {
    "Ornaments",
    "Ski Chairs",
    "BalloonGifts",
    "Hoverboards",
    "InfinityEggs",
    "VictoryScene",
    "__FAKE_INSTANCE_BREAK_ZONES",
}

local TrackedContainers = setmetatable({}, { __mode = "k" })
local HookedContainers = setmetatable({}, { __mode = "k" })

local function TrackContainer(container)
    if not container or TrackedContainers[container] then return end
    TrackedContainers[container] = true
    BindConn(container.Destroying, function()
        TrackedContainers[container] = nil
        HookedContainers[container] = nil
    end)
end

local function DestroyClutterInstance(inst, defer)
    if not inst or not inst.Parent or inst.Name == SAFE_FLOOR_NAME or inst == Workspace then return end
    Runtime.Stats.MapDestroyedCount = (Runtime.Stats.MapDestroyedCount or 0) + 1
    if defer then
        task.defer(function()
            if inst and inst.Parent then
                pcall(inst.Destroy, inst)
            end
        end)
    else
        pcall(inst.Destroy, inst)
    end
end

local function StripVisualObject(obj, stripCollision)
    if not obj or not obj.Parent or obj.Name == SAFE_FLOOR_NAME then return end
    if obj.Name == "Highlight" and obj.Parent and obj.Parent.Name == "RenderedEggs" then return end
    if obj:IsA("BasePart") then
        local changed = false
        if obj.Transparency < 1 then
            obj.Transparency = 1
            changed = true
        end
        if obj.CastShadow then
            obj.CastShadow = false
        end
        if obj.Material ~= Enum.Material.SmoothPlastic then
            obj.Material = Enum.Material.SmoothPlastic
        end
        if stripCollision then
            if obj.CanCollide then
                obj.CanCollide = false
            end
            if obj.CanTouch then
                obj.CanTouch = false
            end
            if obj.CanQuery then
                obj.CanQuery = false
            end
        end
        if changed then
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
        return
    end

    if obj:IsA("SurfaceAppearance") then
        Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        DestroyClutterInstance(obj, false)
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        if obj.Transparency < 1 then
            obj.Transparency = 1
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
    elseif obj:IsA("ParticleEmitter") then
        if obj.Enabled or obj.Rate > 0 then
            obj.Enabled = false
            obj.Rate = 0
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
    elseif obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
        if obj.Enabled then
            obj.Enabled = false
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
    elseif obj:IsA("Light") then
        if obj.Enabled or obj.Brightness > 0 then
            obj.Enabled = false
            obj.Brightness = 0
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
    elseif obj:IsA("Highlight") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
        if obj.Enabled then
            obj.Enabled = false
            Runtime.Stats.VisualsHiddenCount = (Runtime.Stats.VisualsHiddenCount or 0) + 1
        end
    end
end

local function StripLocalCharacterFx(charModel)
    if not charModel then return end
    for _, d in ipairs(charModel:GetDescendants()) do
        if d:IsA("BasePart") then
            if d.CastShadow then
                d.CastShadow = false
            end
        elseif d:IsA("ParticleEmitter") then
            d.Enabled = false
            d.Rate = 0
        elseif d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
            d.Enabled = false
        elseif d:IsA("Light") then
            d.Enabled = false
            d.Brightness = 0
        end
    end
end

function Runtime.Helpers.ClearVisualQueue()
    local q = Runtime.Cache.VisualStripQueue
    if type(q) ~= "table" then return end
    table.clear(q.items)
    table.clear(q.cols)
    table.clear(q.queued)
    q.head = 1
    q.tail = 0
end

function Runtime.Helpers.EnsureVisualStripHeartbeat()
    if Runtime.Cache.VisualStripHbBound then return end
    Runtime.Cache.VisualStripHbBound = true
    BindConn(RunService.Heartbeat, function()
        local q = Runtime.Cache.VisualStripQueue
        if not q or q.head > q.tail then return end
        if not IsRunning() or not Config.OptimizeMap or not Runtime.Cache.Is3dRenderingEnabled then
            Runtime.Helpers.ClearVisualQueue()
            return
        end

        local startAt = os.clock()
        local processed = 0
        local maxOps = 120
        while q.head <= q.tail and processed < maxOps do
            local idx = q.head
            local inst = q.items[idx]
            local stripCol = q.cols[idx] == true
            q.items[idx] = nil
            q.cols[idx] = nil
            q.head = idx + 1

            if inst and inst.Parent and inst.Name ~= SAFE_FLOOR_NAME then
                StripVisualObject(inst, stripCol)
                for _, child in ipairs(inst:GetChildren()) do
                    if not q.queued[child] and (q.tail - q.head + 1) < (q.maxSize or 2500) then
                        q.tail = q.tail + 1
                        q.items[q.tail] = child
                        q.cols[q.tail] = stripCol
                        q.queued[child] = true
                    end
                end
            end
            processed = processed + 1
            if processed >= 24 and (os.clock() - startAt) >= 0.0015 then break end
        end

        if q.head > q.tail then
            q.head = 1
            q.tail = 0
            table.clear(q.queued)
        end
    end)
end

function Runtime.Helpers.EnqueueVisualStrip(inst, stripCollision)
    if not IsRunning() or not Config.OptimizeMap or not Runtime.Cache.Is3dRenderingEnabled then return end
    if not inst or not inst.Parent or inst.Name == SAFE_FLOOR_NAME then return end
    local q = Runtime.Cache.VisualStripQueue
    if not q or q.queued[inst] then return end
    if (q.tail - q.head + 1) >= (q.maxSize or 2500) then return end
    Runtime.Helpers.EnsureVisualStripHeartbeat()
    q.tail = q.tail + 1
    q.items[q.tail] = inst
    q.cols[q.tail] = (stripCollision == true)
    q.queued[inst] = true
end

local function HookContainerChildAdded(container, stripCollision, isIslandsFolder)
    if not container or HookedContainers[container] then return end
    HookedContainers[container] = true
    local myUidStr = isIslandsFolder and tostring(LocalPlayer.UserId) or nil
    BindConn(container.ChildAdded, function(child)
        if not IsRunning() or not Config.OptimizeMap or not Runtime.Cache.Is3dRenderingEnabled then return end
        if isIslandsFolder then
            if not Config.HideIslandVisuals then return end
            local isMine = (child.Name == myUidStr)
            Runtime.Helpers.EnqueueVisualStrip(child, not isMine)
        else
            Runtime.Helpers.EnqueueVisualStrip(child, stripCollision)
        end
    end)
end

local function StripContainerTree(container, stripCollision, watchChildren, forceResweep)
    if not container or not container.Parent then return end
    if not Runtime.Cache.Is3dRenderingEnabled then return end
    local alreadyTracked = (TrackedContainers[container] == true)
    if alreadyTracked and not forceResweep then
        if watchChildren then
            HookContainerChildAdded(container, stripCollision, false)
        end
        return
    end

    TrackContainer(container)
    if watchChildren then
        HookContainerChildAdded(container, stripCollision, false)
    end
    Runtime.Helpers.EnqueueVisualStrip(container, stripCollision)
end

function Runtime.Helpers.SweepDebris(debrisFolder)
    local folder = debrisFolder or Workspace:FindFirstChild("__DEBRIS")
    if not folder or not folder.Parent then return end
    for _, child in ipairs(folder:GetChildren()) do
        if not child:IsA("Folder") and not DEBRIS_PRESERVE_NAMES[child.Name] and child.Name ~= SAFE_FLOOR_NAME then
            DestroyClutterInstance(child, false)
        end
    end
end

function Runtime.Helpers.ClearFolderChildrenOnce(folder)
    if not folder or not folder.Parent then return end
    for _, child in ipairs(folder:GetChildren()) do
        DestroyClutterInstance(child, false)
    end
end

local function ApplyLightingAndEffectsOptimization()
    if not Config.OptimizeLightingAndEffects then return end
    if not Runtime.Cache.SavedLightingState then
        local savedChildren = setmetatable({}, { __mode = "k" })
        for _, child in ipairs(Lighting:GetChildren()) do
            local entry = {}
            if child:IsA("PostEffect") then
                entry.Enabled = child.Enabled
            elseif child:IsA("Atmosphere") then
                entry.Density = child.Density
                entry.Offset = child.Offset
                entry.Glare = child.Glare
                entry.Haze = child.Haze
            elseif child:IsA("Sky") then
                entry.SkyboxBk = child.SkyboxBk
                entry.SkyboxDn = child.SkyboxDn
                entry.SkyboxFt = child.SkyboxFt
                entry.SkyboxLf = child.SkyboxLf
                entry.SkyboxRt = child.SkyboxRt
                entry.SkyboxUp = child.SkyboxUp
                entry.StarCount = child.StarCount
                entry.CelestialBodiesShown = child.CelestialBodiesShown
            elseif child:IsA("Clouds") then
                entry.Enabled = child.Enabled
                entry.Cover = child.Cover
            end
            if next(entry) ~= nil then
                savedChildren[child] = entry
            end
        end
        local prevQualityLevel = nil
        local prevSavedQuality = nil
        pcall(function()
            local r = settings and settings().Rendering
            if r then
                prevQualityLevel = r.QualityLevel
                r.QualityLevel = Enum.QualityLevel.Level01
            end
        end)
        pcall(function()
            local userSettings = UserSettings()
            local ugs = userSettings and userSettings:GetService("UserGameSettings")
            if ugs then
                prevSavedQuality = ugs.SavedQualityLevel
                if ugs.SavedQualityLevel ~= Enum.SavedQualitySetting.QualityLevel1 then
                    ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
                end
            end
        end)

        Runtime.Cache.SavedLightingState = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
            Brightness = Lighting.Brightness,
            EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
            RenderQualityLevel = prevQualityLevel,
            SavedQualityLevel = prevSavedQuality,
            Children = savedChildren,
        }

        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            pcall(function()
                terrain.Decoration = false
            end)
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
            if Config.ClearTerrainVoxels == true then
                pcall(function()
                    local cells = terrain:CountCells()
                    if type(cells) == "number" and cells > 0 then
                        terrain:Clear()
                    end
                end)
            end
        end
    end

    if Lighting.GlobalShadows then
        Lighting.GlobalShadows = false
    end
    if Lighting.Brightness ~= 0 then
        Lighting.Brightness = 0
    end
    if Lighting.FogEnd < 9e8 then
        Lighting.FogEnd = 9e9
    end
    if Lighting.EnvironmentDiffuseScale ~= 0 then
        Lighting.EnvironmentDiffuseScale = 0
    end
    if Lighting.EnvironmentSpecularScale ~= 0 then
        Lighting.EnvironmentSpecularScale = 0
    end

    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("PostEffect") then
            if child.Enabled then
                child.Enabled = false
            end
        elseif child:IsA("Atmosphere") then
            child.Density = 0
            child.Offset = 0
            child.Glare = 0
            child.Haze = 0
        elseif child:IsA("Sky") then
            child.SkyboxBk = ""
            child.SkyboxDn = ""
            child.SkyboxFt = ""
            child.SkyboxLf = ""
            child.SkyboxRt = ""
            child.SkyboxUp = ""
            child.StarCount = 0
            child.CelestialBodiesShown = false
        elseif child:IsA("Clouds") then
            child.Enabled = false
            child.Cover = 0
        end
    end
end

local function CleanOtherPlayerCharacter(model)
    if not Runtime.Cache.Is3dRenderingEnabled or not model or model == LocalPlayer.Character or not model:IsA("Model") then return end
    local plr = Players:GetPlayerFromCharacter(model)
    local isOtherChar = (plr ~= nil and plr ~= LocalPlayer)
        or (model.Name ~= LocalPlayer.Name and model:FindFirstChildOfClass("Humanoid") ~= nil)
    if isOtherChar then
        StripContainerTree(model, true, false, false)
    end
end

local function StripIslandsFolder(islands)
    if not islands or not Runtime.Cache.Is3dRenderingEnabled then return end
    local myUidStr = tostring(LocalPlayer.UserId)
    for _, islandModel in ipairs(islands:GetChildren()) do
        if not TrackedContainers[islandModel] then
            local isMine = (islandModel.Name == myUidStr)
            StripContainerTree(islandModel, not isMine, false, false)
        end
    end
    HookContainerChildAdded(islands, false, true)
end

local function EnsureSafeFloor(plot)
    if not Config.OptimizeMap or not Config.SafeFloorEnabled then
        local existing = Runtime.Cache.SafeFloorPart or Workspace:FindFirstChild(SAFE_FLOOR_NAME)
        if existing and existing.Parent then
            pcall(existing.Destroy, existing)
        end
        Runtime.Cache.SafeFloorPart = nil
        return
    end
    if not plot then return end
    local okCf, cf = pcall(plot.GetCFrame, plot)
    if not okCf or typeof(cf) ~= "CFrame" then return end

    local floor = Runtime.Cache.SafeFloorPart
    if not floor or not floor.Parent then
        floor = Workspace:FindFirstChild(SAFE_FLOOR_NAME)
    end
    if not floor or not floor:IsA("Part") then
        local newFloor = Instance.new("Part")
        newFloor.Name = SAFE_FLOOR_NAME
        newFloor.Anchored = true
        newFloor.CanCollide = true
        newFloor.CanQuery = true
        newFloor.CanTouch = false
        newFloor.Transparency = 1
        newFloor.CastShadow = false
        newFloor.Material = Enum.Material.SmoothPlastic
        newFloor.Size = Vector3.new(2048, 4, 2048)
        newFloor.Parent = Workspace
        floor = newFloor
    end
    Runtime.Cache.SafeFloorPart = floor

    local targetPos = Vector3.new(cf.Position.X, cf.Position.Y - 12, cf.Position.Z)
    if (floor.Position - targetPos).Magnitude > 1 then
        floor.CFrame = CFrame.new(targetPos)
    end
end

function Runtime.Helpers.ApplyUltraLowRamSettings()
    if not Config.UltraLowRAM or Runtime.Cache.UltraLowRamApplied then return end
    Runtime.Cache.UltraLowRamApplied = true
    if Modules.Variables then
        if Runtime.Cache.PrevPotatoMode == nil then
            Runtime.Cache.PrevPotatoMode = Modules.Variables.PotatoMode
        end
        Modules.Variables.PotatoMode = true
    end

    local watchedGuis = Runtime.Cache.LowRamGuiWatched
    if type(watchedGuis) ~= "table" then
        watchedGuis = setmetatable({}, { __mode = "k" })
        Runtime.Cache.LowRamGuiWatched = watchedGuis
    end
    local function suppressLowRamGui(child)
        if not child or not child:IsA("ScreenGui") then return end
        local name = child.Name
        local shouldLock = false
        if name == "Notifications" then
            if Runtime.Cache.PrevNotificationsGuiEnabled == nil then
                Runtime.Cache.PrevNotificationsGuiEnabled = child.Enabled
            end
            shouldLock = true
        elseif Config.HatchDisableAnimation and (name == "EggOpenAnimation" or name == "HatchAnimation") then
            if name == "EggOpenAnimation" and Runtime.Cache.PrevEggOpenGuiEnabled == nil then
                Runtime.Cache.PrevEggOpenGuiEnabled = child.Enabled
            end
            shouldLock = true
        end
        if not shouldLock then return end
        if child.Enabled then
            pcall(function()
                child.Enabled = false
            end)
        end
        if not watchedGuis[child] then
            watchedGuis[child] = true
            BindConn(child:GetPropertyChangedSignal("Enabled"), function()
                if IsRunning() and Config.UltraLowRAM and child.Enabled then
                    pcall(function()
                        child.Enabled = false
                    end)
                end
            end)
        end
    end

    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, child in ipairs(pg:GetChildren()) do
            suppressLowRamGui(child)
        end
        if not Runtime.Cache.EggOpenGuiConnBound then
            Runtime.Cache.EggOpenGuiConnBound = true
            BindConn(pg.ChildAdded, function(child)
                if IsRunning() and Config.UltraLowRAM then
                    suppressLowRamGui(child)
                end
            end)
        end
    end

    if Modules.Network and type(Modules.Network.Invoke) == "function" then
        task.spawn(function()
            local sc = Modules.SettingsCmds
            local hasSc = type(sc) == "table" and type(sc.Get) == "function" and type(sc.GetValue) == "function"
            local function readSetting(name)
                if hasSc then
                    local okG, strVal = pcall(sc.Get, name)
                    local okV, numVal = pcall(sc.GetValue, name)
                    return okG and strVal or nil, okV and numVal or nil
                end
                local saveData = Runtime.Helpers.GetSaveData and Runtime.Helpers.GetSaveData()
                local raw = saveData and saveData.Settings and saveData.Settings[name]
                return nil, raw
            end
            local function ensureToggleState(name, wantStr, wantNum)
                if not IsRunning() then return end
                local curStr, curNum = readSetting(name)
                if curStr == wantStr or (curStr == nil and curNum == wantNum) then return end
                if curStr == nil and curNum == nil then return end
                pcall(Modules.Network.Invoke, "Toggle Setting", name)
                task.wait(0.08)
            end
            local function ensureSliderZero(name)
                if not IsRunning() then return end
                local _, curNum = readSetting(name)
                if type(curNum) == "number" and curNum ~= 0 then
                    pcall(Modules.Network.Invoke, "Slider Setting", name, 0)
                    task.wait(0.08)
                end
            end

            -- Verified PS99 SettingsCmds values: 1="On", 2="Off"
            for _, settingName in ipairs({ "PotatoMode", "EggPotatoMode", "ReduceOrbs", "HideOwnPets" }) do
                ensureToggleState(settingName, "On", 1)
            end
            for _, settingName in ipairs({ "ShowOtherPets", "PetSFX", "NotificationsSFX", "Vibrations" }) do
                ensureToggleState(settingName, "Off", 2)
            end

            -- Multi-state ItemNotifications (1="All" -> cycle to "Off" / 2 with bounded attempts)
            for _ = 1, 6 do
                if not IsRunning() then break end
                local curStr, curNum = readSetting("ItemNotifications")
                if curStr == "Off" or curNum == 2 or (curStr == nil and curNum == nil) then break end
                local okInv = pcall(Modules.Network.Invoke, "Toggle Setting", "ItemNotifications")
                if not okInv then break end
                task.wait(0.08)
            end

            ensureSliderZero("SFX")
            ensureSliderZero("Music")
        end)
    end
end

local function RunMapOptimizerPass(plot)
    if not Config.OptimizeMap then return end
    local inEvent = (plot ~= nil) or (Runtime.Helpers.IsInEventInstance and Runtime.Helpers.IsInEventInstance())
    if not inEvent then return end

    local is3dOn = (Runtime.Cache.Is3dRenderingEnabled == true)
    local things = Workspace:FindFirstChild("__THINGS")

    if Config.StripWorldClutter or (is3dOn and Config.HideEntityVisuals) then
        for _, child in ipairs(Workspace:GetChildren()) do
            if Config.StripWorldClutter and WORLD_CLUTTER_NAMES[child.Name] then
                DestroyClutterInstance(child, false)
            elseif is3dOn and Config.HideEntityVisuals and child:IsA("Model") and not TrackedContainers[child] then
                CleanOtherPlayerCharacter(child)
            end
        end
    end

    if Config.StripWorldClutter then
        Runtime.Helpers.SweepDebris(Workspace:FindFirstChild("__DEBRIS"))
        Runtime.Cache.LastDebrisSweepAt = os.clock()

        if things then
            for _, folderName in ipairs(THINGS_CLEAR_FOLDERS) do
                Runtime.Helpers.ClearFolderChildrenOnce(things:FindFirstChild(folderName))
            end

            if Config.UltraLowRAM then
                for _, subName in ipairs({ "Eggs", "ShinyRelics", "ZoneEggs" }) do
                    local subFolder = things:FindFirstChild(subName)
                    if subFolder and not TrackedContainers[subFolder] then
                        TrackContainer(subFolder)
                        Runtime.Helpers.ClearFolderChildrenOnce(subFolder)
                    end
                end
            end

            local ic = things:FindFirstChild("__INSTANCE_CONTAINER")
            local activeFolder = ic and ic:FindFirstChild("Active")
            local ptActive = activeFolder and activeFolder:FindFirstChild(OPTIMIZER_EVENT_ID)
            if ptActive then
                local water = ptActive:FindFirstChild("Water")
                if water then
                    DestroyClutterInstance(water, false)
                end
                if not HookedContainers[ptActive] then
                    HookedContainers[ptActive] = true
                    BindConn(ptActive.ChildAdded, function(child)
                        if IsRunning() and Config.OptimizeMap and Config.StripWorldClutter and child.Name == "Water" then
                            task.defer(DestroyClutterInstance, child, false)
                        end
                    end)
                end
            end
        end
    end

    if is3dOn then
        if Config.HideIslandVisuals then
            StripIslandsFolder(Workspace:FindFirstChild("PumpkinTycoonIslands"))
            if things then
                StripContainerTree(things:FindFirstChild("Plots"), false, true, false)
            end
            StripContainerTree(Workspace:FindFirstChild("PumpkinTycoonPads"), false, true, false)
            StripContainerTree(Workspace:FindFirstChild("PumpkinTycoonPumpkins"), false, true, false)
        end

        if Config.HideEntityVisuals and things then
            for _, entityFolderName in ipairs({ "Breakables", "CustomEggs", "Pets", "PetsHidden", "Orbs" }) do
                StripContainerTree(things:FindFirstChild(entityFolderName), false, true, false)
            end
        end
    end

    EnsureSafeFloor(plot)
    Runtime.Cache.MapClutterClearedInEvent = true
end

local function HookOtherPlayerEvents(plr)
    if not plr or plr == LocalPlayer then return end
    local charConns = Runtime.Cache.PlayerCharConns
    if charConns[plr] then
        pcall(charConns[plr].Disconnect, charConns[plr])
        charConns[plr] = nil
    end
    if plr.Character and Runtime.Cache.Is3dRenderingEnabled and Config.OptimizeMap and Config.HideEntityVisuals then
        CleanOtherPlayerCharacter(plr.Character)
    end
    charConns[plr] = BindConn(plr.CharacterAdded, function(char)
        if IsRunning() and Config.OptimizeMap and Config.HideEntityVisuals and Runtime.Cache.Is3dRenderingEnabled then
            Runtime.Helpers.EnqueueVisualStrip(char, true)
        end
    end)
end

local function SetupMapOptimizer()
    if not Config.OptimizeMap then return end
    if Config.UltraLowRAM then
        Runtime.Helpers.ApplyUltraLowRamSettings()
    end
    if not Runtime.Cache.MapOptimizerInitialized then
        Runtime.Cache.MapOptimizerInitialized = true
        ApplyLightingAndEffectsOptimization()
        local myChar = LocalPlayer.Character
        if myChar and Config.OptimizeLightingAndEffects then
            StripLocalCharacterFx(myChar)
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            HookOtherPlayerEvents(plr)
        end
        BindConn(Players.PlayerAdded, HookOtherPlayerEvents)
        BindConn(Players.PlayerRemoving, function(plr)
            local charConns = Runtime.Cache.PlayerCharConns
            local c = charConns and charConns[plr]
            if c then
                pcall(c.Disconnect, c)
                charConns[plr] = nil
            end
        end)

        BindConn(Workspace.ChildAdded, function(child)
            if not IsRunning() or not Config.OptimizeMap or not child then return end
            local inEvent = Runtime.Helpers.IsInEventInstance and Runtime.Helpers.IsInEventInstance()
            if not inEvent then return end
            if Config.StripWorldClutter and WORLD_CLUTTER_NAMES[child.Name] then
                task.defer(DestroyClutterInstance, child, false)
                return
            end
            if not Runtime.Cache.Is3dRenderingEnabled then return end
            if Config.HideIslandVisuals and child.Name == "PumpkinTycoonIslands" then
                StripIslandsFolder(child)
            elseif Config.HideIslandVisuals and (child.Name == "PumpkinTycoonPads" or child.Name == "PumpkinTycoonPumpkins") then
                StripContainerTree(child, false, true, false)
            elseif Config.HideEntityVisuals and child:IsA("Model") then
                CleanOtherPlayerCharacter(child)
            end
        end)

        BindConn(Lighting.ChildAdded, function()
            if IsRunning() and Config.OptimizeMap and Config.OptimizeLightingAndEffects then
                task.defer(ApplyLightingAndEffectsOptimization)
            end
        end)

        BindConn(LocalPlayer.CharacterAdded, function(char)
            if IsRunning() and Config.OptimizeMap and Config.OptimizeLightingAndEffects then
                task.defer(StripLocalCharacterFx, char)
            end
        end)
    end

    if Runtime.Helpers.IsInEventInstance and Runtime.Helpers.IsInEventInstance() then
        task.spawn(function()
            RunMapOptimizerPass(nil)
            Runtime.Cache.LastOptimizeScanAt = os.clock()
            Log("INFO", "Map optimizer active (3dOn=%s, destroyed=%d, visualsHidden=%d).",
                tostring(Runtime.Cache.Is3dRenderingEnabled == true),
                tonumber(Runtime.Stats.MapDestroyedCount) or 0,
                tonumber(Runtime.Stats.VisualsHiddenCount) or 0)
        end)
    else
        Log("INFO", "Map optimizer armed (3dOn=%s); clutter pass deferred until PumpkinTycoon.",
            tostring(Runtime.Cache.Is3dRenderingEnabled == true))
    end
end

local function ScheduleMyIslandResweep()
    if not Runtime.Cache.Is3dRenderingEnabled or not Config.OptimizeMap or not Config.HideIslandVisuals then return end
    local token = (Runtime.Cache.MyIslandResweepToken or 0) + 1
    Runtime.Cache.MyIslandResweepToken = token
    task.delay(0.85, function()
        if not IsRunning() or Runtime.Cache.MyIslandResweepToken ~= token then return end
        if not Config.OptimizeMap or not Config.HideIslandVisuals or not Runtime.Cache.Is3dRenderingEnabled then return end
        local islands = Workspace:FindFirstChild("PumpkinTycoonIslands")
        local myDecor = islands and islands:FindFirstChild(tostring(LocalPlayer.UserId))
        if myDecor then
            Runtime.Helpers.EnqueueVisualStrip(myDecor, false)
        end
    end)
end

function Runtime.Helpers.On3dRenderingChanged(active)
    if not IsRunning() then return end
    if not active then
        Runtime.Helpers.ClearVisualQueue()
        Runtime.Cache.MyIslandResweepToken = (Runtime.Cache.MyIslandResweepToken or 0) + 1
        return
    end
    if Config.OptimizeMap and Runtime.Helpers.IsInEventInstance and Runtime.Helpers.IsInEventInstance() then
        table.clear(TrackedContainers)
        RunMapOptimizerPass(nil)
    end
end

local function StepMapOptimizer(plot)
    if not Config.OptimizeMap then return end
    EnsureSafeFloor(plot)

    local now = os.clock()
    if not Runtime.Cache.MapClutterClearedInEvent then
        Runtime.Cache.LastOptimizeScanAt = now
        RunMapOptimizerPass(plot)
        Log("INFO", "Map optimizer entered %s (3dOn=%s, destroyed=%d, visualsHidden=%d).",
            OPTIMIZER_EVENT_ID,
            tostring(Runtime.Cache.Is3dRenderingEnabled == true),
            tonumber(Runtime.Stats.MapDestroyedCount) or 0,
            tonumber(Runtime.Stats.VisualsHiddenCount) or 0)
        return
    end

    if Runtime.Cache.Is3dRenderingEnabled then
        local buttonsDone = tonumber(Runtime.Stats.ButtonsDone) or 0
        local prevButtonsDone = tonumber(Runtime.Cache.LastButtonsDoneForDecor) or -1
        if buttonsDone ~= prevButtonsDone then
            Runtime.Cache.LastButtonsDoneForDecor = buttonsDone
            if prevButtonsDone >= 0 then
                ScheduleMyIslandResweep()
            end
        end
    end

    if Config.StripWorldClutter and (now - (Runtime.Cache.LastDebrisSweepAt or 0)) >= 2.5 then
        Runtime.Cache.LastDebrisSweepAt = now
        Runtime.Helpers.SweepDebris(Workspace:FindFirstChild("__DEBRIS"))
    end

    if (now - (Runtime.Cache.LastConnPruneAt or 0)) >= 15.0 then
        Runtime.Cache.LastConnPruneAt = now
        Runtime.Helpers.PruneConnections()
    end

    local interval = math.max(5.0, tonumber(Config.OptimizeScanInterval) or 15.0)
    if now - (Runtime.Cache.LastOptimizeScanAt or 0) >= interval then
        Runtime.Cache.LastOptimizeScanAt = now
        RunMapOptimizerPass(plot)
    end
end

local function RestoreMapOptimizer()
    Runtime.Helpers.ClearVisualQueue()
    Runtime.Cache.MyIslandResweepToken = (Runtime.Cache.MyIslandResweepToken or 0) + 1
    if Runtime.Cache.PrevPotatoMode ~= nil and Modules.Variables then
        Modules.Variables.PotatoMode = Runtime.Cache.PrevPotatoMode
        Runtime.Cache.PrevPotatoMode = nil
    end
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        if Runtime.Cache.PrevNotificationsGuiEnabled ~= nil then
            local notifsGui = pg:FindFirstChild("Notifications")
            if notifsGui and notifsGui:IsA("ScreenGui") then
                pcall(function()
                    notifsGui.Enabled = Runtime.Cache.PrevNotificationsGuiEnabled
                end)
            end
            Runtime.Cache.PrevNotificationsGuiEnabled = nil
        end
        if Runtime.Cache.PrevEggOpenGuiEnabled ~= nil then
            local eggGui = pg:FindFirstChild("EggOpenAnimation")
            if eggGui and eggGui:IsA("ScreenGui") then
                pcall(function()
                    eggGui.Enabled = Runtime.Cache.PrevEggOpenGuiEnabled
                end)
            end
            Runtime.Cache.PrevEggOpenGuiEnabled = nil
        end
    end
    Runtime.Cache.EggOpenGuiConnBound = false
    if type(Runtime.Cache.LowRamGuiWatched) == "table" then
        table.clear(Runtime.Cache.LowRamGuiWatched)
    end
    Runtime.Cache.UltraLowRamApplied = false
    Runtime.Cache.MapClutterClearedInEvent = false

    local charConns = Runtime.Cache.PlayerCharConns
    if type(charConns) == "table" then
        for _, c in pairs(charConns) do
            if c then
                pcall(c.Disconnect, c)
            end
        end
        table.clear(charConns)
    end

    local safeFloor = Runtime.Cache.SafeFloorPart or Workspace:FindFirstChild(SAFE_FLOOR_NAME)
    if safeFloor and safeFloor.Parent then
        pcall(safeFloor.Destroy, safeFloor)
    end
    Runtime.Cache.SafeFloorPart = nil

    local saved = Runtime.Cache.SavedLightingState
    if type(saved) == "table" then
        pcall(function()
            Lighting.GlobalShadows = saved.GlobalShadows
            Lighting.FogEnd = saved.FogEnd
            Lighting.Brightness = saved.Brightness
            Lighting.EnvironmentDiffuseScale = saved.EnvironmentDiffuseScale
            Lighting.EnvironmentSpecularScale = saved.EnvironmentSpecularScale
        end)
        if saved.RenderQualityLevel ~= nil then
            pcall(function()
                local r = settings and settings().Rendering
                if r then
                    r.QualityLevel = saved.RenderQualityLevel
                end
            end)
        end
        if saved.SavedQualityLevel ~= nil then
            pcall(function()
                local userSettings = UserSettings()
                local ugs = userSettings and userSettings:GetService("UserGameSettings")
                if ugs then
                    ugs.SavedQualityLevel = saved.SavedQualityLevel
                end
            end)
        end
        if type(saved.Children) == "table" then
            for inst, props in pairs(saved.Children) do
                if inst and inst.Parent then
                    pcall(function()
                        for k, v in pairs(props) do
                            (inst :: any)[k] = v
                        end
                    end)
                end
            end
        end
        Runtime.Cache.SavedLightingState = nil
    end
    table.clear(TrackedContainers)
    table.clear(HookedContainers)
    Runtime.Cache.MapOptimizerInitialized = false
end

Runtime.Teardown = function()
    Runtime.Running = false
    for _, conn in ipairs(Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(Connections)
    CleanupKaitunDashboard()
    RestorePetSpeedBuff()
    RestoreAntiAfkNetworkHook()
    RestoreMapOptimizer()
    ReleaseHeldPets()
    Runtime.Cache.PlotSavePlot = nil
    table.clear(Runtime.Cache.PlotSaveEntries)
    table.clear(Runtime.Cache.PlotSaveConnsBound)
    Runtime.Cache.PedInfoCache = nil
    Runtime.Cache.TapTargets = nil
    if type(Runtime.Cache.ActiveTargetCopy) == "table" then
        Runtime.Cache.ActiveTargetCopy.model = nil
    end
    for _, pool in ipairs({ Runtime.Cache.EntryPoolA, Runtime.Cache.EntryPoolB }) do
        if type(pool) == "table" then
            for i = 1, #pool do
                if type(pool[i]) == "table" then
                    pool[i].model = nil
                end
            end
        end
    end
    Runtime.Cache.TurkeyRaycastShared = nil
    Runtime.Cache.TurkeyRaycastFilter = nil
    Runtime.Cache.TurkeyRaycastParams = nil
    table.clear(Runtime.Cache.TargetEggCache)
    Runtime.Cache.MachineSessionDepth = 0
    Runtime.Cache.HatchYieldUntil = 0
    Runtime.Cache.HatchInFlight = false
    Runtime.Cache.MoveLockUntil = 0
    Runtime.Cache.SightingHookBound = false
    Runtime.Cache.ActiveSighting = nil
    Runtime.Cache.WildRerollActive = false
    Runtime.Cache.WildRerollSoldOutLogged = false
    Runtime.Cache.Complete2Unsupported = false
    Runtime.Cache.NetStoreShelfCache = nil
    Runtime.Cache.LastNetStoreRefreshIn = nil
    Runtime.Cache.ForceNetStoreShelfFetch = false
    Runtime.Cache.NetStoreForcePadUntil = 0
    Runtime.Cache.ButtonBuyRequestedAt = 0
    Runtime.Cache.LastButtonBuyFailAt = 0
    if type(Runtime.Cache.WarnThrottle) == "table" then
        table.clear(Runtime.Cache.WarnThrottle)
    end
    Runtime.Cache.TurkeyBossActiveEndsAt = 0
    Runtime.Cache.TurkeyBossEngagedAt = 0
    Runtime.Cache.TurkeyBossSkippedEndsAt = 0
    Runtime.Cache.TurkeyBossReturnPos = nil
    Runtime.Cache.TurkeyBossLastHealth = nil
    Runtime.Cache.TurkeyBossWatchedWindow = 0
    Runtime.Cache.TurkeyBossProbedWindow = 0
    Runtime.Cache.TurkeyBossLastMyDps = 0
    Runtime.Cache.TurkeyBossTopRaw = nil
    Runtime.Cache.TurkeyBossTopParsed = nil
    Runtime.Cache.TurkeyBossOtherShareSum = 0
    Runtime.Cache.TurkeyBossOtherActiveAt = 0
    Runtime.Cache.TurkeyBossOtherLiveDps = 0
    Runtime.Cache.TurkeyBossHpSampleAt = 0
    Runtime.Cache.TurkeyBossHpSampleVal = nil
    Runtime.Cache.TurkeyBossRejoinAfterAt = 0
    Runtime.Cache.TurkeyBossLastPassiveLogAt = 0
    Runtime.Cache.TurkeyBossLastPassiveLogKey = nil
    Runtime.Stats.FightingTurkeyBoss = false
    Runtime.Stats.TurkeyBossShare = 0
    Runtime.Stats.TurkeyBossHealth = 0
    Runtime.Stats.TurkeyBossMaxHealth = 0
    if type(Runtime.Cache.WildSlotCooldown) == "table" then
        table.clear(Runtime.Cache.WildSlotCooldown)
    end
    Runtime.Cache.MailRecipientIdx = 0
    Runtime.Cache.MailMessageCooldownUntil = 0
    if type(Runtime.Cache.MailFailCooldownByKey) == "table" then
        table.clear(Runtime.Cache.MailFailCooldownByKey)
    end
    if type(Runtime.Cache.MailPetFirstSeen) == "table" then
        table.clear(Runtime.Cache.MailPetFirstSeen)
    end
    Log("INFO", "Previous session cleaned up.")
end
getgenv()[GEN_KEY] = Runtime

-- ============================================================================
-- 4. CORE HELPER UTILITIES
-- ============================================================================
local PT = Modules.PumpkinTycoon
local INSTANCE_ID = (PT and PT.INSTANCE_ID) or "PumpkinTycoon"
local NET = (PT and PT.NET) or {}
local VAR = (PT and PT.VAR) or {}

local function GetCharacter()
    local char = LocalPlayer.Character
    local hrp = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
    return char, hrp
end

local function WaitReady()
    local startAt = os.clock()
    local lastLogAt = 0

    while IsRunning() do
        local _, hrp = GetCharacter()
        local loadedAttr = LocalPlayer:GetAttribute("__LOADED") == true
        local hasGui = LocalPlayer:FindFirstChild("PlayerGui") ~= nil
        local saveOk, saveData = callWithSavedIdentity(function()
            return Modules.Save and Modules.Save.Get and Modules.Save.Get()
        end)

        if loadedAttr and hasGui and hrp and saveOk and type(saveData) == "table" then return true end

        local elapsed = os.clock() - startAt
        if (lastLogAt == 0 and elapsed >= 2) or (lastLogAt > 0 and elapsed - lastLogAt >= 15) then
            lastLogAt = elapsed
            local missing = not loadedAttr and "LocalPlayer.__LOADED"
                or (not hasGui and "PlayerGui")
                or (not hrp and "HumanoidRootPart")
                or "SaveData"
            Log("INFO", "Waiting for character and player data (stage=%s, elapsed=%.1fs)...", missing, elapsed)
        end
        task.wait(0.25)
    end
    return false
end

local function HorizontalDist(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function MoveNear(targetPos, minThreshold)
    local _, hrp = GetCharacter()
    if not hrp or not targetPos then return false end
    local dist = HorizontalDist(hrp.Position, targetPos)
    if dist <= (minThreshold or 14) then return true end
    -- Offset cleanly on the same Y+2 plane to avoid lodging inside models
    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2.5, 4))
    Runtime.Cache.LastTeleportAt = os.clock()
    return true
end

local function IsMoveLocked()
    return (Runtime.Cache.MoveLockUntil or 0) > os.clock()
end

local function AcquireMoveLock(durationSec)
    local untilTs = os.clock() + (tonumber(durationSec) or 3.0)
    if untilTs > (Runtime.Cache.MoveLockUntil or 0) then
        Runtime.Cache.MoveLockUntil = untilTs
    end
end

local function ReleaseMoveLock()
    Runtime.Cache.MoveLockUntil = 0
end

--- Close a machine UI modal only when TabController confirms that specific machine tab is open.
local function CloseMachineTab(machineName)
    local tc = Modules.TabController
    if not tc or type(machineName) ~= "string" then return end
    if type(tc.IsOpen) ~= "function" or type(tc.CloseTab) ~= "function" then return end
    local okOpen, isOpen = pcall(tc.IsOpen, machineName)
    if okOpen and isOpen == true then
        pcall(tc.CloseTab)
    end
end

--- Acquire a nested machine session lock and pause active AutoHatch cleanly before moving.
local function BeginMachineSession(waitTimeoutSec)
    Runtime.Cache.MachineSessionDepth = (Runtime.Cache.MachineSessionDepth or 0) + 1
    local lockSec = 4.0
    Runtime.Cache.HatchYieldUntil = math.max(Runtime.Cache.HatchYieldUntil or 0, os.clock() + lockSec)
    AcquireMoveLock(lockSec)

    if Runtime.Cache.MachineSessionDepth == 1 then
        local deadline = os.clock() + (tonumber(waitTimeoutSec) or 1.5)
        while IsRunning() and Runtime.Cache.HatchInFlight and os.clock() < deadline do
            Runtime.Cache.HatchYieldUntil = math.max(Runtime.Cache.HatchYieldUntil or 0, os.clock() + lockSec)
            AcquireMoveLock(lockSec)
            task.wait(0.03)
        end
    end
end

--- Extend both MoveLock and HatchYieldUntil during multi-invoke machine batches.
local function ExtendMachineSession(lockSec)
    local dur = tonumber(lockSec) or 4.0
    if (Runtime.Cache.MachineSessionDepth or 0) > 0 then
        Runtime.Cache.HatchYieldUntil = math.max(Runtime.Cache.HatchYieldUntil or 0, os.clock() + dur)
    end
    AcquireMoveLock(dur)
end

local function EndMachineSession()
    local depth = math.max(0, (Runtime.Cache.MachineSessionDepth or 1) - 1)
    Runtime.Cache.MachineSessionDepth = depth
    if depth == 0 then
        Runtime.Cache.HatchYieldUntil = 0
        ReleaseMoveLock()
    end
end

--- Run a callback across one or more machine visits while holding MoveLock and pausing AutoHatch.
local function WithMachineSession(callback)
    BeginMachineSession(1.5)
    local ok, err = pcall(callback)
    EndMachineSession()
    if not ok then
        Log("DEBUG", "Machine session error: %s", tostring(err))
        return false
    end
    return true
end

local function IsMobileLowFpsEnv()
    local envInfo = Runtime.Helpers and Runtime.Helpers.DetectMobileAntiAfk and Runtime.Helpers.DetectMobileAntiAfk()
    return (envInfo and envInfo.isMobile == true) or (Config.UltraLowRAM == true)
end

local function EnsureNearMachinePad(plot, machineName, rangeFn, standOnPad)
    if not plot or not machineName or not Modules.PumpkinButtonsUtil or not Modules.PumpkinButtonsUtil.MachinePad then
        return false, "missing_util"
    end
    local okPlot, plotModel = pcall(plot.GetModel, plot)
    if not okPlot or not plotModel then
        return false, "no_plot_model"
    end
    local pad = Modules.PumpkinButtonsUtil.MachinePad(plotModel, machineName)
    if not pad or not pad:IsA("BasePart") then
        local retryDeadline = os.clock() + (IsMobileLowFpsEnv() and 0.80 or 0.35)
        while IsRunning() and os.clock() < retryDeadline do
            task.wait(0.10)
            okPlot, plotModel = pcall(plot.GetModel, plot)
            pad = (okPlot and plotModel) and Modules.PumpkinButtonsUtil.MachinePad(plotModel, machineName) or nil
            if pad and pad:IsA("BasePart") then break end
        end
        if not pad or not pad:IsA("BasePart") then
            return false, "pad_not_found"
        end
    end
    local range = 20
    if type(rangeFn) == "number" and rangeFn >= 6 then
        range = rangeFn
    elseif type(rangeFn) == "function" then
        local okR, r = pcall(rangeFn)
        if okR and type(r) == "number" and r >= 6 then
            range = r
        end
    end
    local moveDist = standOnPad and 2.5 or math.clamp(range - 8, 4, 12)
    local _, hrp = GetCharacter()
    if not hrp then return false, "no_hrp" end
    ExtendMachineSession(5.0)

    local isMobile = IsMobileLowFpsEnv()
    local jumpDist = (hrp.Position - pad.Position).Magnitude
    local needMove = HorizontalDist(hrp.Position, pad.Position) > moveDist
        or math.abs(hrp.Position.Y - pad.Position.Y) > 6
    if standOnPad and Modules.MachineCmds and Modules.MachineCmds.IsStandingOn then
        local okOn, standing = pcall(Modules.MachineCmds.IsStandingOn, machineName)
        if okOn and standing == false then
            needMove = true
        end
    end

    local targetOffset = standOnPad
        and Vector3.new(0, (pad.Size.Y * 0.5) + 2.8, 0)
        or Vector3.new(0, 2.5, 1.5)
    local function snapToPad(rootPart)
        if not rootPart or not pad or not pad.Parent then return end
        pcall(function()
            rootPart.AssemblyLinearVelocity = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        end)
        rootPart.CFrame = CFrame.new(pad.Position + targetOffset)
    end

    if needMove then
        if Workspace.StreamingEnabled and jumpDist > 300 and type(LocalPlayer.RequestStreamAroundAsync) == "function" then
            ExtendMachineSession(5.0)
            pcall(LocalPlayer.RequestStreamAroundAsync, LocalPlayer, pad.Position, isMobile and 1.2 or 0.8)
            _, hrp = GetCharacter()
            if not hrp then return false, "no_hrp" end
        end
        snapToPad(hrp)
        Runtime.Cache.LastTeleportAt = os.clock()
    end

    local minSettleSec = isMobile
        and ((needMove and jumpDist > 500) and 0.70 or 0.55)
        or 0.38
    local maxSettleSec = isMobile
        and ((needMove and jumpDist > 500) and 1.35 or 1.00)
        or 0.70
    local settledAt = Runtime.Cache.LastTeleportAt or os.clock()
    local minReadyAt = settledAt + minSettleSec
    local maxDeadline = settledAt + maxSettleSec

    while IsRunning() do
        ExtendMachineSession(5.0)
        _, hrp = GetCharacter()
        if not hrp or not pad or not pad.Parent then
            return false, "lost_hrp_or_pad"
        end
        local curHoriz = HorizontalDist(hrp.Position, pad.Position)
        local curDist = (hrp.Position - pad.Position).Magnitude
        local fellBelow = hrp.Position.Y < (pad.Position.Y - 3.5)

        if curHoriz > (moveDist + 2) or fellBelow then
            snapToPad(hrp)
            local snapWait = isMobile and 0.25 or 0.15
            minReadyAt = math.min(maxDeadline, math.max(minReadyAt, os.clock() + snapWait))
        end

        local now = os.clock()
        if now >= minReadyAt and curDist <= (range - 1) and not fellBelow then
            if not standOnPad then
                return true, nil
            end
            local readySignal = false
            if Modules.MachineCmds then
                if type(Modules.MachineCmds.CanUse) == "function" then
                    local okUse, canUse = pcall(Modules.MachineCmds.CanUse, machineName)
                    if okUse and canUse == true then
                        readySignal = true
                    end
                end
                if not readySignal and type(Modules.MachineCmds.IsStandingOn) == "function" then
                    local okOn, standing = pcall(Modules.MachineCmds.IsStandingOn, machineName)
                    if okOn and standing == true then
                        readySignal = true
                    end
                end
            end
            if readySignal or now >= (minReadyAt + (isMobile and 0.20 or 0.08)) then
                return true, nil
            end
        end

        if now >= maxDeadline then break end
        task.wait(isMobile and 0.08 or 0.05)
    end

    _, hrp = GetCharacter()
    if not hrp or not pad or not pad.Parent then
        return false, "lost_hrp_or_pad"
    end
    local finalDist = (hrp.Position - pad.Position).Magnitude
    if finalDist > (range - 1) then
        return false, string.format("out_of_range(%.1f>%d)", finalDist, range - 1)
    end
    return true, nil
end

local function WithMachinePad(plot, machineName, rangeFn, callback, opts)
    BeginMachineSession(1.5)
    local standOnPad = type(opts) == "table" and opts.standOnPad == true
    local closeModal = type(opts) == "table" and opts.closeModal == true
    local nearOk, nearErr = EnsureNearMachinePad(plot, machineName, rangeFn, standOnPad)
    if not nearOk then
        EndMachineSession()
        LogWarnThrottled("pad_" .. tostring(machineName), 20, "Machine pad unreachable [%s]: %s", tostring(machineName), tostring(nearErr))
        return false, nearErr
    end
    if closeModal then
        CloseMachineTab(machineName)
    end
    local ok, err = pcall(callback)
    if closeModal then
        CloseMachineTab(machineName)
        task.delay(0.2, function()
            if IsRunning() then
                CloseMachineTab(machineName)
            end
        end)
    end
    EndMachineSession()
    if not ok then
        LogWarnThrottled("act_" .. tostring(machineName), 20, "Machine action error [%s]: %s", tostring(machineName), tostring(err))
        return false, tostring(err)
    end
    return true, nil
end

local function GetCurrency(currencyId)
    if Modules.CurrencyCmds and Modules.CurrencyCmds.Get then
        local ok, val = pcall(Modules.CurrencyCmds.Get, currencyId)
        if ok and type(val) == "number" then return val end
    end
    return 0
end

Runtime.Helpers = Runtime.Helpers or {}
Runtime.Helpers.CallWithSavedIdentity = callWithSavedIdentity

function Runtime.Helpers.GetSaveData()
    if not Modules.Save or type(Modules.Save.Get) ~= "function" then return nil end
    local ok, saveData = callWithSavedIdentity(Modules.Save.Get)
    return (ok and type(saveData) == "table") and saveData or nil
end

function Runtime.Helpers.GetSaveInventory(subKey)
    local saveData = Runtime.Helpers.GetSaveData()
    local inv = saveData and saveData.Inventory
    local tbl = type(inv) == "table" and inv[subKey] or nil
    return type(tbl) == "table" and tbl or nil
end

function Runtime.Helpers.GetChaseCategory(petId, pd)
    if type(pd) == "table" then
        if pd.gargantuan == true then return "Gargantuan" end
        if pd.titanic == true then return "Titanic" end
        if pd.huge == true then return "Huge" end
    end
    if type(petId) == "string" then
        if string.sub(petId, 1, 11) == "Gargantuan " then return "Gargantuan" end
        if string.sub(petId, 1, 8) == "Titanic " then return "Titanic" end
        if string.sub(petId, 1, 5) == "Huge " then return "Huge" end
    end
    return nil
end

function Runtime.Helpers.GetMaxEquippedPets()
    if Modules.PetCmds and type(Modules.PetCmds.GetMaxEquipped) == "function" then
        local ok, m = pcall(Modules.PetCmds.GetMaxEquipped)
        if ok and type(m) == "number" and m >= 1 then return math.floor(m) end
    end
    return 4
end

function Runtime.Helpers.FormatCommas(value, invalidFallback)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return invalidFallback or "0"
    end
    local digits = string.format("%.0f", math.floor(value))
    return (digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function Runtime.Helpers.GetGiftItemName()
    return (Modules.PumpkinGiftUtil and Modules.PumpkinGiftUtil.ID)
        or (Modules.ButtonsTypes and Modules.ButtonsTypes.COMPLETION_GIFT)
        or "Flannel Gift"
end

function Runtime.Helpers.ScanFlannelGiftBag(boxesOverride)
    local giftName = Runtime.Helpers.GetGiftItemName()
    local boxes = boxesOverride ~= nil and boxesOverride or Runtime.Helpers.GetSaveInventory("Lootbox")
    if type(boxes) ~= "table" or next(boxes) == nil then
        return giftName, nil, 0, 0
    end
    local firstUid, firstAmt, total = nil, 0, 0
    for uid, d in pairs(boxes) do
        if type(d) == "table" and (d.id == giftName or d._id == giftName) then
            local am = math.max(0, math.floor(tonumber(d._am) or 1))
            if am >= 1 then
                total = total + am
                if not firstUid then
                    firstUid = tostring(uid)
                    firstAmt = am
                end
            end
        end
    end
    return giftName, firstUid, firstAmt, total
end

function Runtime.Helpers.RecordCoinsSpent(amount)
    local amt = tonumber(amount)
    if amt and amt > 0 then
        Runtime.Cache.TrackedCoinsSpent = (Runtime.Cache.TrackedCoinsSpent or 0) + amt
    end
end

function Runtime.Helpers.GetWindowCps(lookbackSec)
    local samples = Runtime.Cache.CoinRateSamples
    if type(samples) ~= "table" or #samples < 2 then return 0, 0 end
    local latest = samples[#samples]
    local cutoff = latest.t - math.max(1, tonumber(lookbackSec) or 60)
    local base = samples[1]
    for i = #samples, 1, -1 do
        local s = samples[i]
        if s.t <= cutoff then
            base = s
            break
        end
        base = s
    end
    local dt = latest.t - base.t
    if dt < 1 then return 0, dt end
    return math.max(0, (latest.cum - base.cum) / dt), dt
end

function Runtime.Helpers.UpdateCoinRateSampler(coinsOverride)
    local now = os.clock()
    if Runtime.Cache.CoinRateSamples and #Runtime.Cache.CoinRateSamples > 0 and (now - (Runtime.Cache.LastCoinRateSampleAt or 0)) < 1.0 then
        return tonumber(Runtime.Stats.CoinsPerSec) or 0
    end
    Runtime.Cache.LastCoinRateSampleAt = now
    local coins = tonumber(coinsOverride) or GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
    local gross = coins + (Runtime.Cache.TrackedCoinsSpent or 0)
    if Runtime.Cache.LastGrossCoins == nil then
        Runtime.Cache.LastGrossCoins = gross
        Runtime.Cache.CumulativeCoinsEarned = 0
    else
        local delta = gross - Runtime.Cache.LastGrossCoins
        if delta > 0 then
            Runtime.Cache.CumulativeCoinsEarned = (Runtime.Cache.CumulativeCoinsEarned or 0) + delta
        end
        Runtime.Cache.LastGrossCoins = gross
    end
    local samples = Runtime.Cache.CoinRateSamples
    if type(samples) ~= "table" then
        samples = {}
        Runtime.Cache.CoinRateSamples = samples
    end
    table.insert(samples, { t = now, cum = Runtime.Cache.CumulativeCoinsEarned or 0 })
    while #samples > 2 and (now - samples[1].t) > 65 do
        table.remove(samples, 1)
    end
    local cps = select(1, Runtime.Helpers.GetWindowCps(60))
    Runtime.Stats.CoinsPerSec = cps
    return cps
end

function Runtime.Helpers.IsIncomeSustainedForCocoa(minCps)
    Runtime.Helpers.UpdateCoinRateSampler()
    local minSampleSec = math.max(10, tonumber(Config.CocoaIncomeMinSampleSec) or 45)
    local longCps, longSpan = Runtime.Helpers.GetWindowCps(60)
    local shortCps, shortSpan = Runtime.Helpers.GetWindowCps(20)
    if longSpan < minSampleSec or shortSpan < 10 then return false, longCps end
    return (longCps >= minCps and shortCps >= (minCps * 0.85)), longCps
end

function Runtime.Helpers.InvalidatePlotSave(plot, key)
    if not plot or (Runtime.Cache.PlotSavePlot ~= nil and Runtime.Cache.PlotSavePlot ~= plot) then
        Runtime.Cache.PlotSavePlot = nil
        table.clear(Runtime.Cache.PlotSaveEntries)
        table.clear(Runtime.Cache.PlotSaveConnsBound)
        Runtime.Cache.PedInfoCache = nil
        Runtime.Cache.PedInfoVer = -1
        return
    end
    local entries = Runtime.Cache.PlotSaveEntries
    if key ~= nil then
        local entry = entries[key]
        if entry then
            entry.dirty = true
            entry.at = 0
            entry.ver = (entry.ver or 0) + 1
        end
        if key == VAR.Pedestals then
            Runtime.Cache.PedInfoCache = nil
        elseif key == VAR.Buttons then
            table.clear(Runtime.Cache.TargetEggCache)
        end
    else
        for _, entry in pairs(entries) do
            entry.dirty = true
            entry.at = 0
            entry.ver = (entry.ver or 0) + 1
        end
        Runtime.Cache.PedInfoCache = nil
        table.clear(Runtime.Cache.TargetEggCache)
    end
end

function Runtime.Helpers.GetPlotSave(plot, key, forceRefresh)
    if not plot or type(key) ~= "string" then return nil, 0 end
    if Runtime.Cache.PlotSavePlot ~= plot then
        Runtime.Cache.PlotSavePlot = plot
        table.clear(Runtime.Cache.PlotSaveEntries)
        table.clear(Runtime.Cache.PlotSaveConnsBound)
        Runtime.Cache.PedInfoCache = nil
        Runtime.Cache.PedInfoVer = -1
        Runtime.Cache.TutorialDonePlot = nil
        if plot.Destroying and type(plot.Destroying.Connect) == "function" then
            BindConn(plot.Destroying, function()
                if Runtime.Cache.PlotSavePlot == plot then
                    Runtime.Cache.PlotSavePlot = nil
                    table.clear(Runtime.Cache.PlotSaveEntries)
                    table.clear(Runtime.Cache.PlotSaveConnsBound)
                    Runtime.Cache.PedInfoCache = nil
                    Runtime.Cache.PedInfoVer = -1
                end
            end)
        end
    end

    local entries = Runtime.Cache.PlotSaveEntries
    local entry = entries[key]
    if not entry then
        entry = { val = nil, hasVal = false, at = 0, dirty = true, ver = 0 }
        entries[key] = entry
    end

    if not Runtime.Cache.PlotSaveConnsBound[key] and type(plot.SaveChanged) == "function" then
        Runtime.Cache.PlotSaveConnsBound[key] = true
        local okSig, sig = pcall(plot.SaveChanged, plot, key)
        if okSig and sig and type(sig.Connect) == "function" then
            BindConn(sig, function()
                if Runtime.Cache.PlotSavePlot ~= plot then return end
                entry.dirty = true
                entry.at = 0
                entry.ver = (entry.ver or 0) + 1
                if key == VAR.Pedestals then
                    Runtime.Cache.PedInfoCache = nil
                elseif key == VAR.Buttons then
                    table.clear(Runtime.Cache.TargetEggCache)
                elseif key == VAR.Tutorial then
                    Runtime.Cache.TutorialDonePlot = nil
                end
            end)
        end
    end

    local now = os.clock()
    if not forceRefresh and entry.hasVal and not entry.dirty and (now - entry.at) < 1.5 then return entry.val, entry.ver end

    local okSave, res = pcall(plot.Save, plot, key)
    if okSave then
        entry.val = res
        entry.hasVal = true
        entry.at = now
        entry.dirty = false
        entry.ver = (entry.ver or 0) + 1
    end
    return entry.val, entry.ver
end

function Runtime.Helpers.HasCraftMachineUnlocked(machineName, plot, buttons)
    if Config.CraftRequireButtonComplete == false then return true end
    local btnState = buttons or (plot and Runtime.Helpers.GetPlotSave(plot, VAR.Buttons))
    if not btnState or not Modules.PumpkinButtonsUtil or not Modules.PumpkinButtonsUtil.Owned then return false end
    return Modules.PumpkinButtonsUtil.Owned(btnState, machineName) == true
end

local function GetFlag(keyName, fallback)
    local FFlags = Modules.FFlags
    if FFlags and FFlags.Keys and FFlags.Get then
        local k = FFlags.Keys[keyName]
        if k ~= nil then
            local ok, v = pcall(FFlags.Get, k)
            if ok and v ~= nil then return v end
        end
    end
    return fallback
end

local function IsInEventInstance()
    if Modules.InstancingCmds and Modules.InstancingCmds.IsInInstance then
        local ok, inside = pcall(Modules.InstancingCmds.IsInInstance, INSTANCE_ID)
        if ok and inside == true then return true end
    end
    if Modules.InstancingCmds and Modules.InstancingCmds.Get then
        local ok, info = pcall(Modules.InstancingCmds.Get)
        if ok and type(info) == "table" and info.instanceID == INSTANCE_ID then return true end
    end
    return LocalPlayer:GetAttribute("InstanceId") == INSTANCE_ID
end
Runtime.Helpers.IsInEventInstance = IsInEventInstance

local function GetMyPlot()
    if not Modules.ClientPlot or not Modules.ClientPlot.GetByPlayer then return nil end
    local ok, plot = pcall(Modules.ClientPlot.GetByPlayer, LocalPlayer)
    if ok and plot and not plot:IsDestroyed() then
        local dir = plot:GetDirectory()
        local dirId = type(dir) == "table" and (dir._id or dir.SaveId) or dir
        local targetDir = (PT and PT.PLOT_DIR) or INSTANCE_ID
        if dirId == targetDir or dirId == INSTANCE_ID then return plot end
    end
    return nil
end

local function GetIslandBox(plot)
    if not plot then return nil end
    local now = os.clock()
    if Runtime.Cache.IslandBox and (now - Runtime.Cache.IslandBoxAt < 2.0) then return Runtime.Cache.IslandBox end
    local model = plot:GetModel()
    if not model then return nil end
    local cf, size = model:GetBoundingBox()
    Runtime.Cache.IslandBox = { cf = cf, size = size, model = model }
    Runtime.Cache.IslandBoxAt = now
    return Runtime.Cache.IslandBox
end

local function IsOnMyIsland(model, islandBox)
    if not model or not model.Parent then return false end
    if model:GetAttribute("OwnerUsername") == LocalPlayer.Name then return true end
    if islandBox and PT and PT.OnIsland then return PT.OnIsland(islandBox.cf, islandBox.size, model:GetPivot().Position) end
    return false
end

function Runtime.Helpers.IsPlotPart2Active(plot)
    local flagOn = GetFlag("PumpkinTycoon_Part2", false) == true
    if not flagOn and PT_Cmds and type(PT_Cmds.Part2) == "function" then
        local ok, res = pcall(PT_Cmds.Part2)
        flagOn = ok and res == true
    end
    if not flagOn then return false end
    if plot and type(plot.GetModel) == "function" then
        local okM, model = pcall(plot.GetModel, plot)
        if okM and model then
            local builtAttr = (PT and PT.PART2_BUILT) or "Part2Built"
            return model:GetAttribute(builtAttr) == true
        end
        return false
    end
    return false
end

local function GetZoneCount(plot)
    if Runtime.Helpers.IsPlotPart2Active(plot) then return #(PT and PT.ZONES or {}) end
    return (PT and PT.PART1_ZONES) or 5
end

local function GetProgressState(plot, forceRefresh)
    local buttons = plot and Runtime.Helpers.GetPlotSave(plot, VAR.Buttons, forceRefresh) or nil
    local isPart2 = Runtime.Helpers.IsPlotPart2Active(plot)
    local p1Done, p1Total = 0, 0
    local p2Done, p2Total = 0, 0
    local done, total = 0, 0
    local btnUtil = Modules.PumpkinButtonsUtil
    if btnUtil then
        if btnUtil.Progress then
            p1Done, p1Total = btnUtil.Progress(buttons, 1)
            if isPart2 then
                p2Done, p2Total = btnUtil.Progress(buttons, 2)
            end
        end
        if isPart2 and btnUtil.CompleteProgress then
            done, total = btnUtil.CompleteProgress(buttons, true)
        elseif isPart2 then
            done = p1Done + p2Done
            total = p1Total + p2Total
        else
            done, total = p1Done, p1Total
        end
    end

    local part1Complete = (p1Total > 0 and p1Done >= p1Total)
    local part2Complete = isPart2 and (p2Total > 0 and p2Done >= p2Total) or false
    local tycoonComplete = (total > 0 and done >= total)
    local claimedComplete = (btnUtil and btnUtil.Completed and btnUtil.Completed(buttons)) == true
    local claimedComplete2 = (btnUtil and btnUtil.Completed2 and btnUtil.Completed2(buttons)) == true
    local rawRebirths = plot and Runtime.Helpers.GetPlotSave(plot, VAR.Rebirths, forceRefresh) or 0
    local rebirths = math.max(0, math.floor(tonumber(rawRebirths) or 0))

    Runtime.Cache.Buttons = buttons
    Runtime.Cache.ButtonsAt = os.clock()
    Runtime.Stats.ButtonsDone = done
    Runtime.Stats.ButtonsTotal = total
    Runtime.Stats.Part1Complete = part1Complete
    Runtime.Stats.Part2Complete = part2Complete
    Runtime.Stats.TycoonComplete = tycoonComplete
    Runtime.Stats.CompletedClaimed = claimedComplete
    Runtime.Stats.Completed2Claimed = claimedComplete2
    Runtime.Stats.Rebirths = rebirths
    Runtime.Stats.Coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
    Runtime.Stats.Tokens = GetCurrency((PT and PT.TOKENS) or "PumpkinTokens")
    Runtime.Stats.IslandLuck = tonumber(LocalPlayer:GetAttribute("PumpkinTycoonIslandLuck")) or 0

    return buttons, tycoonComplete, claimedComplete, claimedComplete2, isPart2, rebirths
end


-- ============================================================================
-- 4B. GENERAL PS99 INVENTORY AUTOMATION (FRUITS, BUNDLES, POTIONS, ENCHANTS)
-- ============================================================================
local function SafeDirLookup(dirTable, key)
    if type(dirTable) ~= "table" or key == nil then return nil end
    local rawVal = rawget(dirTable, key)
    if rawVal ~= nil then return rawVal end
    if getmetatable(dirTable) ~= nil then
        local ok, val = pcall(function()
            return dirTable[key]
        end)
        if ok then return val end
    end
    return nil
end

local function ResolvePetItem(uid)
    local petItemCls = Modules.PetItem
    if not petItemCls or uid == nil or type(petItemCls.Get) ~= "function" then return nil end
    local okG, inst = pcall(petItemCls.Get, petItemCls, uid)
    if okG and inst then return inst end
    return nil
end

function Runtime.Helpers.GetActiveFruitCount(targetFruitId)
    local fCmds = Modules.FruitCmds
    if not fCmds or type(fCmds.GetActiveFruits) ~= "function" then return 0 end
    local ok, active = pcall(fCmds.GetActiveFruits)
    if not ok or type(active) ~= "table" then return 0 end
    if type(targetFruitId) == "string" then
        local entry = active[targetFruitId]
        if type(entry) ~= "table" then return 0 end
        local sCnt = type(entry.Shiny) == "table" and #entry.Shiny or 0
        local nCnt = type(entry.Normal) == "table" and #entry.Normal or 0
        return sCnt + nCnt
    end
    local total = 0
    for _, entry in pairs(active) do
        if type(entry) == "table" then
            total = total + (type(entry.Shiny) == "table" and #entry.Shiny or 0) + (type(entry.Normal) == "table" and #entry.Normal or 0)
        end
    end
    return total
end

function Runtime.Helpers.StepConsumeFruits()
    local fCmds = Modules.FruitCmds
    if not Config.AutoConsumeFruits or not fCmds or not Modules.Save or type(fCmds.Consume) ~= "function" then return end
    local now = os.clock()
    if (now - (Runtime.Cache.LastFruitsStepAt or 0)) < 1.5 then return end
    Runtime.Cache.LastFruitsStepAt = now

    local targetStack = math.clamp(math.floor(tonumber(Config.FruitTargetStack) or 20), 1, 20)
    if type(fCmds.ComputeFruitQueueLimit) == "function" then
        local okL, lim = pcall(fCmds.ComputeFruitQueueLimit)
        if okL and type(lim) == "number" and lim >= 1 then
            targetStack = math.clamp(math.floor(tonumber(Config.FruitTargetStack) or 20), 1, math.floor(lim))
        end
    end
    local minMissing = math.max(1, math.floor(tonumber(Config.FruitMinRefillMissing) or 4))
    local cooldownSec = math.max(2, tonumber(Config.FruitConsumeCooldownSec) or 6)
    local allowed = Config.AllowedFruits

    local rejectBackoff = Runtime.Cache.FruitRejectBackoff
    if type(rejectBackoff) ~= "table" then
        rejectBackoff = {}
        Runtime.Cache.FruitRejectBackoff = rejectBackoff
    end

    if type(allowed) == "table" then
        local anyFruitNeedsEat = false
        for fruitId, isAllowed in pairs(allowed) do
            if isAllowed == true then
                local nextAt = Runtime.Cache.FruitConsumeCooldown[fruitId] or 0
                if now >= nextAt then
                    local activeCnt = Runtime.Helpers.GetActiveFruitCount(fruitId)
                    local missing = targetStack - activeCnt
                    if missing > 0 and (activeCnt == 0 or missing >= minMissing) then
                        anyFruitNeedsEat = true
                        break
                    end
                end
            end
        end
        if not anyFruitNeedsEat then return end
    end

    local invFruits = Runtime.Helpers.GetSaveInventory("Fruit")
    if not invFruits or next(invFruits) == nil then return end

    local stacks = {}
    for uid, data in pairs(invFruits) do
        if type(data) == "table" and type(data.id) == "string" and (allowed == nil or allowed[data.id] == true) then
            local amt = math.max(1, math.floor(tonumber(data._am) or 1))
            table.insert(stacks, {
                uid = tostring(uid),
                id = data.id,
                amt = amt,
                shiny = data.sh == true,
            })
        end
    end
    if #stacks == 0 then return end
    table.sort(stacks, function(a, b)
        if a.id ~= b.id then return a.id < b.id end
        if a.shiny ~= b.shiny then return a.shiny and not b.shiny end
        return a.uid < b.uid
    end)

    local function TryConsumeAndConfirm(uid, fruitId, amt, beforeCnt)
        local cOk = pcall(fCmds.Consume, uid, amt)
        if not cOk then return beforeCnt end
        local deadline = os.clock() + 0.45
        local cur = Runtime.Helpers.GetActiveFruitCount(fruitId)
        while IsRunning() and cur <= beforeCnt and os.clock() < deadline do
            task.wait(0.05)
            cur = Runtime.Helpers.GetActiveFruitCount(fruitId)
        end
        return cur
    end

    for _, st in ipairs(stacks) do
        local nextAt = Runtime.Cache.FruitConsumeCooldown[st.id] or 0
        if os.clock() >= nextAt then
            local activeCnt = Runtime.Helpers.GetActiveFruitCount(st.id)
            local missing = targetStack - activeCnt
            if missing > 0 and (activeCnt == 0 or missing >= minMissing) then
                local maxCan = missing
                if type(fCmds.GetMaxConsume) == "function" then
                    local okM, lim = pcall(fCmds.GetMaxConsume, st.uid)
                    if okM and type(lim) == "number" then
                        maxCan = math.min(maxCan, math.floor(lim))
                    end
                end
                local eatAmt = math.min(missing, maxCan, st.amt)
                if eatAmt >= 1 then
                    local afterCnt = TryConsumeAndConfirm(st.uid, st.id, eatAmt, activeCnt)
                    if afterCnt <= activeCnt and eatAmt > 1 then
                        -- Server queue may sit closer to cap than client timer (client/server drift); retry with 1x
                        afterCnt = TryConsumeAndConfirm(st.uid, st.id, 1, activeCnt)
                    end
                    if afterCnt > activeCnt then
                        rejectBackoff[st.id] = 0
                        Runtime.Cache.FruitConsumeCooldown[st.id] = os.clock() + cooldownSec
                        Log("INFO", "Consumed %dx %s (%d->%d/%d)",
                            afterCnt - activeCnt, st.id, activeCnt, afterCnt, targetStack)
                    else
                        local prevBo = tonumber(rejectBackoff[st.id]) or 0
                        local nextBo = (prevBo <= 0) and 30 or math.min(120, prevBo * 2)
                        rejectBackoff[st.id] = nextBo
                        Runtime.Cache.FruitConsumeCooldown[st.id] = os.clock() + nextBo
                        if prevBo == 0 then
                            Log("DEBUG", "Fruit consume deferred [%s] (client=%d/%d, server full; retry in %ds)",
                                st.id, activeCnt, targetStack, nextBo)
                        end
                    end
                end
            end
        end
    end
end

local function MakeLootboxObject(uid, giftName)
    local dirData = nil
    local dir = Modules.Directory
    if type(dir) == "table" and type(dir.Lootboxes) == "table" then
        for id, data in pairs(dir.Lootboxes) do
            if string.lower(tostring(id)) == string.lower(tostring(giftName)) then
                dirData = data
                break
            end
        end
    end
    if type(dirData) ~= "table" then
        dirData = { _id = giftName, Instant = false, IsCardPack = false }
    end
    local fakeItem = {
        _uid = uid,
        _id = giftName,
        id = giftName,
        uid = uid,
        _data = { id = giftName, _am = 8 },
        GetId = function() return giftName end,
        GetUID = function() return uid end,
        Directory = function() return dirData end,
        GetDirectory = function() return dirData end,
    }
    return setmetatable(fakeItem, {
        __index = function()
            return function() return dirData end
        end,
    })
end

local function StepAutoOpenItems()
    local now = os.clock()
    if (now - (Runtime.Cache.LastAutoOpenItemsAt or 0)) < 2.0 then return end
    Runtime.Cache.LastAutoOpenItemsAt = now

    local targetSet = {}
    local hasAny = false
    for _, list in ipairs({ Config.AutoOpen, Config.Lootbox }) do
        if type(list) == "table" then
            for k, v in pairs(list) do
                if type(k) == "number" and type(v) == "string" and v ~= "" then
                    targetSet[string.lower(v)] = v
                    hasAny = true
                elseif type(k) == "string" and v == true then
                    targetSet[string.lower(k)] = k
                    hasAny = true
                end
            end
        end
    end
    if not hasAny then return end

    -- 1. Misc bundles / gift bags (GiftBag_Open)
    local invMisc = Runtime.Helpers.GetSaveInventory("Misc")
    if type(invMisc) == "table" and Modules.Network then
        for _, itemData in pairs(invMisc) do
            if type(itemData) == "table" and type(itemData.id) == "string" then
                local idStr = itemData.id
                if targetSet[string.lower(idStr)] then
                    local amt = math.max(1, math.floor(tonumber(itemData._am) or 1))
                    local openQty = math.min(amt, 50)
                    local okOpen, resOpen = pcall(Modules.Network.Invoke, "GiftBag_Open", idStr, openQty)
                    if not okOpen or resOpen == false then
                        okOpen, resOpen = pcall(Modules.Network.Invoke, "GiftBag_Open", idStr, 1)
                        openQty = 1
                    end
                    if okOpen and resOpen ~= false then
                        Runtime.Stats.GiftsOpened = (Runtime.Stats.GiftsOpened or 0) + openQty
                        Log("INFO", "Opened %dx %s (Misc Bundle)", openQty, idStr)
                        task.wait(0.08)
                        break
                    end
                end
            end
        end
    end

    -- 2. Standard Lootboxes (LootboxCmds.Open + PresentCmds.OpenCurrent)
    local flannelName = string.lower(tostring(Runtime.Helpers.GetGiftItemName() or "Flannel Gift"))
    local eventOpenerOn = (Workspace:GetAttribute("PumpkinTycoonGiftOpener") == true)
    local invLootbox = Runtime.Helpers.GetSaveInventory("Lootbox")
    if type(invLootbox) == "table" and Modules.LootboxCmds and type(Modules.LootboxCmds.Open) == "function" then
        for uid, itemData in pairs(invLootbox) do
            if type(itemData) == "table" and type(itemData.id) == "string" then
                local idStr = itemData.id
                local lowerId = string.lower(idStr)
                if targetSet[lowerId] and not (eventOpenerOn and lowerId == flannelName) then
                    local amt = math.max(1, math.floor(tonumber(itemData._am) or 1))
                    local openQty = math.clamp(math.min(amt, Config.GiftBatchAmount or 8), 1, 8)
                    local itemObj = MakeLootboxObject(tostring(uid), idStr)
                    if Modules.PresentCmds and type(Modules.PresentCmds.OpenCurrent) == "function" then
                        callWithSavedIdentity(Modules.PresentCmds.OpenCurrent)
                    end
                    callWithSavedIdentity(Modules.LootboxCmds.Open, itemObj, openQty)
                    task.wait(0.8)
                    if Modules.PresentCmds and type(Modules.PresentCmds.OpenCurrent) == "function" then
                        callWithSavedIdentity(Modules.PresentCmds.OpenCurrent)
                    end
                    if Modules.PresentCmds and type(Modules.PresentCmds.Current) == "function" then
                        callWithSavedIdentity(function()
                            local cur = Modules.PresentCmds.Current()
                            if type(cur) == "table" then
                                for k, p in pairs(cur) do
                                    if type(p) == "table" then
                                        p._destroyed = true
                                    end
                                    cur[k] = nil
                                end
                            end
                        end)
                    end
                    Runtime.Stats.GiftsOpened = (Runtime.Stats.GiftsOpened or 0) + openQty
                    Log("INFO", "Opened %dx %s (Lootbox)", openQty, idStr)
                    break
                end
            end
        end
    end
end

local function StepConsumePotions()
    if type(Config.Potions) ~= "table" or next(Config.Potions) == nil then return end
    local now = os.clock()
    if (now - (Runtime.Cache.LastPotionsStepAt or 0)) < 5.0 then return end
    Runtime.Cache.LastPotionsStepAt = now

    local invPotions = Runtime.Helpers.GetSaveInventory("Potion")
    if type(invPotions) ~= "table" or next(invPotions) == nil then return end

    local wanted = {}
    for k, v in pairs(Config.Potions) do
        if type(k) == "number" and type(v) == "string" and v ~= "" then
            wanted[string.lower(v)] = true
        elseif type(k) == "string" and v == true then
            wanted[string.lower(k)] = true
        end
    end
    if next(wanted) == nil then return end

    local activePotions = nil
    if Modules.PotionCmds and type(Modules.PotionCmds.GetActivePotions) == "function" then
        local okA, resA = callWithSavedIdentity(Modules.PotionCmds.GetActivePotions)
        if okA and type(resA) == "table" then
            activePotions = resA
        end
    end
    if not activePotions then
        local saveData = Runtime.Helpers.GetSaveData()
        activePotions = saveData and saveData.Potions or {}
    end

    local bestByPotionId = {}
    for uid, data in pairs(invPotions) do
        if type(data) == "table" and type(data.id) == "string" then
            local lowerId = string.lower(data.id)
            if wanted[lowerId] then
                local tier = math.max(1, math.floor(tonumber(data.tn or data.tier or 1) or 1))
                local prev = bestByPotionId[lowerId]
                if not prev or tier > prev.tier then
                    bestByPotionId[lowerId] = {
                        uid = tostring(uid),
                        id = data.id,
                        tier = tier,
                    }
                end
            end
        end
    end

    Runtime.Cache.PotionConsumeCooldown = Runtime.Cache.PotionConsumeCooldown or {}
    for lowerId, cand in pairs(bestByPotionId) do
        local nextAt = Runtime.Cache.PotionConsumeCooldown[lowerId] or 0
        if now >= nextAt then
            local isActive = false
            if type(activePotions) == "table" then
                local actEntry = activePotions[cand.id]
                if type(actEntry) == "table" then
                    for tKey, expData in pairs(actEntry) do
                        local actTier = tonumber(tKey) or cand.tier
                        local rem = (type(expData) == "table" and tonumber(expData.TimeLeft or expData.time)) or tonumber(expData) or 0
                        if actTier >= cand.tier and rem > 20 then
                            isActive = true
                            break
                        end
                    end
                end
            end
            if not isActive then
                local used = false
                if Modules.PotionCmds and type(Modules.PotionCmds.Consume) == "function" then
                    local okC, resC = callWithSavedIdentity(Modules.PotionCmds.Consume, cand.uid)
                    used = (okC and resC ~= false)
                elseif Modules.Network then
                    local okC, resC = pcall(Modules.Network.Invoke, "Potions_Consume", cand.uid, 1)
                    used = (okC and resC ~= false)
                end
                if used then
                    Runtime.Cache.PotionConsumeCooldown[lowerId] = now + 15.0
                    Log("INFO", "Consumed Potion [%s Tier %d]", cand.id, cand.tier)
                    task.wait(0.08)
                else
                    Runtime.Cache.PotionConsumeCooldown[lowerId] = now + 30.0
                end
            end
        end
    end
end

local function StepEquipEnchants()
    if type(Config.Enchants) ~= "table" or next(Config.Enchants) == nil then return end
    local now = os.clock()
    if (now - (Runtime.Cache.LastEnchantsStepAt or 0)) < 10.0 then return end
    Runtime.Cache.LastEnchantsStepAt = now

    local saveData = Runtime.Helpers.GetSaveData()
    local invEnchants = saveData and saveData.Inventory and saveData.Inventory.Enchant
    if type(invEnchants) ~= "table" or next(invEnchants) == nil then return end

    local wantedCounts = {}
    for k, v in pairs(Config.Enchants) do
        if type(k) == "number" and type(v) == "string" and v ~= "" then
            local key = string.lower(v)
            wantedCounts[key] = (wantedCounts[key] or 0) + 1
        elseif type(k) == "string" and type(v) == "number" and v > 0 then
            local key = string.lower(k)
            wantedCounts[key] = math.floor(v)
        elseif type(k) == "string" and v == true then
            local key = string.lower(k)
            wantedCounts[key] = (wantedCounts[key] or 0) + 1
        end
    end
    if next(wantedCounts) == nil then return end

    local equippedMap = type(saveData.EquippedEnchants) == "table" and saveData.EquippedEnchants or {}
    local equippedCounts = {}
    local equippedUids = {}
    for _, eqUid in pairs(equippedMap) do
        local uidStr = tostring(eqUid)
        equippedUids[uidStr] = true
        local item = invEnchants[uidStr] or invEnchants[eqUid]
        if type(item) == "table" and type(item.id) == "string" then
            local key = string.lower(item.id)
            equippedCounts[key] = (equippedCounts[key] or 0) + 1
        end
    end

    for wantKey, wantQty in pairs(wantedCounts) do
        local curQty = equippedCounts[wantKey] or 0
        if curQty < wantQty then
            local bestUid, bestTier, bestName = nil, -1, nil
            for uid, data in pairs(invEnchants) do
                local uidStr = tostring(uid)
                if type(data) == "table" and type(data.id) == "string" and string.lower(data.id) == wantKey then
                    local amt = math.max(1, math.floor(tonumber(data._am) or 1))
                    local availAmt = equippedUids[uidStr] and (amt - 1) or amt
                    if availAmt >= 1 then
                        local tier = math.max(1, math.floor(tonumber(data.tn or data.tier or 1) or 1))
                        if tier > bestTier then
                            bestTier = tier
                            bestUid = uidStr
                            bestName = data.id
                        end
                    end
                end
            end
            if bestUid then
                local okEq, resEq = false, false
                if Modules.EnchantCmds and type(Modules.EnchantCmds.Equip) == "function" then
                    okEq, resEq = callWithSavedIdentity(Modules.EnchantCmds.Equip, bestUid)
                elseif Modules.Network then
                    okEq, resEq = pcall(Modules.Network.Invoke, "Enchants_Equip", bestUid)
                end
                if okEq and resEq ~= false then
                    Log("INFO", "Equipped Enchant [%s Tier %d]", tostring(bestName), bestTier)
                    task.wait(0.1)
                end
            end
        end
    end
end

-- ============================================================================
-- 5. DUCKK CUSTOM EVENT ENGINE — STATE & ONBOARDING (UPDATE 103: TURKEY HUNT)
-- ============================================================================
local DuckkEvent = {
    Onboarding = {},
    Dag = {},
    Pedestals = {},
    Tokens = {},
    Boosts = {},
    Turkey = {},
    Wild = {},
    Combat = {},
    Hatch = {},
    Fusion = {},
}

local activeFarmTarget = nil
local Craft = {} -- Exposed for AutoMail Daycare UID protection compatibility

function DuckkEvent.Onboarding.EnsurePlot()
    if IsInEventInstance() then
        local plot = GetMyPlot()
        if plot then return plot end
        Runtime.Stats.Phase = "Binding Plot"
        local waitUntil = os.clock() + 5.0
        while IsRunning() and IsInEventInstance() and os.clock() < waitUntil do
            plot = GetMyPlot()
            if plot then
                Log("INFO", "[DuckkEvent] Bound plot %s", tostring(plot:GetId()))
                return plot
            end
            task.wait(0.15)
        end
        return nil
    end

    if not Config.AutoJoin then return nil end
    local now = os.clock()
    if (now - (Runtime.Cache.LastJoinAttemptAt or 0)) < 3.0 then return nil end
    Runtime.Cache.LastJoinAttemptAt = now

    Runtime.Stats.Phase = "Entering Event"
    Log("INFO", "[DuckkEvent] Entering %s instance...", tostring(INSTANCE_ID))
    if Modules.InstancingCmds and type(Modules.InstancingCmds.Enter) == "function" then
        pcall(Modules.InstancingCmds.Enter, INSTANCE_ID)
    end
    if not IsInEventInstance() and Modules.Network and type(Modules.Network.Invoke) == "function" then
        pcall(Modules.Network.Invoke, "Instancing_PlayerEnterInstance", INSTANCE_ID)
    end

    local deadline = os.clock() + 8.0
    while IsRunning() and os.clock() < deadline do
        local plot = GetMyPlot()
        if IsInEventInstance() and plot then
            Log("INFO", "[DuckkEvent] Entered plot %s", tostring(plot:GetId()))
            return plot
        end
        task.wait(0.2)
    end
    return nil
end

function DuckkEvent.Onboarding.StepTutorial(plot)
    if not Config.AutoTutorial or not plot then return end
    if Runtime.Cache.TutorialDonePlot == plot then return end
    if Runtime.Helpers.GetPlotSave(plot, VAR.Tutorial) == true then
        Runtime.Cache.TutorialDonePlot = plot
        return
    end
    local now = os.clock()
    if (now - (Runtime.Cache.LastTutorialInvokeAt or 0)) < 5.0 then return end
    Runtime.Cache.LastTutorialInvokeAt = now
    if pcall(plot.Invoke, plot, NET.TutorialDone) then
        Runtime.Helpers.InvalidatePlotSave(plot, VAR.Tutorial)
    end
end

-- ============================================================================
-- 6. DUCKK DAG CRITICAL-PATH BUTTON SOLVER & REBIRTH PIPELINE
-- ============================================================================
local PRODUCTIVE_BUTTON_IDS = {
    UpgradeMachine = true,
    CocoaStand = true,
    GoldMachine = true,
    RainbowMachine = true,
    PetNetStore = true,
    Merchant = true,
}

local PRODUCTIVE_SUBCLASSES = {
    IslandLuck = true,
    CoinsBoost = true,
    DamageBoost = true,
}

function DuckkEvent.Dag.IsProductiveNode(btn)
    if type(btn) ~= "table" or btn.Optional == true then return false end
    if btn.Opens or btn.PathIndex or btn.Egg or btn.Pedestal then return true end
    local id = tostring(btn.Id or "")
    if PRODUCTIVE_BUTTON_IDS[id] or PRODUCTIVE_SUBCLASSES[tostring(btn.Subclass or "")] then
        return true
    end
    if string.sub(id, 1, 12) == "OrchardChest" or string.sub(id, -5) == "_Luck" or string.find(id, "Pedestal", 1, true) then
        return true
    end
    return false
end

function DuckkEvent.Dag.GetCriticalSet(isPart2)
    local p2 = (isPart2 == true)
    if Runtime.Cache.CriticalButtons ~= nil and Runtime.Cache.CriticalButtonsPart2 == p2 then
        return Runtime.Cache.CriticalButtons
    end
    local crit = {}
    local byId = Modules.ButtonsTypes and Modules.ButtonsTypes.BY_ID
    local allBtns = Modules.ButtonsTypes and Modules.ButtonsTypes.BUTTONS
    if type(allBtns) == "table" then
        local bfs = {}
        for _, b in ipairs(allBtns) do
            local part = b.Part or 1
            if type(b) == "table" and b.Id and ((part == 1) or (p2 and part == 2)) and DuckkEvent.Dag.IsProductiveNode(b) then
                if not crit[b.Id] then
                    crit[b.Id] = true
                    table.insert(bfs, b)
                end
            end
        end
        local head = 1
        while head <= #bfs do
            local node = bfs[head]
            head = head + 1
            if type(node.Required) == "table" and type(byId) == "table" then
                for _, reqId in ipairs(node.Required) do
                    if not crit[reqId] then
                        crit[reqId] = true
                        if type(byId[reqId]) == "table" then
                            table.insert(bfs, byId[reqId])
                        end
                    end
                end
            end
        end
    end
    Runtime.Cache.CriticalButtons = crit
    Runtime.Cache.CriticalButtonsPart2 = p2
    return crit
end

function DuckkEvent.Dag.GetPriceMult()
    if PT_Buttons and type(PT_Buttons.PriceMult) == "function" then
        local ok, m = pcall(PT_Buttons.PriceMult)
        if ok and type(m) == "number" then return m end
    end
    return tonumber(GetFlag("PumpkinTycoon_ButtonPriceMult", 1)) or 1
end

function DuckkEvent.Dag.WantRebirth(rebirths)
    local tgt = math.floor(tonumber(Config.TargetRebirths) or 0)
    return (tgt < 0) or (tgt > 0 and (tonumber(rebirths) or 0) < tgt)
end

function DuckkEvent.Dag.ScanBuyable(buttons, zones, isPart2, priceMult, tycoonComplete, spendableCoins, rebirths)
    local avail = Modules.PumpkinButtonsUtil.Available(buttons, zones, isPart2, priceMult)
    local critSet = DuckkEvent.Dag.GetCriticalSet(isPart2)
    local minCritPrice = math.huge
    local hasCrit = false
    local candidates = {}
    local wantReb = DuckkEvent.Dag.WantRebirth(rebirths)

    for _, btn in ipairs(avail) do
        local isOptional = (btn.Optional == true)
        local allowOptional = false
        if isOptional and tycoonComplete then
            if btn.Id == "Zone8_Cannon" and Config.AutoTurkeyBoss ~= false then
                allowOptional = true
            elseif btn.Id == "Zone8_RebirthShrine" and wantReb then
                allowOptional = true
            elseif Config.BuyOptionalPart2Buttons == true then
                allowOptional = true
            end
        end

        if (not isOptional) or allowOptional then
            local price = Modules.PumpkinButtonsUtil.Price(btn, priceMult)
            local tier = isOptional and 3 or (critSet[btn.Id] and 1 or 2)
            if tier == 1 then
                hasCrit = true
                if price < minCritPrice then minCritPrice = price end
            end
            table.insert(candidates, { btn = btn, price = price, tier = tier })
        end
    end

    -- Duckk 3% Dead-End Guard: never leak Rush coins into decorative leaves unless <= 3% of next critical button
    local nextMinPrice = nil
    local buyable = {}
    for _, c in ipairs(candidates) do
        if c.tier == 1 or (not hasCrit) or c.price <= (minCritPrice * 0.03) then
            if type(c.price) == "number" and c.price > 0 and (not nextMinPrice or c.price < nextMinPrice) then
                nextMinPrice = c.price
            end
            if spendableCoins ~= nil and c.price <= spendableCoins then
                table.insert(buyable, c)
            end
        end
    end

    table.sort(buyable, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.price ~= b.price then return a.price < b.price end
        return tostring(a.btn.Id) < tostring(b.btn.Id)
    end)

    return buyable, nextMinPrice, (hasCrit and minCritPrice or nil)
end

function Runtime.Helpers.IsEarlyZoneHatchActive(plot, buttons)
    local startZone = math.floor(tonumber(Config.HatchStartZone) or 0)
    if startZone < 1 or not plot or not Modules.PumpkinButtonsUtil or not Modules.PumpkinButtonsUtil.Owned then
        return false
    end
    local zoneList = PT and PT.ZONES
    if type(zoneList) ~= "table" then return false end
    local zoneMeta = zoneList[math.clamp(startZone, 1, #zoneList)]
    if type(zoneMeta) ~= "table" or type(zoneMeta.Section) ~= "string" then return false end
    local btnState = buttons or Runtime.Cache.Buttons or Runtime.Helpers.GetPlotSave(plot, VAR.Buttons)
    if type(btnState) ~= "table" then return false end
    return Modules.PumpkinButtonsUtil.Owned(btnState, zoneMeta.Section .. "_Zone") == true
        and Modules.PumpkinButtonsUtil.Owned(btnState, zoneMeta.Section .. "_Egg") == true
end

function Runtime.Helpers.GetNextBuyableButtonMinPrice(plot, buttons, tycoonComplete)
    if not plot or not Modules.PumpkinButtonsUtil or not Modules.PumpkinButtonsUtil.Available then return nil end
    local btnState = buttons or Runtime.Cache.Buttons or Runtime.Helpers.GetPlotSave(plot, VAR.Buttons)
    if type(btnState) ~= "table" then return nil end
    local isPart2 = Runtime.Helpers.IsPlotPart2Active(plot)
    local _, nextMin = DuckkEvent.Dag.ScanBuyable(
        btnState, GetZoneCount(plot), isPart2, DuckkEvent.Dag.GetPriceMult(), tycoonComplete == true, nil, Runtime.Stats.Rebirths
    )
    return nextMin
end

function DuckkEvent.Dag.ClaimAndRebirth(plot, buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths)
    local now = os.clock()

    if Config.AutoCompleteTycoon and tycoonComplete and not claimed1 then
        local ok, res = pcall(plot.Invoke, plot, NET.Complete)
        if ok and res ~= false then
            Runtime.Helpers.InvalidatePlotSave(plot, VAR.Buttons)
            Log("INFO", "[DuckkEvent] Claimed Part 1 Tycoon Completion (BT_Settle)!")
            buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths = GetProgressState(plot, true)
        end
    end

    if Config.AutoCompletePart2 ~= false and isPart2 and tycoonComplete and not claimed2 and NET.Complete2 and not Runtime.Cache.Complete2Unsupported then
        if (now - (Runtime.Cache.LastComplete2FailAt or 0)) >= 15.0 then
            local ok2, res2, err2 = pcall(plot.Invoke, plot, NET.Complete2)
            if ok2 and res2 ~= false then
                Runtime.Cache.LastComplete2FailAt = 0
                Runtime.Helpers.InvalidatePlotSave(plot, VAR.Buttons)
                Log("INFO", "[DuckkEvent] Claimed Part 2 Tycoon Completion (MH_Conclude)!")
                buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths = GetProgressState(plot, true)
            else
                Runtime.Cache.LastComplete2FailAt = now
                if string.find(tostring(err2 or res2), "UnhandledOwnerInvoke", 1, true) then
                    Runtime.Cache.Complete2Unsupported = true
                end
            end
        end
    end

    if DuckkEvent.Dag.WantRebirth(rebirths) and isPart2 and tycoonComplete and NET.Rebirth
        and GetFlag("PumpkinTycoon_Rebirth", false) == true
        and (not Config.AutoCompleteTycoon or claimed1)
        and (Config.AutoCompletePart2 == false or claimed2 or Runtime.Cache.Complete2Unsupported == true)
        and (now - (Runtime.Cache.LastRebirthFailAt or 0)) >= 10.0
    then
        local okR, resR, _, giftsR, newRebR = pcall(plot.Invoke, plot, NET.Rebirth)
        if okR and resR == true then
            Runtime.Cache.LastRebirthFailAt = 0
            Runtime.Helpers.InvalidatePlotSave(plot, VAR.Buttons)
            Runtime.Helpers.InvalidatePlotSave(plot, VAR.Rebirths)
            table.clear(Runtime.Cache.TargetEggCache)
            table.clear(Runtime.Cache.EarlyHatchedByEgg)
            table.clear(Runtime.Cache.EarlyCoinsSpentByEgg)
            Runtime.Cache.ReserveEarlyEggCost = 0
            Runtime.Cache.LastButtonsDoneForDecor = -1
            Runtime.Cache.LastCoinRateSampleAt = 0
            table.clear(Runtime.Cache.CoinRateSamples)
            Runtime.Cache.LastGrossCoins = nil
            Log("INFO", "[DuckkEvent] Rebirth #%s complete (+%s Gifts)!", tostring(newRebR or (rebirths + 1)), tostring(giftsR or "?"))
            buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths = GetProgressState(plot, true)
        else
            Runtime.Cache.LastRebirthFailAt = now
        end
    end

    return buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths
end

function DuckkEvent.Dag.Step(plot)
    if not plot or not Modules.PumpkinButtonsUtil then return nil, false, false, false, false, 0 end

    local now = os.clock()
    local urgent = (Runtime.Cache.ButtonBuyRequestedAt or 0) > (Runtime.Cache.LastButtonsStepAt or 0)
    if not urgent and Runtime.Cache.Buttons ~= nil and (now - (Runtime.Cache.LastButtonsStepAt or 0)) < 0.45 then
        return Runtime.Cache.Buttons, Runtime.Stats.TycoonComplete, Runtime.Stats.CompletedClaimed,
            Runtime.Stats.Completed2Claimed, Runtime.Helpers.IsPlotPart2Active(plot), Runtime.Stats.Rebirths
    end
    Runtime.Cache.LastButtonsStepAt = now
    Runtime.Cache.ButtonBuyRequestedAt = 0

    local buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths = GetProgressState(plot)
    buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths =
        DuckkEvent.Dag.ClaimAndRebirth(plot, buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths)

    if not Config.AutoBuyButtons then
        return buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths
    end

    local zones = GetZoneCount(plot)
    local priceMult = DuckkEvent.Dag.GetPriceMult()
    local coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
    local zoneHatchOn = Runtime.Helpers.IsEarlyZoneHatchActive(plot, buttons)

    if not tycoonComplete and not zoneHatchOn then
        DuckkEvent.Hatch.EvaluateBootstrap(plot, buttons)
    else
        Runtime.Cache.ReserveEarlyEggCost = 0
    end

    local burst = 0
    while IsRunning() and burst < 100 do
        if Config.RushButtonsFirst and not tycoonComplete and not zoneHatchOn and Runtime.Stats.IsHatching then break end
        local spendable = math.max(0, coins - (Runtime.Cache.ReserveEarlyEggCost or 0))
        local buyable = DuckkEvent.Dag.ScanBuyable(buttons, zones, isPart2, priceMult, tycoonComplete, spendable, rebirths)
        if #buyable == 0 then break end

        local target = buyable[1]
        local ok, res = pcall(plot.Invoke, plot, NET.Buy, target.btn.Id)
        if not ok or res == false then
            Runtime.Cache.LastButtonBuyFailAt = os.clock()
            break
        end
        Runtime.Cache.LastButtonBuyFailAt = 0
        burst = burst + 1
        Runtime.Helpers.InvalidatePlotSave(plot, VAR.Buttons)
        table.clear(Runtime.Cache.TargetEggCache)
        Runtime.Helpers.RecordCoinsSpent(target.price)
        Log("INFO", "[DuckkEvent] Unlocked [%s] (%s Coins)", tostring(target.btn.Id), tostring(target.price))

        buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths = GetProgressState(plot, true)
        coins = Runtime.Stats.Coins
        zoneHatchOn = Runtime.Helpers.IsEarlyZoneHatchActive(plot, buttons)
        if not tycoonComplete and not zoneHatchOn then
            DuckkEvent.Hatch.EvaluateBootstrap(plot, buttons)
        else
            Runtime.Cache.ReserveEarlyEggCost = 0
        end
        task.wait(0.02)
    end

    buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths =
        DuckkEvent.Dag.ClaimAndRebirth(plot, buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths)

    return buttons, tycoonComplete, claimed1, claimed2, isPart2, rebirths
end

-- ============================================================================
-- 7. DUCKK DUAL-MODE PEDESTAL ARBITER & MERCHANT ALLOCATOR
--    Mode A (Rush Z6+): Maximize Passive Patch Coins/s (EarnRate Lock)
--    Mode B (Endgame 117/117): Minimal-Slot +100% Luck Lock -> Max Token Slots
-- ============================================================================
local BASE_CPS_LADDER = { 0.02, 0.05, 0.10, 0.25, 0.50, 1.00, 2.50, 6.00 }
local BASE_LUCK_LADDER = { 1, 2, 4, 8, 15, 30, 60, 120 }

function Runtime.Helpers.GetRungBaseCps(rung)
    local r = math.clamp(math.floor(tonumber(rung) or 1), 1, 8)
    local earn = Modules.PumpkinEarnUtil
    if earn and type(earn.Config) == "function" then
        local ok, cfg = pcall(earn.Config)
        if ok and type(cfg) == "table" and type(cfg.Cps) == "table" and type(cfg.Cps[r]) == "number" then
            return cfg.Cps[r]
        end
    end
    return BASE_CPS_LADDER[r] or 0.02
end

function Runtime.Helpers.ComputePedestalEarnScore(standing)
    if type(standing) ~= "table" then return 0 end
    local r = math.clamp(math.floor(tonumber(standing.R) or 1), 1, 8)
    local earn = Modules.PumpkinEarnUtil
    if earn and type(earn.Config) == "function" and type(earn.VariantMult) == "function" then
        local okC, cfg = pcall(earn.Config)
        if okC and type(cfg) == "table" and type(cfg.Cps) == "table" then
            local base = tonumber(cfg.Cps[r]) or Runtime.Helpers.GetRungBaseCps(r)
            local okV, vm = pcall(earn.VariantMult, cfg, standing)
            if okV and type(vm) == "number" and vm > 0 then return base * vm end
        end
    end
    local mult = (standing.Rb and 5 or (standing.Gold and 2 or 1)) * (standing.Sh and 3 or 1)
    return Runtime.Helpers.GetRungBaseCps(r) * mult
end

function Runtime.Helpers.GetPumpkinLuckConfig()
    local pe = Modules.PumpkinEarnUtil
    if pe and type(pe.Config) == "function" then
        local ok, cfg = pcall(pe.Config)
        if ok and type(cfg) == "table" and type(cfg.Luck) == "table" then
            return cfg.Luck, tonumber(cfg.PumpkinLuckCap) or 100
        end
    end
    return BASE_LUCK_LADDER, 100
end

local function AnalyzePedestals(plot)
    local raw, ver = Runtime.Helpers.GetPlotSave(plot, VAR.Pedestals)
    if Runtime.Cache.PedInfoCache and Runtime.Cache.PedInfoVer == ver and Runtime.Cache.PlotSavePlot == plot then
        return Runtime.Cache.PedInfoCache
    end

    local maxPed = (PT and PT.MAX_PEDESTALS) or 8
    local unlockedCount = 0
    local emptyIndices = {}
    local occupied = {}
    local lockedList = {}
    local byIndex = {}

    if type(raw) == "table" then
        for i = 1, maxPed do
            local slot = raw[i]
            if type(slot) == "table" and slot.Unlocked == true then
                unlockedCount = unlockedCount + 1
                if type(slot.Standing) ~= "table" then
                    table.insert(emptyIndices, i)
                else
                    local rung = tonumber(slot.Standing.R) or 1
                    local isLocked = (slot.Locked == true)
                    local item = {
                        index = i,
                        rung = rung,
                        locked = isLocked,
                        earnScore = Runtime.Helpers.ComputePedestalEarnScore(slot.Standing),
                        standing = slot.Standing,
                    }
                    byIndex[i] = item
                    table.insert(occupied, item)
                    if isLocked then
                        table.insert(lockedList, item)
                    end
                end
            end
        end
    end

    table.sort(lockedList, function(a, b)
        if a.earnScore ~= b.earnScore then return a.earnScore < b.earnScore end
        if a.rung ~= b.rung then return a.rung < b.rung end
        return a.index < b.index
    end)

    local info = {
        raw = raw,
        unlockedCount = unlockedCount,
        emptyIndices = emptyIndices,
        occupied = occupied,
        lockedList = lockedList,
        byIndex = byIndex,
    }
    Runtime.Cache.PedInfoCache = info
    Runtime.Cache.PedInfoVer = ver
    return info
end

local function GetKeepLockSettings(maxAllowed, unlockedCount, plot, buttons, tycoonComplete)
    local limit = type(maxAllowed) == "number" and math.max(0, math.floor(maxAllowed)) or 8
    local keepRung = math.clamp(math.floor(tonumber(Config.KeepRung) or 0), 0, limit)
    if keepRung == 1 then keepRung = 0 end

    local autoPart2 = false
    local smartLuckMode = false
    if keepRung == 0 and Config.AutoKeepPart2Pedestals ~= false then
        local p = plot or GetMyPlot()
        local btns = buttons or Runtime.Cache.Buttons
        local hasZ6 = Modules.PumpkinButtonsUtil and btns and Modules.PumpkinButtonsUtil.Owned(btns, "Zone6_Zone")
        if hasZ6 and p and Runtime.Helpers.IsPlotPart2Active(p) then
            keepRung = math.clamp(math.floor(tonumber(Config.Part2KeepMinRung) or 4), 2, limit)
            autoPart2 = true
            local done = (tycoonComplete ~= nil) and (tycoonComplete == true) or (Runtime.Stats.TycoonComplete == true)
            if done and not DuckkEvent.Dag.WantRebirth(Runtime.Stats.Rebirths) and Config.PostCompleteSmartLuckLock ~= false then
                smartLuckMode = true
            end
        end
    end

    local lockMin = (keepRung >= 2) and keepRung or 0
    local minFarm = 1
    if (unlockedCount or 0) > 1 then
        minFarm = autoPart2 and math.clamp(math.floor(tonumber(Config.Part2MinFarmPedestals) or 1), 1, unlockedCount - 1)
            or ((unlockedCount >= 5) and 2 or 1)
    end
    local maxKeepSlots = (lockMin >= 2 and (unlockedCount or 0) > 0) and math.max(0, unlockedCount - minFarm) or 0
    return keepRung, lockMin, maxKeepSlots, autoPart2, smartLuckMode
end

function Runtime.Helpers.ComputeSmartLuckKeepSet(pedInfo, lockMin, maxKeepSlots)
    local keepSet, keepList = {}, {}
    if not pedInfo or type(pedInfo.occupied) ~= "table" or maxKeepSlots <= 0 then
        return keepSet, keepList, 0, 100
    end
    local luckLadder, luckCap = Runtime.Helpers.GetPumpkinLuckConfig()
    local pool = {}
    for _, occ in ipairs(pedInfo.occupied) do
        local r = tonumber(occ.rung) or 1
        if r >= math.max(2, lockMin or 4) then
            local lk = tonumber(luckLadder[math.clamp(r, 1, #luckLadder)]) or 0
            if lk > 0 then
                table.insert(pool, {
                    index = occ.index,
                    rung = r,
                    luck = lk,
                    earnScore = occ.earnScore or 0,
                    locked = occ.locked == true,
                })
            end
        end
    end
    table.sort(pool, function(a, b)
        if a.luck ~= b.luck then return a.luck > b.luck end
        if a.locked ~= b.locked then return a.locked end
        if a.earnScore ~= b.earnScore then return a.earnScore > b.earnScore end
        return a.index < b.index
    end)
    local sumLuck = 0
    for _, item in ipairs(pool) do
        if #keepList >= maxKeepSlots or sumLuck >= luckCap then break end
        keepSet[item.index] = item
        table.insert(keepList, item)
        sumLuck = sumLuck + item.luck
    end
    return keepSet, keepList, sumLuck, luckCap
end

function DuckkEvent.Pedestals.IsProtectedFromFarm(pedInfo, maxKeepSlots, pedIdx, rung, lockMin, smartLuckMode)
    if (lockMin or 0) < 2 or maxKeepSlots <= 0 then return false end
    if smartLuckMode then
        local keepSet = Runtime.Helpers.ComputeSmartLuckKeepSet(pedInfo, lockMin, maxKeepSlots)
        return keepSet[pedIdx] ~= nil
    end
    local minEarn = Runtime.Helpers.GetRungBaseCps(lockMin)
    local occ = pedInfo and pedInfo.byIndex and pedInfo.byIndex[pedIdx]
    local score = (occ and occ.earnScore) or Runtime.Helpers.ComputePedestalEarnScore({ R = rung })
    if score + 1e-9 < minEarn then return false end
    if #pedInfo.lockedList < maxKeepSlots then return true end
    return Config.AutoLockUpgradeSwap and #pedInfo.lockedList > 0 and score > (pedInfo.lockedList[1].earnScore + 1e-6)
end

function DuckkEvent.Pedestals.Step(plot, buttons, tycoonComplete)
    if not plot or not Modules.MerchantTypes then return end
    local now = os.clock()
    if (now - (Runtime.Cache.LastKeepLockStepAt or 0)) < 0.5 then return end
    Runtime.Cache.LastKeepLockStepAt = now

    local pedInfo = AnalyzePedestals(plot)
    if pedInfo.unlockedCount == 0 then
        Runtime.Stats.LockedPedestals = 0
        Runtime.Stats.MaxKeepSlots = 0
        return
    end

    local maxBelow = tonumber(GetFlag("PumpkinTycoon_AutoBreakFreeBelow", 8)) or 8
    local keepDesired, lockMin, maxKeepSlots, _, smartLuckMode =
        GetKeepLockSettings(maxBelow, pedInfo.unlockedCount, plot, buttons, tycoonComplete)
    local lockedList = table.clone(pedInfo.lockedList)
    local sumLuck, luckCap = 0, 100

    if smartLuckMode then
        local keepSet, keepList, sLuck, lCap = Runtime.Helpers.ComputeSmartLuckKeepSet(pedInfo, lockMin, maxKeepSlots)
        sumLuck, luckCap = sLuck, lCap
        for _, item in ipairs(keepList) do
            if not item.locked then
                if pcall(plot.Invoke, plot, NET.SetLock, item.index, true) then
                    Runtime.Helpers.InvalidatePlotSave(plot, VAR.Pedestals)
                    table.insert(lockedList, { index = item.index, rung = item.rung, earnScore = item.earnScore, locked = true })
                end
                task.wait(0.03)
            end
        end
        for i = #lockedList, 1, -1 do
            if not keepSet[lockedList[i].index] then
                if pcall(plot.Invoke, plot, NET.SetLock, lockedList[i].index, false) then
                    Runtime.Helpers.InvalidatePlotSave(plot, VAR.Pedestals)
                    table.remove(lockedList, i)
                end
                task.wait(0.03)
            end
        end
        Runtime.Stats.MaxKeepSlots = math.max(#keepList, (sumLuck < luckCap) and maxKeepSlots or #keepList)
    else
        while #lockedList > maxKeepSlots do
            local drop = table.remove(lockedList, 1)
            pcall(plot.Invoke, plot, NET.SetLock, drop.index, false)
            Runtime.Helpers.InvalidatePlotSave(plot, VAR.Pedestals)
            task.wait(0.03)
        end
        if lockMin >= 2 and maxKeepSlots > 0 then
            local minEarn = Runtime.Helpers.GetRungBaseCps(lockMin)
            local cands = {}
            for _, occ in ipairs(pedInfo.occupied) do
                if not occ.locked and (occ.earnScore or 0) + 1e-9 >= minEarn then
                    table.insert(cands, occ)
                end
            end
            table.sort(cands, function(a, b)
                if a.earnScore ~= b.earnScore then return a.earnScore > b.earnScore end
                return a.rung > b.rung
            end)
            for _, cand in ipairs(cands) do
                if #lockedList < maxKeepSlots then
                    if pcall(plot.Invoke, plot, NET.SetLock, cand.index, true) then
                        Runtime.Helpers.InvalidatePlotSave(plot, VAR.Pedestals)
                        table.insert(lockedList, cand)
                        table.sort(lockedList, function(a, b) return a.earnScore < b.earnScore end)
                    end
                    task.wait(0.03)
                elseif Config.AutoLockUpgradeSwap and #lockedList > 0 and cand.earnScore > (lockedList[1].earnScore + 1e-6) then
                    local weakest = table.remove(lockedList, 1)
                    if pcall(plot.Invoke, plot, NET.SetLock, weakest.index, false) then
                        Runtime.Helpers.InvalidatePlotSave(plot, VAR.Pedestals)
                        task.wait(0.03)
                        if pcall(plot.Invoke, plot, NET.SetLock, cand.index, true) then
                            Runtime.Helpers.InvalidatePlotSave(plot, VAR.Pedestals)
                            table.insert(lockedList, cand)
                            table.sort(lockedList, function(a, b) return a.earnScore < b.earnScore end)
                        end
                    end
                    task.wait(0.03)
                end
            end
        end
        Runtime.Stats.MaxKeepSlots = maxKeepSlots
    end
    Runtime.Stats.LockedPedestals = #lockedList

    -- Sync Server Keep Policy (QW_Policy)
    if (os.clock() - (Runtime.Cache.LastPolicyInvokeAt or 0)) >= 0.6 then
        local targetPolicy = keepDesired
        if keepDesired <= 0 or maxKeepSlots <= 0 then
            targetPolicy = 0
        elseif smartLuckMode and sumLuck >= luckCap then
            targetPolicy = (#lockedList <= 1) and 0 or ((#lockedList == 2) and 8 or 7)
        elseif #lockedList >= maxKeepSlots then
            targetPolicy = 8
        end
        local rawAuto = Runtime.Helpers.GetPlotSave(plot, VAR.AutoBreak)
        local curPolicy = (type(rawAuto) == "table" and tonumber(rawAuto.Below)) or tonumber(rawAuto) or 0
        if curPolicy ~= targetPolicy then
            Runtime.Cache.LastPolicyInvokeAt = os.clock()
            if pcall(plot.Invoke, plot, NET.SetAutoBreak, targetPolicy) then
                Runtime.Helpers.InvalidatePlotSave(plot, VAR.AutoBreak)
            end
        end
    end

    -- Stock AutoPlace & Merchant Band Buyer
    local merchantOwned = Modules.PumpkinButtonsUtil and Modules.PumpkinButtonsUtil.Owned(buttons, Modules.MerchantTypes.BUTTON)
    if not merchantOwned then return end

    if Config.AutoPlaceStock then
        if Runtime.Helpers.GetPlotSave(plot, "StockAutoPlace") == false and Runtime.Cache.LastAutoPlace ~= true then
            Runtime.Cache.LastAutoPlace = true
            pcall(plot.Invoke, plot, NET.SetAutoPlace, true)
            Runtime.Helpers.InvalidatePlotSave(plot, "StockAutoPlace")
        end
        local stockList = Modules.MerchantTypes.CleanStock(Runtime.Helpers.GetPlotSave(plot, VAR.Stock))
        if #stockList > 0 and #pedInfo.emptyIndices > 0 then
            local counts = {}
            for _, b in ipairs(stockList) do counts[b] = (counts[b] or 0) + 1 end
            local bands = Modules.MerchantTypes.BANDS or {}
            local cursor = 1
            for idx = #bands, 1, -1 do
                local bKey = bands[idx]
                while (counts[bKey] or 0) > 0 and cursor <= #pedInfo.emptyIndices do
                    local pedIdx = pedInfo.emptyIndices[cursor]
                    cursor = cursor + 1
                    counts[bKey] = counts[bKey] - 1
                    if pcall(plot.Invoke, plot, NET.PlaceStock, pedIdx, bKey) then
                        Runtime.Helpers.InvalidatePlotSave(plot, VAR.Stock)
                        Runtime.Helpers.InvalidatePlotSave(plot, VAR.Pedestals)
                    else
                        break
                    end
                    task.wait(0.03)
                end
            end
        end
    end

    local autoVar = Modules.MerchantTypes.AUTO_VAR
    if (Config.KeepServerAutoMerchantOff or (Config.RushButtonsFirst and not tycoonComplete))
        and Runtime.Helpers.GetPlotSave(plot, autoVar) == true
    then
        pcall(plot.Invoke, plot, NET.SetAutoMerchant, false)
        Runtime.Helpers.InvalidatePlotSave(plot, autoVar)
    end

    if not Config.AutoBuyMerchant or Runtime.Stats.FightingTurkeyBoss then return end
    if (os.clock() - (Runtime.Cache.LastMerchantFailAt or 0)) < 15.0 then return end

    local rushMode = (Config.RushButtonsFirst == true and not tycoonComplete)
    if rushMode and not (Modules.PumpkinButtonsUtil and Modules.PumpkinButtonsUtil.Owned(buttons, "Zone6_Zone")) then
        return
    end

    local coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
    local activateCoins = tonumber(Config.MerchantActivateCoins) or 100000000
    local spareCoins = tonumber(Config.MerchantMinSpareCoins) or 50000000
    local rushShare = math.clamp(tonumber(Config.MerchantRushMaxCoinShare) or 0.05, 0, 1)
    if not rushMode and coins < activateCoins then return end

    local merchantClean = Modules.MerchantTypes.Clean(Runtime.Helpers.GetPlotSave(plot, VAR.Merchant))
    if not merchantClean or type(merchantClean.Items) ~= "table" then return end

    local stockCount = #Modules.MerchantTypes.CleanStock(Runtime.Helpers.GetPlotSave(plot, VAR.Stock))
    local maxSlots = LocalPlayer:GetAttribute(Modules.MerchantTypes.ATTR_SLOTS) or Modules.MerchantTypes.BaseSlots()
    local bandConfigs = Modules.MerchantTypes.Config()

    local function canBuyBand(price, bal)
        if type(price) ~= "number" or price <= 0 then return false end
        if rushMode then
            local spendable = math.max(0, bal - (Runtime.Cache.ReserveEarlyEggCost or 0))
            return spendable >= price and price <= (bal * rushShare)
        end
        return bal >= activateCoins and (bal - price) >= spareCoins
    end

    local wantVisit = false
    for _, bKey in ipairs(Config.MerchantBandOrder or {}) do
        if Config.AllowedMerchantBands[bKey] == true then
            local avail = merchantClean.Items[bKey] or 0
            local price = bandConfigs and bandConfigs[bKey] and bandConfigs[bKey].Price
            if avail > 0 and stockCount < maxSlots and canBuyBand(price, coins) then
                wantVisit = true
                break
            end
        end
    end
    if not wantVisit then return end

    WithMachinePad(plot, Modules.MerchantTypes.MACHINE, Modules.MerchantTypes.Range, function()
        for _, bKey in ipairs(Config.MerchantBandOrder or {}) do
            if Config.AllowedMerchantBands[bKey] == true then
                local avail = merchantClean.Items[bKey] or 0
                local price = bandConfigs and bandConfigs[bKey] and bandConfigs[bKey].Price
                while IsRunning() and avail > 0 and stockCount < maxSlots and canBuyBand(price, coins) do
                    local ok, res = pcall(plot.Invoke, plot, NET.BuyBand, bKey)
                    if not ok or res ~= true then
                        Runtime.Cache.LastMerchantFailAt = os.clock()
                        return
                    end
                    Runtime.Cache.LastMerchantFailAt = 0
                    Runtime.Helpers.InvalidatePlotSave(plot, VAR.Merchant)
                    Runtime.Helpers.InvalidatePlotSave(plot, VAR.Stock)
                    Runtime.Helpers.RecordCoinsSpent(price)
                    avail = avail - 1
                    stockCount = stockCount + 1
                    coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
                    Log("INFO", "[DuckkEvent] Merchant bought %s (%s Coins)", tostring(bKey), tostring(price))
                    task.wait(0.05)
                end
            end
        end
    end)
end

-- ============================================================================
-- 8. DUCKK WEIGHTED MARGINAL-ROI TOKEN UPGRADER
-- ============================================================================
local RUSH_UPGRADE_WEIGHTS = {
    PumpkinCoins = 3.2,
    PumpkinDamage = 2.8,
    RespawnSpeed = 2.4,
    SpawnLuck = 1.8,
    ChaseOdds = 1.5,
    EggLuck = 1.4,
    StockSlots = 1.1,
    MerchantLuck = 1.0,
}

local ENDGAME_UPGRADE_WEIGHTS = {
    EggLuck = 4.0,
    ChaseOdds = 3.6,
    SpawnLuck = 2.8,
    RespawnSpeed = 2.4,
    MerchantLuck = 1.6,
    StockSlots = 1.4,
    PumpkinDamage = 1.2,
    PumpkinCoins = 1.0,
}

local ALL_UPGRADE_TRACKS = {
    "PumpkinCoins", "PumpkinDamage", "RespawnSpeed", "SpawnLuck",
    "ChaseOdds", "EggLuck", "StockSlots", "MerchantLuck",
}

function DuckkEvent.Tokens.NextTrackOffer(trackKey, weights)
    local row = Modules.UpgradesTypes and Modules.UpgradesTypes.ROWS and Modules.UpgradesTypes.ROWS[trackKey]
    if not row or not Modules.UpgradesTypes.Id then return nil end

    local maxCaps = Config.UpgradeMaxTiers
    local capLimit = #row.Powers
    if type(maxCaps) == "table" then
        local c = maxCaps[trackKey] or maxCaps["PumpkinTycoon" .. tostring(trackKey)]
        if type(c) == "number" then
            if c <= 0 then return nil end
            capLimit = math.min(capLimit, c)
        end
    end

    local tier = 0
    if Modules.EventUpgradeCmds and type(Modules.EventUpgradeCmds.GetTier) == "function" then
        local ok, t = pcall(Modules.EventUpgradeCmds.GetTier, Modules.UpgradesTypes.Id(trackKey))
        if ok and type(t) == "number" then tier = t end
    end
    if tier >= capLimit then return nil end

    local baseCost = row.Costs[tier + 1]
    if not baseCost then return nil end
    local mult = 1
    if Modules.PumpkinUpgradesUtil and type(Modules.PumpkinUpgradesUtil.CostMult) == "function" then
        local okM, m = pcall(Modules.PumpkinUpgradesUtil.CostMult)
        if okM and type(m) == "number" then mult = m end
    end
    local liveCost = math.max(1, math.ceil(baseCost * mult))
    local w = (weights and weights[trackKey]) or 1.0
    -- Tier 1 <= 50 gets an instant 5x bootstrap boost so base multipliers unlock immediately
    if tier == 0 and baseCost <= 50 then
        w = w * 5.0
    end
    return {
        track = trackKey,
        nextTier = tier + 1,
        cost = liveCost,
        weightedCost = liveCost / w,
    }
end

function DuckkEvent.Tokens.Step(plot, buttons, tycoonComplete)
    if not Config.AutoUpgrades or not plot or not Modules.UpgradesTypes or not Modules.PumpkinButtonsUtil then return end
    local now = os.clock()
    if (now - (Runtime.Cache.LastUpgradesStepAt or 0)) < 1.5 then return end
    Runtime.Cache.LastUpgradesStepAt = now

    local machineBtn = Modules.UpgradesTypes.BUTTON or "UpgradeMachine"
    if not Modules.PumpkinButtonsUtil.Owned(buttons, machineBtn) then return end

    local tokens = GetCurrency((PT and PT.TOKENS) or "PumpkinTokens")
    Runtime.Stats.Tokens = tokens
    if tokens <= 0 then return end
    if Runtime.Cache.AllUpgradesMaxed and (now - (Runtime.Cache.AllUpgradesMaxedAt or 0)) < 15.0 then return end

    local weights = tycoonComplete and ENDGAME_UPGRADE_WEIGHTS or RUSH_UPGRADE_WEIGHTS
    for _ = 1, 15 do
        if not IsRunning() then break end
        tokens = GetCurrency((PT and PT.TOKENS) or "PumpkinTokens")
        Runtime.Stats.Tokens = tokens
        if tokens <= 0 then break end

        local offers = {}
        for _, key in ipairs(ALL_UPGRADE_TRACKS) do
            local off = DuckkEvent.Tokens.NextTrackOffer(key, weights)
            if off then table.insert(offers, off) end
        end
        if #offers == 0 then
            Runtime.Cache.AllUpgradesMaxed = true
            Runtime.Cache.AllUpgradesMaxedAt = os.clock()
            break
        end
        Runtime.Cache.AllUpgradesMaxed = false

        table.sort(offers, function(a, b)
            if a.weightedCost ~= b.weightedCost then return a.weightedCost < b.weightedCost end
            return a.cost < b.cost
        end)

        -- Buy best ROI offer if affordable, or any secondary offer whose raw cost <= 35% of the blocked best ROI offer
        local best = offers[1]
        local pick = nil
        if tokens >= best.cost then
            pick = best
        else
            for i = 2, #offers do
                local alt = offers[i]
                if tokens >= alt.cost and alt.cost <= (best.cost * 0.35) then
                    pick = alt
                    break
                end
            end
        end
        if not pick then break end

        local ok, res = pcall(plot.Invoke, plot, NET.UpgradeBuy, pick.track)
        if not ok or res == false then break end
        Log("INFO", "[DuckkEvent] Token Upgrade [%s -> T%d] (%s Tokens)", pick.track, pick.nextTier, tostring(pick.cost))
        task.wait(0.04)
    end
end

-- ============================================================================
-- 9. DUCKK BOOSTS, 2H BULK HOT COCOA, FLANNEL GIFTS & EVENT PASS
-- ============================================================================
local function GetBoostTimerSeconds(boostId)
    if not Modules.BoostCmds or type(Modules.BoostCmds.GetTimer) ~= "function" then return 0 end
    local ok, sec = pcall(Modules.BoostCmds.GetTimer, boostId)
    return (ok and type(sec) == "number") and sec or 0
end

function DuckkEvent.Boosts.IsBoostAllowed(itemName, tier)
    local cfg = Config.AllowedConsumableBoosts
    if type(cfg) ~= "table" then return true end
    local rule = cfg[itemName]
    if rule == nil then return true end
    if type(rule) == "boolean" then return rule end
    if type(rule) == "table" then
        local t = math.floor(tonumber(tier) or 1)
        if type(rule[t]) == "boolean" then return rule[t] end
        if type(rule["Tier" .. tostring(t)]) == "boolean" then return rule["Tier" .. tostring(t)] end
        return true
    end
    return true
end

function DuckkEvent.Boosts.StepConsumables(plot)
    if not Config.AutoConsumeBoosts or not Modules.PumpkinBoostsUtil or not Modules.Network then return end
    local now = os.clock()
    if (now - (Runtime.Cache.LastBoostsStepAt or 0)) < 2.0 then return end
    Runtime.Cache.LastBoostsStepAt = now

    local maxTier = Runtime.Helpers.IsPlotPart2Active(plot) and 3 or 2
    if Modules.PumpkinBoostsUtil.PlayerMaxTier then
        local okT, t = pcall(Modules.PumpkinBoostsUtil.PlayerMaxTier, LocalPlayer)
        if okT and type(t) == "number" and t >= 1 then maxTier = math.clamp(math.floor(t), 1, 3) end
    end

    local itemsMap = Modules.PumpkinBoostsUtil.ITEMS or {}
    local inv = Runtime.Helpers.GetSaveInventory("Consumable")
    if not inv or next(inv) == nil then return end

    for axis, itemName in pairs(itemsMap) do
        local activeTier = 0
        for t = maxTier, 1, -1 do
            local bId = Modules.PumpkinBoostsUtil.Id(axis, t)
            if bId and GetBoostTimerSeconds(bId) > 15 then
                activeTier = t
                break
            end
        end
        local bestUid, bestTier, bestBoostId = nil, activeTier, nil
        for uid, d in pairs(inv) do
            if type(d) == "table" and tostring(d.id or d._id or "") == itemName then
                local t = math.floor(tonumber(d.tn or d.tier or 1) or 1)
                if t > bestTier and t <= maxTier and DuckkEvent.Boosts.IsBoostAllowed(itemName, t) then
                    bestTier = t
                    bestUid = tostring(uid)
                    bestBoostId = Modules.PumpkinBoostsUtil.Id(axis, t)
                end
            end
        end
        if bestUid and bestBoostId and (now - (Runtime.Cache.BoostConsumeCooldown[bestBoostId] or 0)) >= 3.0 then
            local okC, resC = pcall(Modules.Network.Invoke, "Consumables_Consume", bestUid, 1)
            if okC and resC ~= false then
                Runtime.Cache.BoostConsumeCooldown[bestBoostId] = now
                Log("INFO", "[DuckkEvent] Activated %s Tier %d", itemName, bestTier)
                task.wait(0.05)
            end
        end
    end
end

function DuckkEvent.Boosts.StepCocoa(plot, buttons, tycoonComplete)
    if not Config.AutoCocoaStand or not plot or not Modules.PumpkinCocoaUtil or not Modules.PumpkinBoostsUtil then return end
    if not Modules.PumpkinButtonsUtil or not Modules.PumpkinButtonsUtil.Owned(buttons, Modules.PumpkinCocoaUtil.BUTTON) then return end
    local now = os.clock()
    if (now - (Runtime.Cache.LastCocoaCheckAt or 0)) < 2.0 or (now - (Runtime.Cache.LastCocoaFailAt or 0)) < 15.0 then return end
    Runtime.Cache.LastCocoaCheckAt = now

    if not tycoonComplete then
        local sustainedOk = Runtime.Helpers.IsIncomeSustainedForCocoa(tonumber(Config.CocoaMinIncomePerSec) or 3500000)
        if not sustainedOk then return end
    end

    local coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
    local activateCoins = tonumber(Config.CocoaActivateCoins) or 300000000
    local spareCoins = tonumber(Config.CocoaMinSpareCoins) or 150000000
    if coins < activateCoins then return end

    local tier = Modules.PumpkinCocoaUtil.TIER or 1
    local costPerMin = Modules.PumpkinCocoaUtil.CostPerMinute and Modules.PumpkinCocoaUtil.CostPerMinute(tier)
    if type(costPerMin) ~= "number" or costPerMin <= 0 then return end

    local maintainSec = tycoonComplete and (coins >= 1e12 and 1800 or 600) or 120
    local batchMin = tycoonComplete and (coins >= 1e12 and 120 or 30) or 2
    local tankSec = (Modules.PumpkinCocoaUtil.TankSeconds and Modules.PumpkinCocoaUtil.TankSeconds()) or (720 * 60)
    local axes = tycoonComplete and { "Coins", "Damage", "IslandLuck" } or { "Coins" }

    local orders = {}
    local simCoins = coins
    for _, axis in ipairs(axes) do
        local boostId = Modules.PumpkinBoostsUtil.Id(axis, tier)
        local rem = GetBoostTimerSeconds(boostId)
        local totalAxis = Runtime.Helpers.GetAxisBoostSeconds and Runtime.Helpers.GetAxisBoostSeconds(axis) or rem
        if math.max(rem, totalAxis) < maintainSec then
            local maxRoom = math.floor(math.max(0, tankSec - rem) / 60)
            local canBuy = math.floor(math.max(0, simCoins - spareCoins) / costPerMin)
            local mins = math.min(batchMin, maxRoom, canBuy)
            if mins >= 1 then
                table.insert(orders, { boostId = boostId, mins = mins })
                simCoins = simCoins - (mins * costPerMin)
            end
        end
    end
    if #orders == 0 then return end

    WithMachinePad(plot, Modules.PumpkinCocoaUtil.MACHINE, Modules.PumpkinCocoaUtil.Range, function()
        for _, ord in ipairs(orders) do
            if not IsRunning() then break end
            local ok, res = pcall(plot.Invoke, plot, NET.CocoaBuyTime, ord.boostId, ord.mins)
            if ok and res == true then
                Runtime.Cache.LastCocoaFailAt = 0
                Runtime.Helpers.RecordCoinsSpent(ord.mins * costPerMin)
                Log("INFO", "[DuckkEvent] Refilled Hot Cocoa [%s +%dm]", tostring(ord.boostId), ord.mins)
                task.wait(0.05)
            else
                Runtime.Cache.LastCocoaFailAt = os.clock()
                break
            end
        end
    end)
end

function DuckkEvent.Boosts.StepFlannelGifts()
    if not Config.AutoOpenGifts or not Modules.Network then return end
    if Workspace:GetAttribute("PumpkinTycoonGiftOpener") ~= true then return end
    local now = os.clock()
    if (now - (Runtime.Cache.LastGiftAttemptAt or 0)) < 0.30 then return end

    local boxes = Runtime.Helpers.GetSaveInventory("Lootbox")
    if not boxes or next(boxes) == nil then return end
    local giftName, giftUid, giftAmt = Runtime.Helpers.ScanFlannelGiftBag(boxes)
    if not giftUid or giftAmt < 1 then return end

    local count = math.clamp(math.min(giftAmt, Config.GiftBatchAmount or 8), 1, 8)
    local positions = nil
    if Modules.LootboxLocation and Modules.LootboxLocation.ComputePositions and Modules.LootboxTypes then
        local okP, list = pcall(Modules.LootboxLocation.ComputePositions, Modules.LootboxTypes.PlacementConfig, count, {})
        if okP and type(list) == "table" and #list == count then positions = list end
    end
    if not positions then
        local _, hrp = GetCharacter()
        if not hrp then return end
        positions = {}
        for i = 1, count do
            local ang = (math.pi * 2 * i) / count
            positions[i] = hrp.Position + Vector3.new(math.cos(ang) * 10, -3, math.sin(ang) * 10)
        end
    end

    local netsAttr = (Modules.PumpkinGiftUtil and Modules.PumpkinGiftUtil.NETS_ATTRIBUTE) or "PumpkinTycoonGiftNets"
    local sentNets = (LocalPlayer:GetAttribute(netsAttr) == true)
    if Modules.PumpkinGiftUtil then Modules.PumpkinGiftUtil.cardShown = sentNets end

    Runtime.Cache.LastGiftAttemptAt = now
    local ok, res = pcall(Modules.Network.Invoke, NET.GiftOpen, giftUid, count, positions, sentNets)
    if ok and res == true then
        Runtime.Stats.GiftsOpened = (Runtime.Stats.GiftsOpened or 0) + count
        Log("INFO", "[DuckkEvent] Opened %dx %s", count, giftName)
    else
        Runtime.Cache.LastGiftAttemptAt = now + 2.5
    end
end

function DuckkEvent.Boosts.StepEventPass()
    if not Config.AutoEventPass or not Modules.Network or not Modules.EventPassUtil or not Modules.EventPassTypes then return end
    local now = os.clock()
    if (now - (Runtime.Cache.LastPassCheckAt or 0)) < 15.0 then return end
    Runtime.Cache.LastPassCheckAt = now

    local passId = Modules.EventPassUtil.Current and Modules.EventPassUtil.Current() or ""
    if passId == "" then return end
    local ok, state = pcall(Modules.Network.Invoke, Modules.EventPassTypes.NET.Get, passId)
    if not ok or type(state) ~= "table" or state.Buying == false then return end
    local passCfg = Modules.EventPassUtil.Get and Modules.EventPassUtil.Get(passId)
    local weekSet = passCfg and Modules.EventPassUtil.WeekSet and Modules.EventPassUtil.WeekSet(passCfg, state.Week or 1)
    if not weekSet or type(weekSet.Tiers) ~= "table" then return end

    local stars = tonumber(state.Stars) or 0
    local spent = tonumber(state.Spent) or 0
    local owned = type(state.Owned) == "table" and state.Owned or {}
    local unlocks = type(state.TierUnlock) == "table" and state.TierUnlock or {}

    for tIdx, cards in ipairs(weekSet.Tiers) do
        if unlocks[tIdx] ~= nil and spent >= unlocks[tIdx] then
            for _, card in ipairs(cards) do
                local soon = Modules.EventPassUtil.ComingSoon and Modules.EventPassUtil.ComingSoon(card)
                if not soon and card.Key and not owned[card.Key] and type(card.Cost) == "number" and stars >= card.Cost then
                    local bOk, bRes = pcall(Modules.Network.Invoke, Modules.EventPassTypes.NET.Buy, passId, card.Key)
                    if bOk and bRes == true then
                        stars = stars - card.Cost
                        spent = spent + card.Cost
                        owned[card.Key] = true
                        Log("INFO", "[DuckkEvent] Claimed EventPass [%s]", tostring(card.Key))
                        task.wait(0.08)
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 10. DUCKK TURKEY BOSS INTERCEPTOR & WILD / NET STORE SNIPER
-- ============================================================================
function Runtime.Helpers.GetNetCount(netId)
    if type(netId) ~= "string" or netId == "" then return 0 end
    if Modules.MiscItem then
        local ok, cnt = pcall(function() return Modules.MiscItem(netId):CountExact() end)
        if ok and type(cnt) == "number" then return math.max(0, math.floor(cnt)) end
    end
    local invMisc = Runtime.Helpers.GetSaveInventory("Misc")
    if not invMisc then return 0 end
    local sum = 0
    for _, item in pairs(invMisc) do
        if type(item) == "table" and item.id == netId then
            sum = sum + math.max(1, math.floor(tonumber(item._am) or 1))
        end
    end
    return sum
end

function DuckkEvent.Wild.SelectNet(isHuge, isPostTurkeySighting)
    local order = Modules.WildTypes and Modules.WildTypes.NET_ORDER
    local normalName = (type(order) == "table" and order[1]) or "Pet Net"
    local ultraName = (type(order) == "table" and order[2]) or "Ultra Pet Net"
    local nCnt = Runtime.Helpers.GetNetCount(normalName)
    local uCnt = Runtime.Helpers.GetNetCount(ultraName)

    local preferUltra = (Config.HuntUltraOnHuge ~= false)
    if isPostTurkeySighting and Config.UseUltraForHugeAfterTurkey ~= nil then
        preferUltra = (Config.UseUltraForHugeAfterTurkey == true)
    end

    if isHuge then
        if preferUltra then
            if uCnt > 0 then return ultraName, nCnt, uCnt end
            if nCnt > 0 then return normalName, nCnt, uCnt end
        else
            if nCnt > 0 then return normalName, nCnt, uCnt end
            if uCnt > 0 then return ultraName, nCnt, uCnt end
        end
        return nil, nCnt, uCnt
    end

    if nCnt > 0 then return normalName, nCnt, uCnt end
    return nil, nCnt, uCnt
end

function Runtime.Helpers.EnsureSightingHook()
    if Runtime.Cache.SightingHookBound or not Modules.Network or type(Modules.Network.Fired) ~= "function" then return end
    local remoteName = (Modules.PumpkinSightingUtil and Modules.PumpkinSightingUtil.REMOTE) or "PumpkinTycoon: PV_Seen"
    local ok, sig = pcall(Modules.Network.Fired, remoteName)
    if not ok or not sig then return end
    Runtime.Cache.SightingHookBound = true
    BindConn(sig, function(payload)
        if not IsRunning() or type(payload) ~= "table" or type(payload.id) ~= "string" then return end
        if payload.closed == true then
            if Runtime.Cache.ActiveSighting and Runtime.Cache.ActiveSighting.id == payload.id then
                Runtime.Cache.ActiveSighting = nil
            end
            return
        end
        if payload.thrown ~= true and type(payload.entry) == "table" then
            Runtime.Cache.ActiveSighting = {
                id = payload.id,
                slot = tostring(payload.slot or "HugeTurkey"),
                entry = payload.entry,
                expiresAt = tonumber(payload.expiresAt) or (workspace:GetServerTimeNow() + 180),
                spot = type(payload.spot) == "table" and Vector3.new(payload.spot[1] or 0, payload.spot[2] or 0, payload.spot[3] or 0) or nil,
                thrown = false,
            }
            Log("INFO", "[DuckkEvent] Post-Turkey Sighting Spawned: [%s]!", tostring(payload.entry.P))
        end
    end)
end

function DuckkEvent.Wild.StepSighting(plot)
    if Config.AutoCatchSighting == false or not plot then return false end
    local s = Runtime.Cache.ActiveSighting
    if type(s) ~= "table" or s.thrown == true then return false end
    if not Runtime.Helpers.IsPlotPart2Active(plot) then return false end

    local nowSrv = workspace:GetServerTimeNow()
    if s.expiresAt and nowSrv >= s.expiresAt then
        Runtime.Cache.ActiveSighting = nil
        return false
    end
    if Modules.ChaseTypes and type(Modules.ChaseTypes.SoldOutAttribute) == "function" then
        local attr = Modules.ChaseTypes.SoldOutAttribute(s.slot)
        if attr and Workspace:GetAttribute(attr) == true then
            Runtime.Cache.ActiveSighting = nil
            return false
        end
    end

    local throwCd = (Modules.PumpkinWildUtil and Modules.PumpkinWildUtil.ThrowSeconds and Modules.PumpkinWildUtil.ThrowSeconds()) or 3
    if (nowSrv - (Runtime.Cache.LastWildThrowAt or 0)) < (throwCd + 0.1) then return false end

    local netName = DuckkEvent.Wild.SelectNet(true, true)
    if not netName then return false end

    local ok, res, _, payload = false, false, nil, nil
    local _, hrp = GetCharacter()
    if typeof(s.spot) == "Vector3" and hrp and (hrp.Position - s.spot).Magnitude > 36 then
        WithMachineSession(function()
            MoveNear(s.spot, 8)
            task.wait(0.32)
            ok, res, _, payload = pcall(plot.Invoke, plot, NET.CatchSighting, s.id, netName)
        end)
    else
        ok, res, _, payload = pcall(plot.Invoke, plot, NET.CatchSighting, s.id, netName)
    end

    if ok and res and type(payload) == "table" then
        Runtime.Cache.LastWildThrowAt = workspace:GetServerTimeNow()
        Runtime.Stats.WildThrows = (Runtime.Stats.WildThrows or 0) + 1
        s.thrown = true
        Runtime.Cache.ActiveSighting = nil
        if payload.caught == true then
            if type(payload.uid) == "string" and Modules.Network and Modules.Network.Fire then
                pcall(Modules.Network.Fire, "SM_Unmask", { payload.uid })
            end
            Runtime.Stats.SightingsCaught = (Runtime.Stats.SightingsCaught or 0) + 1
            Runtime.Stats.WildCaught = (Runtime.Stats.WildCaught or 0) + 1
            Runtime.Stats.WildHugesCaught = (Runtime.Stats.WildHugesCaught or 0) + 1
            Log("INFO", "[DuckkEvent] CAUGHT SIGHTING [%s] with %s!", tostring(payload.pet or s.slot), netName)
        end
        return true
    end
    return false
end

function DuckkEvent.Wild.StepNetStore(plot, buttons, tycoonComplete)
    if Config.AutoBuyNetStore == false or not plot or not Runtime.Helpers.IsPlotPart2Active(plot) then return end
    local storeUtil = Modules.PumpkinStoreUtil
    local storeBtn = (storeUtil and storeUtil.BUTTON) or "PetNetStore"
    if not Modules.PumpkinButtonsUtil or not Modules.PumpkinButtonsUtil.Owned(buttons, storeBtn) then return end

    local now = os.clock()
    if (now - (Runtime.Cache.LastNetStoreStepAt or 0)) < 3.5 or (now - (Runtime.Cache.LastNetStoreFailAt or 0)) < 6.0 then return end
    Runtime.Cache.LastNetStoreStepAt = now

    -- Disable server AutoBuyNets so Rush budget is never drained
    if Config.KeepServerAutoNetsOff ~= false and (now - (Runtime.Cache.LastNetStoreAutoSyncAt or 0)) >= 15.0 then
        if storeUtil and type(storeUtil.AutoOn) == "function" then
            local aVar = storeUtil.AUTO_VAR or "NetStoreAuto"
            local pVar = storeUtil.PUMPKIN_AUTO_VAR or "MerchantAuto"
            local okA, onA = pcall(storeUtil.AutoOn, Runtime.Helpers.GetPlotSave(plot, aVar), Runtime.Helpers.GetPlotSave(plot, pVar))
            if okA and onA == true then
                Runtime.Cache.LastNetStoreAutoSyncAt = now
                if pcall(plot.Invoke, plot, NET.SetAutoNets, false) then
                    Runtime.Helpers.InvalidatePlotSave(plot, aVar)
                end
            end
        end
    end

    local shelf = Runtime.Cache.NetStoreShelfCache
    local storeFeat = PT_Cmds and type(PT_Cmds.Feature) == "function" and select(2, pcall(PT_Cmds.Feature, "Store")) or nil
    if storeFeat and type(storeFeat.Shelf) == "function" then
        local okS, fShelf = pcall(storeFeat.Shelf)
        if okS and type(fShelf) == "table" and fShelf.seed ~= nil and type(fShelf.offers) == "table" and #fShelf.offers > 0 then
            if not shelf or shelf.seed ~= fShelf.seed then
                shelf = fShelf
                Runtime.Cache.NetStoreShelfCache = shelf
            end
        end
    end

    if (not shelf or Runtime.Cache.ForceNetStoreShelfFetch) and (now - (Runtime.Cache.LastNetStoreShelfFetchAt or 0)) >= 2.5 then
        Runtime.Cache.LastNetStoreShelfFetchAt = now
        local okCall, okRes, _, data = pcall(plot.Invoke, plot, NET.NetShelf)
        if okCall and okRes and type(data) == "table" and type(data.Offers) == "table" then
            local parsed = {}
            for slotKey, off in pairs(data.Offers) do
                local itemD = type(off) == "table" and off.ItemData and off.ItemData.data
                local priceD = type(off) == "table" and off.PriceData and off.PriceData.data
                table.insert(parsed, {
                    slot = tonumber(slotKey) or 0,
                    item = itemD and tostring(itemD.id or "") or "",
                    price = priceD and tonumber(priceD._am) or 0,
                    left = tonumber(off.Stock) or 0,
                })
            end
            table.sort(parsed, function(a, b) return a.slot < b.slot end)
            shelf = { seed = data.Seed, offers = parsed }
            Runtime.Cache.NetStoreShelfCache = shelf
            Runtime.Cache.ForceNetStoreShelfFetch = false
        end
    end
    if type(shelf) ~= "table" or shelf.seed == nil or type(shelf.offers) ~= "table" then return end

    local ultraId = (storeUtil and storeUtil.ULTRA_NET) or "Ultra Pet Net"
    local merchantId = (storeUtil and storeUtil.MERCHANT) or "PetNetStore"
    local discount = 1
    if Modules.MasteryCmds and type(Modules.MasteryCmds.GetPerkPower) == "function" then
        local okP, perk = pcall(Modules.MasteryCmds.GetPerkPower, "Economy", "CheaperMerchants")
        if okP and type(perk) == "number" and perk > 0 and perk < 100 then discount = 1 - (perk / 100) end
    end

    local sorted = {}
    for _, o in ipairs(shelf.offers) do
        if type(o) == "table" and (tonumber(o.left) or 0) > 0 and (tonumber(o.price) or 0) > 0 then
            table.insert(sorted, o)
        end
    end
    if #sorted == 0 then return end
    table.sort(sorted, function(a, b)
        if (a.item == ultraId) ~= (b.item == ultraId) then return a.item == ultraId end
        return a.price < b.price
    end)

    local coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
    local rushMode = (Config.RushButtonsFirst == true and not tycoonComplete)
    local rushShare = math.clamp(tonumber(Config.NetStoreMaxRushCoinShare) or 0.05, 0, 1)
    local plan, simCoins, countPlanned = {}, coins, 0

    for _, o in ipairs(sorted) do
        local isUltra = (o.item == ultraId)
        local cost = math.max(1, math.ceil(o.price * discount))
        local left = math.floor(tonumber(o.left) or 0)
        local qty = 0
        while left > 0 and countPlanned < 12 do
            local okBuy = isUltra and (simCoins >= cost)
                or ((not rushMode) and (simCoins >= cost))
                or (rushMode and simCoins >= cost and cost <= (simCoins * rushShare))
            if not okBuy then break end
            simCoins = simCoins - cost
            left = left - 1
            qty = qty + 1
            countPlanned = countPlanned + 1
        end
        if qty > 0 then table.insert(plan, { offer = o, cost = cost, qty = qty }) end
    end
    if #plan == 0 then return end

    local function runBuy()
        for _, req in ipairs(plan) do
            for _ = 1, req.qty do
                if not IsRunning() then return end
                local okB, resB = pcall(Modules.Network.Invoke, "Merchant_RequestPurchase", merchantId, req.offer.slot, false, shelf.seed)
                if okB and resB == true then
                    req.offer.left = math.max(0, (tonumber(req.offer.left) or 1) - 1)
                    Runtime.Helpers.RecordCoinsSpent(req.cost)
                    Runtime.Stats.NetsBought = (Runtime.Stats.NetsBought or 0) + 1
                    Log("INFO", "[DuckkEvent] Bought %s (slot %d)", tostring(req.offer.item), req.offer.slot)
                    task.wait(0.08)
                else
                    Runtime.Cache.LastNetStoreFailAt = os.clock()
                    Runtime.Cache.ForceNetStoreShelfFetch = true
                    return
                end
            end
        end
    end

    local merEntry = SafeDirLookup(Modules.Directory and Modules.Directory.Merchants, merchantId)
    if type(merEntry) == "table" and merEntry.IgnoreMachineDistance == true and os.clock() >= (Runtime.Cache.NetStoreForcePadUntil or 0) then
        runBuy()
    else
        WithMachinePad(plot, merchantId, 20, runBuy, { closeModal = true })
    end
end

function DuckkEvent.Wild.GetSpeciesMeta(zone, petId)
    if type(petId) ~= "string" then return false, 0 end
    local map = Runtime.Cache.WildSpeciesMap
    if not map then
        map = {}
        local wt = Modules.WildTypes
        if wt and type(wt.Species) == "function" then
            for z = 1, 8 do
                local ok, list = pcall(wt.Species, z)
                if ok and type(list) == "table" then
                    map[z] = {}
                    for _, sp in ipairs(list) do
                        if type(sp) == "table" and type(sp.PetId) == "string" then
                            map[z][sp.PetId] = { huge = (sp.Huge == true), tier = sp.Huge and 4 or (tonumber(sp.Tier) or 0) }
                        end
                    end
                end
            end
        end
        Runtime.Cache.WildSpeciesMap = map
    end
    local rec = (map[zone] and map[zone][petId])
    if rec then return rec.huge, rec.tier end
    local pd = SafeDirLookup(Modules.Directory and Modules.Directory.Pets, petId)
    local isHuge = Runtime.Helpers.GetChaseCategory(petId, pd) ~= nil
    return isHuge, isHuge and 4 or 0
end

function DuckkEvent.Wild.StepHunt(plot, buttons, tycoonComplete)
    if Config.AutoHuntWild == false or not plot or not Runtime.Helpers.IsPlotPart2Active(plot) then
        Runtime.Cache.WildRerollActive = false
        return
    end
    local wildUtil = Modules.PumpkinWildUtil
    if not wildUtil then return end

    local now = os.clock()
    if (now - (Runtime.Cache.LastWildStepAt or 0)) < 0.30 or (now - (Runtime.Cache.LastWildFailAt or 0)) < 3.0 then return end
    Runtime.Cache.LastWildStepAt = now

    -- Keep built-in 80-stud server AutoHunt OFF so it never wastes nets or triggers cooldown
    if (now - (Runtime.Cache.LastHuntAutoSyncAt or 0)) >= 15.0 then
        local huntSave = Runtime.Helpers.GetPlotSave(plot, VAR.Hunt)
        if type(huntSave) == "table" and huntSave.On == true then
            Runtime.Cache.LastHuntAutoSyncAt = now
            if pcall(plot.Invoke, plot, NET.SetHunt, { On = false, Min = 4, Variant = false, UltraOnHuge = true }) then
                Runtime.Helpers.InvalidatePlotSave(plot, VAR.Hunt)
            end
        end
    end

    local nowSrv = workspace:GetServerTimeNow()
    local throwCd = (type(wildUtil.ThrowSeconds) == "function" and wildUtil.ThrowSeconds()) or 3
    if (nowSrv - (Runtime.Cache.LastWildThrowAt or 0)) < (throwCd + 0.1) then return end

    local entries = type(wildUtil.Entries) == "function" and wildUtil.Entries(Runtime.Helpers.GetPlotSave(plot, VAR.Wild)) or nil
    if type(entries) ~= "table" or next(entries) == nil then
        Runtime.Cache.WildRerollActive = false
        return
    end

    local minTier = math.clamp(math.floor(tonumber(Config.HuntMinTier) or 4), 0, 4)
    local varOnly = (Config.HuntVariantsOnly == true)
    local rerollZone = math.clamp(math.floor(tonumber(Config.HuntRerollZone) or 1), 1, 8)
    local keepNets = math.max(0, math.floor(tonumber(Config.HuntRerollKeepNets) or 15))
    local normalNetName = "Pet Net"
    local normalCnt = Runtime.Helpers.GetNetCount(normalNetName)
    local canReroll = (Config.HuntRerollWild == true) and tycoonComplete and (normalCnt > keepNets)
    Runtime.Cache.WildRerollActive = canReroll

    local perZone = type(wildUtil.PerZone) == "function" and wildUtil.PerZone() or nil
    local wildFeat = PT_Cmds and type(PT_Cmds.Feature) == "function" and select(2, pcall(PT_Cmds.Feature, "Wild")) or nil
    Runtime.Cache.WildSlotCooldown = Runtime.Cache.WildSlotCooldown or {}
    local slotCds = Runtime.Cache.WildSlotCooldown

    local bestTarget, bestReroll = nil, nil
    for slotKey, entry in pairs(entries) do
        local slotNum = tonumber(slotKey)
        if slotNum and type(entry) == "table" and type(entry.P) == "string" then
            local z, idx = wildUtil.Split(slotNum)
            local zMeta = z and PT and PT.ZONES and PT.ZONES[z]
            local zOwned = zMeta and Modules.PumpkinButtonsUtil and Modules.PumpkinButtonsUtil.Owned(buttons, zMeta.Section .. "_Zone")
            if zOwned and entry.Z == z and (entry.I == nil or entry.I == idx) and wildUtil.Served(slotNum, perZone) then
                local eKey = tostring(slotNum) .. "|" .. entry.P .. "|" .. tostring(entry.C or 0)
                if not slotCds[eKey] or now >= slotCds[eKey] then
                    local isHuge, tier = DuckkEvent.Wild.GetSpeciesMeta(z, entry.P)
                    local isVar = (entry.G == true or entry.R == true or entry.S == true)
                    local want = isHuge or (minTier < 4 and tier >= minTier and (not varOnly or isVar))
                    if want then
                        local netName = DuckkEvent.Wild.SelectNet(isHuge, false)
                        if netName then
                            local chance = (type(wildUtil.PlayerChance) == "function" and wildUtil.PlayerChance(entry, netName, LocalPlayer)) or (tonumber(entry.C) or 0)
                            if not bestTarget
                                or (isHuge ~= bestTarget.isHuge and isHuge)
                                or (isHuge == bestTarget.isHuge and tier > bestTarget.tier)
                                or (isHuge == bestTarget.isHuge and tier == bestTarget.tier and chance > bestTarget.chance)
                            then
                                bestTarget = { slot = slotNum, zone = z, entry = entry, key = eKey, isHuge = isHuge, tier = tier, net = netName, chance = chance, reroll = false }
                            end
                        end
                    elseif canReroll and z == rerollZone and not isHuge then
                        local chance = tonumber(entry.C) or 0
                        if not bestReroll or chance < bestReroll.chance then
                            bestReroll = { slot = slotNum, zone = z, entry = entry, key = eKey, isHuge = false, tier = tier, net = normalNetName, chance = chance, reroll = true }
                        end
                    end
                end
            end
        end
    end

    local chosen = bestTarget or bestReroll
    if not chosen then return end

    local catchPos = nil
    if wildFeat then
        if type(wildFeat.Physical) == "function" and not chosen.reroll then
            local okP, phys = pcall(wildFeat.Physical, chosen.slot)
            if okP and type(phys) == "table" then
                catchPos = (phys.SpawnArea and phys.SpawnArea:IsA("BasePart") and (phys.SpawnArea.Position + Vector3.new(0, 3, 0)))
                    or (typeof(phys.At) == "Vector3" and (phys.At + Vector3.new(0, 3, 0))) or nil
            end
        end
        if not catchPos and type(wildFeat.Areas) == "function" then
            local okA, areas = pcall(wildFeat.Areas, chosen.zone)
            if okA and type(areas) == "table" and areas[1] and areas[1]:IsA("BasePart") then
                catchPos = areas[1].Position + Vector3.new(0, 3, 0)
            end
        end
    end

    local ok, res, _, payload = false, false, nil, nil
    local _, hrp = GetCharacter()
    if typeof(catchPos) == "Vector3" and hrp and HorizontalDist(hrp.Position, catchPos) > 35 then
        WithMachineSession(function()
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            hrp.CFrame = CFrame.new(catchPos)
            Runtime.Cache.LastTeleportAt = os.clock()
            task.wait(0.32)
            ok, res, _, payload = pcall(plot.Invoke, plot, NET.CatchWild, chosen.slot, chosen.net)
        end)
    else
        ok, res, _, payload = pcall(plot.Invoke, plot, NET.CatchWild, chosen.slot, chosen.net)
    end

    if ok and res and type(payload) == "table" then
        Runtime.Cache.LastWildThrowAt = workspace:GetServerTimeNow()
        Runtime.Stats.WildThrows = (Runtime.Stats.WildThrows or 0) + 1
        Runtime.Helpers.InvalidatePlotSave(plot, VAR.Wild)
        slotCds[chosen.key] = now + (payload.outcome == "soldout" and 30.0 or 4.0)
        if payload.caught == true then
            if type(payload.uid) == "string" and Modules.Network and Modules.Network.Fire then
                pcall(Modules.Network.Fire, "SM_Unmask", { payload.uid })
            end
            if not chosen.reroll then
                Runtime.Stats.WildCaught = (Runtime.Stats.WildCaught or 0) + 1
                if chosen.isHuge then Runtime.Stats.WildHugesCaught = (Runtime.Stats.WildHugesCaught or 0) + 1 end
                Log("INFO", "[DuckkEvent] Caught Wild [%s] (Z%d, %s)", tostring(chosen.entry.P), chosen.zone, chosen.net)
            end
        end
        if wildFeat and type(wildFeat.Respawn) == "function" then
            pcall(wildFeat.Respawn, chosen.slot)
        end
    else
        Runtime.Cache.LastWildFailAt = os.clock()
    end
end

-- Turkey Boss Arena Interceptor
function Runtime.Helpers.GetTurkeyReach()
    local util = Modules.PumpkinTurkeyUtil
    if util and type(util.Dial) == "function" then
        local ok, r = pcall(util.Dial, "PumpkinTycoon_TurkeyReach")
        if ok and type(r) == "number" and r >= 20 then return r end
    end
    return 150
end

function DuckkEvent.Turkey.GetSharedModel()
    local things = Workspace:FindFirstChild("__THINGS")
    local instFolder = things and things:FindFirstChild("Instances") and things.Instances:FindFirstChild(INSTANCE_ID)
    local sharedName = (Modules.PumpkinIslandCmds and Modules.PumpkinIslandCmds.SHARED_NAME) or "PumpkinTycoonShared"
    return instFolder and instFolder:FindFirstChild(sharedName) or nil
end

function DuckkEvent.Turkey.FindBreakable()
    if not Modules.BreakableFrontend or not Modules.BreakableFrontend.AllByInstanceAndClass then return nil, nil, nil end
    local ok, chests = pcall(Modules.BreakableFrontend.AllByInstanceAndClass, "Chest")
    if not ok or type(chests) ~= "table" then return nil, nil, nil end
    for uid, data in pairs(chests) do
        local attrs = data and data.clientAttributes
        if type(attrs) == "table" and attrs.PumpkinTurkey == true and data.model and data.model.Parent then
            return tostring(uid), data, data.model
        end
    end
    return nil, nil, nil
end

function DuckkEvent.Turkey.LeaveArena(plot, reason)
    if (tonumber(Runtime.Stats.TurkeyBossShare) or 0) >= 0.01 and reason == nil then
        Runtime.Stats.TurkeyBossKills = (Runtime.Stats.TurkeyBossKills or 0) + 1
    end
    Runtime.Stats.FightingTurkeyBoss = false
    Runtime.Stats.TurkeyBossShare = 0
    Runtime.Stats.TurkeyBossHealth = 0
    Runtime.Stats.TurkeyBossMaxHealth = 0
    Runtime.Cache.TurkeyBossEngagedAt = 0
    activeFarmTarget = nil
    Runtime.Cache.ActiveTargetCopy.model = nil
    Runtime.Cache.TapTargets = nil

    local retPos = Runtime.Cache.TurkeyBossReturnPos
    Runtime.Cache.TurkeyBossReturnPos = nil
    if not IsMoveLocked() then
        local _, hrp = GetCharacter()
        if hrp and typeof(retPos) == "Vector3" then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            hrp.CFrame = CFrame.new(retPos + Vector3.new(0, 2.5, 0))
        elseif plot and type(plot.LocalTeleport) == "function" then
            pcall(plot.LocalTeleport, plot)
        end
    end
end

function Runtime.Helpers.StepTurkeyBossTarget(plot)
    if Config.AutoTurkeyBoss == false or not plot or not IsInEventInstance() or not Runtime.Helpers.IsPlotPart2Active(plot) then
        if Runtime.Stats.FightingTurkeyBoss then DuckkEvent.Turkey.LeaveArena(plot, "disabled") end
        return false
    end

    local shared = DuckkEvent.Turkey.GetSharedModel()
    local alive = shared ~= nil and shared:GetAttribute("TurkeyAlive") == true
    local endsAt = shared and tonumber(shared:GetAttribute("TurkeyEndsAt")) or 0
    local hp = shared and tonumber(shared:GetAttribute("TurkeyHealth")) or 0
    local maxHp = shared and tonumber(shared:GetAttribute("TurkeyMaxHealth")) or 0
    local uid, data, model = DuckkEvent.Turkey.FindBreakable()
    local nowSrv = workspace:GetServerTimeNow()

    if not model and not (alive and (endsAt <= 0 or nowSrv < endsAt + 2)) then
        if Runtime.Stats.FightingTurkeyBoss then DuckkEvent.Turkey.LeaveArena(plot, nil) end
        return false
    end

    if hp <= 0 and type(data) == "table" then hp = tonumber(data.health) or 0 end
    if maxHp <= 0 and type(data) == "table" then maxHp = tonumber(data.maxHealth) or 0 end
    local myShare = tonumber(LocalPlayer:GetAttribute("PumpkinTurkeyShare")) or 0

    -- Viability check: probe solo for 22s; if solo DPS cannot finish before timer, wait on home island until server joins
    if Config.TurkeyBossSmartKillCheck ~= false and hp > 0 and maxHp > 0 and endsAt > 0 then
        local secLeft = math.max(1, endsAt - nowSrv)
        local rawTop = shared and shared:GetAttribute("TurkeyTop") or ""
        local otherDps, otherCount, myDps = 0, 0, 0
        if type(rawTop) == "string" and rawTop ~= "" and hp < (maxHp * 0.999) then
            local okJ, rows = pcall(HttpService.JSONDecode, HttpService, rawTop)
            if okJ and type(rows) == "table" then
                for _, r in ipairs(rows) do
                    if type(r) == "table" and type(r[1]) == "string" then
                        if r[1] == LocalPlayer.Name then
                            myDps = tonumber(r[3]) or 0
                        else
                            local d = tonumber(r[3]) or 0
                            if d > 0 or (tonumber(r[2]) or 0) > 0 then
                                otherCount = otherCount + 1
                                otherDps = otherDps + d
                            end
                        end
                    end
                end
            end
        end
        local teamDps = otherDps + math.max(myDps, (maxHp * 0.65) / 900)
        local engagedAt = tonumber(Runtime.Cache.TurkeyBossEngagedAt) or 0
        if otherCount == 0 and (teamDps * secLeft) < (hp * 0.90) then
            if Runtime.Stats.FightingTurkeyBoss and engagedAt > 0 and (os.clock() - engagedAt) >= 22.0 then
                Runtime.Cache.TurkeyBossProbedWindow = endsAt
                DuckkEvent.Turkey.LeaveArena(plot, "solo_unkillable")
                return false
            elseif not Runtime.Stats.FightingTurkeyBoss and Runtime.Cache.TurkeyBossProbedWindow == endsAt then
                return false
            end
        end
    end

    local center = (model and model:GetPivot().Position) or Vector3.new(7930, 1998.3, 8000)
    local standPos = Vector3.new(center.X + 18, center.Y + 3.2, center.Z)

    if not Runtime.Stats.FightingTurkeyBoss then
        local _, hrpPrev = GetCharacter()
        if hrpPrev and HorizontalDist(hrpPrev.Position, standPos) > 400 then
            Runtime.Cache.TurkeyBossReturnPos = hrpPrev.Position
        end
        Runtime.Stats.FightingTurkeyBoss = true
        Runtime.Stats.TurkeyBossFights = (Runtime.Stats.TurkeyBossFights or 0) + 1
        Runtime.Cache.TurkeyBossEngagedAt = os.clock()
        Log("INFO", "[DuckkEvent] Intercepting Maple Turkey Boss (HP=%s)!", tostring(math.floor(hp)))
    end

    Runtime.Stats.TurkeyBossShare = myShare
    Runtime.Stats.TurkeyBossHealth = hp
    Runtime.Stats.TurkeyBossMaxHealth = maxHp

    local _, hrp = GetCharacter()
    if Config.AutoTeleportToTarget and not IsMoveLocked() and hrp then
        if HorizontalDist(hrp.Position, center) > 35 or math.abs(hrp.Position.Y - standPos.Y) > 15 then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            hrp.CFrame = CFrame.new(standPos)
        end
    end

    if model and uid then
        local tCopy = Runtime.Cache.ActiveTargetCopy
        tCopy.uid = uid
        tCopy.model = model
        tCopy.pos = center
        tCopy.isBonus = true
        tCopy.isPedestal = false
        tCopy.isTurkeyBoss = true
        tCopy.zone = 0
        tCopy.rung = 8
        tCopy.dist = hrp and HorizontalDist(hrp.Position, center) or 18
        tCopy.score = 10000000
        activeFarmTarget = tCopy
        local tapPool = Runtime.Cache.TargetsBufA
        table.clear(tapPool)
        tapPool[1] = tCopy
        Runtime.Cache.TapTargets = tapPool
        Runtime.Stats.ActiveTargetUid = uid
        Runtime.Stats.ActiveTargetDesc = string.format("TurkeyBoss (%.1f%%)", myShare * 100)
        DuckkEvent.Combat.FocusAllPets(model)
    end
    return true
end

-- ============================================================================
-- 11. DUCKK SPREAD BREAKABLE FARMER, OVERLAP ZONE 8 HATCHER & PET FUSION
-- ============================================================================
function DuckkEvent.Combat.GetPets()
    if not Config.AutoPetFocus or not Modules.PlayerPet or not Modules.PlayerPet.GetByPlayer then return nil end
    local ok, pets = pcall(Modules.PlayerPet.GetByPlayer, LocalPlayer)
    if not ok or type(pets) ~= "table" then return nil end
    local list = {}
    for _, pet in pairs(pets) do
        if pet and (pet.AIHold == nil or pet.AIHold == "PumpkinAutoBreak" or pet.AIHold == "PumpkinKaitun") then
            table.insert(list, pet)
        end
    end
    return list
end

function DuckkEvent.Combat.DirectPet(pet, model)
    if not pet or not model or not model.Parent then return end
    local okT, tType = pcall(pet.GetTargetType, pet)
    local okG, cur = pcall(pet.GetTarget, pet)
    if not okT or not okG or tType ~= "Breakable" or cur ~= model then
        pcall(pet.SetAnchored, pet, false)
        pcall(pet.SetTarget, pet, model)
    end
    pet.AIHold = "PumpkinKaitun"
end

function DuckkEvent.Combat.FocusAllPets(model)
    local pets = DuckkEvent.Combat.GetPets()
    if not pets then return end
    for _, p in ipairs(pets) do DuckkEvent.Combat.DirectPet(p, model) end
end

function DuckkEvent.Combat.SpreadPetsAcrossZone(zoneTargets)
    local pets = DuckkEvent.Combat.GetPets()
    if not pets or #pets == 0 or #zoneTargets == 0 then return end
    for idx, pet in ipairs(pets) do
        local entry = zoneTargets[((idx - 1) % #zoneTargets) + 1]
        if entry and entry.model and entry.model.Parent then
            DuckkEvent.Combat.DirectPet(pet, entry.model)
        end
    end
end

function DuckkEvent.Combat.BelongsToMyPlot(model, attrs, islandBox, plotId, plotSuffix)
    if type(attrs) == "table" and attrs.Plot ~= nil then return attrs.Plot == plotId end
    local owner = model:GetAttribute("OwnerUsername")
    if owner ~= nil then return owner == LocalPlayer.Name end
    local areaId = model:GetAttribute("AreaID")
    if type(areaId) == "string" and plotSuffix then
        if string.sub(areaId, -#plotSuffix) == plotSuffix then return true end
        if string.find(areaId, "_Zone_", 1, true) then return false end
    end
    return IsOnMyIsland(model, islandBox)
end

function DuckkEvent.Combat.StepFarmTargeter(plot)
    if plot and Runtime.Helpers.StepTurkeyBossTarget(plot) then return end
    if not Config.AutoFarm or not plot or not Modules.BreakableFrontend then
        activeFarmTarget = nil
        Runtime.Stats.ActiveTargetDesc = "Idle"
        ReleaseHeldPets()
        return
    end

    local pedInfo = AnalyzePedestals(plot)
    local islandBox = GetIslandBox(plot)
    local plotId = plot:GetId()
    local suffix = plotId and ("_" .. tostring(plotId)) or nil
    local buttons = Runtime.Cache.Buttons
    local _, lockMin, maxKeepSlots, _, smartLuckMode =
        GetKeepLockSettings(nil, pedInfo.unlockedCount, plot, buttons, Runtime.Stats.TycoonComplete)
    local lockedSet = {}
    for _, l in ipairs(pedInfo.lockedList) do lockedSet[l.index] = true end

    local _, hrp = GetCharacter()
    local myPos = hrp and hrp.Position
    local targets = Runtime.Cache.TargetsBufA
    table.clear(targets)

    for _, cls in ipairs({ "Chest", "Normal" }) do
        local ok, map = pcall(Modules.BreakableFrontend.AllByInstanceAndClass, cls)
        if ok and type(map) == "table" then
            for uid, data in pairs(map) do
                local m = data and data.model
                local attrs = data and data.clientAttributes
                if m and m.Parent and DuckkEvent.Combat.BelongsToMyPlot(m, attrs, islandBox, plotId, suffix) then
                    local isBonus = type(attrs) == "table" and ((attrs.OrchardChest ~= nil) or (attrs.HayPile == true)) or false
                    local pedIdx = type(attrs) == "table" and attrs.PumpkinPedestal or nil
                    local rung = type(attrs) == "table" and (tonumber(attrs.PumpkinRung) or 1) or 1

                    local allow = false
                    if isBonus and Config.FarmOrchardAndHay then
                        allow = true
                    elseif type(pedIdx) == "number" then
                        if not lockedSet[pedIdx] and not DuckkEvent.Pedestals.IsProtectedFromFarm(pedInfo, maxKeepSlots, pedIdx, rung, lockMin, smartLuckMode) then
                            allow = true
                        end
                    else
                        allow = true
                    end

                    if allow then
                        local pos = m:GetPivot().Position
                        local dist = myPos and HorizontalDist(myPos, pos) or 0
                        local zn = tonumber(data.zoneNumber) or tonumber(attrs and attrs.ZoneNumber) or tonumber(m:GetAttribute("ZoneNumber")) or 1
                        local score = isBonus and (1e6 - dist * 0.25)
                            or ((type(pedIdx) == "number") and (50000 + rung * 500 - dist * 0.25) or (5000 + zn * 2000 - dist * 0.25))
                        table.insert(targets, {
                            uid = tostring(uid),
                            model = m,
                            pos = pos,
                            isBonus = isBonus,
                            isPedestal = (type(pedIdx) == "number"),
                            isTurkeyBoss = false,
                            zone = zn,
                            rung = rung,
                            dist = dist,
                            score = score,
                        })
                    end
                end
            end
        end
    end

    Runtime.Cache.TapTargets = targets
    if #targets == 0 then
        activeFarmTarget = nil
        Runtime.Stats.ActiveTargetDesc = "Waiting spawn"
        return
    end
    table.sort(targets, function(a, b) return a.score > b.score end)

    local chosen = targets[1]
    activeFarmTarget = chosen
    Runtime.Stats.ActiveTargetUid = chosen.uid
    Runtime.Stats.ActiveTargetDesc = chosen.isBonus and "BonusChest"
        or (chosen.isPedestal and ("Pedestal-R" .. tostring(chosen.rung)) or ("Zone-" .. tostring(chosen.zone)))

    if Config.AutoTeleportToTarget and not IsMoveLocked() and not Runtime.Cache.WildRerollActive then
        local standPos = Runtime.Stats.IsHatching and Runtime.Cache.ActiveHatchStandPos or nil
        if standPos and hrp then
            if HorizontalDist(hrp.Position, standPos) > 5 or math.abs(hrp.Position.Y - standPos.Y) > 8 then
                pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
                hrp.CFrame = CFrame.new(standPos)
            end
        elseif not Runtime.Stats.IsHatching and chosen.dist > 14 then
            MoveNear(chosen.pos, 13)
        end
    end

    if not chosen.isBonus and not chosen.isPedestal and Config.AutoSpreadZoneBreakables ~= false then
        local zPool = {}
        for _, t in ipairs(targets) do
            if not t.isBonus and not t.isPedestal and t.zone == chosen.zone then
                table.insert(zPool, t)
            end
        end
        if #zPool > 0 then
            DuckkEvent.Combat.SpreadPetsAcrossZone(zPool)
            return
        end
    end
    DuckkEvent.Combat.FocusAllPets(chosen.model)
end

local function StepRapidTap()
    if not Config.AutoTap or not Modules.Network or not Modules.Network.UnreliableFire then return end
    local _, hrp = GetCharacter()
    if not hrp then return end
    local reach = (activeFarmTarget and activeFarmTarget.isTurkeyBoss) and Runtime.Helpers.GetTurkeyReach() or 18
    if activeFarmTarget and activeFarmTarget.model and activeFarmTarget.model.Parent then
        if HorizontalDist(hrp.Position, activeFarmTarget.model:GetPivot().Position) <= reach then
            pcall(Modules.Network.UnreliableFire, "Breakables_PlayerDealDamage", activeFarmTarget.uid)
            return
        end
    end
    local pool = Runtime.Cache.TapTargets
    if type(pool) == "table" then
        for _, e in ipairs(pool) do
            if e.model and e.model.Parent and HorizontalDist(hrp.Position, e.model:GetPivot().Position) <= 18 then
                pcall(Modules.Network.UnreliableFire, "Breakables_PlayerDealDamage", e.uid)
                return
            end
        end
    end
end

local function FireOrbsCollect(batch)
    local orbRemote = Runtime.Cache.CachedOrbRemote
    if not orbRemote or not orbRemote.Parent then
        local netFolder = ReplicatedStorage:FindFirstChild("Network")
        orbRemote = netFolder and netFolder:FindFirstChild("Orbs: Collect")
        Runtime.Cache.CachedOrbRemote = orbRemote
    end
    if orbRemote and orbRemote:IsA("RemoteEvent") then
        pcall(orbRemote.FireServer, orbRemote, batch)
    elseif Modules.Network and Modules.Network.Fire then
        pcall(Modules.Network.Fire, "Orbs: Collect", table.clone(batch))
    end
end

function Runtime.Helpers.EnsureOrbsCreateHook()
    if Runtime.Cache.OrbsCreateConnBound or not Modules.Network or type(Modules.Network.Fired) ~= "function" then return end
    local okSig, sig = pcall(Modules.Network.Fired, "Orbs: Create")
    if okSig and sig and type(sig.Connect) == "function" then
        Runtime.Cache.OrbsCreateConnBound = true
        BindConn(sig, function(data)
            if not IsRunning() or not Config.AutoCollectOrbs or type(data) ~= "table" then return end
            local batch = {}
            for _, orb in ipairs(data) do
                local id = type(orb) == "table" and tonumber(orb.id) or nil
                if id then
                    table.insert(batch, id)
                    if #batch >= 50 then
                        FireOrbsCollect(batch)
                        table.clear(batch)
                    end
                end
            end
            if #batch > 0 then FireOrbsCollect(batch) end
        end)
    end
end

local function SweepDrops()
    if not Config.AutoCollectOrbs then return end
    local things = Workspace:FindFirstChild("__THINGS")
    local orbs = things and things:FindFirstChild("Orbs")
    if not orbs then return end
    local batch = {}
    for _, ch in ipairs(orbs:GetChildren()) do
        local id = tonumber(ch.Name) or tonumber(ch:GetAttribute("OrbID") or ch:GetAttribute("id"))
        if id then
            table.insert(batch, id)
            if #batch >= 50 then
                FireOrbsCollect(batch)
                table.clear(batch)
            end
        end
    end
    if #batch > 0 then FireOrbsCollect(batch) end
end

-- Pet Power, Egg Hatcher & Gold/Rainbow Fusion
function DuckkEvent.Hatch.GetPetDamage(data, pd)
    if type(data) ~= "table" or type(data.id) ~= "string" then return 0, false end
    local cat = Runtime.Helpers.GetChaseCategory(data.id, pd)
    if cat then return (cat == "Gargantuan" and 4.0 or (cat == "Titanic" and 2.0 or 1.1)), true end
    local inst = Modules.PetItem and type(Modules.PetItem.From) == "function" and select(2, pcall(Modules.PetItem.From, Modules.PetItem, data)) or nil
    if inst and Modules.PumpkinDamageUtil and type(Modules.PumpkinDamageUtil.PetHit) == "function" then
        local okH, dmg = pcall(Modules.PumpkinDamageUtil.PetHit, inst, 0, nil, true)
        if okH and type(dmg) == "number" and dmg > 0 then return dmg, false end
    end
    return (pd and tonumber(pd.power)) or 1, false
end

function DuckkEvent.Hatch.GetTeamSnapshot()
    local maxEquip = Runtime.Helpers.GetMaxEquippedPets()
    local invPets = Runtime.Helpers.GetSaveInventory("Pet")
    local petsDir = Modules.Directory and Modules.Directory.Pets
    local powers = {}
    if type(invPets) == "table" then
        for _, d in pairs(invPets) do
            if type(d) == "table" and type(d.id) == "string" then
                local pd = SafeDirLookup(petsDir, d.id)
                local pw, isEx = DuckkEvent.Hatch.GetPetDamage(d, pd)
                local amt = math.min(maxEquip, math.max(1, math.floor(tonumber(d._am) or 1)))
                for _ = 1, amt do
                    table.insert(powers, isEx and 1e18 or pw)
                end
            end
        end
    end
    table.sort(powers, function(a, b) return a > b end)
    local best = powers[1] or 0
    local weakest = (#powers >= maxEquip) and powers[maxEquip] or 0
    return { maxEquip = maxEquip, owned = #powers, best = best, weakest = weakest }
end

function DuckkEvent.Hatch.EquipBest()
    if not Config.AutoEquipBestPets or not Modules.PetCmds then return end
    local now = os.clock()
    if (now - (Runtime.Cache.LastEquipBestAt or 0)) < 1.0 then return end
    Runtime.Cache.LastEquipBestAt = now
    if Modules.PetCmds.EquipBest then pcall(Modules.PetCmds.EquipBest) end
end

local EGG_FALLBACK_COST = {
    ["Cocoa Cabin Egg"] = 200, ["Apple Orchard Egg"] = 1000, ["Hayride Hill Egg"] = 4000,
    ["Cider Mill Egg"] = 8000, ["Golden Grove Egg"] = 16000, ["Pine Woods Egg"] = 128000,
    ["Maple Creek Egg"] = 1024000, ["Golden Ridge Egg"] = 8192000,
}

function DuckkEvent.Hatch.GetEggCost(eggName)
    local isP2 = (eggName == "Pine Woods Egg" or eggName == "Maple Creek Egg" or eggName == "Golden Ridge Egg")
    local m1 = tonumber(GetFlag("PumpkinTycoon_EggCostMult", 1)) or 1
    local m2 = isP2 and (tonumber(GetFlag("PumpkinTycoon_EggCostMultP2", 1)) or 1) or 1
    local dirEggs = Modules.Directory and Modules.Directory.Eggs
    local info = dirEggs and SafeDirLookup(dirEggs, eggName)
    local base = (info and (info.overrideCost or info.cost)) or EGG_FALLBACK_COST[eggName] or 16000
    return math.max(1, math.round(base * math.max(0.01, m1 * m2)))
end

function DuckkEvent.Hatch.FindIslandEgg(plot, buttons, preferHighestUnlocked)
    if not plot or not Modules.CustomEggsCmds or not Modules.CustomEggsCmds.All then return nil, nil, nil, nil end
    local ok, allEggs = pcall(Modules.CustomEggsCmds.All)
    if not ok or type(allEggs) ~= "table" then return nil, nil, nil, nil end

    local islandBox = GetIslandBox(plot)
    local ownedNames = {}
    local order = {}
    if not preferHighestUnlocked and type(Config.TargetEggName) == "string" then
        table.insert(order, Config.TargetEggName)
    end
    if PT and type(PT.ZONES) == "table" then
        local maxZ = GetZoneCount(plot)
        for i = math.min(#PT.ZONES, maxZ), 1, -1 do
            local z = PT.ZONES[i]
            if z and z.Egg and Modules.PumpkinButtonsUtil and Modules.PumpkinButtonsUtil.Owned(buttons, z.Section .. "_Egg") then
                ownedNames[z.Egg] = true
                table.insert(order, z.Egg)
            end
        end
    end

    for _, name in ipairs(order) do
        if ownedNames[name] then
            for uid, egg in pairs(allEggs) do
                if type(egg) == "table" and egg._id == name and egg._destroyed ~= true then
                    local pos = egg._position or (egg._model and egg._model:GetPivot().Position)
                    if pos and (not islandBox or not PT.OnIsland or PT.OnIsland(islandBox.cf, islandBox.size, pos)) then
                        return tostring(egg._uid or uid), name, pos, tonumber(egg._maxEggCount)
                    end
                end
            end
        end
    end
    return nil, nil, nil, nil
end

function DuckkEvent.Hatch.EvaluateBootstrap(plot, buttons)
    Runtime.Cache.ReserveEarlyEggCost = 0
    if not Config.AutoHatch or not Config.AutoEarlyHatchForDamage or not plot then return false end
    local eggUid, eggName, eggPos, eggMax = DuckkEvent.Hatch.FindIslandEgg(plot, buttons, true)
    if not eggUid or not eggPos then return false end

    local cost = DuckkEvent.Hatch.GetEggCost(eggName)
    local snap = DuckkEvent.Hatch.GetTeamSnapshot()
    local hatched = Runtime.Cache.EarlyHatchedByEgg[eggName] or 0

    if snap.owned < snap.maxEquip and hatched < snap.maxEquip then
        Runtime.Cache.ReserveEarlyEggCost = cost
        return true, eggUid, eggName, eggPos, eggMax, cost, (snap.maxEquip - hatched)
    end

    local dirEggs = Modules.Directory and Modules.Directory.Eggs
    local info = dirEggs and SafeDirLookup(dirEggs, eggName)
    local commonId = info and type(info.pets) == "table" and info.pets[1] and info.pets[1][1] or nil
    local commonDmg = commonId and select(1, DuckkEvent.Hatch.GetPetDamage({ id = commonId }, SafeDirLookup(Modules.Directory and Modules.Directory.Pets, commonId))) or 0
    local rainbowReady = Modules.PumpkinButtonsUtil and Modules.PumpkinButtonsUtil.Owned(buttons, "RainbowMachine") == true
    local targetMult = rainbowReady and 3.8 or 1.8

    if commonDmg > 0 and snap.weakest < (commonDmg * targetMult) and hatched < 450 then
        local coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
        if coins >= (cost * 15) then
            Runtime.Cache.ReserveEarlyEggCost = cost
            return true, eggUid, eggName, eggPos, eggMax, cost, (450 - hatched)
        end
    end
    return false
end

local GOLDEN_RIDGE_OVERLAP_OFFSET = Vector3.new(16.17, -4.13, 5.76)

local function StepHatch(plot, buttons, tycoonComplete)
    local function halt()
        Runtime.Cache.HatchInFlight = false
        Runtime.Stats.IsHatching = false
        Runtime.Cache.ActiveHatchEggPos = nil
        Runtime.Cache.ActiveHatchStandPos = nil
    end

    if not Config.AutoHatch or not plot or Runtime.Stats.FightingTurkeyBoss or Runtime.Cache.WildRerollActive then
        halt()
        return
    end
    if IsMoveLocked() or (Runtime.Cache.HatchYieldUntil or 0) > os.clock() then
        halt()
        return
    end

    local zoneHatchOn = Runtime.Helpers.IsEarlyZoneHatchActive(plot, buttons)
    local isEarly, eggUid, eggName, eggPos, eggMax, eggCost, capRem = false, nil, nil, nil, nil, 0, nil

    if Config.RushButtonsFirst and not tycoonComplete and not zoneHatchOn then
        local okBoot
        okBoot, eggUid, eggName, eggPos, eggMax, eggCost, capRem = DuckkEvent.Hatch.EvaluateBootstrap(plot, buttons)
        if not okBoot then halt() return end
        isEarly = true
    else
        eggUid, eggName, eggPos, eggMax = DuckkEvent.Hatch.FindIslandEgg(plot, buttons, false)
        if not eggUid or not eggPos then halt() return end
        eggCost = DuckkEvent.Hatch.GetEggCost(eggName)
    end

    local coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
    if zoneHatchOn and not tycoonComplete and Config.AutoBuyButtons ~= false then
        local nextBtn = Runtime.Helpers.GetNextBuyableButtonMinPrice(plot, buttons, tycoonComplete)
        if nextBtn and coins >= nextBtn then
            Runtime.Cache.ButtonBuyRequestedAt = os.clock()
            task.wait(0.12)
            return
        end
    end
    if coins < eggCost then halt() return end

    local maxHatch = (Modules.EggCmds and Modules.EggCmds.GetMaxHatch and select(2, pcall(Modules.EggCmds.GetMaxHatch))) or 1
    if type(eggMax) == "number" and eggMax >= 1 then maxHatch = math.min(maxHatch, eggMax) end
    if isEarly and type(capRem) == "number" then maxHatch = math.min(maxHatch, math.max(1, capRem)) end
    local batch = math.clamp(math.floor(coins / eggCost), 1, maxHatch)

    if Config.HatchDisableAnimation then
        if Workspace:GetAttribute("GlobalInstantHatch") ~= true then
            pcall(Workspace.SetAttribute, Workspace, "GlobalInstantHatch", true)
        end
        if type(Modules.Variables) == "table" then
            Modules.Variables.OpeningEgg = 0
            Modules.Variables.MessageOpen = false
        end
    end

    local standPos = nil
    if eggName == "Golden Ridge Egg" then
        local okCf, plotCf = pcall(plot.GetCFrame, plot)
        if okCf and typeof(plotCf) == "CFrame" then
            standPos = eggPos + plotCf:VectorToWorldSpace(GOLDEN_RIDGE_OVERLAP_OFFSET)
        end
    end

    Runtime.Cache.ActiveHatchEggPos = eggPos
    Runtime.Cache.ActiveHatchStandPos = standPos
    Runtime.Stats.IsHatching = true
    Runtime.Cache.HatchInFlight = true

    local _, hrp = GetCharacter()
    if hrp then
        local targetPos = standPos or eggPos
        if HorizontalDist(hrp.Position, targetPos) > (standPos and 5 or 26) then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            hrp.CFrame = CFrame.new(standPos or (eggPos + Vector3.new(0, 2.5, 4)))
            task.wait(0.20)
        end
    end

    local ok, res = pcall(Modules.Network.Invoke, "CustomEggs_Hatch", eggUid, batch)
    Runtime.Cache.HatchInFlight = false
    if ok and res == true then
        Runtime.Helpers.RecordCoinsSpent(batch * eggCost)
        Runtime.Stats.EggsHatched = (Runtime.Stats.EggsHatched or 0) + batch
        if isEarly then
            Runtime.Cache.EarlyHatchedByEgg[eggName] = (Runtime.Cache.EarlyHatchedByEgg[eggName] or 0) + batch
            DuckkEvent.Hatch.EquipBest()
        end
    end
end

-- Gold & Rainbow Pet Fusion (with Daycare / Equipped / Locked / Shiny protection)
function Craft.CollectDaycareUIDs(cmdModule, daycareUids)
    if not cmdModule or type(cmdModule.GetActive) ~= "function" then return end
    local ok, active = pcall(cmdModule.GetActive)
    if not ok or type(active) ~= "table" then return end
    for slotKey, entry in pairs(active) do
        if type(slotKey) == "string" and slotKey ~= "" then daycareUids[slotKey] = true end
        if type(entry) == "table" then
            if type(entry.uid) == "string" then daycareUids[entry.uid] = true end
            if type(entry._uid) == "string" then daycareUids[entry._uid] = true end
            if type(entry.Pet) == "table" and type(entry.Pet.uid) == "string" then
                daycareUids[entry.Pet.uid] = true
            end
        end
    end
end

function DuckkEvent.Fusion.GetEventPetWhitelist()
    if Runtime.Cache.CraftEventPetSet then return Runtime.Cache.CraftEventPetSet end
    local set = {}
    if Modules.PumpkinDamageUtil and type(Modules.PumpkinDamageUtil.EventPets) == "function" then
        local ok, ev = pcall(Modules.PumpkinDamageUtil.EventPets, true)
        if ok and type(ev) == "table" then
            for id in pairs(ev) do if type(id) == "string" then set[id] = true end end
        end
    end
    if next(set) ~= nil then Runtime.Cache.CraftEventPetSet = set end
    return set
end

function DuckkEvent.Fusion.Step(plot, buttons)
    if not plot or not Modules.Network then return end
    local now = os.clock()
    local interval = Runtime.Stats.TycoonComplete and 25.0 or 6.0
    if (now - (Runtime.Cache.LastCraftCheckAt or 0)) < interval then return end
    Runtime.Cache.LastCraftCheckAt = now

    local invPets = Runtime.Helpers.GetSaveInventory("Pet")
    if not invPets then return end

    local daycare = {}
    Craft.CollectDaycareUIDs(Modules.DaycareCmds, daycare)
    Craft.CollectDaycareUIDs(Modules.ExclusiveDaycareCmds, daycare)

    local equipped = {}
    if Modules.PetCmds and type(Modules.PetCmds.GetEquipped) == "function" then
        local okEq, eqList = pcall(Modules.PetCmds.GetEquipped)
        if okEq and type(eqList) == "table" then
            for _, eq in pairs(eqList) do
                local u = type(eq) == "table" and (eq.uid or eq._uid) or (type(eq) == "string" and eq or nil)
                if u then equipped[tostring(u)] = (equipped[tostring(u)] or 0) + 1 end
            end
        end
    end

    local whitelist = DuckkEvent.Fusion.GetEventPetWhitelist()
    local petsDir = Modules.Directory and Modules.Directory.Pets
    local minBatch = Runtime.Stats.TycoonComplete and 5 or 1

    local machines = {
        { on = Config.AutoMakeGold, btn = "GoldMachine", remote = "GoldMachine_Activate", ptMatch = 0, stat = "GoldCrafted", perk = "GoldReduction" },
        { on = Config.AutoMakeRainbow, btn = "RainbowMachine", remote = "RainbowMachine_Activate", ptMatch = 1, stat = "RainbowCrafted", perk = "RainbowReduction" },
    }

    for _, m in ipairs(machines) do
        if m.on ~= false and Modules.PumpkinButtonsUtil and Modules.PumpkinButtonsUtil.Owned(buttons, m.btn) then
            local cost = 10
            if Modules.MasteryCmds and type(Modules.MasteryCmds.HasPerk) == "function" then
                local okH, has = pcall(Modules.MasteryCmds.HasPerk, "Pets", m.perk)
                if okH and has and Modules.MasteryCmds.GetPerkPower then
                    local okP, p = pcall(Modules.MasteryCmds.GetPerkPower, "Pets", m.perk)
                    if okP and type(p) == "number" then cost = math.max(1, 10 - math.floor(p)) end
                end
            end

            invPets = Runtime.Helpers.GetSaveInventory("Pet") or invPets
            local plans = {}
            for uid, d in pairs(invPets) do
                local uStr = tostring(uid)
                local ptVal = tonumber(d.pt) or 0
                if type(d) == "table" and type(d.id) == "string"
                    and ptVal == m.ptMatch
                    and not daycare[uStr]
                    and d._lk ~= true and d.sh ~= true
                    and (next(whitelist) == nil or whitelist[d.id] == true)
                then
                    local pd = SafeDirLookup(petsDir, d.id)
                    if not Runtime.Helpers.GetChaseCategory(d.id, pd) then
                        local avail = math.max(1, math.floor(tonumber(d._am) or 1)) - (equipped[uStr] or 0)
                        local crafts = math.floor(avail / cost)
                        if crafts >= minBatch then
                            table.insert(plans, { uid = uid, id = d.id, crafts = math.min(crafts, 25) })
                        end
                    end
                end
            end

            if #plans > 0 then
                WithMachinePad(plot, m.btn, 80, function()
                    for _, pl in ipairs(plans) do
                        if not IsRunning() then break end
                        ExtendMachineSession(5.0)
                        local okC, resC, _, shinyCnt = pcall(Modules.Network.Invoke, m.remote, pl.uid, pl.crafts)
                        if okC and resC == true then
                            Runtime.Stats[m.stat] = (Runtime.Stats[m.stat] or 0) + pl.crafts
                            Runtime.Stats.ShinyCrafted = (Runtime.Stats.ShinyCrafted or 0) + (tonumber(shinyCnt) or 0)
                            Log("INFO", "[DuckkEvent] Fused %dx [%s] at %s", pl.crafts, pl.id, m.btn)
                            task.wait(0.08)
                        else
                            break
                        end
                    end
                end, { standOnPad = true, closeModal = true })
                DuckkEvent.Hatch.EquipBest()
            end
        end
    end
end

-- ============================================================================
-- 12B. KAITUN BLACK DASHBOARD UI
-- ============================================================================
local UI = {
    COMPACT_SUFFIXES = {
        { 1e39, "Dd" }, { 1e36, "Ud" }, { 1e33, "Dc" }, { 1e30, "No" },
        { 1e27, "Oc" }, { 1e24, "Sp" }, { 1e21, "Sx" }, { 1e18, "Qi" },
        { 1e15, "Qa" }, { 1e12, "T" },  { 1e9,  "B" },  { 1e6,  "M" },  { 1e3, "K" },
    },
    KEEP_RUNG_SHORT = {
        [2] = "Rare", [3] = "Epic", [4] = "Leg", [5] = "Myth", [6] = "Exotic", [7] = "Divine", [8] = "Secret",
    },
    BOOST_IDS_FALLBACK = {
        Coins = { "PumpkinTycoonCoins1", "PumpkinTycoonCoins2", "PumpkinTycoonCoins3" },
        Damage = { "PumpkinTycoonDamage1", "PumpkinTycoonDamage2", "PumpkinTycoonDamage3" },
        IslandLuck = { "PumpkinTycoonIslandLuck1", "PumpkinTycoonIslandLuck2", "PumpkinTycoonIslandLuck3" },
    },
}

function UI.FormatTime(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), math.floor(seconds % 60))
end

function UI.FormatCompactNumber(n)
    n = tonumber(n) or 0
    if n ~= n or n == math.huge or n == -math.huge then return "0" end
    local sign = ""
    if n < 0 then
        sign = "-"
        n = -n
    end
    if n < 1000 then return sign .. tostring(math.floor(n)) end
    for idx, entry in ipairs(UI.COMPACT_SUFFIXES) do
        if n >= entry[1] then
            local rounded = math.floor((n / entry[1]) * 100 + 0.5) / 100
            if rounded >= 1000 and idx > 1 then
                entry = UI.COMPACT_SUFFIXES[idx - 1]
                rounded = math.floor((n / entry[1]) * 100 + 0.5) / 100
            end
            local text = string.format("%.2f", rounded):gsub("%.00$", ""):gsub("(%.[1-9])0$", "%1")
            return sign .. text .. entry[2]
        end
    end
    return sign .. tostring(math.floor(n))
end

function UI.FormatIslandLuck(val)
    val = tonumber(val) or 0
    if val ~= val or val == math.huge or val == -math.huge or val < 0 then val = 0 end
    local rounded = math.floor(val + 0.5)
    if rounded >= 1e6 then return "+" .. UI.FormatCompactNumber(rounded) .. "%" end
    return "+" .. Runtime.Helpers.FormatCommas(rounded) .. "%"
end

function UI.FormatShortTimer(sec)
    sec = tonumber(sec) or 0
    if sec ~= sec or sec <= 0 or sec == math.huge then return "Off" end
    local s = math.max(1, math.floor(sec))
    if s < 60 then return string.format("%ds", s) end
    if s < 3600 then return string.format("%dm%02ds", math.floor(s / 60), s % 60) end
    return string.format("%dh%02dm", math.floor(s / 3600), math.floor((s % 3600) / 60))
end

function UI.FormatKeepLabel(keepRung)
    if type(keepRung) == "string" and keepRung ~= "" then return keepRung end
    local r = math.floor(tonumber(keepRung) or 0)
    if r <= 0 or r == 1 then return "Off" end
    local shortName = UI.KEEP_RUNG_SHORT[r]
    return shortName and string.format("%s (%d+)", shortName, r) or string.format("R%d+", r)
end

function Runtime.Helpers.GetAxisBoostSeconds(axis)
    local ids = (Modules.PumpkinBoostsUtil and Modules.PumpkinBoostsUtil.IDS and Modules.PumpkinBoostsUtil.IDS[axis])
        or UI.BOOST_IDS_FALLBACK[axis]
    if type(ids) ~= "table" then return 0 end
    local pausedSum, activeMax = 0, 0
    for tier = 1, #ids do
        local boostId = ids[tier]
        local sec = boostId and GetBoostTimerSeconds(boostId) or 0
        if sec > 0 then
            local isPaused = false
            if Modules.BoostCmds and Modules.BoostCmds.IsTierPaused then
                local okP, paused = pcall(Modules.BoostCmds.IsTierPaused, boostId)
                isPaused = okP and paused == true
            end
            if isPaused then
                pausedSum = pausedSum + sec
            elseif sec > activeMax then
                activeMax = sec
            end
        end
    end
    return pausedSum + activeMax
end

function UI.ReadPedestalLockCounts(plot)
    if not plot then return 0, 0 end
    local raw = Runtime.Helpers.GetPlotSave(plot, VAR.Pedestals)
    if type(raw) ~= "table" then return tonumber(Runtime.Stats.LockedPedestals) or 0, tonumber(Runtime.Stats.MaxKeepSlots) or 0 end
    local maxPed = (PT and PT.MAX_PEDESTALS) or 8
    local unlocked, locked = 0, 0
    for i = 1, maxPed do
        local entry = raw[i]
        if type(entry) == "table" and entry.Unlocked == true then
            unlocked = unlocked + 1
            if type(entry.Standing) == "table" and entry.Locked == true then
                locked = locked + 1
            end
        end
    end
    local effKeep, lockMin, maxKeep, _, smartLuckMode =
        GetKeepLockSettings(nil, unlocked, plot, Runtime.Cache.Buttons, Runtime.Stats.TycoonComplete)
    if smartLuckMode then
        local _, keepList, sumLuck, luckCap = Runtime.Helpers.ComputeSmartLuckKeepSet(AnalyzePedestals(plot), lockMin, maxKeep)
        maxKeep = math.max(#keepList, (sumLuck < luckCap) and maxKeep or #keepList)
        effKeep = "Luck100"
    end
    Runtime.Stats.LockedPedestals = locked
    Runtime.Stats.MaxKeepSlots = maxKeep
    return locked, maxKeep, effKeep
end

function UI.ReadCatchesTopStatus()
    local boardId = (Modules.PumpkinContestsUtil and Modules.PumpkinContestsUtil.BOARD_ID) or "PumpkinTycoonCatches"
    local lbCmds = Modules.LeaderboardCmds
    if not lbCmds and Library then
        local clientFolder = Library:FindFirstChild("Client")
        local lbInst = clientFolder and clientFolder:FindFirstChild("LeaderboardCmds")
        if lbInst then
            local okReq, mod = pcall(requireModule, lbInst)
            if okReq and type(mod) == "table" then
                Modules.LeaderboardCmds = mod
                lbCmds = mod
            end
        end
    end

    local rank, score = nil, 0
    if lbCmds and type(lbCmds.Get) == "function" then
        local okGet, state = pcall(lbCmds.Get, boardId)
        local myData = (okGet and type(state) == "table" and type(state.LocalPlayer) == "table") and state.LocalPlayer or nil
        if myData then
            local r = tonumber(myData.GlobalRank)
            if r and r >= 1 and r == r and r < math.huge then
                rank = math.floor(r)
            end
            local s = tonumber(myData.Score)
            if s and s >= 0 and s == s and s < math.huge then
                score = math.floor(s)
            end
        end
    end

    Runtime.Stats.CatchesRank = rank
    Runtime.Stats.CatchesScore = score

    local tierMax = nil
    if rank then
        local okDir, groups = pcall(function()
            local contestsDir = Modules.Directory and Modules.Directory.LeaderboardContests
            local entry = SafeDirLookup(contestsDir, boardId)
            return type(entry) == "table" and entry.SelectGroups or nil
        end)
        if okDir and type(groups) == "table" then
            for i = #groups, 1, -1 do
                local cutoff = tonumber(groups[i])
                if cutoff and rank <= cutoff then
                    tierMax = math.floor(cutoff)
                end
            end
        end
    end

    if rank then
        local rankStr = "#" .. Runtime.Helpers.FormatCommas(rank)
        local scoreStr = Runtime.Helpers.FormatCommas(score)
        if tierMax then
            return string.format("Catches Top: %s (%s pts)  |  Tier: Top %s",
                rankStr, scoreStr, Runtime.Helpers.FormatCommas(tierMax))
        end
        return string.format("Catches Top: %s (%s pts)", rankStr, scoreStr)
    end
    return string.format("Catches Top: Unranked (%s pts)", Runtime.Helpers.FormatCommas(score))
end

function UI.FindDashboardParent()
    local pg = LocalPlayer and (LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5))
    if pg then
        DestroyExistingKaitunGui(pg)
        return pg
    end
    return nil
end

local function InitKaitunDashboard()
    if Config.ShowKaitunUI == false then return end

    local okInit, initErr = pcall(function()
        local parent = UI.FindDashboardParent()
        if not parent or not IsRunning() then return end

        local C_GOLD   = Color3.fromRGB(255, 170, 0)
        local C_DIM    = Color3.fromRGB(200, 205, 220)
        local C_WHITE  = Color3.new(1, 1, 1)
        local C_GREEN  = Color3.fromRGB(80, 220, 120)
        local C_PURPLE = Color3.fromRGB(180, 150, 255)
        local C_CYAN   = Color3.fromRGB(90, 215, 255)

        local sg = Instance.new("ScreenGui")
        sg.Name = KAITUN_GUI_NAME
        sg.DisplayOrder = 999999
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        sg.Parent = parent

        local uiToken = HttpService:GenerateGUID(false)
        Runtime.Cache.KaitunGui = sg
        Runtime.Cache.KaitunUiToken = uiToken

        local bg = Instance.new("Frame")
        bg.Name = "BlackOverlay"
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.new(0, 0, 0)
        bg.BackgroundTransparency = 0
        bg.BorderSizePixel = 0
        bg.ZIndex = 999
        bg.Parent = sg

        local container = Instance.new("Frame")
        container.Name = "ContentContainer"
        container.Size = UDim2.new(1, 0, 0, 440)
        container.AnchorPoint = Vector2.new(0.5, 0.5)
        container.Position = UDim2.new(0.5, 0, 0.5, 0)
        container.BackgroundTransparency = 1
        container.BorderSizePixel = 0
        container.ZIndex = 1000
        container.Parent = sg

        local function MkText(name, parentObj, text, size, color, bold, yPos, h)
            local l = Instance.new("TextLabel")
            l.Name = name
            l.Size = UDim2.new(1, 0, 0, h or (size + 6))
            l.Position = UDim2.new(0, 0, 0, yPos)
            l.BackgroundTransparency = 1
            l.Text = text
            l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
            l.TextSize = size
            l.TextColor3 = color or C_WHITE
            l.TextXAlignment = Enum.TextXAlignment.Center
            l.TextYAlignment = Enum.TextYAlignment.Center
            l.ZIndex = 1000
            l.Parent = parentObj
            return l
        end

        local function MkSep(parentObj, yPos)
            local s = Instance.new("Frame")
            s.Size = UDim2.new(0, 420, 0, 2)
            s.Position = UDim2.new(0.5, -210, 0, yPos)
            s.BackgroundColor3 = C_GOLD
            s.BackgroundTransparency = 0.4
            s.BorderSizePixel = 0
            s.ZIndex = 1000
            s.Parent = parentObj
            return s
        end

        MkText("lblName", container, LocalPlayer and LocalPlayer.Name or "Player", 44, C_GOLD, true, 10, 50)
        MkSep(container, 75)
        local lblTime      = MkText("lblTime", container, "Session Time: 00:00:00", 24, C_WHITE, true, 90, 32)
        local lblCoins     = MkText("lblCoins", container, "Patch Coins: 0  |  Tokens: 0", 22, C_GOLD, true, 130, 32)
        local lblGifts     = MkText("lblGifts", container, "Flannel Gifts: 0 (Bag: 0)  |  Island Luck: +0%", 22, C_GREEN, true, 170, 30)
        local lblEggsCraft = MkText("lblEggsCraft", container, "Eggs: 0 (None)  |  Craft: G 0 / R 0", 18, C_DIM, false, 208, 28)
        local lblTycoon    = MkText("lblTycoon", container, "Tycoon: 0/0 (Wait)  |  Keep: Off (Lock 0/0)", 18, C_DIM, false, 240, 28)
        local lblBoosts    = MkText("lblBoosts", container, "Boosts: Coin Off | Dmg Off | Luck Off", 17, C_PURPLE, false, 272, 27)
        local lblCatches   = MkText("lblCatches", container, "Catches Top: Unranked (0 pts)", 18, C_CYAN, true, 302, 27)
        local lblStatus    = MkText("lblStatus", container, "Status: Initializing  |  Target: None", 18, C_DIM, false, 332, 28)
        MkSep(container, 370)
        MkText("lblRunning", container, "Running: Duckk Kaitun — Turkey Hunt & Pumpkin Tycoon", 22, C_WHITE, true, 385, 34)

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Name = "ToggleBtn"
        toggleBtn.Size = UDim2.new(0, 36, 0, 36)
        toggleBtn.Position = UDim2.new(1, -48, 0, 10)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 25, 50)
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Text = "-"
        toggleBtn.TextSize = 22
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextColor3 = C_WHITE
        toggleBtn.ZIndex = 1001
        toggleBtn.Parent = sg

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = toggleBtn

        local isHidden = false
        container.Visible = true
        bg.Visible = true
        Set3dRenderingSafe(false)

        BindConn(toggleBtn.MouseButton1Click, function()
            isHidden = not isHidden
            container.Visible = not isHidden
            bg.Visible = not isHidden
            toggleBtn.Text = isHidden and "+" or "-"
            Set3dRenderingSafe(isHidden)
        end)

        local prevTexts = {}
        local function SetTextIfChanged(lbl, newText)
            if prevTexts[lbl] ~= newText then
                prevTexts[lbl] = newText
                lbl.Text = newText
            end
        end

        local function RefreshLabels()
            local elapsed = os.time() - (tonumber(Runtime.Stats.StartTime) or os.time())
            SetTextIfChanged(lblTime, "Session Time: " .. UI.FormatTime(elapsed))

            local coins = GetCurrency((PT and PT.COIN) or "PumpkinTycoonCoins")
            local tokens = GetCurrency((PT and PT.TOKENS) or "PumpkinTokens")
            Runtime.Stats.Coins = coins
            Runtime.Stats.Tokens = tokens
            local cps = Runtime.Helpers.UpdateCoinRateSampler(coins)
            SetTextIfChanged(lblCoins, string.format("Patch Coins: %s (+%s/s)  |  Tokens: %s",
                UI.FormatCompactNumber(coins),
                UI.FormatCompactNumber(cps),
                UI.FormatCompactNumber(tokens)))

            local openedGifts = tonumber(Runtime.Stats.GiftsOpened) or 0
            local _, _, _, bagGifts = Runtime.Helpers.ScanFlannelGiftBag()
            local luckAttr = (Modules.PumpkinEarnUtil and Modules.PumpkinEarnUtil.ATTR_ISLAND_LUCK) or "PumpkinTycoonIslandLuck"
            local rawLuck = tonumber(LocalPlayer and LocalPlayer:GetAttribute(luckAttr))
            local luckVal = (type(rawLuck) == "number" and rawLuck == rawLuck and rawLuck < math.huge)
                and math.max(0, rawLuck)
                or (tonumber(Runtime.Stats.IslandLuck) or 0)
            Runtime.Stats.IslandLuck = luckVal
            if (tonumber(Runtime.Stats.ButtonsTotal) or 0) > 68 then
                SetTextIfChanged(lblGifts, string.format("Gifts: %s (Bag: %s)  |  Luck: %s  |  Nets: %d/%d  |  Hunt: %d (Huge: %d)",
                    UI.FormatCompactNumber(openedGifts),
                    UI.FormatCompactNumber(bagGifts),
                    UI.FormatIslandLuck(luckVal),
                    Runtime.Helpers.GetNetCount("Pet Net"),
                    Runtime.Helpers.GetNetCount("Ultra Pet Net"),
                    tonumber(Runtime.Stats.WildCaught) or 0,
                    tonumber(Runtime.Stats.WildHugesCaught) or 0))
            else
                SetTextIfChanged(lblGifts, string.format("Flannel Gifts: %s (Bag: %s)  |  Island Luck: %s",
                    UI.FormatCompactNumber(openedGifts),
                    UI.FormatCompactNumber(bagGifts),
                    UI.FormatIslandLuck(luckVal)))
            end

            local targetEggLabel = (Config.AutoHatch == false) and "Off" or tostring(Config.TargetEggName or "None")
            if targetEggLabel == "" then targetEggLabel = "None" end
            local shinyCrafted = tonumber(Runtime.Stats.ShinyCrafted) or 0
            local craftText = string.format("G %s / R %s",
                UI.FormatCompactNumber(tonumber(Runtime.Stats.GoldCrafted) or 0),
                UI.FormatCompactNumber(tonumber(Runtime.Stats.RainbowCrafted) or 0))
            if shinyCrafted > 0 then
                craftText = craftText .. " / S " .. UI.FormatCompactNumber(shinyCrafted)
            end
            SetTextIfChanged(lblEggsCraft, string.format("Eggs: %s (%s)  |  Craft: %s",
                UI.FormatCompactNumber(tonumber(Runtime.Stats.EggsHatched) or 0),
                targetEggLabel,
                craftText))

            local inEvent = IsInEventInstance()
            local plot = inEvent and GetMyPlot() or nil
            if plot and (tonumber(Runtime.Stats.ButtonsTotal) or 0) == 0 then
                GetProgressState(plot)
            end
            local done = tonumber(Runtime.Stats.ButtonsDone) or 0
            local total = tonumber(Runtime.Stats.ButtonsTotal) or 0
            local tycoonStatus
            if total <= 0 then
                tycoonStatus = inEvent and "Loading" or "Wait"
            elseif Runtime.Stats.TycoonComplete == true then
                tycoonStatus = Runtime.Stats.CompletedClaimed and "Done" or "Claim"
            else
                tycoonStatus = string.format("%d%%", math.clamp(math.floor((done / total) * 100 + 0.5), 0, 99))
            end
            local curReb = tonumber(Runtime.Stats.Rebirths) or 0
            local tgtReb = math.floor(tonumber(Config.TargetRebirths) or 0)
            local rebLabel = (tgtReb > 0) and string.format("%d/%d", curReb, tgtReb) or tostring(curReb)
            local lockedPed, maxKeepPed, effKeepRung = UI.ReadPedestalLockCounts(plot)
            SetTextIfChanged(lblTycoon, string.format("Tycoon: %d/%d (%s)  |  Reb: %s  |  Keep: %s (Lock %d/%d)",
                done, total, tycoonStatus, rebLabel,
                UI.FormatKeepLabel(effKeepRung ~= nil and effKeepRung or Config.KeepRung),
                lockedPed, maxKeepPed))

            SetTextIfChanged(lblBoosts, string.format("Boosts: Coin %s | Dmg %s | Luck %s | Apple %dx",
                UI.FormatShortTimer(Runtime.Helpers.GetAxisBoostSeconds("Coins")),
                UI.FormatShortTimer(Runtime.Helpers.GetAxisBoostSeconds("Damage")),
                UI.FormatShortTimer(Runtime.Helpers.GetAxisBoostSeconds("IslandLuck")),
                Runtime.Helpers.GetActiveFruitCount("Apple")))

            SetTextIfChanged(lblCatches, UI.ReadCatchesTopStatus())

            local targetDesc = tostring(Runtime.Stats.ActiveTargetDesc or "None")
            if Runtime.Stats.FightingTurkeyBoss then
                local bossHp = tonumber(Runtime.Stats.TurkeyBossHealth) or 0
                if bossHp > 0 then
                    targetDesc = string.format("TurkeyBoss (HP %s | %.1f%%)",
                        UI.FormatCompactNumber(bossHp),
                        (tonumber(Runtime.Stats.TurkeyBossShare) or 0) * 100)
                end
            end
            SetTextIfChanged(lblStatus, string.format("Status: %s  |  Target: %s",
                tostring(Runtime.Stats.Phase or "Initializing"), targetDesc))
        end

        pcall(RefreshLabels)

        local lastErrLogAt = 0
        task.spawn(function()
            while IsRunning() and sg and sg.Parent and Runtime.Cache.KaitunUiToken == uiToken do
                task.wait(Config.UltraLowRAM and 1.5 or 0.5)
                if not (IsRunning() and sg and sg.Parent and Runtime.Cache.KaitunUiToken == uiToken) then break end
                local uOk, uErr = pcall(RefreshLabels)
                if not uOk then
                    local now = os.clock()
                    if (now - lastErrLogAt) >= 10 then
                        lastErrLogAt = now
                        Log("DEBUG", "Kaitun UI updater error: %s", tostring(uErr))
                    end
                end
            end
        end)

        Log("INFO", "Kaitun Dashboard UI initialized (3D rendering disabled).")
    end)

    if not okInit then
        CleanupKaitunDashboard()
        Log("DEBUG", "Failed to initialize Kaitun Dashboard UI: %s", tostring(initErr))
    end
end

-- ============================================================================
-- 12C. DISCORD PET DROP WEBHOOK (HUGE / TITANIC / GARGANTUAN)
-- ============================================================================
Runtime.Webhook = Runtime.Webhook or {}

function Runtime.Webhook.NormalizeUrl(raw)
    local cleaned = type(raw) == "string" and (raw:match("^%s*(.-)%s*$") or "") or ""
    if cleaned == "" then return nil, "empty" end
    local base = (cleaned:match("^(.-)%?.*$") or cleaned):gsub("/+$", "")
    if base:match("^https://[%w%-]+%.discord%.com/api/webhooks/%d+/[%w%-_]+$")
        or base:match("^https://discord%.com/api/webhooks/%d+/[%w%-_]+$")
        or base:match("^https://discordapp%.com/api/webhooks/%d+/[%w%-_]+$")
    then
        return base, nil
    end
    return nil, "invalid_format"
end

function Runtime.Webhook.GetHttpSender()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
    if type(http) == "table" and type(http.request) == "function" then return http.request end
    return nil
end

function Runtime.Helpers.EnsureItemsUpdateHook()
    if Runtime.Cache.ItemsUpdateConnBound then return end
    local net = Modules.Network
    if not net or type(net.Fired) ~= "function" then return end
    local okSig, sig = pcall(net.Fired, "Items: Update")
    if okSig and sig and type(sig.Connect) == "function" then
        Runtime.Cache.ItemsUpdateConnBound = true
        BindConn(sig, function(plr)
            if plr == nil or plr == LocalPlayer then
                Runtime.Cache.WebhookInvDirty = true
                Runtime.Cache.GiftBagDirty = true
                Runtime.Cache.MailInvDirty = true
                Runtime.Cache.TeamPowerSnapshotAt = 0
            end
        end)
    end
end

function Runtime.Webhook.ReadSnapshot(forceRefresh)
    if not (Modules.Save and Modules.InventoryCmds and Modules.Directory) then return nil, nil end
    local invPets = Runtime.Helpers.GetSaveInventory("Pet")
    if not invPets then return nil, nil end
    local okCont, container = pcall(Modules.InventoryCmds.Container)
    if not okCont or not container then return nil, nil end

    local now = os.clock()
    local activitySig = tostring(Runtime.Stats.EggsHatched or 0)
        .. "|" .. tostring(Runtime.Stats.GoldCrafted or 0)
        .. "|" .. tostring(Runtime.Stats.RainbowCrafted or 0)
        .. "|" .. tostring(Runtime.Stats.GiftsOpened or 0)
        .. "|" .. tostring(Runtime.Stats.WildCaught or 0)
        .. "|" .. tostring(Runtime.Stats.SightingsCaught or 0)
    if Runtime.Cache.WebhookLastActivitySig ~= activitySig then
        Runtime.Cache.WebhookLastActivitySig = activitySig
        Runtime.Cache.WebhookInvDirty = true
    end

    if not forceRefresh
        and not Runtime.Cache.WebhookInvDirty
        and Runtime.Cache.WebhookLastSnapshot ~= nil
        and container == Runtime.Cache.WebhookLastContainer
        and invPets == Runtime.Cache.WebhookLastInvRef
        and (now - (Runtime.Cache.WebhookLastReadAt or 0)) < 10.0
    then
        return Runtime.Cache.WebhookLastSnapshot, container
    end

    local petsDir = Modules.Directory.Pets
    local snapshot = {}
    for _, itemData in pairs(invPets) do
        if type(itemData) == "table" and type(itemData.id) == "string" then
            local pd = SafeDirLookup(petsDir, itemData.id)
            local category = Runtime.Helpers.GetChaseCategory(itemData.id, pd)
            if category then
                local petType = tonumber(itemData.pt) or 0
                local shiny = (itemData.sh == true)
                local key = itemData.id .. ":" .. tostring(petType) .. ":" .. tostring(shiny)
                local record = snapshot[key]
                if not record then
                    record = { id = itemData.id, petType = petType, shiny = shiny, category = category, amount = 0 }
                    snapshot[key] = record
                end
                record.amount = record.amount + math.max(1, math.floor(tonumber(itemData._am) or 1))
            end
        end
    end

    Runtime.Cache.WebhookLastSnapshot = snapshot
    Runtime.Cache.WebhookLastContainer = container
    Runtime.Cache.WebhookLastInvRef = invPets
    Runtime.Cache.WebhookLastReadAt = now
    Runtime.Cache.WebhookInvDirty = false
    return snapshot, container
end

function Runtime.Webhook.ResolveThumbnail(icon)
    local assetId = type(icon) == "string" and icon:match("(%d+)$") or nil
    if not assetId then return nil end
    local cached = Runtime.Cache.WebhookThumbnails[assetId]
    if cached then return cached end
    local ok, imageUrl = pcall(function()
        local raw = game:HttpGet(
            "https://thumbnails.roblox.com/v1/assets?assetIds=" .. assetId .. "&size=150x150&format=Png&isCircular=false"
        )
        local decoded = HttpService:JSONDecode(raw)
        local row = decoded and decoded.data and decoded.data[1]
        if row and row.state == "Completed" and type(row.imageUrl) == "string" and row.imageUrl:match("^https://") then return row.imageUrl end
        return nil
    end)
    if ok and imageUrl then
        Runtime.Cache.WebhookThumbnails[assetId] = imageUrl
        return imageUrl
    end
    return "https://biggamesapi.io/image/" .. assetId
end

local WEBHOOK_CATEGORY_COLOR = {
    Huge = 16769288,
    Titanic = 16729344,
    Gargantuan = 11731199,
}

function Runtime.Webhook.BuildDropPayload(record, gained)
    local item = Modules.PetItem(record.id):SetType(tonumber(record.petType) or 0):SetShiny(record.shiny == true)
    local petName = tostring(item:GetName() or record.id)
    local okEx, existVal = false, nil
    if Modules.GlobalExistCmds and type(Modules.GlobalExistCmds.Get) == "function" then
        okEx, existVal = pcall(Modules.GlobalExistCmds.Get, item)
    end
    local okRap, rapVal = false, nil
    if Modules.RAPCmds and type(Modules.RAPCmds.Get) == "function" then
        okRap, rapVal = pcall(Modules.RAPCmds.Get, item)
    end

    local amountLine = (type(gained) == "number" and gained > 1) and string.format("**Amount: +%d**\n", gained) or ""
    local embed = {
        title = string.upper(tostring(record.category)) .. " DROP",
        description = string.format(
            "**Name Pet: %s**\n%s**Exist: %s**\n**Rap: %s**\n**Account:**\n||%s||",
            petName,
            amountLine,
            Runtime.Helpers.FormatCommas(okEx and existVal or nil, "No data"),
            Runtime.Helpers.FormatCommas(okRap and rapVal or nil, "No data"),
            LocalPlayer and LocalPlayer.Name or "Unknown"
        ),
        color = WEBHOOK_CATEGORY_COLOR[record.category] or 16769288,
        timestamp = DateTime.now():ToIsoDate(),
    }
    local thumbUrl = Runtime.Webhook.ResolveThumbnail(item:GetIcon())
    if thumbUrl then embed.thumbnail = { url = thumbUrl } end
    local rawDiscordId = type(Config.DiscordID) == "string" and Config.DiscordID:match("(%d+)") or nil
    if rawDiscordId and rawDiscordId ~= "" then
        return {
            content = "<@" .. rawDiscordId .. ">",
            embeds = { embed },
            allowed_mentions = { parse = {}, users = { rawDiscordId } },
        }
    end
    return { embeds = { embed }, allowed_mentions = { parse = {} } }
end

function Runtime.Webhook.PostJson(url, payload)
    local sender = Runtime.Webhook.GetHttpSender()
    if type(sender) ~= "function" then return false, "Executor does not support HTTP requests" end
    local encoded = HttpService:JSONEncode(payload)
    for attempt = 1, 2 do
        local ok, result = pcall(function()
            return sender({
                Url = url .. "?wait=true",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = encoded,
            })
        end)
        if not ok or type(result) ~= "table" then return false, "HTTP request failed" end
        local status = tonumber(result.StatusCode)
        if status and status >= 200 and status < 300 then return true, nil end
        if status == 429 and attempt == 1 then
            local retrySec = 2
            pcall(function()
                local body = type(result.Body) == "string" and HttpService:JSONDecode(result.Body) or nil
                local ra = type(body) == "table" and tonumber(body.retry_after) or nil
                if ra and ra > 0 and ra <= 10 then retrySec = ra + 0.1 end
            end)
            task.wait(retrySec)
        else
            return false, "Discord HTTP " .. tostring(status or "unknown")
        end
    end
    return false, "Discord HTTP 429"
end

function Runtime.Webhook.ResolveCategoryUrl(category)
    if not Config.WebhookEnabled then return nil, "disabled" end
    local fallback = Config.WebhookUrl
    local rawUrl = fallback
    if category == "Gargantuan" then
        if type(Config.GargantuanWebhookURL) == "string" and Config.GargantuanWebhookURL ~= "" then
            rawUrl = Config.GargantuanWebhookURL
        elseif type(Config.TitanicWebhookURL) == "string" and Config.TitanicWebhookURL ~= "" then
            rawUrl = Config.TitanicWebhookURL
        elseif type(Config.HugeWebhookURL) == "string" and Config.HugeWebhookURL ~= "" then
            rawUrl = Config.HugeWebhookURL
        end
    elseif category == "Titanic" then
        if type(Config.TitanicWebhookURL) == "string" and Config.TitanicWebhookURL ~= "" then
            rawUrl = Config.TitanicWebhookURL
        elseif type(Config.HugeWebhookURL) == "string" and Config.HugeWebhookURL ~= "" then
            rawUrl = Config.HugeWebhookURL
        end
    elseif category == "Huge" then
        if type(Config.HugeWebhookURL) == "string" and Config.HugeWebhookURL ~= "" then
            rawUrl = Config.HugeWebhookURL
        end
    end
    return Runtime.Webhook.NormalizeUrl(rawUrl)
end

function Runtime.Webhook.ResolveTargets()
    if not Config.WebhookEnabled then return nil, nil, "disabled" end
    local hugeUrl, hugeErr = Runtime.Webhook.ResolveCategoryUrl("Huge")
    local titanicUrl, titanicErr = Runtime.Webhook.ResolveCategoryUrl("Titanic")
    local gargUrl, gargErr = Runtime.Webhook.ResolveCategoryUrl("Gargantuan")
    local anyUrl = hugeUrl or titanicUrl or gargUrl
    local anyErr = (not anyUrl) and (hugeErr == "invalid_format" or titanicErr == "invalid_format" or gargErr == "invalid_format") and "invalid_format" or nil
    return nil, anyUrl, anyErr
end

function Runtime.Webhook.RunLoop()
    Log("INFO", "Pet drop webhook watcher loop started.")
    local previous = nil
    local previousContainer = nil

    while IsRunning() do
        local _, anyUserUrl, userErr = Runtime.Webhook.ResolveTargets()
        if not anyUserUrl then
            previous, previousContainer = nil, nil
            if Config.WebhookEnabled and userErr == "invalid_format" and Runtime.Cache.WebhookWarnedState ~= "invalid_format" then
                Runtime.Cache.WebhookWarnedState = "invalid_format"
                Log("INFO", "Webhook paused: invalid Discord webhook URL format.")
            end
            task.wait(2.0)
        elseif not Runtime.Webhook.GetHttpSender() then
            if Runtime.Cache.WebhookWarnedState ~= "no_http" then
                Runtime.Cache.WebhookWarnedState = "no_http"
                Log("INFO", "Webhook unavailable: executor has no HTTP request function.")
            end
            task.wait(5.0)
        else
            Runtime.Cache.WebhookWarnedState = nil

            local current, container = Runtime.Webhook.ReadSnapshot(false)
            if current then
                if current ~= previous or container ~= previousContainer then
                    local baseline = (container == previousContainer) and previous or nil
                    previous, previousContainer = current, container
                    if baseline then
                        local categories = type(Config.WebhookCategories) == "table" and Config.WebhookCategories or {}
                        for key, record in pairs(current) do
                            local gained = record.amount - (baseline[key] and baseline[key].amount or 0)
                            if gained > 0 and categories[record.category] ~= false then
                                local targetUrl = Runtime.Webhook.ResolveCategoryUrl(record.category)
                                if targetUrl then
                                    local dropCopy = {
                                        id = record.id,
                                        petType = record.petType,
                                        shiny = record.shiny,
                                        category = record.category,
                                        amount = record.amount,
                                    }
                                    task.spawn(function()
                                        if not IsRunning() then return end
                                        local payload = Runtime.Webhook.BuildDropPayload(dropCopy, gained)
                                        local okPost, reason = Runtime.Webhook.PostJson(targetUrl, payload)
                                        if okPost then
                                            Runtime.Stats.WebhookSent = (Runtime.Stats.WebhookSent or 0) + 1
                                            Log("INFO", "Webhook[%s] sent for %s x%d", tostring(dropCopy.category), tostring(dropCopy.id), gained)
                                        else
                                            Log("DEBUG", "Webhook[%s] send failed: %s", tostring(dropCopy.category), tostring(reason))
                                        end
                                    end)
                                end
                            end
                        end
                    end
                end
            else
                previous, previousContainer = nil, nil
            end

            task.wait(math.max(0.5, tonumber(Config.WebhookPollInterval) or 1.0))
        end
    end
end

-- ============================================================================
-- 12D. AUTO MAIL MANAGER (SEND ONLY - WHITELIST + LIVE FEE + TRADABLE GUARD)
-- ============================================================================
Runtime.Mail = Runtime.Mail or {}

function Runtime.Mail.GetDiamonds()
    if Modules.CurrencyCmds and type(Modules.CurrencyCmds.Get) == "function" then
        local ok, amt = pcall(Modules.CurrencyCmds.Get, "Diamonds")
        if ok and type(amt) == "number" then
            return math.max(0, math.floor(amt))
        end
    end
    local invCurrency = Runtime.Helpers.GetSaveInventory("Currency")
    if type(invCurrency) == "table" then
        for _, v in pairs(invCurrency) do
            if type(v) == "table" and v.id == "Diamonds" then
                return math.max(0, math.floor(tonumber(v._am) or 0))
            end
        end
    end
    return 0
end

function Runtime.Mail.ComputeSendCost()
    local feeMult = 1
    if Modules.FFlags and type(Modules.FFlags.Get) == "function" and type(Modules.FFlags.Keys) == "table" then
        local key = Modules.FFlags.Keys.DiamondSink_MailboxFee_Mult
        if key ~= nil then
            local okM, val = pcall(Modules.FFlags.Get, key)
            if okM and type(val) == "number" and val > 0 then
                feeMult = val
            end
        end
    end
    local baseCost = math.floor(((Modules.BalancingConstants and tonumber(Modules.BalancingConstants.MailboxDiamondCost)) or 20000) * feeMult)
    local save = Runtime.Helpers.GetSaveData()
    if not save then return baseCost end

    if (type(save.Gamepasses) == "table" and save.Gamepasses.VIP == true)
        or (LocalPlayer and LocalPlayer:GetAttribute("Partner") == true)
    then
        return baseCost
    end

    local now = Workspace:GetServerTimeNow()
    local resetTime = tonumber(save.MailboxResetTime)
    if not resetTime or resetTime < now then
        return baseCost
    end

    local sends = math.max(0, math.floor(tonumber(save.MailboxSendsSinceReset) or 0))
    local growth = (Modules.MailboxTypes and tonumber(Modules.MailboxTypes.DiamondCostGrowthRate)) or 1.5
    local cap = math.floor(((Modules.MailboxTypes and tonumber(Modules.MailboxTypes.DiamondCostCap)) or 5000000) * feeMult)
    return math.min(math.floor(baseCost * (growth ^ sends)), cap)
end

function Runtime.Mail.ParseAmount(raw)
    if raw == math.huge or raw == true then return math.huge end
    if type(raw) == "string" then
        local lowered = raw:lower():gsub("%s+", "")
        if lowered == "max" or lowered == "all" or lowered == "inf" then
            return math.huge
        end
        local n = tonumber(lowered)
        return (n and n > 0) and math.floor(n) or 0
    end
    if type(raw) == "number" and raw > 0 then
        return (raw == math.huge) and math.huge or math.floor(raw)
    end
    return 0
end

function Runtime.Mail.ExtractRuleSpec(rawVal)
    local specifiedClass = nil
    local rawAmount = rawVal
    local minAmount = 1
    local keepAmount = 0
    if type(rawVal) == "table" then
        specifiedClass = rawVal.Class or rawVal.class or rawVal.Category or rawVal.category
        rawAmount = rawVal.Amount or rawVal.amount or rawVal.Count or rawVal.count or rawVal[1]
        if rawAmount == nil then rawAmount = math.huge end
        minAmount = math.max(1, math.floor(tonumber(rawVal.MinAmount or rawVal.minAmount) or 1))
        keepAmount = math.max(0, math.floor(tonumber(rawVal.Keep or rawVal.keep) or 0))
    end
    local amount = Runtime.Mail.ParseAmount(rawAmount)
    return {
        class = type(specifiedClass) == "string" and specifiedClass ~= "" and specifiedClass or nil,
        amount = amount,
        minAmount = minAmount,
        keep = keepAmount,
    }
end

function Runtime.Mail.GetRecipients()
    local list = {}
    local seen = {}
    local selfLower = LocalPlayer and LocalPlayer.Name and LocalPlayer.Name:lower() or ""

    local function pushName(raw)
        if type(raw) ~= "string" then return end
        local cleaned = raw:gsub("^@", ""):gsub("%s+", "")
        local lower = cleaned:lower()
        if cleaned ~= "" and lower ~= selfLower and not seen[lower] then
            seen[lower] = true
            table.insert(list, cleaned)
        end
    end

    local rawUsers = Config.MailUsernames
    if type(rawUsers) == "table" then
        for _, u in ipairs(rawUsers) do
            pushName(u)
        end
    elseif type(rawUsers) == "string" then
        pushName(rawUsers)
    end
    return list
end

function Runtime.Mail.PickRecipient(recipients)
    if #recipients == 0 then return nil end
    local now = os.clock()
    local cooldowns = Runtime.Cache.MailFailCooldownByKey
    local startIdx = 1
    if Config.MailRoundRobin == true then
        startIdx = ((Runtime.Cache.MailRecipientIdx or 0) % #recipients) + 1
    end
    for offset = 0, #recipients - 1 do
        local idx = ((startIdx - 1 + offset) % #recipients) + 1
        local name = recipients[idx]
        local untilAt = cooldowns["user:" .. name:lower()] or 0
        if now >= untilAt then
            if Config.MailRoundRobin == true then
                Runtime.Cache.MailRecipientIdx = idx
            end
            return name
        end
    end
    return nil
end

function Runtime.Mail.GetProtectedPetSets()
    local daycareUids = {}
    Craft.CollectDaycareUIDs(Modules.DaycareCmds, daycareUids)
    Craft.CollectDaycareUIDs(Modules.ExclusiveDaycareCmds, daycareUids)

    local equippedCounts = {}
    if Config.MailSkipEquippedPets ~= false and Modules.PetCmds and type(Modules.PetCmds.GetEquipped) == "function" then
        local okEq, equipped = pcall(Modules.PetCmds.GetEquipped)
        if okEq and type(equipped) == "table" then
            for _, eq in pairs(equipped) do
                local stackUid = type(eq) == "table" and (eq.uid or eq._uid) or (type(eq) == "string" and eq or nil)
                if type(stackUid) == "string" and stackUid ~= "" then
                    equippedCounts[stackUid] = (equippedCounts[stackUid] or 0) + 1
                end
            end
        end
    end
    return daycareUids, equippedCounts
end

function Runtime.Mail.InspectItem(categoryName, uid, itemData)
    if type(itemData) ~= "table" then
        return false, "invalid_data", categoryName, nil
    end
    local itemId = itemData.id or (type(itemData.data) == "table" and itemData.data.id) or nil
    if type(itemId) ~= "string" or itemId == "" then
        return false, "missing_id", categoryName, nil
    end
    if Config.MailSkipLocked ~= false and itemData._lk == true then
        return false, "locked", categoryName, nil
    end

    local sendClass = categoryName
    local absMod = Modules.AbstractItem
    if absMod and type(absMod.Get) == "function" then
        local okObj, obj = pcall(absMod.Get, absMod, uid)
        if okObj and type(obj) == "table" then
            if type(obj.Class) == "table" and type(obj.Class.Name) == "string" and obj.Class.Name ~= "" then
                sendClass = obj.Class.Name
            end
            if Config.MailSkipLocked ~= false and type(obj.IsLocked) == "function" then
                local okL, isLocked = pcall(obj.IsLocked, obj)
                if okL and isLocked == true then
                    return false, "locked", sendClass, obj
                end
            end
            if type(obj.IsTradable) == "function" then
                local okT, isTradable = pcall(obj.IsTradable, obj)
                if okT and isTradable == false then
                    return false, "untradable", sendClass, obj
                end
            end
            return true, nil, sendClass, obj
        end
    end

    -- Fallback Directory.Tradable check if AbstractItem:Get was unavailable
    if Modules.Directory then
        local dirMap = {
            Lootbox = "Lootboxes",
            Misc = "MiscItems",
            Fruit = "Fruits",
            Potion = "Potions",
            Enchant = "Enchants",
            Pet = "Pets",
            Currency = "Currency",
            Charm = "Charms",
            Egg = "Eggs",
            Hoverboard = "Hoverboards",
            Booth = "Booths",
        }
        local dirKey = dirMap[categoryName]
        local dirTbl = dirKey and Modules.Directory[dirKey] or nil
        local dirEntry = dirTbl and SafeDirLookup(dirTbl, itemId) or nil
        if type(dirEntry) == "table" and dirEntry.Tradable == false then
            return false, "untradable", sendClass, nil
        end
    end
    return true, nil, sendClass, nil
end

function Runtime.Mail.MatchItemRule(categoryName, itemData, mailItems)
    if type(mailItems) ~= "table" then return nil, nil end
    local itemId = itemData.id or (type(itemData.data) == "table" and itemData.data.id) or ""
    if type(itemId) ~= "string" or itemId == "" then return nil, nil end
    local lowerId = itemId:lower()
    local lowerCat = tostring(categoryName):lower()

    -- 1. Exact Name / Class-scoped Rules (never substring match item names; explicit 0/false excludes)
    for rawKey, rawVal in pairs(mailItems) do
        local keyStr = tostring(rawKey)
        local keyClass, keyName = keyStr:match("^([^:]+):(.+)$")
        local spec = Runtime.Mail.ExtractRuleSpec(rawVal)
        local matched = false
        local reason = nil

        if spec.class then
            if lowerCat == spec.class:lower() then
                local targetLower = (keyName or keyStr):lower()
                if targetLower == lowerId
                    or (categoryName == "Currency" and lowerId == "diamonds"
                        and (targetLower == "diamond" or targetLower == "gems"))
                then
                    matched = true
                    reason = string.format("[%s] %s", categoryName, itemId)
                end
            end
        elseif keyClass and keyName then
            if lowerCat == keyClass:lower() then
                local targetLower = keyName:lower()
                if targetLower == lowerId
                    or (categoryName == "Currency" and lowerId == "diamonds"
                        and (targetLower == "diamond" or targetLower == "gems"))
                then
                    matched = true
                    reason = string.format("[%s] %s", categoryName, itemId)
                end
            end
        else
            local lowerKey = keyStr:lower()
            if lowerKey == "diamonds" or lowerKey == "diamond" or lowerKey == "gems" then
                if categoryName == "Currency" and lowerId == "diamonds" then
                    matched = true
                    reason = "Diamonds Currency"
                end
            elseif lowerKey ~= "keys" and lowerKey ~= "key"
                and lowerKey ~= "huge pets" and lowerKey ~= "huge" and lowerKey ~= "huges"
                and lowerKey ~= "titanic pets" and lowerKey ~= "titanic" and lowerKey ~= "titanics"
                and lowerKey ~= "gargantuan pets" and lowerKey ~= "gargantuan" and lowerKey ~= "gargantuans"
                and lowerKey ~= "exclusive pets" and lowerKey ~= "exclusive" and lowerKey ~= "exclusives"
            then
                if lowerKey == lowerId then
                    matched = true
                    reason = string.format("[%s] %s", categoryName, itemId)
                end
            end
        end

        if matched then
            if spec.amount > 0 then
                return spec, reason
            end
            return nil, nil
        end
    end

    -- 2. Pet Category Aliases (Gargantuan, Titanic, Huge, Exclusive)
    if categoryName == "Pet" then
        local petsDir = Modules.Directory and Modules.Directory.Pets or nil
        local pd = petsDir and SafeDirLookup(petsDir, itemId) or nil
        local chaseCat = Runtime.Helpers.GetChaseCategory(itemId, pd)

        local function pickAlias(aliases)
            for _, alias in ipairs(aliases) do
                local rawVal = mailItems[alias]
                if rawVal ~= nil then
                    local spec = Runtime.Mail.ExtractRuleSpec(rawVal)
                    if not spec.class or spec.class:lower() == "pet" then
                        return spec
                    end
                end
            end
            return nil
        end

        if chaseCat == "Gargantuan" then
            local gSpec = pickAlias({ "Gargantuan Pets", "Gargantuan", "Gargantuans" })
            if gSpec then
                return (gSpec.amount > 0) and gSpec or nil, "Gargantuan Pet"
            end
            local tSpec = pickAlias({ "Titanic Pets", "Titanic", "Titanics" })
            if tSpec and tSpec.amount > 0 then
                return tSpec, "Gargantuan Pet"
            end
        elseif chaseCat == "Titanic" then
            local tSpec = pickAlias({ "Titanic Pets", "Titanic", "Titanics" })
            if tSpec and tSpec.amount > 0 then
                return tSpec, "Titanic Pet"
            end
        elseif chaseCat == "Huge" then
            local hSpec = pickAlias({ "Huge Pets", "Huge", "Huges" })
            if hSpec and hSpec.amount > 0 then
                return hSpec, "Huge Pet"
            end
        else
            local isExclusive = (itemData.exclusive == true) or (type(pd) == "table" and pd.exclusive == true)
            if isExclusive then
                local eSpec = pickAlias({ "Exclusive Pets", "Exclusive", "Exclusives" })
                if eSpec and eSpec.amount > 0 then
                    return eSpec, "Exclusive Pet"
                end
            end
        end
    end

    -- 3. Keys Alias
    if (categoryName == "Misc" or categoryName == "Lootbox" or categoryName == "Item") and itemId:find("Key") then
        local rawVal = mailItems["Keys"] or mailItems["Key"]
        if rawVal ~= nil then
            local spec = Runtime.Mail.ExtractRuleSpec(rawVal)
            if spec.amount > 0 and (not spec.class or spec.class:lower() == lowerCat) then
                return spec, "Key Item"
            end
        end
    end

    return nil, nil
end

function Runtime.Mail.BuildSanitizedMessage()
    local raw = tostring(Config.MailMessage or "")
    if raw == "" then return "" end
    -- GUIs.Mailbox L344/L444: ASCII only and max 100 chars
    local clean = raw:gsub("[^\32-\126]", "")
    if #clean > 100 then
        clean = clean:sub(1, 100)
    end
    if not clean:match("%S") then
        return ""
    end
    return clean
end

function Runtime.Mail.NotifyWebhook(recipient, sendClass, itemId, amountSent, fee, reason)
    if Config.MailWebhookEnabled ~= true then return end
    local rawUrl = (type(Config.MailWebhookUrl) == "string" and Config.MailWebhookUrl ~= "")
        and Config.MailWebhookUrl
        or Config.WebhookUrl
    local url = Runtime.Webhook.NormalizeUrl(rawUrl)
    if not url then return end
    local payload = {
        embeds = {
            {
                title = "MAIL SENT",
                description = string.format(
                    "**Recipient:** `@%s`\n**Item:** `[%s] %s` x%s\n**Rule:** %s\n**Fee:** %s Diamonds\n**Account:** ||%s||",
                    tostring(recipient),
                    tostring(sendClass),
                    tostring(itemId),
                    Runtime.Helpers.FormatCommas(amountSent),
                    tostring(reason or sendClass),
                    Runtime.Helpers.FormatCommas(fee),
                    LocalPlayer and LocalPlayer.Name or "Unknown"
                ),
                color = 3447003,
                timestamp = DateTime.now():ToIsoDate(),
            },
        },
        allowed_mentions = { parse = {} },
    }
    task.spawn(function()
        if not IsRunning() then return end
        local okPost, err = Runtime.Webhook.PostJson(url, payload)
        if not okPost then
            Log("DEBUG", "Mail webhook send failed: %s", tostring(err))
        end
    end)
end

function Runtime.Mail.CollectCandidates(save, mailItems)
    local candidates = {}
    if type(save) ~= "table" or type(save.Inventory) ~= "table" or type(mailItems) ~= "table" then
        return candidates
    end

    local now = os.clock()
    local failCooldowns = Runtime.Cache.MailFailCooldownByKey
    local daycareUids, equippedCounts = Runtime.Mail.GetProtectedPetSets()
    local chaseGraceSec = math.max(2.0, (tonumber(Config.WebhookPollInterval) or 1.0) + 1.5)
    local petsDir = Modules.Directory and Modules.Directory.Pets or nil

    -- 1. Non-Currency Inventory Items
    for categoryName, categoryItems in pairs(save.Inventory) do
        if categoryName ~= "Currency" and type(categoryItems) == "table" then
            for uid, itemData in pairs(categoryItems) do
                if type(itemData) == "table" then
                    local spec, reason = Runtime.Mail.MatchItemRule(categoryName, itemData, mailItems)
                    if spec and spec.amount > 0 then
                        local failKey = categoryName .. ":" .. tostring(uid)
                        if now >= (failCooldowns[failKey] or 0) then
                            local okItem, _, sendClass = Runtime.Mail.InspectItem(categoryName, uid, itemData)
                            if okItem then
                                local rawAmount = math.max(1, math.floor(tonumber(itemData._am) or 1))
                                local available = rawAmount
                                local petBlocked = false
                                if categoryName == "Pet" then
                                    if daycareUids[uid] then
                                        petBlocked = true
                                    else
                                        available = math.max(0, rawAmount - (equippedCounts[uid] or 0))
                                    end
                                    -- Let Pet Drop Webhook snapshot newly hatched Chase pets before shipping them out
                                    if not petBlocked and available > 0 then
                                        local pd = petsDir and SafeDirLookup(petsDir, itemData.id) or nil
                                        if Runtime.Helpers.GetChaseCategory(itemData.id, pd) ~= nil then
                                            local seenAt = Runtime.Cache.MailPetFirstSeen[uid]
                                            if not seenAt then
                                                Runtime.Cache.MailPetFirstSeen[uid] = now
                                                petBlocked = true
                                            elseif (now - seenAt) < chaseGraceSec then
                                                petBlocked = true
                                            end
                                        end
                                    end
                                end

                                if not petBlocked and available > 0 then
                                    local sendable = math.max(0, available - spec.keep)
                                    if sendable >= spec.minAmount then
                                        local amountToSend = math.min(sendable, spec.amount)
                                        if amountToSend > 0 then
                                            table.insert(candidates, {
                                                isCurrency = false,
                                                category = categoryName,
                                                sendClass = sendClass,
                                                uid = uid,
                                                id = itemData.id,
                                                amount = amountToSend,
                                                reason = reason,
                                                failKey = failKey,
                                            })
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Diamonds Currency (checked last so items can still pay mail fees first)
    local invCurrency = save.Inventory.Currency
    if type(invCurrency) == "table" then
        for uid, itemData in pairs(invCurrency) do
            if type(itemData) == "table" and itemData.id == "Diamonds" then
                local spec, reason = Runtime.Mail.MatchItemRule("Currency", itemData, mailItems)
                if spec and spec.amount > 0 then
                    local failKey = "Currency:" .. tostring(uid)
                    if now >= (failCooldowns[failKey] or 0) then
                        local okItem, _, sendClass = Runtime.Mail.InspectItem("Currency", uid, itemData)
                        if okItem then
                            table.insert(candidates, {
                                isCurrency = true,
                                category = "Currency",
                                sendClass = sendClass,
                                uid = uid,
                                id = "Diamonds",
                                spec = spec,
                                reason = reason or "Diamonds Currency",
                                failKey = failKey,
                            })
                        end
                    end
                end
                break
            end
        end
    end

    return candidates
end

function Runtime.Mail.StepSend()
    if Config.AutoMail ~= true then return 0 end
    if not (Modules.Network and type(Modules.Network.Invoke) == "function") then return 0 end

    local mailItems = Config.MailItems
    if type(mailItems) ~= "table" or next(mailItems) == nil then return 0 end

    local recipients = Runtime.Mail.GetRecipients()
    if #recipients == 0 then
        local now = os.clock()
        if (now - (Runtime.Cache.MailLastNoRecipientLogAt or 0)) >= 60 then
            Runtime.Cache.MailLastNoRecipientLogAt = now
            Log("INFO", "AutoMail active but MailUsernames has no valid recipient.")
        end
        return 0
    end

    local save = Runtime.Helpers.GetSaveData()
    if not save then return 0 end

    local candidates = Runtime.Mail.CollectCandidates(save, mailItems)
    if #candidates == 0 then return 0 end

    local maxFee = math.max(0, math.floor(tonumber(Config.MailMaxFee) or 0))
    local reserve = math.max(0, math.floor(tonumber(Config.MailMinDiamondsReserve) or 100000))
    local sendDelay = math.max(0.5, tonumber(Config.MailSendDelay) or 2.2)
    local sentCount = 0

    for _, cand in ipairs(candidates) do
        if not IsRunning() or Config.AutoMail ~= true then break end

        local recipient = Runtime.Mail.PickRecipient(recipients)
        if not recipient then break end

        local fee = Runtime.Mail.ComputeSendCost()
        Runtime.Stats.MailLastFee = fee

        if maxFee > 0 and fee > maxFee then
            local now = os.clock()
            if (now - (Runtime.Cache.MailLastSkipLogAt or 0)) >= 60 then
                Runtime.Cache.MailLastSkipLogAt = now
                Log("INFO", "AutoMail paused: current fee %s exceeds MailMaxFee %s.",
                    Runtime.Helpers.FormatCommas(fee), Runtime.Helpers.FormatCommas(maxFee))
            end
            break
        end

        local curDiamonds = Runtime.Mail.GetDiamonds()
        local amountToSend = cand.amount or 0
        if cand.isCurrency then
            local keepTotal = math.max(reserve, cand.spec.keep or 0)
            local maxSendable = math.max(0, curDiamonds - keepTotal - fee)
            local minThreshold = math.max(10000, cand.spec.minAmount or 1)
            if maxSendable < minThreshold then
                amountToSend = 0
            else
                amountToSend = math.min(maxSendable, cand.spec.amount)
                if amountToSend < 10000 then
                    amountToSend = 0
                end
            end
        else
            if curDiamonds < fee then
                local now = os.clock()
                if (now - (Runtime.Cache.MailLastSkipLogAt or 0)) >= 60 then
                    Runtime.Cache.MailLastSkipLogAt = now
                    Log("INFO", "AutoMail paused: need %s Diamonds for fee, have %s.",
                        Runtime.Helpers.FormatCommas(fee), Runtime.Helpers.FormatCommas(curDiamonds))
                end
                break
            end
        end

        if amountToSend > 0 then
            local msg = Runtime.Mail.BuildSanitizedMessage()
            if msg ~= "" and Workspace:GetServerTimeNow() < (Runtime.Cache.MailMessageCooldownUntil or 0) then
                -- Avoid hitting server 60s message cooldown when user configured a non-empty message
                msg = ""
            end

            local okInvoke, okSent, errMsg = pcall(
                Modules.Network.Invoke,
                "EF_Relay",
                recipient,
                msg,
                cand.sendClass,
                cand.uid,
                amountToSend
            )

            if okInvoke and okSent == true then
                sentCount = sentCount + 1
                Runtime.Stats.MailSentCount = (Runtime.Stats.MailSentCount or 0) + 1
                Runtime.Cache.MailFailCooldownByKey[cand.failKey] = nil
                Runtime.Cache.MailPetFirstSeen[cand.uid] = nil
                Runtime.Cache.MailInvDirty = true
                if msg ~= "" then
                    Runtime.Cache.MailMessageCooldownUntil = Workspace:GetServerTimeNow() + 60
                end
                Log("INFO", "Mail sent: [%s] %s x%s -> @%s (fee=%s)",
                    tostring(cand.sendClass),
                    tostring(cand.id),
                    Runtime.Helpers.FormatCommas(amountToSend),
                    tostring(recipient),
                    Runtime.Helpers.FormatCommas(fee))
                Runtime.Mail.NotifyWebhook(recipient, cand.sendClass, cand.id, amountToSend, fee, cand.reason)
                task.wait(sendDelay)
            else
                Runtime.Stats.MailFailedCount = (Runtime.Stats.MailFailedCount or 0) + 1
                local errText = tostring((not okInvoke and okSent) or errMsg or "unknown_error")
                local cdSec = tonumber(errText:match("^Please wait (%d+) seconds"))
                if cdSec then
                    Runtime.Cache.MailMessageCooldownUntil = Workspace:GetServerTimeNow() + cdSec
                end
                Runtime.Cache.MailFailCooldownByKey[cand.failKey] = os.clock() + 60
                local errLower = errText:lower()
                if errLower:find("not found") or errLower:find("disabled") or errLower:find("does not exist")
                    or errLower:find("doesn't exist") or errLower:find("friends only") or errLower:find("full")
                then
                    Runtime.Cache.MailFailCooldownByKey["user:" .. recipient:lower()] = os.clock() + 60
                end
                Log("DEBUG", "Mail send failed [%s] %s x%s -> @%s: %s",
                    tostring(cand.sendClass),
                    tostring(cand.id),
                    Runtime.Helpers.FormatCommas(amountToSend),
                    tostring(recipient),
                    errText)
                task.wait(1.0)
            end
        end
    end

    return sentCount
end

function Runtime.Mail.RunLoop()
    Log("INFO", "Auto mail sender loop started (AutoMail=%s).", tostring(Config.AutoMail == true))
    while IsRunning() do
        if Config.AutoMail == true then
            local ok, res = pcall(Runtime.Mail.StepSend)
            if not ok then
                Log("DEBUG", "Auto mail loop error: %s", tostring(res))
            end
        end
        task.wait(math.max(1.0, tonumber(Config.MailScanInterval) or 10.0))
    end
end


-- ============================================================================
-- 13. DUCKK CONCURRENT ORCHESTRATOR & ENTRYPOINT
-- ============================================================================
function Runtime.Helpers.RunManagerTick()
    local plot = DuckkEvent.Onboarding.EnsurePlot()
    if not plot then return false end

    DuckkEvent.Onboarding.StepTutorial(plot)
    local buttons, tycoonComplete, claimedComplete = DuckkEvent.Dag.Step(plot)

    local fightingBoss = (Runtime.Stats.FightingTurkeyBoss == true)
    Runtime.Stats.Phase = fightingBoss
        and string.format("Turkey Boss (%.1f%%)", (tonumber(Runtime.Stats.TurkeyBossShare) or 0) * 100)
        or (tycoonComplete
            and (claimedComplete and "Endgame Overlap Hatch & Farm" or "Claiming Tycoon")
            or string.format("DAG Rush (%d/%d)", Runtime.Stats.ButtonsDone, Runtime.Stats.ButtonsTotal))

    DuckkEvent.Pedestals.Step(plot, buttons, tycoonComplete)
    DuckkEvent.Tokens.Step(plot, buttons, tycoonComplete)
    DuckkEvent.Boosts.StepConsumables(plot)
    Runtime.Helpers.StepConsumeFruits()
    Runtime.Helpers.UpdateCoinRateSampler()

    if not fightingBoss then
        DuckkEvent.Boosts.StepCocoa(plot, buttons, tycoonComplete)
    end

    StepPetSpeedBuff()
    StepMapOptimizer(plot)
    DuckkEvent.Boosts.StepFlannelGifts()
    StepAutoOpenItems()
    StepConsumePotions()
    StepEquipEnchants()

    if not fightingBoss then
        DuckkEvent.Wild.StepNetStore(plot, buttons, tycoonComplete)
    end
    if not DuckkEvent.Wild.StepSighting(plot) and not fightingBoss then
        DuckkEvent.Wild.StepHunt(plot, buttons, tycoonComplete)
    else
        Runtime.Cache.WildRerollActive = false
    end
    if Runtime.Cache.WildRerollActive and not fightingBoss then
        Runtime.Stats.Phase = string.format("Wild Huge Reroll Z%d", math.clamp(math.floor(tonumber(Config.HuntRerollZone) or 1), 1, 8))
    end
    if not fightingBoss then
        DuckkEvent.Fusion.Step(plot, buttons)
    end
    DuckkEvent.Boosts.StepEventPass()
    return true
end

function Runtime.Helpers.StepFarmLoopTick()
    if IsInEventInstance() then
        local plot = GetMyPlot()
        if plot then
            DuckkEvent.Combat.StepFarmTargeter(plot)
        end
    end
end

local function StartDuckkLoops()
    Runtime.Helpers.EnsureOrbsCreateHook()
    Runtime.Helpers.EnsureItemsUpdateHook()
    Runtime.Helpers.EnsureSightingHook()

    -- Worker 1: Event State Machine & Economy Manager
    task.spawn(function()
        while IsRunning() do
            local ok, res = pcall(Runtime.Helpers.RunManagerTick)
            task.wait((ok and res == false) and 0.50 or 0.20)
        end
    end)

    -- Worker 2: Breakable Targeter, Turkey Arena & Multi-Pet Spread
    task.spawn(function()
        local lastScan = 0
        while IsRunning() do
            local now = os.clock()
            local dead = (activeFarmTarget == nil) or (not activeFarmTarget.model) or (not activeFarmTarget.model.Parent)
            local interval = Config.FarmLoopInterval or 0.10
            if dead or (now - lastScan) >= interval then
                lastScan = now
                pcall(Runtime.Helpers.StepFarmLoopTick)
            end
            task.wait(Config.UltraLowRAM and 0.06 or 0.03)
        end
    end)

    -- Worker 3: 15Hz Unreliable Tap Engine
    task.spawn(function()
        while IsRunning() do
            pcall(StepRapidTap)
            task.wait(tonumber(Config.TapInterval) or 0.065)
        end
    end)

    -- Worker 4: Sparse Orbs & Lootbags Sweeper
    task.spawn(function()
        while IsRunning() do
            pcall(SweepDrops)
            task.wait(tonumber(Config.OrbSweepInterval) or 0.50)
        end
    end)

    -- Worker 5: Overlap Zone 8 Egg Hatcher & Early Power Bootstrap
    task.spawn(function()
        while IsRunning() do
            local plot = IsInEventInstance() and GetMyPlot() or nil
            if plot then
                local buttons = Runtime.Cache.Buttons
                local tycoonComplete = Runtime.Stats.TycoonComplete
                if buttons == nil or (os.clock() - (Runtime.Cache.ButtonsAt or 0) > 0.5) then
                    buttons, tycoonComplete = GetProgressState(plot)
                end
                pcall(StepHatch, plot, buttons, tycoonComplete)
                Runtime.Cache.HatchInFlight = false
            else
                Runtime.Stats.IsHatching = false
                Runtime.Cache.HatchInFlight = false
            end
            task.wait(Runtime.Stats.IsHatching and (Config.HatchCooldown or 0.02) or 0.25)
        end
    end)

    -- Worker 6: 3-Tier Discord Drop Webhook Watcher
    task.spawn(Runtime.Webhook.RunLoop)

    -- Worker 7: Auto Mail Sender
    task.spawn(Runtime.Mail.RunLoop)
end

if WaitReady() and IsRunning() then
    SetupAntiAfk()
    DisableNativeAutoFarmOnce()
    StepPetSpeedBuff()
    Runtime.Helpers.EnsureOrbsCreateHook()
    Runtime.Helpers.EnsureItemsUpdateHook()
    Runtime.Helpers.EnsureSightingHook()
    InitKaitunDashboard()
    if Config.ShowKaitunUI == false then
        Set3dRenderingSafe(true)
    end
    SetupMapOptimizer()
    Log("INFO", "[DuckkKaitun] Initialized custom Duckk Event Engine (TargetRebirths=%d, AutoTurkey=%s, AutoHunt=%s, AutoNetStore=%s, FPSCap=%s).",
        math.floor(tonumber(Config.TargetRebirths) or 0),
        tostring(Config.AutoTurkeyBoss),
        tostring(Config.AutoHuntWild),
        tostring(Config.AutoBuyNetStore),
        tostring(Runtime.Cache.ActiveFpsCap or "uncapped")
    )
    StartDuckkLoops()
end

