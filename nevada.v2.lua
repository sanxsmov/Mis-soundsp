-- LocalScript: Carga Automática de MP3 desde GitHub (sanxsmov/Mis-soundsp)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- Identificar la función de petición del ejecutor
local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request

-- Configuración de GitHub
local GitHubUser = "sanxsmov"
local RepoName = "Mis-soundsp"
local FolderPath = "sounds"

local ApiURL = "https://api.github.com/repos/" .. GitHubUser .. "/" .. RepoName .. "/contents/" .. FolderPath
local RawBaseURL = "https://raw.githubusercontent.com/" .. GitHubUser .. "/" .. RepoName .. "/main/" .. FolderPath .. "/"

local AvailableSounds = {}
local SoundURLs = {}

-- LECTURA SEGURA DE ARCHIVOS
local function fetchGitHubSounds()
    if httpRequest then
        pcall(function()
            local response = httpRequest({
                Url = ApiURL,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "RobloxApp/1.0"
                }
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

-- REPRODUCCIÓN DE AUDIO
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

-- INTERFAZ GRÁFICA (GUI)
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("SanxsmovAudioMenu") then
    playerGui.SanxsmovAudioMenu:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SanxsmovAudioMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 110, 0, 40)
toggleButton.Position = UDim2.new(0.02, 0, 0.4, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Text = "🔊 Menu Audio"
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 15
toggleButton.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 330, 0, 230)
mainFrame.Position = UDim2.new(0.02, 0, 0.46, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.Visible = false
mainFrame.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 35)
titleLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Text = "Sounds (" .. #AvailableSounds .. " MP3s)"
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 15
titleLabel.Parent = mainFrame

local function createConfigRow(actionName, actionKey, yOffset)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 90, 0, 32)
    toggleBtn.Position = UDim2.new(0.03, 0, 0, yOffset)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Text = actionName .. ": ON"
    toggleBtn.Font = Enum.Font.SourceSans
    toggleBtn.TextSize = 13
    toggleBtn.Parent = mainFrame

    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 135, 0, 32)
    selectBtn.Position = UDim2.new(0.33, 0, 0, yOffset)
    selectBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectBtn.Text = AvailableSounds[1] or "Ninguno"
    selectBtn.Font = Enum.Font.SourceSans
    selectBtn.TextSize = 12
    selectBtn.Parent = mainFrame

    local testBtn = Instance.new("TextButton")
    testBtn.Size = UDim2.new(0, 70, 0, 32)
    testBtn.Position = UDim2.new(0.76, 0, 0, yOffset)
    testBtn.BackgroundColor3 = Color3.fromRGB(50, 110, 190)
    testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    testBtn.Text = "▶ Probar"
    testBtn.Font = Enum.Font.SourceSans
    testBtn.TextSize = 13
    testBtn.Parent = mainFrame

    toggleBtn.MouseButton1Click:Connect(function()
        SelectedSounds[actionKey].Enabled = not SelectedSounds[actionKey].Enabled
        local enabled = SelectedSounds[actionKey].Enabled
        toggleBtn.Text = actionName .. (enabled and ": ON" or ": OFF")
        toggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(180, 50, 50)
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

createConfigRow("Disparar", "Disparar", 50)
createConfigRow("Saltar", "Saltar", 95)
createConfigRow("Matar", "Matar", 140)

toggleButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

-- ACCIONES EN JUEGO
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if SelectedSounds.Disparar.Enabled then
            playAudioUrl(SelectedSounds.Disparar.URL)
        end
    end
end)

local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Jumping:Connect(function(isJumping)
            if isJumping and SelectedSounds.Saltar.Enabled then
                playAudioUrl(SelectedSounds.Saltar.URL)
            end
        end)
    end
end

if player.Character then
    setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

local function trackKill(otherHumanoid)
    otherHumanoid.Died:Connect(function()
        local creator = otherHumanoid:FindFirstChild("creator")
        if creator and creator.Value == player then
            if SelectedSounds.Matar.Enabled then
                playAudioUrl(SelectedSounds.Matar.URL)
            end
        end
    end)
end

workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Humanoid") and descendant.Parent ~= player.Character then
        trackKill(descendant)
    end
end)
