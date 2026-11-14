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

local rng = Random.new()
local cachedUid = nil
local cachedCategory = nil

local PresentCmds = nil
local LootboxCmds = nil
pcall(function() PresentCmds = require(clientFolder:FindFirstChild("PresentCmds")) end)
pcall(function() LootboxCmds = require(clientFolder:FindFirstChild("LootboxCmds")) end)

-- 1. Tìm UID và số lượng của Midnight Gift trong túi
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

-- 2. In thông tin hàm của PresentCmds & LootboxCmds và các Remote liên quan
local function printModuleDetails()
    print("=== [AutoGift v6] KIỂM TRA PRESENTCMDS & REMOTES ===")
    for _, rem in ipairs(network:GetChildren()) do
        local nl = string.lower(rem.Name)
        if string.find(nl, "kx") or string.find(nl, "present") or string.find(nl, "lootbox") or string.find(nl, "giftbag") then
            print(string.format("  [Remote] '%s' (%s)", rem.Name, rem.ClassName))
        end
    end

    if PresentCmds and type(PresentCmds) == "table" then
        for k, fn in pairs(PresentCmds) do
            if type(fn) == "function" then
                local line, nparams, isvar = "?", "?", "?"
                pcall(function()
                    line, nparams, isvar = debug.info(fn, "la")
                end)
                local constStr = ""
                if debug and debug.getconstants then
                    local okC, cs = pcall(debug.getconstants, fn)
                    if okC and type(cs) == "table" then
                        local arr = {}
                        for _, c in pairs(cs) do
                            if type(c) == "string" or type(c) == "number" then
                                table.insert(arr, tostring(c))
                            end
                        end
                        constStr = " | Consts: " .. table.concat(arr, ", ")
                    end
                end
                print(string.format("  [PresentCmds.%s] Line:%s Params:%s%s", tostring(k), tostring(line), tostring(nparams), constStr))
            end
        end
    end

    if LootboxCmds and type(LootboxCmds) == "table" then
        for k, fn in pairs(LootboxCmds) do
            if type(fn) == "function" then
                local line, nparams = "?", "?"
                pcall(function()
                    line, nparams = debug.info(fn, "la")
                end)
                local constStr = ""
                if debug and debug.getconstants then
                    local okC, cs = pcall(debug.getconstants, fn)
                    if okC and type(cs) == "table" then
                        local arr = {}
                        for _, c in pairs(cs) do
                            if type(c) == "string" or type(c) == "number" then
                                table.insert(arr, tostring(c))
                            end
                        end
                        constStr = " | Consts: " .. table.concat(arr, ", ")
                    end
                end
                print(string.format("  [LootboxCmds.%s] Line:%s Params:%s%s", tostring(k), tostring(line), tostring(nparams), constStr))
            end
        end
    end
    print("====================================================")
end

-- 3. Tạo danh sách tọa độ mặt đất quanh nhân vật
local function getDropVectors(count)
    -- Ưu tiên dùng hàm tính tọa độ mặt đất chuẩn của game nếu có
    if PresentCmds and type(PresentCmds.Ground) == "function" then
        local ok, res = pcall(PresentCmds.Ground, count)
        if ok and type(res) == "table" and #res == count and typeof(res[1]) == "Vector3" then
            return res
        end
    end

    local positions = table.create(count)
    local character = localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local centerPos = rootPart and rootPart.Position or Vector3.new(152.0, 14.0, -210.0)

    local rayParams = RaycastParams.new()
    if character then
        rayParams.FilterDescendantsInstances = { character }
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
    end

    for i = 1, count do
        local offsetX = rng:NextNumber(-5, 5)
        local offsetZ = rng:NextNumber(-5, 5)
        local rayResult = Workspace:Raycast(centerPos + Vector3.new(offsetX, 10, offsetZ), Vector3.new(0, -50, 0), rayParams)
        if rayResult then
            positions[i] = rayResult.Position
        else
            positions[i] = centerPos + Vector3.new(offsetX, -3, offsetZ)
        end
    end

    return positions
end

-- ================= KHỞI CHẠY =================
task.spawn(function()
    local initialUid, initialAmount, initialCat = getGiftInfo(targetGiftName)
    print(string.format(
        "[AutoGift v6] Phiên #%d | Quà: '%s' [%s] | UID: %s | Số lượng: %d",
        currentSession, targetGiftName, tostring(initialCat), tostring(initialUid), initialAmount
    ))

    printModuleDetails()

    local openGiftRemote = network:FindFirstChild("KX_Release")

    while _G.AutoOpenGift and (_G.AutoGiftSession == currentSession) do
        local giftUid, currentAmount = getGiftInfo(targetGiftName)

        if not giftUid or currentAmount <= 0 then
            print("[AutoGift v6] ĐÃ MỞ HẾT SẠCH QUÀ TRONG TÚI!")
            break
        end

        local amountToOpen = math.min(maxAmountPerOpen, currentAmount)
        local vectors = getDropVectors(amountToOpen)

        -- Bước 1: Kích nổ các hộp quà đang nằm sẵn trên đất (nếu có)
        if PresentCmds and type(PresentCmds.OpenCurrent) == "function" then
            pcall(PresentCmds.OpenCurrent)
        end

        -- Bước 2: Gửi trực tiếp KX_Release lên Server để thả 8 hộp quà mới
        if openGiftRemote then
            local ok, res1, res2 = pcall(function()
                return openGiftRemote:InvokeServer(giftUid, amountToOpen, vectors)
            end)
            if not ok or res1 == false then
                warn(string.format("[AutoGift v6] KX_Release trả về: %s | %s", tostring(res1), tostring(res2)))
            else
                print(string.format("🎁 [AutoGift v6] Đã thả %d hộp xuống đất! Đang tự động kích nổ...", amountToOpen))
            end
        end

        -- Bước 3: Đợi 0.5s rồi gọi OpenCurrent() để tự động Click kích nổ 8 hộp vừa thả
        task.wait(0.5)
        if PresentCmds and type(PresentCmds.OpenCurrent) == "function" then
            pcall(PresentCmds.OpenCurrent)
        end

        task.wait(delayTime)

        local _, afterAmount = getGiftInfo(targetGiftName)
        if afterAmount < currentAmount then
            print(string.format("✅ [AutoGift v6] Mở thành công! Đã giảm %d hộp -> Còn lại: %d", currentAmount - afterAmount, afterAmount))
        end
    end
end)
