-- ==========================================
-- BYPASS ANTI-CHEAT (MVS2)
-- ==========================================
local my_hook_function = nil
local old_getgc = getgc
local old_getinfo = debug.getinfo

getgc = newcclosure(function(includeTables)
    local gc_table = old_getgc(includeTables)
    local filtered_table = {}
    for i, v in pairs(gc_table) do
        if v ~= my_hook_function then
            table.insert(filtered_table, v)
        end
    end
    return filtered_table
end)

debug.getinfo = newcclosure(function(func, what)
    if func == my_hook_function then return nil end
    return old_getinfo(func, what)
end)local function playSound(url)
  if isUnloaded or type(url) ~= "string" or url == "" or url == "Ninguno" then return end
  
  local finalAssetId = url
  if string.find(url, "http") and not string.find(url, "rbxassetid://") then
    local asset = soundCache[url]
    if not asset then
      if writefile and isfile and getcustomasset then
        local name = "nevada_" .. (url:match("([^/]+)$") or "sound.mp3")
        name = name:gsub("[^%w%._%-]", "_")
        if not isfile(name) then
          local ok, body = pcall(function() return game:HttpGet(url) end)
          if not ok or type(body) ~= "string" or #body == 0 then return end
          local wrote = pcall(writefile, name, body); if not wrote then return end
        end
        local ok, result = pcall(getcustomasset, name)
        if not ok then return end
        asset = result
      else asset = url end
      soundCache[url] = asset
    end
    finalAssetId = asset
  elseif string.match(url, "^%d+$") then
    finalAssetId = "rbxassetid://" .. url
  end

  local s = Instance.new("Sound")
  s.SoundId = finalAssetId
  s.Volume = 1
  s.Parent = SoundService
  s:Play()
  s.Ended:Connect(function() s:Destroy() end)
  task.delay(20, function() if s.Parent then s:Destroy() end end)
end-- ==========================================
-- SILENT AIM PROTEGIDO (CON BYPASS Y VIRTUALUSER)
-- ==========================================
local autoAimActive = false
local autoShootCooldown = 0
local silentAimTarget = nil
local oldNamecall

-- Creamos la función del Hook y la guardamos en la variable del Bypass
my_hook_function = function(self, ...)
    if not checkcaller() and silentAimTarget and silentAimTarget.Parent then
        local method = getnamecallmethod()
        if self == workspace and method == "Raycast" then
            local origin, direction, params = ...
            if typeof(direction) == "Vector3" and direction.Magnitude > 5 then
                -- Jitter para que parezca humano
                local aimPos = silentAimTarget.Position + Vector3.new(math.random(-10, 10)/100, math.random(-10, 10)/100, math.random(-10, 10)/100)
                return oldNamecall(self, origin, (aimPos - origin).Unit * 5000, params)
            end
        end
    end
    return oldNamecall(self, ...)
end

-- Aplicamos el Hook con newcclosure para ocultarlo
if newcclosure then
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(my_hook_function))
else
    oldNamecall = hookmetamethod(game, "__namecall", my_hook_function)
end

-- Botón Flotante
local floatGui = Instance.new("ScreenGui"); floatGui.Name = "NevadaFloatGui"; floatGui.ResetOnSpawn = false; floatGui.Parent = playerGui
local floatBtn = Instance.new("TextButton"); floatBtn.Size = UDim2.new(0, 130, 0, 50); floatBtn.Position = UDim2.new(0, 20, 0.3, 0); floatBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15); floatBtn.Text = "Auto-Shoot: OFF"; floatBtn.TextColor3 = Color3.fromRGB(255, 50, 50); floatBtn.Font = Enum.Font.GothamBold; floatBtn.TextSize = 14; floatBtn.Parent = floatGui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(0, 10); Instance.new("UIStroke", floatBtn).Color = Color3.fromRGB(255, 255, 255)

