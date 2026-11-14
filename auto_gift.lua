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

-- 2. Giải mã chi tiết PresentCmds và LootboxCmds để lấy đúng quy trình mở liên tục
local function inspectPresentAndLootboxModules()
    print("=== [AutoGift v5] PHÂN TÍCH PRESENTCMDS & LOOTBOXCMDS ===")

    -- In tất cả Remote có chữ KX, Present, Gift, Lootbox
    for _, rem in ipairs(network:GetChildren()) do
        local nl = string.lower(rem.Name)
        if string.find(nl, "kx") or string.find(nl, "present") or string.find(nl, "gift") or string.find(nl, "lootbox") then
            print(string.format("  [Remote] '%s' (%s)", rem.Name, rem.ClassName))
        end
    end

    -- Thử decompile nếu công cụ hỗ trợ
    if decompile then
        local pMod = clientFolder:FindFirstChild("PresentCmds")
        if pMod then
            local ok, src = pcall(decompile, pMod)
            if ok and type(src) == "string" and #src > 0 then
                print("--- MÃ NGUỒN PRESENTCMDS ---")
                for line in string.gmatch(src, "[^\r\n]+") do
                    if string.find(line, "Network") or string.find(line, "Invoke") or string.find(line, "Fire") or string.find(line, "function") or string.find(line, "KX") or string.find(line, "Open") or string.find(line, "Drop") then
                        print("  " .. line)
                    end
                end
            end
        end
    end

    -- Đọc Constants & Upvalues của PresentCmds
    if PresentCmds and type(PresentCmds) == "table" then
        for funcName, fn in pairs(PresentCmds) do
            if type(fn) == "function" then
                local infoStr = "  [PresentCmds." .. tostring(funcName) .. "]"
                if debug and debug.getconstants then
                    local okC, consts = pcall(debug.getconstants, fn)
                    if okC and type(consts) == "table" then
                        local list = {}
                        for _, c in pairs(consts) do
                            if type(c) == "string" or type(c) == "number" then
                                table.insert(list, tostring(c))
                            end
                        end
                        infoStr = infoStr .. " Constants: " .. table.concat(list, ", ")
                    end
                end
                print(infoStr)
            end
        end
    end

    -- Đọc Constants của LootboxCmds
    if LootboxCmds and type(LootboxCmds) == "table" then
        for funcName, fn in pairs(LootboxCmds) do
            if type(fn) == "function" then
                local infoStr = "  [LootboxCmds." .. tostring(funcName) .. "]"
                if debug and debug.getconstants then
                    local okC, consts = pcall(debug.getconstants, fn)
                    if okC and type(consts) == "table" then
                        local list = {}
                        for _, c in pairs(consts) do
                            if type(c) == "string" or type(c) == "number" then
                                table.insert(list, tostring(c))
                            end
                        end
                        infoStr = infoStr .. " Constants: " .. table.concat(list, ", ")
                    end
                end
                print(infoStr)
            end
        end
    end

    -- Gắn bộ theo dõi mọi lệnh gọi từ PresentCmds khi bạn mở quà
    if hookmetamethod and getnamecallmethod then
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if (method == "InvokeServer" or method == "FireServer") and self.Parent == network then
                    local nameL = string.lower(self.Name)
                    if not string.find(nameL, "idle") and not string.find(nameL, "click") and not string.find(nameL, "orb") and not string.find(nameL, "breakable") and not string.find(nameL, "pet") and not string.find(nameL, "ping") then
                        local args = { ... }
                        local argSummary = {}
                        for i, a in ipairs(args) do
                            table.insert(argSummary, string.format("[%d]=%s(%s)", i, tostring(a), typeof(a)))
                        end
                        warn(string.format("🔥 [BẮT GÓI TIN] Remote: '%s' (%s) | Args: %s", self.Name, method, table.concat(argSummary, ", ")))
                    end
                end
                return oldNamecall(self, ...)
            end)
        end)
    end

    print("=== [AutoGift v5] HOÀN TẤT PHÂN TÍCH ===")
end

-- 3. Tạo tọa độ chuẩn bằng chính hàm PresentCmds.Ground của game (nếu có) hoặc Raycast
local function getDropVectors(count)
    -- Thử dùng hàm tính mặt đất chính chủ của PresentCmds
    if PresentCmds and type(PresentCmds.Ground) == "function" then
        local ok, res = pcall(PresentCmds.Ground, count)
        if ok and type(res) == "table" and #res == count and typeof(res[1]) == "Vector3" then
            return res
        end
    end

    local positions = table.create(count)
    local character = localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local centerPos = rootPart and rootPart.Position or Vector3.new(152.0, 16.5, -210.0)

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

-- 4. Vô hiệu hóa hiệu ứng rơi mô hình quà (Ẩn GUI / 3D Model)
local function disableDropAnimation()
    if not _G.HideGiftGui then return end
    if PresentCmds and type(PresentCmds) == "table" then
        pcall(function()
            if type(PresentCmds.DropModel) == "function" then
                PresentCmds.DropModel = function(...)
                    return
                end
            end
        end)
    end
end

-- ================= KHỞI CHẠY =================
task.spawn(function()
    local initialUid, initialAmount, initialCat = getGiftInfo(targetGiftName)
    print(string.format(
        "[AutoGift v5] Phiên #%d | Quà: '%s' [%s] | UID: %s | Số lượng hiện tại: %d",
        currentSession, targetGiftName, tostring(initialCat), tostring(initialUid), initialAmount
    ))

    inspectPresentAndLootboxModules()
    disableDropAnimation()

    local openGiftRemote = network:FindFirstChild("KX_Release")

    while _G.AutoOpenGift and (_G.AutoGiftSession == currentSession) do
        local giftUid, currentAmount = getGiftInfo(targetGiftName)

        if not giftUid or currentAmount <= 0 then
            print("[AutoGift v5] ĐÃ MỞ HẾT SẠCH QUÀ TRONG TÚI!")
            break
        end

        local amountToOpen = math.min(maxAmountPerOpen, currentAmount)
        local vectors = getDropVectors(amountToOpen)

        -- BƯỚC 1: Nếu đang có hộp quà cũ nằm trên đất chưa nổ xong, gọi OpenCurrent() để nổ ngay lập tức!
        if PresentCmds and type(PresentCmds.OpenCurrent) == "function" then
            pcall(PresentCmds.OpenCurrent)
        end

        -- BƯỚC 2: Thả 8 hộp quà mới xuống đất (qua PresentCmds.Drop hoặc KX_Release)
        local dropped = false
        if PresentCmds and type(PresentCmds.Drop) == "function" then
            local ok, res = pcall(PresentCmds.Drop, giftUid, amountToOpen, vectors)
            if ok and res ~= false then
                dropped = true
            end
        end

        if not dropped and openGiftRemote then
            local ok, res = pcall(function()
                return openGiftRemote:InvokeServer(giftUid, amountToOpen, vectors)
            end)
            if ok and res ~= false then
                dropped = true
            end
        end

        -- BƯỚC 3: Đợi một nhịp ngắn rồi kích nổ luôn 8 hộp vừa thả để đợt sau không bị kẹt!
        task.wait(0.4)
        if PresentCmds and type(PresentCmds.OpenCurrent) == "function" then
            pcall(PresentCmds.OpenCurrent)
        end

        task.wait(delayTime)

        local _, newAmount = getGiftInfo(targetGiftName)
        if newAmount < currentAmount then
            print(string.format("✅ [AutoGift v5] Đã mở thêm %d hộp! Trong túi còn: %d", currentAmount - newAmount, newAmount))
        end
    end
end)
