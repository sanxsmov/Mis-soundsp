-- ==========================================
-- PARTE 1: HOOK ALTERNATIVO PARA DELTA
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local aimHookTarget = nil
local oldNamecall

-- Intentamos obtener la función original de forma segura
pcall(function()
    local mt = getrawmetatable(game)
    -- Desbloqueamos la tabla antes de leerla
    if setreadonly then setreadonly(mt, false) end
    oldNamecall = mt.__namecall
    if setreadonly then setreadonly(mt, true) end
end)

-- Si no pudimos obtener la función, usamos hookmetamethod como plan B
if not oldNamecall then
    pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(...) return ... end)
    end)
end

-- Hook principal
local function hookFunc(self, ...)
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

-- Aplicamos el hook con protección
pcall(function()
    hookmetamethod(game, "__namecall", hookFunc)
end)

-- Bucle del AutoShoot
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local closestDist = math.huge
    local closestPart = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
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
                        closestPart = p.Character:FindFirstChild("Head") or eHrp
                    end
                end
            end
        end
    end

    if closestPart then
        aimHookTarget = closestPart
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function() tool:Activate() end)
        end
    else
        aimHookTarget = nil
    end
end)

print("✅ Hook Alternativo Activado.")
