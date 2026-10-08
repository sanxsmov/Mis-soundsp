-- LocalScript: NEVADA HUB (Con Macro Original de XeroHub y Sonidos)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

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
-- ESTADO DE LA MACRO Y SONIDOS (Lógica XeroHub)
--------------------------------------------------------------------------------
local macroActivo = false
local macroEquipDelay = 0.04
local macroShootDelay = 0.10

local SoundList = {} 
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

-- Botón Flotante
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

-- Imagen de Fondo
local function getCustomAssetImage(url, localName)
    if writefile and readfile and getcustomasset then
        if not isfile(localName) then
            local success, data = pcall(function() return game:HttpGet(url) end)
            if success and data then pcall(function() writefile(localName, data) end) end
        end
        return getcustomasset(localName)
    end
    return url
end

local backgroundImage = Instance.new("ImageLabel")
backgroundImage.Size = UDim2.new(0.6, 0, 1, 0)
backgroundImage.Position = UDim2.new(0.4, 0, 0, 0)
backgroundImage.BackgroundTransparency = 1
backgroundImage.Image = getCustomAssetImage(ImageURL, "sanxsmov_" .. ImageFileName)
backgroundImage.ImageTransparency = 0.4
backgroundImage.ScaleType = Enum.ScaleType.Fit
backgroundImage.ZIndex = 1
backgroundImage.Parent = mainFrame

-- Watermark
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

-- Topbar
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

-- Sidebar
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
createCategoryLabel("PERSONAL", 205)

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

-- Pestañas
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
local tabMacro = createTabButton("02 Macro", 2, 64)
local tabInicio = createTabButton("01 Inicio", 3, 96)

--------------------------------------------------------------------------------
-- PESTAÑA MACRO (XeroHub Style)
--------------------------------------------------------------------------------
local macroScroll = Instance.new("ScrollingFrame")
macroScroll.Size = UDim2.new(0.95, 0, 1, -5)
macroScroll.Position = UDim2.new(0, 0, 0, 0)
macroScroll.BackgroundTransparency = 1
macroScroll.ScrollBarThickness = 3
macroScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70)
macroScroll.ZIndex = 3
macroScroll.Parent = tabs[2]

local macroLayout = Instance.new("UIListLayout")
macroLayout.SortOrder = Enum.SortOrder.LayoutOrder
macroLayout.Padding = UDim.new(0, 8)
macroLayout.Parent = macroScroll

macroLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    macroScroll.CanvasSize = UDim2.new(0, 0, 0, macroLayout.AbsoluteContentSize.Y + 10)
end)

local function createMacroCard(height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, height)
    card.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    card.BackgroundTransparency = 0.2
    card.ZIndex = 3
    card.Parent = macroScroll

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 6)
    cCorner.Parent = card
    return card
end

-- Toggle Macro
local toggleCard = createMacroCard(36)
local toggleLabel = Instance.new("TextLabel")
toggleLabel.Size = UDim2.new(0.7, 0, 1, 0)
toggleLabel.Position = UDim2.new(0, 10, 0, 0)
toggleLabel.BackgroundTransparency = 1
toggleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
toggleLabel.Text = "Activar Macro"
toggleLabel.Font = Enum.Font.GothamSemibold
toggleLabel.TextSize = 10
toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
toggleLabel.ZIndex = 3
toggleLabel.Parent = toggleCard

local macroToggleBtn = Instance.new("TextButton")
macroToggleBtn.Size = UDim2.new(0, 44, 0, 20)
macroToggleBtn.Position = UDim2.new(1, -54, 0.5, -10)
macroToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
macroToggleBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
macroToggleBtn.Text = "OFF"
macroToggleBtn.Font = Enum.Font.GothamBold
macroToggleBtn.TextSize = 9
macroToggleBtn.ZIndex = 3
macroToggleBtn.Parent = toggleCard

local mtCorner = Instance.new("UICorner")
mtCorner.CornerRadius = UDim.new(0, 4)
mtCorner.Parent = macroToggleBtn

macroToggleBtn.MouseButton1Click:Connect(function()
    macroActivo = not macroActivo
    if macroActivo then
        macroToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        macroToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        macroToggleBtn.Text = "ON"
    else
        macroToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        macroToggleBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        macroToggleBtn.Text = "OFF"
    end
end)

-- Slider Equipar
local equipCard = createMacroCard(48)
local equipLabel = Instance.new("TextLabel")
equipLabel.Size = UDim2.new(1, -20, 0, 20)
equipLabel.Position = UDim2.new(0, 10, 0, 4)
equipLabel.BackgroundTransparency = 1
equipLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
equipLabel.Text = "Delay Equipar: " .. string.format("%.2fs", macroEquipDelay)
equipLabel.Font = Enum.Font.GothamSemibold
equipLabel.TextSize = 9
equipLabel.TextXAlignment = Enum.TextXAlignment.Left
equipLabel.ZIndex = 3
equipLabel.Parent = equipCard

