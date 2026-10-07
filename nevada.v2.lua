-- LocalScript: NEVADA HUB (Con lista de audios desplegable/scroll)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request

--------------------------------------------------------------------------------
-- CONFIGURACIÓN DE GITHUB
--------------------------------------------------------------------------------
local SCRIPT_NAME = "NEVADA | DUELS"
local ACTIVE_USERS = "108 activos"
local HUB_SUBTITLE = "NevadaHub"
local POWERED_BY = "POWERED BY SANXSMOV"

local GitHubUser = "sanxsmov"
local RepoName = "Mis-soundsp"
local FolderPath = "sounds"
local ImageFolder = "images"       
local ImageFileName = "lol.jpg" 

local RawBaseURL = "https://raw.githubusercontent.com/" .. GitHubUser .. "/" .. RepoName .. "/main/"
local ApiURL = "https://api.github.com/repos/" .. GitHubUser .. "/" .. RepoName .. "/contents/" .. FolderPath
local ImageURL = RawBaseURL .. ImageFolder .. "/" .. ImageFileName

--------------------------------------------------------------------------------
-- CARGA DE IMAGEN
--------------------------------------------------------------------------------
local function getCustomAssetImage(url, localName)
    if writefile and readfile and getcustomasset then
        if not isfile(localName) then
            local success, data = pcall(function() return game:HttpGet(url) end)
            if success and data then
                pcall(function() writefile(localName, data) end)
            end
        end
        return getcustomasset(localName)
    end
    return url
end

--------------------------------------------------------------------------------
-- ESTRUCTURA DE SONIDOS Y REPRODUCCIÓN
--------------------------------------------------------------------------------
local SoundList = {} -- Contendrá {Name = "Nombre", URL = "https://..."}
local ActiveSounds = {
    Disparar = { Name = "Ninguno", URL = "" },
    Saltar   = { Name = "Ninguno", URL = "" },
    Matar    = { Name = "Ninguno", URL = "" }
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
                if success and audioData then writefile(fileName, audioData) else return end
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
    sound.Ended:Connect(function() sound:Destroy() end)
end

--------------------------------------------------------------------------------
-- INTERFAZ GRÁFICA
--------------------------------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("XeroStyleNevadaUI") then
    playerGui.XeroStyleNevadaUI:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XeroStyleNevadaUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Botón Flotante Abrir/Cerrar
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 110, 0, 36)
toggleButton.Position = UDim2.new(0.02, 0, 0.3, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
toggleButton.TextColor3 = Color3.fromRGB(220, 220, 220)
toggleButton.Text = "⚡ " .. SCRIPT_NAME
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 10
toggleButton.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleButton

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(35, 35, 40)
toggleStroke.Parent = toggleButton

-- Ventana Principal
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 600, 0, 320)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -160)
mainFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 16)
frameCorner.Parent = mainFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(30, 30, 35)
frameStroke.Thickness = 1.2
frameStroke.Parent = mainFrame

-- Imagen de Fondo (lol.jpg)
local backgroundImage = Instance.new("ImageLabel")
backgroundImage.Size = UDim2.new(0.6, 0, 1, 0)
backgroundImage.Position = UDim2.new(0.4, 0, 0, 0)
backgroundImage.BackgroundTransparency = 1
backgroundImage.Image = getCustomAssetImage(ImageURL, "sanxsmov_" .. ImageFileName)
backgroundImage.ImageTransparency = 0.4
backgroundImage.ScaleType = Enum.ScaleType.Fit
backgroundImage.ZIndex = 1
backgroundImage.Parent = mainFrame

-- Texto Watermark Central
local watermarkText = Instance.new("TextLabel")
watermarkText.Size = UDim2.new(0, 260, 0, 40)
watermarkText.Position = UDim2.new(0.35, 0, 0.42, 0)
watermarkText.BackgroundTransparency = 1
watermarkText.TextColor3 = Color3.fromRGB(180, 180, 190)
watermarkText.TextTransparency = 0.3
watermarkText.Text = HUB_SUBTITLE
watermarkText.Font = Enum.Font.SpecialElite
watermarkText.TextSize = 36
watermarkText.ZIndex = 1
watermarkText.Parent = mainFrame

