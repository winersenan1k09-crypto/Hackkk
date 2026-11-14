local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local localPlayer = Players.LocalPlayer
local library = ReplicatedStorage:WaitForChild("Library")
local clientFolder = library:WaitForChild("Client")

local function requireModule(inst: Instance): any
    return (require :: any)(inst)
end

local Save = requireModule(clientFolder:WaitForChild("Save"))
local Directory = requireModule(library:WaitForChild("Directory"))
local PresentCmds = requireModule(clientFolder:WaitForChild("PresentCmds"))
local LootboxCmds = requireModule(clientFolder:WaitForChild("LootboxCmds"))

-- ================= BIẾN TRẠNG THÁI =================
_G.AutoGiftSession = (_G.AutoGiftSession or 0) + 1
local currentSession = _G.AutoGiftSession

local state = {
    autoOpen = false,
    targetGiftName = "Midnight Gift",
    maxAmountPerOpen = 8,
    delayTime = 1.5,
    clearLagEffects = true,
    hideGiftGui = true,
    antiAfk = true,
    totalOpenedSession = 0,
}

local cachedUid = nil
local cachedCategory = nil
local cachedDirData = nil

-- ================= HÀM XỬ LÝ DỮ LIỆU GAME =================

-- 1. Tìm dữ liệu gốc (Directory) của hộp quà
local function findItemDirectory(giftName)
    local targetLower = string.lower(giftName)
    if type(Directory) == "table" then
        if type(Directory.Lootboxes) == "table" then
            for id, data in pairs(Directory.Lootboxes) do
                if string.lower(tostring(id)) == targetLower then
                    return data
                end
            end
        end
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

-- 2. Quét danh sách tất cả các loại hộp quà/túi quà hiện có trong túi đồ
local function scanAvailableGiftsInBag()
    local list = {}
    local seen = {}
    local saveData = Save.Get()
    if not saveData or not saveData.Inventory then
        return { "Midnight Gift" }
    end

    for _, categoryName in ipairs({ "Lootbox", "Misc" }) do
        local catTable = saveData.Inventory[categoryName]
        if type(catTable) == "table" then
            for _, itemData in pairs(catTable) do
                if type(itemData) == "table" and itemData.id then
                    local idStr = tostring(itemData.id)
                    if not seen[idStr] then
                        seen[idStr] = true
                        table.insert(list, idStr)
                    end
                end
            end
        end
    end

    table.sort(list)
    if #list == 0 then
        table.insert(list, "Midnight Gift")
    end
    return list
end

-- 3. Tìm UID và số lượng thực tế của hộp quà đang chọn
local function getGiftInfo(giftName)
    local saveData = Save.Get()
    if not saveData or not saveData.Inventory then
        return nil, 0, nil
    end

    if cachedCategory and cachedUid then
        local categoryTable = saveData.Inventory[cachedCategory]
        local itemData = categoryTable and categoryTable[cachedUid]
        if itemData and string.lower(tostring(itemData.id)) == string.lower(giftName) then
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

-- 4. Tạo đối tượng Item đầy đủ GetId(), GetUID(), Directory() cho LootboxCmds.Open
local function makeItemObject(uid, giftName)
    if not cachedDirData or string.lower(tostring(cachedDirData._id or "")) ~= string.lower(giftName) then
        cachedDirData = findItemDirectory(giftName)
    end
    local dirData = cachedDirData

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
        end
    })
end

-- 5. Dọn hiệu ứng nổ 3D & âm thanh chống tràn RAM
local function cleanElementLag(obj)
    if not state.clearLagEffects then return end
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Sparkles") or obj:IsA("Smoke") then
        obj.Enabled = false
    elseif obj:IsA("Explosion") then
        obj.Visible = false
    elseif obj:IsA("Sound") then
        obj.Volume = 0
    end
end

local function checkAndHideGui(gui)
    if not state.hideGiftGui or not gui:IsA("ScreenGui") then return end
    local nameLower = string.lower(gui.Name)
    if string.find(nameLower, "lootbox") or string.find(nameLower, "giftbag") or string.find(nameLower, "opening") or string.find(nameLower, "reward") then
        gui.Enabled = false
    end
end

