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
local cachedItemData = nil

local learnedCall = nil -- Lưu hàm/remote bắt được khi người chơi bấm mở tay

-- 1. Tìm UID và thông tin của Midnight Gift trong túi đồ
local function getGiftInfo(giftName)
    local saveData = Save.Get()
    if not saveData or not saveData.Inventory then
        return nil, 0, nil, nil
    end

    if cachedCategory and cachedUid then
        local categoryTable = saveData.Inventory[cachedCategory]
        local itemData = categoryTable and categoryTable[cachedUid]
        if itemData then
            cachedItemData = itemData
            return cachedUid, (itemData._am or 1), cachedCategory, itemData
        else
            cachedUid, cachedCategory, cachedItemData = nil, nil, nil
        end
    end

    local targetLower = string.lower(giftName)
    for categoryName, categoryItems in pairs(saveData.Inventory) do
        if type(categoryItems) == "table" then
            for uid, itemData in pairs(categoryItems) do
                if type(itemData) == "table" and itemData.id and string.lower(tostring(itemData.id)) == targetLower then
                    cachedUid = uid
                    cachedCategory = categoryName
                    cachedItemData = itemData
                    return uid, (itemData._am or 1), categoryName, itemData
                end
            end
        end
    end

    return nil, 0, nil, nil
end

-- 2. In ra cấu trúc tham số để kiểm tra
local function formatArgs(args)
    local parts = {}
    for i, v in ipairs(args) do
        if typeof(v) == "table" then
            local count = 0
            local firstElem = nil
            for k, sub in pairs(v) do
                count = count + 1
                if count == 1 then
                    firstElem = tostring(k) .. "=" .. tostring(sub) .. "(" .. typeof(sub) .. ")"
                end
            end
            table.insert(parts, string.format("[%d]=Table(len=%d, %s)", i, count, tostring(firstElem)))
        else
            table.insert(parts, string.format("[%d]=%s(%s)", i, tostring(v), typeof(v)))
        end
    end
    return table.concat(parts, ", ")
end

-- 3. Quét tất cả Module và Remote liên quan đến mở quà trong game
local foundGiftRemotes = {}
local foundClientModules = {}

local function scanGameGiftApis()
    print("=== [AutoGift] ĐANG QUÉT API MỞ QUÀ TRONG GAME ===")
    local keywords = { "gift", "lootbox", "box", "bag", "open", "release", "present", "consume", "use", "roll", "kx" }

    for _, rem in ipairs(network:GetChildren()) do
        local nameLower = string.lower(rem.Name)
        for _, kw in ipairs(keywords) do
            if string.find(nameLower, kw) then
                table.insert(foundGiftRemotes, rem)
                print(string.format("  [Remote] %s (%s)", rem.Name, rem.ClassName))
                break
            end
        end
    end

    for _, mod in ipairs(clientFolder:GetChildren()) do
        if mod:IsA("ModuleScript") then
            local nameLower = string.lower(mod.Name)
            for _, kw in ipairs(keywords) do
                if string.find(nameLower, kw) then
                    local ok, req = pcall(require, mod)
                    if ok and type(req) == "table" then
                        foundClientModules[mod.Name] = req
                        local funcs = {}
                        for k, v in pairs(req) do
                            if type(v) == "function" then
                                table.insert(funcs, tostring(k))
                            end
                        end
                        print(string.format("  [Module] %s -> Các hàm: %s", mod.Name, table.concat(funcs, ", ")))
                    end
                    break
                end
            end
        end
    end
    print("===================================================")
end

-- 4. Bắt mọi lệnh gửi đi khi người chơi bấm mở quà bằng tay (Cả Lua Network lẫn __namecall)
local ignoredRemotes = {
    ["Idle"] = true, ["Click"] = true, ["Orbs"] = true, ["Breakables"] = true,
    ["Pets"] = true, ["Player"] = true, ["Ping"] = true, ["Stat"] = true
}

local function isSpamRemote(name)
    local lower = string.lower(name)
    for k in pairs(ignoredRemotes) do
        if string.find(lower, string.lower(k)) then
            return true
        end
    end
    return false
end

local function setupSpyHooks()
    -- Cách A: Hook trực tiếp vào Module Network của Pet Simulator 99 (Không cần hookmetamethod)
    local netModObj = clientFolder:FindFirstChild("Network")
    if netModObj then
        local ok, netMod = pcall(require, netModObj)
        if ok and type(netMod) == "table" then
            pcall(function()
                local oldInvoke = netMod.Invoke
                if type(oldInvoke) == "function" then
                    netMod.Invoke = function(remoteName, ...)
                        local args = { ... }
                        if not isSpamRemote(tostring(remoteName)) then
                            warn(string.format("[Spy-Network.Invoke] Remote: '%s' | Args: %s", tostring(remoteName), formatArgs(args)))
                            learnedCall = {
                                type = "NetworkModule",
                                method = "Invoke",
                                func = oldInvoke,
                                remoteName = remoteName,
                                args = args
                            }
                        end
                        return oldInvoke(remoteName, ...)
                    end
                    print("[AutoGift] Đã gắn bộ lắng nghe vào Library.Client.Network.Invoke!")
                end

                local oldFire = netMod.Fire
                if type(oldFire) == "function" then
                    netMod.Fire = function(remoteName, ...)
                        local args = { ... }
                        if not isSpamRemote(tostring(remoteName)) then
                            warn(string.format("[Spy-Network.Fire] Remote: '%s' | Args: %s", tostring(remoteName), formatArgs(args)))
                            if not learnedCall then
                                learnedCall = {
                                    type = "NetworkModule",
                                    method = "Fire",
                                    func = oldFire,
                                    remoteName = remoteName,
                                    args = args
                                }
                            end
                        end
                        return oldFire(remoteName, ...)
                    end
                end
            end)
        end
    end

    -- Cách B: Hook __namecall nếu công cụ chạy script có hỗ trợ
    if hookmetamethod and getnamecallmethod then
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if (method == "InvokeServer" or method == "FireServer") and self.Parent == network then
                    if not checkcaller or not checkcaller() then
                        local args = { ... }
                        if not isSpamRemote(self.Name) then
                            warn(string.format("[Spy-Namecall] Remote: '%s' (%s) | Args: %s", self.Name, method, formatArgs(args)))
                            learnedCall = {
                                type = "RemoteInstance",
                                method = method,
                                remote = self,
                                args = args
                            }
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)
            print("[AutoGift] Đã gắn bộ lắng nghe __namecall!")
        end)
    end
