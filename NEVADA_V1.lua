--// NEVADA V1
--// Nueva interfaz desde cero
--// Sin OnyxDevv

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local API_URL =
    "https://api.github.com/repos/sanxsmov/Mis-soundsp/contents/sounds"

--==================================================
-- GUI
--==================================================

local old = PlayerGui:FindFirstChild("NEVADA")

if old then
    old:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "NEVADA"
Gui.ResetOnSpawn = false
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 520, 0, 350)
Main.Position = UDim2.new(0.5, -260, 0.5, -175)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Main.BorderSizePixel = 0
Main.Parent = Gui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -30, 0, 45)
Title.Position = UDim2.new(0, 15, 0, 8)
Title.BackgroundTransparency = 1
Title.Text = "NEVADA"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 24
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Main

--==================================================
-- TAB BAR
--==================================================

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -30, 0, 40)
TabBar.Position = UDim2.new(0, 15, 0, 58)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Main

local function CreateButton(parent, text, position, size)

    local Button = Instance.new("TextButton")

    Button.Size = size
    Button.Position = position
    Button.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    Button.BorderSizePixel = 0
    Button.Text = text
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextSize = 14
    Button.Font = Enum.Font.GothamMedium
    Button.AutoButtonColor = true
    Button.Parent = parent

    local Corner = Instance.new("UICorner")

    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Button

    return Button
end

local InicioButton =
    CreateButton(
        TabBar,
        "🏠 Inicio",
        UDim2.new(0, 0, 0, 0),
        UDim2.new(0, 125, 0, 38)
    )

local SonidosButton =
    CreateButton(
        TabBar,
        "🔊 Sonidos",
        UDim2.new(0, 135, 0, 0),
        UDim2.new(0, 125, 0, 38)
    )

--==================================================
-- CONTENIDO
--==================================================

local Content = Instance.new("Frame")

Content.Size = UDim2.new(1, -30, 1, -115)
Content.Position = UDim2.new(0, 15, 0, 110)
Content.BackgroundTransparency = 1
Content.Parent = Main

--==================================================
-- INICIO
--==================================================

local Inicio = Instance.new("Frame")

Inicio.Size = UDim2.new(1, 0, 1, 0)
Inicio.BackgroundTransparency = 1
Inicio.Parent = Content

local Welcome = Instance.new("TextLabel")

Welcome.Size = UDim2.new(1, 0, 0, 120)
Welcome.Position = UDim2.new(0, 0, 0, 45)
Welcome.BackgroundTransparency = 1
Welcome.Text = "NEVADA"
Welcome.TextColor3 = Color3.fromRGB(255, 255, 255)
Welcome.TextSize = 30
Welcome.Font = Enum.Font.GothamBold
Welcome.TextXAlignment = Enum.TextXAlignment.Center
Welcome.Parent = Inicio

local Subtitle = Instance.new("TextLabel")

Subtitle.Size = UDim2.new(1, 0, 0, 30)
Subtitle.Position = UDim2.new(0, 0, 0, 90)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Nueva interfaz"
Subtitle.TextColor3 = Color3.fromRGB(160, 160, 160)
Subtitle.TextSize = 14
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextXAlignment = Enum.TextXAlignment.Center
Subtitle.Parent = Inicio

--==================================================
-- SONIDOS
--==================================================

local Sonidos = Instance.new("Frame")

Sonidos.Size = UDim2.new(1, 0, 1, 0)
Sonidos.BackgroundTransparency = 1
Sonidos.Visible = false
Sonidos.Parent = Content

local Status = Instance.new("TextLabel")

Status.Size = UDim2.new(1, -145, 0, 35)
Status.Position = UDim2.new(0, 0, 0, 0)
Status.BackgroundTransparency = 1
Status.Text = "Catálogo: esperando..."
Status.TextColor3 = Color3.fromRGB(210, 210, 210)
Status.TextSize = 13
Status.Font = Enum.Font.Gotham
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Sonidos

local Refresh =
    CreateButton(
        Sonidos,
        "↻ Actualizar",
        UDim2.new(1, -135, 0, 0),
        UDim2.new(0, 135, 0, 35)
    )

local List = Instance.new("ScrollingFrame")

List.Size = UDim2.new(1, 0, 1, -45)
List.Position = UDim2.new(0, 0, 0, 45)
List.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
List.BorderSizePixel = 0
List.ScrollBarThickness = 5
List.CanvasSize = UDim2.new(0, 0, 0, 0)
List.Parent = Sonidos

local ListCorner = Instance.new("UICorner")

ListCorner.CornerRadius = UDim.new(0, 8)
ListCorner.Parent = List

local Layout = Instance.new("UIListLayout")

Layout.Padding = UDim.new(0, 5)
Layout.Parent = List

--==================================================
-- CATÁLOGO
--==================================================

local function ClearList()

    for _, Object in ipairs(List:GetChildren()) do

        if Object:IsA("TextButton") then
            Object:Destroy()
        end

    end

end

local function LoadSounds()

    ClearList()

    Status.Text = "Cargando catálogo..."

    local Success, Response = pcall(function()

        return game:HttpGet(API_URL)

    end)

    if not Success then

        Status.Text = "No se pudo conectar con GitHub."

        return

    end

    local DecodeSuccess, Data = pcall(function()

        return HttpService:JSONDecode(Response)

    end)

    if not DecodeSuccess or type(Data) ~= "table" then

        Status.Text = "Error leyendo el catálogo."

        return

    end

    local Count = 0

    for _, Item in ipairs(Data) do

        if type(Item) == "table" and type(Item.name) == "string" then

            local Name = Item.name
            local Lower = Name:lower()

            if Lower:match("%.mp3$")
            or Lower:match("%.wav$")
            or Lower:match("%.ogg$") then

                Count += 1

                local SoundButton =
                    CreateButton(
                        List,
                        "🔊 " .. Name,
                        UDim2.new(0, 0, 0, 0),
                        UDim2.new(1, -10, 0, 38)
                    )

                SoundButton.MouseButton1Click:Connect(function()

                    Status.Text =
                        "Seleccionado: " .. Name

                end)

            end

        end

    end

    List.CanvasSize =
        UDim2.new(0, 0, 0, Count * 43)

    Status.Text =
        "Sonidos encontrados: " .. tostring(Count)

end

--==================================================
-- NAVEGACIÓN
--==================================================

InicioButton.MouseButton1Click:Connect(function()

    Inicio.Visible = true
    Sonidos.Visible = false

end)

SonidosButton.MouseButton1Click:Connect(function()

    Inicio.Visible = false
    Sonidos.Visible = true

    LoadSounds()

end)

Refresh.MouseButton1Click:Connect(function()

    LoadSounds()

end)

--==================================================
-- INICIO
--==================================================

print("NEVADA V1 cargado correctamente.")
