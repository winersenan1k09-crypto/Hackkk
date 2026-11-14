local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("Network")

-- ================= CẤU HÌNH =================
_G.AutoOpenGift = true
_G.HideGiftGui = true
_G.ClearLagEffects = true

local targetGiftName = _G.TargetGiftName or "Midnight Gift" -- Tên hộp quà muốn mở
local remoteName = _G.RemoteName or "KX_Release"            -- Tên Remote chính
local maxAmountPerOpen = _G.MaxAmountPerOpen or 8           -- Số hộp mở mỗi nhịp (game giới hạn tối đa 8 hộp/lần quăng)
local delayTime = _G.DelayTime or 0.8                       -- Mở liên tục mỗi 0.8 giây cho đến khi hết sạch 952 hộp
-- ============================================

local openGiftRemote = network:WaitForChild(remoteName, 10)
local lootboxRemote = network:FindFirstChild("Lootbox: Open") or network:FindFirstChild("GiftBag_Open")
local Save = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Client"):WaitForChild("Save"))

-- Chống chạy chồng chéo nhiều vòng lặp
_G.AutoGiftSession = (_G.AutoGiftSession or 0) + 1
local currentSession = _G.AutoGiftSession

local rng = Random.new()
local cachedUid = nil
local cachedCategory = nil

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

-- 2. Ẩn GUI mở quà
local function checkAndHideGui(gui)
    if not _G.HideGiftGui or not gui:IsA("ScreenGui") then return end
    local nameLower = string.lower(gui.Name)
    if string.find(nameLower, "gift") or string.find(nameLower, "open") or string.find(nameLower, "reward") or string.find(nameLower, "lootbox") then
        gui.Enabled = false
    end
end

-- 3. Dọn hiệu ứng nổ quà 3D chống lag/crash
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
-- (Server sẽ từ chối nếu tọa độ hộp quà bị lơ lửng trên không trung)
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

        -- Bắn tia từ trên xuống để tìm đúng độ cao Y của mặt sàn nơi nhân vật đang đứng
        local rayResult = Workspace:Raycast(testOrigin, Vector3.new(0, -50, 0), rayParams)
        if rayResult then
            positions[i] = rayResult.Position
        else
            -- Nếu không bắt được sàn thì hạ trục Y xuống 3 studs (ngang bàn chân nhân vật)
            positions[i] = centerPos + Vector3.new(offsetX, -3, offsetZ)
        end
    end

    return positions
end

-- 5. Gửi request mở quà và kiểm tra kết quả thực sự từ Server
local function tryOpenGift(uid, giftName, amount, vectors)
    -- Cách 1: Thử gọi KX_Release với tọa độ mặt đất
    if openGiftRemote then
        if openGiftRemote:IsA("RemoteFunction") then
            local ok, res1, res2 = pcall(function()
                return openGiftRemote:InvokeServer(uid, amount, vectors)
            end)
            if ok and res1 ~= false then
                return true, "KX_Release(UID)", res1
            end
            -- Nếu truyền UID bị từ chối, thử truyền tên hộp quà
            local okName, resName1, resName2 = pcall(function()
                return openGiftRemote:InvokeServer(giftName, amount, vectors)
            end)
            if okName and resName1 ~= false then
                return true, "KX_Release(Name)", resName1
            end
            warn("[AutoGift] Phản hồi từ KX_Release:", tostring(res1), tostring(res2))
        else
            openGiftRemote:FireServer(uid, amount, vectors)
            return true, "KX_Release(FireServer)", true
        end
    end

    -- Cách 2: Dự phòng gọi Remote 'Lootbox: Open' nếu có
    if lootboxRemote then
        local ok, res1, res2 = pcall(function()
            if lootboxRemote:IsA("RemoteFunction") then
                return lootboxRemote:InvokeServer(uid, amount)
            else
                lootboxRemote:FireServer(uid, amount)
                return true
            end
        end)
        if ok and res1 ~= false then
            return true, lootboxRemote.Name, res1
        end
    end

    return false, "Failed", nil
end

-- ================= KHỞI CHẠY LIÊN TỤC =================
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
        "[AutoGift] Phiên #%d | Hộp quà: '%s' | Nhóm: [%s] | UID: %s | Tổng số: %d",
        currentSession, targetGiftName, tostring(initialCat), tostring(initialUid), initialAmount
    ))

    -- Vòng lặp mở liên tục cho đến khi mở hết toàn bộ 952 hộp
    while _G.AutoOpenGift and (_G.AutoGiftSession == currentSession) do
        local giftUid, currentAmount, category = getGiftInfo(targetGiftName)

        if not giftUid or currentAmount <= 0 then
            print(string.format("[AutoGift] HOÀN TẤT! Đã mở hết sạch '%s' trong túi đồ!", targetGiftName))
            break
        end

        local amountToOpen = math.min(maxAmountPerOpen, currentAmount)
        local groundVectors = generateGroundPositions(amountToOpen, 6)

        local openedOk, methodUsed = tryOpenGift(giftUid, targetGiftName, amountToOpen, groundVectors)

        if openedOk then
            print(string.format(
                "[AutoGift] Đang mở liên tục %d '%s' (%s) | Trong túi còn: %d",
                amountToOpen, targetGiftName, methodUsed, currentAmount
            ))
        else
            warn("[AutoGift] Server chưa cho mở đợt này (đang chờ hộp cũ nổ xong hoặc sai khu vực)...")
        end

        task.wait(delayTime)
    end

    for _, conn in ipairs(connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end

    print(string.format("[AutoGift] Đã dừng phiên #%d.", currentSession))
end)
