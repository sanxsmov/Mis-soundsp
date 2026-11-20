-- language: Lua (Luau), file: phantom_silent_esp.lua
-- target: Roblox Android + Delta — Phantom Forces (PlaceId 292439477)
-- silent aim: intercepta FireServer del arma, reemplaza la dirección por
--             el Head del enemigo con predicción. El servidor de PF acepta
--             la dirección afirmada por el cliente → el tiro entra sin mover
--             la cámara. No usa aimbot de cámara.
-- ESP: Highlight + BillboardGui (nombre, HP, distancia).

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera
local LP         = Players.LocalPlayer

-- ── config ────────────────────────────────────────────────────
local CFG = {
    silent        = true,
    fov           = 220,       -- radio de búsqueda en píxeles
    hit_part      = "Head",
    hit_chance    = 95,        -- % de disparos redirigidos
    pred_factor   = 0.055,     -- predicción por velocidad del target
    team_check    = true,
    visible_only  = true,

    esp           = true,
    esp_color     = Color3.fromRGB(0, 255, 120),
    esp_name      = true,
    esp_health    = true,
    esp_distance  = true,
}

-- ── bypass de superficie (Delta soporta todo) ─────────────────
pcall(function()
    local real_genv = getgenv()
    local proxy = setmetatable({}, {
        __index    = function(_, k) return real_genv[k] end,
        __newindex = function(_, k, v) rawset(real_genv, k, v) end,
        __pairs    = function()
            local clean = {}
            for k, v in pairs(real_genv) do
                if not (type(k) == "string" and (k:match("^_") or k:match("^phantom"))) then
                    clean[k] = v
                end
            end
            return next, clean, nil
        end,
    })
    hookfunction(identifyexecutor, newcclosure(function() return nil, nil end))
    hookfunction(getgenv, newcclosure(function() return proxy end))

    local ri = debug.info
    hookfunction(ri, newcclosure(function(f, opt)
        local r = table.pack(ri(f, opt))
        for i = 1, r.n do
            if type(r[i]) == "string" then
                r[i] = r[i]:gsub("[%w_]+%.dll", "[C]"):gsub("delta", "core"):gsub("executor", "core")
            end
        end
        return table.unpack(r, 1, r.n)
    end))
end)

-- ── helpers ───────────────────────────────────────────────────
local function is_teammate(p)
    return CFG.team_check and LP.Team ~= nil and p.Team ~= nil and LP.Team == p.Team
end

local function visible(part)
    if not CFG.visible_only then return true end
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LP.Character, part.Parent }
    return workspace:Raycast(origin, dir.Unit * dir.Magnitude, params) == nil
end

local function closest_target()
    local best, best_dist = nil, CFG.fov
    local center = Camera.ViewportSize / 2
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP or is_teammate(p) then continue end
        local ch = p.Character
        if not ch then continue end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = ch:FindFirstChild(CFG.hit_part)
        if not part or not visible(part) then continue end
        local s, on = Camera:WorldToViewportPoint(part.Position)
        if not on then continue end
        local d = (Vector2.new(s.X, s.Y) - center).Magnitude
        if d < best_dist then best_dist = d; best = part end
    end
    return best
end

local function predict(part)
    local root_ = part.Parent and part.Parent:FindFirstChild("HumanoidRootPart")
    if not root_ then return part.Position end
    local my_root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local dist = my_root and (part.Position - my_root.Position).Magnitude or 50
    local t_flight = dist / 550    -- velocidad de bala típica PF
    return part.Position + root_.AssemblyLinearVelocity * (t_flight * CFG.pred_factor)
end

-- ── silent aim: hook __namecall ───────────────────────────────
-- Phantom Force dispara por FireServer en un RemoteEvent cuyo nombre varía
-- por parche. Filtramos por método + patrón de nombre + chequeo de args
-- Vector3 para no romper otros remotos (chat, compras, etc).

local recent_shots = {}   -- dedupe por si el arma llama el remote en ráfaga

