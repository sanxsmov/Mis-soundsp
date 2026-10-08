-- LocalScript: XEROHUB (Macro & Sounds)
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
local GitHubUser = "sanxsmov"
local RepoName = "Mis-soundsp"
local FolderPath = "sounds"

local RawBaseURL = "https://raw.githubusercontent.com/" .. GitHubUser .. "/" .. RepoName .. "/main/"
local ApiURL = "https://api.github.com/repos/" .. GitHubUser .. "/" .. RepoName .. "/contents/" .. FolderPath

--------------------------------------------------------------------------------
-- ESTADO DE XEROHUB
--------------------------------------------------------------------------------
local macroEnabled = false
local equipDelay = 0.05
local shootDelay = 0.10

local SoundList = {} 
local XeroSounds = {
    Disparar = { Name = "Ninguno", URL = "" },
    Saltar   = { Name = "Ninguno", URL = "" },
    Matar    = { Name = "Ninguno", URL = "" }
}

local SoundCache = {}
local function playSound(url)
    if not url or url == "" then return end
    local soundAssetId = SoundCache[url]

    if not soundAssetId then
        local sanitizeName = url:match("([^/]+)%.mp3$") or ("sound_" .. tick())
        local fileName = "xero_" .. sanitizeName .. ".mp3"

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
-- INTERFAZ GRÁFICA (Estilo XeroHub)
--------------------------------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("XeroHubMainUI") then
    playerGui.XeroHubMainUI:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XeroHubMainUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Botón Flotante para Abrir/Cerrar
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 90, 0, 30)
toggleButton.Position = UDim2.new(0.02, 0, 0.2, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
toggleButton.TextColor3 = Color3.fromRGB(240, 240, 240)
toggleButton.Text = "XeroHub"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 11
toggleButton.Parent = screenGui

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 6)
tbCorner.Parent = toggleButton

local tbStroke = Instance.new("UIStroke")
tbStroke.Color = Color3.fromRGB(40, 40, 50)
tbStroke.Parent = toggleButton

-- Ventana Principal de XeroHub
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 480, 0, 300)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -150)
mainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
mainFrame.Visible = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 8)
mfCorner.Parent = mainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Color = Color3.fromRGB(45, 45, 55)
mfStroke.Parent = mainFrame

-- Barra Superior
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 35)
topBar.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -20, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Text = "XeroHub — Macro & Sounds"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 12
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

-- Contenedor de Contenido
local contentContainer = Instance.new("ScrollingFrame")
contentContainer.Size = UDim2.new(1, -20, 1, -45)
contentContainer.Position = UDim2.new(0, 10, 0, 40)
contentContainer.BackgroundTransparency = 1
contentContainer.ScrollBarThickness = 4
contentContainer.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.Parent = contentContainer

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    contentContainer.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end)

