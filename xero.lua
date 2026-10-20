-- PRUEBA DE MENÚ BÁSICO
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local Frame = Instance.new("Frame")
Frame.Parent = ScreenGui
Frame.Size = UDim2.new(0, 200, 0, 100)
Frame.Position = UDim2.new(0.5, -100, 0.5, -50)
Frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
Frame.BorderSizePixel = 0

local Text = Instance.new("TextLabel")
Text.Parent = Frame
Text.Size = UDim2.new(1, 0, 1, 0)
Text.BackgroundTransparency = 1
Text.Text = "¡FUNCIONA!"
Text.TextColor3 = Color3.fromRGB(255, 255, 255)
Text.TextScaled = true
Text.Font = Enum.Font.GothamBold