local namecall_orig = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if not checkcaller() and CFG.silent and method then
        local m = method:lower()
        if (m == "fireserver" or m == "invokeserver") and typeof(self) == "Instance" then
            local n = self.Name:lower()
            local armed = n:find("fire") or n:find("shoot") or n:find("attack")
                or n:find("hit") or n:find("bullet") or n:find("dmg") or n:find("damage")
            if armed then
                -- solo si el remoto lleva un Vector3 (dirección/origen) en args
                local args = { ... }
                local has_vec = false
                for i = 1, math.min(#args, 6) do
                    if typeof(args[i]) == "Vector3" then has_vec = true; break end
                end
                if has_vec and math.random(1, 100) <= CFG.hit_chance then
                    local t = closest_target()
                    if t then
                        local aim = predict(t)
                        for i = 1, math.min(#args, 6) do
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

-- ── ESP ───────────────────────────────────────────────────────
local esp_map = {}

local function build_esp(p)
    if p == LP or esp_map[p] then return end
    local ch = p.Character
    if not ch or not ch:FindFirstChild("HumanoidRootPart") then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local hl = Instance.new("Highlight")
    hl.Adornee = ch
    hl.FillColor = CFG.esp_color
    hl.FillTransparency = 0.55
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.OutlineTransparency = 0
    hl.Parent = ch

    local bb = Instance.new("BillboardGui")
    bb.Adornee = ch.Head
    bb.Size = UDim2.new(0, 200, 0, 44)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = ch

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = CFG.esp_color
    lbl.TextStrokeTransparency = 0
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = bb

    esp_map[p] = { hl = hl, bb = bb, lbl = lbl, hum = hum }

    task.spawn(function()
        while esp_map[p] and CFG.esp do
            task.wait(0.35)
            local r = ch:FindFirstChild("HumanoidRootPart")
            local mr = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if r and mr and lbl.Parent then
                local parts = {}
                if CFG.esp_name     then parts[#parts+1] = p.Name end
                if CFG.esp_health   then parts[#parts+1] = math.floor(hum.Health) .. " HP" end
                if CFG.esp_distance then parts[#parts+1] = math.floor((r.Position - mr.Position).Magnitude) .. "m" end
                lbl.Text = table.concat(parts, " | ")
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

local function refresh_esp()
    for _, p in ipairs(Players:GetPlayers()) do
        if CFG.esp then build_esp(p) else drop_esp(p) end
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.8)
        if CFG.esp then build_esp(p) end
    end)
end)
Players.PlayerRemoving:Connect(drop_esp)
task.spawn(function() while task.wait(1.5) do refresh_esp() end end)

-- ── GUI táctil ────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "core"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local function mkbtn(txt, pos, on)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 58, 0, 58)
    b.Position = pos
    b.BackgroundColor3 = on and Color3.fromRGB(0, 160, 90) or Color3.fromRGB(30, 30, 30)
    b.BackgroundTransparency = 0.2
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextScaled = true
    b.Font = Enum.Font.GothamBold
    b.Text = txt
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = gui
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    return b
end

local sa_btn  = mkbtn("SA",  UDim2.new(1, -74, 0.5, -74), CFG.silent)
local esp_btn = mkbtn("ESP", UDim2.new(1, -74, 0.5, -6),  CFG.esp)

sa_btn.MouseButton1Click:Connect(function()
    CFG.silent = not CFG.silent
    sa_btn.BackgroundColor3 = CFG.silent and Color3.fromRGB(0, 160, 90) or Color3.fromRGB(30, 30, 30)
end)
esp_btn.MouseButton1Click:Connect(function()
    CFG.esp = not CFG.esp
    esp_btn.BackgroundColor3 = CFG.esp and Color3.fromRGB(0, 160, 90) or Color3.fromRGB(30, 30, 30)
    refresh_esp()
end)

print(("[phantom] silent=%s | esp=%s | fov=%d")
    :format(tostring(CFG.silent), tostring(CFG.esp), CFG.fov))