local equipSliderBg = Instance.new("TextButton")
equipSliderBg.Size = UDim2.new(1, -20, 0, 10)
equipSliderBg.Position = UDim2.new(0, 10, 0, 28)
equipSliderBg.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
equipSliderBg.Text = ""
equipSliderBg.AutoButtonColor = false
equipSliderBg.ZIndex = 3
equipSliderBg.Parent = equipCard

local esCorner = Instance.new("UICorner")
esCorner.CornerRadius = UDim.new(0, 4)
esCorner.Parent = equipSliderBg

local equipFill = Instance.new("Frame")
equipFill.Size = UDim2.new((macroEquipDelay - 0.01) / 0.49, 0, 1, 0)
equipFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
equipFill.BorderSizePixel = 0
equipFill.ZIndex = 4
equipFill.Parent = equipSliderBg

local efCorner = Instance.new("UICorner")
efCorner.CornerRadius = UDim.new(0, 4)
efCorner.Parent = equipFill

local function updateEquipSlider(input)
    local pos = math.clamp((input.Position.X - equipSliderBg.AbsolutePosition.X) / equipSliderBg.AbsoluteSize.X, 0, 1)
    macroEquipDelay = math.round((0.01 + pos * 0.49) * 100) / 100
    equipFill.Size = UDim2.new(pos, 0, 1, 0)
    equipLabel.Text = "Delay Equipar: " .. string.format("%.2fs", macroEquipDelay)
end

local draggingEquip = false
equipSliderBg.MouseButton1Down:Connect(function(input) draggingEquip = true; updateEquipSlider(input) end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingEquip = false end end)
UserInputService.InputChanged:Connect(function(input) if draggingEquip and input.UserInputType == Enum.UserInputType.MouseMovement then updateEquipSlider(input) end end)

-- Slider Disparo
local shootCard = createMacroCard(48)
local shootLabel = Instance.new("TextLabel")
shootLabel.Size = UDim2.new(1, -20, 0, 20)
shootLabel.Position = UDim2.new(0, 10, 0, 4)
shootLabel.BackgroundTransparency = 1
shootLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
shootLabel.Text = "Delay Disparo: " .. string.format("%.2fs", macroShootDelay)
shootLabel.Font = Enum.Font.GothamSemibold
shootLabel.TextSize = 9
shootLabel.TextXAlignment = Enum.TextXAlignment.Left
shootLabel.ZIndex = 3
shootLabel.Parent = shootCard

local shootSliderBg = Instance.new("TextButton")
shootSliderBg.Size = UDim2.new(1, -20, 0, 10)
shootSliderBg.Position = UDim2.new(0, 10, 0, 28)
shootSliderBg.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
shootSliderBg.Text = ""
shootSliderBg.AutoButtonColor = false
shootSliderBg.ZIndex = 3
shootSliderBg.Parent = shootCard

local ssCorner = Instance.new("UICorner")
ssCorner.CornerRadius = UDim.new(0, 4)
ssCorner.Parent = shootSliderBg

local shootFill = Instance.new("Frame")
shootFill.Size = UDim2.new((macroShootDelay - 0.01) / 0.49, 0, 1, 0)
shootFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
shootFill.BorderSizePixel = 0
shootFill.ZIndex = 4
shootFill.Parent = shootSliderBg

local sfCorner = Instance.new("UICorner")
sfCorner.CornerRadius = UDim.new(0, 4)
sfCorner.Parent = shootFill

local function updateShootSlider(input)
    local pos = math.clamp((input.Position.X - shootSliderBg.AbsolutePosition.X) / shootSliderBg.AbsoluteSize.X, 0, 1)
    macroShootDelay = math.round((0.01 + pos * 0.49) * 100) / 100
    shootFill.Size = UDim2.new(pos, 0, 1, 0)
    shootLabel.Text = "Delay Disparo: " .. string.format("%.2fs", macroShootDelay)
end

local draggingShoot = false
shootSliderBg.MouseButton1Down:Connect(function(input) draggingShoot = true; updateShootSlider(input) end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingShoot = false end end)
UserInputService.InputChanged:Connect(function(input) if draggingShoot and input.UserInputType == Enum.UserInputType.MouseMovement then updateShootSlider(input) end end)

--------------------------------------------------------------------------------
-- PESTAÑA SOUNDS (XeroHub Style)
--------------------------------------------------------------------------------
local soundsContainer = Instance.new("Frame")
soundsContainer.Size = UDim2.new(0.95, 0, 1, -5)
soundsContainer.BackgroundTransparency = 1
soundsContainer.ZIndex = 3
soundsContainer.Parent = tabs[1]

local soundsLayout = Instance.new("UIListLayout")
soundsLayout.SortOrder = Enum.SortOrder.LayoutOrder
soundsLayout.Padding = UDim.new(0, 8)
soundsLayout.Parent = soundsContainer

