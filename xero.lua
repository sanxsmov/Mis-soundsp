-- language: Lua (Luau), file: aimbot_hard.lua
-- target: Roblox Android + Delta — Rivals / Phantom Forces
-- por qué pega más que el anterior:
--   1. mousemoverel en vez de Camera.CFrame = Lerp → input real, servidor lo valida
--      como movimiento de cámara legítimo, no como corrección anómala.
--   2. hitbox override en el Head → el tiro entra aunque el crosshair tiemble ±40px.
--   3. sticky target → no cambia de enemigo a mitad de ráfaga.
--   4. predicción con velocidad real + aceleración, no factor fijo.
--   5. auto-fire opcional vía mouse1click (Delta lo expone).
--   6. selección por ángulo al crosshair, no por distancia al centro de pantalla.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera
local LP         = Players.LocalPlayer

local GAME = "unknown"
if game.PlaceId == 292439477 then GAME = "phantom"
elseif game.PlaceId == 17625359962 then GAME = "rivals" end

-- capacidades Delta
local HAS_MOUSE = type(mousemoverel) == "function"
local HAS_CLICK = type(mouse1click) == "function"

-- ── config ────────────────────────────────────────────────────
local CFG = {
    enabled       = true,
    fov           = 200,          -- radio de búsqueda (píxeles)
    snap_speed    = 0.85,         -- 1.0 = instantáneo; 0.85 = casi snap con 1-2 frames de suavizado
    hit_part      = "Head",
    hitbox_expand = 4.5,          -- multiplicador del hitbox (1 = sin override, 4.5 = brutal)
    sticky        = true,         -- no cambia de target mientras esté vivo y en FOV
    team_check    = true,
    auto_fire     = false,        -- click automático al lockear
    fire_cooldown = 0.08,
    pred_factor   = 1.0,          -- 1.0 = predicción completa por velocidad
}

-- ── hitbox override (esto es lo que hace al aimbot "potente") ─
-- agranda el hitbox del Head de cada enemigo. El tiro entra aunque el
-- crosshair no esté perfecto. Se revierte al apagar el script.
local hitbox_orig_size = {}
local function expand_hitbox(char)
    local head = char and char:FindFirstChild("Head")
    if not head or hitbox_orig_size[head] then return end
    hitbox_orig_size[head] = head.Size
    head.Size = head.Size * CFG.hitbox_expand
    head.Transparency = 0  -- asegura que sea clickeable
end
local function restore_hitbox(char)
    local head = char and char:FindFirstChild("Head")
    if not head or not hitbox_orig_size[head] then return end
    head.Size = hitbox_orig_size[head]
    hitbox_orig_size[head] = nil
end
local function refresh_hitboxes()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            if CFG.enabled then expand_hitbox(p.Character) else restore_hitbox(p.Character) end
        end
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(ch)
        task.wait(0.5)
        if CFG.enabled then expand_hitbox(ch) end
    end)
end)
task.spawn(function() while task.wait(1) do refresh_hitboxes() end end)

-- ── selección de target ───────────────────────────────────────
local function is_teammate(p)
    return LP.Team ~= nil and p.Team ~= nil and LP.Team == p.Team
end

local function visible(part)
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LP.Character, part.Parent }
    return workspace:Raycast(origin, dir.Unit * dir.Magnitude, params) == nil
end

-- sticky: guarda el último target mientras siga vivo y en FOV
local locked_target = nil
local locked_char   = nil

local function valid_target(part)
    if not part or not part.Parent then return false end
    local char = part.Parent
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local root_ = char:FindFirstChild("HumanoidRootPart")
    if not root_ then return false end
    local s, on = Camera:WorldToViewportPoint(part.Position)
    if not on then return false end
    local center = Camera.ViewportSize / 2
    return (Vector2.new(s.X, s.Y) - center).Magnitude <= CFG.fov
end

local function pick_target()
    -- sticky primero
    if CFG.sticky and locked_target and valid_target(locked_target) then
        return locked_target, locked_char
    end
    locked_target, locked_char = nil, nil

    local best, best_char, best_score = nil, nil, math.huge
    local center = Camera.ViewportSize / 2
    local my_root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP or is_teammate(p) then continue end
        local ch = p.Character
        if not ch then continue end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = ch:FindFirstChild(CFG.hit_part)
        if not part then continue end
        if not visible(part) then continue end

        local s, on = Camera:WorldToViewportPoint(part.Position)
        if not on then continue end
        local screen_pos = Vector2.new(s.X, s.Y)
        local ang_dist = (screen_pos - center).Magnitude
        if ang_dist > CFG.fov then continue end

        -- score: ángulo pesa más que distancia física
        local phys_dist = my_root and (part.Position - my_root.Position).Magnitude or 0
        local score = ang_dist + phys_dist * 0.15
        if score < best_score then
            best_score = score
            best = part
            best_char = ch
        end
    end
    locked_target, locked_char = best, best_char
    return best, best_char
