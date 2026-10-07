-- LocalScript: Nevada v2 (Macro + Sonidos)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- Lista fija de audios de sanxsmov para evitar congelamientos de API
local RawBaseURL = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/sounds/"

local AvailableSounds = {
    "Ningun Audio",
    "Skeet",
    "Hitmarker",
    "Rust",
    "Neverlose",
    "TF2"
}

local SoundURLs = {
    ["Ningun Audio"] = "",
    ["Skeet"] = RawBaseURL .. "Skeet.mp3",
    ["Hitmarker"] = RawBaseURL .. "Hitmarker.mp3",
    ["Rust"] = RawBaseURL .. "Rust.mp3",
    ["Neverlose"] = RawBaseURL .. "Neverlose.mp3",
    ["TF2"] = RawBaseURL .. "TF2.mp3"
}

local SelectedSounds = {
    Disparar = { Name = AvailableSounds[2], URL = SoundURLs[AvailableSounds[2]], Enabled = true },
    Saltar   = { Name = AvailableSounds[2], URL = SoundURLs[AvailableSounds[2]], Enabled = true },
    Matar    = { Name = AvailableSounds[2], URL = SoundURLs[AvailableSounds[2]], Enabled = true }
}

-- Configuración de Macros
local SelectedMacros = {
    Pistola  = { Enabled = false, Delay = 0.01 },
    Cuchillo = { Enabled = false, Delay = 0.01 }
}

local SoundCache = {}

local function playAudioUrl(url)
    if not url or url == "" then return end

    local soundAssetId = SoundCache[url]

    if not soundAssetId then
        local sanitizeName = url:match("([^/]+)%.mp3$") or ("sound_" .. tick())
        local fileName = "sanxsmov_" .. sanitizeName .. ".mp3"

        if writefile and readfile and getcustomasset then
            if not isfile(fileName) then
                local success, audioData = pcall(function() return game:HttpGet(url) end)
                if success and audioData then
                    writefile(fileName, audioData)
                else
                    return
                end
            end
            soundAssetId = getcustomasset(fileName)
            SoundCache[url] = soundAssetId
        else
            soundAssetId = url
        end
    end

    local sound = Instance.new("Sound")
    sound.SoundId = soundAssetId
    sound.Volume = 1
    sound.Parent = SoundService
    sound:Play()

    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

-- LÓGICA DE MACRO (Pistola y Cuchillo)
local isMacroRunning = false

local function runMacro(toolType)
    if isMacroRunning then return end
    
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local backpack = player:FindFirstChild("Backpack")
    
    if not hum or hum.Health <= 0 then return end
    isMacroRunning = true

    -- Equipar arma si está en el inventario
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool and backpack then
        local foundTool = backpack:FindFirstChildOfClass("Tool")
        if foundTool then
            hum:EquipTool(foundTool)
            task.wait(0.02)
            tool = foundTool
        end
    end

    -- Usar la herramienta (Macro rápida)
    if tool then
        tool:Activate()
    end

    task.wait(SelectedMacros[toolType].Delay)
    isMacroRunning = false
end

