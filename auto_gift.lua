local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("Network")

-- ================= CẤU HÌNH =================
-- Có thể chỉnh trực tiếp tại đây hoặc đặt biến _G trước khi chạy loadstring
_G.AutoOpenGift = (_G.AutoOpenGift ~= nil) and _G.AutoOpenGift or true
_G.HideGiftGui = (_G.HideGiftGui ~= nil) and _G.HideGiftGui or true
_G.ClearLagEffects = (_G.ClearLagEffects ~= nil) and _G.ClearLagEffects or true

local targetGiftName = _G.TargetGiftName or "Midnight Gift" -- Tên hộp quà muốn mở
local remoteName = _G.RemoteName or "KX_Release"            -- Tên Remote trong ReplicatedStorage.Network
local maxAmountPerOpen = _G.MaxAmountPerOpen or 8           -- Số lượng mở tối đa mỗi lần
local delayTime = _G.DelayTime or 1.8                       -- Thời gian nghỉ giữa mỗi lần mở (giây)
-- ============================================

local openGiftRemote = network:WaitForChild(remoteName, 10)
if not openGiftRemote then
    warn(string.format("[AutoGift] Không tìm thấy Remote '%s' trong ReplicatedStorage.Network!", remoteName))
    return
end

local Save = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Client"):WaitForChild("Save"))

-- Chống chạy chồng chéo nhiều vòng lặp khi bấm Execute nhiều lần
_G.AutoGiftSession = (_G.AutoGiftSession or 0) + 1
local currentSession = _G.AutoGiftSession

local rng = Random.new()
local cachedUid = nil
local cachedCategory = nil

-- 1. Hàm lấy UID có bộ nhớ đệm (Cache) - Không cần quét lại toàn bộ kho đồ mỗi vòng lặp
local function getGiftInfo(giftName)
    local saveData = Save.Get()
    if not saveData or not saveData.Inventory then
        return nil, 0, nil
    end

    -- Nếu đã lưu Cache từ lần trước thì truy cập trực tiếp (tốc độ tức thời, không tốn CPU/RAM)
    if cachedCategory and cachedUid then
        local categoryTable = saveData.Inventory[cachedCategory]
        local itemData = categoryTable and categoryTable[cachedUid]
        if itemData then
            return cachedUid, (itemData._am or 1), cachedCategory
        else
            -- Nếu không còn tồn tại ở UID cũ thì xóa Cache để tìm lại
            cachedUid, cachedCategory = nil, nil
        end
    end

    -- Chỉ quét kho đồ ở lần đầu tiên hoặc khi UID bị thay đổi
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

-- 2. Hàm kiểm tra và tắt GUI mở quà
local function checkAndHideGui(gui)
    if not _G.HideGiftGui or not gui:IsA("ScreenGui") then return end
    local nameLower = string.lower(gui.Name)
    if string.find(nameLower, "gift") or string.find(nameLower, "open") or string.find(nameLower, "reward") or string.find(nameLower, "lootbox") then
        gui.Enabled = false
    end
end

-- 3. Hàm dọn hiệu ứng nổ quà / âm thanh trong Workspace để chống tràn RAM
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

-- 4. Tạo tọa độ ngẫu nhiên quanh nhân vật
local function generatePositionsAroundPlayer(count, radius)
    local positions = table.create(count)
    local character = localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local centerPos = rootPart and rootPart.Position or Vector3.new(152.0, 14.0, -210.0)

    for i = 1, count do
        positions[i] = centerPos + Vector3.new(rng:NextNumber(-radius, radius), 0, rng:NextNumber(-radius, radius))
    end
    return positions
end

-- 5. Gửi request lên Server
local isRemoteFunction = openGiftRemote:IsA("RemoteFunction")
local function sendOpenRequest(id, amount, vectors)
    if isRemoteFunction then
        return openGiftRemote:InvokeServer(id, amount, vectors)
    else
        openGiftRemote:FireServer(id, amount, vectors)
        return true
    end
end

-- ================= KHỞI CHẠY =================
task.spawn(function()
    local connections = {}

    -- Theo dõi và tắt GUI ngay khi mới sinh ra
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, gui in ipairs(playerGui:GetChildren()) do
            checkAndHideGui(gui)
        end
        table.insert(connections, playerGui.ChildAdded:Connect(checkAndHideGui))
    end

    -- Tự động tắt các hạt Particle/Âm thanh mới sinh ra trong Workspace khi mở quà
    local thingsFolder = Workspace:FindFirstChild("__THINGS") or Workspace
    table.insert(connections, thingsFolder.DescendantAdded:Connect(cleanElementLag))

    print(string.format("[AutoGift] Bắt đầu phiên #%d - Đang mở: %s", currentSession, targetGiftName))

    -- Vòng lặp chính: Tự dừng nếu tắt _G.AutoOpenGift hoặc nếu có phiên mới đè lên
    while _G.AutoOpenGift and (_G.AutoGiftSession == currentSession) do
        local giftUid, currentAmount, category = getGiftInfo(targetGiftName)

        if not giftUid or currentAmount <= 0 then
            warn(string.format("[AutoGift] Đã mở hết hoặc không tìm thấy '%s' trong túi đồ!", targetGiftName))
            break
        end

        local amountToOpen = math.min(maxAmountPerOpen, currentAmount)
        local randomizedVectors = generatePositionsAroundPlayer(amountToOpen, 8)

        local success, result = pcall(sendOpenRequest, giftUid, amountToOpen, randomizedVectors)
        if not success then
            warn("[AutoGift] Lỗi gửi request:", result)
            task.wait(3) -- Nghỉ lâu hơn nếu mạng hoặc Server bị nghẽn
        else
            print(string.format(
                "[AutoGift] Đã mở %d '%s' [%s] | Còn lại: %d",
                amountToOpen, targetGiftName, tostring(category), math.max(0, currentAmount - amountToOpen)
            ))
        end

        task.wait(delayTime)
    end

    -- Ngắt toàn bộ sự kiện khi dừng để giải phóng RAM (Chống Memory Leak)
    for _, conn in ipairs(connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end

    print(string.format("[AutoGift] Đã kết thúc phiên #%d và giải phóng bộ nhớ.", currentSession))
end)