-- ================= KHỞI TẠO GIAO DIỆN WINDUI (DUCKKY HUB) =================
local loadCode = loadstring :: any
local WindUI = loadCode((game :: any):HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Duckky Hub",
    Icon = "gift",
    Author = "Pet Simulator 99 | Auto Gift & Utilities",
    Folder = "DuckkyHub",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark",
    Resizable = true,
    Transparent = true,
    ToggleKey = Enum.KeyCode.RightControl,
    Topbar = {
        ButtonsType = "Mac" -- 3 nút Traffic Lights phong cách macOS: Đỏ (x) và Vàng (-)
    },
    OpenButton = {
        Title = "🦆 Duckky Hub",
        Icon = "gift",
        CornerRadius = UDim.new(0, 10),
        StrokeThickness = 1.5,
        Color = ColorSequence.new(
            Color3.fromHex("FFAA00"),
            Color3.fromHex("FF5500")
        ),
        OnlyMobile = false,
        Enabled = true,
        Draggable = true,
    }
})

-- ================= TẠO TABS =================
local GiftTab = Window:Tab({
    Title = "Auto Mở Quà",
    Icon = "gift",
})

local PlayerTab = Window:Tab({
    Title = "Nhân Vật & AFK",
    Icon = "user",
})

-- ================= TAB 1: AUTO MỞ QUÀ =================
local StatusParagraph = GiftTab:Paragraph({
    Title = "Trạng Thái: Đang chờ bật",
    Desc = "Đang kiểm tra kho đồ..."
})

local function updateStatusDisplay()
    local uid, amount, cat = getGiftInfo(state.targetGiftName)
    local statusText = state.autoOpen and "🟢 ĐANG CHẠY AUTO" or "⚪ ĐANG TẠM DỪNG"
    local bodyText = string.format(
        "Hộp quà: %s [%s] | Trong túi còn: %d | Đã mở: %d hộp\nUID: %s",
        state.targetGiftName,
        tostring(cat or "Chưa thấy"),
        amount,
        state.totalOpenedSession,
        tostring(uid or "Không có")
    )
    pcall(function()
        StatusParagraph:SetTitle(statusText)
        StatusParagraph:SetDesc(bodyText)
    end)
end

local GiftSection = GiftTab:Section({
    Title = "Điều Khiển Mở Hộp Quà"
})

local initialGiftList = scanAvailableGiftsInBag()
local defaultGift = "Midnight Gift"
for _, name in ipairs(initialGiftList) do
    if string.lower(name) == "midnight gift" then
        defaultGift = name
        state.targetGiftName = name
        break
    end
end

local GiftDropdown = GiftSection:Dropdown({
    Title = "Chọn Hộp Quà Trong Túi",
    Values = initialGiftList,
    Value = defaultGift,
    Callback = function(selectedName)
        if type(selectedName) == "string" and #selectedName > 0 then
            state.targetGiftName = selectedName
            cachedUid, cachedCategory, cachedDirData = nil, nil, nil
            updateStatusDisplay()
            WindUI:Notify({
                Title = "Duckky Hub",
                Content = "Đã chọn hộp quà: " .. selectedName,
                Duration = 2,
                Icon = "gift"
            })
        end
    end
})

