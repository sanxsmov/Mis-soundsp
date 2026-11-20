-- language: Lua (Luau), file: delta_suite.lua
-- target: Roblox Android + Delta — Rivals (17625359962), Phantom Forces (292439477)
-- Delta tiene: hookmetamethod, checkcaller, gethui, hookfunction, newcclosure.
-- silent aim: prende automático solo en Phantom Forces.
--             En Rivals queda OFF por Server Authority (mataría el efecto igual).

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera
local LP         = Players.LocalPlayer

-- ── detección de juego ────────────────────────────────────────
local GAME = "unknown"
if game.PlaceId == 292439477 then GAME = "phantom"
elseif game.PlaceId == 17625359962 then GAME = "rivals" end

-- ── bypass de superficie (Delta lo soporta entero) ────────────
local real_genv = getgenv()
local proxy = setmetatable({}, {
    __index    = function(_, k) return real_genv[k] end,
    __newindex = function(_, k, v) rawset(real_genv, k, v) end,
    __pairs    = function()
        local clean = {}
        for k, v in pairs(real_genv) do
            if not (type(k) == "string" and (k:match("^_") or k:match("^delta") or k:match("^suite"))) then
                clean[k] = v
            end
        end
        return next, clean, nil
    end,
})
hookfunction(identifyexecutor, newcclosure(function() return nil, nil end))
hookfunction(getgenv, newcclosure(function() return proxy end))
hookfunction(getfenv, newcclosure(function(f)
    local env = getfenv(f)
    if type(env) == "table" then
        for k in pairs(env) do
            if type(k) == "string" and (k:match("^_") or k:match("^delta")) then
                rawset(env, k, nil)
            end
        end
        return setmetatable({}, { __index = env })
    end
    return env
end))
local real_info = debug.info
hookfunction(real_info, newcclosure(function(f, opt)
    local r = table.pack(real_info(f, opt))
    for i = 1, r.n do
        if type(r[i]) == "string" then
            r[i] = r[i]:gsub("[%w_]+%.dll", "[C]"):gsub("delta", "core"):gsub("executor", "core")
        end
    end
    return table.unpack(r, 1, r.n)
end))

-- ── config ────────────────────────────────────────────────────
local CFG = {
    aim_enabled  = true,
    aim_fov      = 160,
    aim_smooth   = 0.22,
    aim_part     = "Head",
    esp_enabled  = true,
    esp_color    = Color3.fromRGB(0, 255, 120),
    -- silent: ON en Phantom, OFF en Rivals por Server Authority
    silent       = (GAME == "phantom"),
    hit_chance   = 92,
    pred_factor  = 0.06,
}

-- ── GUI táctil ────────────────────────────────────────────────
local root = Instance.new("ScreenGui")
root.Name = "core"
root.ResetOnSpawn = false
root.IgnoreGuiInset = true
root.Parent = gethui()

local function mkbtn(text, pos)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 58, 0, 58)
    b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    b.BackgroundTransparency = 0.2
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextScaled = true
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = root
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = b
    b.Text = text
    return b
end

local function paint(btn, on)
    btn.BackgroundColor3 = on and Color3.fromRGB(0, 160, 90) or Color3.fromRGB(30, 30, 30)
end

local aim_btn = mkbtn("AIM", UDim2.new(1, -74, 0.5, -100))
local esp_btn = mkbtn("ESP", UDim2.new(1, -74, 0.5, -30))
local sa_btn  = mkbtn("SA",  UDim2.new(1, -74, 0.5, 40))
paint(aim_btn, CFG.aim_enabled)
paint(esp_btn, CFG.esp_enabled)
paint(sa_btn,  CFG.silent)

esp_btn.MouseButton1Click:Connect(function()
    CFG.esp_enabled = not CFG.esp_enabled
    paint(esp_btn, CFG.esp_enabled)
end)
sa_btn.MouseButton1Click:Connect(function()
    CFG.silent = not CFG.silent
    paint(sa_btn, CFG.silent)
end)

-- ── aimbot táctil ─────────────────────────────────────────────
local holding = false
aim_btn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then
        holding = true; paint(aim_btn, true)
    end
end)
aim_btn.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then
        holding = false; paint(aim_btn, CFG.aim_enabled)
    end
