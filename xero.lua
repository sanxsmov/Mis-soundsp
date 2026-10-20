-- ==========================================
-- XERO AUTOSHOOT (Visión 360° sin atravesar paredes)
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Interfaz rápida
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "XeroAutoShoot360"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 150, 0, 40)
btn.Position = UDim2.new(0, 20, 0, 100)
btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
btn.Text = "AutoShoot 360: OFF"
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Font = Enum.Font.GothamBold
btn.Parent = ScreenGui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = btn

local autoShootEnabled = false
btn.MouseButton1Click:Connect(function()
    autoShootEnabled = not autoShootEnabled
    btn.Text = autoShootEnabled and "AutoShoot 360: ON" or "AutoShoot 360: OFF"
    btn.BackgroundColor3 = autoShootEnabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(30, 30, 30)
end)

-- Lógica del AutoShoot 360
RunService.Heartbeat:Connect(function()
    if not autoShootEnabled then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local closestDist = math.huge
    local closestEnemy = nil

    -- Buscamos al enemigo más cercano en un radio de 300 studs
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local eHum = p.Character:FindFirstChild("Humanoid")
            
            -- Comprobamos que esté vivo
            if eHum and eHum.Health > 0 then
                local eHrp = p.Character.HumanoidRootPart
                local dist = (eHrp.Position - hrp.Position).Magnitude
                
                if dist < 300 and dist < closestDist then
                    -- Comprobamos si hay paredes entre nosotros y él
                    local params = RaycastParams.new()
                    params.FilterDescendantsInstances = {char, Camera}
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    
                    -- El rayo sale de NUESTRO personaje hacia el enemigo
                    local result = workspace:Raycast(hrp.Position, eHrp.Position - hrp.Position, params)
                    
                    -- Si el rayo toca al enemigo (o no toca nada), significa que está a la vista
                    if not result or result.Instance:IsDescendantOf(p.Character) then
                        closestDist = dist
                        closestEnemy = eHrp
                    end
                end
            end
        end
    end

    -- Si encontramos a alguien a la vista (aunque no lo miremos), disparamos
    if closestEnemy then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function()
                tool:Activate() 
            end)
        end
    end
end)