GiftSection:Button({
    Title = "🔄 Làm Mới Danh Sách Hộp Quà",
    Desc = "Quét lại túi đồ để cập nhật hộp quà mới nhận",
    Callback = function()
        local newList = scanAvailableGiftsInBag()
        pcall(function()
            if GiftDropdown.SetValues then
                GiftDropdown:SetValues(newList)
            end
        end)
        updateStatusDisplay()
        WindUI:Notify({
            Title = "Duckky Hub",
            Content = "Đã quét lại túi đồ (" .. tostring(#newList) .. " vật phẩm)!",
            Duration = 2,
            Icon = "refresh-cw"
        })
    end
})

GiftSection:Toggle({
    Title = "🚀 Bật Auto Mở Hộp Quà Liên Tục",
    Desc = "Tự động mở và kích nổ liên tục cho đến khi hết quà",
    Value = false,
    Callback = function(value)
        state.autoOpen = value
        updateStatusDisplay()
        WindUI:Notify({
            Title = "Duckky Hub",
            Content = (value and "Đã BẬT " or "Đã TẮT ") .. "Auto mở: " .. state.targetGiftName,
            Duration = 2,
            Icon = value and "play" or "square"
        })
    end
})

GiftSection:Slider({
    Title = "Số Hộp Mở Mỗi Đợt",
    Desc = "Tối đa 8 hộp/lần",
    Step = 1,
    Value = { Min = 1, Max = 8, Default = 8 },
    Callback = function(val)
        state.maxAmountPerOpen = math.clamp(math.floor(val), 1, 8)
    end
})

GiftSection:Slider({
    Title = "Thời Gian Nghỉ (x0.1 Giây)",
    Desc = "15 = 1.5 giây (ổn định nhất)",
    Step = 1,
    Value = { Min = 5, Max = 50, Default = 15 },
    Callback = function(val)
        state.delayTime = math.clamp(val / 10, 0.5, 5.0)
    end
})

local OptSection = GiftTab:Section({
    Title = "Tối Ưu & Tiện Ích"
})

OptSection:Toggle({
    Title = "🧹 Xóa Hiệu Ứng Nổ & Âm Thanh (Chống Crash)",
    Value = true,
    Callback = function(value)
        state.clearLagEffects = value
    end
})

OptSection:Toggle({
    Title = "🙈 Tự Động Ẩn GUI Hiệu Ứng Mở Quà",
    Value = true,
    Callback = function(value)
        state.hideGiftGui = value
    end
})

OptSection:Button({
    Title = "⚡ Kích Nổ Hộp Quà Dưới Đất Ngay",
    Desc = "Mở ngay các hộp quà đang kẹt trên mặt đất",
    Callback = function()
        if type(PresentCmds.OpenCurrent) == "function" then
            pcall(PresentCmds.OpenCurrent)
        end
        WindUI:Notify({
            Title = "Duckky Hub",
            Content = "Đã gửi lệnh kích nổ các hộp quà!",
            Duration = 2,
            Icon = "zap"
        })
    end
})

-- ================= TAB 2: NHÂN VẬT & AFK =================
local PlayerSection = PlayerTab:Section({
    Title = "Tiện Ích Treo Máy"
})

PlayerSection:Toggle({
    Title = "🛡️ Chống Kick AFK 20 Phút",
    Value = true,
    Callback = function(value)
        state.antiAfk = value
    end
})

PlayerSection:Paragraph({
    Title = "Hướng Dẫn Bật / Tắt Menu",
    Desc = "• Bấm nút [-] hoặc [x] trên thanh tiêu đề để thu nhỏ/đóng menu.\n• Click vào nút nổi '🦆 Duckky Hub' trên màn hình hoặc bấm phím RightControl (Ctrl Phải) để mở lại bất cứ lúc nào!\n• Nhấn giữ chuột bất kỳ đâu trên thanh tiêu đề để kéo di chuyển menu."
})

local StatsSection = PlayerTab:Section({
    Title = "Chỉ Số Nhân Vật"
})

StatsSection:Slider({
    Title = "Tốc Độ Chạy (WalkSpeed)",
    Step = 1,
    Value = { Min = 16, Max = 150, Default = 16 },
    Callback = function(val)
        local char = localPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = val
        end
    end
})

StatsSection:Slider({
    Title = "Độ Cao Nhảy (JumpPower)",
    Step = 1,
    Value = { Min = 50, Max = 200, Default = 50 },
    Callback = function(val)
        local char = localPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = val
        end
    end
})

-- ================= VÒNG LẶP XỬ LÝ NGẦM =================
task.spawn(function()
    local connections = {}

    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        table.insert(connections, playerGui.ChildAdded:Connect(checkAndHideGui))
    end

    local thingsFolder = Workspace:FindFirstChild("__THINGS") or Workspace
    table.insert(connections, thingsFolder.DescendantAdded:Connect(cleanElementLag))

    table.insert(connections, localPlayer.Idled:Connect(function()
        if state.antiAfk then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end))

    updateStatusDisplay()

    while _G.AutoGiftSession == currentSession do
        if state.autoOpen then
            local giftUid, currentAmount = getGiftInfo(state.targetGiftName)

            if not giftUid or currentAmount <= 0 then
                state.autoOpen = false
                updateStatusDisplay()
                WindUI:Notify({
                    Title = "Duckky Hub",
                    Content = "🎉 Đã mở hết sạch '" .. state.targetGiftName .. "' trong túi đồ!",
                    Duration = 5,
                    Icon = "check-circle"
                })
            else
                local amountToOpen = math.min(state.maxAmountPerOpen, currentAmount)
                local itemObj = makeItemObject(giftUid, state.targetGiftName)

                if type(PresentCmds.OpenCurrent) == "function" then
                    pcall(PresentCmds.OpenCurrent)
                end

                pcall(LootboxCmds.Open, itemObj, amountToOpen)

                task.wait(0.8)
                if type(PresentCmds.OpenCurrent) == "function" then
                    pcall(PresentCmds.OpenCurrent)
                end

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

                task.wait(state.delayTime)

                local _, afterAmount = getGiftInfo(state.targetGiftName)
                if afterAmount < currentAmount then
                    state.totalOpenedSession = state.totalOpenedSession + (currentAmount - afterAmount)
                end
                updateStatusDisplay()
            end
        else
            task.wait(0.5)
        end
    end

    for _, conn in ipairs(connections) do
        if conn.Connected then conn:Disconnect() end
    end
end)
