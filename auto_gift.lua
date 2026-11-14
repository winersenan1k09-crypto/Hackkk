local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("Network")
local Save = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Client"):WaitForChild("Save"))

-- ================= CẤU HÌNH =================
_G.AutoOpenGift = true
_G.HideGiftGui = true
_G.ClearLagEffects = true

local targetGiftName = _G.TargetGiftName or "Midnight Gift"
local maxAmountPerOpen = _G.MaxAmountPerOpen or 8
local delayTime = _G.DelayTime or 1.5 -- Nghỉ 1.5 giây để ổn định, không lỗi
-- ============================================

_G.AutoGiftSession = (_G.AutoGiftSession or 0) + 1
local currentSession = _G.AutoGiftSession

local rng = Random.new()
local cachedUid = nil
local cachedCategory = nil

-- Biến lưu lệnh chuẩn bắt được khi người chơi mở mồi 1 lần
local learnedRemote = nil
local learnedMethod = nil
local learnedArgsTemplate = nil

-- 1. Hàm lấy UID và số lượng thực tế trong túi đồ
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

-- 2. Ẩn GUI hiệu ứng mở quà (nhưng không ẩn túi đồ Inventory)
local function checkAndHideGui(gui)
    if not _G.HideGiftGui or not gui:IsA("ScreenGui") then return end
    local nameLower = string.lower(gui.Name)
    if string.find(nameLower, "lootbox") or string.find(nameLower, "giftbag") or string.find(nameLower, "opening") or string.find(nameLower, "reward") then
        gui.Enabled = false
    end
end

-- 3. Dọn hiệu ứng nổ 3D chống lag/crash
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

-- 4. Tạo tọa độ chạm chuẩn mặt đất (Raycast) xung quanh nhân vật
local function generateGroundPositions(count, radius)
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
        local offsetX = rng:NextNumber(-radius, radius)
        local offsetZ = rng:NextNumber(-radius, radius)
        local testOrigin = centerPos + Vector3.new(offsetX, 10, offsetZ)

        local rayResult = Workspace:Raycast(testOrigin, Vector3.new(0, -50, 0), rayParams)
        if rayResult then
            positions[i] = rayResult.Position
        else
            positions[i] = centerPos + Vector3.new(offsetX, -3, offsetZ)
        end
    end

    return positions
end

-- 5. Kiểm tra xem bảng tham số có chứa thông tin hộp quà không
local function tableContainsValue(tbl, targetUid, targetNameLower)
    for _, v in pairs(tbl) do
        if type(v) == "string" then
            if v == targetUid or string.lower(v) == targetNameLower then
                return true
            end
        elseif type(v) == "table" then
            if tableContainsValue(v, targetUid, targetNameLower) then
                return true
            end
        end
    end
    return false
end

-- 6. Tự động bắt lệnh chuẩn nếu người chơi tự bấm mở 1 hộp trong túi đồ
local function setupAutoLearnHook()
    if not hookmetamethod or not getnamecallmethod then return end

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if (method == "InvokeServer" or method == "FireServer") and self.Parent == network then
            if not checkcaller or not checkcaller() then
                local args = { ... }
                local uid = cachedUid
                local nameLower = string.lower(targetGiftName)

                if tableContainsValue(args, uid, nameLower) then
                    learnedRemote = self
                    learnedMethod = method
                    learnedArgsTemplate = args
                    warn(string.format("[AutoGift] ĐÃ HỌC ĐƯỢC LỆNH CHUẨN TỪ GAME! Remote: '%s' (%s)", self.Name, method))
                end
            end
        end
        return oldNamecall(self, ...)
    end)
end

