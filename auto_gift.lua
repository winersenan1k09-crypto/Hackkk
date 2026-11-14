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

-- ================= KHỞI TẠO GIAO DIỆN MACLIB =================
local loadCode = loadstring :: any
local MacLib = loadCode((game :: any):HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()

local Window = MacLib:Window({
    Title = "Reallloween Hub",
    Subtitle = "Pet Simulator 99 | Auto Gift & Utilities",
    Size = UDim2.fromOffset(820, 560),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})

Window:GlobalSetting({
    Name = "Hiệu ứng kính mờ (UI Blur)",
    Default = Window:GetAcrylicBlurState(),
    Callback = function(bool)
        Window:SetAcrylicBlurState(bool)
    end,
})

Window:GlobalSetting({
    Name = "Thông báo (Notifications)",
    Default = Window:GetNotificationsState(),
    Callback = function(bool)
        Window:SetNotificationsState(bool)
    end,
})

local tabGroups = {
    MainGroup = Window:TabGroup()
}

local tabs = {
    AutoGift = tabGroups.MainGroup:Tab({ Name = "Auto Mở Quà", Image = "rbxassetid://18821914323" }),
    Player = tabGroups.MainGroup:Tab({ Name = "Nhân Vật & AFK", Image = "rbxassetid://10723407389" }),
    Settings = tabGroups.MainGroup:Tab({ Name = "Cấu Hình", Image = "rbxassetid://10734950309" }),
}

local sections = {
    GiftLeft = tabs.AutoGift:Section({ Side = "Left" }),
    GiftRight = tabs.AutoGift:Section({ Side = "Right" }),
    PlayerLeft = tabs.Player:Section({ Side = "Left" }),
    PlayerRight = tabs.Player:Section({ Side = "Right" }),
}

-- ================= TAB 1: AUTO MỞ QUÀ =================
sections.GiftLeft:Header({
    Name = "Điều Khiển Mở Hộp Quà",
    Text = "Điều Khiển Mở Hộp Quà"
})

-- Bảng hiển thị trạng thái bên cột Phải
sections.GiftRight:Header({
    Name = "Trạng Thái Thời Gian Thực",
    Text = "Trạng Thái Thời Gian Thực"
})

local statusParagraph = sections.GiftRight:Paragraph({
    Header = "Trạng Thái: Đang chờ bật",
    Body = "Đang kiểm tra kho đồ..."
})

local function updateStatusDisplay()
    local uid, amount, cat = getGiftInfo(state.targetGiftName)
    local statusText = state.autoOpen and "🟢 ĐANG CHẠY AUTO" or "⚪ ĐANG TẠM DỪNG"
    local bodyText = string.format(
        "Hộp quà: %s [%s]\nSố lượng còn trong túi: %d\nĐã mở trong phiên này: %d hộp\nUID: %s",
        state.targetGiftName,
        tostring(cat or "Chưa thấy"),
        amount,
        state.totalOpenedSession,
        tostring(uid or "Không có")
    )
    pcall(function()
        statusParagraph:UpdateHeader(statusText)
        statusParagraph:UpdateBody(bodyText)
    end)
end

-- Dropdown chọn hộp quà trong túi
local initialGiftList = scanAvailableGiftsInBag()
local defaultIdx = 1
for idx, name in ipairs(initialGiftList) do
    if string.lower(name) == "midnight gift" then
        defaultIdx = idx
        state.targetGiftName = name
        break
    end
end

local giftDropdown = sections.GiftLeft:Dropdown({
    Name = "Chọn Hộp Quà Trong Túi",
    Search = true,
    Multi = false,
    Required = true,
    Options = initialGiftList,
    Default = defaultIdx,
    Callback = function(selectedName)
        if type(selectedName) == "string" and #selectedName > 0 then
            state.targetGiftName = selectedName
            cachedUid, cachedCategory, cachedDirData = nil, nil, nil
            updateStatusDisplay()
            Window:Notify({
                Title = "Reallloween Hub",
                Description = "Đã chọn hộp quà: " .. selectedName,
                Lifetime = 3
            })
        end
    end,
}, "GiftDropdown")

sections.GiftLeft:Button({
    Name = "🔄 Làm Mới Danh Sách Hộp Quà",
    Callback = function()
        local newList = scanAvailableGiftsInBag()
        pcall(function()
            giftDropdown:ClearOptions()
            giftDropdown:InsertOptions(newList)
        end)
        updateStatusDisplay()
        Window:Notify({
            Title = "Reallloween Hub",
            Description = "Đã quét lại túi đồ (" .. tostring(#newList) .. " vật phẩm)!",
            Lifetime = 3
        })
    end,
})

sections.GiftLeft:Input({
    Name = "Hoặc Tự Nhập Tên Hộp Quà",
    Placeholder = "Ví dụ: Midnight Gift",
    AcceptedCharacters = "All",
    Callback = function(input)
        if type(input) == "string" and #input > 0 then
            state.targetGiftName = input
            cachedUid, cachedCategory, cachedDirData = nil, nil, nil
            updateStatusDisplay()
            Window:Notify({
                Title = "Reallloween Hub",
                Description = "Đã đặt tên hộp quà: " .. input,
                Lifetime = 3
            })
        end
    end,
}, "CustomGiftInput")

sections.GiftLeft:Divider()

sections.GiftLeft:Toggle({
    Name = "🚀 Bật Auto Mở Hộp Quà Liên Tục",
    Default = false,
    Callback = function(value)
        state.autoOpen = value
        updateStatusDisplay()
        Window:Notify({
            Title = "Reallloween Hub",
            Description = (value and "Đã BẬT " or "Đã TẮT ") .. "Auto mở: " .. state.targetGiftName,
            Lifetime = 3
        })
    end,
}, "AutoOpenToggle")

sections.GiftLeft:Slider({
    Name = "Số Hộp Mở Mỗi Đợt",
    Default = 8,
    Minimum = 1,
    Maximum = 8,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        state.maxAmountPerOpen = math.clamp(math.floor(val), 1, 8)
    end,
}, "AmountPerOpenSlider")

sections.GiftLeft:Slider({
    Name = "Thời Gian Nghỉ (x0.1 Giây)",
    Default = 15,
    Minimum = 5,
    Maximum = 50,
    DisplayMethod = "Value",
    Precision = 0,
    Callback = function(val)
        state.delayTime = math.clamp(val / 10, 0.5, 5.0)
    end,
}, "DelayTimeSlider")

sections.GiftLeft:SubLabel({
    Text = "Mẹo: Mức 15 tương đương 1.5 giây (chuẩn ổn định nhất)."
})

-- Cột Phải: Tối ưu chống lag & điều khiển phụ
sections.GiftRight:Divider()

sections.GiftRight:Header({
    Name = "Tối Ưu Chống Crash & Ẩn GUI",
    Text = "Tối Ưu Chống Crash & Ẩn GUI"
})

sections.GiftRight:Toggle({
    Name = "🧹 Xóa Hiệu Ứng Nổ & Âm Thanh (Chống Crash)",
    Default = true,
    Callback = function(value)
        state.clearLagEffects = value
    end,
}, "ClearLagToggle")

sections.GiftRight:Toggle({
    Name = "🙈 Tự Động Ẩn GUI Hiệu Ứng Mở Quà",
    Default = true,
    Callback = function(value)
        state.hideGiftGui = value
    end,
}, "HideGiftGuiToggle")

sections.GiftRight:Button({
    Name = "⚡ Kích Nổ Hộp Quà Dưới Đất Ngay",
    Callback = function()
        if type(PresentCmds.OpenCurrent) == "function" then
            pcall(PresentCmds.OpenCurrent)
        end
        Window:Notify({
            Title = "Reallloween Hub",
            Description = "Đã gửi lệnh kích nổ các hộp quà trên mặt đất!",
            Lifetime = 2
        })
    end,
})

-- ================= TAB 2: NHÂN VẬT & CHỐNG AFK =================
sections.PlayerLeft:Header({
    Name = "Tiện Ích Treo Máy (Anti-AFK)",
    Text = "Tiện Ích Treo Máy (Anti-AFK)"
})

sections.PlayerLeft:Toggle({
    Name = "🛡️ Chống Kick AFK 20 Phút",
    Default = true,
    Callback = function(value)
        state.antiAfk = value
    end,
}, "AntiAfkToggle")

sections.PlayerLeft:Paragraph({
    Header = "Hướng dẫn Phím Tắt Menu",
    Body = "Bấm phím RightControl (Ctrl Phải) trên bàn phím để Ẩn / Hiện nhanh cửa sổ Menu này bất cứ lúc nào."
})

sections.PlayerRight:Header({
    Name = "Chỉ Số Nhân Vật",
    Text = "Chỉ Số Nhân Vật"
})

sections.PlayerRight:Slider({
    Name = "Tốc Độ Chạy (WalkSpeed)",
    Default = 16,
    Minimum = 16,
    Maximum = 150,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        local char = localPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = val
        end
    end,
})

sections.PlayerRight:Slider({
    Name = "Độ Cao Nhảy (JumpPower)",
    Default = 50,
    Minimum = 50,
    Maximum = 200,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        local char = localPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = val
        end
    end,
})

-- ================= TAB 3: CẤU HÌNH =================
MacLib:SetFolder("ReallloweenHub")
tabs.Settings:InsertConfigSection("Left")
tabs.AutoGift:Select()

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

    Window.onUnloaded(function()
        state.autoOpen = false
        _G.AutoGiftSession = _G.AutoGiftSession + 1
        for _, conn in ipairs(connections) do
            if conn.Connected then conn:Disconnect() end
        end
    end)

    updateStatusDisplay()

    while _G.AutoGiftSession == currentSession do
        if state.autoOpen then
            local giftUid, currentAmount = getGiftInfo(state.targetGiftName)

            if not giftUid or currentAmount <= 0 then
                state.autoOpen = false
                updateStatusDisplay()
                Window:Notify({
                    Title = "Reallloween Hub",
                    Description = "🎉 Đã mở hết sạch '" .. state.targetGiftName .. "' trong túi đồ!",
                    Lifetime = 5
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
end)