local draggingFloat, dragStartFloat, startPosFloat = false, nil, nil
floatBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingFloat = true; dragStartFloat = input.Position; startPosFloat = floatBtn.Position end end)
UserInputService.InputChanged:Connect(function(input) if draggingFloat and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then local delta = input.Position - dragStartFloat; floatBtn.Position = UDim2.new(startPosFloat.X.Scale, startPosFloat.X.Offset + delta.X, startPosFloat.Y.Scale, startPosFloat.Y.Offset + delta.Y) end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingFloat = false end end)
floatBtn.MouseButton1Click:Connect(function() autoAimActive = not autoAimActive; if autoAimActive then floatBtn.Text = "Auto-Shoot: ON"; floatBtn.TextColor3 = Color3.fromRGB(0, 255, 100) else floatBtn.Text = "Auto-Shoot: OFF"; floatBtn.TextColor3 = Color3.fromRGB(255, 50, 50) end end)

local function isInLobby()
    for _, obj in ipairs(playerGui:GetDescendants()) do if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then local txt = obj.Text:lower(); if obj.Visible and (txt:find("tienda") or txt:find("shop") or txt:find("inventario") or txt:find("código") or txt:find("code")) then return true end end end
    local char = player.Character; if char and char:FindFirstChildOfClass("ForceField") then return true end
    return false
end
local function isGun(tool) if not tool or not tool:IsA("Tool") then return false end; local name = string.lower(tool.Name); if string.find(name, "knife") or string.find(name, "cuchillo") or string.find(name, "sword") or string.find(name, "espada") or string.find(name, "melee") then return false end; if string.find(name, "gun") or string.find(name, "pistol") or string.find(name, "revolver") or string.find(name, "sheriff") or string.find(name, "arma") or string.find(name, "colt") then return true end; return false end

RunService.Heartbeat:Connect(function()
    if not autoAimActive or not player.Character then return end
    if tick() - autoShootCooldown < 0.15 then return end 
    if isInLobby() then return end
    local char = player.Character; local hrp = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChildOfClass("Humanoid"); if not hrp or not hum then return end
    local armaEnMano = char:FindFirstChildOfClass("Tool"); if armaEnMano and not isGun(armaEnMano) then armaEnMano = nil end
    local closestEnemy = nil; local shortestDist = math.huge
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local enemyHum = otherPlayer.Character:FindFirstChildOfClass("Humanoid")
            if enemyHum and enemyHum.Health > 0 and (player.Team == nil or otherPlayer.Team == nil or player.Team ~= otherPlayer.Team) then
                local enemyHrp = otherPlayer.Character.HumanoidRootPart; local dist = (enemyHrp.Position - hrp.Position).Magnitude
                if dist < 300 and dist < shortestDist then
                    local raycastParams = RaycastParams.new(); raycastParams.FilterDescendantsInstances = {char, camera}; raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                    local result = workspace:Raycast(camera.CFrame.Position, (enemyHrp.Position - camera.CFrame.Position), raycastParams)
                    if not result or result.Instance:IsDescendantOf(otherPlayer.Character) then shortestDist = dist; closestEnemy = enemyHrp end
                end
            end
        end
    end
    if closestEnemy then
        if not armaEnMano then local backpack = player:FindFirstChildOfClass("Backpack"); if backpack then for _, item in ipairs(backpack:GetChildren()) do if isGun(item) then pcall(function() hum:EquipTool(item) end); task.wait(0.1); armaEnMano = item; break end end end end
        if armaEnMano and armaEnMano.Parent == char and isGun(armaEnMano) then
            silentAimTarget = closestEnemy
            -- Disparamos simulando un toque real
            pcall(function() 
                if VirtualUser then VirtualUser:CaptureController(); VirtualUser:ClickButton1(Vector2.new(0,0)) end
            end)
            task.wait(math.random(8, 15) / 100) 
            silentAimTarget = nil 
            autoShootCooldown = tick() 
        end
    else
        silentAimTarget = nil
    end
end)