-- 7. Thử mở quà bằng tất cả các phương thức của Pet Simulator 99
local function tryOpenGift(uid, giftName, amount, vectors)
    -- Ưu tiên 1: Nếu đã bắt được lệnh chuẩn từ thao tác tay của người chơi
    if learnedRemote and learnedArgsTemplate then
        local argsToSend = table.clone(learnedArgsTemplate)
        -- Nếu tham số thứ 3 là danh sách tọa độ Vector3 thì làm mới tọa độ ngẫu nhiên quanh nhân vật
        if type(argsToSend[3]) == "table" and typeof(argsToSend[3][1]) == "Vector3" then
            local countNeeded = #argsToSend[3]
            argsToSend[3] = generateGroundPositions(countNeeded, 6)
        end
        local ok, res = pcall(function()
            if learnedMethod == "InvokeServer" then
                return learnedRemote:InvokeServer(unpack(argsToSend))
            else
                learnedRemote:FireServer(unpack(argsToSend))
                return true
            end
        end)
        if ok and res ~= false then
            return true, "Learned:" .. learnedRemote.Name
        end
    end

    -- Ưu tiên 2: Các Remote chuẩn cho nhóm [Lootbox] và [GiftBag] trong Pet Sim 99
    local candidateRemotes = {
        network:FindFirstChild("Lootbox: Open"),
        network:FindFirstChild("GiftBag_Open"),
        network:FindFirstChild("KX_Release")
    }

    for _, rem in ipairs(candidateRemotes) do
        if rem then
            -- Thử bộ tham số 1: (Tên hộp quà, Số lượng) -> Chuẩn của Lootbox: Open
            local ok1, res1 = pcall(function()
                if rem:IsA("RemoteFunction") then
                    return rem:InvokeServer(giftName, amount)
                end
                return false
            end)
            if ok1 and res1 ~= false and res1 ~= nil then
                return true, rem.Name .. "(Name,Amount)"
            end

            -- Thử bộ tham số 2: (UID, Số lượng)
            local ok2, res2 = pcall(function()
                if rem:IsA("RemoteFunction") then
                    return rem:InvokeServer(uid, amount)
                end
                return false
            end)
            if ok2 and res2 ~= false and res2 ~= nil then
                return true, rem.Name .. "(UID,Amount)"
            end

            -- Thử bộ tham số 3: (UID, Số lượng, Bảng tọa độ)
            local ok3, res3 = pcall(function()
                if rem:IsA("RemoteFunction") then
                    return rem:InvokeServer(uid, amount, vectors)
                end
                return false
            end)
            if ok3 and res3 ~= false and res3 ~= nil then
                return true, rem.Name .. "(UID,Amount,Vectors)"
            end

            -- Thử bộ tham số 4: Chỉ truyền (UID) hoặc (Tên hộp quà)
            local ok4, res4 = pcall(function()
                if rem:IsA("RemoteFunction") then
                    return rem:InvokeServer(uid)
                end
                return false
            end)
            if ok4 and res4 ~= false and res4 ~= nil then
                return true, rem.Name .. "(UID)"
            end
        end
    end

    return false, "NeedManualClick"
end

-- ================= KHỞI CHẠY =================
task.spawn(function()
    local connections = {}

    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, gui in ipairs(playerGui:GetChildren()) do
            checkAndHideGui(gui)
        end
        table.insert(connections, playerGui.ChildAdded:Connect(checkAndHideGui))
    end

    local thingsFolder = Workspace:FindFirstChild("__THINGS") or Workspace
    table.insert(connections, thingsFolder.DescendantAdded:Connect(cleanElementLag))

    local initialUid, initialAmount, initialCat = getGiftInfo(targetGiftName)
    print(string.format(
        "[AutoGift] Phiên #%d | Hộp quà: '%s' [%s] | UID: %s | Số lượng: %d | Delay: %.1fs",
        currentSession, targetGiftName, tostring(initialCat), tostring(initialUid), initialAmount, delayTime
    ))

    pcall(setupAutoLearnHook)

    local warnedManual = false

    while _G.AutoOpenGift and (_G.AutoGiftSession == currentSession) do
        local giftUid, currentAmount = getGiftInfo(targetGiftName)

        if not giftUid or currentAmount <= 0 then
            print(string.format("[AutoGift] HOÀN TẤT! Đã mở hết sạch '%s'!", targetGiftName))
            break
        end

        local amountToOpen = math.min(maxAmountPerOpen, currentAmount)
        local groundVectors = generateGroundPositions(amountToOpen, 6)

        local openedOk, methodUsed = tryOpenGift(giftUid, targetGiftName, amountToOpen, groundVectors)

        if openedOk then
            warnedManual = false
            print(string.format(
                "[AutoGift] Đã mở %d '%s' qua [%s] | Trong túi còn: %d",
                amountToOpen, targetGiftName, methodUsed, currentAmount
            ))
        else
            if not warnedManual then
                warnedManual = true
                warn("==================================================================")
                warn("[AutoGift] HƯỚNG DẪN: Hãy mở túi đồ và BẤM MỞ 'Midnight Gift' BẰNG TAY 1 LẦN!")
                warn("[AutoGift] Script sẽ tự động bắt lệnh chuẩn của Server và tự mở tiếp toàn bộ 952 hộp!")
                warn("==================================================================")
            end
        end

        task.wait(delayTime)
    end

    for _, conn in ipairs(connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end

    print(string.format("[AutoGift] Đã kết thúc phiên #%d.", currentSession))
end)