local subWatermark = Instance.new("TextLabel")
subWatermark.Size = UDim2.new(0, 260, 0, 20)
subWatermark.Position = UDim2.new(0.35, 0, 0.56, 0)
subWatermark.BackgroundTransparency = 1
subWatermark.TextColor3 = Color3.fromRGB(100, 100, 110)
subWatermark.Text = POWERED_BY
subWatermark.Font = Enum.Font.GothamBold
subWatermark.TextSize = 8
subWatermark.ZIndex = 1
subWatermark.Parent = mainFrame

-- Topbar Superior
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 45)
topBar.BackgroundTransparency = 1
topBar.ZIndex = 3
topBar.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(0, 15, 0, 10)
closeBtn.BackgroundTransparency = 1
closeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.ZIndex = 3
closeBtn.Parent = topBar

closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 200, 1, 0)
titleLabel.Position = UDim2.new(0, 48, 0, -2)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
titleLabel.Text = "<b>" .. SCRIPT_NAME .. "</b>  <font color=\"#666666\">" .. ACTIVE_USERS .. "</font>"
titleLabel.Font = Enum.Font.Gotham
titleLabel.TextSize = 11
titleLabel.RichText = true
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 3
titleLabel.Parent = topBar

-- Sidebar (Navegación Izquierda)
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 140, 1, -55)
sidebar.Position = UDim2.new(0, 12, 0, 45)
sidebar.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
sidebar.BackgroundTransparency = 0.2
sidebar.ZIndex = 2
sidebar.Parent = mainFrame

local sideCorner = Instance.new("UICorner")
sideCorner.CornerRadius = UDim.new(0, 12)
sideCorner.Parent = sidebar

local sideStroke = Instance.new("UIStroke")
sideStroke.Color = Color3.fromRGB(22, 22, 26)
sideStroke.Parent = sidebar

local function createCategoryLabel(text, yOffset)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.9, 0, 0, 15)
    lbl.Position = UDim2.new(0.08, 0, 0, yOffset)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(90, 90, 100)
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 8
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3
    lbl.Parent = sidebar
end

createCategoryLabel("PRINCIPAL", 12)
createCategoryLabel("PERSONAL", 175)

-- Panel de Contenido
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -170, 1, -55)
contentFrame.Position = UDim2.new(0, 160, 0, 45)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants = true
contentFrame.ZIndex = 2
contentFrame.Parent = mainFrame

local tabTitle = Instance.new("TextLabel")
tabTitle.Size = UDim2.new(1, 0, 0, 25)
tabTitle.Position = UDim2.new(0, 0, 0, 5)
tabTitle.BackgroundTransparency = 1
tabTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
tabTitle.Text = "Sounds"
tabTitle.Font = Enum.Font.GothamBold
tabTitle.TextSize = 14
tabTitle.TextXAlignment = Enum.TextXAlignment.Left
tabTitle.ZIndex = 3
tabTitle.Parent = contentFrame

--------------------------------------------------------------------------------
-- PESTAÑAS
--------------------------------------------------------------------------------
local tabs = {}
local tabButtons = {}