end)

local function is_teammate(p)
    return LP.Team ~= nil and p.Team ~= nil and LP.Team == p.Team
end

local function closest()
    local best, bd = nil, CFG.aim_fov
    local center = Camera.ViewportSize / 2
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP or is_teammate(p) then continue end
        local ch = p.Character
        if not ch then continue end
        local h = ch:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then continue end
        local part = ch:FindFirstChild(CFG.aim_part)
        if not part then continue end
        local s, on = Camera:WorldToViewportPoint(part.Position)
        if not on then continue end
        local d = (Vector2.new(s.X, s.Y) - center).Magnitude
        if d < bd then bd = d; best = part end
    end
    return best
end

local function predict(part)
    local root_ = part.Parent and part.Parent:FindFirstChild("HumanoidRootPart")
    if not root_ then return part.Position end
    return part.Position + root_.AssemblyLinearVelocity * CFG.pred_factor
end

RunService.RenderStepped:Connect(function()
    if not CFG.aim_enabled or not holding then return end
    local t = closest()
    if not t then return end
    local goal = CFrame.new(Camera.CFrame.Position, t.Position)
    Camera.CFrame = Camera.CFrame:Lerp(goal, CFG.aim_smooth)
end)

-- ── ESP ───────────────────────────────────────────────────────
local esp_map = {}
local function build_esp(p)
    if p == LP or esp_map[p] then return end
    local ch = p.Character
    if not ch or not ch:FindFirstChild("HumanoidRootPart") then return end
    local h = ch:FindFirstChildOfClass("Humanoid")
    if not h then return end

    local hl = Instance.new("Highlight")
    hl.Adornee = ch
    hl.FillColor = CFG.esp_color
    hl.FillTransparency = 0.55
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.Parent = ch

    local bb = Instance.new("BillboardGui")
    bb.Adornee = ch.Head
    bb.Size = UDim2.new(0, 200, 0, 40)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = ch

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.TextColor3 = CFG.esp_color
    l.TextStrokeTransparency = 0
    l.TextScaled = true
    l.Font = Enum.Font.GothamBold
    l.Parent = bb

    esp_map[p] = { hl = hl, bb = bb, lbl = l, hum = h }

    task.spawn(function()
        while esp_map[p] and CFG.esp_enabled do
            task.wait(0.5)
            local r = ch:FindFirstChild("HumanoidRootPart")
            local mr = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if r and mr and l.Parent then
                l.Text = ("%s | %d HP | %dm"):format(p.Name, math.floor(h.Health), math.floor((r.Position - mr.Position).Magnitude))
            end
        end
    end)
end

local function drop_esp(p)
    local d = esp_map[p]
    if not d then return end
    if d.hl then d.hl:Destroy() end
    if d.bb then d.bb:Destroy() end
    esp_map[p] = nil
end

local function refresh()
    for _, p in ipairs(Players:GetPlayers()) do
        if CFG.esp_enabled then build_esp(p) else drop_esp(p) end
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(1); if CFG.esp_enabled then build_esp(p) end end)
end)
Players.PlayerRemoving:Connect(drop_esp)
task.spawn(function() while task.wait(2) do refresh() end end)

-- ── silent aim (hook __namecall, corregido para Delta) ───────
local namecall_orig = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if not checkcaller() and CFG.silent and method then
        local m = method:lower()
        if (m == "fireserver" or m == "invokeserver") and typeof(self) == "Instance" then
            local n = self.Name:lower()
            if n:find("fire") or n:find("shoot") or n:find("attack") or n:find("hit") then
                if math.random(1, 100) <= CFG.hit_chance then
                    local args = { ... }
                    local t = closest()
                    if t then
                        local aim = predict(t)
                        for i = 1, math.min(#args, 4) do
                            if typeof(args[i]) == "Vector3" then
                                args[i] = aim
                                break
                            end
                        end
                        return namecall_orig(self, table.unpack(args))
                    end
                end
            end
        end
    end
    return namecall_orig(self, ...)
end)

print(("[delta] %s | aim=%s | esp=%s | silent=%s")
    :format(GAME, tostring(CFG.aim_enabled), tostring(CFG.esp_enabled), tostring(CFG.silent)))
