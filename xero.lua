-- ==========================================
-- SYNERGY SILENT AIM (Para Delta Móvil)
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Variables
local autoShootEnabled = false
local wallCheckEnabled = true

-- Interfaz (La misma que te pasé antes)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SilentAimUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 130)
MainFrame.Position = UDim2.new(0, 20, 0, 100)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
local UICorner = Instance.new("UICorner"); UICorner.CornerRadius = UDim.new(0, 10); UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ Silent Aim (Sin mover cámara)"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local function createToggle(text, yPos, defaultState)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, 35)
    container.Position = UDim2.new(0, 10, 0, yPos)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    container.Parent = MainFrame
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = container
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 30, 0, 15)
    toggle.Position = UDim2.new(1, -40, 0.5, -7.5)
    toggle.BackgroundColor3 = defaultState and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 60)
    toggle.Text = ""
    toggle.Parent = container
    local toggleCorner = Instance.new("UICorner"); toggleCorner.CornerRadius = UDim.new(1, 0); toggleCorner.Parent = toggle
    
    local state = defaultState
    toggle.MouseButton1Click:Connect(function()
        state = not state
        toggle.BackgroundColor3 = state and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 60)
        local circle = toggle:FindFirstChild("Circle")
        if circle then circle:Destroy() end
        if state then
            local c = Instance.new("Frame")
            c.Name = "Circle"
            c.Size = UDim2.new(0, 15, 0, 15)
            c.Position = UDim2.new(1, -15, 0, 0)
            c.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            c.Parent = toggle
            local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(1, 0); cc.Parent = c
        end
    end)
    return toggle
end

local toggle1 = createToggle("Auto Shoot", 40, false)
local toggle2 = createToggle("Verificación de paredes", 80, true)

-- Actualizar variables
toggle1.MouseButton1Click:Connect(function()
    autoShootEnabled = toggle1.BackgroundColor3 == Color3.fromRGB(0, 200, 100)
end)
toggle2.MouseButton1Click:Connect(function()
    wallCheckEnabled = toggle2.BackgroundColor3 == Color3.fromRGB(0, 200, 100)
end)

-- Lógica
local function isEnemy(p)
    if p == LocalPlayer then return false end
    if p.Team and LocalPlayer.Team then return p.Team ~= LocalPlayer.Team end
    return true
end

RunService.Heartbeat:Connect(function()
    if not autoShootEnabled then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local closestDist = math.huge
    local closestEnemy = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local eHum = p.Character:FindFirstChild("Humanoid")
            if eHum and eHum.Health > 0 then
                local eHrp = p.Character.HumanoidRootPart
                local dist = (eHrp.Position - hrp.Position).Magnitude
                
                if dist < 300 and dist < closestDist then
                    local canSee = true
                    if wallCheckEnabled then
                        local params = RaycastParams.new()
                        params.FilterDescendantsInstances = {char, Camera}
                        params.FilterType = Enum.RaycastFilterType.Exclude
                        local result = workspace:Raycast(hrp.Position, eHrp.Position - hrp.Position, params)
                        if result and not result.Instance:IsDescendantOf(p.Character) then
                            canSee = false
                        end
                    end

                    if canSee then
                        closestDist = dist
                        closestEnemy = p.Character:FindFirstChild("Head") or eHrp
                    end
                end
            end
        end
    end

    if closestEnemy then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool and tool:FindFirstChild("Handle") then
            -- SILENT AIM (Truco de rotación del arma)
            -- Hacemos que el arma mire al enemigo sin mover tu cámara
            local originalCFrame = tool.Handle.CFrame
            
            -- Calculamos hacia dónde está el enemigo desde el arma
            local direction = (closestEnemy.Position - tool.Handle.Position).Unit
            tool.Handle.CFrame = CFrame.new(tool.Handle.Position, tool.Handle.Position + direction)
            
            -- Disparamos
            pcall(function()
                tool:Activate()
            end)
            
            -- (Opcional) Devolver el arma a su sitio, aunque visualmente no importa mucho
            -- tool.Handle.CFrame = originalCFrame 
        end
    end
end)