local function createTabButton(text, index, yOffset)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 28)
    btn.Position = UDim2.new(0.05, 0, 0, yOffset)
    btn.BackgroundColor3 = (index == 1) and Color3.fromRGB(20, 20, 24) or Color3.fromRGB(12, 12, 14)
    btn.TextColor3 = (index == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(110, 110, 120)
    btn.Text = "  " .. text
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 9
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 3
    btn.Parent = sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 2, 0.5, 0)
    indicator.Position = UDim2.new(0, 2, 0.25, 0)
    indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    indicator.Visible = (index == 1)
    indicator.ZIndex = 4
    indicator.Parent = btn

    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(1, 0, 1, -35)
    tabFrame.Position = UDim2.new(0, 0, 0, 35)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Visible = (index == 1)
    tabFrame.ZIndex = 3
    tabFrame.Parent = contentFrame

    tabs[index] = tabFrame
    tabButtons[index] = btn

    btn.MouseButton1Click:Connect(function()
        for i, t in ipairs(tabs) do t.Visible = (i == index) end
        for i, b in ipairs(tabButtons) do
            b.BackgroundColor3 = (i == index) and Color3.fromRGB(20, 20, 24) or Color3.fromRGB(12, 12, 14)
            b.TextColor3 = (i == index) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(110, 110, 120)
            if b:FindFirstChildOfClass("Frame") then
                b:FindFirstChildOfClass("Frame").Visible = (i == index)
            end
        end
        tabTitle.Text = text:gsub("^%d+%s*", "")
    end)

    return tabFrame
end

local tabSounds = createTabButton("04 Sounds", 1, 32)
local tabInicio = createTabButton("01 Inicio", 2, 64)

--------------------------------------------------------------------------------
-- SECCIÓN Y LISTA DESPLEGABLE DE AUDIOS EN TAB SOUNDS
--------------------------------------------------------------------------------
-- Indicadores de estado actual
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
statusLabel.Text = "Disparo: Ninguno | Salto: Ninguno | Muerte: Ninguno"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 8
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.ZIndex = 3
statusLabel.Parent = tabSounds

local function updateStatusText()
    statusLabel.Text = "Disparo: " .. ActiveSounds.Disparar.Name .. " | Salto: " .. ActiveSounds.Saltar.Name .. " | Muerte: " .. ActiveSounds.Matar.Name
end

-- Contenedor con Scroll para la Lista
local scrollList = Instance.new("ScrollingFrame")
scrollList.Size = UDim2.new(0.95, 0, 1, -28)
scrollList.Position = UDim2.new(0, 0, 0, 24)
scrollList.BackgroundTransparency = 1
scrollList.ScrollBarThickness = 3
scrollList.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70)
scrollList.ZIndex = 3
scrollList.Parent = tabSounds

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = scrollList

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
end)

