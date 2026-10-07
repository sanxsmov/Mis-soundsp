-- LocalScript: UI Customizada Arrastrable & Sonidos en Partida (sanxsmov/Mis-soundsp)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request

local GitHubUser = "sanxsmov"
local RepoName = "Mis-soundsp"
local FolderPath = "sounds"

local ApiURL = "https://api.github.com/repos/" .. GitHubUser .. "/" .. RepoName .. "/contents/" .. FolderPath
local RawBaseURL = "https://raw.githubusercontent.com/" .. GitHubUser .. "/" .. RepoName .. "/main/" .. FolderPath .. "/"

local AvailableSounds = {}
local SoundURLs = {}

local function fetchGitHubSounds()
    if httpRequest then
        pcall(function()
            local response = httpRequest({
                Url = ApiURL,
                Method = "GET",
                Headers = { ["User-Agent"] = "RobloxApp/1.0" }
            })

            if response and (response.StatusCode == 200 or response.StatusDescription == "OK") then
                local data = HttpService:JSONDecode(response.Body)
                for _, item in ipairs(data) do
                    if item.type == "file" and item.name:lower():match("%.mp3$") then
                        local cleanName = item.name:gsub("%.mp3$", "")
                        table.insert(AvailableSounds, cleanName)
                        SoundURLs[cleanName] = item.download_url or (RawBaseURL .. item.name)
                    end
                end
            end
        end)
    end

    if #AvailableSounds == 0 then
        table.insert(AvailableSounds, "Ningun Audio")
        SoundURLs["Ningun Audio"] = ""
    end
end

fetchGitHubSounds()

local SelectedSounds = {
    Disparar = { Name = AvailableSounds[1], URL = SoundURLs[AvailableSounds[1]], Enabled = true },
    Saltar   = { Name = AvailableSounds[1], URL = SoundURLs[AvailableSounds[1]], Enabled = true },
    Matar    = { Name = AvailableSounds[1], URL = SoundURLs[AvailableSounds[1]], Enabled = true }
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

-- =================================================================
-- COMPROBACIÓN DE PARTIDA
-- =================================================================
local function isInMatch()
    local char = player.Character
    if not char then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end

    local hasWeapon = char:FindFirstChildOfClass("Tool") or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChildOfClass("Tool"))
    
    local inGameValue = player:FindFirstChild("InGame") or player:FindFirstChild("Playing")
    if inGameValue and inGameValue:IsA("BoolValue") then
        return inGameValue.Value
    end

    return hasWeapon ~= nil
end

-- =================================================================
-- INTERFAZ GUI MODERNA Y ARRASTRABLE (SANXSMOV)
-- =================================================================
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("SanxsmovAudioMenu") then
    playerGui.SanxsmovAudioMenu:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SanxsmovAudioMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Botón Flotante para Abrir/Cerrar
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 120, 0, 42)
toggleButton.Position = UDim2.new(0.02, 0, 0.4, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
toggleButton.TextColor3 = Color3.fromRGB(0, 220, 255)
toggleButton.Text = "🔊 sanxsmov UI"
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

-- Panel Principal
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 350, 0, 250)
mainFrame.Position = UDim2.new(0.35, 0, 0.3, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 10)
frameCorner.Parent = mainFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(45, 45, 55)
frameStroke.Thickness = 1.5
frameStroke.Parent = mainFrame

-- Barra de Título (Arrastrable)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -15, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Text = "⚡ sanxsmov Sound Hub"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local subTitle = Instance.new("TextLabel")
subTitle.Size = UDim2.new(0, 100, 1, 0)
subTitle.Position = UDim2.new(1, -110, 0, 0)
subTitle.BackgroundTransparency = 1
subTitle.TextColor3 = Color3.fromRGB(120, 120, 140)
subTitle.Text = #AvailableSounds .. " audios"
subTitle.Font = Enum.Font.Gotham
subTitle.TextSize = 11
subTitle.TextXAlignment = Enum.TextXAlignment.Right
subTitle.Parent = titleBar

-- SISTEMA DE ARRASTRE DE PANTALLA (DRAGGABLE)
local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

-- Creador de Filas Estilizadas
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

    local btnCorner1 = Instance.new("UICorner")
    btnCorner1.CornerRadius = UDim.new(0, 6)
    btnCorner1.Parent = toggleBtn

    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 130, 0, 32)
    selectBtn.Position = UDim2.new(0.35, 0, 0.16, 0)
    selectBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    selectBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
    selectBtn.Text = AvailableSounds[1] or "Ninguno"
    selectBtn.Font = Enum.Font.Gotham
    selectBtn.TextSize = 11
    selectBtn.Parent = rowFrame

    local btnCorner2 = Instance.new("UICorner")
    btnCorner2.CornerRadius = UDim.new(0, 6)
    btnCorner2.Parent = selectBtn

    local testBtn = Instance.new("TextButton")
    testBtn.Size = UDim2.new(0, 65, 0, 32)
    testBtn.Position = UDim2.new(0.77, 0, 0.16, 0)
    testBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
    testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    testBtn.Text = "▶ Test"
    testBtn.Font = Enum.Font.GothamBold
    testBtn.TextSize = 11
    testBtn.Parent = rowFrame

    local btnCorner3 = Instance.new("UICorner")
    btnCorner3.CornerRadius = UDim.new(0, 6)
    btnCorner3.Parent = testBtn

    toggleBtn.MouseButton1Click:Connect(function()
        SelectedSounds[actionKey].Enabled = not SelectedSounds[actionKey].Enabled
        local enabled = SelectedSounds[actionKey].Enabled
        toggleBtn.Text = actionName .. (enabled and ": ON" or ": OFF")
        toggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(35, 160, 90) or Color3.fromRGB(200, 50, 60)
    end)

    local currentIndex = 1
    selectBtn.MouseButton1Click:Connect(function()
        if #AvailableSounds == 0 then return end
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

createConfigRow("Disparar", "Disparar", 52)
createConfigRow("Saltar", "Saltar", 112)
createConfigRow("Matar", "Matar", 172)

toggleButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

-- =================================================================
-- MONITOREO DE EVENTOS EN PARTIDA
-- =================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if SelectedSounds.Disparar.Enabled and isInMatch() then
            playAudioUrl(SelectedSounds.Disparar.URL)
        end
    end
end)

local function setupPlayerMatchEvents(targetPlayer)
    local function setupChar(char)
        local hum = char:WaitForChild("Humanoid", 5)

        if targetPlayer == player and hum then
            hum.Jumping:Connect(function(isJumping)
                if isJumping and SelectedSounds.Saltar.Enabled and isInMatch() then
                    playAudioUrl(SelectedSounds.Saltar.URL)
                end
            end)
        end

        if hum then
            hum.Died:Connect(function()
                if SelectedSounds.Matar.Enabled and isInMatch() then
                    playAudioUrl(SelectedSounds.Matar.URL)
                end
            end)
        end
    end

    if targetPlayer.Character then setupChar(targetPlayer.Character) end
    targetPlayer.CharacterAdded:Connect(setupChar)
end

for _, p in ipairs(Players:GetPlayers()) do
    setupPlayerMatchEvents(p)
end

Players.PlayerAdded:Connect(setupPlayerMatchEvents)
