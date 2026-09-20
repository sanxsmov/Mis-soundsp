-- XeroHub: carga la versión actual de GitHub y luego instala el sonido al saltar.
local XERO_BASE_URL = 'https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/XeroHub_Duels_Separated(9)_autoload_FINAL_jump_sound_FIXED2.lua'

local source = game:HttpGet(XERO_BASE_URL)
local baseChunk, baseError = loadstring(source)

if not baseChunk then
    error("[XeroHub] Error al compilar la versión de GitHub: " .. tostring(baseError))
end

baseChunk()

local jumpChunk, jumpError = loadstring('\n-- Sonido al saltar (mínimo)\nlocal XeroJumpSoundEnabled = false\nlocal XeroJumpSoundId = ""\n\nlocal function XeroSetupJumpSound(character)\n    local humanoid = character and character:FindFirstChildOfClass("Humanoid")\n    if not humanoid then return end\n\n    humanoid.StateChanged:Connect(function(_, state)\n        if state ~= Enum.HumanoidStateType.Jumping then return end\n        if not XeroJumpSoundEnabled or XeroJumpSoundId == "" then return end\n\n        local root = character:FindFirstChild("HumanoidRootPart") or character\n        local sound = Instance.new("Sound")\n        sound.SoundId = XeroJumpSoundId\n        sound.Volume = 1\n        sound.Parent = root\n\n        local ok = pcall(function()\n            sound:Play()\n        end)\n        if not ok then\n            sound:Destroy()\n            return\n        end\n\n        sound.Ended:Connect(function()\n            if sound.Parent then sound:Destroy() end\n        end)\n\n        task.delay(10, function()\n            if sound.Parent then sound:Destroy() end\n        end)\n    end)\nend\n\nlocal XeroJumpPlayer = game:GetService("Players").LocalPlayer\n\nif XeroJumpPlayer then\n    if XeroJumpPlayer.Character then\n        XeroSetupJumpSound(XeroJumpPlayer.Character)\n    end\n\n    XeroJumpPlayer.CharacterAdded:Connect(function(character)\n        task.wait(0.25)\n        XeroSetupJumpSound(character)\n    end)\nend\n\n-- Para probar el sonido directamente, cambia estas dos líneas:\n-- XeroJumpSoundEnabled = true\n-- XeroJumpSoundId = "rbxassetid://TU_ID"\n')
if not jumpChunk then
    error("[XeroHub] Error al compilar el sonido al saltar: " .. tostring(jumpError))
end

jumpChunk()
