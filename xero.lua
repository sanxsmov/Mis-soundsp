-- ==========================================
-- PARTE 1: HOOK ESTILO XERO (Bypass Completo)
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- 1. Bypass de hilo de Xero (Esto es lo que hacía funcionar a Xero)
pcall(function()
    local setthread = setthreadidentity or set_thread_identity or setidentity
    if setthread then pcall(function() setthread(8) end) end
end)

-- 2. Ocultar el hook (Líneas exactas de tu captura)
local my_hook_function = nil
local old_getgc = getgc
local old_getinfo = debug.getinfo

if old_getgc and old_getinfo and newcclosure then
    getgc = newcclosure(function(includeTables)
        local gc = old_getgc(includeTables)
        local filtered = {}
        for i, v in pairs(gc) do
            if v ~= my_hook_function then table.insert(filtered, v) end
        end
        return filtered
    end)

    debug.getinfo = newcclosure(function(func, what)
        if func == my_hook_function then return nil end
        return old_getinfo(func, what)
    end)
end

-- 3. Hook del Raycast
local aimHookTarget = nil
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

-- 4. Aplicar el Hook de forma segura (Aquí está el truco para que no falle)
pcall(function()
    local mt = getrawmetatable(game)
    local oldSetReadonly = setreadonly
    oldSetReadonly(mt, false) -- Desbloquea la tabla
    oldNamecall = mt.__namecall
    mt.__namecall = newcclosure(my_hook_function)
    oldSetReadonly(mt, true) -- La vuelve a bloquear
end)

-- 5. Bucle del AutoShoot
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
            pcall(function()
                tool:Activate() 
            end)
        end
    else
        aimHookTarget = nil
    end
end)

print("✅ Xero Hook Activado (Bypass Completo).")