-- INTERFAZ GRÁFICA (UI)
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("SanxsmovAudioMenu") then
    playerGui.SanxsmovAudioMenu:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SanxsmovAudioMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Botón Flotante
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 120, 0, 42)
toggleButton.Position = UDim2.new(0.02, 0, 0.4, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
toggleButton.TextColor3 = Color3.fromRGB(0, 220, 255)
toggleButton.Text = "🔊 Nevada v2"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 13
toggleButton.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleButton

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(0, 220, 255)
toggleStroke.Thickness = 1.5
toggleStroke.Parent = toggleButton

-- Ventana Principal
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 350, 0, 360)
mainFrame.Position = UDim2.new(0.35, 0, 0.25, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 10)
frameCorner.Parent = mainFrame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
titleBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -15, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Text = "⚡ Nevada v2 - Hub"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Arrastrar UI
local dragging, dragInput, dragStart, startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Creador de filas de sonido
local function createConfigRow(actionName, actionKey, yOffset)
    local rowFrame = Instance.new("Frame")
    rowFrame.Size = UDim2.new(0.92, 0, 0, 48)
    rowFrame.Position = UDim2.new(0.04, 0, 0, yOffset)
    rowFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    rowFrame.Parent = mainFrame

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = rowFrame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 95, 0, 32)
    toggleBtn.Position = UDim2.new(0.03, 0, 0.16, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 90)
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Text = actionName .. ": ON"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 12
    toggleBtn.Parent = rowFrame

    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 130, 0, 32)
    selectBtn.Position = UDim2.new(0.35, 0, 0.16, 0)
    selectBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    selectBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
    selectBtn.Text = SelectedSounds[actionKey].Name
    selectBtn.Font = Enum.Font.Gotham
    selectBtn.TextSize = 11
    selectBtn.Parent = rowFrame

    local testBtn = Instance.new("TextButton")
    testBtn.Size = UDim2.new(0, 65, 0, 32)
    testBtn.Position = UDim2.new(0.77, 0, 0.16, 0)
    testBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
    testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    testBtn.Text = "▶ Test"
    testBtn.Font = Enum.Font.GothamBold
    testBtn.TextSize = 11
    testBtn.Parent = rowFrame

    toggleBtn.MouseButton1Click:Connect(function()
        SelectedSounds[actionKey].Enabled = not SelectedSounds[actionKey].Enabled
        local enabled = SelectedSounds[actionKey].Enabled
        toggleBtn.Text = actionName .. (enabled and ": ON" or ": OFF")
        toggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(35, 160, 90) or Color3.fromRGB(200, 50, 60)
    end)

    local currentIndex = 2
    selectBtn.MouseButton1Click:Connect(function()
        currentIndex = (currentIndex % #AvailableSounds) + 1
        local selectedName = AvailableSounds[currentIndex]
        selectBtn.Text = selectedName
        SelectedSounds[actionKey].Name = selectedName
        SelectedSounds[actionKey].URL = SoundURLs[selectedName]
    end)

    testBtn.MouseButton1Click:Connect(function()
        playAudioUrl(SelectedSounds[actionKey].URL)
    end)
end

-- Creador de filas de macro
local function createMacroRow(macroName, macroKey, keyBindText, yOffset)
    local rowFrame = Instance.new("Frame")
    rowFrame.Size = UDim2.new(0.92, 0, 0, 48)
    rowFrame.Position = UDim2.new(0.04, 0, 0, yOffset)
    rowFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    rowFrame.Parent = mainFrame

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = rowFrame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 140, 0, 32)
    toggleBtn.Position = UDim2.new(0.03, 0, 0.16, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Text = macroName .. ": OFF"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 12
    toggleBtn.Parent = rowFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 130, 0, 32)
    label.Position = UDim2.new(0.5, 0, 0.16, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(0, 220, 255)
    label.Text = keyBindText
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.Parent = rowFrame

    toggleBtn.MouseButton1Click:Connect(function()
        SelectedMacros[macroKey].Enabled = not SelectedMacros[macroKey].Enabled
        local enabled = SelectedMacros[macroKey].Enabled
        toggleBtn.Text = macroName .. (enabled and ": ON" or ": OFF")
        toggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(35, 160, 90) or Color3.fromRGB(200, 50, 60)
    end)
end

createConfigRow("Disparar", "Disparar", 52)
createConfigRow("Saltar", "Saltar", 112)
createConfigRow("Matar", "Matar", 172)

createMacroRow("Macro Disparo", "Pistola", "[Click Izquierdo]", 232)
createMacroRow("Macro Cuchillo", "Cuchillo", "[Tecla E]", 292)

toggleButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

-- Teclas que activan las macros
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if SelectedMacros.Pistola.Enabled and input.UserInputType == Enum.UserInputType.MouseButton1 then
        runMacro("Pistola")
    end

    if SelectedMacros.Cuchillo.Enabled and input.KeyCode == Enum.KeyCode.E then
        runMacro("Cuchillo")
    end
end)

-- Conexión de Eventos de Disparo en la partida
local boundTools = {}

local function bindTool(tool)
    if tool:IsA("Tool") and not boundTools[tool] then
        boundTools[tool] = true
        tool.Activated:Connect(function()
            if SelectedSounds.Disparar.Enabled then
                playAudioUrl(SelectedSounds.Disparar.URL)
            end
        end)
    end
end

local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Jumping:Connect(function(isJumping)
            if isJumping and SelectedSounds.Saltar.Enabled then
                playAudioUrl(SelectedSounds.Saltar.URL)
            end
        end)
    end

    char.ChildAdded:Connect(bindTool)
    for _, item in ipairs(char:GetChildren()) do
        bindTool(item)
    end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)
