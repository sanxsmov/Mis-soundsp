-- LocalScript: Carga Automática de MP3 desde GitHub (sanxsmov/Mis-soundsp)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- Detectar la función de petición compatible de tu ejecutor
local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request

-- =================================================================
-- 1. LECTURA DE LA API DE GITHUB
-- =================================================================
local GitHubUser = "sanxsmov"
local RepoName = "Mis-soundsp"
local FolderPath = "sounds"

local ApiURL = "https://api.github.com/repos/" .. GitHubUser .. "/" .. RepoName .. "/contents/" .. FolderPath
local RawBaseURL = "https://raw.githubusercontent.com/" .. GitHubUser .. "/" .. RepoName .. "/main/" .. FolderPath .. "/"

local AvailableSounds = {}
local SoundURLs = {}

local function fetchGitHubSounds()
    if not httpRequest then
        warn("Tu ejecutor no soporta funciones de 'request'.")
        return
    end

    -- Realizamos la petición HTTP incluyendo el User-Agent obligatorio para GitHub
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
    else
        warn("Error al conectar con la API de GitHub. Código:", response and response.StatusCode)
    end

    if #AvailableSounds == 0 then
        table.insert(AvailableSounds, "Sin Audios")
        SoundURLs["Sin Audios"] = ""
    end
end

-- Ejecutar la lectura de audios
fetchGitHubSounds()

-- Configuración de sonidos elegidos
local SelectedSounds = {
    Disparar = { Name = AvailableSounds[1], URL = SoundURLs[AvailableSounds[1]], Enabled = true },
    Saltar   = { Name = AvailableSounds[1], URL = SoundURLs[AvailableSounds[1]], Enabled = true },
    Matar    = { Name = AvailableSounds[1], URL = SoundURLs[AvailableSounds[1]], Enabled = true }
}

-- Caché local
local SoundCache = {}

-- =================================================================
-- 2. DESCARGA CON WRITEFILE Y CONVERSIÓN CON GETCUSTOMASSET
-- =================================================================
local function playAudioUrl(url)
    if not url or url == "" then return end

    local soundAssetId = SoundCache[url]

    if not soundAssetId then
        local sanitizeName = url:match("([^/]+)%.mp3$") or ("sound_" .. tick())
        local fileName = "sanxsmov_" .. sanitizeName .. ".mp3"

        if writefile and readfile and getcustomasset then
            if not isfile(fileName) then
                local audioData = game:HttpGet(url)
                writefile(fileName, audioData)
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
-- 3. INTERFAZ GRÁFICA (GUI FLOTANTE)
-- =================================================================
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SanxsmovAudioMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Botón Flotante para Abrir/Cerrar
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 110, 0, 40)
toggleButton.Position = UDim2.new(0.02, 0, 0.4, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Text = "🔊 Audio Menu"
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 15
toggleButton.Parent = screenGui

-- Frame Principal
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
titleLabel.Text = "Sounds (" .. #AvailableSounds .. " MP3s detectados)"
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 15
titleLabel.Parent = mainFrame

local function createConfigRow(actionName, actionKey, yOffset)
    -- Botón ON/OFF
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 90, 0, 32)
    toggleBtn.Position = UDim2.new(0.03, 0, 0, yOffset)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Text = actionName .. ": ON"
    toggleBtn.Font = Enum.Font.SourceSans
    toggleBtn.TextSize = 13
    toggleBtn.Parent = mainFrame

    -- Botón Selector de Audio
    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 135, 0, 32)
    selectBtn.Position = UDim2.new(0.33, 0, 0, yOffset)
    selectBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectBtn.Text = AvailableSounds[1] or "Sin Audios"
    selectBtn.Font = Enum.
