local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("Network")
local library = ReplicatedStorage:WaitForChild("Library")
local clientFolder = library:WaitForChild("Client")
local Save = require(clientFolder:WaitForChild("Save"))
local Directory = require(library:WaitForChild("Directory"))

-- ================= CẤU HÌNH =================
_G.AutoOpenGift = true
_G.HideGiftGui = true
_G.ClearLagEffects = true

local targetGiftName = _G.TargetGiftName or "Midnight Gift"
local maxAmountPerOpen = _G.MaxAmountPerOpen or 8
local delayTime = _G.DelayTime or 1.5
-- ============================================

_G.AutoGiftSession = (_G.AutoGiftSession or 0) + 1
local currentSession = _G.AutoGiftSession

local cachedUid = nil
local cachedCategory = nil

local PresentCmds = require(clientFolder:WaitForChild("PresentCmds"))
local LootboxCmds = require(clientFolder:WaitForChild("LootboxCmds"))

-- 1. Tìm dữ liệu gốc (Directory) của Midnight Gift trong game
local function findItemDirectory(giftName)
    local targetLower = string.lower(giftName)
    if type(Directory) == "table" then
        -- Quét ưu tiên trong Directory.Lootboxes trước
        if type(Directory.Lootboxes) == "table" then
            for id, data in pairs(Directory.Lootboxes) do
                if string.lower(tostring(id)) == targetLower then
                    return data
                end
            end
        end
        -- Quét toàn bộ các nhánh trong Directory
        for _, subDir in pairs(Directory) do
            if type(subDir) == "table" then
                for id, data in pairs(subDir) do
                    if string.lower(tostring(id)) == targetLower and type(data) == "table" then
                        return data
                    end
                end
            end
        end
    end
    return {
        _id = giftName,
        Instant = false,
        IsCardPack = false,
    }
end

local cachedDirData = findItemDirectory(targetGiftName)

-- 2. Tìm UID và số lượng thực tế của Midnight Gift trong túi đồ
local function getGiftInfo(giftName)
    local saveData = Save.Get()
    if not saveData or not saveData.Inventory then
        return nil, 0, nil
    end

    if cachedCategory and cachedUid then
        local categoryTable = saveData.Inventory[cachedCategory]
        local itemData = categoryTable and categoryTable[cachedUid]
        if itemData then
            return cachedUid, (itemData._am or 1), cachedCategory
        else
            cachedUid, cachedCategory = nil, nil
        end
    end

    local targetLower = string.lower(giftName)
    for categoryName, categoryItems in pairs(saveData.Inventory) do
        if type(categoryItems) == "table" then
            for uid, itemData in pairs(categoryItems) do
                if type(itemData) == "table" and itemData.id and string.lower(tostring(itemData.id)) == targetLower then
                    cachedUid = uid
                    cachedCategory = categoryName
                    return uid, (itemData._am or 1), categoryName
                end
            end
        end
    end

    return nil, 0, nil
end

-- 3. Tạo đối tượng Item đầy đủ GetId(), GetUID(), Directory() cho LootboxCmds.Open
local function makeItemObject(uid, giftName)
    local fakeItem = {
        _uid = uid,
        _id = giftName,
        id = giftName,
        uid = uid,
        _data = { id = giftName, _am = 8 },
        GetId = function() return giftName end,
        GetUID = function() return uid end,
        Directory = function() return cachedDirData end,
        GetDirectory = function() return cachedDirData end,
    }
    return setmetatable(fakeItem, {
        __index = function(_, k)
            warn("[AutoGift v8] LootboxCmds.Open gọi thêm thuộc tính: " .. tostring(k))
            return function() return cachedDirData end
        end
    })
end

-- 4. Ẩn GUI và hiệu ứng nổ để không lag/crash khi mở 900+ hộp
local function cleanElementLag(obj)
    if not _G.ClearLagEffects then return end
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Sparkles") or obj:IsA("Smoke") then
        obj.Enabled = false
    elseif obj:IsA("Explosion") then
        obj.Visible = false
    elseif obj:IsA("Sound") then
        obj.Volume = 0
    end
end

-- ================= KHỞI CHẠY =================
task.spawn(function()
    local connections = {}
    local thingsFolder = Workspace:FindFirstChild("__THINGS") or Workspace
    table.insert(connections, thingsFolder.DescendantAdded:Connect(cleanElementLag))

    local initialUid, initialAmount, initialCat = getGiftInfo(targetGiftName)
    print(string.format(
        "=== [AutoGift v8] Quà: '%s' [%s] | UID: %s | Số lượng: %d | DirFound: %s ===",
        targetGiftName, tostring(initialCat), tostring(initialUid), initialAmount, tostring(cachedDirData ~= nil)
    ))

    while _G.AutoOpenGift and (_G.AutoGiftSession == currentSession) do
        local giftUid, currentAmount = getGiftInfo(targetGiftName)

        if not giftUid or currentAmount <= 0 then
            print("🎉 [AutoGift v8] HOÀN TẤT! ĐÃ MỞ HẾT SẠCH QUÀ TRONG TÚI!")
            break
        end

        local amountToOpen = math.min(maxAmountPerOpen, currentAmount)
        local itemObj = makeItemObject(giftUid, targetGiftName)

        -- Bước 1: Kích nổ các hộp quà đang nằm sẵn trên đất (nếu có)
        if type(PresentCmds.OpenCurrent) == "function" then
            pcall(PresentCmds.OpenCurrent)
        end

        -- Bước 2: Gọi LootboxCmds.Open(itemObj, amountToOpen) để thả 8 hộp quà xuống đất
        local okOpen, resOpen, errOpen = pcall(LootboxCmds.Open, itemObj, amountToOpen)
        print(string.format("[AutoGift v8] LootboxCmds.Open(%d) -> ok=%s, res=%s, err=%s", amountToOpen, tostring(okOpen), tostring(resOpen), tostring(errOpen)))

        -- Bước 3: Chờ hộp quà rơi xuống đất rồi gọi PresentCmds.OpenCurrent() để tự Click kích nổ!
        task.wait(0.8)
        if type(PresentCmds.OpenCurrent) == "function" then
            local okPop, resPop = pcall(PresentCmds.OpenCurrent)
            print(string.format("[AutoGift v8] PresentCmds.OpenCurrent() -> ok=%s, res=%s", tostring(okPop), tostring(resPop)))
        end

        -- Giải phóng danh sách hộp quà trên mặt đất để lượt tiếp theo luôn có chỗ trống
        if type(PresentCmds.Current) == "function" then
            pcall(function()
                local cur = PresentCmds.Current()
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

        task.wait(delayTime)

        local _, afterAmount = getGiftInfo(targetGiftName)
        if afterAmount < currentAmount then
            print(string.format("✅ [AutoGift v8] ĐÃ MỞ THÀNH CÔNG %d HỘP! Trong túi còn: %d", currentAmount - afterAmount, afterAmount))
        end
    end

    for _, conn in ipairs(connections) do
        if conn.Connected then conn:Disconnect() end
    end
end)