end

-- 5. Tạo tọa độ mặt đất quanh nhân vật
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

-- 6. Thử mở quà qua các Module Client (LootboxCmds / GiftBagCmds) hoặc Remote đã bắt được
local function attemptOpenGift(uid, giftName, amount, vectors)
    -- Ưu tiên 1: Nếu đã bắt được lệnh từ thao tác bấm tay của người chơi
    if learnedCall then
        local argsCopy = table.clone(learnedCall.args)
        for i, v in ipairs(argsCopy) do
            if type(v) == "table" and typeof(v[1]) == "Vector3" then
                argsCopy[i] = generateGroundPositions(#v, 6)
            end
        end

        if learnedCall.type == "NetworkModule" then
            local ok, res1, res2 = pcall(learnedCall.func, learnedCall.remoteName, unpack(argsCopy))
            if ok and res1 ~= false then
                return true, "Learned-Network:" .. tostring(learnedCall.remoteName)
            end
        elseif learnedCall.type == "RemoteInstance" then
            local ok, res1, res2 = pcall(function()
                if learnedCall.method == "InvokeServer" then
                    return learnedCall.remote:InvokeServer(unpack(argsCopy))
                else
                    learnedCall.remote:FireServer(unpack(argsCopy))
                    return true
                end
            end)
            if ok and res1 ~= false then
                return true, "Learned-Remote:" .. tostring(learnedCall.remote.Name)
            end
        end
    end

    -- Ưu tiên 2: Thử gọi qua Module LootboxCmds hoặc GiftBagCmds nếu có
    for modName, modTable in pairs(foundClientModules) do
        if type(modTable.Open) == "function" then
            -- Thử truyền (giftName, amount) hoặc (uid, amount)
            local ok1, res1 = pcall(modTable.Open, giftName, amount)
            if ok1 and res1 ~= false and res1 ~= nil then
                return true, modName .. ".Open(Name)"
            end
            local ok2, res2 = pcall(modTable.Open, uid, amount)
            if ok2 and res2 ~= false and res2 ~= nil then
                return true, modName .. ".Open(UID)"
            end
        end
    end

    -- Ưu tiên 3: Thử các Remote tìm thấy trong ReplicatedStorage.Network
    for _, rem in ipairs(foundGiftRemotes) do
        if rem:IsA("RemoteFunction") then
            local ok1, r1 = pcall(rem.InvokeServer, rem, giftName, amount)
            if ok1 and r1 == true then return true, rem.Name .. "(Name,Amt)" end

            local ok2, r2 = pcall(rem.InvokeServer, rem, uid, amount)
            if ok2 and r2 == true then return true, rem.Name .. "(UID,Amt)" end

            local ok3, r3 = pcall(rem.InvokeServer, rem, uid, amount, vectors)
            if ok3 and r3 == true then return true, rem.Name .. "(UID,Amt,Vec)" end

            local ok4, r4 = pcall(rem.InvokeServer, rem, giftName, amount, vectors)
            if ok4 and r4 == true then return true, rem.Name .. "(Name,Amt,Vec)" end
        end
    end

    return false, "Waiting"
end

-- ================= KHỞI CHẠY =================
task.spawn(function()
    local initialUid, initialAmount, initialCat = getGiftInfo(targetGiftName)
    print(string.format(
        "[AutoGift] Phiên #%d | Quà: '%s' [%s] | UID: %s | Số lượng ban đầu: %d",
        currentSession, targetGiftName, tostring(initialCat), tostring(initialUid), initialAmount
    ))

    scanGameGiftApis()
    setupSpyHooks()

    warn("👉 [AutoGift] HÃY MỞ BALO VÀ BẤM MỞ 1 HỘP 'Midnight Gift' BẰNG TAY ĐỂ XEM TÊN REMOTE TRONG ROBLOX OUTPUT!")

    while _G.AutoOpenGift and (_G.AutoGiftSession == currentSession) do
        local giftUid, currentAmount = getGiftInfo(targetGiftName)

        if not giftUid or currentAmount <= 0 then
            print("[AutoGift] Đã mở hết sạch quà trong túi!")
            break
        end

        local amountToOpen = math.min(maxAmountPerOpen, currentAmount)
        local groundVectors = generateGroundPositions(amountToOpen, 6)

        local openedOk, methodUsed = attemptOpenGift(giftUid, targetGiftName, amountToOpen, groundVectors)
        if openedOk then
            print(string.format("[AutoGift] Mở thành công qua [%s] | Còn lại: %d", methodUsed, currentAmount))
        end

        task.wait(delayTime)
    end
end)
