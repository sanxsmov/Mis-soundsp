
-- ==========================================
-- XERO DEFINITIVO (Menú + ESP + Sonidos + SilentAim Protegido)
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Limpiar menús viejos y el botón de prueba
if LocalPlayer.PlayerGui:FindFirstChild("XeroCompleteUI") then
    LocalPlayer.PlayerGui.XeroCompleteUI:Destroy()
end
if LocalPlayer.PlayerGui:FindFirstChild("ScreenGui") then
    LocalPlayer.PlayerGui.ScreenGui:Destroy()
end

-- ==========================================
-- 1. INTERFAZ
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "XeroCompleteUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 400)
MainFrame.Position = UDim2.new(0, 50, 0, 50)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
local UICorner = Instance.new("UICorner"); UICorner.CornerRadius = UDim.new(0, 10); UICorner.Parent = MainFrame

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TopBar.Parent = MainFrame
local TopCorner = Instance.new("UICorner"); TopCorner.CornerRadius = UDim.new(0, 10); TopCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Xero Definitivo"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Parent = TopBar
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, 0, 0, 30)
TabContainer.Position = UDim2.new(0, 0, 0, 30)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = MainFrame

local function createTab(name, xOffset)
    local tab = Instance.new("TextButton")
    tab.Size = UDim2.new(0, 90, 1, 0)
    tab.Position = UDim2.new(0, xOffset, 0, 0)
    tab.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    tab.Text = name
    tab.TextColor3 = Color3.fromRGB(255, 255, 255)
    tab.Font = Enum.Font.GothamSemibold
    tab.TextSize = 12
    tab.Parent = TabContainer
    return tab
end

local CombatTabBtn = createTab("Combat", 0)
local VisualTabBtn = createTab("Visuals", 90)
local SoundTabBtn = createTab("Sonidos", 180)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -80)
Content.Position = UDim2.new(0, 10, 0, 70)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local function clearContent()
    for _, child in ipairs(Content:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
end

local function createToggle(text, yPos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 35)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.Text = text .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Parent = Content
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 5); corner.Parent = btn
    return btn
end

-- ==========================================
-- 2. VARIABLES Y LÓGICA DE PESTAÑAS
-- ==========================================
local autoShootEnabled, silentAimEnabled, espEnabled, soundEnabled = false, false, false, false
local targetPartName = "Head"

local function loadCombatTab()
    clearContent()
    local asBtn = createToggle("AutoShoot", 10)
    local saBtn = createToggle("SilentAim (Raycast)", 55)
    local partBtn = createToggle("Target: Head", 100)
    
    asBtn.MouseButton1Click:Connect(function()
        autoShootEnabled = not autoShootEnabled
        asBtn.Text = autoShootEnabled and "AutoShoot: ON" or "AutoShoot: OFF"
        asBtn.BackgroundColor3 = autoShootEnabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(30, 30, 30)
    end)
    saBtn.MouseButton1Click:Connect(function()
        silentAimEnabled = not silentAimEnabled
        saBtn.Text = silentAimEnabled and "SilentAim: ON" or "SilentAim: OFF"
        saBtn.BackgroundColor3 = silentAimEnabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(30, 30, 30)
    end)
    partBtn.MouseButton1Click:Connect(function()
        if targetPartName == "Head" then targetPartName = "HumanoidRootPart"; partBtn.Text = "Target: Body"
        else targetPartName = "Head"; partBtn.Text = "Target: Head" end
    end)
end

local function loadVisualTab()
    clearContent()
    local espBtn = createToggle("ESP (Brillo Rojo)", 10)
    espBtn.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        espBtn.Text = espEnabled and "ESP: ON" or "ESP: OFF"
        espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(30, 30, 30)
    end)
end

local function loadSoundTab()
    clearContent()
    local sndBtn = createToggle("Sonido al Disparar", 10)
    sndBtn.MouseButton1Click:Connect(function()
        soundEnabled = not soundEnabled
        sndBtn.Text = soundEnabled and "Sonido: ON" or "Sonido: OFF"
        sndBtn.BackgroundColor3 = soundEnabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(30, 30, 30)
    end)
end

CombatTabBtn.MouseButton1Click:Connect(loadCombatTab)
VisualTabBtn.MouseButton1Click:Connect(loadVisualTab)
SoundTabBtn.MouseButton1Click:Connect(loadSoundTab)
loadCombatTab()

-- ==========================================
-- 3. ESP
-- ==========================================
local espFolder = Instance.new("Folder"); espFolder.Parent = ScreenGui
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
            local char = p.Character; local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if not activeESPs[p] then
                    local highlight = Instance.new("Highlight")
                    highlight.Adornee = char
                    highlight.FillColor = Color3.fromRGB(255, 0, 0)
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.5
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = espFolder
                    activeESPs[p] = highlight
                end
            else
                if activeESPs[p] then activeESPs[p]:Destroy(); activeESPs[p] = nil end
            end
        end
    end
end

-- ==========================================
-- 4. SONIDO
-- ==========================================
local soundFolder = Instance.new("Folder"); soundFolder.Parent = workspace
local shootSound = Instance.new("Sound")
shootSound.SoundId = "rbxassetid://131961136" 
shootSound.Volume = 1
shootSound.Parent = soundFolder

-- ==========================================
-- 5. HOOK DEL SILENT AIM (Protegido)
-- ==========================================
local aimHookTarget = nil
local hookSuccess = false

pcall(function()
    local oldNamecall
    local my_hook_function = function(self, ...)
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

    if newcclosure then 
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(my_hook_function))
    else 
        oldNamecall = hookmetamethod(game, "__namecall", my_hook_function) 
    end
    hookSuccess = true
end)

-- ==========================================
-- 6. AUTO-SHOOT
-- ==========================================
local function isEnemy(p)
    if p == LocalPlayer then return false end
    if p.Team and LocalPlayer.Team then return p.Team ~= LocalPlayer.Team end
    return true
end

RunService.Heartbeat:Connect(function()
    updateESP()
    if not autoShootEnabled and not silentAimEnabled then
        aimHookTarget = nil
        return 
    end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local closestDist = math.huge
    local closestPart = nil
    
    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local eHum = p.Character:FindFirstChild("Humanoid")
            if eHum and eHum.Health > 0 then
                local eHrp = p.Character.HumanoidRootPart
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

    if closestPart then
        -- Si el hook funcionó, activamos el Silent Aim
        if silentAimEnabled and hookSuccess then 
            aimHookTarget = closestPart 
        end
        
        -- Si el AutoShoot está activo, disparamos
        if autoShootEnabled then
            if not hookSuccess then
                -- Si el hook falló, usamos el método simple de mover cámara
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, closestPart.Position)
            end
            
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                pcall(function()
                    tool:Activate()
                    if soundEnabled then shootSound:Play() end
                end)
            end
        end
    else
        aimHookTarget = nil
    end
end)