local function createDropdownSelector(labelName, soundKey)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, 46)
    card.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    card.BackgroundTransparency = 0.2
    card.ZIndex = 3
    card.Parent = soundsContainer

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 6)
    cCorner.Parent = card

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.Text = labelName
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3
    lbl.Parent = card

    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(0, 180, 0, 28)
    dropBtn.Position = UDim2.new(1, -190, 0.5, -14)
    dropBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    dropBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    dropBtn.Text = "Ninguno ▾"
    dropBtn.Font = Enum.Font.Gotham
    dropBtn.TextSize = 9
    dropBtn.ZIndex = 3
    dropBtn.Parent = card

    local dCorner = Instance.new("UICorner")
    dCorner.CornerRadius = UDim.new(0, 6)
    dCorner.Parent = dropBtn

    local dropListFrame = Instance.new("Frame")
    dropListFrame.Size = UDim2.new(0, 180, 0, 140)
    dropListFrame.Position = UDim2.new(1, -190, 1, 4)
    dropListFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    dropListFrame.Visible = false
    dropListFrame.ZIndex = 10
    dropListFrame.Parent = card

    local dlCorner = Instance.new("UICorner")
    dlCorner.CornerRadius = UDim.new(0, 6)
    dlCorner.Parent = dropListFrame

    local dlStroke = Instance.new("UIStroke")
    dlStroke.Color = Color3.fromRGB(40, 40, 50)
    dlStroke.Parent = dropListFrame

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -10, 0, 26)
    searchBox.Position = UDim2.new(0, 5, 0, 5)
    searchBox.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    searchBox.TextColor3 = Color3.fromRGB(220, 220, 220)
    searchBox.PlaceholderText = "Buscar sonido..."
    searchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 110)
    searchBox.Text = ""
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 8
    searchBox.ZIndex = 11
    searchBox.Parent = dropListFrame

    local sbCorner = Instance.new("UICorner")
    sbCorner.CornerRadius = UDim.new(0, 4)
    sbCorner.Parent = searchBox

    local optionScroll = Instance.new("ScrollingFrame")
    optionScroll.Size = UDim2.new(1, -6, 1, -38)
    optionScroll.Position = UDim2.new(0, 3, 0, 34)
    optionScroll.BackgroundTransparency = 1
    optionScroll.ScrollBarThickness = 3
    optionScroll.ZIndex = 11
    optionScroll.Parent = dropListFrame

    local optLayout = Instance.new("UIListLayout")
    optLayout.SortOrder = Enum.SortOrder.LayoutOrder
    optLayout.Padding = UDim.new(0, 3)
    optLayout.Parent = optionScroll

    optLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        optionScroll.CanvasSize = UDim2.new(0, 0, 0, optLayout.AbsoluteContentSize.Y + 5)
    end)

    local function populateOptions(filter)
        for _, child in ipairs(optionScroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end

        for _, soundData in ipairs(SoundList) do
            if not filter or filter == "" or soundData.Name:lower():find(filter:lower()) then
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, 0, 0, 24)
                optBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
                optBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
                optBtn.Text = "  " .. soundData.Name .. ((ActiveSounds[soundKey].Name == soundData.Name) and "  ✓" or "")
                optBtn.Font = Enum.Font.Gotham
                optBtn.TextSize = 8
                optBtn.TextXAlignment = Enum.TextXAlignment.Left
                optBtn.ZIndex = 12
                optBtn.Parent = optionScroll

                local oCorner = Instance.new("UICorner")
                oCorner.CornerRadius = UDim.new(0, 4)
                oCorner.Parent = optBtn

                optBtn.MouseButton1Click:Connect(function()
                    ActiveSounds[soundKey] = { Name = soundData.Name, URL = soundData.URL }
                    dropBtn.Text = soundData.Name .. " ▾"
                    dropListFrame.Visible = false
                    playAudioUrl(soundData.URL)
                end)
            end
        end
    end

    dropBtn.MouseButton1Click:Connect(function()
        dropListFrame.Visible = not dropListFrame.Visible
        if dropListFrame.Visible then
            populateOptions("")
            searchBox.Text = ""
        end
    end)

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        populateOptions(searchBox.Text)
    end)

    return dropBtn
end

createDropdownSelector("Sonido Disparo:", "Disparar")
createDropdownSelector("Sonido Salto:", "Saltar")
createDropdownSelector("Sonido Matar:", "Matar")

--------------------------------------------------------------------------------
-- CARGA DE AUDIOS DESDE GITHUB
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

    if #SoundList == 0 then
        local defaults = {"Rust", "Skeet", "Hitmarker", "TF2", "Neverlose"}
        for _, name in ipairs(defaults) do
            table.insert(SoundList, { Name = name, URL = RawBaseURL .. FolderPath .. "/" .. name .. ".mp3" })
        end
    end
end)

toggleButton.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)

--------------------------------------------------------------------------------
-- BUCLE DE LA MACRO Y DETECCIÓN DE EVENTOS (XeroHub Engine)
--------------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    if not macroActivo then return end
    
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        pcall(function()
            task.wait(macroEquipDelay)
            VirtualUser:Button1Down(Vector2.new(0,0))
            task.wait(macroShootDelay)
            VirtualUser:Button1Up(Vector2.new(0,0))
        end)
    end
end)

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