end

-- ── predicción real ───────────────────────────────────────────
local last_pos = {}
local last_vel = {}
local function predict(part)
    local root_ = part.Parent and part.Parent:FindFirstChild("HumanoidRootPart")
    if not root_ then return part.Position end
    local key = part
    local vel = root_.AssemblyLinearVelocity
    local prev = last_vel[key]
    local accel = prev and (vel - prev) or Vector3.zero
    last_vel[key] = vel

    -- tiempo de vuelo estimado (studs / velocidad de bala típica ~500)
    local my_root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local dist = my_root and (part.Position - my_root.Position).Magnitude or 50
    local t = dist / 500

    local predicted = part.Position
        + vel * (t * CFG.pred_factor)
        + accel * (0.5 * t * t)
    return predicted
end

-- ── aimbot core: mousemoverel ────────────────────────────────
local holding = false

-- en Delta, mousemoverel mueve la cámara como input real
-- (convierte delta de mundo a delta de píxeles)
local function move_camera_to(target_pos, strength)
    local cam_pos = Camera.CFrame.Position
    local current_dir = Camera.CFrame.LookVector
    local desired_dir = (target_pos - cam_pos).Unit

    local dot = current_dir:Dot(desired_dir)
    dot = math.clamp(dot, -1, 1)
    local angle = math.acos(dot)
    if angle < 0.001 then return end

    -- delta en píxeles proporcional al ángulo y al FOV de la cámara
    local fov_rad = math.rad(Camera.FieldOfView)
    local px_per_rad = Camera.ViewportSize.Y / fov_rad
    local dx = (desired_dir.X - current_dir.X) * px_per_rad * strength
    local dy = -(desired_dir.Y - current_dir.Y) * px_per_rad * strength

    if HAS_MOUSE then
        mousemoverel(dx, dy)
    else
        -- fallback: rotación de cámara directa (menos potente pero funciona sin Delta)
        local goal = CFrame.new(cam_pos, target_pos)
        Camera.CFrame = Camera.CFrame:Lerp(goal, strength)
    end
end

RunService.RenderStepped:Connect(function(dt)
    if not CFG.enabled or not holding then return end
    local target = pick_target()
    if not target then return end
    local aim = predict(target)
    move_camera_to(aim, CFG.snap_speed)

    -- auto-fire
    if CFG.auto_fire and HAS_CLICK then
        local now = tick()
        if (now - (CFG._last_fire or 0)) >= CFG.fire_cooldown then
            pcall(mouse1click)
            CFG._last_fire = now
        end
    end
end)

-- ── GUI ───────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "core"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 76, 0, 76)
btn.Position = UDim2.new(1, -90, 0.5, -38)
btn.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
btn.BackgroundTransparency = 0.2
btn.TextColor3 = Color3.new(1, 1, 1)
btn.TextScaled = true
btn.Font = Enum.Font.GothamBold
btn.Text = "AIM"
btn.BorderSizePixel = 0
btn.AutoButtonColor = false
btn.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = btn

local auto = Instance.new("TextButton")
auto.Size = UDim2.new(0, 52, 0, 52)
auto.Position = UDim2.new(1, -82, 0.5, -110)
auto.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
auto.BackgroundTransparency = 0.2
auto.TextColor3 = Color3.new(1, 1, 1)
auto.TextScaled = true
auto.Font = Enum.Font.GothamBold
auto.Text = "AF"
auto.BorderSizePixel = 0
auto.AutoButtonColor = false
auto.Parent = gui
Instance.new("UICorner").Parent = auto
auto.UICorner.CornerRadius = UDim.new(1, 0)

btn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then
        holding = true
        btn.BackgroundColor3 = Color3.fromRGB(0, 220, 120)
    end
end)
btn.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then
        holding = false
        btn.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
    end
end)
auto.MouseButton1Click:Connect(function()
    CFG.auto_fire = not CFG.auto_fire
    auto.BackgroundColor3 = CFG.auto_fire and Color3.fromRGB(160, 60, 0) or Color3.fromRGB(30, 30, 30)
end)

print(("[aim-hard] %s | mousemoverel=%s | click=%s | expand=%.1f")
    :format(GAME, tostring(HAS_MOUSE), tostring(HAS_CLICK), CFG.hitbox_expand))
