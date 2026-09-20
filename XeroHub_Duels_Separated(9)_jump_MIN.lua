-- XeroHub: cargador de la versión actual de GitHub + sonido al saltar
local XERO_BASE_URL = 'https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/XeroHub_Duels_Separated(9)_autoload_FINAL_jump_sound_FIXED2.lua'

local source = game:HttpGet(XERO_BASE_URL)

local jumpCode = [[
-- ==========================================
-- SONIDO AL SALTAR (mínimo)
-- ==========================================
local XeroJumpSoundEnabled = false
local XeroJumpSoundId = ""

local function XeroSetupJumpSound(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    humanoid.StateChanged:Connect(function(_, state)
        if state ~= Enum.HumanoidStateType.Jumping then return end
        if not XeroJumpSoundEnabled or XeroJumpSoundId == "" then return end

        local root = character:FindFirstChild("HumanoidRootPart") or character
        local sound = Instance.new("Sound")
        sound.SoundId = XeroJumpSoundId
        sound.Volume = 1
        sound.Parent = root
        sound:Play()

        sound.Ended:Connect(function()
            if sound.Parent then sound:Destroy() end
        end)

        task.delay(10, function()
            if sound.Parent then sound:Destroy() end
        end)
    end)
end

local XeroJumpPlayer = game:GetService("Players").LocalPlayer

if XeroJumpPlayer.Character then
    XeroSetupJumpSound(XeroJumpPlayer.Character)
end

XeroJumpPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.25)
    XeroSetupJumpSound(character)
end)

-- Activa estas dos variables si quieres probarlo directamente:
-- XeroJumpSoundEnabled = true
-- XeroJumpSoundId = "rbxassetid://TU_ID"
]]

local chunk, compileError = loadstring(source .. "\n" .. jumpCode)
if not chunk then
    error("XeroHub no pudo compilar: " .. tostring(compileError))
end

chunk()