local function populateSoundList()
    for _, child in ipairs(scrollList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for _, soundData in ipairs(SoundList) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 32)
        row.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
        row.BackgroundTransparency = 0.2
        row.ZIndex = 3
        row.Parent = scrollList

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 6)
        rCorner.Parent = row

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 140, 1, 0)
        nameLabel.Position = UDim2.new(0, 8, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        nameLabel.Text = soundData.Name
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 9
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.ZIndex = 3
        nameLabel.Parent = row

        -- Botón Probar ▶
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.new(0, 24, 0, 20)
        playBtn.Position = UDim2.new(1, -150, 0.2, 0)
        playBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        playBtn.TextColor3 = Color3.fromRGB(0, 170, 255)
        playBtn.Text = "▶"
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 8
        playBtn.ZIndex = 3
        playBtn.Parent = row

        local pCorner = Instance.new("UICorner")
        pCorner.CornerRadius = UDim.new(0, 4)
        pCorner.Parent = playBtn

        playBtn.MouseButton1Click:Connect(function()
            playAudioUrl(soundData.URL)
        end)

        -- Botón Asignar Disparo
        local gunBtn = Instance.new("TextButton")
        gunBtn.Size = UDim2.new(0, 38, 0, 20)
        gunBtn.Position = UDim2.new(1, -122, 0.2, 0)
        gunBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
        gunBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
        gunBtn.Text = "Disparo"
        gunBtn.Font = Enum.Font.Gotham
        gunBtn.TextSize = 7
        gunBtn.ZIndex = 3
        gunBtn.Parent = row

        local gCorner = Instance.new("UICorner")
        gCorner.CornerRadius = UDim.new(0, 4)
        gCorner.Parent = gunBtn

        gunBtn.MouseButton1Click:Connect(function()
            ActiveSounds.Disparar = { Name = soundData.Name, URL = soundData.URL }
            updateStatusText()
        end)

        -- Botón Asignar Salto
        local jumpBtn = Instance.new("TextButton")
        jumpBtn.Size = UDim2.new(0, 38, 0, 20)
        jumpBtn.Position = UDim2.new(1, -80, 0.2, 0)
        jumpBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
        jumpBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
        jumpBtn.Text = "Salto"
        jumpBtn.Font = Enum.Font.Gotham
        jumpBtn.TextSize = 7
        jumpBtn.ZIndex = 3
        jumpBtn.Parent = row

        local jCorner = Instance.new("UICorner")
        jCorner.CornerRadius = UDim.new(0, 4)
        jCorner.Parent = jumpBtn

        jumpBtn.MouseButton1Click:Connect(function()
            ActiveSounds.Saltar = { Name = soundData.Name, URL = soundData.URL }
            updateStatusText()
        end)

        -- Botón Asignar Matar
        local killBtn = Instance.new("TextButton")
        killBtn.Size = UDim2.new(0, 38, 0, 20)
        killBtn.Position = UDim2.new(1, -38, 0.2, 0)
        killBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
        killBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
        killBtn.Text = "Matar"
        killBtn.Font = Enum.Font.Gotham
        killBtn.TextSize = 7
        killBtn.ZIndex = 3
        killBtn.Parent = row

        local kCorner = Instance.new("UICorner")
        kCorner.CornerRadius = UDim.new(0, 4)
        kCorner.Parent = killBtn

        killBtn.MouseButton1Click:Connect(function()
            ActiveSounds.Matar = { Name = soundData.Name, URL = soundData.URL }
            updateStatusText()
        end)
    end
end

--------------------------------------------------------------------------------
-- ESCANEO AUTOMÁTICO DE AUDIOS EN GITHUB
--------------------------------------------------------------------------------
task.spawn(function()
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
                        local downloadUrl = item.download_url or (RawBaseURL .. FolderPath .. "/" .. item.name)
                        table.insert(SoundList, { Name = cleanName, URL = downloadUrl })
                    end
                end
            end
        end)
    end

    -- Si por red falla la API, asigna lista base
    if #SoundList == 0 then
        local defaults = {"Rust", "Skeet", "Hitmarker", "TF2", "Neverlose"}
        for _, name in ipairs(defaults) do
            table.insert(SoundList, { Name = name, URL = RawBaseURL .. FolderPath .. "/" .. name .. ".mp3" })
        end
    end

    -- Asignar el primer audio detectado por defecto si existe
    if #SoundList > 0 then
        ActiveSounds.Disparar = { Name = SoundList[1].Name, URL = SoundList[1].URL }
        updateStatusText()
    end

    populateSoundList()
end)

toggleButton.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)

--------------------------------------------------------------------------------
-- EVENTOS DE JUEGO (REPRODUCCIÓN DE AUDIOS ASIGNADOS)
--------------------------------------------------------------------------------
local boundTools = {}
local function bindTool(tool)
    if tool:IsA("Tool") and not boundTools[tool] then
        boundTools[tool] = true
        tool.Activated:Connect(function()
            if ActiveSounds.Disparar.URL ~= "" then
                playAudioUrl(ActiveSounds.Disparar.URL)
            end
        end)
    end
end

local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Jumping:Connect(function(isJumping)
            if isJumping and ActiveSounds.Saltar.URL ~= "" then
                playAudioUrl(ActiveSounds.Saltar.URL)
            end
        end)
    end
    char.ChildAdded:Connect(bindTool)
    for _, item in ipairs(char:GetChildren()) do bindTool(item) end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)