local function createSectionTitle(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(140, 140, 160)
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = contentContainer
end

--------------------------------------------------------------------------------
-- CONTROLES DE MACRO
--------------------------------------------------------------------------------
createSectionTitle("MACRO CONFIGURATION")

-- Toggle Macro
local macroCard = Instance.new("Frame")
macroCard.Size = UDim2.new(1, 0, 0, 36)
macroCard.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
macroCard.Parent = contentContainer

Instance.new("UICorner", macroCard).CornerRadius = UDim.new(0, 6)

local macroText = Instance.new("TextLabel")
macroText.Size = UDim2.new(0.7, 0, 1, 0)
macroText.Position = UDim2.new(0, 10, 0, 0)
macroText.BackgroundTransparency = 1
macroText.TextColor3 = Color3.fromRGB(220, 220, 220)
macroText.Text = "Enable Macro"
macroText.Font = Enum.Font.GothamSemibold
macroText.TextSize = 10
macroText.TextXAlignment = Enum.TextXAlignment.Left
macroText.Parent = macroCard

local macroBtn = Instance.new("TextButton")
macroBtn.Size = UDim2.new(0, 45, 0, 20)
macroBtn.Position = UDim2.new(1, -55, 0.5, -10)
macroBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
macroBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
macroBtn.Text = "OFF"
macroBtn.Font = Enum.Font.GothamBold
macroBtn.TextSize = 9
macroBtn.Parent = macroCard
Instance.new("UICorner", macroBtn).CornerRadius = UDim.new(0, 4)

macroBtn.MouseButton1Click:Connect(function()
    macroEnabled = not macroEnabled
    if macroEnabled then
        macroBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        macroBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        macroBtn.Text = "ON"
    else
        macroBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        macroBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        macroBtn.Text = "OFF"
    end
end)

-- Delay Equipar Slider
local equipCard = Instance.new("Frame")
equipCard.Size = UDim2.new(1, 0, 0, 45)
equipCard.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
equipCard.Parent = contentContainer
Instance.new("UICorner", equipCard).CornerRadius = UDim.new(0, 6)

local equipLabel = Instance.new("TextLabel")
equipLabel.Size = UDim2.new(1, -20, 0, 20)
equipLabel.Position = UDim2.new(0, 10, 0, 4)
equipLabel.BackgroundTransparency = 1
equipLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
equipLabel.Text = "Equip Delay: " .. string.format("%.2fs", equipDelay)
equipLabel.Font = Enum.Font.GothamSemibold
equipLabel.TextSize = 9
equipLabel.TextXAlignment = Enum.TextXAlignment.Left
equipLabel.Parent = equipCard

local equipSlider = Instance.new("TextButton")
equipSlider.Size = UDim2.new(1, -20, 0, 8)
equipSlider.Position = UDim2.new(0, 10, 0, 28)
equipSlider.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
equipSlider.Text = ""
equipSlider.AutoButtonColor = false
equipSlider.Parent = equipCard
Instance.new("UICorner", equipSlider).CornerRadius = UDim.new(0, 4)

local equipFill = Instance.new("Frame")
equipFill.Size = UDim2.new((equipDelay - 0.01) / 0.49, 0, 1, 0)
equipFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
equipFill.BorderSizePixel = 0
equipFill.Parent = equipSlider
Instance.new("UICorner", equipFill).CornerRadius = UDim.new(0, 4)

local draggingEquip = false
equipSlider.MouseButton1Down:Connect(function(input)
    draggingEquip = true
    local pos = math.clamp((input.Position.X - equipSlider.AbsolutePosition.X) / equipSlider.AbsoluteSize.X, 0, 1)
    equipDelay = math.round((0.01 + pos * 0.49) * 100) / 100
    equipFill.Size = UDim2.new(pos, 0, 1, 0)
    equipLabel.Text = "Equip Delay: " .. string.format("%.2fs", equipDelay)
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingEquip = false end end)
UserInputService.InputChanged:Connect(function(input)
    if draggingEquip and input.UserInputType == Enum.UserInputType.MouseMovement then
        local pos = math.clamp((input.Position.X - equipSlider.AbsolutePosition.X) / equipSlider.AbsoluteSize.X, 0, 1)
        equipDelay = math.round((0.01 + pos * 0.49) * 100) / 100
        equipFill.Size = UDim2.new(pos, 0, 1, 0)
        equipLabel.Text = "Equip Delay: " .. string.format("%.2fs", equipDelay)
    end
end)

-- Delay Disparo Slider
local shootCard = Instance.new("Frame")
shootCard.Size = UDim2.new(1, 0, 0, 45)
shootCard.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
shootCard.Parent = contentContainer
Instance.new("UICorner", shootCard).CornerRadius = UDim.new(0, 6)

local shootLabel = Instance.new("TextLabel")
shootLabel.Size = UDim2.new(1, -20, 0, 20)
shootLabel.Position = UDim2.new(0, 10, 0, 4)
shootLabel.BackgroundTransparency = 1
shootLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
shootLabel.Text = "Shoot Delay: " .. string.format("%.2fs", shootDelay)
shootLabel.Font = Enum.Font.GothamSemibold
shootLabel.TextSize = 9
shootLabel.TextXAlignment = Enum.TextXAlignment.Left
shootLabel.Parent = shootCard

local shootSlider = Instance.new("TextButton")
shootSlider.Size = UDim2.new(1, -20, 0, 8)
shootSlider.Position = UDim2.new(0, 10, 0, 28)
shootSlider.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
shootSlider.Text = ""
shootSlider.AutoButtonColor = false
shootSlider.Parent = shootCard
Instance.new("UICorner", shootSlider).CornerRadius = UDim.new(0, 4)

local shootFill = Instance.new("Frame")
shootFill.Size = UDim2.new((shootDelay - 0.01) / 0.49, 0, 1, 0)
shootFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
shootFill.BorderSizePixel = 0
shootFill.Parent = shootSlider
Instance.new("UICorner", shootFill).CornerRadius = UDim.new(0, 4)

local draggingShoot = false
shootSlider.MouseButton1Down:Connect(function(input)
    draggingShoot = true
    local pos = math.clamp((input.Position.X - shootSlider.AbsolutePosition.X) / shootSlider.AbsoluteSize.X, 0, 1)
    shootDelay = math.round((0.01 + pos * 0.49) * 100) / 100
    shootFill.Size = UDim2.new(pos, 0, 1, 0)
    shootLabel.Text = "Shoot Delay: " .. string.format("%.2fs", shootDelay)
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingShoot and input.UserInputType == Enum.UserInputType.MouseMovement then
        local pos = math.clamp((input.Position.X - shootSlider.AbsolutePosition.X) / shootSlider.AbsoluteSize.X, 0, 1)
        shootDelay = math.round((0.01 + pos * 0.49) * 100) / 100
        shootFill.Size = UDim2.new(pos, 0, 1, 0)
        shootLabel.Text = "Shoot Delay: " .. string.format("%.2fs", shootDelay)
    end
end)

--------------------------------------------------------------------------------
-- SELECCIÓN DE SONIDOS
--------------------------------------------------------------------------------
createSectionTitle("SOUNDS CONFIGURATION")

local function createDropdown(labelName, soundKey)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 42)
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    card.Parent = contentContainer
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.Text = labelName
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = card

    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(0, 160, 0, 26)
    dropBtn.Position = UDim2.new(1, -170, 0.5, -13)
    dropBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    dropBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    dropBtn.Text = "Ninguno ▾"
    dropBtn.Font = Enum.Font.Gotham
    dropBtn.TextSize = 9
    dropBtn.Parent = card
    Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 4)

    local dropList = Instance.new("Frame")
    dropList.Size = UDim2.new(0, 160, 0, 120)
    dropList.Position = UDim2.new(1, -170, 1, 4)
    dropList.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    dropList.Visible = false
    dropList.ZIndex = 5
    dropList.Parent = card
    Instance.new("UICorner", dropList).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", dropList).Color = Color3.fromRGB(40, 40, 50)

    local optScroll = Instance.new("ScrollingFrame")
    optScroll.Size = UDim2.new(1, -4, 1, -4)
    optScroll.Position = UDim2.new(0, 2, 0, 2)
    optScroll.BackgroundTransparency = 1
    optScroll.ScrollBarThickness = 3
    optScroll.ZIndex = 6
    optScroll.Parent = dropList

    local optLayout = Instance.new("UIListLayout")
    optLayout.SortOrder = Enum.SortOrder.LayoutOrder
    optLayout.Padding = UDim.new(0, 2)
    optLayout.Parent = optScroll

    optLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        optScroll.CanvasSize = UDim2.new(0, 0, 0, optLayout.AbsoluteContentSize.Y + 4)
    end)

    local function populate()
        for _, child in ipairs(optScroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end

        for _, sound in ipairs(SoundList) do
            local opt = Instance.new("TextButton")
            opt.Size = UDim2.new(1, 0, 0, 22)
            opt.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
            opt.TextColor3 = Color3.fromRGB(210, 210, 210)
            opt.Text = " " .. sound.Name
            opt.Font = Enum.Font.Gotham
            opt.TextSize = 8
            opt.TextXAlignment = Enum.TextXAlignment.Left
            opt.ZIndex = 7
            opt.Parent = optScroll
            Instance.new("UICorner", opt).CornerRadius = UDim.new(0, 3)

            opt.MouseButton1Click:Connect(function()
                XeroSounds[soundKey] = { Name = sound.Name, URL = sound.URL }
                dropBtn.Text = sound.Name .. " ▾"
                dropList.Visible = false
                playSound(sound.URL)
            end)
        end
    end

    dropBtn.MouseButton1Click:Connect(function()
        dropList.Visible = not dropList.Visible
        if dropList.Visible then populate() end
    end)
end

createDropdown("Shoot Sound:", "Disparar")
createDropdown("Jump Sound:", "Saltar")
createDropdown("Kill Sound:", "Matar")

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

            if response and response.StatusCode == 200 then
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
        table.insert(SoundList, { Name = "Rust", URL = RawBaseURL .. FolderPath .. "/Rust.mp3" })
        table.insert(SoundList, { Name = "Hitmarker", URL = RawBaseURL .. FolderPath .. "/Hitmarker.mp3" })
    end
end)

toggleButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

--------------------------------------------------------------------------------
-- LÓGICA DE MACRO Y EVENTOS
--------------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    if not macroEnabled then return end
    
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        pcall(function()
            task.wait(equipDelay)
            VirtualUser:Button1Down(Vector2.new(0,0))
            task.wait(shootDelay)
            VirtualUser:Button1Up(Vector2.new(0,0))
        end)
    end
end)

local boundTools = {}
local function bindTool(tool)
    if tool:IsA("Tool") and not boundTools[tool] then
        boundTools[tool] = true
        tool.Activated:Connect(function()
            if XeroSounds.Disparar.URL ~= "" then
                playSound(XeroSounds.Disparar.URL)
            end
        end)
    end
end

local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Jumping:Connect(function(isJumping)
            if isJumping and XeroSounds.Saltar.URL ~= "" then
                playSound(XeroSounds.Saltar.URL)
            end
        end)
    end
    char.ChildAdded:Connect(bindTool)
    for _, item in ipairs(char:GetChildren()) do bindTool(item) end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)
