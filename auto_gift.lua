local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("Network")
local library = ReplicatedStorage:WaitForChild("Library")
local clientFolder = library:WaitForChild("Client")
local Save = require(clientFolder:WaitForChild("Save"))

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

-- 1. Tìm UID và số lượng thực tế của Midnight Gift
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

-- 2. In ngắn gọn Constants & Protos của PresentCmds.OpenCurrent, Drop, Current và LootboxCmds.Open
local function dumpFuncInfo(label, fn)
    if type(fn) ~= "function" then return end
    local line, nparams = "?", "?"
    pcall(function() line, nparams = debug.info(fn, "la") end)
    local constsList = {}
    if debug and debug.getconstants then
        local ok, cs = pcall(debug.getconstants, fn)
        if ok and type(cs) == "table" then
            for _, c in pairs(cs) do
                if type(c) == "string" or type(c) == "number" then
                    table.insert(constsList, tostring(c))
                end
            end
        end
    end
    print(string.format("  [%s] L:%s P:%s | Consts: %s", label, tostring(line), tostring(nparams), table.concat(constsList, ", ")))

    -- In thêm các hàm con (protos) bên trong nếu có
    if debug and debug.getprotos then
        local okP, protos = pcall(debug.getprotos, fn)
        if okP and type(protos) == "table" then
            for idx, p in ipairs(protos) do
                local pConsts = {}
                local okPC, pcs = pcall(debug.getconstants, p)
                if okPC and type(pcs) == "table" then
                    for _, c in pairs(pcs) do
                        if type(c) == "string" or type(c) == "number" then
                            table.insert(pConsts, tostring(c))
                        end
                    end
                end
                print(string.format("    -> Proto#%d Consts: %s", idx, table.concat(pConsts, ", ")))
            end
        end
    end
end

-- 3. Tạo đối tượng Item chuẩn cho hàm LootboxCmds.Open(item, amount)
local function makeItemObject(uid, giftName)
    -- Thử tạo qua thư viện Items của game trước (nếu có)
    local itemsFolder = library:FindFirstChild("Items")
    if itemsFolder then
        local lootboxItemMod = itemsFolder:FindFirstChild("LootboxItem")
        if lootboxItemMod then
            local ok, LItem = pcall(require, lootboxItemMod)
            if ok and type(LItem) == "function" then
                local ok2, obj = pcall(LItem, giftName)
                if ok2 and type(obj) == "table" then
                    obj._uid = uid
                    return obj
                end
            end
        end
    end

    -- Tạo đối tượng giả lập có đầy đủ hàm GetId() và GetUID() như LootboxCmds.Open yêu cầu
    local fakeItem = {
        _uid = uid,
        _id = giftName,
        id = giftName,
        uid = uid,
        GetId = function() return giftName end,
        GetUID = function() return uid end,
    }
    return setmetatable(fakeItem, {
        __index = function(_, k)
            warn("[AutoGift v7] LootboxCmds.Open gọi thêm thuộc tính: " .. tostring(k))
            return function() return nil end
        end
    })
end

-- ================= KHỞI CHẠY =================
task.spawn(function()
    local initialUid, initialAmount, initialCat = getGiftInfo(targetGiftName)
    print(string.format(
        "=== [AutoGift v7] Quà: '%s' [%s] | UID: %s | Số lượng: %d ===",
        targetGiftName, tostring(initialCat), tostring(initialUid), initialAmount
    ))

    dumpFuncInfo("PresentCmds.OpenCurrent", PresentCmds.OpenCurrent)
    dumpFuncInfo("PresentCmds.Drop", PresentCmds.Drop)
    dumpFuncInfo("PresentCmds.Current", PresentCmds.Current)
    dumpFuncInfo("LootboxCmds.Open", LootboxCmds.Open)

    while _G.AutoOpenGift and (_G.AutoGiftSession == currentSession) do
        local giftUid, currentAmount = getGiftInfo(targetGiftName)

        if not giftUid or currentAmount <= 0 then
            print("[AutoGift v7] ĐÃ MỞ HẾT SẠCH QUÀ TRONG TÚI!")
            break
        end

        local amountToOpen = math.min(maxAmountPerOpen, currentAmount)
        local itemObj = makeItemObject(giftUid, targetGiftName)

        -- Bước 1: Kích nổ các hộp quà đang nằm sẵn trên đất (nếu có)
        if type(PresentCmds.OpenCurrent) == "function" then
            pcall(PresentCmds.OpenCurrent)
        end

        -- Bước 2: Gọi trực tiếp hàm LootboxCmds.Open chính chủ của game!
        -- Hàm này tự động chạy ComputePositions() và gọi KX_Release với tham số chuẩn 100%
        local okOpen, resOpen, errOpen = pcall(LootboxCmds.Open, itemObj, amountToOpen)
        print(string.format("[AutoGift v7] Gọi LootboxCmds.Open(%d) -> ok=%s, res=%s, err=%s", amountToOpen, tostring(okOpen), tostring(resOpen), tostring(errOpen)))

        -- Bước 3: Đợi hộp quà chạm đất rồi tự động kích nổ luôn (OpenCurrent)
        task.wait(0.6)
        if type(PresentCmds.OpenCurrent) == "function" then
            local okPop, resPop = pcall(PresentCmds.OpenCurrent)
            print(string.format("[AutoGift v7] Gọi PresentCmds.OpenCurrent() -> ok=%s, res=%s", tostring(okPop), tostring(resPop)))
        end

        -- Xóa trạng thái hộp quà cũ trên mặt đất để không bị báo 'Not enough space' ở đợt sau
        if type(PresentCmds.Current) == "function" then
            pcall(function()
                local cur = PresentCmds.Current()
                if type(cur) == "table" then
                    for _, p in pairs(cur) do
                        if type(p) == "table" then
                            p._destroyed = true
                        end
                    end
                end
            end)
        end

        task.wait(delayTime)

        local _, afterAmount = getGiftInfo(targetGiftName)
        if afterAmount < currentAmount then
            print(string.format("✅ [AutoGift v7] MỞ THÀNH CÔNG %d HỘP! Còn lại: %d", currentAmount - afterAmount, afterAmount))
        end
    end
end)
