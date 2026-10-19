-- ==========================================
-- XERO INDEPENDIENTE: BYPASS + AUTO-SHOOT + SILENT AIM + ESP (SOLO BRILLO)
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==========================================
-- 1. EL BYPASS (ANTI-CHEAT)
-- ==========================================
pcall(function()
    local setthread = setthreadidentity or set_thread_identity or setidentity
    if setthread then pcall(function() setthread(8) end) end
end)

local my_hook_function = nil
local old_getgc = getgc
local old_getinfo = debug.getinfo

if old_getgc and old_getinfo and newcclosure then
    getgc = newcclosure(function(includeTables)
        local gc = old_getgc(includeTables)
        local filtered = {}
        for i, v in pairs(gc) do
            if v ~= my_hook_function then
                table.insert(filtered, v)
            end
        end
        return filtered
    end)

    debug.getinfo = newcclosure(function(func, what)
        if func == my_hook_function then return nil end
        return old_getinfo(func, what)
    end)
end

-- ==========================================
-- 2. VARIABLES DE ESTADO
-- ==========================================
local autoShootEnabled = false
local silentAimEnabled = false
local espEnabled = false
local targetPartName = "Head"
local aimHookTarget = nil

-- ==========================================
-- 3. INTERFAZ (BOTONES FLOTANTES)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XeroAutoShootUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local function createBtn(text, yPos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 130, 0, 40)
    btn.Position = UDim2.new(0, 20, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    btn.Text = text .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Parent = btn
    
    return btn
end

local asBtn = createBtn("AutoShoot", 100)
local saBtn = createBtn("SilentAim", 150)
local espBtn = createBtn("ESP", 200)

asBtn.MouseButton1Click:Connect(function()
    autoShootEnabled = not autoShootEnabled
    asBtn.Text = autoShootEnabled and "AutoShoot: ON" or "AutoShoot: OFF"
    asBtn.BackgroundColor3 = autoShootEnabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(15, 15, 15)
end)

saBtn.MouseButton1Click:Connect(function()
    silentAimEnabled = not silentAimEnabled
    saBtn.Text = silentAimEnabled and "SilentAim: ON" or "SilentAim: OFF"
    saBtn.BackgroundColor3 = silentAimEnabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(15, 15, 15)
end)

espBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    espBtn.Text = espEnabled and "ESP: ON" or "ESP: OFF"
    espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(15, 15, 15)
end)

-- ==========================================
-- 4. EL HOOK DEL SILENT AIM
-- ==========================================
local oldNamecall

my_hook_function = function(self, ...)
    if not checkcaller() and aimHookTarget and aimHookTarget.Parent then
        local method = getnamecallmethod()
        if self == workspace and method == "Raycast" then
            local origin, direction, params = ...
            if typeof(direction) == "Vector3" and direction.Magnitude > 5 then
                local newDir = (aimHookTarget.Position - origin).Unit * 5000
                return oldNamecall(self, origin, newDir, params)
            end
        end
    end
    return oldNamecall(self, ...)
end

pcall(function()
    if newcclosure then
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(my_hook_function))
    else
        oldNamecall = hookmetamethod(game, "__namecall", my_hook_function)
    end
end)

-- ==========================================
-- 5. LÓGICA DEL ESP (Solo Resplandor, sin textos)
-- ==========================================
local espFolder = Instance.new("Folder")
espFolder.Name = "XeroESP"
espFolder.Parent = screenGui
local activeESPs = {}

local function updateESP()
    if not espEnabled then
        for plr, highlight in pairs(activeESPs) do
            if highlight then highlight:Destroy() end
            activeESPs[plr] = nil
        end
        return
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local char = p.Character
            local hum = char:FindFirstChild("Humanoid")
            
            -- Si está vivo y es enemigo
            if hum and hum.Health > 0 and (LocalPlayer.Team == nil or p.Team == nil or LocalPlayer.Team ~= p.Team) then
                if not activeESPs[p] then
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "XeroHighlight"
                    highlight.Adornee = char
                    highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Color rojo de relleno
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255) -- Borde blanco
                    highlight.FillTransparency = 0.5 -- Transparencia del relleno
                    highlight.OutlineTransparency = 0 -- Borde sólido
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Se ve a través de paredes
                    highlight.Parent = espFolder
                    
                    activeESPs[p] = highlight
                end
            else
                -- Si muere o cambia de equipo, lo borramos
                if activeESPs[p] then
                    activeESPs[p]:Destroy()
                    activeESPs[p] = nil
                end
            end
        end
    end
end

-- ==========================================
-- 6. LÓGICA DEL AUTO-SHOOT
-- ==========================================
local function isEnemy(p)
    if p == LocalPlayer then return false end
    if p.Team and LocalPlayer.Team then return p.Team ~= LocalPlayer.Team end
    return true
end

RunService.Heartbeat:Connect(function()
    -- Actualizamos el ESP
    updateESP()

    -- Lógica de disparo
    if not autoShootEnabled and not silentAimEnabled then
        aimHookTarget = nil
        return
    end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local tool = char:FindFirstChildOfClass("Tool")
    if not hrp or not tool or not tool:FindFirstChild("Handle") then return end

    local closestDist = math.huge
    local closestPart = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local eHum = p.Character:FindFirstChild("Humanoid")
            if eHum and eHum.Health > 0 then
                local eHrp = p.Character.HumanoidRootPart
                local screenPos, onScreen = Camera:WorldToViewportPoint(eHrp.Position)
                
                if onScreen then
                    local dist = (eHrp.Position - hrp.Position).Magnitude
                    if dist < 300 and dist < closestDist then
                        local params = RaycastParams.new()
                        params.FilterDescendantsInstances = {char, Camera}
                        params.FilterType = Enum.RaycastFilterType.Exclude
                        local result = workspace:Raycast(Camera.CFrame.Position, eHrp.Position - Camera.CFrame.Position, params)
                        
                        if not result or result.Instance:IsDescendantOf(p.Character) then
                            closestDist = dist
                            closestPart = p.Character:FindFirstChild(targetPartName) or eHrp
                        end
                    end
                end
            end
        end
    end

    if closestPart then
        if silentAimEnabled then aimHookTarget = closestPart end
        if autoShootEnabled then
            pcall(function()
                tool:Activate()
                task.wait(0.05)
                tool:Deactivate()
            end)
        end
    else
        aimHookTarget = nil
    end
end)
