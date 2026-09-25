-- XeroHub | DUELS MURDERS VS SHERIFF | Kev --

local SoundCatalogCore = {
    TARGET_SOUND_ID = "10209603",
    CATALOG_URL = "https://api.github.com/repos/sanxsmov/Mis-soundsp/contents/sounds",
    CACHE_FOLDER = "XeroHub/SoundsV2",
}

local function soundTrim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function soundExtension(fileName)
    local extension = string.lower(tostring(fileName or ""):match("%.([%w]+)$") or "")
    if extension == "mp3" or extension == "ogg" then return extension end
    return nil
end

function SoundCatalogCore.prettyName(fileName)
    local extension = soundExtension(fileName)
    local name = tostring(fileName or "")
    if extension then name = name:sub(1, #name - #extension - 1) end
    name = name:gsub("%s*%(%d+%)%s*$", "")
    name = name:gsub("[_%-]+", " "):gsub("%s+", " ")
    name = soundTrim(name)
    name = name:gsub("%S+", function(word)
        return word:sub(1, 1):upper() .. word:sub(2):lower()
    end)
    return name ~= "" and name or "Sonido sin nombre"
end

function SoundCatalogCore.parseCatalog(items)
    local result = {}
    for _, item in ipairs(type(items) == "table" and items or {}) do
        local extension = type(item) == "table" and soundExtension(item.name) or nil
        if extension and item.type == "file"
            and type(item.download_url) == "string" and item.download_url ~= "" then
            table.insert(result, {
                name = tostring(item.name),
                label = SoundCatalogCore.prettyName(item.name),
                extension = extension,
                sha = tostring(item.sha or ""),
                url = item.download_url,
            })
        end
    end

    table.sort(result, function(left, right)
        local leftLabel, rightLabel = left.label:lower(), right.label:lower()
        if leftLabel == rightLabel then return left.name:lower() < right.name:lower() end
        return leftLabel < rightLabel
    end)

    local totals, seen = {}, {}
    for _, entry in ipairs(result) do
        local key = entry.label:lower()
        totals[key] = (totals[key] or 0) + 1
    end
    for _, entry in ipairs(result) do
        local key = entry.label:lower()
        if totals[key] > 1 then
            seen[key] = (seen[key] or 0) + 1
            entry.label = entry.label .. " [" .. tostring(seen[key]) .. "]"
        end
    end
    return result
end

function SoundCatalogCore.cachePath(entry)
    entry = type(entry) == "table" and entry or {}
    local extension = entry.extension or soundExtension(entry.name) or "mp3"
    local token = tostring(entry.sha or ""):gsub("[^%w]", ""):sub(1, 12)
    if token == "" then
        token = tostring(entry.name or "sound"):gsub("[^%w]", "_"):sub(1, 40)
    end
    return SoundCatalogCore.CACHE_FOLDER .. "/" .. token .. "." .. extension
end

function SoundCatalogCore.entryKey(entry)
    entry = type(entry) == "table" and entry or {}
    return tostring(entry.name or "") .. "@" .. tostring(entry.sha or "")
end

function SoundCatalogCore.isAudioPayload(statusCode, body, extension)
    local status = tonumber(statusCode)
    if not status or status < 200 or status >= 300 or type(body) ~= "string" or #body < 64 then
        return false
    end

    extension = string.lower(tostring(extension or "")):gsub("^%.", "")
    local isOgg = body:sub(1, 4) == "OggS"
    local first, second = string.byte(body, 1, 2)
    local isMp3 = body:sub(1, 3) == "ID3"
        or (first == 0xFF and second ~= nil and second >= 0xE0)

    if extension == "ogg" then return isOgg end
    if extension == "mp3" then return isMp3 end
    return isMp3 or isOgg
end

function SoundCatalogCore.matchesOriginal(soundId, soundName)
    local idText = soundTrim(soundId)
    local digits = idText:match("^rbxassetid://(%d+)$")
        or idText:match("^(%d+)$")
        or idText:match("[?&]id=(%d+)")
    return digits == SoundCatalogCore.TARGET_SOUND_ID
        or string.lower(soundTrim(soundName)) == "gunshot"
end

-- XERO_SOUND_CATALOG_CORE_END

local MM2_PLACE_ID = 142823291
local MMV_PLACE_ID = 74369636333825
local MMV2_PLACE_ID = 74369636333825
local DUELS_BIMO_PLACE_ID = 116817810725116


-- ==========================================
-- ESTADO COMPARTIDO PARA AUTO-SAVE
-- ==========================================
-- Estas variables deben existir ANTES de declarar las funciones de auto-save.
-- Si se declaran después, Lua las trata como locales distintas y el auto-save
-- termina leyendo/escribiendo valores incorrectos.
local macroActivo = false
local macroEquipDelay = 0.04
local macroShootDelay = 0.10
local knifeMacroEnabled = false
local triggerBotEnabled = false
local knifeEquipDelay = 0.10
local knifeThrowDelay = 0.10
local selectedPistolSkin = "Floral"

-- Soporte general de mando. La Dead Zone filtra el drift del stick derecho
-- incluso cuando no está activo el Aimbot Controller.
local controllerSupportEnabled = false
local controllerDeadZone = 0.20
local controllerSensitivity = 1.00
local controllerCameraSensitivity = 1.00
local controllerInvertY = false
local controllerDeadZoneAction = "XeroHub_Controller_DeadZone"
local controllerDeadZoneBound = false
local controllerAimbotEnabled = false
local controllerAimDeadZone = 0.20
local controllerAimConnection = nil
local controllerDriftAssistEnabled = false
local controllerDriftAssistStrength = 45
local controllerDriftAssistBind = "XeroHub_Drift_L1_R1"
local controllerDriftAssistBound = false
local stopControllerAimbot, startControllerAimbot

-- ==========================================
-- AUTO-SAVE / AUTO-LOAD REAL
-- ==========================================
-- Esta copia es independiente del selector "Auto Load Config".
-- Guarda una configuración completa en un archivo fijo y la restaura
-- DESPUÉS de que todos los controles/UI hayan sido creados.
local AUTO_CONFIG_FILE = "XeroHub_AutoConfig.json"
local AUTO_SAVE_DELAY = 0.30
local autoSaveReady = false
local autoSaveQueued = false
local autoConfigLoaded = false

local function autoCanWrite()
    return type(writefile) == "function"
end

local function autoCanRead()
    return type(readfile) == "function"
end

local function autoJsonEncode(data)
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONEncode(data)
    end)
    return ok and result or nil
end

local function autoJsonDecode(raw)
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    return ok and result or nil
end

local function buildAutoConfig()
    -- Guarda únicamente lo que realmente está activo/seleccionado.
    -- Así, al cargarlo en una ejecución nueva, todo lo omitido queda en su estado inicial.
    local toggles = {}
    local sliders = {}
    local colors = {}
    local extras = {}

    local function saveToggle(name, value)
        if value == true then toggles[name] = true end
    end

    local function saveSlider(name, value, enabled)
        if enabled then sliders[name] = tonumber(value) end
    end

    saveToggle("Auto Shoot", autoShootEnabled)
    saveToggle("AutoShoot Cuchillo", autoShootCuchilloEnabled)
    saveToggle("Silent Aim (Pistola)", silentAimPistolaEnabled)
    saveToggle("Silent Aim (Cuchillo)", silentAimCuchilloEnabled)
    saveToggle("Silent Aim (FOV)", silentAimFovEnabled)
    saveToggle("Mostrar Círculo FOV", fovVisiblePreference)
    saveToggle("ESP Lineas", espLinesEnabled)
    saveToggle("ESP Box 2D", espSettings.Box)
    saveToggle("ESP Barra Vida", espSettings.HealthBar)
    saveToggle("Btn Flotante AutoShoot", asBtn and asBtn.Visible)
    saveToggle("Btn Flotante SilentAim", saBtn and saBtn.Visible)
    saveToggle("Aumentar Hitbox", hitboxEnabled)
    saveToggle("Hitbox Invisible", hitboxInvisible)
    saveToggle("ESP Jugadores", espEnabled)
    saveToggle("Mostrar Resplandor (Glow)", espSettings.Glow)
    saveToggle("Mostrar Nombre", espSettings.Name)
    saveToggle("Mostrar Distancia", espSettings.Distance)
    saveToggle("Ocultar mi Nombre (Local)", hideNameEnabled)
    saveToggle("Activar Macro", macroActivo)
    saveToggle("Activar Trigger Bot", triggerBotEnabled)
    saveToggle("Macro Cuchillo (L2)", knifeMacroEnabled)
    saveToggle("Aimbot Controller Support", controllerAimbotEnabled)
    saveToggle("Controller Support", controllerSupportEnabled)
    saveToggle("Compensación Drift L1/R1", controllerDriftAssistEnabled)

    saveSlider("Tamaño del FOV", fovRadius, silentAimFovEnabled or fovVisiblePreference)
    saveSlider("Tamaño de Hitbox", hitboxSize, hitboxEnabled)
    saveSlider("Delay Equipar Macro", macroEquipDelay, macroActivo)
    saveSlider("Delay Disparo Macro", macroShootDelay, macroActivo)
    saveSlider("Delay Equipar Cuchillo", knifeEquipDelay, knifeMacroEnabled)
    saveSlider("Delay Lanzamiento Cuchillo", knifeThrowDelay, knifeMacroEnabled)
    saveSlider("Dead Zone Aimbot", controllerAimDeadZone * 100, controllerAimbotEnabled)
    saveSlider("Dead Zone del Stick", controllerDeadZone * 100, controllerSupportEnabled)
    saveSlider("Sensibilidad del Stick", controllerSensitivity * 100, controllerSupportEnabled)
    saveSlider("Sensibilidad de Cámara", controllerCameraSensitivity * 100, controllerSupportEnabled)
    saveSlider("Fuerza Drift L1/R1", controllerDriftAssistStrength, controllerDriftAssistEnabled)
    if controllerSupportEnabled then
        extras["Invertir Stick"] = controllerInvertY == true
    end

    if hitboxEnabled then
        colors["Color de Hitbox"] = {R = hitboxColor.R, G = hitboxColor.G, B = hitboxColor.B}
    end
    if espEnabled then
        colors["Color del ESP"] = {R = espColor.R, G = espColor.G, B = espColor.B}
    end

    if silentAimPistolaEnabled or silentAimCuchilloEnabled then
        extras["Partes Aimbot"] = runtime.GetTargetSelectionArray("SilentAim")
        extras["Parte Aimbot"] = silentAimTargetPart
    end
    if autoShootEnabled or autoShootCuchilloEnabled then
        extras["Partes AutoShoot"] = runtime.GetTargetSelectionArray("AutoShoot")
        extras["Parte AutoShoot"] = autoShootTargetPart
    end

    local data = {
        Version = 4,
        Toggles = toggles,
        Sliders = sliders,
        Colors = colors,
        Extras = extras,
    }

    -- Apariencia: solo se conserva si hay algo activado.
    if runtime.SerializeAppearanceConfig then
        local appearance = runtime.SerializeAppearanceConfig()
        local anyAppearance = false
        if type(appearance.Enabled) == "table" then
            for key, enabled in pairs(appearance.Enabled) do
                if enabled == true then anyAppearance = true break end
            end
        end
        if anyAppearance then
            data.Apariencia = appearance
        end
    end

    -- Sonidos: solo se conservan los que realmente están activados.
    if runtime.SerializeSoundConfig then
        local sounds = runtime.SerializeSoundConfig()
        local soundData = {}
        if sounds.Arma and (sounds.Arma.Activado == true or sounds.Arma.Silenciado == true) then
            soundData.Arma = sounds.Arma
        end
        if sounds.Muerte and sounds.Muerte.Activado == true then
            soundData.Muerte = sounds.Muerte
        end
        if next(soundData) ~= nil then data.Sonidos = soundData end
    end

    -- Skybox: solo si el usuario tiene uno realmente seleccionado.
    if modes and modes.active then
        data.Skybox = {
            Activado = true,
            Nombre = tostring(modes.active),
            CustomInput = tostring(modes.customInput or ""),
            Custom = type(skies) == "table" and type(skies.Custom) == "table" and table.clone(skies.Custom) or nil,
        }
    end

    -- Sonido al saltar: se lee mediante variables globales para poder conservar
    -- el auto-save aunque la UI de salto se declare más abajo en el archivo.
    local jumpEnabled = getgenv and getgenv().XeroJumpSoundEnabled == true
    local jumpLabel = runtime.JumpSoundSelectedLabel
    if jumpEnabled then
        data.SonidoSalto = {
            Activado = true,
            Seleccionado = jumpLabel,
        }
    end

    if selectedPistolSkin and selectedPistolSkin ~= "Floral" then
        data.PistolSkin = tostring(selectedPistolSkin)
    end

    return data
end

local function saveAutoConfig()
    if not autoSaveReady or not autoCanWrite() then return false end

    local encoded = autoJsonEncode(buildAutoConfig())
    if not encoded then return false end

    local ok = pcall(function()
        writefile(AUTO_CONFIG_FILE, encoded)
    end)

    return ok
end

local function queueAutoConfigSave()
    if not autoSaveReady or autoSaveQueued then return end

    autoSaveQueued = true
    task.delay(AUTO_SAVE_DELAY, function()
        autoSaveQueued = false
        saveAutoConfig()
    end)
end

local function markAutoConfigChanged()
    -- Un pequeño debounce evita escribir el archivo en cada tick del control.
    if autoSaveReady then
        queueAutoConfigSave()
    end
end

local function loadAutoConfig()
    if not autoCanRead() then return false end
    local okRead, raw = pcall(function() return readfile(AUTO_CONFIG_FILE) end)
    if not okRead or type(raw) ~= "string" or raw == "" then return false end
    local data = autoJsonDecode(raw)
    return type(data) == "table"
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local workspace = game:GetService("Workspace")

-- Estilo iOS: radios consistentes para ventana, controles y overlays.
local IOS_STYLE = {
    WindowRadius = 20,
    ElementRadius = 14,
    OverlayRadius = 14,
    OpenButtonRadius = 16,
}

task_wait = task.wait
task_spawn = task.spawn
task_delay = task.delay
math_floor = math.floor
math_rad = math.rad
string_lower = string.lower
string_find = string.find
table_insert = table.insert
table_sort = table.sort
Vector3_new = Vector3.new
Vector2_new = Vector2.new
CFrame_new = CFrame.new
Color3_fromRGB = Color3.fromRGB
getnamecallmethod = getnamecallmethod
checkcaller = checkcaller
typeof = typeof

-- 🔥 RUTAS DIRECTAS DE MEMORIA BLINDADAS
local function ws_Raycast(ws, origin, dir, params) return ws:Raycast(origin, dir, params) end
local Filter_Exclude = Enum.RaycastFilterType.Exclude

-- NUEVO CACHÉ PARA EVITAR LAG DE MOONVEIL
local function ffc(obj, name) return obj and obj:FindFirstChild(name) end
local function ffcClass(obj, className) return obj and obj:FindFirstChildOfClass(className) end
local getPlayers = Players.GetPlayers
local getChildren = Players.GetChildren
-- ==========================================
-- FILTRO DE ZONAS SEGURAS (Lobby, Votación, etc.)
-- ==========================================
local ZONAS_SEGURAS = {
    {Centro = Vector3.new(-320.50, 280.82, 16.00), Radio = 500, RadioSq = 250000}, -- Lobby principal
    {Centro = Vector3.new(1564.14, -155.45, 40.04), Radio = 300, RadioSq = 90000}  -- Zona de votación de mapa
}

local player = Players.LocalPlayer

-- ==========================================
-- SKINS DE PISTOLA - GitHub
-- ==========================================
local PISTOL_SKINS = {
    ["Floral"] = {
        url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/textures/pistola_floral.png",
        ext = "png"
    },
    ["Haunted"] = {
        url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/textures/1989.jpg",
        ext = "jpg"
    },
    ["Blanco/Negro"] = {
        url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/textures/pistola_chiquita_en_negro_.png",
        ext = "png"
    }
}


local function getSkinAsset(skinInfo, name)
    if type(skinInfo) ~= "table" or type(skinInfo.url) ~= "string" then
        return nil, "Ruta de skin inválida"
    end

    if type(writefile) ~= "function"
        or type(getcustomasset) ~= "function" then
        return nil, "Falta writefile o getcustomasset"
    end

    local folder = "XeroHub_Skins_V5"
    pcall(function()
        if type(isfolder) == "function" and not isfolder(folder)
            and type(makefolder) == "function" then
            makefolder(folder)
        end
    end)

    local ext = tostring(skinInfo.ext or "png"):lower()
    if ext ~= "png" and ext ~= "jpg" and ext ~= "jpeg" then
        ext = "png"
    end

    local safeName = tostring(name):gsub("[^%w_%-]", "_")
    local path = folder .. "/" .. safeName .. "." .. ext

    local function validImageData(data)
        if type(data) ~= "string" or #data < 64 then
            return false
        end

        local b1, b2, b3, b4 = data:byte(1, 4)
        local isPNG = b1 == 137 and b2 == 80 and b3 == 78 and b4 == 71
        local isJPG = b1 == 255 and b2 == 216 and b3 == 255
        return isPNG or isJPG
    end

    local function readCached()
        if type(readfile) ~= "function" then return nil end
        local ok, data = pcall(function()
            return readfile(path)
        end)
        if ok and validImageData(data) then
            return data
        end
        return nil
    end

    -- Si hay una copia dañada, la eliminamos y descargamos de nuevo.
    local cached = readCached()
    if not cached then
        if type(deletefile) == "function" then
            pcall(function() deletefile(path) end)
        end

        local data = nil

        -- request/http_request suele conservar mejor los bytes binarios que
        -- algunas implementaciones de game:HttpGet.
        local requestFn = nil
        if type(request) == "function" then
            requestFn = request
        elseif type(http_request) == "function" then
            requestFn = http_request
        elseif syn and type(syn.request) == "function" then
            requestFn = syn.request
        end

        if requestFn then
            local ok, response = pcall(function()
                return requestFn({
                    Url = skinInfo.url,
                    Method = "GET"
                })
            end)

            if ok and type(response) == "table"
                and (response.StatusCode == nil or tonumber(response.StatusCode) == 200)
                and type(response.Body) == "string" then
                data = response.Body
            end
        end

        if not validImageData(data) then
            local ok, fallback = pcall(function()
                return game:HttpGet(skinInfo.url)
            end)
            if ok and validImageData(fallback) then
                data = fallback
            end
        end

        if not validImageData(data) then
            return nil, "GitHub descargó datos inválidos para " .. tostring(name)
        end

        local okWrite = pcall(function()
            writefile(path, data)
        end)
        if not okWrite then
            return nil, "No se pudo escribir " .. path
        end
    end

    local ok, asset = pcall(function()
        return getcustomasset(path)
    end)

    if ok and type(asset) == "string" and asset ~= "" then
        return asset, path
    end

    return nil, "getcustomasset no pudo convertir " .. path
end

local function trySetTextureProperty(obj, propertyName, asset)
    local ok = pcall(function()
        obj[propertyName] = asset
    end)
    return ok
end

local function applyPistolSkin(tool, skinName)
    if not tool or (not tool:IsA("Tool") and not tool:IsA("Model")) then
        return false, 0, "No hay un modelo de pistola equipado."
    end

    local skinInfo = PISTOL_SKINS[skinName]
    if not skinInfo then
        return false, 0, "Skin desconocida: " .. tostring(skinName)
    end

    local asset, assetInfo = getSkinAsset(skinInfo, skinName)
    if not asset then
        return false, 0, assetInfo or "No se pudo crear el asset."
    end

    local changed = 0
    local inspected = 0
    local touched = {}

    for _, obj in ipairs(tool:GetDescendants()) do
        inspected = inspected + 1
        local ok = false

        -- Texturas/decals clásicos.
        if obj:IsA("Texture") or obj:IsA("Decal") then
            ok = trySetTextureProperty(obj, "Texture", asset)

        -- MeshPart.
        elseif obj:IsA("MeshPart") then
            ok = trySetTextureProperty(obj, "TextureID", asset)

        -- SpecialMesh.
        elseif obj:IsA("SpecialMesh") then
            ok = trySetTextureProperty(obj, "TextureId", asset)

        -- Algunos modelos usan SurfaceAppearance.
        elseif obj:IsA("SurfaceAppearance") then
            ok = trySetTextureProperty(obj, "ColorMap", asset)
        end

        if ok then
            changed = changed + 1
            table.insert(touched, obj:GetFullName())
        end
    end

    if changed == 0 then
        return false, 0,
            "No se encontró Texture, Decal, MeshPart, SpecialMesh o SurfaceAppearance modificable."
    end

    return true, changed,
        "Asset: " .. tostring(assetInfo) ..
        " | Revisados: " .. tostring(inspected)
end

local function findEquippedPistol()
    local character = player.Character
    if not character then return nil end

    local equipped = character:FindFirstChildOfClass("Tool")
    if not equipped then return nil end

    -- Si el juego tiene una herramienta claramente identificada como pistola,
    -- la usamos. Si no, usamos la Tool equipada.
    local lower = equipped.Name:lower()
    if lower:find("pistol") or lower:find("gun") or lower:find("revolver")
        or lower:find("weapon") then
        return equipped
    end

    return equipped
end

local function applySelectedPistolSkin()
    local tool = findEquippedPistol()
    if tool then
        local ok, count, detail = applyPistolSkin(tool, selectedPistolSkin)
        if ok and count > 0 then
            return ok, count, detail
        end
    end

    -- Algunos juegos dibujan el arma en un ViewModel dentro de CurrentCamera
    -- y no en la Tool del personaje. Intentamos modelos cuyo nombre identifica
    -- razonablemente un arma, sin tocar toda la cámara.
    local camera = workspace.CurrentCamera
    if camera then
        local total = 0
        local lastDetail = nil
        for _, obj in ipairs(camera:GetChildren()) do
            if obj:IsA("Model") then
                local n = obj.Name:lower()
                if n:find("pistol") or n:find("gun")
                    or n:find("revolver") or n:find("weapon")
                    or n:find("viewmodel") then
                    local ok, count, detail = applyPistolSkin(obj, selectedPistolSkin)
                    if ok and count > 0 then
                        total = total + count
                        lastDetail = detail
                    end
                end
            end
        end
        if total > 0 then
            return true, total, lastDetail
        end
    end

    return false, 0,
        "No se encontraron texturas modificables en la pistola/visual model."
end


while not player do
    task.wait()
    player = Players.LocalPlayer
end

local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

-- Ciclo de vida único: evita que una reejecución deje Heartbeats, RenderStepped
-- u objetos Drawing de la sesión anterior consumiendo CPU en segundo plano.
local runtimeEnv = (getgenv and getgenv()) or _G
local previousRuntime = runtimeEnv.__ILUNX_RUNTIME
if previousRuntime and previousRuntime.Cleanup then
    pcall(previousRuntime.Cleanup)
end

local runtime = {
    Alive = true,
    Connections = {},
    Drawings = {},
    InfectedTexts = setmetatable({}, {__mode = "k"}),
}

runtime.NextConnectionPruneAt = 96

function runtime.PruneConnections()
    local list = runtime.Connections
    local writeIndex = 1

    for readIndex = 1, #list do
        local connection = list[readIndex]
        local connected = false
        if connection then
            pcall(function() connected = connection.Connected == true end)
        end

        if connected then
            list[writeIndex] = connection
            writeIndex = writeIndex + 1
        end
    end

    for index = #list, writeIndex, -1 do
        list[index] = nil
    end

    -- No barremos en cada Track: sólo después de crecer otra tanda razonable.
    runtime.NextConnectionPruneAt = #list + 64
end

function runtime.Track(connection)
    if connection then
        local list = runtime.Connections
        list[#list + 1] = connection
        if #list >= (runtime.NextConnectionPruneAt or 96) then
            runtime.PruneConnections()
        end
    end
    return connection
end

function runtime.TrackDrawing(drawing)
    if drawing then table.insert(runtime.Drawings, drawing) end
    return drawing
end

function runtime.UntrackDrawing(drawing)
    if not drawing then return end
    local list = runtime.Drawings
    for i = #list, 1, -1 do
        if list[i] == drawing then
            list[i] = list[#list]
            list[#list] = nil
            return
        end
    end
end

function runtime.RemoveDrawing(drawing)
    if not drawing then return end
    runtime.UntrackDrawing(drawing)
    pcall(function() drawing:Remove() end)
end

function runtime.TrackInfectedText(textObject)
    if textObject then runtime.InfectedTexts[textObject] = true end
    return textObject
end

function runtime.Cleanup()
    if not runtime.Alive then return end
    runtime.Alive = false
    if runtime.GraphicsCleanup then pcall(runtime.GraphicsCleanup) end
    if runtime.SoundCleanup then pcall(runtime.SoundCleanup) end

    for i = #runtime.Connections, 1, -1 do
        local connection = runtime.Connections[i]
        pcall(function() connection:Disconnect() end)
        runtime.Connections[i] = nil
    end

    for i = #runtime.Drawings, 1, -1 do
        local drawing = runtime.Drawings[i]
        pcall(function() drawing:Remove() end)
        runtime.Drawings[i] = nil
    end

    for textObject in pairs(runtime.InfectedTexts) do
        pcall(function() textObject:SetAttribute("AstraInfectado", nil) end)
        runtime.InfectedTexts[textObject] = nil
    end

    if runtime.AimState and runtime.AimState.Owner == runtime then
        runtime.AimState.Target = nil
        runtime.AimState.Owner = nil
    end

    if runtime.GhostCleanup then
        pcall(runtime.GhostCleanup)
    end

    if runtime.AvatarThumbnailSpoofCleanup then
        pcall(runtime.AvatarThumbnailSpoofCleanup)
    end

    if runtime.AppearanceCleanup then
        pcall(runtime.AppearanceCleanup)
    end

    if runtime.BodySelectorGui then
        pcall(function() runtime.BodySelectorGui:Destroy() end)
        runtime.BodySelectorGui = nil
    end

    if runtime.AppearanceStudioGui then
        if runtime.AppearanceStudio and runtime.AppearanceStudio.BaseAvatarTemplate then
            pcall(function() runtime.AppearanceStudio.BaseAvatarTemplate:Destroy() end)
        end
        pcall(function() runtime.AppearanceStudioGui:Destroy() end)
        runtime.AppearanceStudioGui = nil
        runtime.AppearanceStudio = nil
    end

    if runtime.StartupGui then
        pcall(function() runtime.StartupGui:Destroy() end)
        runtime.StartupGui = nil
    end

    if runtime.NotificationGui then
        pcall(function() runtime.NotificationGui:Destroy() end)
        runtime.NotificationGui = nil
    end

    if runtime.ScreenGui then
        pcall(function() runtime.ScreenGui:Destroy() end)
        runtime.ScreenGui = nil
    end
end

runtimeEnv.__ILUNX_RUNTIME = runtime

function AstraRequest(ruta)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        local success, response = pcall(function()
            return req({
                Url = "https://hub.onyx-scripts.com" .. ruta,
                Method = "GET",
                Headers = {
                    ["Astra-Auth"] = "OnyxHub!", 
                    ["User-Agent"] = "Roblox/iLunXHub"
                }
            })
        end)
        if success and response then return response.Body end
    end
    return nil
end

task.spawn(function()
    local banStatus = AstraRequest("/check_ban")
    if banStatus == "BANNED" then
        player:Kick("\nXeroHub SECURITY\nTu red (IP) está baneada permanentemente del Hub por intento de robo o violación de reglas.\n\n.")
    end
end)



-- ==========================================
--  VARIABLES GLOBALES DE CONFIGURACIÓN 
-- ==========================================
_G.AstraBotonesOcultos = false
fovVisiblePreference = false
fovRadius = 120
fovFollowsCursor = false
activeTouches = {}
extraFovCircles = {}
aimbotEnabled = false
autoShootEnabled = false
fullAimbotEnabled = false
hitboxEnabled = false
hitboxInvisible = false 
hitboxTransparency = 0.6
hitboxSize = 10
hitboxColor = Color3.fromRGB(255, 255, 255)
teamCheckEnabled = true
espEnabled = false
espColor = Color3.fromRGB(255, 255, 255)
espSettings = { Glow = true, Name = true, Distance = true, Box = false, HealthBar = false }
espLinesEnabled = false
gunKillEnabled = false
knifeKillEnabled = false
flying = false
flySpeed = 50
emoteWalkEnabled = false 
currentEmoteTrack = nil
allEmotes = {}
filteredEmotes = {}
currentPage = 1
emotesPerPage = 12
hideNameEnabled = false
fakeNameEnabled = false
rainbowEnabled = false
creatorTagEnabled = false 
spoofNameText = "Nombre falso"
aimbotTargetPart = "Cabeza"

local UIElements = {} -- Tabla para guardar referencias

local playerGui = player:WaitForChild("PlayerGui")
local previousOverlay = playerGui:FindFirstChild("XeroHub_Overlays") or playerGui:FindFirstChild("iLunXHub_Overlays")
if previousOverlay then
    previousOverlay:Destroy()
end

-- ==========================================
-- ÚNICA ANIMACIÓN: SPLASH REAL AL EJECUTAR
-- ==========================================
local startupSplashState = {}

do
    -- Splash: negro real, nítido y cubriendo todo el viewport.
    local splashParent = playerGui
    pcall(function()
        if gethui then splashParent = gethui() else splashParent = game:GetService("CoreGui") end
    end)

    local previousSplash = splashParent and (splashParent:FindFirstChild("XeroHub_Startup") or splashParent:FindFirstChild("iLunXHub_Startup"))
    if previousSplash then previousSplash:Destroy() end

    local startupGui = Instance.new("ScreenGui")
    startupGui.Name = "XeroHub_Startup"
    startupGui.ResetOnSpawn = false
    startupGui.IgnoreGuiInset = true
    startupGui.DisplayOrder = 2147483647
    startupGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() startupGui.ScreenInsets = Enum.ScreenInsets.None end)
    pcall(function() startupGui.ClipToDeviceSafeArea = false end)

    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(startupGui) end
    end)

    local parented = pcall(function() startupGui.Parent = splashParent end)
    if not parented then startupGui.Parent = playerGui end
    runtime.StartupGui = startupGui

    local splash = Instance.new("CanvasGroup")
    splash.Name = "Splash"
    splash.Size = UDim2.fromScale(1, 1)
    splash.Position = UDim2.fromScale(0, 0)
    splash.BackgroundColor3 = Color3.new(0, 0, 0)
    splash.BackgroundTransparency = 0
    splash.BorderSizePixel = 0
    splash.GroupTransparency = 0
    splash.Active = true
    splash.ZIndex = 1
    splash.Parent = startupGui

    local content = Instance.new("Frame")
    content.Name = "LoaderContent"
    content.AnchorPoint = Vector2.new(0.5, 0.5)
    content.Position = UDim2.fromScale(0.5, 0.5)
    content.Size = UDim2.fromOffset(460, 128)
    content.BackgroundTransparency = 1
    content.ZIndex = 2
    content.Parent = splash

    local contentScale = Instance.new("UIScale")
    contentScale.Scale = 1
    contentScale.Parent = content

    local brand = Instance.new("TextLabel")
    brand.AnchorPoint = Vector2.new(0.5, 0)
    brand.Size = UDim2.new(1, 0, 0, 46)
    brand.Position = UDim2.new(0.5, 0, 0, 10)
    brand.BackgroundTransparency = 1
    brand.RichText = true
    brand.Text = '<font color="#FFFFFF">XERO</font><font color="#A7A7A7"> HUB</font>'
    brand.TextColor3 = Color3.new(1, 1, 1)
    brand.TextTransparency = 0
    brand.Font = Enum.Font.GothamBold
    brand.TextSize = 32
    brand.TextXAlignment = Enum.TextXAlignment.Center
    brand.ZIndex = 3
    brand.Parent = content

    local status = Instance.new("TextLabel")
    status.AnchorPoint = Vector2.new(0.5, 0)
    status.Size = UDim2.new(1, -48, 0, 22)
    status.Position = UDim2.new(0.5, 0, 0, 62)
    status.BackgroundTransparency = 1
    status.Text = "Cargando XeroHub..."
    status.TextColor3 = Color3.fromHex("#9B9B9B")
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 13
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.ZIndex = 3
    status.Parent = content

    local progressTrack = Instance.new("Frame")
    progressTrack.AnchorPoint = Vector2.new(0.5, 0)
    progressTrack.Size = UDim2.fromOffset(230, 2)
    progressTrack.Position = UDim2.new(0.5, 0, 0, 98)
    progressTrack.BackgroundColor3 = Color3.fromHex("#242424")
    progressTrack.BorderSizePixel = 0
    progressTrack.ZIndex = 3
    progressTrack.Parent = content
    Instance.new("UICorner", progressTrack).CornerRadius = UDim.new(1, 0)

    local progress = Instance.new("Frame")
    progress.Size = UDim2.fromScale(0.04, 1)
    progress.BackgroundColor3 = Color3.fromHex("#E7E7E7")
    progress.BorderSizePixel = 0
    progress.ZIndex = 4
    progress.Parent = progressTrack
    Instance.new("UICorner", progress).CornerRadius = UDim.new(1, 0)

    startupSplashState.Gui = startupGui
    startupSplashState.Group = splash
    startupSplashState.Card = content
    startupSplashState.Status = status

    startupSplashState.Progress = progress
end

function startupSplashState.Finish(message)
    local startupGui = startupSplashState.Gui
    if not startupGui or not startupGui.Parent then return end

    -- Sólo los errores conservan un momento de lectura. La carga correcta
    -- termina inmediatamente, sin duración mínima ni esperar animaciones.
    if message and startupSplashState.Status then
        startupSplashState.Status.Text = message
        task.wait(0.65)
    end
    if startupSplashState.Progress then
        startupSplashState.Progress.Size = UDim2.fromScale(1, 1)
    end
    if startupGui.Parent then startupGui:Destroy() end
    runtime.StartupGui = nil
    startupSplashState.Gui = nil
    startupSplashState.Group = nil
    startupSplashState.Card = nil
    startupSplashState.Status = nil
    startupSplashState.Progress = nil
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XeroHub_Overlays"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true 
screenGui.DisplayOrder = 999 
screenGui.Parent = playerGui
runtime.ScreenGui = screenGui

local espFolder = Instance.new("Folder")
espFolder.Name = "iLunXESPFolder"
espFolder.Parent = screenGui

local activeDrag = nil

-- Una sola conexión global mueve todos los botones arrastrables. Esto evita
-- acumular listeners cada vez que se crea un nuevo botón flotante.
runtime.Track(UserInputService.InputChanged:Connect(function(input)
    local drag = activeDrag
    if not drag or input ~= drag.Input then return end
    if not drag.Object or not drag.Object.Parent then
        activeDrag = nil
        return
    end

    local delta = input.Position - drag.Start
    drag.Object.Position = UDim2.new(
        drag.Position.X.Scale,
        drag.Position.X.Offset + delta.X,
        drag.Position.Y.Scale,
        drag.Position.Y.Offset + delta.Y
    )
end))

local function makeDraggable(guiObject, objectToMove)
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeDrag = {
                Source = guiObject,
                Object = objectToMove,
                Input = input.UserInputType == Enum.UserInputType.Touch and input or nil,
                Start = input.Position,
                Position = objectToMove.Position,
            }

            local endedConnection
            endedConnection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if activeDrag and activeDrag.Source == guiObject then
                        activeDrag = nil
                    end
                    if endedConnection then
                        endedConnection:Disconnect()
                        endedConnection = nil
                    end
                end
            end)
        end
    end)

    guiObject.InputChanged:Connect(function(input)
        if activeDrag and activeDrag.Source == guiObject
            and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            activeDrag.Input = input
        end
    end)
end

-- ==========================================
-- NOXHUB / UI SEPARADA
-- La lógica carga XeroHub_UI.lua por archivo local o URL RAW.
-- ==========================================
local WindUI
-- UI separada: puedes ofuscar este archivo sin mezclar las ~1k líneas visuales.
-- Orden de carga: archivo local XeroHub_UI.lua -> URL RAW oficial de XeroHub.
local NOX_UI_URL = ((getgenv and getgenv()) or _G).NOX_UI_URL or "https://raw.githubusercontent.com/OnyxDevv/Onyx-web/refs/heads/main/main%20(3).lua"
local ok, result = pcall(function()
    local source
    if isfile and readfile and isfile("XeroHub_UI.lua") then
        source = readfile("XeroHub_UI.lua")
    elseif NOX_UI_URL ~= "" then
        source = game:HttpGet(NOX_UI_URL)
    else
        error("Falta XeroHub_UI.lua o getgenv().NOX_UI_URL")
    end
    -- XeroHub UI patch: el main remoto actual no tiene numeración para Sonidos.
    -- Se corrige en memoria antes de compilar para no requerir otro archivo UI local.
    if type(source) == "string" then
        source = source:gsub(
            'AutoFarm="06",%["Gráficos"%]="07",Animaciones="08",Apariencia="09",%["Generar Armas"%]="10",%["Configuración"%]="11",%["Créditos"%]="12"',
            'AutoFarm="06",["Gráficos"]="07",Sonidos="08",Animaciones="09",Apariencia="10",["Generar Armas"]="11",["Configuración"]="12",["Créditos"]="13"',
            1
        )
        source = source:gsub(
            '%["Gráficos"%]="Ajusta el ambiente, la iluminación y los efectos%.",',
            '["Gráficos"]="Ajusta el ambiente, la iluminación y los efectos.", Sonidos="Personaliza los sonidos de disparo y muerte.",',
            1
        )
    end
    local chunk, compileError = loadstring(source)
    if not chunk then error("No se pudo compilar: " .. tostring(compileError)) end
    return chunk()
end)

if ok and result then
    WindUI = result
else
    warn("[XeroHub] No se pudo iniciar la UI: " .. tostring(result))
    startupSplashState.Finish("No se pudo cargar XeroHub")
    runtime.Cleanup()
    return
end

local Window = WindUI:CreateWindow({
    Title = "Xero | DUELS",
    Subtitle = "DUELS",
    Theme = "Xero",
    Author = "by Kev",
    Size = UDim2.fromOffset(620, 350),
    MinSize = Vector2.new(330, 270),
    Resizable = true,
    OpenButton = {Title = "Abrir XeroHub", Enabled = true},
})

-- La UI ya está cargada; el resto del arranque prepara sus controles.
if startupSplashState.Progress then
    startupSplashState.Progress.Size = UDim2.fromScale(0.65, 1)
    startupSplashState.Status.Text = "Preparando controles..."
end

pcall(function()
    Window:OnDestroy(runtime.Cleanup)
end)


-- ==========================================
-- CONTADOR DE USUARIOS ACTIVOS (CACHÉ OPTIMIZADO)
-- ==========================================
task.spawn(function()
    -- Obtenemos la función HTTP compatible con el ejecutor
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if not req then return end
    local lastActiveUsersCount = nil
    
    while runtime.Alive do
        local success, response = pcall(function()
            return req({
                Url = "https://hub.onyx-scripts.com/ping?user=" .. tostring(player.Name) .. "&jobid=" .. tostring(game.JobId),
                Method = "GET",
                Headers = {
                    ["Astra-Auth"] = "OnyxHub!", 
                    ["User-Agent"] = "Roblox/iLunXHub"
                }
            })
        end)
        
        if success and response and response.StatusCode == 200 then
            local vivos = tonumber(response.Body)
            if vivos and vivos ~= lastActiveUsersCount then
                lastActiveUsersCount = vivos
                Window:SetTitle("XERO | DUELS · " .. tostring(vivos) .. " activos")
            end
        end
        if runtime.Alive then task.wait(10) end
    end
end)

-- ==========================================
-- NOTIFICACIONES XERO: tarjetas monocromáticas desde la derecha
-- Entra y sale rápido; la cola corta descarta avisos viejos para no atrasarse.
-- ==========================================
local sendNotification
do
local NOTIFICATION_TIMING = {
    Enter = 0.18,
    Hold = 0.68,
    Exit = 0.14,
    Gap = 0.015,
}

local notificationGui = Instance.new("ScreenGui")
notificationGui.Name = "XeroHub_Notifications"
notificationGui.ResetOnSpawn = false
notificationGui.IgnoreGuiInset = true
notificationGui.DisplayOrder = 2147483647
notificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
notificationGui.Parent = playerGui
runtime.NotificationGui = notificationGui

local NotifContainer = Instance.new("Frame")
NotifContainer.Name = "XeroNotifications"
NotifContainer.Size = UDim2.fromScale(1, 1)
NotifContainer.BackgroundTransparency = 1
NotifContainer.Active = false
NotifContainer.ZIndex = 200
NotifContainer.Parent = notificationGui

local notificationQueue = {}
local notificationWorkerRunning = false
local lastNotificationText = nil
local lastNotificationAt = 0
runtime.NotificationSerial = 0
runtime.NotificationsReady = false

local function createMinimalBanner(payload)
    local banner = Instance.new("CanvasGroup")
    banner.Name = "XeroToast"
    banner.AnchorPoint = Vector2.new(1, 0)
    banner.Position = UDim2.new(1, 374, 0, 64)
    banner.Size = UDim2.new(1, -24, 0, 82)
    banner.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
    banner.BackgroundTransparency = 0.02
    banner.BorderSizePixel = 0
    banner.ClipsDescendants = true
    banner.GroupTransparency = 1
    banner.ZIndex = 201
    banner.Parent = NotifContainer
    local limit = Instance.new("UISizeConstraint", banner)
    limit.MaxSize = Vector2.new(350, 82)
    Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", banner)
    stroke.Color = Color3.fromRGB(68, 68, 68)
    stroke.Transparency = 0.2
    stroke.Thickness = 1

    local accent = Instance.new("Frame", banner)
    accent.Size = UDim2.new(0, 2, 1, -28)
    accent.Position = UDim2.fromOffset(12, 14)
    accent.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    accent.BorderSizePixel = 0
    accent.ZIndex = 202
    Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

    local title = Instance.new("TextLabel", banner)
    title.Size = UDim2.new(1, -46, 0, 16)
    title.Position = UDim2.fromOffset(25, 11)
    title.BackgroundTransparency = 1
    title.Text = string.upper(payload.title)
    title.TextColor3 = Color3.fromRGB(245, 245, 245)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 10
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 202

    local body = Instance.new("TextLabel", banner)
    body.Size = UDim2.new(1, -46, 0, 44)
    body.Position = UDim2.fromOffset(25, 29)
    body.BackgroundTransparency = 1
    body.Text = payload.text
    body.TextColor3 = Color3.fromRGB(185, 185, 185)
    body.Font = Enum.Font.Gotham
    body.TextSize = 12
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.ZIndex = 202
    -- Grow for longer messages and narrow screens, without clipping their text.
    local function fitText()
        local width = math.max(1, banner.AbsoluteSize.X - 46)
        local measured = game:GetService("TextService"):GetTextSize(
            payload.text, 12, Enum.Font.Gotham, Vector2.new(width, 10000))
        local height = math.max(82, math.ceil(measured.Y) + 44)
        limit.MaxSize = Vector2.new(350, height)
        banner.Size = UDim2.new(1, -24, 0, height)
        body.Size = UDim2.new(1, -46, 1, -40)
    end
    banner:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitText)
    fitText()
    return banner
end

local function runNotificationQueue()
    if notificationWorkerRunning then return end
    notificationWorkerRunning = true

    task.spawn(function()
        while runtime.Alive and #notificationQueue > 0 do
            local payload = table.remove(notificationQueue, 1)
            local banner = createMinimalBanner(payload)

            local enterTween = TweenService:Create(
                banner,
                TweenInfo.new(NOTIFICATION_TIMING.Enter, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {Position = UDim2.new(1, -12, 0, 64), GroupTransparency = 0}
            )
            enterTween:Play()
            enterTween.Completed:Wait()

            task.wait(payload.duration)
            if not runtime.Alive or not banner.Parent then break end

            local exitTween = TweenService:Create(
                banner,
                TweenInfo.new(NOTIFICATION_TIMING.Exit, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                {Position = UDim2.new(1, 374, 0, 64), GroupTransparency = 1}
            )
            exitTween:Play()
            exitTween.Completed:Wait()
            if banner.Parent then banner:Destroy() end
            task.wait(NOTIFICATION_TIMING.Gap)
        end

        notificationWorkerRunning = false
        if runtime.Alive and #notificationQueue > 0 then
            runNotificationQueue()
        end
    end)
end

sendNotification = function(text, options)
    options = type(options) == "table" and options or {}
    if not runtime.Alive then return end
    if (not runtime.NotificationsReady or runtime.SuppressNotifications) and not options.force then return end

    text = tostring(text or "")
    if text == "" then return end

    -- El serial permite que los wrappers sepan que el callback ya avisó,
    -- incluso cuando el texto repetido se descarta visualmente.
    runtime.NotificationSerial = (runtime.NotificationSerial or 0) + 1

    local now = os.clock()
    if text == lastNotificationText and now - lastNotificationAt < 0.25 then return end
    lastNotificationText = text
    lastNotificationAt = now

    local holdDuration = tonumber(options.duration)
    if not holdDuration then
        holdDuration = #text > 90 and 0.95 or (#text > 55 and 0.80 or NOTIFICATION_TIMING.Hold)
    end
    holdDuration = math.clamp(holdDuration, 0.40, 1.20)

    local payload = {
        text = text,
        title = tostring(options.title or "XeroHub"),
        icon = tostring(options.icon or "◇"),
        accent = Color3.fromHex("#E6E6E6"),
        duration = holdDuration,
        key = options.key,
    }

    -- Sustituye estados todavía pendientes del mismo control; no tiene sentido
    -- mostrar "activado" si el usuario ya volvió a desactivarlo.
    if payload.key then
        for index = #notificationQueue, 1, -1 do
            if notificationQueue[index].key == payload.key then
                table.remove(notificationQueue, index)
            end
        end
    end

    if options.priority then
        table.insert(notificationQueue, 1, payload)
    else
        table.insert(notificationQueue, payload)
    end

    -- Máximo cuatro pendientes: los avisos recientes aparecen pronto.
    while #notificationQueue > 4 do
        if options.priority then table.remove(notificationQueue, #notificationQueue)
        else table.remove(notificationQueue, 1) end
    end
    runNotificationQueue()
end
end

-- Conserva el nombre usado por las funciones existentes del script.
function showBottomMessage(text, options)
    sendNotification(text, options)
end




local MainSection = Window:Section({ Title = "PRINCIPAL", Opened = true })
local ConfigSection = Window:Section({ Title = "CONFIGURACIÓN", Opened = true })

-- ÚNICAS pestañas visibles del XeroHub Lite.
local Tabs = {
    Inicio = MainSection:Tab({Title = "Inicio", Icon = "solar:home-bold"}),
    Aim = MainSection:Tab({Title = "Macro / Silent", Icon = "solar:target-bold"}),
    Vis = MainSection:Tab({Title = "ESP", Icon = "solar:eye-bold"}),
    Sonidos = MainSection:Tab({Title = "Sounds", Icon = "solar:volume-loud-bold"}),
    Config = ConfigSection:Tab({Title = "Configuración", Icon = "solar:settings-bold"}),
}

-- Compatibilidad para el código interno antiguo. Estas referencias NO crean
-- pestañas ni controles visibles y evitan errores en bloques que no queremos mostrar.

-- ==========================================
-- PESTAÑA SONIDOS: catálogo automático del repo + overlay local del disparo
-- ==========================================
do
local soundEnv = (getgenv and getgenv()) or _G
local soundAssetLoader = getcustomasset
    or getsynasset
    or (syn and (syn.getcustomasset or syn.getsynasset))
local soundCatalogCachePath = SoundCatalogCore.CACHE_FOLDER .. "/catalog.json"

local soundState = {
    Enabled = false,
    DesiredEnabled = false,
    Catalog = {},
    ByLabel = {},
    SelectedLabel = nil,
    ActiveLabel = nil,
    ActiveKey = nil,
    PendingKey = nil,
    LoadToken = 0,
    CatalogToken = 0,
    PreviewToken = 0,
    ReplacementSound = nil,
    PreviewSound = nil,
    Originals = setmetatable({}, {__mode = "k"}),
    Bindings = setmetatable({}, {__mode = "k"}),
    PendingBindings = setmetatable({}, {__mode = "k"}),
    Muting = setmetatable({}, {__mode = "k"}),
    LastTrigger = setmetatable({}, {__mode = "k"}),
    MuteGunshot = false,
    SyncingMuteToggle = false,
}
runtime.SoundChanger = soundState

-- Sonido de muerte separado del disparo. Comparte catálogo/caché, no estado.
local killSoundState = {
    Enabled = false,
    DesiredEnabled = false,
    SelectedLabel = nil,
    ActiveLabel = nil,
    ActiveKey = nil,
    PendingKey = nil,
    LoadToken = 0,
    -- Este Sound ya viene precargado. GunKill usa su SoundId directamente;
    -- Died/uuhhh lo usa sólo como fallback cuando no hay trigger nativo.
    ReplacementSound = nil,
    NativeOriginalIds = setmetatable({}, {__mode = "k"}),
    NativeUpdating = setmetatable({}, {__mode = "k"}),
    NativeAppliedIds = setmetatable({}, {__mode = "k"}),
    -- Died nativo de la víctima: se parchea ANTES de la muerte y se restaura después.
    NativeDeathOriginalIds = setmetatable({}, {__mode = "k"}),
    NativeDeathUpdating = setmetatable({}, {__mode = "k"}),
    NativeDeathAppliedIds = setmetatable({}, {__mode = "k"}),
    NativeDeathTargetTokens = setmetatable({}, {__mode = "k"}),
    NativeDeathTargetConnections = setmetatable({}, {__mode = "k"}),
    NativeDeathSerial = 0,
    RecentNativeDeathTarget = nil,
    DynamicOriginals = setmetatable({}, {__mode = "k"}),
    Bindings = setmetatable({}, {__mode = "k"}),
    PendingBindings = setmetatable({}, {__mode = "k"}),
    Muting = setmetatable({}, {__mode = "k"}),
    LastTrigger = setmetatable({}, {__mode = "k"}),
    AttackTools = setmetatable({}, {__mode = "k"}),
    AttackMonitorConnections = {},
    RecentLocalAttack = 0,
    RecentAttackTool = nil,
    LastConfirmedKillTrigger = 0,
    LastKillReplacementAt = 0,
    TriggeredHumanoids = setmetatable({}, {__mode = "k"}),
    ActiveOneShots = setmetatable({}, {__mode = "k"}),
    SuppressedGunKillOriginalVolumes = setmetatable({}, {__mode = "k"}),
    -- Mientras el custom de kill está activo, los Died ajenos quedan mudos por
    -- defecto. Sólo se vuelve audible el Died exacto que ya tiene el custom.
    SuppressedDeathOriginalVolumes = setmetatable({}, {__mode = "k"}),
}
runtime.KillSoundChanger = killSoundState

local KILL_GUN_SOUND_ID = "296102734"
local DEFAULT_DEATH_SOUND = "rbxasset://sounds/uuhhh.mp3"
local KILL_FALLBACK_ATTACK_WINDOW = 1.25
local KILL_DUPLICATE_WINDOW = 0.22
local NATIVE_DEATH_ARM_WINDOW = 2.00
local NATIVE_DEATH_RESTORE_AFTER_DEATH = 2.20
local NATIVE_DEATH_TOUCH_WINDOW = 0.90
local NATIVE_DEATH_MAX_TARGET_DISTANCE = 22
local NATIVE_DEATH_NEAREST_DISTANCE = 16

local soundDropdown
local soundToggle
local muteGunshotToggle
local killSoundDropdown
local killSoundToggle

local function soundRequest(url)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        local ok, response = pcall(function()
            return req({
                Url = url,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "XeroHub-Sounds/1.0",
                    ["Accept"] = "application/vnd.github+json",
                },
            })
        end)
        if ok and type(response) == "table" then
            local status = tonumber(response.StatusCode or response.Status or 0) or 0
            local body = response.Body or response.body
            if status == 0 and response.Success == true then status = 200 end
            if type(body) == "string" and status > 0 then return body, status end
        end
    end

    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body, 200 end
    return nil, 0
end

local function ensureSoundFolder()
    if type(makefolder) ~= "function" then return false end
    if not isfolder or not isfolder("XeroHub") then pcall(makefolder, "XeroHub") end
    if not isfolder or not isfolder(SoundCatalogCore.CACHE_FOLDER) then
        pcall(makefolder, SoundCatalogCore.CACHE_FOLDER)
    end
    if type(isfolder) == "function" then
        local ok, exists = pcall(isfolder, SoundCatalogCore.CACHE_FOLDER)
        return ok and exists == true
    end
    return true
end

local function decodeCatalog(body)
    if type(body) ~= "string" or body == "" then return nil end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok then return nil end
    local parsed = SoundCatalogCore.parseCatalog(decoded)
    return #parsed > 0 and parsed or nil
end

local function fallbackCatalog()
    return SoundCatalogCore.parseCatalog({
        {
            name = "holyshit-female.mp3",
            type = "file",
            sha = "674d3a85092fe12c0118dcee6234d9391b29b7     ",
            download_url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/sounds/holyshit-female.mp3",
        },
    })
end

local function fetchSoundCatalog()
    local body, status = soundRequest(SoundCatalogCore.CATALOG_URL)
    local catalog = status >= 200 and status < 300 and decodeCatalog(body) or nil
    if catalog then
        if type(writefile) == "function" then
            ensureSoundFolder()
            pcall(writefile, soundCatalogCachePath, body)
        end
        return catalog, "GitHub"
    end

    if type(isfile) == "function" and type(readfile) == "function"
        and isfile(soundCatalogCachePath) then
        local ok, cached = pcall(readfile, soundCatalogCachePath)
        catalog = ok and decodeCatalog(cached) or nil
        if catalog then return catalog, "caché" end
    end
    return fallbackCatalog(), "respaldo"
end

local function getSelectedEntry()
    return soundState.ByLabel[soundState.SelectedLabel]
end

local function waitForSoundLoaded(sound, timeout)
    task.spawn(function()
        pcall(function() ContentProvider:PreloadAsync({sound}) end)
    end)
    local deadline = os.clock() + (tonumber(timeout) or 8)
    while runtime.Alive and sound and sound.Parent and os.clock() < deadline do
        if sound.IsLoaded then return true end
        task.wait(0.05)
    end
    return sound and sound.Parent and sound.IsLoaded == true
end

local function downloadSound(entry)
    if type(soundAssetLoader) ~= "function" then
        return nil, "Tu ejecutor no incluye getcustomasset/getsynasset."
    end
    if type(writefile) ~= "function" then
        return nil, "Tu ejecutor no permite guardar el audio con writefile."
    end

    local hasFolders = ensureSoundFolder()
    local localPath = SoundCatalogCore.cachePath(entry)
    if not hasFolders then
        localPath = "XeroHub_SoundV2_" .. localPath:match("([^/]+)$")
    end

    local validCache = false
    if type(isfile) == "function" and type(readfile) == "function" and isfile(localPath) then
        local ok, cached = pcall(readfile, localPath)
        validCache = ok and SoundCatalogCore.isAudioPayload(200, cached, entry.extension)
    end

    if not validCache then
        local body, status = soundRequest(entry.url)
        if not SoundCatalogCore.isAudioPayload(status, body, entry.extension) then
            return nil, "GitHub no devolvió un " .. string.upper(entry.extension) .. " válido (HTTP " .. tostring(status) .. ")."
        end
        local ok, writeError = pcall(writefile, localPath, body)
        if not ok then return nil, "No se pudo guardar el audio: " .. tostring(writeError) end
    end

    local ok, assetId = pcall(soundAssetLoader, localPath)
    if not ok or type(assetId) ~= "string" or assetId == "" then
        return nil, "El ejecutor no pudo registrar el audio local."
    end
    return assetId, localPath
end

local function createLoadedSound(entry, objectName)
    local assetId, result = downloadSound(entry)
    if not assetId then return nil, result end

    local sound = Instance.new("Sound")
    sound.Name = objectName
    sound.SoundId = assetId
    sound.Volume = 1
    sound.Parent = SoundService

    if not waitForSoundLoaded(sound, 8) then
        pcall(function() sound:Destroy() end)
        return nil, "El archivo se registró, pero Roblox no terminó de cargarlo."
    end
    return sound, result
end

local function disconnectConnectionList(connections)
    for _, connection in ipairs(connections or {}) do
        pcall(function() connection:Disconnect() end)
    end
end

local function disconnectSoundBindings()
    for sound, connections in pairs(soundState.Bindings) do
        disconnectConnectionList(connections)
        soundState.Bindings[sound] = nil
    end
    for sound, connections in pairs(soundState.PendingBindings) do
        disconnectConnectionList(connections)
        soundState.PendingBindings[sound] = nil
    end
end

local function restoreOriginalSounds()
    disconnectSoundBindings()
    for sound, volume in pairs(soundState.Originals) do
        if sound and sound.Parent then
            soundState.Muting[sound] = true
            pcall(function() sound.Volume = volume end)
            soundState.Muting[sound] = nil
        end
        soundState.Originals[sound] = nil
    end
end

local function isTargetGunshot(sound)
    if not sound or not sound:IsA("Sound") or sound == soundState.ReplacementSound
        or sound == soundState.PreviewSound then return false end

    local idMatch = SoundCatalogCore.matchesOriginal(sound.SoundId, "")
    if idMatch then return true end
    if not SoundCatalogCore.matchesOriginal("", sound.Name) then return false end
    return sound:FindFirstAncestorWhichIsA("Tool") ~= nil
end

local function playReplacement(sound)
    if soundState.MuteGunshot then return end
    local now = os.clock()
    if sound and now - (soundState.LastTrigger[sound] or 0) < 0.03 then return end
    if sound then soundState.LastTrigger[sound] = now end
    local replacement = soundState.ReplacementSound
    if not soundState.Enabled or not replacement or not replacement.Parent then return end
    pcall(function()
        replacement:Stop()
        replacement.TimePosition = 0
        replacement:Play()
    end)
end

local function bindGunshot(sound)
    if not (soundState.Enabled or soundState.MuteGunshot)
        or soundState.Originals[sound] ~= nil or not isTargetGunshot(sound) then
        return false
    end

    soundState.Originals[sound] = sound.Volume
    soundState.Muting[sound] = true
    pcall(function() sound.Volume = 0 end)
    soundState.Muting[sound] = nil

    local connections = {}
    table.insert(connections, sound.Played:Connect(function() playReplacement(sound) end))
    table.insert(connections, sound:GetPropertyChangedSignal("Playing"):Connect(function()
        if sound.Playing then playReplacement(sound) end
    end))
    table.insert(connections, sound:GetPropertyChangedSignal("Volume"):Connect(function()
        if (soundState.Enabled or soundState.MuteGunshot) and sound.Parent
            and not soundState.Muting[sound] and sound.Volume ~= 0 then
            soundState.Muting[sound] = true
            pcall(function() sound.Volume = 0 end)
            soundState.Muting[sound] = nil
        end
    end))
    soundState.Bindings[sound] = connections
    local pending = soundState.PendingBindings[sound]
    if pending then
        disconnectConnectionList(pending)
        soundState.PendingBindings[sound] = nil
    end
    if sound.IsPlaying or sound.Playing then playReplacement(sound) end
    return true
end

local function watchCandidateSound(sound)
    if not sound or not sound:IsA("Sound") or bindGunshot(sound)
        or soundState.PendingBindings[sound] then return end

    local connections = {}
    local function retry()
        if not runtime.Alive or not (soundState.Enabled or soundState.MuteGunshot) or not sound.Parent then return end
        bindGunshot(sound)
    end
    table.insert(connections, sound:GetPropertyChangedSignal("SoundId"):Connect(retry))
    table.insert(connections, sound:GetPropertyChangedSignal("Name"):Connect(retry))
    table.insert(connections, sound.AncestryChanged:Connect(retry))
    soundState.PendingBindings[sound] = connections

    task.delay(3, function()
        if soundState.PendingBindings[sound] == connections then
            disconnectConnectionList(connections)
            soundState.PendingBindings[sound] = nil
        end
    end)
end

local function scanGunshots()
    local changed = 0
    local seen = setmetatable({}, {__mode = "k"})
    local roots = {
        workspace,
        player.Character,
        player:FindFirstChildOfClass("Backpack"),
        workspace.CurrentCamera,
        SoundService,
    }
    for _, root in ipairs(roots) do
        if root then
            if root:IsA("Sound") and not seen[root] then
                seen[root] = true
                if bindGunshot(root) then changed = changed + 1 end
            end
            for _, object in ipairs(root:GetDescendants()) do
                if object:IsA("Sound") and not seen[object] then
                    seen[object] = true
                    if bindGunshot(object) then changed = changed + 1 end
                end
            end
        end
    end
    return changed
end

local function countBoundGunshots()
    local count = 0
    for sound in pairs(soundState.Originals) do
        if sound and sound.Parent then count = count + 1 end
    end
    return count
end

local function setSoundToggleSilently(value)
    if not soundToggle then return end
    local suppressed = runtime.SuppressNotifications
    runtime.SuppressNotifications = true
    soundState.SyncingToggle = true
    pcall(function() soundToggle:Set(value) end)
    soundState.SyncingToggle = false
    runtime.SuppressNotifications = suppressed
end

local function setMuteGunshotToggleSilently(value)
    if not muteGunshotToggle then return end
    local suppressed = runtime.SuppressNotifications
    runtime.SuppressNotifications = true
    soundState.SyncingMuteToggle = true
    pcall(function() muteGunshotToggle:Set(value) end)
    soundState.SyncingMuteToggle = false
    runtime.SuppressNotifications = suppressed
end

local function setSoundDropdownSilently(label)
    if not soundDropdown or not label then return end
    soundState.SyncingDropdown = true
    pcall(function() soundDropdown:Select(label) end)
    soundState.SyncingDropdown = false
end

local function disableSoundChanger(announce)
    soundState.LoadToken = soundState.LoadToken + 1
    soundState.DesiredEnabled = false
    soundState.Enabled = false
    soundState.PendingKey = nil
    soundState.ActiveKey = nil
    soundState.ActiveLabel = nil
    restoreOriginalSounds()
    if soundState.ReplacementSound then
        pcall(function() soundState.ReplacementSound:Destroy() end)
        soundState.ReplacementSound = nil
    end
    if announce then
        showBottomMessage("Sonido original del arma restaurado.", {
            title = "XeroHub · SonidosV2",
            key = "sounds:state",
        })
    end
end

local function disableGunshotMute(announce)
    if not soundState.MuteGunshot then
        if announce then
            showBottomMessage("El sonido de disparo ya está activo.", {
                title = "XeroHub · SonidosV2",
                key = "sounds:mute",
            })
        end
        return
    end

    soundState.MuteGunshot = false
    restoreOriginalSounds()

    if announce then
        showBottomMessage("Sonido de disparo activado.", {
            title = "XeroHub · SonidosV2",
            key = "sounds:mute",
        })
    end
end

local function enableGunshotMute(announce)
    if soundState.Enabled or soundState.DesiredEnabled then
        disableSoundChanger(false)
        setSoundToggleSilently(false)
    end

    soundState.MuteGunshot = true
    local linked = scanGunshots()

    if announce then
        showBottomMessage("Sonido de disparo desactivado · " .. tostring(linked) .. " Gunshot enlazado(s).", {
            title = "XeroHub · SonidosV2",
            key = "sounds:mute",
        })
    end
end

local function activateEntry(entry, changedSelection, silent)
    if not entry then
        soundState.DesiredEnabled = false
        if not silent then
            showBottomMessage("Selecciona un sonido del catálogo.", {title = "XeroHub · Sonidos"})
        end
        setSoundToggleSilently(false)
        return
    end

    if soundState.MuteGunshot then
        disableGunshotMute(false)
        setMuteGunshotToggleSilently(false)
    end

    soundState.LoadToken = soundState.LoadToken + 1
    local token = soundState.LoadToken
    local entryKey = SoundCatalogCore.entryKey(entry)
    soundState.PendingKey = entryKey
    local wasEnabled = soundState.Enabled
    if not silent then
        showBottomMessage("Preparando " .. entry.label .. "…", {
            title = "XeroHub · SonidosV2",
            key = "sounds:load",
        })
    end

    task.spawn(function()
        local replacement, result = createLoadedSound(entry, "XeroHub_CustomGunshot")
        local selectedEntry = getSelectedEntry()
        if not runtime.Alive or soundState.LoadToken ~= token or not soundState.DesiredEnabled
            or not selectedEntry or SoundCatalogCore.entryKey(selectedEntry) ~= entryKey then
            if replacement then pcall(function() replacement:Destroy() end) end
            return
        end

        if not replacement then
            soundState.PendingKey = nil
            if not silent then
                showBottomMessage(tostring(result), {
                    title = "XeroHub · Error de sonido",
                    key = "sounds:load",
                    priority = true,
                })
            end
            local activeEntry = soundState.ByLabel[soundState.ActiveLabel]
            if wasEnabled and activeEntry
                and SoundCatalogCore.entryKey(activeEntry) == soundState.ActiveKey then
                soundState.SelectedLabel = soundState.ActiveLabel
                soundEnv.XERO_SELECTED_SOUND = soundState.ActiveLabel
                setSoundDropdownSilently(soundState.ActiveLabel)
            else
                disableSoundChanger(false)
                setSoundToggleSilently(false)
            end
            return
        end

        local previous = soundState.ReplacementSound
        soundState.ReplacementSound = replacement
        soundState.Enabled = true
        soundState.ActiveLabel = entry.label
        soundState.ActiveKey = entryKey
        soundState.PendingKey = nil
        scanGunshots()
        local linked = countBoundGunshots()
        if previous and previous ~= replacement then
            pcall(function() previous:Destroy() end)
        end

        soundEnv.XERO_SELECTED_SOUND = entry.label
        if not silent then
            showBottomMessage(
                (changedSelection and "Sonido cambiado a " or "Sonido activado: ")
                    .. entry.label .. " · " .. tostring(linked) .. " Gunshot enlazado(s).",
                {title = "XeroHub · Sonidos", key = "sounds:state"}
            )
        end
    end)
end

local function previewEntry(entry)
    if not entry then
        showBottomMessage("Selecciona un sonido para probarlo.", {title = "XeroHub · Sonidos"})
        return
    end
    soundState.PreviewToken = soundState.PreviewToken + 1
    local token = soundState.PreviewToken
    showBottomMessage("Cargando vista previa: " .. entry.label .. "…", {
        title = "XeroHub · Sonidos",
        key = "sounds:preview",
    })

    task.spawn(function()
        local preview, result = createLoadedSound(entry, "XeroHub_SoundPreview")
        if not runtime.Alive or soundState.PreviewToken ~= token then
            if preview then pcall(function() preview:Destroy() end) end
            return
        end
        if not preview then
            showBottomMessage(tostring(result), {
                title = "XeroHub · Error de sonido",
                key = "sounds:preview",
                priority = true,
            })
            return
        end
        if soundState.PreviewSound then
            pcall(function() soundState.PreviewSound:Destroy() end)
        end
        soundState.PreviewSound = preview
        local endedConnection
        endedConnection = preview.Ended:Connect(function()
            if endedConnection then endedConnection:Disconnect() end
            if soundState.PreviewSound == preview then soundState.PreviewSound = nil end
            pcall(function() preview:Destroy() end)
        end)
        preview:Play()
        showBottomMessage("Reproduciendo: " .. entry.label, {
            title = "XeroHub · SonidosV2",
            key = "sounds:preview",
        })
    end)
end

local function getSelectedKillEntry()
    return soundState.ByLabel[killSoundState.SelectedLabel]
end

local function extractSoundDigits(soundId)
    local text = soundTrim(soundId)
    return text:match("^rbxassetid://(%d+)$")
        or text:match("^(%d+)$")
        or text:match("[?&]id=(%d+)")
end

local function getCharacterFromSound(sound)
    local node = sound and sound.Parent
    while node and node ~= workspace do
        if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
            return node
        end
        node = node.Parent
    end
    return nil
end

local function classifyKillSound(sound)
    if not sound or not sound:IsA("Sound")
        or sound == soundState.ReplacementSound
        or sound == soundState.PreviewSound
        or sound == killSoundState.ReplacementSound then
        return nil
    end

    local digits = extractSoundDigits(sound.SoundId)
    local name = string.lower(soundTrim(sound.Name))

    -- DUELS puede mover/clonar GunKill fuera del Character o Backpack justo al
    -- reproducirlo. Se detecta globalmente por nombre/ID para que ninguna copia
    -- alcance a colarse junto al Death Sound personalizado.
    if digits == KILL_GUN_SOUND_ID or name == "gunkill" then
        return "gunkill"
    end

    -- Sonido nativo de muerte de cualquier jugador, incluido el usuario local.
    local idText = string.lower(soundTrim(sound.SoundId))
    if (idText == string.lower(DEFAULT_DEATH_SOUND) or name == "died") then
        local character = getCharacterFromSound(sound)
        if character and Players:GetPlayerFromCharacter(character) then
            return "death"
        end
    end

    return nil
end

local function disconnectKillConnectionList(connections)
    for _, connection in ipairs(connections or {}) do
        pcall(function() connection:Disconnect() end)
    end
end

local function restoreDynamicDeathSound(sound)
    local original = killSoundState.DynamicOriginals[sound]
    if original == nil then return end
    killSoundState.DynamicOriginals[sound] = nil
    if sound and sound.Parent then
        killSoundState.Muting[sound] = true
        pcall(function() sound.Volume = original end)
        killSoundState.Muting[sound] = nil
    end
end

local function muteDynamicDeathSound(sound)
    if not sound or not sound.Parent then return end
    if killSoundState.DynamicOriginals[sound] == nil then
        killSoundState.DynamicOriginals[sound] = sound.Volume
    end
    killSoundState.Muting[sound] = true
    pcall(function() sound.Volume = 0 end)
    killSoundState.Muting[sound] = nil

    local token = os.clock()
    sound:SetAttribute("XeroKillMuteToken", token)
    task.spawn(function()
        local deadline = os.clock() + 3.5
        while runtime.Alive and killSoundState.Enabled and sound and sound.Parent
            and sound:GetAttribute("XeroKillMuteToken") == token
            and (sound.Playing or sound.IsPlaying) and os.clock() < deadline do
            task.wait(0.05)
        end
        if sound and sound.Parent and sound:GetAttribute("XeroKillMuteToken") == token then
            pcall(function() sound:SetAttribute("XeroKillMuteToken", nil) end)
            restoreDynamicDeathSound(sound)
        end
    end)
end

local function toolHasNativeGunKill(tool)
    if not tool or not tool.Parent or not tool:IsA("Tool") then return false end
    for _, object in ipairs(tool:GetDescendants()) do
        if object:IsA("Sound") then
            local name = string.lower(soundTrim(object.Name))
            local digits = extractSoundDigits(object.SoundId)
            if name == "gunkill" or digits == KILL_GUN_SOUND_ID
                or killSoundState.NativeOriginalIds[object] ~= nil then
                return true
            end
        end
    end
    return false
end

local function getNativeKillAssetId()
    local replacement = killSoundState.ReplacementSound
    if not replacement or not replacement.Parent then return nil end
    local customId = soundTrim(replacement.SoundId)
    return customId ~= "" and customId or nil
end

local function applyNativeGunKill(sound)
    if not killSoundState.Enabled or not sound or not sound.Parent then return false end
    local customId = getNativeKillAssetId()
    if not customId then return false end

    -- Se conserva el ID original una sola vez. El juego seguirá llamando :Play()
    -- sobre ESTE MISMO Sound; sólo cambiamos el contenido que reproduce.
    if killSoundState.NativeOriginalIds[sound] == nil then
        killSoundState.NativeOriginalIds[sound] = sound.SoundId
    end

    if sound.SoundId ~= customId then
        killSoundState.NativeUpdating[sound] = true
        pcall(function() sound.SoundId = customId end)
        killSoundState.NativeUpdating[sound] = nil
    end

    -- Preload sólo cuando cambia el asset seleccionado. No ocurre al matar.
    if killSoundState.NativeAppliedIds[sound] ~= customId then
        killSoundState.NativeAppliedIds[sound] = customId
        task.spawn(function()
            pcall(function() ContentProvider:PreloadAsync({sound}) end)
        end)
    end
    return true
end

local function restoreNativeGunKill(sound)
    local originalId = killSoundState.NativeOriginalIds[sound]
    if originalId == nil then return end
    killSoundState.NativeOriginalIds[sound] = nil
    killSoundState.NativeAppliedIds[sound] = nil
    if sound and sound.Parent then
        killSoundState.NativeUpdating[sound] = true
        pcall(function() sound.SoundId = originalId end)
        killSoundState.NativeUpdating[sound] = nil
    end
end

local function isNativeDeathSound(sound)
    if not sound or not sound:IsA("Sound") then return false end
    if killSoundState.NativeDeathOriginalIds[sound] ~= nil then return true end
    local name = string.lower(soundTrim(sound.Name))
    local idText = string.lower(soundTrim(sound.SoundId))
    return name == "died" or idText == string.lower(DEFAULT_DEATH_SOUND)
end

local function releaseSuppressedDeathSound(sound)
    local original = killSoundState.SuppressedDeathOriginalVolumes[sound]
    if original == nil then return end
    killSoundState.SuppressedDeathOriginalVolumes[sound] = nil
    if sound and sound.Parent then
        killSoundState.Muting[sound] = true
        pcall(function() sound.Volume = original end)
        killSoundState.Muting[sound] = nil
    end
end

local function suppressDefaultDeathSound(sound)
    if not killSoundState.Enabled or not sound or not sound.Parent or not isNativeDeathSound(sound) then
        return false
    end

    -- Si ya parcheamos ESTE Died con el sonido personalizado, debe quedar audible.
    if killSoundState.NativeDeathOriginalIds[sound] ~= nil then
        releaseSuppressedDeathSound(sound)
        return false
    end

    if killSoundState.SuppressedDeathOriginalVolumes[sound] == nil then
        killSoundState.SuppressedDeathOriginalVolumes[sound] = sound.Volume
    end

    killSoundState.Muting[sound] = true
    pcall(function() sound.Volume = 0 end)
    killSoundState.Muting[sound] = nil
    return true
end

local function restoreSuppressedDeathSounds()
    for sound in pairs(killSoundState.SuppressedDeathOriginalVolumes) do
        releaseSuppressedDeathSound(sound)
    end
end

local function releaseSuppressedGunKill(sound)
    local original = killSoundState.SuppressedGunKillOriginalVolumes[sound]
    if original == nil then return end
    killSoundState.SuppressedGunKillOriginalVolumes[sound] = nil
    if sound and sound.Parent then
        killSoundState.Muting[sound] = true
        pcall(function() sound.Volume = original end)
        killSoundState.Muting[sound] = nil
    end
end

local function suppressGunKillSound(sound)
    if not killSoundState.Enabled or not sound or not sound.Parent then return false end
    if killSoundState.SuppressedGunKillOriginalVolumes[sound] == nil then
        killSoundState.SuppressedGunKillOriginalVolumes[sound] = sound.Volume
    end
    killSoundState.Muting[sound] = true
    pcall(function() sound.Volume = 0 end)
    killSoundState.Muting[sound] = nil
    return true
end

local function restoreSuppressedGunKillSounds()
    for sound in pairs(killSoundState.SuppressedGunKillOriginalVolumes) do
        releaseSuppressedGunKill(sound)
    end
end

local function applyNativeDeathSound(sound)
    if not killSoundState.Enabled or not sound or not sound.Parent or not isNativeDeathSound(sound) then
        return false
    end

    local customId = getNativeKillAssetId()
    if not customId then return false end

    if killSoundState.NativeDeathOriginalIds[sound] == nil then
        killSoundState.NativeDeathOriginalIds[sound] = sound.SoundId
    end

    if sound.SoundId ~= customId then
        killSoundState.NativeDeathUpdating[sound] = true
        pcall(function() sound.SoundId = customId end)
        killSoundState.NativeDeathUpdating[sound] = nil
    end

    if killSoundState.NativeDeathAppliedIds[sound] ~= customId then
        killSoundState.NativeDeathAppliedIds[sound] = customId
        task.spawn(function()
            pcall(function() ContentProvider:PreloadAsync({sound}) end)
        end)
    end

    return true
end

local function restoreNativeDeathSound(sound)
    local originalId = killSoundState.NativeDeathOriginalIds[sound]
    if originalId == nil then return end

    killSoundState.NativeDeathOriginalIds[sound] = nil
    killSoundState.NativeDeathAppliedIds[sound] = nil

    if sound and sound.Parent then
        killSoundState.NativeDeathUpdating[sound] = true
        pcall(function() sound.SoundId = originalId end)
        killSoundState.NativeDeathUpdating[sound] = nil
        if killSoundState.Enabled then
            suppressDefaultDeathSound(sound)
        end
    end
end

local function disconnectNativeDeathTarget(character)
    local connections = killSoundState.NativeDeathTargetConnections[character]
    if connections then
        for _, connection in ipairs(connections) do
            pcall(function() connection:Disconnect() end)
        end
        killSoundState.NativeDeathTargetConnections[character] = nil
    end
end

local function restoreNativeDeathTarget(character, token)
    if token ~= nil and killSoundState.NativeDeathTargetTokens[character] ~= token then
        return
    end

    disconnectNativeDeathTarget(character)
    killSoundState.NativeDeathTargetTokens[character] = nil
    if killSoundState.RecentNativeDeathTarget == character then
        killSoundState.RecentNativeDeathTarget = nil
    end

    for sound in pairs(killSoundState.NativeDeathOriginalIds) do
        if sound and (not character or sound:IsDescendantOf(character)) then
            restoreNativeDeathSound(sound)
        end
    end
end

local function playerCharacterFromPart(part)
    local node = part
    while node and node ~= workspace do
        if node:IsA("Model") then
            local targetPlayer = Players:GetPlayerFromCharacter(node)
            if targetPlayer and targetPlayer ~= player then
                return node, targetPlayer
            end
        end
        node = node.Parent
    end
    return nil, nil
end

local function validNativeDeathTarget(character, ignoreDistance)
    if not character or character == player.Character then return false end
    local targetPlayer = Players:GetPlayerFromCharacter(character)
    if not targetPlayer or targetPlayer == player then return false end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local targetRoot = character:FindFirstChild("HumanoidRootPart")
    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not targetRoot or not myRoot then return false end

    if ignoreDistance then return true end
    return (myRoot.Position - targetRoot.Position).Magnitude <= NATIVE_DEATH_MAX_TARGET_DISTANCE
end

local function armNativeDeathTarget(character, tool, forceExactTarget)
    if not killSoundState.Enabled or not character or not character.Parent then return false end
    if toolHasNativeGunKill(tool) then return false end
    if not validNativeDeathTarget(character, forceExactTarget == true) then return false end

    local previousTarget = killSoundState.RecentNativeDeathTarget
    if previousTarget and previousTarget ~= character then
        restoreNativeDeathTarget(previousTarget)
    end

    local customId = getNativeKillAssetId()
    if not customId then return false end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    disconnectNativeDeathTarget(character)

    killSoundState.NativeDeathSerial = (killSoundState.NativeDeathSerial or 0) + 1
    local token = killSoundState.NativeDeathSerial
    killSoundState.NativeDeathTargetTokens[character] = token
    killSoundState.RecentNativeDeathTarget = character

    local connections = {}
    killSoundState.NativeDeathTargetConnections[character] = connections

    local function watchDeathSound(sound)
        if not sound or not sound:IsA("Sound") or not isNativeDeathSound(sound) then return end
        applyNativeDeathSound(sound)
        -- El default estaba silenciado globalmente. Ya que ESTE Sound tiene el
        -- custom, restauramos su volumen para que Roblox lo reproduzca nativamente.
        releaseSuppressedDeathSound(sound)

        table.insert(connections, sound:GetPropertyChangedSignal("SoundId"):Connect(function()
            if killSoundState.Enabled
                and killSoundState.NativeDeathTargetTokens[character] == token
                and sound.Parent
                and not killSoundState.NativeDeathUpdating[sound] then
                applyNativeDeathSound(sound)
            end
        end))
    end

    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("Sound") and isNativeDeathSound(object) then
            watchDeathSound(object)
        end
    end

    table.insert(connections, character.DescendantAdded:Connect(function(object)
        if killSoundState.Enabled
            and killSoundState.NativeDeathTargetTokens[character] == token
            and object:IsA("Sound") then
            watchDeathSound(object)
        end
    end))

    table.insert(connections, humanoid.Died:Connect(function()
        if killSoundState.NativeDeathTargetTokens[character] ~= token then return end
        -- NO restauramos en Humanoid.Died: el CoreScript aún tiene que hacer Died:Play().
        task.delay(NATIVE_DEATH_RESTORE_AFTER_DEATH, function()
            restoreNativeDeathTarget(character, token)
        end)
    end))

    task.delay(NATIVE_DEATH_ARM_WINDOW, function()
        if killSoundState.NativeDeathTargetTokens[character] ~= token then return end
        local hum = character and character.Parent and character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            restoreNativeDeathTarget(character, token)
        end
    end)

    return true
end

runtime.ArmNativeDeathTarget = function(character, tool)
    -- El modo global escucha Humanoid.Died; no necesita armar una víctima ni
    -- modificar GunKill, lo que evita dos reproducciones para la misma muerte.
    return false
end

local function findManualMeleeTarget(tool)
    if not killSoundState.Enabled or toolHasNativeGunKill(tool) then return nil end

    -- PC / mouse: si estás apuntando al jugador que cuchilleas, éste gana prioridad.
    local mouseTarget = mouse and mouse.Target
    if mouseTarget then
        local character = playerCharacterFromPart(mouseTarget)
        if character and validNativeDeathTarget(character) then
            return character
        end
    end

    -- Móvil / fallback: jugador vivo más cercano al Handle/HRP, sólo a rango de melee.
    local myCharacter = player.Character
    local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local referencePart = tool and (tool:FindFirstChild("Handle", true) or tool:FindFirstChildWhichIsA("BasePart", true))
    local referencePosition = referencePart and referencePart.Position or myRoot.Position
    local bestCharacter, bestDistance = nil, NATIVE_DEATH_NEAREST_DISTANCE

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            local character = targetPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and root then
                local distance = (referencePosition - root.Position).Magnitude
                if distance <= bestDistance and validNativeDeathTarget(character) then
                    bestDistance = distance
                    bestCharacter = character
                end
            end
        end
    end

    return bestCharacter
end

local function playKillReplacement(humanoid)
    if not killSoundState.Enabled or not humanoid or not humanoid.Parent then return false end
    if killSoundState.TriggeredHumanoids[humanoid] then return false end

    local replacement = killSoundState.ReplacementSound
    if not replacement or not replacement.Parent then return false end
    killSoundState.TriggeredHumanoids[humanoid] = true

    -- Cada muerte obtiene su propia instancia. Dos jugadores que mueran casi al
    -- mismo tiempo no se cortan entre sí y cada Humanoid sólo puede dispararla una vez.
    local oneShot = replacement:Clone()
    oneShot.Name = "XeroHub_GlobalDeathSound"
    oneShot.Looped = false
    oneShot.TimePosition = 0
    oneShot.Parent = SoundService
    killSoundState.ActiveOneShots[oneShot] = true

    local cleaned = false
    local function cleanup()
        if cleaned then return end
        cleaned = true
        killSoundState.ActiveOneShots[oneShot] = nil
        if oneShot then pcall(function() oneShot:Destroy() end) end
    end

    local endedConnection
    endedConnection = oneShot.Ended:Connect(function()
        if endedConnection then endedConnection:Disconnect() end
        cleanup()
    end)

    local ok = pcall(function() oneShot:Play() end)
    if not ok then
        if endedConnection then endedConnection:Disconnect() end
        cleanup()
        return false
    end

    task.delay(math.max(8, (oneShot.TimeLength or 0) + 2), function()
        if endedConnection then pcall(function() endedConnection:Disconnect() end) end
        cleanup()
    end)
    return true
end

local function bindKillSound(sound)
    if not killSoundState.Enabled or not sound or not sound:IsA("Sound") then return false end

    local kind = classifyKillSound(sound)
    if not kind then return false end

    if killSoundState.Bindings[sound] then
        if kind == "gunkill" then suppressGunKillSound(sound) end
        return true
    end

    local connections = {}

    if kind == "death" then
        -- Se hace al enlazar el Sound, mucho antes de Humanoid.Died/Played. Así el
        -- uuhhh original no puede colarse aunque haya ping o el target llegue tarde.
        suppressDefaultDeathSound(sound)
        table.insert(connections, sound:GetPropertyChangedSignal("Volume"):Connect(function()
            if killSoundState.Enabled and sound.Parent
                and killSoundState.NativeDeathOriginalIds[sound] == nil
                and not killSoundState.Muting[sound] then
                suppressDefaultDeathSound(sound)
            end
        end))
    else
        -- GunKill ya no dispara el personalizado: se silencia porque la muerte
        -- global del Humanoid producirá exactamente una reproducción.
        local function enforceGunKillMute()
            if killSoundState.Enabled and sound.Parent then
                suppressGunKillSound(sound)
            end
        end
        enforceGunKillMute()
        table.insert(connections, sound:GetPropertyChangedSignal("Volume"):Connect(function()
            if killSoundState.Enabled and sound.Parent and not killSoundState.Muting[sound] then
                enforceGunKillMute()
            end
        end))
        -- Algunos clones llaman :Play() antes de terminar de copiar Volume. Estas
        -- dos señales vuelven a imponer el mute en el mismo ciclo de reproducción.
        table.insert(connections, sound.Played:Connect(enforceGunKillMute))
        table.insert(connections, sound:GetPropertyChangedSignal("Playing"):Connect(function()
            if sound.Playing then enforceGunKillMute() end
        end))
    end

    table.insert(connections, sound.AncestryChanged:Connect(function()
        if not sound.Parent then
            disconnectKillConnectionList(connections)
            killSoundState.Bindings[sound] = nil
            killSoundState.NativeOriginalIds[sound] = nil
            killSoundState.NativeAppliedIds[sound] = nil
            killSoundState.DynamicOriginals[sound] = nil
        end
    end))

    killSoundState.Bindings[sound] = connections
    local pending = killSoundState.PendingBindings[sound]
    if pending then
        disconnectKillConnectionList(pending)
        killSoundState.PendingBindings[sound] = nil
    end

    return true
end

local function watchCandidateKillSound(sound)
    if not sound or not sound:IsA("Sound") or bindKillSound(sound)
        or killSoundState.PendingBindings[sound] then return end

    local connections = {}
    local function retry()
        if not runtime.Alive or not killSoundState.Enabled or not sound.Parent then return end
        bindKillSound(sound)
    end
    table.insert(connections, sound:GetPropertyChangedSignal("SoundId"):Connect(retry))
    table.insert(connections, sound:GetPropertyChangedSignal("Name"):Connect(retry))
    table.insert(connections, sound.AncestryChanged:Connect(retry))
    killSoundState.PendingBindings[sound] = connections

    task.delay(3, function()
        if killSoundState.PendingBindings[sound] == connections then
            disconnectKillConnectionList(connections)
            killSoundState.PendingBindings[sound] = nil
        end
    end)
end

local function scanKillSounds()
    local changed = 0
    local seen = setmetatable({}, {__mode = "k"})
    local roots = {
        workspace,
        player.Character,
        player:FindFirstChildOfClass("Backpack"),
        workspace.CurrentCamera,
        SoundService,
    }
    for _, root in ipairs(roots) do
        if root then
            if root:IsA("Sound") and not seen[root] then
                seen[root] = true
                if bindKillSound(root) then changed = changed + 1 end
            end
            for _, object in ipairs(root:GetDescendants()) do
                if object:IsA("Sound") and not seen[object] then
                    seen[object] = true
                    if bindKillSound(object) then changed = changed + 1 end
                end
            end
        end
    end
    return changed
end

local function bindAttackTool(tool)
    if not tool or not tool:IsA("Tool") or killSoundState.AttackTools[tool] then return end
    killSoundState.AttackTools[tool] = true

    local function markTouched(part)
        if not part or not part:IsA("BasePart") then return end
        local touchConnection = part.Touched:Connect(function(hit)
            if not killSoundState.Enabled or toolHasNativeGunKill(tool) then return end
            if os.clock() - (killSoundState.RecentLocalAttack or 0) > NATIVE_DEATH_TOUCH_WINDOW then return end
            local character = playerCharacterFromPart(hit)
            if character and validNativeDeathTarget(character) then
                armNativeDeathTarget(character, tool)
            end
        end)
        table.insert(killSoundState.AttackMonitorConnections, touchConnection)
    end

    for _, object in ipairs(tool:GetDescendants()) do
        if object:IsA("BasePart") then markTouched(object) end
    end

    local descendantConnection = tool.DescendantAdded:Connect(function(object)
        if killSoundState.Enabled and object:IsA("BasePart") then
            markTouched(object)
        end
    end)
    table.insert(killSoundState.AttackMonitorConnections, descendantConnection)

    local activationConnection = tool.Activated:Connect(function()
        if not killSoundState.Enabled then return end

        killSoundState.RecentLocalAttack = os.clock()
        killSoundState.RecentAttackTool = tool

        if not toolHasNativeGunKill(tool) then
            -- Se ejecuta en el mismo tick de Activated; mouse/nearest arma a la víctima
            -- antes de que llegue el cambio de Health/Died desde el servidor.
            local targetCharacter = findManualMeleeTarget(tool)
            if targetCharacter then
                armNativeDeathTarget(targetCharacter, tool)
            end
        end
    end)
    table.insert(killSoundState.AttackMonitorConnections, activationConnection)
end

local function bindAttackRoot(root)
    if not root then return end
    for _, object in ipairs(root:GetDescendants()) do
        if object:IsA("Tool") then bindAttackTool(object) end
    end
    local connection = root.DescendantAdded:Connect(function(object)
        if killSoundState.Enabled and object:IsA("Tool") then bindAttackTool(object) end
    end)
    table.insert(killSoundState.AttackMonitorConnections, connection)
end

local function stopLocalAttackMonitoring()
    for i = #killSoundState.AttackMonitorConnections, 1, -1 do
        pcall(function() killSoundState.AttackMonitorConnections[i]:Disconnect() end)
        killSoundState.AttackMonitorConnections[i] = nil
    end
    killSoundState.AttackTools = setmetatable({}, {__mode = "k"})
    killSoundState.RecentAttackTool = nil
    killSoundState.TriggeredHumanoids = setmetatable({}, {__mode = "k"})

    for character in pairs(killSoundState.NativeDeathTargetTokens) do
        restoreNativeDeathTarget(character)
    end
end

local function startLocalAttackMonitoring()
    stopLocalAttackMonitoring()

    local boundPlayers = setmetatable({}, {__mode = "k"})
    local boundHumanoids = setmetatable({}, {__mode = "k"})

    local function bindCharacter(character)
        if not killSoundState.Enabled or not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
            or character:WaitForChild("Humanoid", 5)
        if not humanoid or boundHumanoids[humanoid] then return end
        boundHumanoids[humanoid] = true

        local function triggerDeath()
            playKillReplacement(humanoid)
        end
        table.insert(killSoundState.AttackMonitorConnections, humanoid.Died:Connect(triggerDeath))
        table.insert(killSoundState.AttackMonitorConnections, humanoid.HealthChanged:Connect(function(health)
            if health <= 0 then triggerDeath() end
        end))
    end

    local function bindPlayer(targetPlayer)
        if boundPlayers[targetPlayer] then return end
        boundPlayers[targetPlayer] = true
        if targetPlayer.Character then task.defer(bindCharacter, targetPlayer.Character) end
        table.insert(killSoundState.AttackMonitorConnections, targetPlayer.CharacterAdded:Connect(function(character)
            task.defer(bindCharacter, character)
        end))
    end

    for _, targetPlayer in ipairs(Players:GetPlayers()) do bindPlayer(targetPlayer) end
    table.insert(killSoundState.AttackMonitorConnections, Players.PlayerAdded:Connect(bindPlayer))
end

local function disconnectKillBindings()
    for sound, connections in pairs(killSoundState.Bindings) do
        disconnectKillConnectionList(connections)
        killSoundState.Bindings[sound] = nil
    end
    for sound, connections in pairs(killSoundState.PendingBindings) do
        disconnectKillConnectionList(connections)
        killSoundState.PendingBindings[sound] = nil
    end
end

local function restoreKillOriginalSounds()
    disconnectKillBindings()
    for sound in pairs(killSoundState.NativeOriginalIds) do
        restoreNativeGunKill(sound)
    end
    for character in pairs(killSoundState.NativeDeathTargetTokens) do
        restoreNativeDeathTarget(character)
    end
    for sound in pairs(killSoundState.NativeDeathOriginalIds) do
        restoreNativeDeathSound(sound)
    end
    for sound in pairs(killSoundState.DynamicOriginals) do
        restoreDynamicDeathSound(sound)
    end
    restoreSuppressedDeathSounds()
    restoreSuppressedGunKillSounds()
    for oneShot in pairs(killSoundState.ActiveOneShots) do
        killSoundState.ActiveOneShots[oneShot] = nil
        if oneShot then pcall(function() oneShot:Destroy() end) end
    end
end

local function setKillToggleSilently(value)
    if not killSoundToggle then return end
    local suppressed = runtime.SuppressNotifications
    runtime.SuppressNotifications = true
    killSoundState.SyncingToggle = true
    pcall(function() killSoundToggle:Set(value) end)
    killSoundState.SyncingToggle = false
    runtime.SuppressNotifications = suppressed
end

local function setKillDropdownSilently(label)
    if not killSoundDropdown or not label then return end
    killSoundState.SyncingDropdown = true
    pcall(function() killSoundDropdown:Select(label) end)
    killSoundState.SyncingDropdown = false
end

local function disableKillSoundChanger(announce)
    killSoundState.LoadToken = killSoundState.LoadToken + 1
    killSoundState.DesiredEnabled = false
    killSoundState.Enabled = false
    killSoundState.PendingKey = nil
    killSoundState.ActiveKey = nil
    killSoundState.ActiveLabel = nil
    killSoundState.RecentLocalAttack = 0
    killSoundState.RecentAttackTool = nil
    killSoundState.LastConfirmedKillTrigger = 0
    killSoundState.LastKillReplacementAt = 0
    stopLocalAttackMonitoring()
    restoreKillOriginalSounds()
    if killSoundState.ReplacementSound then
        pcall(function() killSoundState.ReplacementSound:Destroy() end)
        killSoundState.ReplacementSound = nil
    end
    if announce then
        showBottomMessage("Sonido de muerte original restaurado.", {
            title = "XeroHub · SonidosV2",
            key = "sounds:kill:state",
        })
    end
end

local function activateKillEntry(entry, changedSelection, silent)
    if not entry then
        killSoundState.DesiredEnabled = false
        if not silent then
            showBottomMessage("Selecciona un sonido de muerte del catálogo.", {title = "XeroHub · Sonidos"})
        end
        setKillToggleSilently(false)
        return
    end

    killSoundState.LoadToken = killSoundState.LoadToken + 1
    local token = killSoundState.LoadToken
    local entryKey = SoundCatalogCore.entryKey(entry)
    killSoundState.PendingKey = entryKey
    local wasEnabled = killSoundState.Enabled
    if not silent then
        showBottomMessage("Preparando sonido de muerte: " .. entry.label .. "…", {
            title = "XeroHub · SonidosV2",
            key = "sounds:kill:load",
        })
    end

    task.spawn(function()
        local replacement, result = createLoadedSound(entry, "XeroHub_CustomKillSound")
        local selectedEntry = getSelectedKillEntry()
        if not runtime.Alive or killSoundState.LoadToken ~= token or not killSoundState.DesiredEnabled
            or not selectedEntry or SoundCatalogCore.entryKey(selectedEntry) ~= entryKey then
            if replacement then pcall(function() replacement:Destroy() end) end
            return
        end

        if not replacement then
            killSoundState.PendingKey = nil
            if not silent then
                showBottomMessage(tostring(result), {
                    title = "XeroHub · Error de sonido",
                    key = "sounds:kill:load",
                    priority = true,
                })
            end
            local activeEntry = soundState.ByLabel[killSoundState.ActiveLabel]
            if wasEnabled and activeEntry
                and SoundCatalogCore.entryKey(activeEntry) == killSoundState.ActiveKey then
                killSoundState.SelectedLabel = killSoundState.ActiveLabel
                soundEnv.XERO_SELECTED_KILL_SOUND = killSoundState.ActiveLabel
                setKillDropdownSilently(killSoundState.ActiveLabel)
            else
                disableKillSoundChanger(false)
                setKillToggleSilently(false)
            end
            return
        end

        local previous = killSoundState.ReplacementSound
        killSoundState.ReplacementSound = replacement
        killSoundState.Enabled = true
        killSoundState.ActiveLabel = entry.label
        killSoundState.ActiveKey = entryKey
        killSoundState.PendingKey = nil

        startLocalAttackMonitoring()
        scanKillSounds()
        if previous and previous ~= replacement then
            pcall(function() previous:Destroy() end)
        end

        soundEnv.XERO_SELECTED_KILL_SOUND = entry.label
        if not silent then
            showBottomMessage(
                (changedSelection and "Sonido de muerte cambiado a " or "Sonido de muerte activado: ")
                    .. entry.label .. " · modo global listo.",
                {title = "XeroHub · SonidosV2", key = "sounds:kill:state"}
            )
        end
    end)
end

-- Config de sonidos: guarda selección + estado y puede restaurarse aunque el catálogo
-- todavía no haya terminado de cargar. También conserva el nombre real del archivo
-- para no depender únicamente del label visible del dropdown.
local function findSoundConfigEntry(section)
    if type(section) ~= "table" then return nil end

    local fileName = type(section.Archivo) == "string" and section.Archivo or nil
    if fileName and fileName ~= "" then
        for _, entry in ipairs(soundState.Catalog) do
            if entry.name == fileName then return entry end
        end
    end

    local label = type(section.Seleccionado) == "string" and section.Seleccionado or nil
    if label and label ~= "" then return soundState.ByLabel[label] end
    return nil
end

function runtime.SerializeSoundConfig()
    local weaponEntry = getSelectedEntry()
    local killEntry = getSelectedKillEntry()

    return {
        Arma = {
            Seleccionado = soundState.SelectedLabel or soundState.ActiveLabel or soundEnv.XERO_SELECTED_SOUND,
            Archivo = weaponEntry and weaponEntry.name or nil,
            Activado = soundState.DesiredEnabled == true,
            Silenciado = soundState.MuteGunshot == true,
        },
        Muerte = {
            Seleccionado = killSoundState.SelectedLabel or killSoundState.ActiveLabel or soundEnv.XERO_SELECTED_KILL_SOUND,
            Archivo = killEntry and killEntry.name or nil,
            Activado = killSoundState.DesiredEnabled == true,
        },
    }
end

local function applySavedSoundConfig(data)
    if type(data) ~= "table" then return false end

    local weaponConfig = type(data.Arma) == "table" and data.Arma or {}
    local killConfig = type(data.Muerte) == "table" and data.Muerte or {}

    -- Primero apagamos el estado anterior para que una config nunca se mezcle con otra.
    disableSoundChanger(false)
    disableGunshotMute(false)
    disableKillSoundChanger(false)
    setSoundToggleSilently(false)
    setMuteGunshotToggleSilently(false)
    setKillToggleSilently(false)

    local weaponEntry = findSoundConfigEntry(weaponConfig)
    if weaponEntry then
        soundState.SelectedLabel = weaponEntry.label
        soundEnv.XERO_SELECTED_SOUND = weaponEntry.label
        setSoundDropdownSilently(weaponEntry.label)
    end

    local killEntry = findSoundConfigEntry(killConfig)
    if killEntry then
        killSoundState.SelectedLabel = killEntry.label
        soundEnv.XERO_SELECTED_KILL_SOUND = killEntry.label
        setKillDropdownSilently(killEntry.label)
    end

    -- Mute y custom son mutuamente excluyentes igual que en la UI normal.
    if weaponConfig.Silenciado == true then
        enableGunshotMute(false)
        setMuteGunshotToggleSilently(true)
    elseif weaponConfig.Activado == true and weaponEntry then
        soundState.DesiredEnabled = true
        setSoundToggleSilently(true)
        activateEntry(weaponEntry, false, true)
    end

    if killConfig.Activado == true and killEntry then
        killSoundState.DesiredEnabled = true
        setKillToggleSilently(true)
        activateKillEntry(killEntry, false, true)
    end

    return true
end

function runtime.LoadSoundConfig(data)
    if type(data) ~= "table" then return false end

    -- Si el catálogo aún está descargándose, se aplica desde applyCatalog().
    runtime.PendingSoundConfig = data
    if next(soundState.ByLabel) ~= nil then
        local pending = runtime.PendingSoundConfig
        runtime.PendingSoundConfig = nil
        return applySavedSoundConfig(pending)
    end
    return true
end

local function applyCatalog(catalog, source)
    soundState.Catalog = catalog
    soundState.ByLabel = {}
    local values = {}
    for _, entry in ipairs(catalog) do
        soundState.ByLabel[entry.label] = entry
        table.insert(values, entry.label)
    end
    if #values == 0 then values = {"Sin sonidos disponibles"} end

    local selected = soundState.SelectedLabel or soundEnv.XERO_SELECTED_SOUND
    if not soundState.ByLabel[selected] then selected = values[1] end
    soundState.SelectedLabel = soundState.ByLabel[selected] and selected or nil
    local selectedEntry = soundState.ByLabel[soundState.SelectedLabel]

    if soundDropdown then
        pcall(function()
            soundDropdown:Refresh(values)
            if soundState.SelectedLabel then setSoundDropdownSilently(soundState.SelectedLabel) end
        end)
    end

    local killSelected = killSoundState.SelectedLabel or soundEnv.XERO_SELECTED_KILL_SOUND
    if not soundState.ByLabel[killSelected] then killSelected = values[1] end
    killSoundState.SelectedLabel = soundState.ByLabel[killSelected] and killSelected or nil
    local selectedKillEntry = soundState.ByLabel[killSoundState.SelectedLabel]
    if killSoundDropdown then
        pcall(function()
            killSoundDropdown:Refresh(values)
            if killSoundState.SelectedLabel then setKillDropdownSilently(killSoundState.SelectedLabel) end
        end)
    end

    if runtime.JumpSoundDropdown then
        pcall(function()
            runtime.JumpSoundDropdown:Refresh(values)
            local jumpLabel = runtime.JumpSoundSelectedLabel
            if jumpLabel and soundState.ByLabel[jumpLabel] then
                runtime.JumpSoundDropdown:Select(jumpLabel)
            end
        end)
    end

    local pendingSoundConfig = runtime.PendingSoundConfig
    if pendingSoundConfig then
        runtime.PendingSoundConfig = nil
        applySavedSoundConfig(pendingSoundConfig)
        return #catalog, source
    end

    local selectedKey = selectedEntry and SoundCatalogCore.entryKey(selectedEntry) or nil
    if soundState.DesiredEnabled and selectedEntry and selectedKey ~= soundState.ActiveKey
        and selectedKey ~= soundState.PendingKey then
        activateEntry(selectedEntry, true)
    end

    local selectedKillKey = selectedKillEntry and SoundCatalogCore.entryKey(selectedKillEntry) or nil
    if killSoundState.DesiredEnabled and selectedKillEntry and selectedKillKey ~= killSoundState.ActiveKey
        and selectedKillKey ~= killSoundState.PendingKey then
        activateKillEntry(selectedKillEntry, true)
    end
    return #catalog, source
end

local function refreshSoundCatalog(announce)
    soundState.CatalogToken = soundState.CatalogToken + 1
    local token = soundState.CatalogToken
    if announce then
        showBottomMessage("Actualizando catálogo del repo…", {
            title = "XeroHub · SonidosV2",
            key = "sounds:catalog",
        })
    end
    task.spawn(function()
        local catalog, source = fetchSoundCatalog()
        if not runtime.Alive or soundState.CatalogToken ~= token then return end
        local count = applyCatalog(catalog, source)
        if announce then
            showBottomMessage(
                tostring(count) .. " sonido(s) cargado(s) desde " .. tostring(source) .. ".",
                {title = "XeroHub · Sonidos", key = "sounds:catalog"}
            )
        end
    end)
end

Tabs.Sonidos:Paragraph({
    Title = "Sonidos",
    Desc = "Personaliza los sonidos de disparo y de muerte.",
})
Tabs.Sonidos:Section({Title = "Sonido de disparo"})

soundDropdown = Tabs.Sonidos:Dropdown({
    Title = "Sonido del arma",
    Desc = "Elige el sonido que quieres al disparar.",
    Values = {"Cargando catálogo…"},
    Value = "Cargando catálogo…",
    Callback = function(value)
        if soundState.SyncingDropdown then return end
        local label = type(value) == "table" and value[1] or value
        if not soundState.ByLabel[label] then return end
        local changed = soundState.SelectedLabel ~= label
        soundState.SelectedLabel = label
        local entry = soundState.ByLabel[label]
        if soundState.DesiredEnabled then
            if changed or SoundCatalogCore.entryKey(entry) ~= soundState.ActiveKey then
                activateEntry(entry, true)
            end
        else
            soundEnv.XERO_SELECTED_SOUND = label
        end
    end,
})

local jumpCatalogDropdown
jumpCatalogDropdown = Tabs.Sonidos:Dropdown({
    Title = "Sonido al saltar",
    Desc = "Selecciona un sonido del catálogo de /sounds.",
    Values = {"Cargando catálogo…"},
    Value = "Cargando catálogo…",
    Callback = function(value)
        local label = type(value) == "table" and value[1] or value
        if not soundState.ByLabel[label] then return end

        runtime.JumpSoundSelectedLabel = label
        -- Elegir un sonido de salto lo activa automáticamente.
        -- La selección vive en Sounds; Configuración solo la guarda/carga.
        getgenv().XeroJumpSoundEnabled = true
        markAutoConfigChanged()
        local entry = soundState.ByLabel[label]

        task.spawn(function()
            local assetId, err = runtime.LoadSoundCatalogEntry(entry)
            if assetId then
                runtime.JumpSoundAssetId = assetId
                showBottomMessage("Sonido de salto listo: " .. tostring(label), {
                    title = "XeroHub · Salto",
                    key = "jump:sound:ready",
                })
            else
                runtime.JumpSoundAssetId = nil
                showBottomMessage(tostring(err or "No se pudo cargar el sonido."), {
                    title = "XeroHub · Salto",
                    key = "jump:sound:error",
                })
            end
        end)
    end,
})
runtime.JumpSoundDropdown = jumpCatalogDropdown

Tabs.Sonidos:Button({
    Title = "Actualizar lista de sonidos",
    Desc = "Carga los sonidos nuevos.",
    Callback = function() refreshSoundCatalog(true) end,
})

Tabs.Sonidos:Button({
    Title = "Probar sonido",
    Desc = "Escucha el sonido seleccionado.",
    Callback = function() previewEntry(getSelectedEntry()) end,
})

soundToggle = Tabs.Sonidos:Toggle({
    Title = "Cambiar sonido",
    Desc = "Usa el sonido elegido al disparar.",
    Value = false,
    Callback = function(enabled)
        if soundState.SyncingToggle then return end
        if enabled then
            soundState.DesiredEnabled = true
            activateEntry(getSelectedEntry(), false)
        else disableSoundChanger(true) end
    end,
})
UIElements.TogWeaponSound = soundToggle

muteGunshotToggle = Tabs.Sonidos:Toggle({
    Title = "Desactivar sonido de disparo",
    Desc = "Dispara sin ningún sonido.",
    Value = false,
    Callback = function(enabled)
        if soundState.SyncingMuteToggle then return end
        if enabled then
            enableGunshotMute(true)
        else
            disableGunshotMute(true)
        end
    end,
})
UIElements.TogMuteGunshot = muteGunshotToggle

Tabs.Sonidos:Section({Title = "Sonido de muerte"})
Tabs.Sonidos:Paragraph({
    Title = "Death sound global",
    Desc = "Suena cuando muere cualquier jugador, incluso tú.",
})

killSoundDropdown = Tabs.Sonidos:Dropdown({
    Title = "Sonido de muerte",
    Desc = "Elige el sonido para cualquier muerte.",
    Values = {"Cargando catálogo…"},
    Value = "Cargando catálogo…",
    Callback = function(value)
        if killSoundState.SyncingDropdown then return end
        local label = type(value) == "table" and value[1] or value
        if not soundState.ByLabel[label] then return end
        local changed = killSoundState.SelectedLabel ~= label
        killSoundState.SelectedLabel = label
        local entry = soundState.ByLabel[label]
        if killSoundState.DesiredEnabled then
            if changed or SoundCatalogCore.entryKey(entry) ~= killSoundState.ActiveKey then
                activateKillEntry(entry, true)
            end
        else
            soundEnv.XERO_SELECTED_KILL_SOUND = label
        end
    end,
})

Tabs.Sonidos:Button({
    Title = "Probar sonido de muerte",
    Desc = "Escucha el sonido seleccionado.",
    Callback = function() previewEntry(getSelectedKillEntry()) end,
})

killSoundToggle = Tabs.Sonidos:Toggle({
    Title = "Cambiar sonido de muerte",
    Desc = "Reproduce el sonido cuando muere cualquier jugador.",
    Value = false,
    Callback = function(enabled)
        if killSoundState.SyncingToggle then return end
        if enabled then
            killSoundState.DesiredEnabled = true
            activateKillEntry(getSelectedKillEntry(), false)
        else
            disableKillSoundChanger(true)
        end
    end,
})
UIElements.TogKillSound = killSoundToggle

-- Puente para que otras secciones (como Sonido al Saltar) usen
-- exactamente el mismo catálogo y cargador de /sounds.
runtime.LoadSoundCatalogEntry = function(entry)
    if type(entry) ~= "table" then
        return nil, "Sonido no válido."
    end
    return downloadSound(entry)
end

runtime.GetSoundCatalogEntry = function(label)
    return soundState.ByLabel[label]
end

local function onRelevantSoundAdded(object)
    if not object:IsA("Sound") then return end
    if soundState.Enabled or soundState.MuteGunshot then watchCandidateSound(object) end
    if killSoundState.Enabled then watchCandidateKillSound(object) end
end

-- Evita escuchar TODO game (CoreGui, Lighting, UI, etc.). Workspace ya cubre
-- Character y CurrentCamera; SoundService y Backpack completan los otros roots.
runtime.Track(workspace.DescendantAdded:Connect(onRelevantSoundAdded))
runtime.Track(SoundService.DescendantAdded:Connect(onRelevantSoundAdded))
local soundBackpack = player:FindFirstChildOfClass("Backpack")
if soundBackpack then
    runtime.Track(soundBackpack.DescendantAdded:Connect(onRelevantSoundAdded))
end

runtime.SoundCleanup = function()
    soundState.LoadToken = soundState.LoadToken + 1
    soundState.PreviewToken = soundState.PreviewToken + 1
    killSoundState.LoadToken = killSoundState.LoadToken + 1
    disableSoundChanger(false)
    disableGunshotMute(false)
    disableKillSoundChanger(false)
    if soundState.PreviewSound then
        pcall(function() soundState.PreviewSound:Destroy() end)
        soundState.PreviewSound = nil
    end
end

refreshSoundCatalog(false)
end

Tabs.Inicio:Paragraph({
    Title = "Bienvenido a XeroHub",
    Desc = "Elige una categoría y encuentra cada ajuste con el buscador.",
})

local nombreEjecutor = identifyexecutor and identifyexecutor() or "Desconocido"
local accountPlan = "Free"
pcall(function()
    if player.MembershipType == Enum.MembershipType.Premium then
        accountPlan = "Premium"
    end
end)

Tabs.Inicio:Paragraph({
    Title = tostring(player.DisplayName),
    Desc = "@" .. tostring(player.Name)
        .. "\nEjecutor: " .. tostring(nombreEjecutor)
        .. "\nCuenta: " .. tostring(player.AccountAge or 0) .. " días"
        .. "\nPlan: " .. tostring(accountPlan),
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=150&h=150",
    ImageSize = 58,
    CircleImage = true,
    ImageAlign = "left",
    ImageStrokeColor = Color3.fromRGB(244, 244, 244),
    ImageStrokeThickness = 1,
    Gothic = true,
    DecorText = "PROFILE",
    Color = Color3.fromRGB(11, 11, 14),
    StrokeColor = Color3.fromRGB(44, 44, 50),
})
-- ==========================================
-- CAMBIOS RECIENTES · INICIO
-- ==========================================
Tabs.Inicio:Section({Title = "Novedades de XeroHub"})

Tabs.Inicio:Paragraph({
    Title = "Apariencia",
    Desc = "Pestaña Apariencia agregada con Korblox, Headless y algunos limiteds.",
    Image = "solar:palette-bold",
    ImageSize = 34,
    Color = Color3.fromHex("#20252C")
})

Tabs.Inicio:Paragraph({
    Title = "Clonador de avatar",
    Desc = "Clona avatares por username o seleccionando jugadores del servidor.",
    Image = "solar:user-id-bold",
    ImageSize = 34,
    Color = Color3.fromHex("#20252C")
})


Tabs.Inicio:Section({Title = "Información del Servidor"})

-- Se carga de forma directa (como en MM2)
local gameNameStr = "Desconocido"
pcall(function() 
    gameNameStr = MarketplaceService:GetProductInfo(game.PlaceId).Name 
end)

Tabs.Inicio:Paragraph({ 
    Title = "Juego Actual", 
    Desc = gameNameStr .. "\nPlace ID: " .. game.PlaceId,
    Image = "rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=150&h=150", --  Extrae la foto oficial del juego
    ImageSize = 48 
})



local XERO_CREDITS_PROFILE = "rbxassetid://74846094133538" -- Foto del creador para Créditos.

Tabs.Inicio:Section({ Title = "Juegos Soportados" })

local TPS = game:GetService("TeleportService")

function TPSeguro_Duels(placeId, nombreJuego)
    if game.PlaceId == placeId then
        showBottomMessage("Ya estás en " .. nombreJuego .. ", buscando otro servidor...")
        pcall(function() TPS:Teleport(placeId, player) end)
    else
        showBottomMessage("Intentando ir a " .. nombreJuego .. "...")
        -- Copiamos el link por si Roblox bloquea el TP por seguridad
        pcall(function() setclipboard("https://www.roblox.com/games/" .. tostring(placeId)) end)
        task.wait(0.5)
        showBottomMessage("Link copiado. Si no te hace TP, pégalo en tu navegador para entrar.")
        -- Intentamos el TP de todos modos
        pcall(function() TPS:Teleport(placeId, player) end)
    end
end

Tabs.Inicio:Button({
    Title = "Murder Mystery 2",
    Callback = function() TPSeguro_Duels(142823291, "MM2") end
})

Tabs.Inicio:Button({
    Title = "Murderers VS Sheriffs (Duels)",
    Callback = function() TPSeguro_Duels(135856908115931, "Duels") end
})

Tabs.Inicio:Button({
    Title = "Duelos de Asesinato",
    Callback = function() TPSeguro_Duels(120851538706364, "DSA") end
})


Tabs.Inicio:Button({
    Title = "Murder Mystery V (MMV)",
    Callback = function() TPSeguro_Duels(74369636333825, "MMV") end
})


Tabs.Inicio:Section({Title = "Optimización"})

do
local Stats = game:GetService("Stats")
local statsContainer = Instance.new("Frame")
statsContainer.Name = "XeroPerformance"
statsContainer.Size = UDim2.fromOffset(184, 44)
statsContainer.AnchorPoint = Vector2.new(1, 0)
statsContainer.Position = UDim2.new(1, -12, 0, 12)
statsContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
statsContainer.BackgroundTransparency = 0.06
statsContainer.BorderSizePixel = 0
statsContainer.Visible = false
statsContainer.ZIndex = 100
statsContainer.Parent = screenGui
Instance.new("UICorner", statsContainer).CornerRadius = UDim.new(0, 12)
local outline = Instance.new("UIStroke", statsContainer)
outline.Color = Color3.fromRGB(60, 60, 60)
outline.Thickness = 1
local divider = Instance.new("Frame", statsContainer)
divider.Position = UDim2.new(0.5, 0, 0, 12)
divider.Size = UDim2.fromOffset(1, 20)
divider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
divider.BorderSizePixel = 0
divider.ZIndex = 101
local function metric(caption, x)
    local label = Instance.new("TextLabel", statsContainer)
    label.Size = UDim2.fromOffset(72, 12)
    label.Position = UDim2.fromOffset(x, 6)
    label.BackgroundTransparency = 1
    label.Text = caption
    label.TextColor3 = Color3.fromRGB(140, 140, 140)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 8
    label.ZIndex = 101
    local value = Instance.new("TextLabel", statsContainer)
    value.Size = UDim2.fromOffset(72, 20)
    value.Position = UDim2.fromOffset(x, 18)
    value.BackgroundTransparency = 1
    value.Text = "--"
    value.TextColor3 = Color3.fromRGB(240, 240, 240)
    value.Font = Enum.Font.GothamMedium
    value.TextSize = 14
    value.ZIndex = 101
    return value
end
local fpsLabel = metric("FPS", 10)
local pingLabel = metric("PING / ms", 102)
local showStatsEnabled = false
local fpsFrames, statsElapsed = 0, 0
Tabs.Inicio:Toggle({
    Title = "Mostrar FPS y Ping",
    Callback = function(Value)
        showStatsEnabled = Value
        statsContainer.Visible = Value
        fpsFrames, statsElapsed = 0, 0
        fpsLabel.Text, pingLabel.Text = "--", "--"
    end,
})
runtime.Track(RunService.RenderStepped:Connect(function(deltaTime)
    if not showStatsEnabled then return end
    fpsFrames = fpsFrames + 1
    statsElapsed = statsElapsed + deltaTime
    if statsElapsed >= 1 then
        fpsLabel.Text = tostring(math.floor(fpsFrames / statsElapsed + 0.5))
        local ok, pingValue = pcall(function()
            return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        pingLabel.Text = ok and tostring(pingValue) or "--"
        fpsFrames, statsElapsed = 0, 0
    end
end))
end

local fpsBoostEnabled = false
local FPS_SCAN_BUDGET = 0.0035
local FPS_SCAN_CHECK_EVERY = 64

runtime.FPSBoost = {
    Cache = setmetatable({}, {__mode = "k"}),
    LightingState = nil,
    TerrainState = nil,
    CacheFolder = nil,
    Connection = nil,
}

function runtime.ApplyLowGraphics(v)
    if not fpsBoostEnabled or not v or not v.Parent then return end

    local supported = v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture")
        or v:IsA("SpecialMesh") or v:IsA("Light") or v:IsA("PostEffect")
        or v:IsA("SurfaceAppearance") or v:IsA("BaseWrap") or v:IsA("Clothing")
        or v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
        or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles")
    if not supported then return end

    -- No tocamos avatares: evita ropa/meshes rotos y reduce muchísimo el trabajo.
    local model = v:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then return end

    local cache = runtime.FPSBoost.Cache
    if cache[v] then return end
    local data = {}
    cache[v] = data

    if v:IsA("BasePart") and not v:IsA("Terrain") then
        data.Material = v.Material
        data.Reflectance = v.Reflectance
        data.CastShadow = v.CastShadow
        v.Material = Enum.Material.SmoothPlastic
        v.Reflectance = 0
        v.CastShadow = false
        if v:IsA("MeshPart") then
            data.TextureID = v.TextureID
            v.TextureID = ""
        end
    elseif v:IsA("SpecialMesh") then
        data.TextureId = v.TextureId
        v.TextureId = ""
    elseif v:IsA("SurfaceAppearance") or v:IsA("BaseWrap") or v:IsA("Clothing") then
        data.Parent = v.Parent
        v.Parent = runtime.FPSBoost.CacheFolder
    elseif v:IsA("Decal") or v:IsA("Texture") then
        data.Transparency = v.Transparency
        v.Transparency = 1
    elseif v:IsA("Light") or v:IsA("PostEffect") or v:IsA("ParticleEmitter")
        or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Smoke")
        or v:IsA("Fire") or v:IsA("Sparkles") then
        data.Enabled = v.Enabled
        v.Enabled = false
    end
end

function runtime.RestoreLowGraphics()
    for v, data in pairs(runtime.FPSBoost.Cache) do
        if v then
            pcall(function()
                if data.Parent and data.Parent.Parent then v.Parent = data.Parent end
                if data.Material then v.Material = data.Material end
                if data.Reflectance ~= nil then v.Reflectance = data.Reflectance end
                if data.CastShadow ~= nil then v.CastShadow = data.CastShadow end
                if data.TextureID ~= nil then v.TextureID = data.TextureID end
                if data.TextureId ~= nil then v.TextureId = data.TextureId end
                if data.Transparency ~= nil then v.Transparency = data.Transparency end
                if data.Enabled ~= nil then v.Enabled = data.Enabled end
            end)
        end
        runtime.FPSBoost.Cache[v] = nil
    end
end

Tabs.Inicio:Button({
    Title = "Cambiar de Servidor",
    Callback = function()
        showBottomMessage("Buscando servidor vacío...")
        local TPS = game:GetService("TeleportService")
        local Api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        
        task.spawn(function()
            local success, err = pcall(function()
                local req = request or http_request or (syn and syn.request)
                if req then
                    local res = req({Url = Api, Method = "GET"})
                    if res.StatusCode == 200 then
                        local data = HttpService:JSONDecode(res.Body)
                        local servers = {}
                        if data and data.data then for _, v in pairs(data.data) do if v.playing < v.maxPlayers and v.id ~= game.JobId then table.insert(servers, v.id) end end end
                        if #servers > 0 then
                            local randomServer = servers[math.random(1, #servers)]
                            showBottomMessage("¡Servidor encontrado!...")
                            TPS:TeleportToPlaceInstance(game.PlaceId, randomServer, player)
                        else showBottomMessage("No hay servidores vacíos disponibles.") end
                    else showBottomMessage("Error de conexión con el Proxy.") end
                else showBottomMessage("Tu ejecutor no soporta HTTP Requests.") end
            end)
            if not success then warn("Error en Server Hop:", err) end
        end)
    end,
})

-- ==========================================
-- PESTAÑA AIMBOT
-- ==========================================

-- 🔥 FIX OFUSCADOR: Mover la lista de jugadores AQUÍ ARRIBA antes del macro
local listaJugadores = Players:GetPlayers()
runtime.Track(Players.PlayerAdded:Connect(function(p) table.insert(listaJugadores, p) end))
runtime.Track(Players.PlayerRemoving:Connect(function(p)
    for i, v in ipairs(listaJugadores) do
        if v == p then table.remove(listaJugadores, i) break end
    end
end))

-- Macro de cuchillo independiente de la pistola
local triggerBotConnection = nil

Tabs.Aim:Section({Title = "Macro (Pistola)"})
UIElements.TogMacro = Tabs.Aim:Toggle({
    Title = "Activar Macro", 
    Desc = "Dispara con un solo toque.",
    Callback = function(s) macroActivo = s == true; markAutoConfigChanged() end
})

UIElements.SliMacroEquip = Tabs.Aim:Slider({
    Title = "Delay al Equipar",
    Desc = "Sube esto si la pistola no alcanza a salir. (Segundos)",
    Step = 0.01,
    Value = {Min = 0.01, Max = 0.50, Default = 0.04},
    Callback = function(v) macroEquipDelay = tonumber(v) or macroEquipDelay; markAutoConfigChanged() end
})

UIElements.SliMacroShoot = Tabs.Aim:Slider({
    Title = "Delay de Disparo",
    Desc = "Sube esto si el tiro no cuenta daño. (Segundos)",
    Step = 0.01,
    Value = {Min = 0.05, Max = 0.80, Default = 0.10},
    Callback = function(v) macroShootDelay = tonumber(v) or macroShootDelay; markAutoConfigChanged() end
})

Tabs.Aim:Section({Title = "Macro (Cuchillo)"})
local knifeL2ActionName = "XeroHub_KnifeMacro_L2_Block"
local knifeL2BlockBound = false

local function setKnifeL2Block(enabled)
    if enabled and not knifeL2BlockBound then
        local ok = pcall(function()
            ContextActionService:BindActionAtPriority(
                knifeL2ActionName,
                function()
                    -- Consume L2 para que el juego no lo use para
                    -- alternar Shift Lock mientras la macro está activa.
                    return Enum.ContextActionResult.Sink
                end,
                false,
                3000,
                Enum.KeyCode.ButtonL2
            )
        end)
        knifeL2BlockBound = ok
    elseif not enabled and knifeL2BlockBound then
        pcall(function()
            ContextActionService:UnbindAction(knifeL2ActionName)
        end)
        knifeL2BlockBound = false
    end
end



-- Trigger Bot
-- Dispara automáticamente en cuanto un jugador enemigo cruza
-- exactamente el centro de la mira. Se evalúa en RenderStepped
-- para minimizar la latencia y no depende del clic del usuario.
local triggerBotConnection = nil
local triggerLastTarget = nil
local triggerLastFire = 0
local triggerFireInterval = 0.03

local function getTriggerTarget()
    local camera = workspace.CurrentCamera
    local character = LocalPlayer.Character
    if not camera or not character then return nil end

    -- El Trigger solo funciona con una Tool clasificada como pistola.
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool or not esLaPistola(tool) then return nil end

    local viewport = camera.ViewportSize
    local ray = camera:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    params.IgnoreWater = true

    local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    if not hit or not hit.Instance then return nil end

    local model = hit.Instance:FindFirstAncestorOfClass("Model")
    if not model or model == character then return nil end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end

    local targetPlayer = Players:GetPlayerFromCharacter(model)
    if not targetPlayer or targetPlayer == LocalPlayer then return nil end

    -- Usa la misma comprobación de enemigo del resto del script.
    if isEnemy and not isEnemy(targetPlayer) then return nil end

    return model
end

local function triggerBotFire(target)
    if not target then return end

    local character = LocalPlayer.Character
    if not character then return end

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool or not esLaPistola(tool) then return end

    -- Activate() se ejecuta inmediatamente al detectar el objetivo.
    pcall(function()
        tool:Activate()
    end)
end

local function setTriggerBot(enabled)
    triggerBotEnabled = enabled == true
    triggerLastTarget = nil
    triggerLastFire = 0

    if triggerBotConnection then
        triggerBotConnection:Disconnect()
        triggerBotConnection = nil
    end

    if triggerBotEnabled then
        triggerBotConnection = RunService.RenderStepped:Connect(function()
            if not triggerBotEnabled then return end

            local target = getTriggerTarget()
            if not target then
                triggerLastTarget = nil
                return
            end

            local now = os.clock()

            -- Disparo inmediato al adquirir el objetivo.
            -- Si el mismo objetivo permanece en la mira, se permite
            -- otro disparo solo después del intervalo mínimo.
            if target ~= triggerLastTarget or now - triggerLastFire >= triggerFireInterval then
                triggerLastTarget = target
                triggerLastFire = now
                triggerBotFire(target)
            end
        end)
    end
end

UIElements.TogTriggerBot = Tabs.Aim:Toggle({
    Title = "Activar Trigger Bot",
    Desc = "Dispara solo con el centro exacto de la mira sobre un enemigo.",
    Callback = function(v)
        setTriggerBot(v)
        markAutoConfigChanged()
    end
})

UIElements.TogKnifeMacro = Tabs.Aim:Toggle({
    Title = "Activar Macro Cuchillo (L2)",
    Desc = "Un toque de L2 equipa y lanza el cuchillo.",
    Callback = function(v)
        knifeMacroEnabled = v == true
        setKnifeL2Block(knifeMacroEnabled)
        markAutoConfigChanged()
    end
})

UIElements.SliKnifeEquip = Tabs.Aim:Slider({
    Title = "Delay Equipar Cuchillo",
    Desc = "Tiempo antes de lanzar. (Segundos)",
    Step = 0.01,
    Value = {Min = 0.01, Max = 0.50, Default = 0.10},
    Callback = function(v) knifeEquipDelay = tonumber(v) or knifeEquipDelay; markAutoConfigChanged() end
})

UIElements.SliKnifeThrow = Tabs.Aim:Slider({
    Title = "Delay Lanzamiento Cuchillo",
    Desc = "Tiempo después del lanzamiento. (Segundos)",
    Step = 0.01,
    Value = {Min = 0.01, Max = 0.50, Default = 0.10},
    Callback = function(v) knifeThrowDelay = tonumber(v) or knifeThrowDelay; markAutoConfigChanged() end
})

-- L2 se usa como un solo toque. La macro no exige mantener el botón.
local knifeMacroBusy = false

-- Busca el cuchillo por su estructura real, no por el nombre "Knife".
local function obtenerCuchilloMacro()
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")

    for _, container in ipairs({character, backpack}) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") and (
                    item:FindFirstChild("Throw", true)
                    or item:FindFirstChild("KnifeClient", true)
                    or item:FindFirstChild("KnifeServer", true)
                ) then
                    return item
                end
            end
        end
    end

    return nil
end

runtime.Track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- El propio juego procesa L2 para Throw, por eso NO bloqueamos
    -- el macro cuando gameProcessed es true.
    if knifeMacroBusy or not knifeMacroEnabled then return end
    if input.KeyCode ~= Enum.KeyCode.ButtonL2 then return end

    knifeMacroBusy = true

    local ok, err = pcall(function()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local knife = obtenerCuchilloMacro()

        if not (knife and humanoid) then
            return
        end

        -- Equipar y esperar a que Roblox confirme que el Tool ya está en el personaje.
        humanoid:EquipTool(knife)
        local equipDeadline = os.clock() + math.max(knifeEquipDelay, 0.05)
        repeat
            task.wait()
        until knife.Parent == character or os.clock() >= equipDeadline

        -- Un pequeño margen después de que el Tool entra al personaje ayuda a que
        -- KnifeClient/LocalScripts terminen de inicializarse antes del lanzamiento.
        task.wait(math.max(0, knifeEquipDelay))

        -- Usamos la activación normal de la Tool. Esto deja que el propio
        -- KnifeClient ejecute la secuencia correcta de lanzamiento y sus argumentos,
        -- en vez de llamar a Throw:FireServer() sin los datos que el juego pueda exigir.
        pcall(function()
            knife:Activate()
        end)

        task.wait(knifeThrowDelay)
        pcall(function()
            if humanoid and humanoid.Parent then
                humanoid:UnequipTools()
            end
        end)
    end)

    knifeMacroBusy = false
end))

local deadZoneFrame = Instance.new("Frame")
deadZoneFrame.Size = UDim2.new(0, 150, 0, 150)
deadZoneFrame.Position = UDim2.new(0.8, -75, 0.8, -75) 
deadZoneFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50) 
deadZoneFrame.BackgroundTransparency = 0.5
deadZoneFrame.Visible = false
deadZoneFrame.ZIndex = 100
deadZoneFrame.Parent = screenGui 
Instance.new("UICorner", deadZoneFrame).CornerRadius = UDim.new(0, IOS_STYLE.WindowRadius)

local dzStroke = Instance.new("UIStroke", deadZoneFrame)
dzStroke.Color = Color3.fromRGB(255, 255, 255)
dzStroke.Thickness = 2
dzStroke.LineJoinMode = Enum.LineJoinMode.Round

local dzLabel = Instance.new("TextLabel", deadZoneFrame)
dzLabel.Size = UDim2.new(1, 0, 1, 0)
dzLabel.BackgroundTransparency = 1
dzLabel.Text = "ZONA MUERTA\n(Arrastrar)"
dzLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
dzLabel.Font = Enum.Font.GothamBold
dzLabel.TextSize = 14
dzLabel.TextWrapped = true

makeDraggable(deadZoneFrame, deadZoneFrame)

UIElements.TogDeadZone = Tabs.Aim:Toggle({
    Title = "Mostrar/Acomodar Zona Muerta", 
    Callback = function(s) deadZoneFrame.Visible = s end
})

UIElements.SliDeadZone = Tabs.Aim:Slider({
    Title = "Tamaño de Zona Muerta", 
    Step = 10,
    Value = {Min = 80, Max = 400, Default = 150}, 
    Callback = function(v) deadZoneFrame.Size = UDim2.new(0, v, 0, v) end
})

local forbiddenKeywords = {"knife", "cuchillo", "blade", "sword", "dagger", "kunai", "toy", "juguete", "balloon", "food", "drink", "pizza", "burger", "teddy", "combat", "punch", "fist", "wallet", "phone", "boombox", "radio"}
local weaponClassificationCache = setmetatable({}, {__mode = "k"})

function esLaPistola(item)
    if not item:IsA("Tool") then return false end
    local cached = weaponClassificationCache[item]
    if cached ~= nil then return cached end

    if item:FindFirstChild("Throw") or item:FindFirstChild("KnifeClient") or item:FindFirstChild("KnifeServer") then
        weaponClassificationCache[item] = false
        return false
    end
    
    local n = string.lower(item.Name)
    for i = 1, #forbiddenKeywords do
        if string.find(n, forbiddenKeywords[i]) then
            weaponClassificationCache[item] = false
            return false
        end
    end
    
    weaponClassificationCache[item] = true
    return true
end

function obtenerPistola()
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")
    if char then for _, item in ipairs(char:GetChildren()) do if esLaPistola(item) then return item end end end
    if backpack then for _, item in ipairs(backpack:GetChildren()) do if esLaPistola(item) then return item end end end
    return nil 
end

-- ==========================================
-- CACHÉ INTELIGENTE DE LOBBY (0 LAG)
-- ==========================================
local isTeamLobby = false
local hasForceField = false

-- 1. Actualiza el caché SOLO cuando cambias de equipo
local function updateTeamCache()
    if player.Team then
        local tName = string.lower(player.Team.Name)
        if string.find(tName, "lobby") or string.find(tName, "spectat") or string.find(tName, "espectador") or string.find(tName, "menu") or string.find(tName, "dead") then
            isTeamLobby = true
        else
            isTeamLobby = false
        end
    else
        isTeamLobby = false
    end
end

runtime.Track(player:GetPropertyChangedSignal("Team"):Connect(updateTeamCache))
updateTeamCache() -- Escaneo inicial

-- 2. Actualiza el caché SOLO cuando te ponen o quitan un campo de fuerza.
-- Reutilizamos sólo dos listeners del Character actual; los de la ronda anterior
-- se desconectan en el acto para no dejar cierres/referencias vivas entre respawns.
runtime.BindForceFieldCache = function(char)
    if runtime.ForceFieldAddedConnection then
        pcall(function() runtime.ForceFieldAddedConnection:Disconnect() end)
        runtime.ForceFieldAddedConnection = nil
    end
    if runtime.ForceFieldRemovedConnection then
        pcall(function() runtime.ForceFieldRemovedConnection:Disconnect() end)
        runtime.ForceFieldRemovedConnection = nil
    end

    hasForceField = char and char:FindFirstChildOfClass("ForceField") ~= nil or false
    if not char then
        runtime.PruneConnections()
        return
    end

    runtime.ForceFieldAddedConnection = runtime.Track(char.ChildAdded:Connect(function(child)
        if child:IsA("ForceField") then hasForceField = true end
    end))
    runtime.ForceFieldRemovedConnection = runtime.Track(char.ChildRemoved:Connect(function(child)
        if child:IsA("ForceField") then hasForceField = false end
    end))
    runtime.PruneConnections()
end

runtime.Track(player.CharacterAdded:Connect(function(char)
    runtime.BindForceFieldCache(char)
end))
runtime.BindForceFieldCache(player.Character)

-- 3. La función maestra ahora es 1000x más rápida
function estaEnLobby()
    local char = player.Character 
    if not char then return true end
    
    -- Leemos las variables del caché en un milisegundo
    if hasForceField or isTeamLobby then return true end
    
    -- Solo hace las matemáticas de distancia si los cachés fallaron
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local myPos = hrp.Position
        for i = 1, #ZONAS_SEGURAS do
            local zona = ZONAS_SEGURAS[i]
            local delta = myPos - zona.Centro
            if delta:Dot(delta) <= zona.RadioSq then
                return true
            end
        end
    end
    
    return false
end

function ejecutarAccionMacro()
    
    if estaEnLobby() then return end

    local hayEnemigos = false
    for i = 1, #listaJugadores do
    local p = listaJugadores[i]
        if p ~= player then
            local pChar = p.Character
            if pChar and pChar:FindFirstChild("Humanoid") and pChar.Humanoid.Health > 0 then
                if player.Team == nil or p.Team == nil or player.Team ~= p.Team then
                    hayEnemigos = true
                    break 
                end
            end
        end
    end

    if not hayEnemigos then return end

    local char = player.Character if not char then return end
    local hum = char:FindFirstChild("Humanoid") if not hum then return end
    local herramientaEnMano = char:FindFirstChildOfClass("Tool")
    if herramientaEnMano and not esLaPistola(herramientaEnMano) then return end

    local pistola = obtenerPistola()
    if not pistola then return end

    task.spawn(function()
        hum:UnequipTools() 
        task.wait() 
        hum:EquipTool(pistola) 
        
        -- Usa la variable del slider para el tiempo de equipar
        task.wait(macroEquipDelay) 
        
        if pistola.Parent == char then 
            pistola:Activate() 
            
            -- Usa la variable del slider para el registro del disparo
            task.wait(macroShootDelay) 
            
            pistola:Deactivate()
            hum:UnequipTools() 
        end
    end)
end


local toquesPantalla = {} 

runtime.Track(UserInputService.InputChanged:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.Touch and toquesPantalla[input] then
        if (toquesPantalla[input].posicion - input.Position).Magnitude > 10 then
            toquesPantalla = {} 
        end
    end
end))

runtime.Track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not macroActivo then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonR2) then
        ejecutarAccionMacro()
    elseif input.UserInputType == Enum.UserInputType.Touch then
        local pos = input.Position
        local dzPos = deadZoneFrame.AbsolutePosition
        local dzSize = deadZoneFrame.AbsoluteSize
        local tocoZonaMuerta = (pos.X >= dzPos.X) and (pos.X <= dzPos.X + dzSize.X) and (pos.Y >= dzPos.Y) and (pos.Y <= dzPos.Y + dzSize.Y)
        
        if not tocoZonaMuerta then 
            toquesPantalla[input] = {posicion = input.Position, tiempo = tick()} 
        end
    end
end))

runtime.Track(UserInputService.InputEnded:Connect(function(input, processed)
    if not macroActivo then return end
    
    if input.UserInputType == Enum.UserInputType.Touch and toquesPantalla[input] then
        local datosToque = toquesPantalla[input] 
        local posicionFinal = input.Position
        local distanciaMovida = (datosToque.posicion - posicionFinal).Magnitude 
        local tiempoPresionado = tick() - datosToque.tiempo
        
        toquesPantalla[input] = nil
        
        if distanciaMovida < 10 and tiempoPresionado < 0.35 and tiempoPresionado > 0.03 then 
            ejecutarAccionMacro() 
        end
    end
end))

-- ==========================================
-- 🚀 OPTIMIZACIÓN EXTREMA: CACHÉ DE ENEMIGOS POR EVENTOS
-- ==========================================



local enemyCache = {}

function updateMyTeam() enemyCache = {} end -- Si el LocalPlayer cambia, reseteamos todo
function updateEnemy(p) enemyCache[p] = nil end -- Borramos solo al enemigo que cambió

runtime.Track(player:GetPropertyChangedSignal("Team"):Connect(updateMyTeam))
runtime.Track(player:GetPropertyChangedSignal("TeamColor"):Connect(updateMyTeam))
runtime.Track(player:GetAttributeChangedSignal("Team"):Connect(updateMyTeam))
runtime.Track(player:GetAttributeChangedSignal("team"):Connect(updateMyTeam))

runtime.EnemyEventConnections = setmetatable({}, {__mode = "k"})

runtime.ClearEnemyPlayerEvents = function(p)
    local bundle = runtime.EnemyEventConnections[p]
    if not bundle then return end
    runtime.EnemyEventConnections[p] = nil
    for i = 1, #bundle do
        pcall(function() bundle[i]:Disconnect() end)
    end
end

function setupPlayerEvents(p)
    runtime.ClearEnemyPlayerEvents(p)
    local bundle = {
        p:GetPropertyChangedSignal("Team"):Connect(function() updateEnemy(p) end),
        p:GetPropertyChangedSignal("TeamColor"):Connect(function() updateEnemy(p) end),
        p:GetAttributeChangedSignal("Team"):Connect(function() updateEnemy(p) end),
        p:GetAttributeChangedSignal("team"):Connect(function() updateEnemy(p) end),
    }
    runtime.EnemyEventConnections[p] = bundle
    for i = 1, #bundle do runtime.Track(bundle[i]) end
end

for _, p in ipairs(listaJugadores) do
    if p ~= player then setupPlayerEvents(p) end
end
runtime.Track(Players.PlayerAdded:Connect(function(p) setupPlayerEvents(p) end))
runtime.Track(Players.PlayerRemoving:Connect(function(p)
    runtime.ClearEnemyPlayerEvents(p)
    updateEnemy(p)
    runtime.PruneConnections()
end))

function isEnemy(targetPlayer)
    if not teamCheckEnabled then return true end
    if targetPlayer == player then return false end
    
    if enemyCache[targetPlayer] ~= nil then return enemyCache[targetPlayer] end

    local isDiff = true
    if player.Team ~= nil and targetPlayer.Team ~= nil then
        isDiff = (player.Team ~= targetPlayer.Team)
    else
        local pAttr = player:GetAttribute("Team") or player:GetAttribute("team") 
        local tAttr = targetPlayer:GetAttribute("Team") or targetPlayer:GetAttribute("team")
        if pAttr ~= nil and tAttr ~= nil then
            isDiff = (pAttr ~= tAttr)
        elseif player.TeamColor.Name ~= "White" and player.TeamColor.Name ~= "Medium stone grey" then
            isDiff = (player.TeamColor ~= targetPlayer.TeamColor)
        end
    end
    
    enemyCache[targetPlayer] = isDiff
    return isDiff
end


-- ==========================================
-- AUTO SHOOT Y SILENT AIM (OPTIMIZADOS AL MÁXIMO)
-- ==========================================
Tabs.Aim:Section({Title = "Auto Shoot"})

local autoShootTargetPart = "Cabeza"
local autoShootCuchilloEnabled = false
local tapToShootEnabled = false
local silentAimPistolaEnabled = false 
local silentAimCuchilloEnabled = false 
local silentAimTargetPart = "Cabeza"
local silentAimFovEnabled = false
-- ==========================================
-- SELECTOR CORPORAL VISUAL + APARIENCIA
-- Todo vive en runtime para no aumentar la presión de locales del chunk principal.
-- ==========================================
runtime.TargetBodyOrder = {
    "Cabeza", "Torso superior", "Torso inferior",
    "Brazo izquierdo", "Brazo derecho", "Pierna izquierda", "Pierna derecha"
}
runtime.TargetBodyGroups = {
    ["Cabeza"] = {"Head"},
    ["Torso superior"] = {"UpperTorso", "Torso"},
    ["Torso inferior"] = {"LowerTorso", "Torso", "HumanoidRootPart"},
    ["Brazo izquierdo"] = {"LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftArm"},
    ["Brazo derecho"] = {"RightUpperArm", "RightLowerArm", "RightHand", "RightArm"},
    ["Pierna izquierda"] = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftLeg"},
    ["Pierna derecha"] = {"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightLeg"},
}
runtime.TargetSelections = {
    AutoShoot = { ["Cabeza"] = true },
    SilentAim = { ["Cabeza"] = true },
}
runtime.TargetPartNameCache = {
    AutoShoot = {"Head"},
    SilentAim = {"Head"},
}
-- OPT: cacheamos las referencias de partes por Character. Silent Aim corre muy
-- seguido, así que evitar FindFirstChild repetido aquí quita bastante trabajo en móvil.
runtime.TargetSelectionVersion = {AutoShoot = 1, SilentAim = 1}
runtime.TargetPartCache = {
    AutoShoot = setmetatable({}, {__mode = "k"}),
    SilentAim = setmetatable({}, {__mode = "k"}),
}

function runtime.RebuildTargetPartNameCache(mode)
    local selected = runtime.TargetSelections[mode] or {}
    local result = runtime.TargetPartNameCache[mode] or {}
    table.clear(result)
    local seenNames = {}
    for _, groupName in ipairs(runtime.TargetBodyOrder) do
        if selected[groupName] then
            local names = runtime.TargetBodyGroups[groupName]
            for i = 1, #names do
                local name = names[i]
                if not seenNames[name] then
                    seenNames[name] = true
                    result[#result + 1] = name
                end
            end
        end
    end
    if #result == 0 then result[1] = "Head" end
    runtime.TargetPartNameCache[mode] = result
    return result
end

function runtime.GetTargetSelectionArray(mode)
    local result = {}
    local selected = runtime.TargetSelections[mode] or {}
    for _, name in ipairs(runtime.TargetBodyOrder) do
        if selected[name] then table_insert(result, name) end
    end
    return result
end

function runtime.SetTargetSelection(mode, value)
    local selected = runtime.TargetSelections[mode]
    if not selected then return end
    table.clear(selected)

    local function enableGroup(name)
        if runtime.TargetBodyGroups[name] then selected[name] = true end
    end

    if type(value) == "table" then
        for _, name in ipairs(value) do enableGroup(name) end
    elseif value == "Cabeza" then
        enableGroup("Cabeza")
    elseif value == "Torso" then
        enableGroup("Torso superior")
        enableGroup("Torso inferior")
    elseif value == "Cuerpo Completo" then
        for _, name in ipairs(runtime.TargetBodyOrder) do enableGroup(name) end
    elseif type(value) == "string" then
        enableGroup(value)
    end

    if not next(selected) then selected["Cabeza"] = true end
    runtime.RebuildTargetPartNameCache(mode)
    runtime.TargetSelectionVersion[mode] = (runtime.TargetSelectionVersion[mode] or 0) + 1
    local cache = runtime.TargetPartCache[mode]
    if cache then table.clear(cache) end
    local names = runtime.GetTargetSelectionArray(mode)
    if mode == "AutoShoot" then
        autoShootTargetPart = table.concat(names, ", ")
    else
        silentAimTargetPart = table.concat(names, ", ")
    end

    if runtime.BodySelector and runtime.BodySelector.Refresh then
        runtime.BodySelector.Refresh()
    end
end

function runtime.CollectTargetParts(char, mode, out, seen)
    table.clear(out)
    if not char then return out end

    local modeCache = runtime.TargetPartCache[mode]
    local version = runtime.TargetSelectionVersion[mode] or 1
    local cached = modeCache and modeCache[char]
    if cached and cached.Version == version then
        local valid = true
        for i = 1, #cached.Parts do
            local part = cached.Parts[i]
            if not part or part.Parent ~= char then valid = false break end
            out[i] = part
        end
        if valid and #out > 0 then return out end
        table.clear(out)
        modeCache[char] = nil
    end

    local partNames = runtime.TargetPartNameCache[mode] or runtime.RebuildTargetPartNameCache(mode)
    table.clear(seen)
    for i = 1, #partNames do
        local part = ffc(char, partNames[i])
        if part and part:IsA("BasePart") and not seen[part] then
            seen[part] = true
            out[#out + 1] = part
        end
    end
    if #out == 0 then
        local fallback = ffc(char, "Head") or ffc(char, "HumanoidRootPart")
        if fallback then out[1] = fallback end
    end

    if modeCache and #out > 0 then
        local parts = table.create and table.create(#out) or {}
        for i = 1, #out do parts[i] = out[i] end
        modeCache[char] = {Version = version, Parts = parts}
    end
    return out
end

function runtime.EnsureBodySelector()
    if runtime.BodySelectorGui and runtime.BodySelectorGui.Parent then return end

    local parent = playerGui
    pcall(function()
        parent = gethui and gethui() or game:GetService("CoreGui")
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "iLunX_BodySelector"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        gui.ScreenInsets = Enum.ScreenInsets.None
        gui.ClipToDeviceSafeArea = false
        gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
        gui.OnTopOfCoreBlur = true
    end)
    gui.Parent = parent
    runtime.BodySelectorGui = gui

    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromHex("#000000")
    overlay.BackgroundTransparency = 0.36
    overlay.Visible = false
    overlay.Active = true
    overlay.ZIndex = 400
    overlay.Parent = gui

    local card = Instance.new("CanvasGroup")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(440, 360)
    card.BackgroundColor3 = Color3.fromHex("#111214")
    card.BorderSizePixel = 0
    card.ZIndex = 401
    card.Parent = overlay
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 22)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromHex("#5E636A")
    stroke.Transparency = 0.35
    stroke.Thickness = 1
    stroke.Parent = card

    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -88, 0, 24)
    title.Position = UDim2.fromOffset(18, 14)
    title.BackgroundTransparency = 1
    title.Text = "Selector corporal"
    title.TextColor3 = Color3.fromHex("#F7F8F9")
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 402
    title.Parent = card

    local closeSelector = Instance.new("TextButton")
    closeSelector.Name = "Close"
    closeSelector.Size = UDim2.fromOffset(28, 28)
    closeSelector.Position = UDim2.new(1, -42, 0, 12)
    closeSelector.BackgroundColor3 = Color3.fromHex("#25272B")
    closeSelector.BorderSizePixel = 0
    closeSelector.Text = "×"
    closeSelector.TextColor3 = Color3.fromHex("#E7E7E7")
    closeSelector.Font = Enum.Font.GothamBold
    closeSelector.TextSize = 16
    closeSelector.AutoButtonColor = false
    closeSelector.ZIndex = 405
    closeSelector.Parent = card
    Instance.new("UICorner", closeSelector).CornerRadius = UDim.new(0, 9)
    closeSelector.Activated:Connect(function()
        overlay.Visible = false
    end)

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -36, 0, 28)
    subtitle.Position = UDim2.fromOffset(18, 39)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Toca varias zonas del cuerpo. Las partes activas se iluminan al instante."
    subtitle.TextColor3 = Color3.fromHex("#9DA3AB")
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 10
    subtitle.TextWrapped = true
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextYAlignment = Enum.TextYAlignment.Top
    subtitle.ZIndex = 402
    subtitle.Parent = card

    local figure = Instance.new("Frame")
    figure.Size = UDim2.fromOffset(160, 220)
    figure.Position = UDim2.fromOffset(18, 74)
    figure.BackgroundColor3 = Color3.fromHex("#090A0C")
    figure.BackgroundTransparency = 0.08
    figure.BorderSizePixel = 0
    figure.ZIndex = 402
    figure.Parent = card
    Instance.new("UICorner", figure).CornerRadius = UDim.new(0, 14)

    runtime.BodySelector = {
        Mode = "AutoShoot",
        Segments = {},
        Rows = {},
        Overlay = overlay,
        Card = card,
        Scale = scale,
        Title = title,
        Subtitle = subtitle,
        CloseButton = closeSelector,
        Figure = figure,
        List = nil,
    }

    local function toggle(name)
        local selected = runtime.TargetSelections[runtime.BodySelector.Mode]
        selected[name] = not selected[name] or nil
        runtime.BodySelector.Refresh()
    end

    local function segment(name, x, y, w, h, radius)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.fromOffset(w, h)
        button.Position = UDim2.fromOffset(x, y)
        button.BackgroundColor3 = Color3.fromHex("#24262A")
        button.BorderSizePixel = 0
        button.Text = ""
        button.AutoButtonColor = false
        button.ZIndex = 404
        button.Parent = figure
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, radius or 10)
        local segStroke = Instance.new("UIStroke")
        segStroke.Color = Color3.fromHex("#4B5057")
        segStroke.Transparency = 0.35
        segStroke.Thickness = 1
        segStroke.Parent = button
        runtime.BodySelector.Segments[name] = {Button = button, Stroke = segStroke}
        button.Activated:Connect(function() toggle(name) end)
    end

    segment("Cabeza", 59, 8, 42, 42, 21)
    segment("Torso superior", 46, 55, 68, 45, 11)
    segment("Torso inferior", 50, 104, 60, 32, 9)
    segment("Brazo izquierdo", 20, 58, 20, 78, 10)
    segment("Brazo derecho", 120, 58, 20, 78, 10)
    segment("Pierna izquierda", 49, 143, 25, 66, 11)
    segment("Pierna derecha", 86, 143, 25, 66, 11)

    local list = Instance.new("ScrollingFrame")
    list.Name = "BodyPartList"
    list.Size = UDim2.fromOffset(232, 220)
    list.Position = UDim2.fromOffset(190, 74)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 2
    list.ScrollBarImageColor3 = Color3.fromHex("#6E737A")
    list.CanvasSize = UDim2.fromOffset(0, 210)
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.ElasticBehavior = Enum.ElasticBehavior.Never
    list.ZIndex = 402
    list.Parent = card
    runtime.BodySelector.List = list

    for index, name in ipairs(runtime.TargetBodyOrder) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 27)
        row.Position = UDim2.fromOffset(0, (index - 1) * 30)
        row.BackgroundColor3 = Color3.fromHex("#1C1E21")
        row.BorderSizePixel = 0
        row.TextColor3 = Color3.fromHex("#E7E7E7")
        row.Font = Enum.Font.GothamMedium
        row.TextSize = 10
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.AutoButtonColor = false
        row.ZIndex = 403
        row.Parent = list
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 12)
        pad.Parent = row
        runtime.BodySelector.Rows[name] = row
        row.Activated:Connect(function() toggle(name) end)
    end

    local function action(text, x, width, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(width, 32)
        b.Position = UDim2.new(0, x, 1, -42)
        b.BackgroundColor3 = Color3.fromHex("#25272B")
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromHex("#F2F3F5")
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.AutoButtonColor = false
        b.ZIndex = 403
        b.Parent = card
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 11)
        b.Activated:Connect(callback)
        return b
    end

    local selectAllButton = action("Todo", 18, 74, function()
        local selected = runtime.TargetSelections[runtime.BodySelector.Mode]
        for _, name in ipairs(runtime.TargetBodyOrder) do selected[name] = true end
        runtime.BodySelector.Refresh()
    end)
    local clearButton = action("Limpiar", 98, 78, function()
        table.clear(runtime.TargetSelections[runtime.BodySelector.Mode])
        runtime.BodySelector.Refresh()
    end)
    local done = action("Aplicar", 330, 92, function()
        local mode = runtime.BodySelector.Mode
        local selected = runtime.TargetSelections[mode]
        if not next(selected) then selected["Cabeza"] = true end
        runtime.SetTargetSelection(mode, runtime.GetTargetSelectionArray(mode))
        overlay.Visible = false
        showBottomMessage((mode == "AutoShoot" and "Auto Shoot" or "Silent Aim") .. ": selección corporal aplicada.")
    end)
    done.BackgroundColor3 = Color3.fromHex("#E6E9EC")
    done.TextColor3 = Color3.fromHex("#111214")
    runtime.BodySelector.SelectAllButton = selectAllButton
    runtime.BodySelector.ClearButton = clearButton
    runtime.BodySelector.DoneButton = done

    -- Reflow real del selector. En portrait apila el muñeco y la lista; en
    -- landscape/desktop conserva las dos columnas. Sólo usa UIScale como último
    -- recurso si el viewport es físicamente menor que el layout base.
    function runtime.ApplyBodySelectorResponsiveLayout()
        local selector = runtime.BodySelector
        if not selector then return 1 end
        local bounds = selector.Overlay.AbsoluteSize
        if bounds.X < 1 or bounds.Y < 1 then
            local currentCamera = workspace.CurrentCamera
            bounds = currentCamera and currentCamera.ViewportSize or Vector2.new(800, 600)
        end

        local margin = math.clamp(math.floor(math.min(bounds.X, bounds.Y) * 0.025), 6, 14)
        local rawAvailableW = math.max(1, bounds.X - margin * 2)
        local rawAvailableH = math.max(1, bounds.Y - margin * 2)
        local availableW = math.max(240, rawAvailableW)
        local availableH = math.max(260, rawAvailableH)
        local portrait = availableW < 470 or (availableW / math.max(1, availableH)) < 1.05

        if not portrait then
            selector.Card.Size = UDim2.fromOffset(440, 360)
            selector.Title.Position = UDim2.fromOffset(18, 14)
            selector.Title.Size = UDim2.new(1, -88, 0, 24)
            selector.Title.TextSize = 15
            selector.Subtitle.Position = UDim2.fromOffset(18, 39)
            selector.Subtitle.Size = UDim2.new(1, -36, 0, 28)
            selector.Subtitle.TextSize = 10
            selector.CloseButton.Position = UDim2.new(1, -42, 0, 12)
            selector.Figure.Position = UDim2.fromOffset(18, 74)
            selector.Figure.Size = UDim2.fromOffset(160, 220)
            selector.List.Position = UDim2.fromOffset(190, 74)
            selector.List.Size = UDim2.fromOffset(232, 220)
            selector.List.CanvasSize = UDim2.fromOffset(0, 210)

            for index, name in ipairs(runtime.TargetBodyOrder) do
                local row = selector.Rows[name]
                if row then
                    row.Size = UDim2.new(1, 0, 0, 27)
                    row.Position = UDim2.fromOffset(0, (index - 1) * 30)
                    row.TextSize = 10
                end
            end

            selector.SelectAllButton.Size = UDim2.fromOffset(74, 32)
            selector.SelectAllButton.Position = UDim2.new(0, 18, 1, -42)
            selector.ClearButton.Size = UDim2.fromOffset(78, 32)
            selector.ClearButton.Position = UDim2.new(0, 98, 1, -42)
            selector.DoneButton.Size = UDim2.fromOffset(92, 32)
            selector.DoneButton.Position = UDim2.new(0, 330, 1, -42)

            local targetScale = math.min(1, availableW / 440, availableH / 360)
            selector.Scale.Scale = targetScale
            selector.LayoutMode = "wide"
            selector.TargetScale = targetScale
            return targetScale
        end

        local cardW = math.min(420, availableW)
        local cardH = math.min(620, availableH)
        cardH = math.max(360, cardH)
        selector.Card.Size = UDim2.fromOffset(cardW, cardH)
        local portraitScale = math.min(1, rawAvailableW / cardW, rawAvailableH / cardH)
        portraitScale = math.max(0.55, portraitScale)
        selector.Scale.Scale = portraitScale
        selector.TargetScale = portraitScale
        selector.LayoutMode = "portrait"

        selector.Title.Position = UDim2.fromOffset(14, 12)
        selector.Title.Size = UDim2.new(1, -58, 0, 22)
        selector.Title.TextSize = cardW < 330 and 12 or 14
        selector.Title.TextTruncate = Enum.TextTruncate.AtEnd
        selector.Subtitle.Position = UDim2.fromOffset(14, 35)
        selector.Subtitle.Size = UDim2.new(1, -28, 0, 32)
        selector.Subtitle.TextSize = cardW < 330 and 9 or 10
        selector.CloseButton.Position = UDim2.new(1, -40, 0, 10)

        local figureY = 72
        selector.Figure.Size = UDim2.fromOffset(160, 220)
        selector.Figure.Position = UDim2.fromOffset(math.floor((cardW - 160) / 2), figureY)

        local listY = figureY + 228
        local actionsY = cardH - 42
        local listH = math.max(58, actionsY - listY - 8)
        selector.List.Position = UDim2.fromOffset(14, listY)
        selector.List.Size = UDim2.new(1, -28, 0, listH)

        local rowHeight = cardH < 520 and 25 or 27
        local rowStep = rowHeight + 3
        selector.List.CanvasSize = UDim2.fromOffset(0, #runtime.TargetBodyOrder * rowStep)
        for index, name in ipairs(runtime.TargetBodyOrder) do
            local row = selector.Rows[name]
            if row then
                row.Size = UDim2.new(1, -3, 0, rowHeight)
                row.Position = UDim2.fromOffset(0, (index - 1) * rowStep)
                row.TextSize = 10
            end
        end

        local gap = 7
        local buttonW = math.floor((cardW - 28 - gap * 2) / 3)
        selector.SelectAllButton.Size = UDim2.fromOffset(buttonW, 32)
        selector.SelectAllButton.Position = UDim2.fromOffset(14, actionsY)
        selector.ClearButton.Size = UDim2.fromOffset(buttonW, 32)
        selector.ClearButton.Position = UDim2.fromOffset(14 + buttonW + gap, actionsY)
        selector.DoneButton.Size = UDim2.fromOffset(buttonW, 32)
        selector.DoneButton.Position = UDim2.fromOffset(14 + (buttonW + gap) * 2, actionsY)

        return portraitScale
    end

    runtime.Track(overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if overlay.Visible and runtime.BodySelector then
            runtime.ApplyBodySelectorResponsiveLayout()
        end
    end))

    function runtime.BodySelector.Refresh()
        if not runtime.BodySelector then return end
        runtime.RebuildTargetPartNameCache(runtime.BodySelector.Mode)
        local selected = runtime.TargetSelections[runtime.BodySelector.Mode] or {}
        for _, name in ipairs(runtime.TargetBodyOrder) do
            local active = selected[name] == true
            local seg = runtime.BodySelector.Segments[name]
            if seg then
                seg.Button.BackgroundColor3 = active and Color3.fromHex("#E6E9EC") or Color3.fromHex("#24262A")
                seg.Stroke.Color = active and Color3.fromHex("#FFFFFF") or Color3.fromHex("#4B5057")
                seg.Stroke.Transparency = active and 0.05 or 0.35
            end
            local row = runtime.BodySelector.Rows[name]
            if row then
                row.Text = (active and "✓  " or "○  ") .. name
                row.BackgroundColor3 = active and Color3.fromHex("#34373C") or Color3.fromHex("#1C1E21")
                row.TextColor3 = active and Color3.fromHex("#FFFFFF") or Color3.fromHex("#B9BEC5")
            end
        end
    end
end

function runtime.OpenBodySelector(mode)
    runtime.EnsureBodySelector()
    if runtime.BodySelectorGui then
        runtime.BodySelectorGui.DisplayOrder = 2147483647
    end
    runtime.BodySelector.Mode = mode
    runtime.BodySelector.Title.Text = "Selector corporal · " .. (mode == "AutoShoot" and "Auto Shoot" or "Silent Aim")
    runtime.BodySelector.Refresh()
    runtime.BodySelector.Overlay.Visible = true

    local targetScale = runtime.ApplyBodySelectorResponsiveLayout()
    runtime.BodySelector.Scale.Scale = targetScale * 0.965
    runtime.BodySelector.Card.GroupTransparency = 0.12
    TweenService:Create(
        runtime.BodySelector.Scale,
        TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Scale = targetScale}
    ):Play()
    TweenService:Create(
        runtime.BodySelector.Card,
        TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {GroupTransparency = 0}
    ):Play()
end

runtime.AppearanceCatalog = {
    Headless = {Name="Headless Head", Id=134082579, Category="Especiales", Kind="Headless", Badge="OFF-SALE", Desc="Headless local estable"},
    Korblox = {Name="Korblox Right Leg", Id=139607718, Category="Especiales", Kind="Korblox", Badge="OFF-SALE", Desc="Korblox Deathspeaker · reemplazo local R15"},
    HideHair = {Name="Eliminar cabello", Category="Especiales", Kind="HairToggle", Desc="Oculta únicamente el cabello del avatar."},

    -- Caras clásicas/limited. El Id es el asset del catálogo; la textura real
    -- se resuelve una sola vez con game:GetObjects y queda cacheada.
    SSHF = {Name="Super Super Happy Face", Id=494291269, Category="Caras", Kind="Face", Badge="LIMITED • FACE"},
    Stitchface = {Name="Stitchface", Id=8329679, Category="Caras", Kind="Face", Badge="LIMITED • FACE"},
    PlayfulVampire = {Name="Playful Vampire", Id=2409285794, Category="Caras", Kind="Face", Badge="LIMITED • FACE"},
    BeastMode = {Name="Beast Mode", Id=128992838, Category="Caras", Kind="Face", Badge="LIMITED • FACE"},
    YumFace = {Name="Yum!", Id=26019070, Category="Caras", Kind="Face", Badge="LIMITED • FACE"},

    RC = {Name="8-Bit Royal Crown", Id=10159600649, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},
    BitTabby = {Name="8-Bit Tabby Cat", Id=10159617728, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},
    BitCoin = {Name="8-Bit Roblox Coin", Id=10159622004, Category="8-Bit", Kind="Accessory", Badge="LIMITED • FX"},
    BitExtraLife = {Name="8-Bit Extra Life", Id=10159606132, Category="8-Bit", Kind="Accessory", Badge="LIMITED • FX"},
    BitHP = {Name="8-Bit HP Bar", Id=10159610478, Category="8-Bit", Kind="Accessory", Badge="LIMITED • FX"},
    BitClockwork = {Name="8-Bit Clockwork Shades", Id=450557238, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},
    BitEyeball = {Name="8-Bit Eyeball", Id=507791112, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},
    BitTentacles = {Name="8-Bit Mr. Tentacles", Id=507795810, Category="8-Bit", Kind="Accessory", Badge="LIMITED • RARE"},
    BitBowler = {Name="8-Bit Rainbow Bowler", Id=323417020, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},
    BitSwordpack = {Name="8-Bit SwordPack", Id=121925647, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},

    FallFairy = {Name="Fall Fairy", Id=128217885, Category="Fairies", Kind="Accessory", Badge="LIMITED • FX"},
    WinterFairy = {Name="Winter Fairy", Id=141742418, Category="Fairies", Kind="Accessory", Badge="LIMITED • FX"},
    PatrickFairy = {Name="St Patrick's Day Fairy", Id=226189871, Category="Fairies", Kind="Accessory", Badge="LIMITED • FX"},
    SpringFairy = {Name="Spring Fairy", Id=150381051, Category="Fairies", Kind="Accessory", Badge="FX"},

    GreenQueen = {Name="Green Queen of the Night", Id=553970961, Category="Queen of the Night", Kind="Accessory", Badge="LIMITED"},
    BlueQueen = {Name="Blue Queen of the Night", Id=553970606, Category="Queen of the Night", Kind="Accessory", Badge="LIMITED"},
    PurpleQueen = {Name="Purple Queen of the Night", Id=553971858, Category="Queen of the Night", Kind="Accessory", Badge="LIMITED • RARE"},
    PinkQueen = {Name="Pink Queen of the Night", Id=553971558, Category="Queen of the Night", Kind="Accessory", Badge="LIMITED • RARE"},
    NavyQueen = {Name="Navy Queen of the Night", Id=501966049, Category="Queen of the Night", Kind="Accessory", Badge="TOY EXCLUSIVE"},

    Fiery = {Name="Fiery Horns of the Netherworld", Id=215718515, Category="Horns", Kind="Accessory", Badge="LIMITED • FX"},
    Poisoned = {Name="Poisoned Horns of the Toxic Wasteland", Id=1744060292, Category="Horns", Kind="Accessory", Badge="LIMITED • FX"},
    Frozen = {Name="Frozen Horns", Id=74891470, Category="Horns", Kind="Accessory", Badge="LIMITED • FX"},
    BlackIronHorns = {Name="Black Iron Horns", Id=628771505, Category="Horns", Kind="Accessory", Badge="LIMITED • CLASSIC"},

    Valk = {Name="Valkyrie Helm", Id=1365767, Category="Valkyries", Kind="Accessory", Badge="LIMITED"},
    SparkleValk = {Name="Sparkle Time Valkyrie", Id=1180433861, Category="Valkyries", Kind="Accessory", Badge="LIMITED U • ULTRA RARE"},
    Blackvalk = {Name="Blackvalk", Id=124730194, Category="Valkyries", Kind="Accessory", Badge="LIMITED • RARE"},
    EmeraldValk = {Name="Emerald Valkyrie", Id=2830437685, Category="Valkyries", Kind="Accessory", Badge="LIMITED • RARE"},
    VioletValk = {Name="Violet Valkyrie", Id=1402432199, Category="Valkyries", Kind="Accessory", Badge="OFF-SALE"},

    ClockworkShades = {Name="Clockwork's Shades", Id=11748356, Category="Clockwork", Kind="Accessory", Badge="LIMITED • CLASSIC"},
    ClockworkHeadphones = {Name="Clockwork's Headphones", Id=1235488, Category="Clockwork", Kind="Accessory", Badge="LIMITED • CLASSIC"},

    DomEmpyreus = {Name="Dominus Empyreus", Id=21070012, Category="Dominus", Kind="Accessory", Badge="LIMITED • RARE"},
    DomInfernus = {Name="Dominus Infernus", Id=31101391, Category="Dominus", Kind="Accessory", Badge="LIMITED • RARE"},
    DomFrigidus = {Name="Dominus Frigidus", Id=48545806, Category="Dominus", Kind="Accessory", Badge="LIMITED • RARE"},
    DomAstra = {Name="Dominus Astra", Id=162067148, Category="Dominus", Kind="Accessory", Badge="LIMITED • RARE"},

    STF = {Name="Sparkle Time Fedora", Id=1285307, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED"},
    RSTF = {Name="Red Sparkle Time Fedora", Id=72082328, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    MBSTF = {Name="Midnight Blue STF", Id=119916949, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    BSTF = {Name="Black Sparkle Time Fedora", Id=259423244, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    PSTF = {Name="Purple Sparkle Time Fedora", Id=63043890, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    GSTF = {Name="Green Sparkle Time Fedora", Id=100929604, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    TSTF = {Name="Teal Sparkle Time Fedora", Id=147180077, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    SBSTF = {Name="Sky Blue Sparkle Time Fedora", Id=493476042, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    PISTF = {Name="Pink Sparkle Time Fedora", Id=334663683, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    WSTF = {Name="White Sparkle Time Fedora", Id=1016143686, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED"},
    OSTF = {Name="Orange Sparkle Time Fedora", Id=215751161, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},

    Swordpack = {Name="Swordpack", Id=19398258, Category="Espalda", Kind="Accessory", Badge="LIMITED"},
    Daemonshank = {Name="Daemonshank", Id=17521857429, Category="Espalda", Kind="Accessory", Badge="LIMITED"},
    MoltenWings = {Name="Molten Lava Wings", Id=17266515535, Category="Espalda", Kind="Accessory", Badge="LIMITED"},
    Requiem = {Name="The Requiem", Id=107334338147739, Category="Espalda", Kind="Accessory", Badge="LIMITED"},

    KorbloxPauldrons = {Name="Korblox Shoulder Pauldrons", Id=286513125, Category="Hombro", Kind="Accessory", Badge="LIMITED"},
    Raven = {Name="The Raven", Id=20945145, Category="Hombro", Kind="Accessory", Badge="LIMITED"},
    ORLY = {Name="O RLY?", Id=25872570, Category="Hombro", Kind="Accessory", Badge="LIMITED"},
    Headrow = {Name="Headrow", Id=1082935, Category="Hombro", Kind="Accessory", Badge="LIMITED"},
    SparkleBuddy = {Name="RIA 24 Sparkle Buddy", Id=136613436441070, Category="Hombro", Kind="Accessory", Badge="LIMITED"},

    BloxyCreator = {Name="Best Video Content Creator", Id=6736478948, Category="Exclusivos", Kind="Accessory", Badge="BLOXY • OFF-SALE"},
}

runtime.AppearanceOrder = {
    "Headless", "Korblox", "HideHair",
    "SSHF", "Stitchface", "PlayfulVampire", "BeastMode", "YumFace",
    "RC", "BitTabby", "BitCoin", "BitExtraLife", "BitHP", "BitClockwork", "BitEyeball", "BitTentacles", "BitBowler", "BitSwordpack",
    "FallFairy", "WinterFairy", "PatrickFairy", "SpringFairy",
    "GreenQueen", "BlueQueen", "PurpleQueen", "PinkQueen", "NavyQueen",
    "Fiery", "Poisoned", "Frozen", "BlackIronHorns",
    "Valk", "SparkleValk", "Blackvalk", "EmeraldValk", "VioletValk",
    "ClockworkShades", "ClockworkHeadphones",
    "DomEmpyreus", "DomInfernus", "DomFrigidus", "DomAstra",
    "STF", "RSTF", "MBSTF", "BSTF", "PSTF", "GSTF", "TSTF", "SBSTF", "PISTF", "WSTF", "OSTF",
    "Swordpack", "Daemonshank", "MoltenWings", "Requiem",
    "KorbloxPauldrons", "Raven", "ORLY", "Headrow", "SparkleBuddy",
    "BloxyCreator",
}

runtime.AppearanceCategories = {
    "Caras", "8-Bit", "Fairies", "Queen of the Night", "Horns", "Valkyries",
    "Clockwork", "Dominus", "Sparkle Time", "Espalda", "Hombro", "Exclusivos"
}

runtime.Appearance = {
    Enabled = {},
    Templates = {},
    ToggleElements = {},
    OriginalHead = setmetatable({}, {__mode = "k"}),
    OriginalKorblox = setmetatable({}, {__mode = "k"}),
    OriginalFace = setmetatable({}, {__mode = "k"}),
    -- Estado real de Head previo a cualquier capa Face/Headless. Ambas capas leen
    -- de aquí para no guardarse mutuamente como "estado original".
    HeadBaseVisuals = setmetatable({}, {__mode = "k"}),
    FaceTextureCache = {},
    FaceToggleSyncing = false,
    -- Caras clásicas sobre cabezas dinámicas/custom: usamos un head visual compatible
    -- en vez de proyectar el Decal sobre UVs incompatibles.
    FaceClassicVisuals = setmetatable({}, {__mode = "k"}),
    FaceClassicSyncConnection = nil,
    FaceVisualContainer = nil,
    HairVisualCache = setmetatable({}, {__mode = "k"}),

    -- Clonador de avatar: overlay visual local, sin ApplyDescription.
    -- Headless/Korblox/HideHair/limiteds siguen siendo capas independientes.
    AvatarClone = {
        Active = false,
        KeepOnRespawn = true,
        Applying = false,
        TargetUserId = nil,
        TargetName = nil,
        Template = nil,
        Overlay = nil,
        DriverRig = nil,
        BaseCharacter = nil,
        BaseVisualCache = setmetatable({}, {__mode = "k"}),
        -- Hot-path del clon: listas directas evitan recorrer el hash completo y hacer
        -- búsquedas de ancestros cada RenderStepped. Se actualizan sólo cuando cambia
        -- la topología visual del Character.
        BaseHiddenParts = {},
        BaseHiddenTextures = {},
        BaseHiddenEffects = {},
        BaseHiddenIndex = setmetatable({}, {__mode = "k"}),
        ToolVisualConnections = setmetatable({}, {__mode = "k"}),
        OverlayVisualCache = setmetatable({}, {__mode = "k"}),
        MotorPairs = {},
        -- Transparencia nativa: copiamos al overlay el LTM que CameraModule ya
        -- calcula para el Character real. No hay detección manual de primera persona.
        NativeTransparencyPairs = {},
        NativeEffectPairs = {},
        NativeTransparencyBindName = nil,
        NativeCameraTransparencyLast = nil,
        AnimationConnection = nil,
        RenderAnimationConnection = nil,
        BaseDescendantConnection = nil,
        -- Máscara visual instantánea durante el freeze de inicio de ronda.
        RespawnMaskConnection = nil,
        RespawnMaskDescendantConnection = nil,
        RespawnMaskTopologyConnection = nil,
        RespawnMaskGeneration = nil,
        RespawnMaskPending = false,
        VisualContainer = nil,
        SelectedServerPlayer = nil,
        UsernameInput = "",
    },

    BodyGuardConnections = {},
    AccessoryOffsets = {},
    -- Cachés débiles: evitan buscar el mismo accesorio/weld/attachment en cada tick del slider.
    ActiveAccessories = {},
    AccessoryWeld = setmetatable({}, {__mode = "k"}),
    AccessoryBaseWeld = setmetatable({}, {__mode = "k"}),
    AttachmentCache = setmetatable({}, {__mode = "k"}),
    -- Snapshot visual por clon para escalar sin acumular cambios al mover el slider.
    AccessoryBaseVisual = setmetatable({}, {__mode = "k"}),
    EditorSelectedKey = nil,
    EditorSyncing = false,
    BatchLoading = false,
    RespawnGeneration = 0,
    -- Guard del Character actual: si Roblox reconstruye los accesorios tras respawn,
    -- los visuales de iLunX se reinyectan en el siguiente frame sin polling.
    AccessoryGuardConnections = {},
    AccessoryGuardMutating = {},
    AccessoryGuardPending = false,
    AccessoryGuardDirty = false,
    AccessoryCloneRefreshPending = false,
    AccessoryGuardCharacter = nil,
    EditorDisplayToKey = {},
    EditorControls = {},
    EditorSlots = {},
}

for _, key in ipairs(runtime.AppearanceOrder) do
    runtime.Appearance.Enabled[key] = false
end

local KORBLOX_UPPER_MESH = "https://assetdelivery.roblox.com/v1/asset/?id=9598310133"
local KORBLOX_TEXTURE = "rbxassetid://902843398"

local function appearanceSafeSet(obj, prop, value)
    if not obj then return end
    pcall(function()
        if obj[prop] ~= value then obj[prop] = value end
    end)
end

function runtime.ClearAppearanceBodyGuards()
    local list = runtime.Appearance.BodyGuardConnections
    for i = #list, 1, -1 do
        pcall(function() list[i]:Disconnect() end)
        list[i] = nil
    end
end

function runtime.GetHeadBaseVisualState(model)
    local head = model and model:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return nil end

    local base = runtime.Appearance.HeadBaseVisuals[model]
    if base and base.Head == head then
        return base
    end

    local visuals = setmetatable({}, {__mode = "k"})
    for _, d in ipairs(head:GetDescendants()) do
        if d:IsA("Decal") or d:IsA("Texture") then
            visuals[d] = {
                Transparency = d.Transparency,
                Texture = d:IsA("Decal") and d.Texture or nil,
            }
        end
    end

    base = {
        Head = head,
        Transparency = head.Transparency,
        LocalTransparencyModifier = head.LocalTransparencyModifier,
        Visuals = visuals,
    }
    runtime.Appearance.HeadBaseVisuals[model] = base
    return base
end

function runtime.ReleaseHeadBaseVisualState(model)
    if not model then return end
    if runtime.Appearance.Enabled.Headless then return end
    if runtime.GetActiveFaceKey and runtime.GetActiveFaceKey() then return end
    runtime.Appearance.HeadBaseVisuals[model] = nil
end

function runtime.GetHeadAppearanceSnapshot(char)
    local snap = runtime.Appearance.OriginalHead[char]
    local base = runtime.GetHeadBaseVisualState(char)
    local head = base and base.Head
    if not head then return nil end

    if not snap or snap.Head ~= head then
        local visuals = setmetatable({}, {__mode = "k"})
        for d, original in pairs(base.Visuals or {}) do
            if d and d.Parent and original then
                visuals[d] = original.Transparency
            end
        end

        snap = {
            Head = head,
            Transparency = base.Transparency,
            LocalTransparencyModifier = base.LocalTransparencyModifier,
            Visuals = visuals,
        }
        runtime.Appearance.OriginalHead[char] = snap
    end

    return snap
end

function runtime.ApplyHeadlessLayer(char)
    char = char or player.Character
    if not char then return false end
    local snap = runtime.GetHeadAppearanceSnapshot(char)
    if not snap then return false end
    local head = snap.Head

    if runtime.Appearance.Enabled.Headless then
        appearanceSafeSet(head, "Transparency", 1)
        appearanceSafeSet(head, "LocalTransparencyModifier", 1)
        for _, d in ipairs(head:GetDescendants()) do
            if d:IsA("Decal") or d:IsA("Texture") then
                if snap.Visuals[d] == nil then snap.Visuals[d] = d.Transparency end
                appearanceSafeSet(d, "Transparency", 1)
            end
        end
    else
        appearanceSafeSet(head, "Transparency", snap.Transparency)
        appearanceSafeSet(head, "LocalTransparencyModifier", snap.LocalTransparencyModifier)
        for d, old in pairs(snap.Visuals) do
            if d and d.Parent then appearanceSafeSet(d, "Transparency", old) end
        end
        runtime.Appearance.OriginalHead[char] = nil
        runtime.ReleaseHeadBaseVisualState(char)
    end
    return true
end

function runtime.GetActiveFaceKey()
    for _, key in ipairs(runtime.AppearanceOrder) do
        local asset = runtime.AppearanceCatalog[key]
        if asset and asset.Kind == "Face" and runtime.Appearance.Enabled[key] then
            return key
        end
    end
    return nil
end

function runtime.GetFaceTexture(key)
    local asset = runtime.AppearanceCatalog[key]
    if not asset or asset.Kind ~= "Face" then return nil end

    local cached = runtime.Appearance.FaceTextureCache[key]
    if cached and cached ~= "" then return cached end

    local texture
    local ok, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(asset.Id))
    end)

    if ok and type(objects) == "table" then
        for _, root in ipairs(objects) do
            local decal
            if root:IsA("Decal") then
                decal = root
            else
                decal = root:FindFirstChildWhichIsA("Decal", true)
            end
            if decal and decal.Texture and decal.Texture ~= "" then
                texture = decal.Texture
                break
            end
        end
        for _, root in ipairs(objects) do
            pcall(function() root:Destroy() end)
        end
    end

    if texture and texture ~= "" then
        runtime.Appearance.FaceTextureCache[key] = texture
        return texture
    end
    return nil
end

function runtime.GetFaceAppearanceSnapshot(model)
    local base = runtime.GetHeadBaseVisualState(model)
    local head = base and base.Head
    if not head then return nil end

    local snap = runtime.Appearance.OriginalFace[model]
    if snap and snap.Head == head then
        return snap
    end

    local faceDecal
    for _, child in ipairs(head:GetChildren()) do
        if child:IsA("Decal") and (string_lower(child.Name) == "face" or child.Face == Enum.NormalId.Front) then
            faceDecal = child
            break
        end
    end

    local baseVisual = faceDecal and base.Visuals and base.Visuals[faceDecal]
    snap = {
        Head = head,
        Decal = faceDecal,
        Texture = baseVisual and baseVisual.Texture or (faceDecal and faceDecal.Texture or nil),
        DecalTransparency = baseVisual and baseVisual.Transparency or (faceDecal and faceDecal.Transparency or nil),
        Created = false,
        HeadTransparency = base.Transparency,
        HeadLTM = base.LocalTransparencyModifier,
    }
    runtime.Appearance.OriginalFace[model] = snap
    return snap
end

function runtime.FaceNeedsClassicVisual(model)
    local snap = runtime.GetFaceAppearanceSnapshot(model)
    if not snap or not snap.Head then return false end
    local head = snap.Head

    -- Dynamic Heads traen FaceControls. Una cabeza MeshPart/custom sin Decal frontal
    -- tampoco garantiza UVs compatibles con las caras clásicas.
    if head:FindFirstChildOfClass("FaceControls") or head:FindFirstChild("FaceControls") then
        return true
    end
    if snap.Decal and snap.Decal.Parent == head then
        return false
    end
    return head:IsA("MeshPart")
end

function runtime.GetFaceVisualContainer()
    local folder = runtime.Appearance.FaceVisualContainer
    if folder and folder.Parent then return folder end

    folder = Instance.new("Folder")
    folder.Name = "Xero_FaceVisuals"
    folder.Parent = workspace
    runtime.Appearance.FaceVisualContainer = folder
    return folder
end

function runtime.DestroyFaceClassicVisual(model)
    local entry = model and runtime.Appearance.FaceClassicVisuals[model]
    if not entry then return end
    runtime.Appearance.FaceClassicVisuals[model] = nil
    if entry.Part and entry.Part.Parent then
        pcall(function() entry.Part:Destroy() end)
    end
end

local function getClassicFaceHeadScale(model)
    -- Una cara clásica debe conservar la geometría estándar de Roblox. Para igualar
    -- el tamaño relativo de la skin usamos únicamente HeadScale, no las dimensiones
    -- X/Y/Z de una Dynamic Head (esas dimensiones describen otra malla y deformaban
    -- o empequeñecían el reemplazo clásico).
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return 1 end

    -- En un Character/modelo ya escalado, este NumberValue representa el HeadScale
    -- realmente aplicado y evita reconstruir HumanoidDescription en el hot path.
    local scaleValue = humanoid:FindFirstChild("HeadScale")
    if scaleValue and scaleValue:IsA("NumberValue") then
        return math.clamp(tonumber(scaleValue.Value) or 1, 0.5, 2)
    end

    -- Fallback para templates/previews donde Roblox no haya creado el NumberValue.
    local ok, description = pcall(function()
        return humanoid:GetAppliedDescription()
    end)
    if ok and description then
        local headScale = math.clamp(tonumber(description.HeadScale) or 1, 0.5, 2)
        pcall(function() description:Destroy() end)
        return headScale
    end

    return 1
end

function runtime.SyncFaceClassicVisual(model)
    local entry = model and runtime.Appearance.FaceClassicVisuals[model]
    if not entry then return false end
    local head = entry.Head
    local part = entry.Part
    if not head or not head.Parent or not part or not part.Parent then
        runtime.DestroyFaceClassicVisual(model)
        return false
    end

    local key = runtime.GetActiveFaceKey()
    if not key then
        runtime.DestroyFaceClassicVisual(model)
        return false
    end

    -- La cabeza original permanece presente para attachments/animaciones, pero no se dibuja.
    -- Estas dos propiedades sí se reafirman porque CameraModule/juegos pueden reescribirlas.
    appearanceSafeSet(head, "Transparency", 1)
    appearanceSafeSet(head, "LocalTransparencyModifier", 1)

    local texture = runtime.GetFaceTexture(key)
    if texture and entry.Decal
        and (entry.LastAppliedTexture ~= texture or entry.Decal.Texture ~= texture) then
        appearanceSafeSet(entry.Decal, "Texture", texture)
        entry.LastAppliedTexture = texture
    end

    local hidden = runtime.Appearance.Enabled.Headless == true
    local hiddenTransparency = hidden and 1 or 0
    if entry.LastHidden ~= hidden or part.Transparency ~= hiddenTransparency
        or (entry.Decal and entry.Decal.Transparency ~= hiddenTransparency) then
        entry.LastHidden = hidden
        appearanceSafeSet(part, "Transparency", hiddenTransparency)
        if entry.Decal then appearanceSafeSet(entry.Decal, "Transparency", hiddenTransparency) end
    end

    if not entry.Static then
        -- XERO_PERF_FACE_SYNC: sólo CFrame/LTM son realmente dinámicos por frame.
        appearanceSafeSet(part, "CFrame", head.CFrame)

        local headColor = head.Color
        if entry.LastColor ~= headColor or part.Color ~= headColor then
            entry.LastColor = headColor
            appearanceSafeSet(part, "Color", headColor)
        end
        local castShadow = head.CastShadow
        if entry.LastCastShadow ~= castShadow or part.CastShadow ~= castShadow then
            entry.LastCastShadow = castShadow
            appearanceSafeSet(part, "CastShadow", castShadow)
        end

        local headScale = entry.HeadScale or 1
        local scaleValue = entry.HeadScaleValue
        if not scaleValue or not scaleValue.Parent then
            local humanoid = entry.Humanoid
            if not humanoid or humanoid.Parent ~= model then
                humanoid = model:FindFirstChildOfClass("Humanoid")
                entry.Humanoid = humanoid
            end
            scaleValue = humanoid and humanoid:FindFirstChild("HeadScale")
            if scaleValue and scaleValue:IsA("NumberValue") then
                entry.HeadScaleValue = scaleValue
            else
                entry.HeadScaleValue = nil
                scaleValue = nil
            end
        end

        if scaleValue then
            headScale = math.clamp(tonumber(scaleValue.Value) or headScale, 0.5, 2)
            entry.HeadScale = headScale
        elseif not entry.HeadScale then
            headScale = getClassicFaceHeadScale(model)
            entry.HeadScale = headScale
        end

        local mesh = entry.Mesh
        if mesh then
            local targetMeshScale = Vector3.new(1.25, 1.25, 1.25) * headScale
            if entry.LastAppliedHeadScale ~= headScale or mesh.Scale ~= targetMeshScale then
                entry.LastAppliedHeadScale = headScale
                mesh.Scale = targetMeshScale
            end
        end

        -- El visual está fuera del Character/overlay, por lo que CameraModule no lo
        -- desvanece automáticamente en primera persona. Replicamos sólo ese fade.
        local cameraTransparency = 0
        local currentCamera = workspace.CurrentCamera
        if currentCamera then
            local cameraDelta = currentCamera.Focus.Position - currentCamera.CFrame.Position
            local distanceSq = cameraDelta:Dot(cameraDelta)
            if distanceSq < 4 then
                local distance = math.sqrt(distanceSq)
                cameraTransparency = 1 - (distance - 0.5) / 1.5
                if cameraTransparency < 0.5 then cameraTransparency = 0 end
                cameraTransparency = math.clamp(cameraTransparency, 0, 1)
            end
        end
        appearanceSafeSet(part, "LocalTransparencyModifier", hidden and 1 or cameraTransparency)
    end

    return true
end

function runtime.FaceClassicUsesAvatarCloneSync(model)
    local state = runtime.Appearance and runtime.Appearance.AvatarClone
    return model ~= nil
        and state ~= nil
        and state.Overlay == model
        and model.Parent ~= nil
end

function runtime.EnsureFaceClassicSync()
    local current = runtime.Appearance.FaceClassicSyncConnection
    if current and current.Connected then return end

    runtime.Appearance.FaceClassicSyncConnection = runtime.Track(RunService.RenderStepped:Connect(function()
        local anyLive = false
        for model, entry in pairs(runtime.Appearance.FaceClassicVisuals) do
            -- El overlay clonado ya se actualiza al final de su propio syncPose.
            -- No lo repetimos en este RenderStepped para evitar un callback duplicado.
            if entry and not entry.Static and not runtime.FaceClassicUsesAvatarCloneSync(model) then
                if runtime.SyncFaceClassicVisual(model) then anyLive = true end
            end
        end
        if not anyLive then
            local conn = runtime.Appearance.FaceClassicSyncConnection
            runtime.Appearance.FaceClassicSyncConnection = nil
            if conn then pcall(function() conn:Disconnect() end) end
        end
    end))
end

function runtime.CreateFaceClassicVisual(model, texture)
    local snap = runtime.GetFaceAppearanceSnapshot(model)
    if not snap or not snap.Head then return nil end
    local head = snap.Head

    local old = runtime.Appearance.FaceClassicVisuals[model]
    if old and old.Part and old.Part.Parent and old.Head == head then
        if texture and old.Decal then appearanceSafeSet(old.Decal, "Texture", texture) end
        runtime.SyncFaceClassicVisual(model)
        return old
    end
    runtime.DestroyFaceClassicVisual(model)

    local cloneState = runtime.Appearance.AvatarClone
    local isLive = model == player.Character
        or (cloneState and cloneState.Overlay == model)

    local headScale = getClassicFaceHeadScale(model)

    local part = Instance.new("Part")
    part.Name = "Xero_FaceClassicVisual"
    part.Size = Vector3.new(2, 1, 1)
    part.CFrame = head.CFrame
    part.Color = head.Color
    part.Material = Enum.Material.SmoothPlastic
    part.Transparency = 0
    part.LocalTransparencyModifier = 0
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Massless = true
    part.CastShadow = head.CastShadow
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth

    local mesh = Instance.new("SpecialMesh")
    mesh.Name = "Xero_ClassicHeadMesh"
    mesh.MeshType = Enum.MeshType.Head
    mesh.Scale = Vector3.new(1.25, 1.25, 1.25) * headScale
    mesh.Parent = part

    local decal = Instance.new("Decal")
    decal.Name = "face"
    decal.Face = Enum.NormalId.Front
    decal.Texture = texture or ""
    decal.Transparency = runtime.Appearance.Enabled.Headless and 1 or 0
    decal.Parent = part

    local entry = {
        Head = head,
        Part = part,
        Mesh = mesh,
        Decal = decal,
        HeadScale = headScale,
        Static = not isLive,
    }
    runtime.Appearance.FaceClassicVisuals[model] = entry

    if isLive then
        part.Anchored = true
        part.Parent = runtime.GetFaceVisualContainer()

        -- El clon ya posee un RenderStepped para copiar toda la pose. Su Face clásica
        -- se alinea dentro de ese mismo callback, así que no iniciamos otro loop.
        if not runtime.FaceClassicUsesAvatarCloneSync(model) then
            runtime.EnsureFaceClassicSync()
        end
    else
        -- Editor/thumbnail: puede vivir dentro del modelo porque no participa en la
        -- física del jugador. Un WeldConstraint conserva la pose al rotar/PivotTo.
        part.Anchored = false
        part.Parent = model
        local weld = Instance.new("WeldConstraint")
        weld.Name = "Xero_FaceClassicWeld"
        weld.Part0 = head
        weld.Part1 = part
        weld.Parent = part
    end

    runtime.SyncFaceClassicVisual(model)
    return entry
end

function runtime.RestoreFaceLayerForModel(model)
    local snap = model and runtime.Appearance.OriginalFace[model]
    runtime.DestroyFaceClassicVisual(model)
    if not snap then return true end

    if snap.Head and snap.Head.Parent then
        appearanceSafeSet(snap.Head, "Transparency", snap.HeadTransparency)
        appearanceSafeSet(snap.Head, "LocalTransparencyModifier", snap.HeadLTM)
    end

    local decal = snap.Decal
    if decal and decal.Parent then
        if snap.Created then
            pcall(function() decal:Destroy() end)
        else
            appearanceSafeSet(decal, "Texture", snap.Texture or "")
            appearanceSafeSet(decal, "Transparency", snap.DecalTransparency or 0)
        end
    end

    runtime.Appearance.OriginalFace[model] = nil
    runtime.ReleaseHeadBaseVisualState(model)
    return true
end

function runtime.ApplyFaceLayer(model)
    model = model or player.Character
    if not model then return false end

    local key = runtime.GetActiveFaceKey()
    if not key then
        return runtime.RestoreFaceLayerForModel(model)
    end

    -- Cuando hay clon activo el Character real está oculto debajo del overlay. No
    -- creamos un segundo head visual fuera de él; la cara se aplica al overlay visible.
    local cloneState = runtime.Appearance.AvatarClone
    local cloneOwnsVisibleHead = cloneState and model == player.Character and (
        cloneState.Active
        or (cloneState.Applying and cloneState.Overlay and cloneState.Overlay.Parent)
    )
    if cloneOwnsVisibleHead then
        runtime.RestoreFaceLayerForModel(model)
        return true
    end

    local texture = runtime.GetFaceTexture(key)
    if not texture then return false end

    local snap = runtime.GetFaceAppearanceSnapshot(model)
    if not snap or not snap.Head then return false end

    if runtime.FaceNeedsClassicVisual(model) then
        -- Si había un Decal clásico modificado por una llamada previa, se restaura antes
        -- de ocultar la cabeza original.
        if snap.Decal and snap.Decal.Parent then
            appearanceSafeSet(snap.Decal, "Texture", snap.Texture or "")
            appearanceSafeSet(snap.Decal, "Transparency", snap.DecalTransparency or 0)
        end
        appearanceSafeSet(snap.Head, "Transparency", 1)
        appearanceSafeSet(snap.Head, "LocalTransparencyModifier", 1)
        return runtime.CreateFaceClassicVisual(model, texture) ~= nil
    end

    runtime.DestroyFaceClassicVisual(model)
    appearanceSafeSet(snap.Head, "Transparency", snap.HeadTransparency)
    appearanceSafeSet(snap.Head, "LocalTransparencyModifier", snap.HeadLTM)

    local decal = snap.Decal
    if not decal or not decal.Parent then
        -- Sólo las Parts clásicas llegan aquí sin decal; en MeshPart/custom usamos el fallback.
        if not snap.Head:IsA("Part") then return false end
        decal = Instance.new("Decal")
        decal.Name = "face"
        decal.Face = Enum.NormalId.Front
        decal.Transparency = 0
        decal.Parent = snap.Head
        snap.Decal = decal
        snap.Texture = ""
        snap.DecalTransparency = 0
        snap.Created = true
    end

    appearanceSafeSet(decal, "Texture", texture)
    appearanceSafeSet(
        decal,
        "Transparency",
        runtime.Appearance.Enabled.Headless and 1 or (snap.DecalTransparency or 0)
    )
    return true
end

function runtime.DisableOtherFaceToggles(activeKey)
    if runtime.Appearance.FaceToggleSyncing then return end
    runtime.Appearance.FaceToggleSyncing = true

    local wasSuppressed = runtime.SuppressNotifications
    runtime.SuppressNotifications = true
    for _, otherKey in ipairs(runtime.AppearanceOrder) do
        if otherKey ~= activeKey then
            local otherAsset = runtime.AppearanceCatalog[otherKey]
            if otherAsset and otherAsset.Kind == "Face" and runtime.Appearance.Enabled[otherKey] then
                runtime.Appearance.Enabled[otherKey] = false
                local toggle = runtime.Appearance.ToggleElements[otherKey]
                if toggle then
                    pcall(function() toggle:Set(false) end)
                end
            end
        end
    end
    runtime.SuppressNotifications = wasSuppressed
    runtime.Appearance.FaceToggleSyncing = false
end

function runtime.GetKorbloxSnapshot(char)
    local upper = char and char:FindFirstChild("RightUpperLeg")
    local lower = char and char:FindFirstChild("RightLowerLeg")
    local foot = char and char:FindFirstChild("RightFoot")
    if not upper or not upper:IsA("MeshPart") then return nil end

    local snap = runtime.Appearance.OriginalKorblox[char]
    if not snap or snap.Upper ~= upper then
        snap = {
            Upper = upper,
            Lower = lower,
            Foot = foot,
            UpperMeshId = upper.MeshId,
            UpperTextureID = upper.TextureID,
            UpperTransparency = upper.Transparency,
            UpperLTM = upper.LocalTransparencyModifier,
            LowerTransparency = lower and lower.Transparency or nil,
            LowerLTM = lower and lower.LocalTransparencyModifier or nil,
            FootTransparency = foot and foot.Transparency or nil,
            FootLTM = foot and foot.LocalTransparencyModifier or nil,
        }
        runtime.Appearance.OriginalKorblox[char] = snap
    end
    return snap
end

function runtime.ApplyKorbloxLayer(char)
    char = char or player.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
        if runtime.Appearance.Enabled.Korblox then
            showBottomMessage("Korblox local requiere R15.")
        end
        return false
    end

    local snap = runtime.GetKorbloxSnapshot(char)
    if not snap then return false end

    if runtime.Appearance.Enabled.Korblox then
        -- Reemplazo visual directo: NO ApplyDescription. Así no reconstruye Head ni accesorios.
        appearanceSafeSet(snap.Upper, "MeshId", KORBLOX_UPPER_MESH)
        appearanceSafeSet(snap.Upper, "TextureID", KORBLOX_TEXTURE)
        appearanceSafeSet(snap.Upper, "Transparency", 0)
        appearanceSafeSet(snap.Upper, "LocalTransparencyModifier", 0)

        -- El esqueleto se conserva para no romper animaciones, pero estas dos piezas
        -- quedan totalmente ocultas en cliente. Esto evita el "pie cortado" mezclado.
        if snap.Lower and snap.Lower.Parent then
            appearanceSafeSet(snap.Lower, "Transparency", 1)
            appearanceSafeSet(snap.Lower, "LocalTransparencyModifier", 1)
        end
        if snap.Foot and snap.Foot.Parent then
            appearanceSafeSet(snap.Foot, "Transparency", 1)
            appearanceSafeSet(snap.Foot, "LocalTransparencyModifier", 1)
        end
    else
        appearanceSafeSet(snap.Upper, "MeshId", snap.UpperMeshId)
        appearanceSafeSet(snap.Upper, "TextureID", snap.UpperTextureID)
        appearanceSafeSet(snap.Upper, "Transparency", snap.UpperTransparency)
        appearanceSafeSet(snap.Upper, "LocalTransparencyModifier", snap.UpperLTM)
        if snap.Lower and snap.Lower.Parent then
            if snap.LowerTransparency ~= nil then appearanceSafeSet(snap.Lower, "Transparency", snap.LowerTransparency) end
            if snap.LowerLTM ~= nil then appearanceSafeSet(snap.Lower, "LocalTransparencyModifier", snap.LowerLTM) end
        end
        if snap.Foot and snap.Foot.Parent then
            if snap.FootTransparency ~= nil then appearanceSafeSet(snap.Foot, "Transparency", snap.FootTransparency) end
            if snap.FootLTM ~= nil then appearanceSafeSet(snap.Foot, "LocalTransparencyModifier", snap.FootLTM) end
        end
        runtime.Appearance.OriginalKorblox[char] = nil
    end
    return true
end

function runtime.EnforceBodyAppearance(char)
    char = char or player.Character
    if not char then return end
    runtime.ApplyFaceLayer(char)
    if runtime.Appearance.Enabled.Headless then runtime.ApplyHeadlessLayer(char) end
    if runtime.Appearance.Enabled.Korblox then runtime.ApplyKorbloxLayer(char) end
end

local function appearanceGuard(obj, prop, desired)
    if not obj then return end
    local conn = obj:GetPropertyChangedSignal(prop):Connect(function()
        if not runtime.Alive then return end
        if obj.Parent and obj[prop] ~= desired then
            pcall(function() obj[prop] = desired end)
        end
    end)
    table_insert(runtime.Appearance.BodyGuardConnections, conn)
end

function runtime.RebuildAppearanceBodyGuards(char)
    runtime.ClearAppearanceBodyGuards()
    char = char or player.Character
    if not char then return end

    if runtime.Appearance.Enabled.Headless then
        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            appearanceGuard(head, "Transparency", 1)
            appearanceGuard(head, "LocalTransparencyModifier", 1)
            local childConn = head.DescendantAdded:Connect(function(d)
                if runtime.Appearance.Enabled.Headless and (d:IsA("Decal") or d:IsA("Texture")) then
                    task.defer(function()
                        if d.Parent then appearanceSafeSet(d, "Transparency", 1) end
                    end)
                end
            end)
            table_insert(runtime.Appearance.BodyGuardConnections, childConn)
        end
    end

    if runtime.Appearance.Enabled.Korblox then
        local upper = char:FindFirstChild("RightUpperLeg")
        local lower = char:FindFirstChild("RightLowerLeg")
        local foot = char:FindFirstChild("RightFoot")
        if upper and upper:IsA("MeshPart") then
            appearanceGuard(upper, "Transparency", 0)
            appearanceGuard(upper, "LocalTransparencyModifier", 0)

            -- Duels puede restaurar la pierna normal al volver al lobby sin crear un
            -- Character nuevo. Comparamos el ID numérico porque Roblox normaliza URLs.
            local meshConn = upper:GetPropertyChangedSignal("MeshId"):Connect(function()
                if not runtime.Alive or not runtime.Appearance.Enabled.Korblox or not upper.Parent then return end
                if not string.find(tostring(upper.MeshId), "9598310133", 1, true) then
                    appearanceSafeSet(upper, "MeshId", KORBLOX_UPPER_MESH)
                end
            end)
            table_insert(runtime.Appearance.BodyGuardConnections, meshConn)

            local textureConn = upper:GetPropertyChangedSignal("TextureID"):Connect(function()
                if not runtime.Alive or not runtime.Appearance.Enabled.Korblox or not upper.Parent then return end
                if not string.find(tostring(upper.TextureID), "902843398", 1, true) then
                    appearanceSafeSet(upper, "TextureID", KORBLOX_TEXTURE)
                end
            end)
            table_insert(runtime.Appearance.BodyGuardConnections, textureConn)
        end
        if lower and lower:IsA("BasePart") then
            appearanceGuard(lower, "Transparency", 1)
            appearanceGuard(lower, "LocalTransparencyModifier", 1)
        end
        if foot and foot:IsA("BasePart") then
            appearanceGuard(foot, "Transparency", 1)
            appearanceGuard(foot, "LocalTransparencyModifier", 1)
        end
    end

    local activeFaceKey = runtime.GetActiveFaceKey()
    if activeFaceKey then
        local snap = runtime.GetFaceAppearanceSnapshot(char)
        local desiredTexture = runtime.GetFaceTexture(activeFaceKey)
        if snap and snap.Decal and desiredTexture then
            local decal = snap.Decal
            local faceConn = decal:GetPropertyChangedSignal("Texture"):Connect(function()
                if not runtime.Alive or not runtime.GetActiveFaceKey() or not decal.Parent then return end
                local wanted = runtime.GetFaceTexture(runtime.GetActiveFaceKey())
                if wanted and decal.Texture ~= wanted then
                    appearanceSafeSet(decal, "Texture", wanted)
                end
            end)
            table_insert(runtime.Appearance.BodyGuardConnections, faceConn)
        end

        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            local faceChildConn = head.DescendantAdded:Connect(function(d)
                if runtime.GetActiveFaceKey() and d:IsA("Decal") then
                    task.defer(function()
                        if runtime.Alive and char.Parent then runtime.ApplyFaceLayer(char) end
                    end)
                end
            end)
            table_insert(runtime.Appearance.BodyGuardConnections, faceChildConn)
        end
    end

    if runtime.Appearance.Enabled.Headless or runtime.Appearance.Enabled.Korblox or activeFaceKey then
        local conn = char.ChildAdded:Connect(function(child)
            if child.Name == "Head" or child.Name == "RightUpperLeg" or child.Name == "RightLowerLeg" or child.Name == "RightFoot" then
                task.defer(function()
                    if runtime.Alive and char.Parent then
                        runtime.EnforceBodyAppearance(char)
                        runtime.RebuildAppearanceBodyGuards(char)
                    end
                end)
            end
        end)
        table_insert(runtime.Appearance.BodyGuardConnections, conn)
    end
end

function runtime.RemoveAppearanceAccessory(key, char)
    if not char then return end

    -- Evita que el guard de respawn confunda una eliminación intencional
    -- (toggle OFF / reemplazo) con una limpieza hecha por Roblox.
    runtime.Appearance.AccessoryGuardMutating[key] = true

    local cached = runtime.Appearance.ActiveAccessories[key]
    if cached and cached.Parent == char then
        runtime.Appearance.ActiveAccessories[key] = nil
        runtime.Appearance.AccessoryWeld[cached] = nil
        cached:Destroy()
        runtime.Appearance.AccessoryGuardMutating[key] = nil
        return
    end

    runtime.Appearance.ActiveAccessories[key] = nil
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Accoutrement") and obj:GetAttribute("iLunXAppearanceKey") == key then
            runtime.Appearance.AccessoryWeld[obj] = nil
            obj:Destroy()
        end
    end

    runtime.Appearance.AccessoryGuardMutating[key] = nil
end

function runtime.GetAppearanceTemplate(key)
    local cached = runtime.Appearance.Templates[key]
    if cached then return cached end
    local asset = runtime.AppearanceCatalog[key]
    if not asset or asset.Kind ~= "Accessory" then return nil end

    local ok, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(asset.Id))
    end)
    if not ok or type(objects) ~= "table" or #objects == 0 then return nil end

    local template
    for _, root in ipairs(objects) do
        if root:IsA("Accoutrement") then
            template = root:Clone()
        else
            local found = root:FindFirstChildWhichIsA("Accoutrement", true)
            if found then template = found:Clone() end
        end
        if template then break end
    end
    for _, root in ipairs(objects) do pcall(function() root:Destroy() end) end

    if template then
        template.Parent = nil
        runtime.Appearance.Templates[key] = template
    end
    return template
end

local function isAppearanceBodyAttachment(char, attachment)
    return attachment
        and attachment:IsA("Attachment")
        and attachment.Parent
        and attachment.Parent:IsA("BasePart")
        and attachment.Parent.Parent == char
end

local function findAppearanceAttachment(char, name)
    local cache = runtime.Appearance.AttachmentCache[char]
    if not cache then
        cache = {}
        runtime.Appearance.AttachmentCache[char] = cache
        for _, d in ipairs(char:GetDescendants()) do
            -- CRÍTICO: nunca cachear el Attachment DEL PROPIO limited. Durante un
            -- respawn temprano el Accessory ya puede ser hijo del Character antes de
            -- que Roblox agregue el Attachment corporal; antes eso permitía soldar
            -- Handle -> Handle y el limited quedaba invisible/desprendido.
            if isAppearanceBodyAttachment(char, d) then
                cache[d.Name] = cache[d.Name] or d
            end
        end
    end

    local found = cache[name]
    if found and found.Name == name and isAppearanceBodyAttachment(char, found) then
        return found
    end
    cache[name] = nil

    -- Fallback por si Duels reemplazó una pieza/attachment después del snapshot.
    for _, d in ipairs(char:GetDescendants()) do
        if d.Name == name and isAppearanceBodyAttachment(char, d) then
            cache[name] = d
            return d
        end
    end
end

local function manualAttachAppearanceAccessory(char, accessory)
    local handle = accessory and accessory:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return false end
    handle.Anchored = false
    handle.CanCollide = false
    handle.CanTouch = false
    handle.CanQuery = false
    handle.Massless = true

    for _, d in ipairs(handle:GetChildren()) do
        if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then d:Destroy() end
    end

    local ha = handle:FindFirstChildWhichIsA("Attachment")
    if ha then
        local ba = findAppearanceAttachment(char, ha.Name)
        if ba then
            handle.CFrame = ba.Parent.CFrame * ba.CFrame * ha.CFrame:Inverse()
            local weld = Instance.new("Weld")
            weld.Name = "iLunXAppearanceWeld"
            weld.Part0 = handle
            weld.Part1 = ba.Parent
            weld.C0 = ha.CFrame
            weld.C1 = ba.CFrame
            weld.Parent = handle
            return true
        end
    end

    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        local point = CFrame.new()
        pcall(function() point = accessory.AttachmentPoint end)
        handle.CFrame = head.CFrame * point:Inverse()
        local weld = Instance.new("Weld")
        weld.Name = "iLunXAppearanceWeld"
        weld.Part0 = handle
        weld.Part1 = head
        weld.C0 = point
        weld.C1 = CFrame.new()
        weld.Parent = handle
        return true
    end
    return false
end

function runtime.FindAppearanceWeld(accessory)
    if not accessory then return nil end
    local cached = runtime.Appearance.AccessoryWeld[accessory]
    if cached and cached.Parent then return cached end
    local handle = accessory:FindFirstChild("Handle")
    if not handle then return nil end
    local preferred = handle:FindFirstChild("AccessoryWeld") or handle:FindFirstChild("iLunXAppearanceWeld")
    if preferred and preferred:IsA("Weld") then
        runtime.Appearance.AccessoryWeld[accessory] = preferred
        return preferred
    end
    for _, d in ipairs(handle:GetChildren()) do
        if d:IsA("Weld") then
            runtime.Appearance.AccessoryWeld[accessory] = d
            return d
        end
    end
end

function runtime.GetAppearanceOffset(key)
    local state = runtime.Appearance.AccessoryOffsets[key]
    if not state then
        state = {Position = Vector3.new(), Rotation = Vector3.new(), Scale = 1}
        runtime.Appearance.AccessoryOffsets[key] = state
    elseif state.Scale == nil then
        -- Compatibilidad con estados/configs creados antes del slider de tamaño.
        state.Scale = 1
    end
    return state
end

function runtime.ApplyAppearanceScaleToInstance(key, accessory)
    if not accessory or not accessory.Parent then return false end

    local snapshot = runtime.Appearance.AccessoryBaseVisual[accessory]
    if not snapshot then
        snapshot = {
            Parts = setmetatable({}, {__mode = "k"}),
            Meshes = setmetatable({}, {__mode = "k"}),
            LastScale = nil,
        }

        -- Clasificamos una sola vez. Durante el drag ya no buscamos SpecialMesh por pieza.
        for _, obj in ipairs(accessory:GetDescendants()) do
            if obj:IsA("BasePart") then
                local mesh = obj:FindFirstChildOfClass("SpecialMesh")
                if mesh then
                    snapshot.Meshes[mesh] = mesh.Scale
                else
                    snapshot.Parts[obj] = obj.Size
                end
            elseif obj:IsA("SpecialMesh") and snapshot.Meshes[obj] == nil then
                snapshot.Meshes[obj] = obj.Scale
            end
        end

        runtime.Appearance.AccessoryBaseVisual[accessory] = snapshot
    end

    local scale = math.clamp(tonumber(runtime.GetAppearanceOffset(key).Scale) or 1, 0.25, 3)
    if snapshot.LastScale == scale then return true end
    snapshot.LastScale = scale

    for part, baseSize in pairs(snapshot.Parts) do
        if part and part.Parent then part.Size = baseSize * scale end
    end
    for mesh, baseScale in pairs(snapshot.Meshes) do
        if mesh and mesh.Parent then mesh.Scale = baseScale * scale end
    end
    return true
end

function runtime.ApplyAppearanceOffsetToInstance(key, accessory, applyScale)
    if not accessory or not accessory.Parent then return false end
    if applyScale ~= false then runtime.ApplyAppearanceScaleToInstance(key, accessory) end

    local weld = runtime.FindAppearanceWeld(accessory)
    if not weld then
        local char = player.Character
        if char then pcall(function() manualAttachAppearanceAccessory(char, accessory) end) end
        weld = runtime.FindAppearanceWeld(accessory)
    end
    if not weld then return false end

    local base = runtime.Appearance.AccessoryBaseWeld[accessory]
    if not base then
        base = weld.C1
        runtime.Appearance.AccessoryBaseWeld[accessory] = base
    end

    local state = runtime.GetAppearanceOffset(key)
    local p = state.Position
    local r = state.Rotation
    weld.C1 = base
        * CFrame.new(p.X, p.Y, p.Z)
        * CFrame.Angles(math_rad(r.X), math_rad(r.Y), math_rad(r.Z))
    return true
end

function runtime.ApplyAppearanceOffset(key, char, applyScale)
    char = char or player.Character
    if not char then return false end

    local cached = runtime.Appearance.ActiveAccessories[key]
    if cached and cached.Parent == char then
        return runtime.ApplyAppearanceOffsetToInstance(key, cached, applyScale)
    end

    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Accoutrement") and obj:GetAttribute("iLunXAppearanceKey") == key then
            runtime.Appearance.ActiveAccessories[key] = obj
            return runtime.ApplyAppearanceOffsetToInstance(key, obj, applyScale)
        end
    end
    return false
end

function runtime.ApplyAppearanceAccessory(key, char)
    char = char or player.Character
    if not char then return false end
    runtime.RemoveAppearanceAccessory(key, char)
    if not runtime.Appearance.Enabled[key] then return true end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local template = runtime.GetAppearanceTemplate(key)
    local asset = runtime.AppearanceCatalog[key]
    if not humanoid or not template or not asset then return false end

    local accessory = template:Clone()
    accessory:SetAttribute("iLunXAppearanceKey", key)

    -- AddAccessory funciona mejor recibiendo el Accessory sin parent. Roblox lo
    -- parenta y crea el weld. Si el rig todavía no está listo, hacemos fallback manual.
    local ok = pcall(function() humanoid:AddAccessory(accessory) end)
    if not ok or accessory.Parent ~= char then
        accessory.Parent = char
        ok = manualAttachAppearanceAccessory(char, accessory)
    end

    if not ok then
        runtime.Appearance.ActiveAccessories[key] = nil
        if accessory.Parent then accessory:Destroy() end
        return false
    end

    runtime.Appearance.ActiveAccessories[key] = accessory

    -- XERO_SYNC_LIMITED_ATTACH:
    -- Humanoid:AddAccessory puede parentar el Accessory antes de crear AccessoryWeld.
    -- Si esperamos al defer, durante respawn existe una carrera donde el limited queda
    -- creado pero todavía no visible. Intentamos cerrar el attach EN ESTE MISMO turno.
    local attachedNow = runtime.ApplyAppearanceOffsetToInstance(key, accessory, true)
    if not attachedNow then
        runtime.Appearance.AttachmentCache[char] = nil
        pcall(function() manualAttachAppearanceAccessory(char, accessory) end)
        runtime.Appearance.AccessoryWeld[accessory] = nil
        attachedNow = runtime.ApplyAppearanceOffsetToInstance(key, accessory, true)
    end

    -- Roblox todavía puede reemplazar attachments unos frames después. Esta segunda
    -- pasada es barata y sólo actúa sobre ESTE accessory; no escanea todo el avatar.
    task.defer(function()
        if not runtime.Alive or accessory.Parent ~= char then return end
        if not runtime.ApplyAppearanceOffsetToInstance(key, accessory, true) then
            runtime.Appearance.AttachmentCache[char] = nil
            pcall(function() manualAttachAppearanceAccessory(char, accessory) end)
            runtime.Appearance.AccessoryWeld[accessory] = nil
            runtime.ApplyAppearanceOffsetToInstance(key, accessory, true)
        end
        runtime.EnforceBodyAppearance(char)
    end)
    return true
end

function runtime.ReapplyAppearanceAccessories(char)
    char = char or player.Character
    if not char then return end
    for _, key in ipairs(runtime.AppearanceOrder) do
        local asset = runtime.AppearanceCatalog[key]
        if asset and asset.Kind == "Accessory" and runtime.Appearance.Enabled[key] then
            runtime.ApplyAppearanceAccessory(key, char)
        end
    end
    runtime.EnforceBodyAppearance(char)
end

local function hasEnabledAppearanceAccessory()
    for _, key in ipairs(runtime.AppearanceOrder) do
        local asset = runtime.AppearanceCatalog[key]
        if asset and asset.Kind == "Accessory" and runtime.Appearance.Enabled[key] then
            return true
        end
    end
    return false
end

-- Reaplica únicamente lo que falte. Si el clon existe pero todavía no tiene
-- weld válido, reintenta el attach sobre el mismo clon antes de recrearlo.
function runtime.EnsureAppearanceAccessoryKey(key, char)
    char = char or player.Character
    if not char or not runtime.Appearance.Enabled[key] then return false end

    local current = runtime.Appearance.ActiveAccessories[key]
    if not current or current.Parent ~= char then
        current = nil
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Accoutrement") and obj:GetAttribute("iLunXAppearanceKey") == key then
                current = obj
                runtime.Appearance.ActiveAccessories[key] = obj
                break
            end
        end
    end

    if current and current.Parent == char then
        -- No basta con que exista cualquier Weld. Un self-weld o un weld apuntando a
        -- una pieza corporal vieja puede hacer que ApplyAppearanceOffset parezca OK
        -- aunque el limited esté visualmente perdido. Validamos primero la topología.
        if runtime.IsAppearanceAccessoryReady(key, char) then
            return runtime.ApplyAppearanceOffsetToInstance(key, current, true)
        end

        runtime.Appearance.AttachmentCache[char] = nil
        runtime.Appearance.AccessoryWeld[current] = nil
        runtime.Appearance.AccessoryBaseWeld[current] = nil
        if manualAttachAppearanceAccessory(char, current) then
            runtime.Appearance.AccessoryWeld[current] = nil
            runtime.Appearance.AccessoryBaseWeld[current] = nil
            return runtime.IsAppearanceAccessoryReady(key, char)
                and runtime.ApplyAppearanceOffsetToInstance(key, current, true)
                or false
        end
        return false
    end

    return runtime.ApplyAppearanceAccessory(key, char)
end



local function isHairAccessory(accessory)
    if not accessory or not accessory:IsA("Accessory") then
        return false
    end

    -- Método moderno
    local isHair = false
    pcall(function()
        isHair = accessory.AccessoryType == Enum.AccessoryType.Hair
    end)

    if isHair then
        return true
    end

    -- Fallback para accesorios antiguos
    local handle = accessory:FindFirstChild("Handle")
    if handle and handle:FindFirstChild("HairAttachment") then
        return true
    end

    return false
end


function runtime.ApplyHairRemoval(char)
    local cache = runtime.Appearance.HairVisualCache
    local enabled = runtime.Appearance.Enabled.HideHair == true

    -- RESTAURAR
    if not enabled then
        for object, original in pairs(cache) do
            if object and object.Parent then
                pcall(function()
                    if original.LocalTransparencyModifier ~= nil
                        and object:IsA("BasePart") then

                        object.LocalTransparencyModifier =
                            original.LocalTransparencyModifier
                    end

                    if original.Enabled ~= nil then
                        object.Enabled = original.Enabled
                    end
                end)
            end

            cache[object] = nil
        end

        return
    end

    -- OCULTAR
    char = char or player.Character
    if not char then return end

    for _, accessory in ipairs(char:GetChildren()) do
        if isHairAccessory(accessory)
            and accessory:GetAttribute("iLunXAppearanceKey") == nil then

            for _, object in ipairs(accessory:GetDescendants()) do

                if object:IsA("BasePart") then

                    if not cache[object] then
                        cache[object] = {
                            LocalTransparencyModifier =
                                object.LocalTransparencyModifier
                        }
                    end

                    object.LocalTransparencyModifier = 1

                elseif object:IsA("ParticleEmitter")
                    or object:IsA("Trail")
                    or object:IsA("Beam") then

                    if not cache[object] then
                        cache[object] = {
                            Enabled = object.Enabled
                        }
                    end

                    object.Enabled = false
                end
            end
        end
    end
end

function runtime.EnsureAppearanceAccessories(char)
    char = char or player.Character
    if not char then return end

    for _, key in ipairs(runtime.AppearanceOrder) do
        local asset = runtime.AppearanceCatalog[key]
        if asset and asset.Kind == "Accessory" and runtime.Appearance.Enabled[key] then
            runtime.EnsureAppearanceAccessoryKey(key, char)
        end
    end

    runtime.EnforceBodyAppearance(char)
end

-- Comprueba que el limited no sólo exista, sino que ya tenga un weld válido hacia
-- una pieza del Character actual. "Parent == char" por sí solo no significa visible.
function runtime.IsAppearanceAccessoryReady(key, char)
    char = char or player.Character
    if not char then return false end

    local accessory = runtime.Appearance.ActiveAccessories[key]
    if not accessory or accessory.Parent ~= char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Accoutrement") and child:GetAttribute("iLunXAppearanceKey") == key then
                accessory = child
                runtime.Appearance.ActiveAccessories[key] = child
                break
            end
        end
    end
    if not accessory or accessory.Parent ~= char then return false end

    local handle = accessory:FindFirstChild("Handle")
    local weld = runtime.FindAppearanceWeld(accessory)
    if not handle or not handle:IsA("BasePart") or not weld or not weld.Parent then return false end
    if weld.Part0 ~= handle or not weld.Part1 or not weld.Part1:IsDescendantOf(char) then return false end

    -- AccessoryWeld válido = Handle -> una pieza corporal ACTUAL del Character.
    -- Esto rechaza tanto el antiguo self-weld Handle -> Handle como referencias a
    -- Heads/Torsos que Duels ya reemplazó durante el respawn.
    if weld.Part1 == handle or weld.Part1.Parent ~= char
        or char:FindFirstChild(weld.Part1.Name) ~= weld.Part1 then
        return false
    end
    return true
end

-- XERO_LIMITED_RESPAWN_SETTLE:
-- Micro-guardia dedicada a limiteds. NO espera el freeze de 4.5-7 s del clon; sólo
-- trabaja durante la pequeña ventana en la que Roblox va agregando Head/attachments.
-- Sale inmediatamente en cuanto todos los limiteds activos tienen weld válido.
function runtime.FastEnsureAppearanceAccessories(char, generation, maxDuration)
    char = char or player.Character
    if not char or not char.Parent or not hasEnabledAppearanceAccessory() then return true end

    local deadline = os.clock() + (tonumber(maxDuration) or 0.9)
    local pass = 0

    repeat
        if not runtime.Alive or char ~= player.Character or not char.Parent then return false end
        if generation and generation ~= runtime.Appearance.RespawnGeneration then return false end

        pass = pass + 1
        local allReady = true
        for _, key in ipairs(runtime.AppearanceOrder) do
            local asset = runtime.AppearanceCatalog[key]
            if asset and asset.Kind == "Accessory" and runtime.Appearance.Enabled[key] then
                if not runtime.IsAppearanceAccessoryReady(key, char) then
                    runtime.EnsureAppearanceAccessoryKey(key, char)
                end
                if not runtime.IsAppearanceAccessoryReady(key, char) then
                    allReady = false
                end
            end
        end

        if allReady then
            runtime.EnforceBodyAppearance(char)
            return true
        end

        -- Dos frames inmediatos cubren la mayoría de respawns. Después bajamos
        -- frecuencia para no convertir una condición rara en trabajo por frame.
        if pass <= 2 then
            RunService.Heartbeat:Wait()
        else
            task.wait(math.min(0.025 * pass, 0.10))
        end
    until os.clock() >= deadline

    return false
end

-- ==========================================
-- CLONADOR DE AVATAR · OVERLAY VISUAL 100% CLIENTE
-- ==========================================
-- IMPORTANTE: no usamos Humanoid:ApplyDescription*(). Esas llamadas pueden estar
-- restringidas al backend del servidor. En su lugar Roblox construye un modelo
-- independiente del avatar y iLunXHub lo sincroniza visualmente sobre el Character.
-- El Character real permanece debajo, por lo que Headless/Korblox/HideHair y los
-- limiteds del hub siguen siendo capas independientes y reversibles.

function runtime.GetHumanoidDescriptionFromUserIdSafe(userId)
    userId = tonumber(userId)
    if not userId or userId <= 0 then return nil, "UserId inválido" end

    local ok, result = pcall(function()
        return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
    end)
    if ok and result then return result end

    ok, result = pcall(function()
        return Players:GetHumanoidDescriptionFromUserId(userId)
    end)
    if ok and result then return result end

    return nil, tostring(result or "No se pudo obtener la apariencia")
end

function runtime.ReapplyAppearanceLayers(char)
    char = char or player.Character
    if not char or not char.Parent then return end

    runtime.EnforceBodyAppearance(char)
    runtime.ApplyHairRemoval(char)
    runtime.EnsureAppearanceAccessories(char)
    runtime.RebuildAppearanceBodyGuards(char)
end

function runtime.PrepareAvatarCloneTemplate(model)
    if not model or not model:IsA("Model") then return nil end

    model.Name = "iLunX_AvatarCloneTemplate"
    model.Archivable = true
    model:SetAttribute("iLunXAvatarClone", true)

    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript")
            or object:IsA("Tool") or object:IsA("ForceField") or object:IsA("BillboardGui") then
            pcall(function() object:Destroy() end)
        elseif object:IsA("BasePart") then
            object.CanCollide = false
            object.CanTouch = false
            object.CanQuery = false
            object.Massless = true
            object.Anchored = false
        end
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function() humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        pcall(function() humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
        pcall(function() humanoid.NameDisplayDistance = 0 end)
        pcall(function() humanoid.HealthDisplayDistance = 0 end)
        pcall(function() humanoid.AutoRotate = false end)
        pcall(function() humanoid.PlatformStand = true end)
        pcall(function() humanoid.BreakJointsOnDeath = false end)
        pcall(function() humanoid.RequiresNeck = false end)

        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then pcall(function() animator:Destroy() end) end
    end

    return model
end

function runtime.CreateAvatarCloneTemplateFromDescription(description, rigType)
    if not description or not description:IsA("HumanoidDescription") then
        return nil, "Descripción inválida"
    end

    rigType = rigType or Enum.HumanoidRigType.R15
    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(
            description,
            rigType,
            Enum.AssetTypeVerification.Default
        )
    end)

    if (not ok or not model) then
        ok, model = pcall(function()
            return Players:CreateHumanoidModelFromDescription(
                description,
                rigType,
                Enum.AssetTypeVerification.Default
            )
        end)
    end

    if not ok or not model then
        return nil, tostring(model or "No se pudo construir el avatar")
    end

    return runtime.PrepareAvatarCloneTemplate(model)
end

function runtime.CreateAvatarCloneTemplateFromUserId(userId, rigType)
    userId = tonumber(userId)
    if not userId or userId <= 0 then return nil, "UserId inválido" end

    local description, descriptionError = runtime.GetHumanoidDescriptionFromUserIdSafe(userId)
    if description then
        local model, modelError = runtime.CreateAvatarCloneTemplateFromDescription(description, rigType)
        pcall(function() description:Destroy() end)
        if model then return model end
        descriptionError = modelError or descriptionError
    end

    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromUserIdAsync(userId)
    end)
    if (not ok or not model) then
        ok, model = pcall(function()
            return Players:CreateHumanoidModelFromUserId(userId)
        end)
    end

    if not ok or not model then
        return nil, tostring(model or descriptionError or "No se pudo construir el avatar")
    end

    local prepared = runtime.PrepareAvatarCloneTemplate(model)
    local sourceHumanoid = prepared and prepared:FindFirstChildOfClass("Humanoid")
    if sourceHumanoid and rigType and sourceHumanoid.RigType ~= rigType then
        pcall(function() prepared:Destroy() end)
        return nil, "El avatar usa un rig incompatible con este personaje"
    end

    return prepared
end

function runtime.AvatarCloneRestoreOverlayVisuals()
    local state = runtime.Appearance.AvatarClone
    for object, original in pairs(state.OverlayVisualCache) do
        if object and object.Parent then
            pcall(function()
                if original.LocalTransparencyModifier ~= nil and object:IsA("BasePart") then
                    object.LocalTransparencyModifier = original.LocalTransparencyModifier
                end
                if original.Transparency ~= nil and (object:IsA("Decal") or object:IsA("Texture")) then
                    object.Transparency = original.Transparency
                end
                if original.Enabled ~= nil then
                    object.Enabled = original.Enabled
                end
            end)
        end
    end
end

function runtime.AvatarCloneCaptureOverlayVisuals(overlay)
    local state = runtime.Appearance.AvatarClone
    state.OverlayVisualCache = setmetatable({}, {__mode = "k"})

    for _, object in ipairs(overlay:GetDescendants()) do
        if object:IsA("BasePart") then
            state.OverlayVisualCache[object] = {
                LocalTransparencyModifier = object.LocalTransparencyModifier,
            }
        elseif object:IsA("Decal") or object:IsA("Texture") then
            state.OverlayVisualCache[object] = {
                Transparency = object.Transparency,
            }
        elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
            or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
            state.OverlayVisualCache[object] = {
                Enabled = object.Enabled,
            }
        end
    end
end

function runtime.UpdateAvatarCloneLayers()
    local state = runtime.Appearance.AvatarClone
    local overlay = state.Overlay
    if not overlay or not overlay.Parent then return end

    runtime.AvatarCloneRestoreOverlayVisuals()

    runtime.ApplyFaceLayer(overlay)

    if runtime.Appearance.Enabled.Headless then
        local head = overlay:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            head.LocalTransparencyModifier = 1
            for _, object in ipairs(head:GetDescendants()) do
                if object:IsA("Decal") or object:IsA("Texture") then
                    object.Transparency = 1
                end
            end
        end
    end

    if runtime.Appearance.Enabled.Korblox then
        for _, partName in ipairs({"RightUpperLeg", "RightLowerLeg", "RightFoot"}) do
            local part = overlay:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                part.LocalTransparencyModifier = 1
            end
        end
    end

    if runtime.Appearance.Enabled.HideHair then
        for _, object in ipairs(overlay:GetChildren()) do
            if isHairAccessory(object) then
                for _, visual in ipairs(object:GetDescendants()) do
                    if visual:IsA("BasePart") then
                        visual.LocalTransparencyModifier = 1
                    elseif visual:IsA("ParticleEmitter") or visual:IsA("Trail") or visual:IsA("Beam")
                        or visual:IsA("Smoke") or visual:IsA("Fire") or visual:IsA("Sparkles") then
                        visual.Enabled = false
                    end
                end
            end
        end
    end
end


-- ==============================================================
-- CLONADOR · TRANSPARENCIA NATIVA DE CÁMARA
-- ==============================================================
-- Roblox CameraModule ya decide cuánto debe desvanecerse el Character en
-- primera persona/zoom. El Character real está oculto por nuestro overlay, así
-- que copiamos ese LocalTransparencyModifier al equivalente visual del clon.
-- No medimos distancia a la cámara, no cambiamos CameraSubject y no guardamos
-- snapshots temporales que puedan pisar Hair/Korblox/Headless.
function runtime.AvatarCloneResolveNativeSourcePart(char, overlay, clonePart)
    if not char or not overlay or not clonePart then return nil, nil end

    if clonePart.Parent == overlay then
        return char:FindFirstChild(clonePart.Name), nil
    end

    local accessory = clonePart:FindFirstAncestorWhichIsA("Accoutrement")
    if accessory and accessory:IsDescendantOf(overlay) then
        local handle = accessory:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            local preferred = handle:FindFirstChild("AccessoryWeld")
                or handle:FindFirstChild("iLunXAppearanceWeld")

            if preferred and preferred:IsA("Weld") and preferred.Part1 then
                local realPart = char:FindFirstChild(preferred.Part1.Name)
                if realPart and realPart:IsA("BasePart") then
                    return realPart, accessory
                end
            end

            for _, joint in ipairs(handle:GetChildren()) do
                if (joint:IsA("Weld") or joint:IsA("Motor6D")) and joint.Part1 then
                    local realPart = char:FindFirstChild(joint.Part1.Name)
                    if realPart and realPart:IsA("BasePart") then
                        return realPart, accessory
                    end
                end
            end

            local attachment = handle:FindFirstChildWhichIsA("Attachment")
            if attachment then
                for _, bodyPart in ipairs(overlay:GetChildren()) do
                    if bodyPart:IsA("BasePart") and bodyPart:FindFirstChild(attachment.Name) then
                        local realPart = char:FindFirstChild(bodyPart.Name)
                        if realPart and realPart:IsA("BasePart") then
                            return realPart, accessory
                        end
                    end
                end
            end
        end

        local realHead = char:FindFirstChild("Head")
        return realHead and realHead:IsA("BasePart") and realHead or nil, accessory
    end

    local parentPart = clonePart.Parent
    while parentPart and parentPart ~= overlay do
        if parentPart:IsA("BasePart") then
            local realPart = char:FindFirstChild(parentPart.Name)
            if realPart and realPart:IsA("BasePart") then
                return realPart, nil
            end
        end
        parentPart = parentPart.Parent
    end

    return nil, nil
end

function runtime.AvatarCloneBuildNativeTransparencyMap(char, overlay)
    local state = runtime.Appearance.AvatarClone
    table.clear(state.NativeTransparencyPairs)
    table.clear(state.NativeEffectPairs)

    if not char or not char.Parent or not overlay or not overlay.Parent then return false end

    -- CameraModule no necesita leer el LTM del Character real para calcular el fade:
    -- usa únicamente la distancia cámara <-> Focus. Por eso cacheamos sólo los
    -- visuales DEL CLON y conservamos su LTM base para combinarlo con Headless/Korblox.
    for _, object in ipairs(overlay:GetDescendants()) do
        if object:IsA("BasePart") then
            local accessory = object:FindFirstAncestorWhichIsA("Accoutrement")
            local original = state.OverlayVisualCache[object]
            state.NativeTransparencyPairs[#state.NativeTransparencyPairs + 1] = {
                ClonePart = object,
                Accessory = accessory,
                BaseLTM = original and tonumber(original.LocalTransparencyModifier)
                    or tonumber(object.LocalTransparencyModifier)
                    or 0,
            }
        elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
            or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
            local accessory = object:FindFirstAncestorWhichIsA("Accoutrement")
            local original = state.OverlayVisualCache[object]
            state.NativeEffectPairs[#state.NativeEffectPairs + 1] = {
                Effect = object,
                Accessory = accessory,
                BaseEnabled = original and original.Enabled ~= false or object.Enabled,
            }
        end
    end

    return #state.NativeTransparencyPairs > 0
end

function runtime.AvatarCloneNativeLayerHidden(pair)
    local part = pair and pair.ClonePart
    if not part then return false end

    if runtime.Appearance.Enabled.Headless and part.Name == "Head"
        and part.Parent == runtime.Appearance.AvatarClone.Overlay then
        return true
    end

    if runtime.Appearance.Enabled.Korblox and part.Parent == runtime.Appearance.AvatarClone.Overlay
        and (part.Name == "RightUpperLeg" or part.Name == "RightLowerLeg" or part.Name == "RightFoot") then
        return true
    end

    if runtime.Appearance.Enabled.HideHair and pair.Accessory and isHairAccessory(pair.Accessory) then
        return true
    end

    return false
end

function runtime.AvatarCloneSyncNativeTransparency(char, overlay, dt)
    local state = runtime.Appearance.AvatarClone
    if state.Overlay ~= overlay or not overlay or not overlay.Parent or not char or not char.Parent then return end

    local currentCamera = workspace.CurrentCamera
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local subject = currentCamera and currentCamera.CameraSubject
    local cameraOwnsCharacter = currentCamera and humanoid and (
        subject == humanoid
        or subject == char
        or (subject and subject:IsDescendantOf(char))
    )

    -- Mismo cálculo usado por TransparencyController de CameraModule.
    -- IMPORTANTE: NO leemos LocalTransparencyModifier del Character real porque
    -- XeroHub lo mantiene en 1 para esconderlo debajo del overlay.
    local transparency = 0
    if cameraOwnsCharacter and currentCamera then
        local distance = (currentCamera.Focus.Position - currentCamera.CFrame.Position).Magnitude
        transparency = (distance < 2) and (1 - (distance - 0.5) / 1.5) or 0
        if transparency < 0.5 then
            transparency = 0
        end

        local last = state.NativeCameraTransparencyLast
        if last ~= nil and transparency < 1 and last < 0.95 then
            local maxDelta = 2.8 * math.max(tonumber(dt) or 0, 0)
            transparency = last + math.clamp(transparency - last, -maxDelta, maxDelta)
        end

        transparency = math.clamp(math.floor(transparency * 100 + 0.5) / 100, 0, 1)
    end

    state.NativeCameraTransparencyLast = transparency

    for i = 1, #state.NativeTransparencyPairs do
        local pair = state.NativeTransparencyPairs[i]
        local clonePart = pair.ClonePart
        if clonePart and clonePart.Parent then
            local layerLTM = runtime.AvatarCloneNativeLayerHidden(pair) and 1
                or math.clamp(tonumber(pair.BaseLTM) or 0, 0, 1)
            local desired = math.max(transparency, layerLTM)
            if clonePart.LocalTransparencyModifier ~= desired then
                clonePart.LocalTransparencyModifier = desired
            end
        end
    end

    for i = 1, #state.NativeEffectPairs do
        local pair = state.NativeEffectPairs[i]
        local effect = pair.Effect
        if effect and effect.Parent then
            local hiddenByLayer = runtime.Appearance.Enabled.HideHair
                and pair.Accessory and isHairAccessory(pair.Accessory)
            local desired = pair.BaseEnabled == true and transparency < 0.95 and not hiddenByLayer
            if effect.Enabled ~= desired then effect.Enabled = desired end
        end
    end
end

function runtime.AvatarCloneBindNativeTransparency(char, overlay)
    local state = runtime.Appearance.AvatarClone
    local oldName = state.NativeTransparencyBindName
    if oldName then
        pcall(function() RunService:UnbindFromRenderStep(oldName) end)
        state.NativeTransparencyBindName = nil
    end

    if not runtime.AvatarCloneBuildNativeTransparencyMap(char, overlay) then return false end

    local bindName = "XeroHub_AvatarCloneNativeTransparency"
    pcall(function() RunService:UnbindFromRenderStep(bindName) end)
    state.NativeTransparencyBindName = bindName
    state.NativeCameraTransparencyLast = nil

    local ok = pcall(function()
        RunService:BindToRenderStep(
            bindName,
            Enum.RenderPriority.Camera.Value + 1,
            function(dt)
                if not runtime.Alive or player.Character ~= char
                    or state.Overlay ~= overlay or not overlay.Parent then
                    return
                end
                runtime.AvatarCloneSyncNativeTransparency(char, overlay, dt)
                -- CameraModule ya terminó de escribir LTM. Reafirmamos el avatar base
                -- aquí, reutilizando ESTE render callback en vez de duplicar el trabajo
                -- dentro del sincronizador de pose.
                runtime.AvatarCloneEnforceBaseHidden(char)
            end
        )
    end)

    if not ok then
        state.NativeTransparencyBindName = nil
        return false
    end

    runtime.AvatarCloneSyncNativeTransparency(char, overlay, 0)
    return true
end

function runtime.AvatarCloneSuspendLocalLayers(char)
    local headless = runtime.Appearance.Enabled.Headless == true
    local korblox = runtime.Appearance.Enabled.Korblox == true
    local hideHair = runtime.Appearance.Enabled.HideHair == true

    if headless then
        runtime.Appearance.Enabled.Headless = false
        runtime.ApplyHeadlessLayer(char)
    end
    if korblox then
        runtime.Appearance.Enabled.Korblox = false
        runtime.ApplyKorbloxLayer(char)
    end
    if hideHair then
        runtime.Appearance.Enabled.HideHair = false
        runtime.ApplyHairRemoval(char)
    end

    return headless, korblox, hideHair
end

function runtime.AvatarCloneResumeLocalLayers(char, headless, korblox, hideHair)
    runtime.Appearance.Enabled.Headless = headless == true
    runtime.Appearance.Enabled.Korblox = korblox == true
    runtime.Appearance.Enabled.HideHair = hideHair == true

    runtime.EnforceBodyAppearance(char)
    runtime.ApplyHairRemoval(char)
end

-- Las armas equipadas también viven dentro del Character. El overlay sólo debe
-- ocultar el avatar base; jamás un Tool ni sus Handles/meshes/efectos.
function runtime.AvatarCloneIsToolVisual(object, char)
    if not object then return false end
    char = char or player.Character

    local tool
    if object:IsA("Tool") then
        tool = object
    else
        tool = object:FindFirstAncestorWhichIsA("Tool")
    end

    return tool ~= nil and (not char or tool:IsDescendantOf(char))
end

function runtime.AvatarCloneResetBaseVisualTracking()
    local state = runtime.Appearance.AvatarClone
    table.clear(state.BaseHiddenParts)
    table.clear(state.BaseHiddenTextures)
    table.clear(state.BaseHiddenEffects)
    state.BaseHiddenIndex = setmetatable({}, {__mode = "k"})
end

function runtime.AvatarCloneTrackHiddenObject(object)
    if not object then return end
    local state = runtime.Appearance.AvatarClone
    if state.BaseHiddenIndex[object] then return end

    local list
    if object:IsA("BasePart") then
        list = state.BaseHiddenParts
    elseif object:IsA("Decal") or object:IsA("Texture") then
        list = state.BaseHiddenTextures
    elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
        or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
        list = state.BaseHiddenEffects
    end
    if not list then return end

    list[#list + 1] = object
    state.BaseHiddenIndex[object] = {List = list, Index = #list}
end

function runtime.AvatarCloneUntrackHiddenObject(object)
    if not object then return end
    local state = runtime.Appearance.AvatarClone
    local slot = state.BaseHiddenIndex[object]
    if not slot then return end

    local list = slot.List
    local index = slot.Index
    local lastIndex = #list
    local lastObject = list[lastIndex]

    list[index] = lastObject
    list[lastIndex] = nil
    state.BaseHiddenIndex[object] = nil

    if lastObject and lastObject ~= object then
        local lastSlot = state.BaseHiddenIndex[lastObject]
        if lastSlot then lastSlot.Index = index end
    end
end

function runtime.AvatarCloneClearToolVisualGuards()
    local state = runtime.Appearance.AvatarClone
    for tool, bundle in pairs(state.ToolVisualConnections) do
        if bundle then
            if bundle.DescendantAdded then
                pcall(function() bundle.DescendantAdded:Disconnect() end)
            end
            if bundle.AncestryChanged then
                pcall(function() bundle.AncestryChanged:Disconnect() end)
            end
        end
        state.ToolVisualConnections[tool] = nil
    end
end

function runtime.AvatarCloneRestoreCachedVisual(object, cache)
    cache = cache or runtime.Appearance.AvatarClone.BaseVisualCache
    local original = cache and cache[object]
    if not original or not object or not object.Parent then
        if cache and object then cache[object] = nil end
        runtime.AvatarCloneUntrackHiddenObject(object)
        return
    end

    pcall(function()
        if original.LocalTransparencyModifier ~= nil and object:IsA("BasePart") then
            object.LocalTransparencyModifier = original.LocalTransparencyModifier
        end
        if original.Transparency ~= nil and (object:IsA("Decal") or object:IsA("Texture")) then
            object.Transparency = original.Transparency
        end
        if original.Enabled ~= nil then
            object.Enabled = original.Enabled
        end
    end)

    cache[object] = nil
    runtime.AvatarCloneUntrackHiddenObject(object)
end

-- Liberación dirigida: ya no recorremos BaseVisualCache entero por frame. Si se
-- equipa/reparenta un Tool, sólo inspeccionamos ese Tool y restauramos los objetos
-- que realmente estaban cacheados como parte del avatar base.
function runtime.AvatarCloneReleaseToolVisuals(char, specificTool)
    local state = runtime.Appearance.AvatarClone
    local cache = state.BaseVisualCache
    if not cache then return end

    local function releaseObject(object)
        if object and cache[object] then
            runtime.AvatarCloneRestoreCachedVisual(object, cache)
        end
    end

    local function releaseTool(tool)
        if not tool or not tool:IsA("Tool") then return end
        if char and not tool:IsDescendantOf(char) then return end
        releaseObject(tool)
        for _, object in ipairs(tool:GetDescendants()) do
            releaseObject(object)
        end
    end

    if specificTool then
        releaseTool(specificTool)
        return
    end

    char = char or player.Character
    if not char then return end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then releaseTool(child) end
    end
end

-- Guard 100% event-driven para armas. También cubre el caso raro en el que Duels
-- reparenta una pieza ya cacheada DENTRO de un Tool existente: Tool.DescendantAdded
-- la libera en ese instante, sin un escaneo de todo el cache en RenderStepped.
function runtime.AvatarCloneBindToolVisualGuard(char, tool)
    local state = runtime.Appearance.AvatarClone
    if not char or not tool or not tool:IsA("Tool") or not tool:IsDescendantOf(char) then return end
    if state.ToolVisualConnections[tool] then return end

    local bundle = {}
    state.ToolVisualConnections[tool] = bundle

    runtime.AvatarCloneReleaseToolVisuals(char, tool)

    bundle.DescendantAdded = tool.DescendantAdded:Connect(function(object)
        if state.BaseCharacter ~= char or not state.Active then return end
        if state.BaseVisualCache[object] then
            runtime.AvatarCloneRestoreCachedVisual(object, state.BaseVisualCache)
        end
    end)

    bundle.AncestryChanged = tool.AncestryChanged:Connect(function()
        if tool:IsDescendantOf(char) then return end
        local current = state.ToolVisualConnections[tool]
        if current ~= bundle then return end
        state.ToolVisualConnections[tool] = nil
        if bundle.DescendantAdded then
            pcall(function() bundle.DescendantAdded:Disconnect() end)
        end
        if bundle.AncestryChanged then
            pcall(function() bundle.AncestryChanged:Disconnect() end)
        end
    end)
end

function runtime.AvatarCloneCacheAndHideObject(object, cache)
    if not object or not object.Parent then return end

    -- FIX GUN/KNIFE: Handle, MeshPart, SurfaceAppearance, trails, partículas y
    -- cualquier skin que pertenezca a un Tool equipado deben conservarse visibles.
    if runtime.AvatarCloneIsToolVisual(object, player.Character) then
        runtime.AvatarCloneRestoreCachedVisual(object, cache)
        return
    end

    if cache[object] then
        if object:IsA("BasePart") then
            if runtime.Appearance.Enabled.Korblox and object.Name == "RightUpperLeg"
                and object.Parent == player.Character then
                return
            end
            object.LocalTransparencyModifier = 1
        elseif object:IsA("Decal") or object:IsA("Texture") then
            object.Transparency = 1
        elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
            or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
            object.Enabled = false
        end
        return
    end

    if object:IsA("BasePart") then
        local originalLTM = object.LocalTransparencyModifier
        local hairOriginal = runtime.Appearance.HairVisualCache[object]
        if hairOriginal and hairOriginal.LocalTransparencyModifier ~= nil then
            originalLTM = hairOriginal.LocalTransparencyModifier
        end
        cache[object] = {LocalTransparencyModifier = originalLTM}
        runtime.AvatarCloneTrackHiddenObject(object)

        if not (runtime.Appearance.Enabled.Korblox and object.Name == "RightUpperLeg"
            and object.Parent == player.Character) then
            object.LocalTransparencyModifier = 1
        end
    elseif object:IsA("Decal") or object:IsA("Texture") then
        cache[object] = {Transparency = object.Transparency}
        runtime.AvatarCloneTrackHiddenObject(object)
        object.Transparency = 1
    elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
        or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
        local originalEnabled = object.Enabled
        local hairOriginal = runtime.Appearance.HairVisualCache[object]
        if hairOriginal and hairOriginal.Enabled ~= nil then
            originalEnabled = hairOriginal.Enabled
        end
        cache[object] = {Enabled = originalEnabled}
        runtime.AvatarCloneTrackHiddenObject(object)
        object.Enabled = false
    end
end

function runtime.AvatarCloneHideBase(char)
    char = char or player.Character
    if not char or not char.Parent then return false end

    local state = runtime.Appearance.AvatarClone
    if state.BaseCharacter ~= char then
        runtime.AvatarCloneClearToolVisualGuards()
        state.BaseCharacter = char
        state.BaseVisualCache = setmetatable({}, {__mode = "k"})
        runtime.AvatarCloneResetBaseVisualTracking()
    end

    local cache = state.BaseVisualCache
    local firstHide = next(cache) == nil
    local wasHeadless, wasKorblox, wasHideHair

    if firstHide then
        wasHeadless, wasKorblox, wasHideHair = runtime.AvatarCloneSuspendLocalLayers(char)
    end

    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            -- El arma equipada forma parte del Character, pero NO del avatar base.
            runtime.AvatarCloneBindToolVisualGuard(char, child)
        elseif child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
            runtime.AvatarCloneCacheAndHideObject(child, cache)
            for _, visual in ipairs(child:GetDescendants()) do
                if visual:IsA("Decal") or visual:IsA("Texture") then
                    runtime.AvatarCloneCacheAndHideObject(visual, cache)
                end
            end
        elseif child:IsA("Accoutrement") and child:GetAttribute("iLunXAppearanceKey") == nil then
            for _, visual in ipairs(child:GetDescendants()) do
                runtime.AvatarCloneCacheAndHideObject(visual, cache)
            end
        end
    end

    if firstHide then
        runtime.AvatarCloneResumeLocalLayers(char, wasHeadless, wasKorblox, wasHideHair)
    end

    return true
end

function runtime.AvatarCloneRestoreBase(char)
    local state = runtime.Appearance.AvatarClone
    char = char or state.BaseCharacter or player.Character
    if not char then
        runtime.AvatarCloneClearToolVisualGuards()
        state.BaseCharacter = nil
        state.BaseVisualCache = setmetatable({}, {__mode = "k"})
        runtime.AvatarCloneResetBaseVisualTracking()
        return
    end

    local wasHeadless, wasKorblox, wasHideHair = runtime.AvatarCloneSuspendLocalLayers(char)

    for object, original in pairs(state.BaseVisualCache) do
        if object and object.Parent then
            pcall(function()
                if original.LocalTransparencyModifier ~= nil and object:IsA("BasePart") then
                    object.LocalTransparencyModifier = original.LocalTransparencyModifier
                end
                if original.Transparency ~= nil and (object:IsA("Decal") or object:IsA("Texture")) then
                    object.Transparency = original.Transparency
                end
                if original.Enabled ~= nil then
                    object.Enabled = original.Enabled
                end
            end)
        end
    end

    runtime.AvatarCloneClearToolVisualGuards()
    state.BaseCharacter = nil
    state.BaseVisualCache = setmetatable({}, {__mode = "k"})
    runtime.AvatarCloneResetBaseVisualTracking()
    runtime.AvatarCloneResumeLocalLayers(char, wasHeadless, wasKorblox, wasHideHair)
end

function runtime.AvatarCloneDisconnectAnimation()
    local state = runtime.Appearance.AvatarClone
    runtime.AvatarCloneClearToolVisualGuards()
    if state.NativeTransparencyBindName then
        pcall(function() RunService:UnbindFromRenderStep(state.NativeTransparencyBindName) end)
        state.NativeTransparencyBindName = nil
    end
    table.clear(state.NativeTransparencyPairs)
    table.clear(state.NativeEffectPairs)
    state.NativeCameraTransparencyLast = nil
    if state.AnimationConnection then
        pcall(function() state.AnimationConnection:Disconnect() end)
        state.AnimationConnection = nil
    end
    if state.RenderAnimationConnection then
        pcall(function() state.RenderAnimationConnection:Disconnect() end)
        state.RenderAnimationConnection = nil
    end
    if state.BaseDescendantConnection then
        pcall(function() state.BaseDescendantConnection:Disconnect() end)
        state.BaseDescendantConnection = nil
    end
    if state.RespawnMaskConnection then
        pcall(function() state.RespawnMaskConnection:Disconnect() end)
        state.RespawnMaskConnection = nil
    end
    if state.RespawnMaskDescendantConnection then
        pcall(function() state.RespawnMaskDescendantConnection:Disconnect() end)
        state.RespawnMaskDescendantConnection = nil
    end
    if state.RespawnMaskTopologyConnection then
        pcall(function() state.RespawnMaskTopologyConnection:Disconnect() end)
        state.RespawnMaskTopologyConnection = nil
    end
    state.RespawnMaskPending = false
    state.RespawnMaskGeneration = nil
    if state.DriverRig then
        pcall(function() state.DriverRig:Destroy() end)
        state.DriverRig = nil
    end
    table.clear(state.MotorPairs)
end

function runtime.AvatarCloneDestroyOverlay(restoreBase)
    local state = runtime.Appearance.AvatarClone
    runtime.AvatarCloneDisconnectAnimation()

    if state.Overlay then
        runtime.DestroyFaceClassicVisual(state.Overlay)
        runtime.Appearance.OriginalFace[state.Overlay] = nil
        runtime.Appearance.OriginalHead[state.Overlay] = nil
        runtime.Appearance.HeadBaseVisuals[state.Overlay] = nil
        pcall(function() state.Overlay:Destroy() end)
        state.Overlay = nil
    end
    state.OverlayVisualCache = setmetatable({}, {__mode = "k"})

    if restoreBase then
        runtime.AvatarCloneRestoreBase(player.Character)
    end
end

function runtime.AvatarCloneEnforceBaseHidden(char)
    local state = runtime.Appearance.AvatarClone
    char = char or state.BaseCharacter or player.Character
    if not char or state.BaseCharacter ~= char then return end

    local cache = state.BaseVisualCache
    local korblox = runtime.Appearance.Enabled.Korblox == true

    -- Hot path: no pairs(BaseVisualCache), no FindFirstAncestorWhichIsA y no pcall
    -- por objeto. Las armas se liberan por eventos en AvatarCloneBindToolVisualGuard.
    local parts = state.BaseHiddenParts
    local i = 1
    while i <= #parts do
        local object = parts[i]
        if not object or not object.Parent or not cache[object] then
            runtime.AvatarCloneUntrackHiddenObject(object)
        else
            if not (korblox and object.Name == "RightUpperLeg" and object.Parent == char)
                and object.LocalTransparencyModifier ~= 1 then
                object.LocalTransparencyModifier = 1
            end
            i = i + 1
        end
    end

    local textures = state.BaseHiddenTextures
    i = 1
    while i <= #textures do
        local object = textures[i]
        if not object or not object.Parent or not cache[object] then
            runtime.AvatarCloneUntrackHiddenObject(object)
        else
            if object.Transparency ~= 1 then object.Transparency = 1 end
            i = i + 1
        end
    end

    local effects = state.BaseHiddenEffects
    i = 1
    while i <= #effects do
        local object = effects[i]
        if not object or not object.Parent or not cache[object] then
            runtime.AvatarCloneUntrackHiddenObject(object)
        else
            if object.Enabled then object.Enabled = false end
            i = i + 1
        end
    end
end

function runtime.AvatarCloneBuildMotorSync(char, overlay)
    local state = runtime.Appearance.AvatarClone

    -- HANDOFF SIN CORTE: mientras construimos el rig de referencia dejamos vivo
    -- el sync anterior (la máscara de respawn). Algunas llamadas de avatar pueden
    -- ceder varios frames; desconectarlo aquí arriba era el microcorte al aterrizar.
    local baseHumanoid = char:FindFirstChildOfClass("Humanoid")
    local baseRoot = char:FindFirstChild("HumanoidRootPart")
    local overlayRoot = overlay:FindFirstChild("HumanoidRootPart")
    if not baseHumanoid or not baseRoot or not overlayRoot then
        return false, "El personaje todavía no tiene un rig válido"
    end

    -- --------------------------------------------------------------
    -- DRIVER ESTÁNDAR DE NUESTRO AVATAR
    -- --------------------------------------------------------------
    -- Sólo lo usamos para obtener pivotes estándar si el juego modificó
    -- attachments del Character. Nunca se parenta ni participa en física.
    local driverRig
    local driverError

    local okDescription, baseDescription = pcall(function()
        return baseHumanoid:GetAppliedDescription()
    end)

    if okDescription and baseDescription then
        driverRig, driverError =
            runtime.CreateAvatarCloneTemplateFromDescription(
                baseDescription,
                baseHumanoid.RigType
            )
        pcall(function() baseDescription:Destroy() end)
    end

    if not driverRig then
        driverRig, driverError =
            runtime.CreateAvatarCloneTemplateFromUserId(
                player.UserId,
                baseHumanoid.RigType
            )
    end

    if not driverRig then
        return false, "No se pudo construir el rig de referencia: " .. tostring(driverError or "desconocido")
    end

    -- A partir de aquí no hay yields: hacemos el cambio de máscara -> clon definitivo
    -- de forma atómica dentro del mismo frame.
    runtime.AvatarCloneDisconnectAnimation()
    state.Overlay = overlay
    state.DriverRig = driverRig

    -- --------------------------------------------------------------
    -- FÍSICA DEL OVERLAY
    -- --------------------------------------------------------------
    -- Todas las body parts son coordenadas visuales ancladas. Como el overlay
    -- vive fuera de player.Character, esto no puede empujar al jugador.
    for _, object in ipairs(overlay:GetDescendants()) do
        if object:IsA("BasePart") then
            object.CanCollide = false
            object.CanTouch = false
            object.CanQuery = false
            object.Massless = true
            object.AssemblyLinearVelocity = Vector3.zero
            object.AssemblyAngularVelocity = Vector3.zero

            if object.Parent == overlay then
                object.Anchored = true
            elseif object.Parent and object.Parent:IsA("Accoutrement") then
                -- Los accesorios siguen sus AccessoryWeld sobre la body part.
                object.Anchored = false
            end
        elseif object:IsA("Motor6D") then
            -- Las body parts las colocamos nosotros mediante RigAttachments.
            -- Desactivar joints evita que el solver intente recolocarlas.
            pcall(function() object.Enabled = false end)
        end
    end

    overlayRoot.Anchored = true
    overlayRoot.Transparency = 1
    overlayRoot.LocalTransparencyModifier = 1

    local baseParts = {}
    local cloneParts = {}
    local driverParts = {}

    for _, object in ipairs(char:GetChildren()) do
        if object:IsA("BasePart") then baseParts[object.Name] = object end
    end
    for _, object in ipairs(overlay:GetChildren()) do
        if object:IsA("BasePart") then cloneParts[object.Name] = object end
    end
    for _, object in ipairs(driverRig:GetChildren()) do
        if object:IsA("BasePart") then driverParts[object.Name] = object end
    end

    -- Orden jerárquico. Cada hijo se calcula después de su padre, por lo que
    -- cabeza/brazos/piernas siempre permanecen conectados al bundle clonado.
    local r15Joints = {
        {"HumanoidRootPart", "LowerTorso"},
        {"LowerTorso", "UpperTorso"},
        {"UpperTorso", "Head"},

        {"UpperTorso", "LeftUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"},
        {"LeftLowerArm", "LeftHand"},

        {"UpperTorso", "RightUpperArm"},
        {"RightUpperArm", "RightLowerArm"},
        {"RightLowerArm", "RightHand"},

        {"LowerTorso", "LeftUpperLeg"},
        {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"},

        {"LowerTorso", "RightUpperLeg"},
        {"RightUpperLeg", "RightLowerLeg"},
        {"RightLowerLeg", "RightFoot"},
    }

    local r6Joints = {
        {"HumanoidRootPart", "Torso"},
        {"Torso", "Head"},
        {"Torso", "Left Arm"},
        {"Torso", "Right Arm"},
        {"Torso", "Left Leg"},
        {"Torso", "Right Leg"},
    }

    local jointSpecs =
        baseHumanoid.RigType == Enum.HumanoidRigType.R15
        and r15Joints
        or r6Joints

    local function findSharedRigAttachment(part0, part1)
        if not part0 or not part1 then return nil, nil end

        for _, object in ipairs(part0:GetChildren()) do
            if object:IsA("Attachment")
                and string.find(object.Name, "RigAttachment", 1, true) then

                local other = part1:FindFirstChild(object.Name)
                if other and other:IsA("Attachment") then
                    return object, other
                end
            end
        end

        return nil, nil
    end

    for _, spec in ipairs(jointSpecs) do
        local parentName = spec[1]
        local childName = spec[2]

        local realParent = baseParts[parentName]
        local realChild = baseParts[childName]
        local cloneParent = cloneParts[parentName]
        local cloneChild = cloneParts[childName]
        local driverParent = driverParts[parentName]
        local driverChild = driverParts[childName]

        if realParent and realChild and cloneParent and cloneChild then
            -- Pivotes del CLON: estos preservan exactamente sus proporciones.
            local cloneA0, cloneA1 =
                findSharedRigAttachment(cloneParent, cloneChild)

            -- Para leer la pose preferimos attachments reales del Character.
            local realA0, realA1 =
                findSharedRigAttachment(realParent, realChild)

            -- Si el juego los quitó/modificó, usamos los del rig estándar.
            local driverA0, driverA1 =
                findSharedRigAttachment(driverParent, driverChild)

            if cloneA0 and cloneA1
                and ((realA0 and realA1) or (driverA0 and driverA1)) then

                table.insert(state.MotorPairs, {
                    RealParent = realParent,
                    RealChild = realChild,
                    CloneParent = cloneParent,
                    CloneChild = cloneChild,

                    CloneC0 = cloneA0.CFrame,
                    CloneC1 = cloneA1.CFrame,
                    CloneC1Inverse = cloneA1.CFrame:Inverse(),

                    RealC0 = realA0 and realA0.CFrame or nil,
                    RealC1 = realA1 and realA1.CFrame or nil,

                    DriverC0 = driverA0 and driverA0.CFrame or nil,
                    DriverC0Inverse = driverA0 and driverA0.CFrame:Inverse() or nil,
                    DriverC1 = driverA1 and driverA1.CFrame or nil,
                })
            end
        end
    end

    -- R6 puede no traer RigAttachments de hombros/caderas. Conservamos un
    -- fallback visual para él; en R15 normalmente entramos por el camino anterior.
    if #state.MotorPairs == 0 and baseHumanoid.RigType == Enum.HumanoidRigType.R6 then
        for _, spec in ipairs(r6Joints) do
            local realParent = baseParts[spec[1]]
            local realChild = baseParts[spec[2]]
            local cloneParent = cloneParts[spec[1]]
            local cloneChild = cloneParts[spec[2]]

            if realParent and realChild and cloneParent and cloneChild then
                table.insert(state.MotorPairs, {
                    RealParent = realParent,
                    RealChild = realChild,
                    CloneParent = cloneParent,
                    CloneChild = cloneChild,
                    R6Fallback = true,
                    InitialRealRelative = realParent.CFrame:ToObjectSpace(realChild.CFrame),
                    InitialRealRelativeInverse = realParent.CFrame:ToObjectSpace(realChild.CFrame):Inverse(),
                    InitialCloneRelative = cloneParent.CFrame:ToObjectSpace(cloneChild.CFrame),
                })
            end
        end
    end

    if #state.MotorPairs == 0 then
        return false, "No se pudieron encontrar pivotes de cuerpo compatibles"
    end

    local function syncPose()
        if not runtime.Alive
            or state.Overlay ~= overlay
            or not overlay.Parent
            or player.Character ~= char then
            return
        end

        -- El root visual sigue exactamente nuestro movimiento global.
        -- XERO_PERF_CLONE_SYNC: las body parts del overlay están ancladas; sus
        -- velocidades ya se limpian al construir el clon y no necesitan 2 escrituras/joint/frame.
        overlayRoot.CFrame = baseRoot.CFrame

        -- state.MotorPairs ya está en orden raíz -> extremidades. Un solo pcall
        -- protege el frame completo en vez de crear uno por articulación.
        pcall(function()
            for i = 1, #state.MotorPairs do
                local pair = state.MotorPairs[i]
                local realParent = pair.RealParent
                local realChild = pair.RealChild
                local cloneParent = pair.CloneParent
                local cloneChild = pair.CloneChild

                if realParent and realParent.Parent
                    and realChild and realChild.Parent
                    and cloneParent and cloneParent.Parent
                    and cloneChild and cloneChild.Parent then

                    if pair.R6Fallback then
                        local currentRelative = realParent.CFrame:ToObjectSpace(realChild.CFrame)
                        local delta = pair.InitialRealRelativeInverse * currentRelative
                        cloneChild.CFrame = cloneParent.CFrame * pair.InitialCloneRelative * delta
                    else
                        local poseTransform
                        if pair.RealC0 and pair.RealC1 then
                            local parentJointWorld = realParent.CFrame * pair.RealC0
                            local childJointWorld = realChild.CFrame * pair.RealC1
                            poseTransform = parentJointWorld:ToObjectSpace(childJointWorld)
                        else
                            poseTransform = pair.DriverC0Inverse
                                * realParent.CFrame:Inverse()
                                * realChild.CFrame
                                * pair.DriverC1
                        end

                        cloneChild.CFrame = cloneParent.CFrame
                            * pair.CloneC0
                            * poseTransform
                            * pair.CloneC1Inverse
                    end
                end
            end
        end)

        -- La cabeza clásica de Face vive fuera del overlay para no contaminar el rig.
        -- Re-alinearla AQUÍ, después de actualizar todos los CFrame del clon, evita
        -- que quede un frame atrás al caminar/correr si su RenderStepped separado
        -- se ejecutó antes que esta marioneta visual.
        runtime.SyncFaceClassicVisual(overlay)

        -- En condiciones normales la invisibilidad base se reafirma en el bind
        -- Camera+1 de transparencia. Sólo usamos este fallback si ese bind falló.
        if not state.NativeTransparencyBindName then
            runtime.AvatarCloneEnforceBaseHidden(char)
        end
    end

    -- El juego puede terminar su pose tarde en móvil; RenderStepped toma la
    -- posición final que realmente se va a dibujar y actualiza la marioneta.
    state.AnimationConnection = RunService.RenderStepped:Connect(syncPose)

    state.BaseDescendantConnection = char.DescendantAdded:Connect(function(object)
        if state.Overlay ~= overlay or not state.Active then return end
        if object:IsDescendantOf(overlay) then return end

        -- EQUIPPED WEAPON FIX: Character.DescendantAdded también dispara por el
        -- Tool y por TODOS sus descendientes. Nunca los pasamos al hide del avatar.
        local tool = object:IsA("Tool") and object or object:FindFirstAncestorWhichIsA("Tool")
        if tool then
            runtime.AvatarCloneBindToolVisualGuard(char, tool)
            if state.BaseVisualCache[object] then
                runtime.AvatarCloneRestoreCachedVisual(object, state.BaseVisualCache)
            end
            return
        end

        local acc = object:FindFirstAncestorWhichIsA("Accoutrement")
        if acc and acc:GetAttribute("iLunXAppearanceKey") ~= nil then
            return
        end

        if object:IsA("BasePart") then
            if object.Name ~= "HumanoidRootPart" then
                runtime.AvatarCloneCacheAndHideObject(object, state.BaseVisualCache)
            end
        elseif object:IsA("Decal") or object:IsA("Texture")
            or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
            or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
            runtime.AvatarCloneCacheAndHideObject(object, state.BaseVisualCache)
        end
    end)

    syncPose()
    return true
end

function runtime.GetAvatarCloneVisualContainer()
    local state = runtime.Appearance.AvatarClone
    local folder = state.VisualContainer

    if folder and folder.Parent then
        return folder
    end

    folder = workspace:FindFirstChild("iLunX_LocalAvatarClones")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "iLunX_LocalAvatarClones"
        folder.Parent = workspace
    end

    state.VisualContainer = folder
    return folder
end

function runtime.ApplyAvatarCloneTemplate(char, template)
    char = char or player.Character
    if not char or not char.Parent or not template then
        return false, "Personaje o avatar no disponible"
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local ownRoot = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not ownRoot then
        return false, "El personaje todavía no terminó de cargar"
    end

    local state = runtime.Appearance.AvatarClone
    if state.Applying then return false, "Ya se está aplicando otro avatar" end
    state.Applying = true

    -- Conservamos la máscara/overlay anterior hasta que el nuevo clon ya tenga
    -- MotorPairs y pose inicial listos. Así nunca existe un frame entre ambos.
    local previousOverlay = state.Overlay
    local handoffVisualCache = nil

    local ok, result = pcall(function()
        local overlay = template:Clone()
        overlay.Name = "iLunX_AvatarCloneOverlay"
        overlay:SetAttribute("iLunXAvatarClone", true)
        runtime.PrepareAvatarCloneTemplate(overlay)

        local sourceRoot = overlay:FindFirstChild("HumanoidRootPart")
        local sourceHumanoid = overlay:FindFirstChildOfClass("Humanoid")
        if not sourceRoot or not sourceHumanoid then
            overlay:Destroy()
            error("El avatar generado no tiene un rig válido")
        end
        if sourceHumanoid.RigType ~= humanoid.RigType then
            overlay:Destroy()
            error("El rig del avatar no coincide con el personaje actual")
        end

        -- IMPORTANTE: conservamos el Humanoid del clon.
        -- Roblox lo usa para resolver correctamente Shirt/Pants, BodyColors,
        -- CharacterMesh y layered clothing / WrapLayer. Como el overlay vive
        -- fuera de player.Character y todas sus body parts están ancladas,
        -- este Humanoid no participa en la física del jugador real.
        pcall(function()
            sourceHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            sourceHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            sourceHumanoid.NameDisplayDistance = 0
            sourceHumanoid.HealthDisplayDistance = 0
            sourceHumanoid.AutoRotate = false
            sourceHumanoid.PlatformStand = true
            sourceHumanoid.BreakJointsOnDeath = false
            sourceHumanoid.RequiresNeck = false
        end)

        local sourceAnimator = sourceHumanoid:FindFirstChildOfClass("Animator")
        if sourceAnimator then
            pcall(function() sourceAnimator:Destroy() end)
        end

        -- ANTI-FLING DE RESPAWN:
        -- PrepareAvatarCloneTemplate deja las piezas sin Anchored para que el modelo
        -- pueda reutilizar sus welds. Antes de meter el overlay a Workspace las
        -- congelamos TODAS. Así jamás existe ese Heartbeat intermedio en el que el
        -- solver físico puede mover el clon mientras Duels teletransporta/libera al
        -- Character al comenzar una ronda. AvatarCloneBuildMotorSync vuelve a dejar
        -- libres únicamente los handles de accesorios después de fijar el rig visual.
        for _, object in ipairs(overlay:GetDescendants()) do
            if object:IsA("BasePart") then
                object.Anchored = true
                object.CanCollide = false
                object.CanTouch = false
                object.CanQuery = false
                object.Massless = true
                object.AssemblyLinearVelocity = Vector3.zero
                object.AssemblyAngularVelocity = Vector3.zero
            end
        end

        -- Si venimos de la máscara de respawn, el clon nuevo se prepara totalmente
        -- invisible. La máscara vieja sigue animándose mientras Roblox resuelve
        -- clothing/wraps y mientras construimos el rig de referencia.
        if previousOverlay and previousOverlay.Parent then
            handoffVisualCache = setmetatable({}, {__mode = "k"})
            for _, object in ipairs(overlay:GetDescendants()) do
                if object:IsA("BasePart") then
                    handoffVisualCache[object] = {
                        LocalTransparencyModifier = object.LocalTransparencyModifier,
                    }
                    object.LocalTransparencyModifier = 1
                elseif object:IsA("Decal") or object:IsA("Texture") then
                    handoffVisualCache[object] = {Transparency = object.Transparency}
                    object.Transparency = 1
                elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
                    or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
                    handoffVisualCache[object] = {Enabled = object.Enabled}
                    object.Enabled = false
                end
            end
        end

        -- Nunca vive dentro de player.Character: queda totalmente aislado de
        -- los assemblies y de cualquier script que inspeccione el Character.
        overlay.Parent = runtime.GetAvatarCloneVisualContainer()
        overlay:PivotTo(ownRoot.CFrame)

        -- Un frame para que Roblox resuelva clothing/wraps del modelo ya parentado.
        -- La máscara anterior continúa visible y animada durante esta espera.
        RunService.Heartbeat:Wait()
        if not overlay.Parent then
            error("El avatar visual desapareció durante la carga")
        end

        -- En un handoff el cache original ya se tomó ANTES de esconder el clon
        -- nuevo. En una aplicación normal usamos el capturador habitual.
        if not handoffVisualCache then
            runtime.AvatarCloneCaptureOverlayVisuals(overlay)
        end

        local synced, syncError = runtime.AvatarCloneBuildMotorSync(char, overlay)
        if not synced then
            overlay:Destroy()
            if state.Overlay == overlay then state.Overlay = nil end
            error(syncError or "No se pudo sincronizar la pose del avatar")
        end

        -- BuildMotorSync ya ejecutó syncPose() y no cedió después de desconectar
        -- la máscara. Revelamos el clon definitivo y retiramos el viejo en este
        -- mismo frame: sin pose default, sin flash y sin microcorte al tocar piso.
        if handoffVisualCache then
            state.OverlayVisualCache = handoffVisualCache
            runtime.AvatarCloneRestoreOverlayVisuals()
        end

        if previousOverlay and previousOverlay ~= overlay and previousOverlay.Parent then
            runtime.DestroyFaceClassicVisual(previousOverlay)
            runtime.Appearance.OriginalFace[previousOverlay] = nil
            runtime.Appearance.OriginalHead[previousOverlay] = nil
            runtime.Appearance.HeadBaseVisuals[previousOverlay] = nil
            pcall(function() previousOverlay:Destroy() end)
        end

        runtime.ReapplyAppearanceLayers(char)
        runtime.AvatarCloneHideBase(char)
        runtime.UpdateAvatarCloneLayers()
        runtime.AvatarCloneBindNativeTransparency(char, overlay)
    end)

    state.Applying = false

    if not ok then
        runtime.AvatarCloneDestroyOverlay(false)
        if previousOverlay and previousOverlay.Parent then
            runtime.DestroyFaceClassicVisual(previousOverlay)
            runtime.Appearance.OriginalFace[previousOverlay] = nil
            runtime.Appearance.OriginalHead[previousOverlay] = nil
            runtime.Appearance.HeadBaseVisuals[previousOverlay] = nil
            pcall(function() previousOverlay:Destroy() end)
        end

        -- Nunca dejamos el Character real oculto si una reaplicación falla.
        -- Antes, durante una reaplicación, el cache podía seguir forzando
        -- LocalTransparencyModifier=1: eso producía el
        -- estado "clon congelado + jugador invisible" hasta clonar otra vez.
        runtime.AvatarCloneRestoreBase(char)
        runtime.ReapplyAppearanceLayers(char)

        return false, tostring(result)
    end

    return true
end

function runtime.SetClonedAvatarTemplate(template, userId, targetName, silent)
    if not template then return false, "No se recibió un avatar válido" end

    local state = runtime.Appearance.AvatarClone
    if state.Applying then return false, "Ya se está aplicando otro avatar" end

    local previousTemplate = state.Template
    local previousUserId = state.TargetUserId
    local previousName = state.TargetName
    local previousActive = state.Active == true

    local ok, err = runtime.ApplyAvatarCloneTemplate(player.Character, template)
    if not ok then
        if previousTemplate then
            pcall(function() runtime.ApplyAvatarCloneTemplate(player.Character, previousTemplate) end)
        end
        pcall(function() template:Destroy() end)
        state.Template = previousTemplate
        state.TargetUserId = previousUserId
        state.TargetName = previousName
        state.Active = previousActive
        return false, err
    end

    state.Template = template
    state.TargetUserId = tonumber(userId)
    state.TargetName = tostring(targetName or userId or "Avatar")
    state.Active = true

    if previousTemplate and previousTemplate ~= template then
        pcall(function() previousTemplate:Destroy() end)
    end

    if runtime.MarkAvatarThumbnailSpoofDirty then
        runtime.MarkAvatarThumbnailSpoofDirty()
    end

    if not silent then
        showBottomMessage("Avatar clonado: " .. state.TargetName)
    end
    return true
end

function runtime.CloneAvatarFromPlayer(targetPlayer, silent)
    if not targetPlayer or not targetPlayer:IsA("Player") then
        return false, "Jugador no válido"
    end

    local char = player.Character
    local ownHumanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not ownHumanoid then return false, "Tu personaje todavía no cargó" end

    local template
    local targetHumanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    if targetHumanoid then
        local ok, description = pcall(function()
            return targetHumanoid:GetAppliedDescription()
        end)
        if ok and description then
            template = select(1, runtime.CreateAvatarCloneTemplateFromDescription(description, ownHumanoid.RigType))
            pcall(function() description:Destroy() end)
        end
    end

    if not template then
        local model, err = runtime.CreateAvatarCloneTemplateFromUserId(targetPlayer.UserId, ownHumanoid.RigType)
        if not model then return false, err end
        template = model
    end

    return runtime.SetClonedAvatarTemplate(
        template,
        targetPlayer.UserId,
        targetPlayer.Name,
        silent
    )
end

function runtime.CloneAvatarByUsername(username, silent)
    username = tostring(username or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if username == "" then return false, "Escribe un username" end

    local okId, userId = pcall(function()
        return Players:GetUserIdFromNameAsync(username)
    end)
    if not okId or not userId then
        return false, "No se encontró ese usuario"
    end

    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false, "Tu personaje todavía no cargó" end

    local template, err = runtime.CreateAvatarCloneTemplateFromUserId(userId, humanoid.RigType)
    if not template then return false, err end

    local resolvedName = username
    pcall(function()
        resolvedName = Players:GetNameFromUserIdAsync(userId)
    end)

    return runtime.SetClonedAvatarTemplate(template, userId, resolvedName, silent)
end

function runtime.RestoreAvatarClone(silent)
    local state = runtime.Appearance.AvatarClone
    if state.Applying then return false, "La apariencia todavía se está aplicando" end

    state.Applying = true
    runtime.AvatarCloneDestroyOverlay(true)

    if state.Template then
        pcall(function() state.Template:Destroy() end)
        state.Template = nil
    end

    state.Active = false
    state.TargetUserId = nil
    state.TargetName = nil
    state.Applying = false

    runtime.ReapplyAppearanceLayers(player.Character)
    if runtime.MarkAvatarThumbnailSpoofDirty then
        runtime.MarkAvatarThumbnailSpoofDirty()
    end

    if not silent then
        showBottomMessage("Tu avatar original fue restaurado.")
    end
    return true
end

-- Mantiene el clon visible desde el primer frame del Character nuevo sin
-- engancharlo todavía a la física/pose del rig. Todas sus piezas quedan ancladas
-- y el modelo completo sólo sigue el CFrame del HumanoidRootPart nuevo.
function runtime.BeginAvatarCloneRespawnMask(char, generation)
    local state = runtime.Appearance.AvatarClone
    if not state or not state.Active or not state.KeepOnRespawn or not state.Template then
        return false
    end
    if not char or not char.Parent then return false end

    if state.RespawnMaskGeneration == generation
        and (state.RespawnMaskPending or state.RespawnMaskConnection) then
        return true
    end

    if state.RespawnMaskConnection then
        pcall(function() state.RespawnMaskConnection:Disconnect() end)
        state.RespawnMaskConnection = nil
    end
    if state.RespawnMaskDescendantConnection then
        pcall(function() state.RespawnMaskDescendantConnection:Disconnect() end)
        state.RespawnMaskDescendantConnection = nil
    end
    if state.RespawnMaskTopologyConnection then
        pcall(function() state.RespawnMaskTopologyConnection:Disconnect() end)
        state.RespawnMaskTopologyConnection = nil
    end

    state.RespawnMaskGeneration = generation
    state.RespawnMaskPending = true

    task.spawn(function()
        local function valid()
            return runtime.Alive
                and char
                and char.Parent
                and player.Character == char
                and state.Active
                and state.KeepOnRespawn
                and state.Template
                and state.RespawnMaskGeneration == generation
                and (not generation or generation == runtime.Appearance.RespawnGeneration)
        end

        if not valid() then
            if state.RespawnMaskGeneration == generation then
                state.RespawnMaskPending = false
            end
            return
        end

        local root = char:FindFirstChild("HumanoidRootPart")
            or char:WaitForChild("HumanoidRootPart", 1.5)
        local humanoid = char:FindFirstChildOfClass("Humanoid")
            or char:WaitForChild("Humanoid", 1.5)

        if not valid() or not root or not root:IsA("BasePart") or not humanoid then
            if state.RespawnMaskGeneration == generation then
                state.RespawnMaskPending = false
            end
            return
        end

        local overlay = state.Overlay
        if not overlay or not overlay.Parent then
            overlay = state.Template:Clone()
            overlay.Name = "iLunX_AvatarCloneOverlay"
            overlay:SetAttribute("iLunXAvatarClone", true)
            runtime.PrepareAvatarCloneTemplate(overlay)

            -- La máscara nace aislada: nunca participa en la física del Character real.
            for _, object in ipairs(overlay:GetDescendants()) do
                if object:IsA("BasePart") then
                    local accessory = object:FindFirstAncestorWhichIsA("Accoutrement")
                    object.Anchored = accessory == nil
                    object.CanCollide = false
                    object.CanTouch = false
                    object.CanQuery = false
                    object.Massless = true
                    object.AssemblyLinearVelocity = Vector3.zero
                    object.AssemblyAngularVelocity = Vector3.zero
                elseif object:IsA("Motor6D") then
                    pcall(function() object.Enabled = false end)
                end
            end

            overlay.Parent = runtime.GetAvatarCloneVisualContainer()
            state.Overlay = overlay
            runtime.AvatarCloneCaptureOverlayVisuals(overlay)
        else
            for _, object in ipairs(overlay:GetDescendants()) do
                if object:IsA("BasePart") then
                    local accessory = object:FindFirstAncestorWhichIsA("Accoutrement")
                    object.Anchored = accessory == nil
                    object.CanCollide = false
                    object.CanTouch = false
                    object.CanQuery = false
                    object.Massless = true
                    object.AssemblyLinearVelocity = Vector3.zero
                    object.AssemblyAngularVelocity = Vector3.zero
                elseif object:IsA("Motor6D") then
                    pcall(function() object.Enabled = false end)
                end
            end
        end

        if not valid() or state.Overlay ~= overlay or not overlay.Parent then
            return
        end

        local overlayRoot = overlay:FindFirstChild("HumanoidRootPart")
        if not overlayRoot or not overlayRoot:IsA("BasePart") then
            if state.RespawnMaskGeneration == generation then
                state.RespawnMaskPending = false
            end
            return
        end
        overlayRoot.Anchored = true
        overlayRoot.Transparency = 1
        overlayRoot.LocalTransparencyModifier = 1

        pcall(function() overlay:PivotTo(root.CFrame) end)

        -- --------------------------------------------------------------
        -- RESPAWN MASK · LIVE MOTOR POSE
        -- --------------------------------------------------------------
        -- Duels reconstruye partes/Motor6D del MISMO Character durante el countdown.
        -- No guardamos referencias a sus piezas: cada frame resolvemos las actuales.
        -- Además usamos Motor6D.Transform directamente, que es la pose que Animator
        -- escribe para caída/idle/salto/caminar incluso durante el freeze inicial.
        local jointSpecs
        if humanoid.RigType == Enum.HumanoidRigType.R15 then
            jointSpecs = {
                {"HumanoidRootPart", "LowerTorso"},
                {"LowerTorso", "UpperTorso"},
                {"UpperTorso", "Head"},

                {"UpperTorso", "LeftUpperArm"},
                {"LeftUpperArm", "LeftLowerArm"},
                {"LeftLowerArm", "LeftHand"},

                {"UpperTorso", "RightUpperArm"},
                {"RightUpperArm", "RightLowerArm"},
                {"RightLowerArm", "RightHand"},

                {"LowerTorso", "LeftUpperLeg"},
                {"LeftUpperLeg", "LeftLowerLeg"},
                {"LeftLowerLeg", "LeftFoot"},

                {"LowerTorso", "RightUpperLeg"},
                {"RightUpperLeg", "RightLowerLeg"},
                {"RightLowerLeg", "RightFoot"},
            }
        else
            jointSpecs = {
                {"HumanoidRootPart", "Torso"},
                {"Torso", "Head"},
                {"Torso", "Left Arm"},
                {"Torso", "Right Arm"},
                {"Torso", "Left Leg"},
                {"Torso", "Right Leg"},
            }
        end

        local function findSharedRigAttachment(part0, part1)
            if not part0 or not part1 then return nil, nil end
            for _, object in ipairs(part0:GetChildren()) do
                if object:IsA("Attachment")
                    and string.find(object.Name, "RigAttachment", 1, true) then

                    local other = part1:FindFirstChild(object.Name)
                    if other and other:IsA("Attachment") then
                        return object, other
                    end
                end
            end
            return nil, nil
        end

        -- XERO_PERF_CLONE_MOTOR_INDEX: antes cada joint hacía su propio
        -- overlay:GetDescendants(). R15 podía recorrer el mismo modelo 15 veces
        -- durante cada respawn. Indexamos los Motor6D en una sola pasada.
        local cloneMotorIndex = {}
        for _, object in ipairs(overlay:GetDescendants()) do
            if object:IsA("Motor6D") and object.Part0 and object.Part1 then
                local row = cloneMotorIndex[object.Part0.Name]
                if not row then
                    row = {}
                    cloneMotorIndex[object.Part0.Name] = row
                end
                row[object.Part1.Name] = object
            end
        end

        -- Sólo cacheamos geometría DEL CLON, porque esa no cambia durante el respawn.
        local cloneJointData = {}
        for i = 1, #jointSpecs do
            local parentName, childName = jointSpecs[i][1], jointSpecs[i][2]
            local cloneParent = overlay:FindFirstChild(parentName)
            local cloneChild = overlay:FindFirstChild(childName)

            if cloneParent and cloneParent:IsA("BasePart")
                and cloneChild and cloneChild:IsA("BasePart") then

                local motorRow = cloneMotorIndex[parentName]
                local cloneMotor = motorRow and motorRow[childName] or nil
                local cloneC0, cloneC1

                if cloneMotor then
                    cloneC0 = cloneMotor.C0
                    cloneC1 = cloneMotor.C1
                else
                    local a0, a1 = findSharedRigAttachment(cloneParent, cloneChild)
                    if a0 and a1 then
                        cloneC0 = a0.CFrame
                        cloneC1 = a1.CFrame
                    end
                end

                if cloneC0 and cloneC1 then
                    cloneJointData[i] = {
                        ParentName = parentName,
                        ChildName = childName,
                        CloneParent = cloneParent,
                        CloneChild = cloneChild,
                        CloneC0 = cloneC0,
                        CloneC1 = cloneC1,
                        CloneC1Inverse = cloneC1:Inverse(),
                    }
                end
            end
        end

        runtime.AvatarCloneHideBase(char)
        runtime.UpdateAvatarCloneLayers()
        runtime.AvatarCloneBindNativeTransparency(char, overlay)

        -- --------------------------------------------------------------
        -- RESPAWN MASK · EVENT-DRIVEN POSE CACHE
        -- --------------------------------------------------------------
        -- Antes escaneábamos TODOS los descendants y buscábamos 15 partes R15 en
        -- cada RenderStepped. Ahora la topología se resuelve una vez y sólo se
        -- invalida cuando Duels agrega/quita/reemplaza una pieza, attachment o joint.
        local bodyPartNames = {}
        for i = 1, #jointSpecs do
            bodyPartNames[jointSpecs[i][1]] = true
            bodyPartNames[jointSpecs[i][2]] = true
        end

        local posePairs = {}
        local poseCacheDirty = true

        local function isPoseTopologyObject(object)
            if not object then return false end
            if object:IsA("Motor6D") then return true end
            if object:IsA("BasePart") then
                return bodyPartNames[object.Name] == true
            end
            if object:IsA("Attachment")
                and string.find(object.Name, "RigAttachment", 1, true) then
                local parentPart = object.Parent
                return parentPart and parentPart:IsA("BasePart")
                    and bodyPartNames[parentPart.Name] == true
            end
            return false
        end

        local function rebuildRespawnPoseCache()
            if not valid() or state.Overlay ~= overlay or not overlay.Parent then
                return false
            end

            local partsByName = {}
            for _, object in ipairs(char:GetChildren()) do
                if object:IsA("BasePart") and bodyPartNames[object.Name] then
                    partsByName[object.Name] = object
                end
            end

            local liveMotorMap = {}
            for _, object in ipairs(char:GetDescendants()) do
                if object:IsA("Motor6D") and object.Part0 and object.Part1 then
                    liveMotorMap[object.Part0.Name .. ">" .. object.Part1.Name] = object
                end
            end

            local rebuilt = {}
            for i = 1, #jointSpecs do
                local data = cloneJointData[i]
                if data then
                    local realParent = partsByName[data.ParentName]
                    local realChild = partsByName[data.ChildName]
                    local liveMotor = liveMotorMap[data.ParentName .. ">" .. data.ChildName]

                    if liveMotor
                        and (liveMotor.Part0 ~= realParent or liveMotor.Part1 ~= realChild) then
                        liveMotor = nil
                    end

                    if realParent and realChild
                        and data.CloneParent and data.CloneParent.Parent
                        and data.CloneChild and data.CloneChild.Parent then

                        local realC0, realC1
                        if not liveMotor then
                            local realA0, realA1 = findSharedRigAttachment(realParent, realChild)
                            if realA0 and realA1 then
                                realC0 = realA0.CFrame
                                realC1 = realA1.CFrame
                            end
                        end

                        rebuilt[#rebuilt + 1] = {
                            Data = data,
                            RealParent = realParent,
                            RealChild = realChild,
                            LiveMotor = liveMotor,
                            RealC0 = realC0,
                            RealC1 = realC1,
                        }
                    end
                end
            end

            posePairs = rebuilt
            root = partsByName.HumanoidRootPart or root
            poseCacheDirty = false
            return true
        end

        local function hideNewVisual(object)
            if not valid() or state.Overlay ~= overlay then return end
            if object:IsDescendantOf(overlay) then return end

            if isPoseTopologyObject(object) then
                poseCacheDirty = true
            end

            local tool = object:IsA("Tool") and object or object:FindFirstAncestorWhichIsA("Tool")
            if tool then
                runtime.AvatarCloneBindToolVisualGuard(char, tool)
                if state.BaseVisualCache[object] then
                    runtime.AvatarCloneRestoreCachedVisual(object, state.BaseVisualCache)
                end
                return
            end

            local acc = object:FindFirstAncestorWhichIsA("Accoutrement")
            if acc and acc:GetAttribute("iLunXAppearanceKey") ~= nil then
                return
            end

            if object:IsA("BasePart") then
                if object.Name ~= "HumanoidRootPart" then
                    runtime.AvatarCloneCacheAndHideObject(object, state.BaseVisualCache)
                end
            elseif object:IsA("Decal") or object:IsA("Texture")
                or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
                or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
                runtime.AvatarCloneCacheAndHideObject(object, state.BaseVisualCache)
            end
        end

        state.RespawnMaskDescendantConnection = char.DescendantAdded:Connect(hideNewVisual)
        state.RespawnMaskTopologyConnection = char.DescendantRemoving:Connect(function(object)
            if isPoseTopologyObject(object) then
                poseCacheDirty = true
            end
        end)

        rebuildRespawnPoseCache()

        state.RespawnMaskConnection = RunService.RenderStepped:Connect(function()
            if not valid() or state.Overlay ~= overlay or not overlay.Parent then
                return
            end

            -- Normalmente esto es falso. Sólo reconstruye el caché cuando Duels
            -- realmente tocó la topología del rig durante el countdown.
            if not poseCacheDirty then
                for i = 1, #posePairs do
                    local pair = posePairs[i]
                    local motor = pair.LiveMotor
                    if not pair.RealParent.Parent
                        or not pair.RealChild.Parent
                        or not pair.Data.CloneParent.Parent
                        or not pair.Data.CloneChild.Parent
                        or (motor and (not motor.Parent
                            or motor.Part0 ~= pair.RealParent
                            or motor.Part1 ~= pair.RealChild)) then
                        poseCacheDirty = true
                        break
                    end
                end
            end

            if poseCacheDirty then
                rebuildRespawnPoseCache()
            end

            if root and root.Parent then
                overlayRoot.CFrame = root.CFrame
            end

            -- XERO_PERF_RESPAWN_SYNC: sin GetDescendants(), FindFirstChild(),
            -- tablas temporales ni escrituras de velocidad en partes ancladas.
            pcall(function()
                for i = 1, #posePairs do
                    local pair = posePairs[i]
                    local data = pair.Data
                    local realParent = pair.RealParent
                    local realChild = pair.RealChild
                    local cloneParent = data.CloneParent
                    local cloneChild = data.CloneChild

                    local poseTransform
                    local liveMotor = pair.LiveMotor

                    if liveMotor then
                        poseTransform = liveMotor.Transform
                    elseif pair.RealC0 and pair.RealC1 then
                        local parentJointWorld = realParent.CFrame * pair.RealC0
                        local childJointWorld = realChild.CFrame * pair.RealC1
                        poseTransform = parentJointWorld:ToObjectSpace(childJointWorld)
                    end

                    if poseTransform then
                        cloneChild.CFrame = cloneParent.CFrame
                            * data.CloneC0
                            * poseTransform
                            * data.CloneC1Inverse
                    end
                end
            end)

            -- La máscara de respawn usa otro loop de pose. La Face clásica también
            -- debe tomar el Head ya actualizado de ESTE frame para no quedarse atrás.
            runtime.SyncFaceClassicVisual(overlay)

            if not state.NativeTransparencyBindName then
                runtime.AvatarCloneEnforceBaseHidden(char)
            end
        end)

        state.RespawnMaskPending = false
    end)

    return true
end

function runtime.AvatarCloneResetForRespawn(char, generation)
    local state = runtime.Appearance.AvatarClone

    -- Desconectamos la pose vieja, pero conservamos el overlay si el clon debe
    -- sobrevivir al respawn. Ese mismo overlay cubre el Character nuevo mientras
    -- Duels termina su freeze/teleport interno.
    local keepMask = state.Active
        and state.KeepOnRespawn
        and state.Template
        and state.Overlay
        and state.Overlay.Parent

    runtime.AvatarCloneDisconnectAnimation()
    state.BaseCharacter = nil
    state.BaseVisualCache = setmetatable({}, {__mode = "k"})
    runtime.AvatarCloneResetBaseVisualTracking()

    if keepMask then
        runtime.BeginAvatarCloneRespawnMask(char, generation)
    else
        if state.Overlay then
            runtime.DestroyFaceClassicVisual(state.Overlay)
            runtime.Appearance.OriginalFace[state.Overlay] = nil
            runtime.Appearance.OriginalHead[state.Overlay] = nil
            runtime.Appearance.HeadBaseVisuals[state.Overlay] = nil
            pcall(function() state.Overlay:Destroy() end)
            state.Overlay = nil
        end
        state.OverlayVisualCache = setmetatable({}, {__mode = "k"})

        -- Incluso si el overlay anterior ya no existía, podemos crear una máscara
        -- fresca desde el template sin esperar a que termine el countdown.
        if state.Active and state.KeepOnRespawn and state.Template then
            runtime.BeginAvatarCloneRespawnMask(char, generation)
        end
    end
end

function runtime.ClearAppearanceAccessoryGuard()
    local list = runtime.Appearance.AccessoryGuardConnections
    for i = #list, 1, -1 do
        pcall(function() list[i]:Disconnect() end)
        list[i] = nil
    end
    runtime.Appearance.AccessoryGuardPending = false
    runtime.Appearance.AccessoryGuardDirty = false
    runtime.Appearance.AccessoryCloneRefreshPending = false
    runtime.Appearance.AccessoryGuardCharacter = nil
end

function runtime.BindAppearanceAccessoryGuard(char, generation)
    runtime.ClearAppearanceAccessoryGuard()
    if not char or not char.Parent then return end
    runtime.Appearance.AccessoryGuardCharacter = char

    local queueEnsure

    -- El clon tiene SU propia cola. Nunca vuelve a mantener ocupado el guard de
    -- limiteds mientras espera state.Applying / handoff del overlay.
    local function queueCloneRefresh()
        if runtime.Appearance.AccessoryCloneRefreshPending then return end
        runtime.Appearance.AccessoryCloneRefreshPending = true

        task.spawn(function()
            local deadline = os.clock() + 2.5
            while runtime.Alive
                and char == player.Character
                and char.Parent
                and (not generation or generation == runtime.Appearance.RespawnGeneration) do

                local cloneState = runtime.Appearance.AvatarClone
                if not (cloneState and cloneState.Applying) then break end
                if os.clock() >= deadline then break end
                RunService.Heartbeat:Wait()
            end

            runtime.Appearance.AccessoryCloneRefreshPending = false
            if not runtime.Alive or char ~= player.Character or not char.Parent then return end
            if generation and generation ~= runtime.Appearance.RespawnGeneration then return end

            local cloneState = runtime.Appearance.AvatarClone
            if cloneState and cloneState.Applying then
                task.delay(0.12, queueCloneRefresh)
                return
            end

            -- SEGUNDA VALIDACIÓN CRÍTICA: un limited pudo ser eliminado/re-soldado
            -- mientras el clon estaba aplicándose. No ocultamos el avatar base hasta
            -- comprobar de nuevo que todos los limiteds activos están realmente unidos.
            local ready = runtime.FastEnsureAppearanceAccessories(char, generation, 0.35)
            runtime.EnforceBodyAppearance(char)
            runtime.ApplyHairRemoval(char)

            if cloneState and cloneState.Active and cloneState.Overlay and cloneState.Overlay.Parent then
                runtime.AvatarCloneHideBase(char)
                runtime.UpdateAvatarCloneLayers()
                runtime.AvatarCloneBuildNativeTransparencyMap(char, cloneState.Overlay)
            end

            if not ready then
                task.delay(0.05, function()
                    if runtime.Alive and char == player.Character and char.Parent then
                        queueEnsure()
                    end
                end)
            end
        end)
    end

    queueEnsure = function()
        if runtime.Appearance.AccessoryGuardPending then
            -- Antes este evento se PERDÍA. Ahora queda marcado y fuerza otra pasada
            -- apenas termine la que ya está ejecutándose.
            runtime.Appearance.AccessoryGuardDirty = true
            return
        end

        runtime.Appearance.AccessoryGuardPending = true
        runtime.Appearance.AccessoryGuardDirty = false

        task.spawn(function()
            if not runtime.Alive or char ~= player.Character or not char.Parent then
                runtime.Appearance.AccessoryGuardPending = false
                return
            end
            if generation and generation ~= runtime.Appearance.RespawnGeneration then
                runtime.Appearance.AccessoryGuardPending = false
                return
            end

            local ready = runtime.FastEnsureAppearanceAccessories(char, generation, 0.45)
            runtime.EnforceBodyAppearance(char)
            runtime.ApplyHairRemoval(char)

            -- Liberamos el pending ANTES de mirar Dirty. Si entra un evento justo aquí,
            -- iniciará su propia pasada; si entró antes, Dirty ya quedó en true.
            runtime.Appearance.AccessoryGuardPending = false
            local rerun = runtime.Appearance.AccessoryGuardDirty
            runtime.Appearance.AccessoryGuardDirty = false

            if not runtime.Alive or char ~= player.Character or not char.Parent then return end
            if generation and generation ~= runtime.Appearance.RespawnGeneration then return end

            if rerun or not ready then
                task.delay(0.03, function()
                    if runtime.Alive and char == player.Character and char.Parent then
                        queueEnsure()
                    end
                end)
            end

            queueCloneRefresh()
        end)
    end

    table_insert(runtime.Appearance.AccessoryGuardConnections, char.ChildRemoved:Connect(function(child)
        if not child:IsA("Accoutrement") then return end
        local key = child:GetAttribute("iLunXAppearanceKey")
        if not key or runtime.Appearance.AccessoryGuardMutating[key] then return end
        if runtime.Appearance.Enabled[key] then
            runtime.Appearance.ActiveAccessories[key] = nil
            runtime.Appearance.AccessoryWeld[child] = nil
            queueEnsure()
        end
    end))

    -- Si Roblox/DUELS rompe sólo el AccessoryWeld sin quitar el Accessory completo,
    -- ChildRemoved no se dispara para el limited. Vigilamos también esa topología.
    table_insert(runtime.Appearance.AccessoryGuardConnections, char.DescendantRemoving:Connect(function(obj)
        if not hasEnabledAppearanceAccessory() then return end

        local acc = obj:IsA("Accoutrement") and obj or obj:FindFirstAncestorWhichIsA("Accoutrement")
        if acc then
            local key = acc:GetAttribute("iLunXAppearanceKey")
            if key and runtime.Appearance.Enabled[key] and not runtime.Appearance.AccessoryGuardMutating[key] then
                if obj:IsA("Weld") or obj:IsA("WeldConstraint") or obj:IsA("Motor6D")
                    or obj:IsA("Attachment") or obj:IsA("BasePart") then
                    runtime.Appearance.AccessoryWeld[acc] = nil
                    runtime.Appearance.AccessoryBaseWeld[acc] = nil
                    queueEnsure()
                end
            end
            return
        end

        -- Un body part/attachment destino también puede ser reemplazado sin quitar el
        -- limited. La pasada posterior detectará que Weld.Part1 ya no es la pieza actual.
        if obj:IsA("Attachment")
            or (obj:IsA("BasePart") and (obj.Name == "Head"
                or obj.Name == "UpperTorso" or obj.Name == "Torso"
                or obj.Name == "RightUpperLeg" or obj.Name == "LeftUpperLeg")) then
            runtime.Appearance.AttachmentCache[char] = nil
            queueEnsure()
        end
    end))

    -- Algunos juegos insertan Head/attachments por etapas. En cuanto aparece un
    -- attachment corporal nuevo hacemos una comprobación coalescida.
    table_insert(runtime.Appearance.AccessoryGuardConnections, char.DescendantAdded:Connect(function(obj)
        if obj:IsA("Attachment") and hasEnabledAppearanceAccessory() then
            local cache = runtime.Appearance.AttachmentCache[char]
            -- Sólo attachments de body parts directos del Character. Nunca el attachment
            -- interno de un limited recién parentado (eso causaba self-welds aleatorios).
            if cache and isAppearanceBodyAttachment(char, obj) then
                cache[obj.Name] = obj
            end
            queueEnsure()
        elseif obj:IsA("BasePart")
            and (obj.Name == "Head"
                or obj.Name == "UpperTorso"
                or obj.Name == "Torso"
                or obj.Name == "RightUpperLeg"
                or obj.Name == "RightLowerLeg"
                or obj.Name == "RightFoot") then
            runtime.Appearance.AttachmentCache[char] = nil
            queueEnsure()
        end
    end))
end

function runtime.AvatarCloneRigReady(char, humanoid)
    if not char or not humanoid then return false end

    local requiredParts
    if humanoid.RigType == Enum.HumanoidRigType.R15 then
        requiredParts = {
            "HumanoidRootPart", "LowerTorso", "UpperTorso", "Head",
            "LeftUpperArm", "LeftLowerArm", "LeftHand",
            "RightUpperArm", "RightLowerArm", "RightHand",
            "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
            "RightUpperLeg", "RightLowerLeg", "RightFoot",
        }
    else
        requiredParts = {
            "HumanoidRootPart", "Torso", "Head",
            "Left Arm", "Right Arm", "Left Leg", "Right Leg",
        }
    end

    for i = 1, #requiredParts do
        local part = char:FindFirstChild(requiredParts[i])
        if not part or not part:IsA("BasePart") then
            return false
        end
    end

    return true
end

function runtime.WaitForAvatarCloneRigReady(char, humanoid, generation, maxWait)
    local deadline = os.clock() + (tonumber(maxWait) or 1.5)

    repeat
        if not runtime.Alive
            or not char
            or not char.Parent
            or player.Character ~= char
            or (generation and generation ~= runtime.Appearance.RespawnGeneration) then
            return false
        end

        if runtime.AvatarCloneRigReady(char, humanoid) then
            return true
        end

        RunService.Heartbeat:Wait()
    until os.clock() >= deadline

    return runtime.AvatarCloneRigReady(char, humanoid)
end

-- Espera la salida real de la fase de spawn/teleport de Duels.
-- No modifica el Character: sólo observa que el mismo root permanezca válido y
-- estable durante varios frames antes de construir/reconstruir el overlay.
function runtime.WaitForAvatarCloneSpawnStable(char, humanoid, generation, maxWait)
    local deadline = os.clock() + (tonumber(maxWait) or 6)
    local startedAt = os.clock()
    local stableFrames = 0
    local lastRoot = nil
    local lastPosition = nil

    while runtime.Alive and os.clock() < deadline do
        if not char or not char.Parent or player.Character ~= char
            or (generation and generation ~= runtime.Appearance.RespawnGeneration) then
            return false
        end

        humanoid = humanoid or char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then
            stableFrames = 0
            RunService.Heartbeat:Wait()
            continue
        end

        local stateType = humanoid:GetState()
        local blockedState =
            stateType == Enum.HumanoidStateType.Dead
            or stateType == Enum.HumanoidStateType.PlatformStanding
            or stateType == Enum.HumanoidStateType.Physics
            or stateType == Enum.HumanoidStateType.FallingDown

        -- Duels deja al jugador suspendido unos segundos antes de soltar la ronda.
        -- Mientras siga anclado, en un estado físico bloqueado o todavía flotando
        -- dentro de esa ventana inicial, NO hacemos el bind definitivo. La máscara
        -- anclada sigue visible sin participar en la física.
        local elapsed = os.clock() - startedAt
        local airborneSpawnWindow =
            humanoid.FloorMaterial == Enum.Material.Air
            and elapsed < 4.5

        local sameRoot = lastRoot == nil or lastRoot == root
        local teleported = false
        if lastPosition and sameRoot then
            teleported = (root.Position - lastPosition).Magnitude > 10
        end

        if root.Anchored or blockedState or airborneSpawnWindow or not sameRoot or teleported then
            stableFrames = 0
        else
            stableFrames = stableFrames + 1
            if stableFrames >= 6 then
                return true
            end
        end

        lastRoot = root
        lastPosition = root.Position
        RunService.Heartbeat:Wait()
    end

    return false
end

function runtime.AvatarCloneIsBoundToCharacter(char)
    local state = runtime.Appearance.AvatarClone
    if not state or not char or state.BaseCharacter ~= char then return false end
    local overlay = state.Overlay
    if not overlay or not overlay.Parent then return false end

    local connectionAlive = false
    if state.AnimationConnection then
        pcall(function()
            connectionAlive = state.AnimationConnection.Connected == true
        end)
    end
    if not connectionAlive or #state.MotorPairs == 0 then return false end

    -- El juego de Duels puede reconstruir piezas del MISMO Character al terminar
    -- el freeze de inicio de ronda. En ese caso RenderStepped sigue conectado,
    -- pero MotorPairs apunta a las piezas viejas y el clon se queda congelado.
    -- Verificamos que cada referencia siga siendo la pieza actual del Character.
    for i = 1, #state.MotorPairs do
        local pair = state.MotorPairs[i]
        local realParent = pair.RealParent
        local realChild = pair.RealChild
        local cloneParent = pair.CloneParent
        local cloneChild = pair.CloneChild

        if not realParent or not realChild or not cloneParent or not cloneChild
            or not realParent.Parent or not realChild.Parent
            or not cloneParent.Parent or not cloneChild.Parent
            or realParent ~= char:FindFirstChild(realParent.Name)
            or realChild ~= char:FindFirstChild(realChild.Name)
            or not cloneParent:IsDescendantOf(overlay)
            or not cloneChild:IsDescendantOf(overlay) then
            return false
        end
    end

    return true
end

function runtime.GuardAvatarCloneAfterRespawn(char, generation)
    -- Primero dejamos que Duels termine SU spawn. Antes este guard podía intentar
    -- reconstruir el overlay cada 0.35 s mientras el jugador seguía suspendido.
    -- Eso hacía coincidir la recreación del rig visual con el teleport/release de
    -- ronda. Ahora no hay ningún apply hasta que el root lleve varios frames estable.
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = char and char:WaitForChild("Humanoid", 1)
    end
    if not humanoid then return end

    if not runtime.WaitForAvatarCloneSpawnStable(char, humanoid, generation, 7) then
        return
    end

    local deadline = os.clock() + 6
    local nextRetryAt = 0

    while runtime.Alive
        and char
        and char.Parent
        and player.Character == char
        and (not generation or generation == runtime.Appearance.RespawnGeneration)
        and os.clock() < deadline do

        local state = runtime.Appearance.AvatarClone
        if not state.Active or not state.KeepOnRespawn or not state.Template then
            return
        end

        if not runtime.AvatarCloneIsBoundToCharacter(char)
            and not state.Applying
            and os.clock() >= nextRetryAt then

            nextRetryAt = os.clock() + 0.45

            -- Si Duels reemplazó una pieza del rig incluso después de soltar la
            -- ronda, exigimos otra mini ventana estable antes del rebind.
            if runtime.WaitForAvatarCloneRigReady(char, humanoid, generation, 0.8)
                and runtime.WaitForAvatarCloneSpawnStable(char, humanoid, generation, 1.2) then

                -- Conservamos la máscara hasta que el nuevo overlay esté listo.
                local ok = runtime.ApplyAvatarCloneTemplate(char, state.Template)
                if not ok then
                    runtime.AvatarCloneRestoreBase(char)
                    runtime.ReapplyAppearanceLayers(char)
                end
            end
        end

        task.wait(0.18)
    end
end

function runtime.FastRestoreAppearanceOnRespawn(char, generation)
    if not runtime.Alive or not char or not char.Parent then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = char:WaitForChild("Humanoid", 0.35)
    end
    if not runtime.Alive or not humanoid or not char.Parent then return end
    if generation and generation ~= runtime.Appearance.RespawnGeneration then return end

    if runtime.Appearance.Enabled.Headless or runtime.GetActiveFaceKey() or hasEnabledAppearanceAccessory() then
        if not char:FindFirstChild("Head") then
            char:WaitForChild("Head", 0.35)
        end
    end
    if runtime.Appearance.Enabled.Korblox and humanoid.RigType == Enum.HumanoidRigType.R15 then
        if not char:FindFirstChild("RightUpperLeg") then
            char:WaitForChild("RightUpperLeg", 0.35)
        end
    end

    if not runtime.Alive or not char.Parent then return end
    if generation and generation ~= runtime.Appearance.RespawnGeneration then return end

    -- XERO_FAST_LIMITEDS_RESPAWN:
    -- Los limiteds de Xero llevan iLunXAppearanceKey y AvatarCloneHideBase los excluye
    -- expresamente del ocultado. Por eso no necesitan esperar los 4.5-7 s usados para
    -- estabilizar el overlay del clon. Los reaplicamos en cuanto existen Head/attachments;
    -- el apply definitivo del clon podrá repetir esta pasada después como protección.
    runtime.ReapplyAppearanceLayers(char)
    runtime.FastEnsureAppearanceAccessories(char, generation, 0.9)

    local cloneState = runtime.Appearance.AvatarClone
    if cloneState.Active
        and cloneState.KeepOnRespawn
        and cloneState.Template then

        -- Durante el freeze de inicio NO mostramos el Character real. Una máscara
        -- visual 100% anclada sigue al root desde el primer frame, mientras el apply
        -- definitivo espera a que el rig/teleport de Duels estén estables.
        runtime.BeginAvatarCloneRespawnMask(char, generation)

        if not runtime.WaitForAvatarCloneRigReady(char, humanoid, generation, 1.8) then
            return
        end
        if not runtime.WaitForAvatarCloneSpawnStable(char, humanoid, generation, 7) then
            return
        end
    end

    if cloneState.Active
        and cloneState.KeepOnRespawn
        and cloneState.Template
        and not cloneState.Applying then

        local ok = runtime.ApplyAvatarCloneTemplate(char, cloneState.Template)
        if not ok then
            runtime.AvatarCloneRestoreBase(char)
            runtime.ReapplyAppearanceLayers(char)
        end
        if generation and generation ~= runtime.Appearance.RespawnGeneration then return end
    end
end

function runtime.SetAppearance(key, state)
    local asset = runtime.AppearanceCatalog[key]
    if not asset then return end
    runtime.Appearance.Enabled[key] = state == true
    local char = player.Character

    if asset.Kind == "Headless" then
    runtime.ApplyHeadlessLayer(char)
    runtime.EnforceBodyAppearance(char)
    runtime.RebuildAppearanceBodyGuards(char)

    elseif asset.Kind == "Korblox" then
        runtime.ApplyKorbloxLayer(char)
        runtime.EnforceBodyAppearance(char)
        runtime.RebuildAppearanceBodyGuards(char)

    elseif asset.Kind == "HairToggle" then
        runtime.ApplyHairRemoval(char)

    elseif asset.Kind == "Face" then
        if state then
            runtime.DisableOtherFaceToggles(key)
        end
        local ok = runtime.ApplyFaceLayer(char)
        runtime.EnforceBodyAppearance(char)
        runtime.RebuildAppearanceBodyGuards(char)
        if state and not ok then
            showBottomMessage("No se pudo cargar la textura de " .. asset.Name .. ".")
            runtime.Appearance.Enabled[key] = false
            local toggle = runtime.Appearance.ToggleElements[key]
            if toggle then task.defer(function() pcall(function() toggle:Set(false) end) end) end
        end

    else
        local ok = runtime.ApplyAppearanceAccessory(key, char)
        if state and not ok then
            showBottomMessage("No se pudo cargar " .. asset.Name .. ".")
            runtime.Appearance.Enabled[key] = false
            local toggle = runtime.Appearance.ToggleElements[key]
            if toggle then task.defer(function() pcall(function() toggle:Set(false) end) end) end
        end
    end

    local cloneState = runtime.Appearance.AvatarClone
    if cloneState and cloneState.Active and cloneState.Overlay and cloneState.Overlay.Parent then
        runtime.AvatarCloneHideBase(char)
        runtime.UpdateAvatarCloneLayers()
    end

    if not runtime.Appearance.BatchLoading and runtime.RefreshAppearanceEditor then runtime.RefreshAppearanceEditor() end
    if runtime.RefreshAppearanceStudio then
        task.defer(runtime.RefreshAppearanceStudio)
    end
    if runtime.MarkAvatarThumbnailSpoofDirty then
        runtime.MarkAvatarThumbnailSpoofDirty()
    end
end

function runtime.RestoreAppearance()
    for key in pairs(runtime.Appearance.Enabled) do runtime.Appearance.Enabled[key] = false end

    local cloneState = runtime.Appearance.AvatarClone
    if cloneState and cloneState.Active and runtime.RestoreAvatarClone then
        pcall(function() runtime.RestoreAvatarClone(true) end)
    end

    local char = player.Character
    if char then
        for _, key in ipairs(runtime.AppearanceOrder) do
            local asset = runtime.AppearanceCatalog[key]
            if asset and asset.Kind == "Accessory" then runtime.RemoveAppearanceAccessory(key, char) end
        end
        runtime.ApplyFaceLayer(char)
        runtime.ApplyHeadlessLayer(char)
        runtime.ApplyKorbloxLayer(char)
        runtime.ApplyHairRemoval(char)
    end
    runtime.ClearAppearanceBodyGuards()
    for model in pairs(runtime.Appearance.FaceClassicVisuals) do
        runtime.DestroyFaceClassicVisual(model)
    end
    if runtime.Appearance.FaceVisualContainer and runtime.Appearance.FaceVisualContainer.Parent then
        pcall(function() runtime.Appearance.FaceVisualContainer:Destroy() end)
    end
    runtime.Appearance.FaceVisualContainer = nil
    runtime.Appearance.HeadBaseVisuals = setmetatable({}, {__mode = "k"})
    runtime.Appearance.OriginalHead = setmetatable({}, {__mode = "k"})
    runtime.Appearance.OriginalFace = setmetatable({}, {__mode = "k"})
    table.clear(runtime.Appearance.AccessoryOffsets)
    table.clear(runtime.Appearance.ActiveAccessories)
    runtime.Appearance.EditorSelectedKey = nil
    if runtime.RefreshAppearanceStudio then
        task.defer(runtime.RefreshAppearanceStudio)
    end
    if runtime.MarkAvatarThumbnailSpoofDirty then
        runtime.MarkAvatarThumbnailSpoofDirty()
    end
end

function runtime.SerializeAppearanceConfig()
    local enabled = {}
    for key, state in pairs(runtime.Appearance.Enabled) do enabled[key] = state == true end
    local offsets = {}
    for key, state in pairs(runtime.Appearance.AccessoryOffsets) do
        offsets[key] = {
            X = state.Position.X, Y = state.Position.Y, Z = state.Position.Z,
            RX = state.Rotation.X, RY = state.Rotation.Y, RZ = state.Rotation.Z,
            Scale = tonumber(state.Scale) or 1,
        }
    end
    return {
        Enabled = enabled,
        Offsets = offsets,
        -- compatibilidad con configs anteriores
        Korblox = enabled.Korblox,
        RC = enabled.RC,
        Fiery = enabled.Fiery,
        Poisoned = enabled.Poisoned,
    }
end

function runtime.LoadAppearanceConfig(data)
    if type(data) ~= "table" then return end
    table.clear(runtime.Appearance.AccessoryOffsets)
    if type(data.Offsets) == "table" then
        for key, value in pairs(data.Offsets) do
            if type(value) == "table" and runtime.AppearanceCatalog[key] then
                runtime.Appearance.AccessoryOffsets[key] = {
                    Position = Vector3.new(tonumber(value.X) or 0, tonumber(value.Y) or 0, tonumber(value.Z) or 0),
                    Rotation = Vector3.new(tonumber(value.RX) or 0, tonumber(value.RY) or 0, tonumber(value.RZ) or 0),
                    Scale = math.clamp(tonumber(value.Scale) or 1, 0.25, 3),
                }
            end
        end
    end

    local desired = {}
    if type(data.Enabled) == "table" then
        for key in pairs(runtime.AppearanceCatalog) do desired[key] = data.Enabled[key] == true end
    else
        for key in pairs(runtime.AppearanceCatalog) do desired[key] = false end
        desired.Korblox = data.Korblox == true
        desired.RC = data.RC == true
        desired.Fiery = data.Fiery == true
        desired.Poisoned = data.Poisoned == true
    end

    local wasSuppressed = runtime.SuppressNotifications
    runtime.SuppressNotifications = true
    runtime.Appearance.BatchLoading = true
    for _, key in ipairs(runtime.AppearanceOrder) do
        local wanted = desired[key] == true
        local current = runtime.Appearance.Enabled[key] == true
        if current ~= wanted then
            local toggle = runtime.Appearance.ToggleElements[key]
            if toggle then
                pcall(function() toggle:Set(wanted) end)
            else
                runtime.SetAppearance(key, wanted)
            end
        elseif wanted then
            -- Mismo toggle, nuevos offsets: actualiza sin destruir/reclonar el accesorio.
            local asset = runtime.AppearanceCatalog[key]
            if asset and asset.Kind == "Accessory" then
                runtime.ApplyAppearanceOffset(key, nil, true)
            elseif asset and asset.Kind == "HairToggle" then
                runtime.ApplyHairRemoval(player.Character)
            else
                runtime.EnforceBodyAppearance(player.Character)
            end
        end
    end
    runtime.Appearance.BatchLoading = false
    runtime.SuppressNotifications = wasSuppressed

    if runtime.RefreshAppearanceEditor then runtime.RefreshAppearanceEditor() end
    if runtime.MarkAvatarThumbnailSpoofDirty then
        runtime.MarkAvatarThumbnailSpoofDirty()
    end
end

runtime.AppearanceCleanup = function()
    pcall(runtime.RestoreAppearance)
    runtime.ClearAppearanceBodyGuards()
    runtime.ClearAppearanceAccessoryGuard()

    local cloneState = runtime.Appearance.AvatarClone
    if cloneState then
        pcall(function() runtime.AvatarCloneDestroyOverlay(true) end)
        if cloneState.Template then
            pcall(function() cloneState.Template:Destroy() end)
            cloneState.Template = nil
        end
        cloneState.Active = false
        cloneState.TargetUserId = nil
        cloneState.TargetName = nil

        if cloneState.VisualContainer and cloneState.VisualContainer.Parent then
            pcall(function() cloneState.VisualContainer:Destroy() end)
        end
        cloneState.VisualContainer = nil
    end

    for key, template in pairs(runtime.Appearance.Templates) do
        pcall(function() template:Destroy() end)
        runtime.Appearance.Templates[key] = nil
    end
end

runtime.Track(player.CharacterAdded:Connect(function(char)
    runtime.Appearance.RespawnGeneration = (runtime.Appearance.RespawnGeneration or 0) + 1
    local generation = runtime.Appearance.RespawnGeneration
    runtime.Appearance.AttachmentCache[char] = nil
    table.clear(runtime.Appearance.ActiveAccessories)

    local cloneState = runtime.Appearance.AvatarClone
    runtime.AvatarCloneResetForRespawn(char, generation)
    if cloneState.Active and not cloneState.KeepOnRespawn then
        cloneState.Active = false
        cloneState.TargetUserId = nil
        cloneState.TargetName = nil
        if cloneState.Template then
            pcall(function() cloneState.Template:Destroy() end)
            cloneState.Template = nil
        end
    end

    -- El guard entra desde el primer frame: si Roblox limpia un limited mientras
    -- termina de construir el avatar, se repone sin esperar un timer fijo.
    runtime.BindAppearanceAccessoryGuard(char, generation)

    task.spawn(function()
        runtime.FastRestoreAppearanceOnRespawn(char, generation)

        -- El primer apply puede coincidir con el freeze/teleport de inicio de ronda.
        -- La guardia de 10 s corrige cualquier reconstrucción tardía sin que el
        -- usuario tenga que pulsar "Clonar" de nuevo.
        runtime.GuardAvatarCloneAfterRespawn(char, generation)
    end)
end))

pcall(function()
    runtime.Track(player.CharacterAppearanceLoaded:Connect(function(char)
        if char ~= player.Character then return end
        local generation = runtime.Appearance.RespawnGeneration
        runtime.Appearance.AttachmentCache[char] = nil

        task.defer(function()
            if runtime.Alive and char.Parent and generation == runtime.Appearance.RespawnGeneration then
                -- CharacterAppearanceLoaded puede reemplazar attachments aunque el limited
                -- ya hubiera aparecido en CharacterAdded. Revalidamos sólo sus welds.
                runtime.FastEnsureAppearanceAccessories(char, generation, 0.45)
                local cloneState = runtime.Appearance.AvatarClone
                if cloneState.Active
                    and cloneState.KeepOnRespawn
                    and cloneState.Template
                    and not cloneState.Applying then

                    -- El overlay NO es hijo del Character; vive en
                    -- iLunX_LocalAvatarClones. La comprobación anterior contra
                    -- Overlay.Parent == char siempre daba false y provocaba un
                    -- segundo apply innecesario justo cuando terminaba el respawn.
                    if runtime.AvatarCloneIsBoundToCharacter(char) then
                        runtime.ReapplyAppearanceLayers(char)
                        runtime.AvatarCloneHideBase(char)
                        runtime.UpdateAvatarCloneLayers()
                    else
                        -- CharacterAppearanceLoaded puede disparar DURANTE el countdown.
                        -- Conservamos/recreamos la máscara visual; el guard espera el
                        -- estado físico estable para hacer el bind definitivo.
                        runtime.BeginAvatarCloneRespawnMask(char, generation)
                        task.spawn(function()
                            runtime.GuardAvatarCloneAfterRespawn(char, generation)
                        end)
                    end
                else
                    runtime.ReapplyAppearanceLayers(char)
                end
            end
        end)
    end))
end)

-- También protege el Character que ya existía cuando se ejecutó el hub.
if player.Character and player.Character.Parent then
    runtime.BindAppearanceAccessoryGuard(player.Character, runtime.Appearance.RespawnGeneration)
end

-- =========================
-- UI DE APARIENCIA
-- =========================
-- LayoutOrder explícito permite crear los sliders de forma LAZY y colocarlos
-- debajo de su limited aunque se creen mucho después de arrancar el hub.
local appearanceLayoutOrder = 100

local function placeAppearanceElement(element, order)
    if element and element.ElementFrame then
        element.ElementFrame.LayoutOrder = order
    end
    return element
end

local function nextAppearanceOrder(step)
    local current = appearanceLayoutOrder
    appearanceLayoutOrder = appearanceLayoutOrder + (step or 10)
    return current
end

aimHookState = runtimeEnv.__ILUNX_AIM_HOOK_STATE
if not aimHookState then
    aimHookState = {Target = nil, Mouse = mouse, Owner = runtime}
    runtimeEnv.__ILUNX_AIM_HOOK_STATE = aimHookState

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local target = aimHookState.Target
        if not checkcaller() and target then
            -- 🔥 FIX: Quitamos IsDescendantOf, que era lo que crasheaba el juego
            if target.Parent then 
                local method = getnamecallmethod()
                if self == workspace then
                    if method == "Raycast" then
                        local origin, direction, p3 = ...
                        if typeof(direction) == "Vector3" and direction.Magnitude > 5 and (origin - workspace.CurrentCamera.CFrame.Position).Magnitude > 1 then
                            local newDir = (target.Position - origin).Unit * 5000
                            return oldNamecall(self, origin, newDir, p3)
                        end
                    elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" then
                        local ray, p2, p3, p4 = ...
                        if typeof(ray) == "Ray" and ray.Direction.Magnitude > 5 and (ray.Origin - workspace.CurrentCamera.CFrame.Position).Magnitude > 1 then
                            local newRay = Ray.new(ray.Origin, (target.Position - ray.Origin).Unit * 5000)
                            return oldNamecall(self, newRay, p2, p3, p4)
                        end
                    end
                end
            else
                aimHookState.Target = nil
            end
        end
        return oldNamecall(self, ...)
    end)

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(t, k)
        local target = aimHookState.Target
        if not checkcaller() and t == aimHookState.Mouse and target and target.Parent then
            if k == "Hit" or k == "hit" then return target.CFrame
            elseif k == "Target" or k == "target" then return target end
        end
        return oldIndex(t, k)
    end)
else
    aimHookState.Target = nil
    aimHookState.Mouse = mouse
    aimHookState.Owner = runtime
end

runtime.AimState = aimHookState

-- ==========================================
-- MEMORIA DEL ESP (OBLIGATORIO ANTES DEL HILO)
-- ==========================================
activeESPs = {} 
MAX_ESP_DISTANCE = 1500 

function cleanESP(targetPlayer)
    if activeESPs[targetPlayer] then
        if activeESPs[targetPlayer].Highlight then activeESPs[targetPlayer].Highlight:Destroy() end
        if activeESPs[targetPlayer].Billboard then activeESPs[targetPlayer].Billboard:Destroy() end
        activeESPs[targetPlayer] = nil
    end
end

function hideESP(targetPlayer)
    local espObj = activeESPs[targetPlayer]
    if not espObj then return end
    if espObj.Highlight and espObj.Highlight.Enabled then espObj.Highlight.Enabled = false end
    if espObj.Billboard and espObj.Billboard.Enabled then espObj.Billboard.Enabled = false end
    -- Fuerza una sola reconstrucción de texto al volver a ser válido, sin destruir Instances.
    espObj.LastDistance = -1
end


-- ==========================================
-- 🚀 HILO MAESTRO DE OPTIMIZACIÓN (CERO LAG)
-- ==========================================

-- Agrupamos todo en UNA SOLA tabla para no rebasar el límite de 200 locales de Lua
mState = {
    tHB = 0, tESP = 0, tAS = 0, tSA = 0,
    hbAct = false, espAct = false, asAct = false, saAct = false,
    espHex = "#FFFFFF", lastEspColor = espColor,
    pHB = RaycastParams.new(),
    pAS = RaycastParams.new(),
    pSA = RaycastParams.new(),
    igHB = {},
    igAS = {}, scAS = {}, seenAS = {},
    igSA = {}, scSA = {}, seenSA = {},
    hbBlockedColor = Color3_fromRGB(255, 50, 50),
    hbByChar = setmetatable({}, {__mode = "k"}),
    hbAdornment = setmetatable({}, {__mode = "k"}),
    charCore = setmetatable({}, {__mode = "k"}),
    vpX = -1, vpY = -1, centerX = 0, centerY = 0,
    maxEspDistanceSq = MAX_ESP_DISTANCE * MAX_ESP_DISTANCE,
}
mState.pHB.FilterType = Enum.RaycastFilterType.Exclude
mState.pAS.FilterType = Enum.RaycastFilterType.Exclude
mState.pSA.FilterType = Enum.RaycastFilterType.Exclude

function getCharCore(char)
    if not char then return nil end
    local core = mState.charCore[char]
    if core and core.Humanoid and core.Humanoid.Parent == char and core.HRP and core.HRP.Parent == char then
        if not core.Head or core.Head.Parent ~= char then core.Head = ffc(char, "Head") end
        if not core.LeftFoot or core.LeftFoot.Parent ~= char then core.LeftFoot = ffc(char, "LeftFoot") or ffc(char, "LeftLeg") end
        if not core.RightFoot or core.RightFoot.Parent ~= char then core.RightFoot = ffc(char, "RightFoot") or ffc(char, "RightLeg") end
        return core
    end
    core = {
        Humanoid = ffc(char, "Humanoid") or char:FindFirstChildOfClass("Humanoid"),
        HRP = ffc(char, "HumanoidRootPart"),
        Head = ffc(char, "Head"),
        LeftFoot = ffc(char, "LeftFoot") or ffc(char, "LeftLeg"),
        RightFoot = ffc(char, "RightFoot") or ffc(char, "RightLeg"),
    }
    mState.charCore[char] = core
    return core
end

function enemigoEnLobby(enemyChar, enemyHrp)
    if enemyChar:FindFirstChildOfClass("ForceField") then return true end
    local core = enemyHrp and nil or getCharCore(enemyChar)
    local eHrp = enemyHrp or (core and core.HRP)
    if eHrp then
        for _, zona in ipairs(ZONAS_SEGURAS) do
            local delta = eHrp.Position - zona.Centro
            if delta:Dot(delta) <= zona.RadioSq then return true end
        end
    end
    return false
end


-- Variables en caché fuera del Heartbeat
enLobby = false
timerLobby = 0

runtime.Track(RunService.Heartbeat:Connect(function(deltaTime)
    -- XERO_PERF_IDLE_HEARTBEAT: con las cuatro familias apagadas no hacemos
    -- cámara, lobby, jugadores ni raycasts. Si alguna quedó activa, permitimos
    -- un último frame para ejecutar su limpieza normal.
    local masterFeatureActive = hitboxEnabled or espEnabled
        or autoShootEnabled or autoShootCuchilloEnabled
        or silentAimPistolaEnabled or silentAimCuchilloEnabled
    local masterNeedsCleanup = mState.hbAct or mState.espAct or mState.asAct or mState.saAct
    if not masterFeatureActive and not masterNeedsCleanup then
        mState.tHB, mState.tESP, mState.tAS, mState.tSA = 0, 0, 0, 0
        timerLobby = 1 -- al volver a activar, refresca lobby inmediatamente
        return
    end

    local camera = workspace.CurrentCamera -- 🔥 FIX: Siempre la cámara actual
    timerLobby = timerLobby + deltaTime
    if timerLobby >= 1 then
        timerLobby = 0
        pcall(function() enLobby = estaEnLobby() end)
    end

    -- ==========================================
    -- 1. HITBOX (0.15s) - FIX VISUAL + WELD
    -- ==========================================
    if hitboxEnabled then
        mState.hbAct = true
        mState.tHB = mState.tHB + deltaTime
        if mState.tHB >= 0.15 then
            mState.tHB = 0
            if not enLobby then
                local myChar = player.Character
                local myHead = myChar and myChar:FindFirstChild("Head")
                local origin = camera.CFrame.Position 
                local targetSize = Vector3_new(hitboxSize, hitboxSize, hitboxSize)
                mState.igHB[1] = myChar
                
                for i = 1, #listaJugadores do
                    local v = listaJugadores[i]
                    local targetChar = v ~= player and v.Character or nil
                    local targetCore = targetChar and getCharCore(targetChar) or nil
                    local hrp = targetCore and targetCore.HRP
                    local targetHum = targetCore and targetCore.Humanoid
                    
                    if hrp and targetHum and targetHum.Health > 0 and isEnemy(v) then
                        -- 1. BUSCAMOS O CREAMOS EL BLOQUE FALSO
                        local fakeHitbox = mState.hbByChar[targetChar]
                        if not (fakeHitbox and fakeHitbox.Parent == targetChar) then
                            fakeHitbox = nil
                            for _, child in ipairs(targetChar:GetChildren()) do
                                if child:GetAttribute("EsAstraHitbox") then
                                    fakeHitbox = child
                                    break
                                end
                            end
                            mState.hbByChar[targetChar] = fakeHitbox
                        end

                        if not fakeHitbox then
                            fakeHitbox = Instance.new("Part")
                            fakeHitbox.Name = "Torso" -- 🔥 EL TRUCO: El juego lo acepta como cuerpo válido y el cuchillo NO rebota
                            fakeHitbox:SetAttribute("EsAstraHitbox", true)
                            fakeHitbox.Shape = Enum.PartType.Block
                            fakeHitbox.Size = targetSize
                            fakeHitbox.CFrame = hrp.CFrame 
                            fakeHitbox.Massless = true
                            fakeHitbox.CanCollide = false
                            fakeHitbox.Anchored = false
                            fakeHitbox.Transparency = 1 
                            fakeHitbox.Parent = targetChar 
                            
                            local weld = Instance.new("WeldConstraint")
                            weld.Part0 = hrp
                            weld.Part1 = fakeHitbox
                            weld.Parent = fakeHitbox
                            
                            local box = Instance.new("BoxHandleAdornment") 
                            box.Name = "AstraHitboxBox" 
                            box.Adornee = fakeHitbox 
                            box.AlwaysOnTop = true 
                            box.ZIndex = 5 
                            box.Parent = fakeHitbox
                            mState.hbByChar[targetChar] = fakeHitbox
                            mState.hbAdornment[fakeHitbox] = box
                        end
                        
                        -- 2. ACTUALIZAMOS TAMAÑO FÍSICO
                        if fakeHitbox.Size ~= targetSize then fakeHitbox.Size = targetSize end
                        
                        -- 3. CÁLCULO DE VISIBILIDAD (Raycast)
                        local aLaVista = false
                        if myHead then
                            local rayDirection = hrp.Position - origin
                            if rayDirection:Dot(rayDirection) < 62500 then
                                mState.igHB[2] = targetChar
                                mState.pHB.FilterDescendantsInstances = mState.igHB
                                local result = ws_Raycast(workspace, origin, rayDirection, mState.pHB)
                                aLaVista = not result 
                            end
                        end
                        
                        -- 4. ACTUALIZAMOS LO VISUAL (Más transparente)
                        local targetColor = aLaVista and espColor or mState.hbBlockedColor
                        
                        -- Leemos el valor del slider (si por alguna razón es nil, usamos 0.6 de respaldo)
                        local currentTrans = hitboxTransparency or 0.6
                        local targetBoxTrans = hitboxInvisible and 1 or currentTrans
                        
                        local box = mState.hbAdornment[fakeHitbox]
                        if not (box and box.Parent == fakeHitbox) then
                            box = fakeHitbox:FindFirstChild("AstraHitboxBox")
                            mState.hbAdornment[fakeHitbox] = box
                        end
                        if box then
                            if box.Size ~= fakeHitbox.Size then box.Size = fakeHitbox.Size end
                            if box.Color3 ~= targetColor then box.Color3 = targetColor end
                            if box.Transparency ~= targetBoxTrans then box.Transparency = targetBoxTrans end
                            if box.Visible ~= not hitboxInvisible then box.Visible = not hitboxInvisible end
                        end -- 🔥 AQUÍ ESTÁ EL END QUE FALTABA
                    elseif targetChar then
                        -- Limpieza automática con caché; el escaneo queda sólo como fallback legacy.
                        local cachedHitbox = mState.hbByChar[targetChar]
                        if cachedHitbox and cachedHitbox.Parent then cachedHitbox:Destroy() end
                        mState.hbByChar[targetChar] = nil
                        if not cachedHitbox then
                            for _, child in ipairs(targetChar:GetChildren()) do
                                if child:GetAttribute("EsAstraHitbox") then child:Destroy() end
                            end
                        end
                    end
                end
            else
                -- 🔥 LIMPIEZA LOBBY: BORRAMOS LAS HITBOXES QUE QUEDARON PEGADAS
                for i = 1, #listaJugadores do
                    local v = listaJugadores[i]
                    if v ~= player and v.Character then
                        local cachedHitbox = mState.hbByChar[v.Character]
                        if cachedHitbox and cachedHitbox.Parent then cachedHitbox:Destroy() end
                        mState.hbByChar[v.Character] = nil
                        if not cachedHitbox then
                            for _, child in ipairs(v.Character:GetChildren()) do
                                if child:GetAttribute("EsAstraHitbox") then child:Destroy() end
                            end
                        end
                    end
                end
            end
        end
    elseif mState.hbAct then
        mState.hbAct = false
        mState.tHB = 0
        -- LIMPIEZA: Destruimos los bloques falsos cuando se apaga el Hitbox
        for i = 1, #listaJugadores do
            local v = listaJugadores[i]
            if v ~= player and v.Character then
                local cachedHitbox = mState.hbByChar[v.Character]
                if cachedHitbox and cachedHitbox.Parent then cachedHitbox:Destroy() end
                mState.hbByChar[v.Character] = nil
                if not cachedHitbox then
                    for _, child in ipairs(v.Character:GetChildren()) do
                        if child:GetAttribute("EsAstraHitbox") then child:Destroy() end
                    end
                end
                
                -- Limpieza por si quedó basura del script anterior
                local hrp = v.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local box = hrp:FindFirstChild("AstraHitboxBox")
                    if box then box:Destroy() end
                    hrp.Transparency = 1
                end
            end
        end
    end

    -- ==========================================
    -- 2. ESP (0.25s): 4 actualizaciones/s son suficientes para etiquetas.
    -- ==========================================
    if espEnabled then
        mState.espAct = true
        mState.tESP = mState.tESP + deltaTime
        if mState.tESP >= 0.25 then
            mState.tESP = 0
            if not enLobby then
                local myChar = player.Character
                local myCore = myChar and getCharCore(myChar) or nil
                local myPos = (myCore and myCore.Head and myCore.Head.Position) or nil

                if mState.lastEspColor ~= espColor then
                    mState.lastEspColor = espColor
                    mState.espHex = string.format(
                        "#%02X%02X%02X",
                        math_floor(espColor.R * 255 + 0.5),
                        math_floor(espColor.G * 255 + 0.5),
                        math_floor(espColor.B * 255 + 0.5)
                    )
                end

                for i = 1, #listaJugadores do
                    local p = listaJugadores[i]
                    if p ~= player then
                        local char = p.Character
                        local core = char and getCharCore(char) or nil
                        local targetHum = core and core.Humanoid
                        local targetHead = core and core.Head
                        if myPos and targetHum and targetHum.Health > 0 and targetHead and isEnemy(p) and not enemigoEnLobby(char, core.HRP) then
                            local delta = targetHead.Position - myPos
                            local distSq = delta:Dot(delta)
                            
                            if distSq <= mState.maxEspDistanceSq then
                                local dist = math.sqrt(distSq)
                                if activeESPs[p] and activeESPs[p].Char ~= char then cleanESP(p) end

                                -- Duels puede reconstruir Head/partes dentro del MISMO Character.
                                -- Si algún objeto del ESP fue destruido o quedó inválido, lo recreamos.
                                if activeESPs[p] then
                                    local cachedESP = activeESPs[p]
                                    if not cachedESP.Highlight or not cachedESP.Highlight.Parent
                                        or not cachedESP.Billboard or not cachedESP.Billboard.Parent
                                        or not cachedESP.Text or not cachedESP.Text.Parent then
                                        cleanESP(p)
                                    end
                                end
                                
                                if not activeESPs[p] then
                                    local highlight = Instance.new("Highlight") 
                                    highlight.Name = p.Name.."_Glow" 
                                    highlight.FillTransparency = 0.6
                                    highlight.OutlineTransparency = 1 
                                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop 
                                    highlight.Adornee = char 
                                    highlight.Parent = espFolder
                                    
                                    local billboard = Instance.new("BillboardGui") 
                                    billboard.Name = p.Name.."_Tag" 
                                    billboard.Size = UDim2.new(0, 200, 0, 50) 
                                    billboard.StudsOffset = Vector3.new(0, 3.5, 0) 
                                    billboard.AlwaysOnTop = true 
                                    billboard.Adornee = targetHead 
                                    billboard.Parent = espFolder
                                    
                                    local textLabel = Instance.new("TextLabel") 
                                    textLabel.Size = UDim2.new(1, 0, 1, 0) 
                                    textLabel.BackgroundTransparency = 1 
                                    textLabel.TextStrokeTransparency = 1 
                                    textLabel.RichText = true 
                                    textLabel.Font = Enum.Font.SourceSansBold 
                                    textLabel.TextSize = 14
                                    textLabel.TextYAlignment = Enum.TextYAlignment.Bottom 
                                    textLabel.Parent = billboard

                                    local stroke = Instance.new("UIStroke")
                                    stroke.Color = Color3.fromRGB(0, 0, 0)
                                    stroke.Thickness = 1.2
                                    stroke.Parent = textLabel
                                    
                                    activeESPs[p] = {
                                        Highlight = highlight,
                                        Billboard = billboard,
                                        Char = char,
                                        Text = textLabel,
                                        LastDistance = -1,
                                        LastNameEnabled = nil,
                                        LastDistanceEnabled = nil,
                                        LastHex = nil,
                                    }
                                end
                                
                                local espObj = activeESPs[p]
                                if espObj.Highlight.Enabled ~= espSettings.Glow then espObj.Highlight.Enabled = espSettings.Glow end
                                if espObj.Highlight.FillColor ~= espColor then espObj.Highlight.FillColor = espColor end

                                -- El Character puede seguir siendo el mismo aunque Duels reemplace la Head.
                                -- Reengancha el nombre a la cabeza ACTUAL sin destruir/recrear el ESP.
                                if espObj.Billboard.Adornee ~= targetHead then
                                    espObj.Billboard.Adornee = targetHead
                                    espObj.LastDistance = -1
                                end
                                
                                local distanceInt = math_floor(dist)
                                if espObj.LastDistance ~= distanceInt
                                    or espObj.LastNameEnabled ~= espSettings.Name
                                    or espObj.LastDistanceEnabled ~= espSettings.Distance
                                    or espObj.LastHex ~= mState.espHex then
                                    local infoText = ""
                                    if espSettings.Name then
                                        infoText = '<font color="' .. mState.espHex .. '">' .. p.Name .. '</font>'
                                    end
                                    if espSettings.Distance then
                                        infoText = infoText .. (infoText == "" and "" or "\n") .. '<font size="11" color="#bdc3c7">' .. distanceInt .. 'm</font>'
                                    end

                                    espObj.LastDistance = distanceInt
                                    espObj.LastNameEnabled = espSettings.Name
                                    espObj.LastDistanceEnabled = espSettings.Distance
                                    espObj.LastHex = mState.espHex

                                    if infoText ~= "" then
                                        if not espObj.Billboard.Enabled then espObj.Billboard.Enabled = true end
                                        espObj.Text.Text = infoText
                                    elseif espObj.Billboard.Enabled then
                                        espObj.Billboard.Enabled = false
                                    end
                                end
                            else hideESP(p) end
                        else hideESP(p) end
                    end
                end
            end
        end
    elseif mState.espAct then
        mState.espAct = false
        mState.tESP = 0
        for i = 1, #listaJugadores do hideESP(listaJugadores[i]) end
    end

    -- ==========================================
    -- 3. AUTO SHOOT (0.15s)
    -- ==========================================
    if autoShootEnabled or autoShootCuchilloEnabled then
        mState.asAct = true
        mState.tAS = mState.tAS + deltaTime
        if mState.tAS >= 0.15 then
            mState.tAS = 0
            if not enLobby then
                local char = player.Character
                local localCore = char and getCharCore(char) or nil
                local hrp = localCore and localCore.HRP
                if hrp then
                    local arma = char:FindFirstChildOfClass("Tool")
                    if arma and arma:FindFirstChild("Handle") then
                        local esGun = esLaPistola(arma)
                        if (esGun and autoShootEnabled) or (not esGun and autoShootCuchilloEnabled) then
                            local myPos = hrp.Position
                            local headPos = (localCore and localCore.Head and localCore.Head.Position) or myPos
                            
                            local closestTargetPart = nil
                            local closestTargetDistSq = math.huge
                            mState.igAS[1] = char

                            -- Seleccionar el visible más cercano no requiere crear N tablas,
                            -- ordenar N candidatos y reciclarlos: basta conservar el mejor.
                            for i = 1, #listaJugadores do
                                local p = listaJugadores[i]
                                local enemyChar = p ~= player and p.Character or nil
                                if enemyChar and isEnemy(p) then
                                    local enemyCore = getCharCore(enemyChar)
                                    local enemyHrp = enemyCore and enemyCore.HRP
                                    local enemyHum = enemyCore and enemyCore.Humanoid
                                    local enemyDelta = enemyHrp and (enemyHrp.Position - myPos) or nil
                                    if enemyHum and enemyHum.Health > 0 and enemyDelta and enemyDelta:Dot(enemyDelta) <= 640000 then
                                        runtime.CollectTargetParts(enemyChar, "AutoShoot", mState.scAS, mState.seenAS)
                                        for j = 1, #mState.scAS do
                                            local part = mState.scAS[j]
                                            local partDelta = part.Position - myPos
                                            local distSq = partDelta:Dot(partDelta)
                                            if distSq < closestTargetDistSq then
                                                mState.igAS[2] = enemyChar
                                                mState.pAS.FilterDescendantsInstances = mState.igAS
                                                if not ws_Raycast(workspace, headPos, part.Position - headPos, mState.pAS) then
                                                    closestTargetDistSq = distSq
                                                    closestTargetPart = part
                                                end
                                            end
                                        end
                                    end
                                end
                            end

                            if closestTargetPart then
                                aimHookState.Target = closestTargetPart
                                pcall(function() 
                                    arma:Activate() 
                                    task_delay(0.02, function() if arma.Parent == char then arma:Deactivate() end end)
                                end)
                            else
                                aimHookState.Target = nil
                            end
                        else aimHookState.Target = nil end
                    else aimHookState.Target = nil end
                else aimHookState.Target = nil end
            else aimHookState.Target = nil end
        end
    elseif mState.asAct then
        mState.asAct = false
        mState.tAS = 0
        aimHookState.Target = nil
    end

    -- ==========================================
    -- 4. SILENT AIM (0.03s · ~33 Hz)
    -- ==========================================
    if silentAimPistolaEnabled or silentAimCuchilloEnabled then
        mState.saAct = true
        mState.tSA = mState.tSA + deltaTime
        if mState.tSA >= 0.03 then
            mState.tSA = 0
            if not enLobby then
                local char = player.Character
                local localCore = char and getCharCore(char) or nil
                local hrp = localCore and localCore.HRP
                if hrp then
                    local arma = char:FindFirstChildOfClass("Tool")
                    local allowedWeapon = false
                    if arma then
                        local esGun = esLaPistola(arma)
                        if (esGun and silentAimPistolaEnabled) or (not esGun and silentAimCuchilloEnabled) then
                            allowedWeapon = true
                        end
                    end

                    if allowedWeapon then
                        local closestTargetPart = nil
                        local shortestDistToCenter = math.huge 
                        local shortestDistanceFisica = math.huge 
                        local myPos = hrp.Position
                        local headPos = (localCore and localCore.Head and localCore.Head.Position) or myPos
                        local viewport = camera.ViewportSize
                        if viewport.X ~= mState.vpX or viewport.Y ~= mState.vpY then
                            mState.vpX, mState.vpY = viewport.X, viewport.Y
                            mState.centerX, mState.centerY = viewport.X * 0.5, viewport.Y * 0.5
                        end
                        local centerX, centerY = mState.centerX, mState.centerY
                        local fovSq = fovRadius * fovRadius
                        local broadFov = fovRadius + 150
                        local broadFovSq = broadFov * broadFov
                        
                        mState.igSA[1] = char

                        for i = 1, #listaJugadores do 
                            local p = listaJugadores[i]
                            local enemyChar = p ~= player and p.Character or nil
                            if enemyChar and isEnemy(p) then
                                local enemyCore = getCharCore(enemyChar)
                                local enemyHum = enemyCore and enemyCore.Humanoid
                                local enemyHrp = enemyCore and enemyCore.HRP
                                local enemyDelta = enemyHrp and (enemyHrp.Position - myPos) or nil
                                if enemyHum and enemyHum.Health > 0 and enemyDelta and enemyDelta:Dot(enemyDelta) <= 640000 then
                                    if silentAimFovEnabled then
                                        local hrpPos2D, onScreen = camera:WorldToViewportPoint(enemyHrp.Position)
                                        local dx, dy = hrpPos2D.X - centerX, hrpPos2D.Y - centerY
                                        if not onScreen or (dx * dx + dy * dy) > broadFovSq then continue end
                                    end

                                    runtime.CollectTargetParts(enemyChar, "SilentAim", mState.scSA, mState.seenSA)

                                    mState.igSA[2] = enemyChar 
                                    mState.pSA.FilterDescendantsInstances = mState.igSA
                                    
                                    for j = 1, #mState.scSA do
                                        local part = mState.scSA[j]
                                        local pasaFiltro = false
                                        local candidateDistance = math.huge
                                        
                                        if silentAimFovEnabled then
                                            local hrpPos2D, onScreen = camera:WorldToViewportPoint(part.Position)
                                            if onScreen then
                                                -- Cambiamos pos2D por hrpPos2D
                                                local dx, dy = hrpPos2D.X - centerX, hrpPos2D.Y - centerY 
                                                candidateDistance = dx * dx + dy * dy
                                                if candidateDistance <= fovSq and candidateDistance < shortestDistToCenter then pasaFiltro = true end
                                            end
                                        else
                                            local partDelta = part.Position - myPos
                                            candidateDistance = partDelta:Dot(partDelta)
                                            if candidateDistance < shortestDistanceFisica then pasaFiltro = true end
                                        end
                                        
                                        if pasaFiltro and not ws_Raycast(workspace, headPos, part.Position - headPos, mState.pSA) then
                                            if silentAimFovEnabled then shortestDistToCenter = candidateDistance else shortestDistanceFisica = candidateDistance end
                                            closestTargetPart = part
                                        end
                                    end
                                end
                            end
                        end
                        if closestTargetPart then aimHookState.Target = closestTargetPart
                        elseif not autoShootEnabled and not autoShootCuchilloEnabled then aimHookState.Target = nil end
                    elseif not autoShootEnabled and not autoShootCuchilloEnabled then aimHookState.Target = nil end
                elseif not autoShootEnabled and not autoShootCuchilloEnabled then aimHookState.Target = nil end
            end
        end
    elseif mState.saAct then
        mState.saAct = false
        mState.tSA = 0
        if not autoShootEnabled and not autoShootCuchilloEnabled then aimHookState.Target = nil end
    end
end))

-- ================= INTERFAZ =================
UIElements.TogAutoShoot = Tabs.Aim:Toggle({
    Title = "Auto Shoot",
    Desc = "Dispara automáticamente a la parte del cuerpo seleccionada.",
    Value = false,
    Callback = function(Value)
        autoShootEnabled = Value
        showBottomMessage(Value and "Auto Shoot: ACTIVADO" or "Auto Shoot: DESACTIVADO")
         -- ENCIENDE/APAGA EL BUCLE
    end,
})

UIElements.TogAutoShootCuchillo = Tabs.Aim:Toggle({
    Title = "Auto Shoot (Cuchillo)",
    Desc = "Ataca o lanza el cuchillo automáticamente.",
    Value = false,
    Callback = function(Value)
        autoShootCuchilloEnabled = Value
       -- ENCIENDE/APAGA EL BUCLE
    end,
})

Tabs.Aim:Button({
    Title = "Selector corporal · Auto Shoot",
    Desc = "Abre una plantilla visual y permite seleccionar varias partes a la vez.",
    Callback = function() runtime.OpenBodySelector("AutoShoot") end,
})

UIElements.TogSilentAimPistola = Tabs.Aim:Toggle({
    Title = "Silent Aim (Pistola)",
    Desc = "Redirige las balas de tu pistola al enemigo.",
    Value = false,
    Callback = function(Value)
        silentAimPistolaEnabled = Value
        showBottomMessage(Value and "Silent Aim Pistola: ACTIVADO" or "Silent Aim Pistola: DESACTIVADO")
        -- ENCIENDE/APAGA EL BUCLE
    end,
})

UIElements.TogSilentAimCuchillo = Tabs.Aim:Toggle({
    Title = "Silent Aim (Cuchillo)",
    Desc = "Redirige los ataques de tu cuchillo al enemigo.",
    Value = false,
    Callback = function(Value)
        silentAimCuchilloEnabled = Value
        -- ENCIENDE/APAGA EL BUCLE
    end,
})



-- ==========================================
-- CONTROL / SOPORTE DE MANDO
-- ==========================================
Tabs.Aim:Section({Title = "🎮 Control"})

local function setControllerDeadZoneFilter(enabled)
    if enabled and not controllerDeadZoneBound then
        local ok = pcall(function()
            ContextActionService:BindActionAtPriority(
                controllerDeadZoneAction,
                function(_, inputState, inputObject)
                    if not controllerSupportEnabled then
                        return Enum.ContextActionResult.Pass
                    end
                    if inputObject and inputObject.KeyCode == Enum.KeyCode.Thumbstick2 then
                        local p = inputObject.Position
                        local magnitude = Vector2.new(p.X, p.Y).Magnitude
                        -- Sólo consume el pequeño movimiento que corresponde al drift.
                        if magnitude <= controllerDeadZone then
                            return Enum.ContextActionResult.Sink
                        end
                    end
                    return Enum.ContextActionResult.Pass
                end,
                false,
                4000,
                Enum.KeyCode.Thumbstick2
            )
        end)
        controllerDeadZoneBound = ok
    elseif not enabled and controllerDeadZoneBound then
        pcall(function() ContextActionService:UnbindAction(controllerDeadZoneAction) end)
        controllerDeadZoneBound = false
    end
end

UIElements.TogControllerSupport = Tabs.Aim:Toggle({
    Title = "Controller Support",
    Desc = "Activa el filtro del stick derecho y el soporte de mando.",
    Value = false,
    Callback = function(v)
        controllerSupportEnabled = v == true
        if controllerSupportEnabled then applyControllerCameraSensitivity() end
        setControllerDeadZoneFilter(controllerSupportEnabled)
        if not controllerSupportEnabled and controllerAimbotEnabled then
            controllerAimbotEnabled = false
            pcall(function() UIElements.TogControllerAimbot:Set(false) end)
            stopControllerAimbot()
        end
        markAutoConfigChanged()
    end
})

UIElements.SliControllerDeadZone = Tabs.Aim:Slider({
    Title = "Dead Zone del Stick",
    Desc = "0–50%. Ignora movimientos pequeños causados por drift.",
    Step = 1,
    Value = {Min = 0, Max = 50, Default = 20},
    Callback = function(v)
        controllerDeadZone = math.clamp((tonumber(v) or 20) / 100, 0, 0.50)
        if controllerSupportEnabled then setControllerDeadZoneFilter(true) end
        markAutoConfigChanged()
    end
})

UIElements.SliControllerSensitivity = Tabs.Aim:Slider({
    Title = "Sensibilidad del Stick",
    Desc = "Ajusta cuánto influye el stick en el Aimbot Controller.",
    Step = 1,
    Value = {Min = 25, Max = 200, Default = 100},
    Callback = function(v)
        controllerSensitivity = math.clamp((tonumber(v) or 100) / 100, 0.25, 2.00)
        markAutoConfigChanged()
    end
})

local function applyControllerCameraSensitivity()
    local ugs = UserSettings and UserSettings()
    local gameSettings = ugs and ugs:GetService("UserGameSettings")
    if gameSettings then
        pcall(function()
            gameSettings.GamepadCameraSensitivity = controllerCameraSensitivity
        end)
    end
end

UIElements.SliControllerCameraSensitivity = Tabs.Aim:Slider({
    Title = "Sensibilidad de Cámara",
    Desc = "Cámara rápida sin aumentar el drift del stick.",
    Step = 1,
    Value = {Min = 50, Max = 150, Default = 100},
    Callback = function(v)
        controllerCameraSensitivity = math.clamp((tonumber(v) or 100) / 100, 0.50, 1.50)
        applyControllerCameraSensitivity()
        markAutoConfigChanged()
    end
})

local function setControllerDriftAssist(enabled)
    enabled = enabled == true
    if enabled and not controllerDriftAssistBound then
        local ok = pcall(function()
            RunService:BindToRenderStep(controllerDriftAssistBind, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
                if not controllerDriftAssistEnabled then return end
                local camera = workspace.CurrentCamera
                if not camera then return end

                local left = UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL1)
                local right = UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR1)
                local direction = (right and 1 or 0) - (left and 1 or 0)
                if direction == 0 then return end

                local angle = math.rad(controllerDriftAssistStrength) * deltaTime * direction
                camera.CFrame = camera.CFrame * CFrame.Angles(0, angle, 0)
            end)
        end)
        controllerDriftAssistBound = ok
    elseif not enabled and controllerDriftAssistBound then
        pcall(function() RunService:UnbindFromRenderStep(controllerDriftAssistBind) end)
        controllerDriftAssistBound = false
    end
end

UIElements.TogControllerDriftAssist = Tabs.Aim:Toggle({
    Title = "Compensación Drift L1/R1",
    Desc = "L1 gira a la izquierda y R1 a la derecha para corregir el drift.",
    Value = false,
    Callback = function(v)
        controllerDriftAssistEnabled = v == true
        setControllerDriftAssist(controllerDriftAssistEnabled)
        markAutoConfigChanged()
    end
})

UIElements.SliControllerDriftAssist = Tabs.Aim:Slider({
    Title = "Fuerza Drift L1/R1",
    Desc = "Velocidad de corrección mientras mantienes L1 o R1.",
    Step = 1,
    Value = {Min = 5, Max = 180, Default = 45},
    Callback = function(v)
        controllerDriftAssistStrength = math.clamp(tonumber(v) or 45, 5, 180)
        markAutoConfigChanged()
    end
})

UIElements.TogControllerInvert = Tabs.Aim:Toggle({
    Title = "Invertir Stick",
    Desc = "Invierte el eje vertical del Aimbot Controller.",
    Value = false,
    Callback = function(v)
        controllerInvertY = v == true
        markAutoConfigChanged()
    end
})

-- ==========================================
-- AIMBOT CONTROLLER SUPPORT
-- ==========================================
Tabs.Aim:Section({Title = "🎯 Aimbot Controller"})

local function getControllerRightStickMagnitude()
    local ok, states = pcall(function()
        return UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
    end)
    if not ok or type(states) ~= "table" then
        return 0
    end

    for i = 1, #states do
        local state = states[i]
        if state.KeyCode == Enum.KeyCode.Thumbstick2 then
            local p = state.Position
            return Vector2.new(p.X, p.Y).Magnitude
        end
    end

    return 0
end

local function findControllerAimTarget()
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local viewport = camera.ViewportSize
    local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local bestPart = nil
    local bestDistSq = math.huge

    local char = player.Character
    local myCore = char and getCharCore(char)
    local myHrp = myCore and myCore.HRP
    if not myHrp then return nil end

    for i = 1, #listaJugadores do
        local p = listaJugadores[i]
        if p ~= player and isEnemy(p) then
            local enemyChar = p.Character
            local enemyCore = enemyChar and getCharCore(enemyChar)
            local hum = enemyCore and enemyCore.Humanoid

            if enemyChar and hum and hum.Health > 0 then
                runtime.CollectTargetParts(
                    enemyChar,
                    "SilentAim",
                    runtime._ControllerAimParts or {},
                    runtime._ControllerAimSeen or {}
                )

                local parts = runtime._ControllerAimParts or {}
                for j = 1, #parts do
                    local part = parts[j]
                    if part and part.Parent then
                        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
                        if onScreen and screenPos.Z > 0 then
                            local dx = screenPos.X - center.X
                            local dy = screenPos.Y - center.Y
                            local distSq = dx * dx + dy * dy

                            if distSq < bestDistSq then
                                bestDistSq = distSq
                                bestPart = part
                            end
                        end
                    end
                end

                table.clear(parts)
                table.clear(runtime._ControllerAimSeen or {})
            end
        end
    end

    return bestPart
end

function stopControllerAimbot()
    if controllerAimConnection then
        controllerAimConnection:Disconnect()
        controllerAimConnection = nil
    end
end

function startControllerAimbot()
    stopControllerAimbot()

    controllerAimConnection = runtime.Track(RunService.RenderStepped:Connect(function()
        if not controllerAimbotEnabled then return end

        local camera = workspace.CurrentCamera
        if not camera then return end

        -- La Dead Zone evita que el drift del stick derecho active el soporte.
        if getControllerRightStickMagnitude() <= controllerAimDeadZone then
            return
        end

        local target = findControllerAimTarget()
        if not target or not target.Parent then return end

        local camPos = camera.CFrame.Position
        local desired = CFrame.lookAt(camPos, target.Position)
        local lerpAmount = math.clamp(0.20 * controllerSensitivity, 0.05, 0.90)
        if controllerInvertY then
            local current = camera.CFrame
            local targetCF = CFrame.lookAt(camPos, target.Position)
            local _, pitch, yaw = targetCF:ToOrientation()
            desired = CFrame.new(camPos) * CFrame.Angles(-pitch, yaw, 0)
        end
        camera.CFrame = camera.CFrame:Lerp(desired, lerpAmount)
    end))
end

UIElements.TogControllerAimbot = Tabs.Aim:Toggle({
    Title = "Aimbot Controller Support",
    Desc = "Mueve la cámara hacia el enemigo usando el stick derecho.",
    Value = false,
    Callback = function(Value)
        controllerAimbotEnabled = (Value == true) and controllerSupportEnabled
        if controllerAimbotEnabled then
            startControllerAimbot()
        else
            stopControllerAimbot()
        end
        markAutoConfigChanged()
    end,
})

UIElements.SliControllerAimDeadZone = Tabs.Aim:Slider({
    Title = "Dead Zone Aimbot",
    Desc = "Ignora movimientos pequeños del stick derecho.",
    Step = 1,
    Value = {
        Min = 0,
        Max = 50,
        Default = 20
    },
    Callback = function(Value)
        controllerAimDeadZone = (tonumber(Value) or 20) / 100
        markAutoConfigChanged()
    end,
})

-- ==========================================
-- KEYBIND PARA SILENT AIM (SOLO PC)
-- ==========================================
silentAimKey = nil
Tabs.Aim:Section({Title = "Selección y controles"})
Tabs.Aim:Input({
    Title = "Tecla para Activar/Desactivar Silent Aim",
    Placeholder = "Escribe una letra (Ej: Q, E, R...)",
    Callback = function(Text)
        if Text and Text ~= "" then
            silentAimKey = string.upper(Text) -- Lo convierte a mayúscula automáticamente
            showBottomMessage("Tecla Silent Aim asignada a: " .. silentAimKey)
        else
            silentAimKey = nil
        end
    end
})

runtime.Track(UserInputService.InputBegan:Connect(function(input, processed)
    -- Si el jugador está escribiendo en el chat, no hacemos nada
    if processed then return end
    
    if input.UserInputType == Enum.UserInputType.Keyboard and silentAimKey then
        if input.KeyCode.Name == silentAimKey then
            -- Alternamos el estado basado en la pistola
            local newState = not silentAimPistolaEnabled 
            
            -- Aplicamos el nuevo estado a ambas variables
            silentAimPistolaEnabled = newState
            silentAimCuchilloEnabled = newState
            
            -- Actualizamos los toggles de la UI visualmente sin romperlos
            pcall(function() UIElements.TogSilentAimPistola:Set(newState) end)
            pcall(function() UIElements.TogSilentAimCuchillo:Set(newState) end)
            
            -- Sincronizamos el botón flotante si lo tienen en pantalla
            pcall(function()
                if saBtn then
                    if newState then
                        saBtn.Text = "Silent Aim: ON"
                        saBtn.TextColor3 = Color3.fromHex("#DCE0E5")
                        if saStroke then saStroke.Color = Color3.fromRGB(255, 255, 255) end
                    else
                        saBtn.Text = "Silent Aim: OFF"
                        saBtn.TextColor3 = Color3.fromHex("#F3F4F5")
                        if saStroke then saStroke.Color = Color3.fromHex("#464B52") end
                    end
                end
            end)

            -- Avisamos al jugador
            showBottomMessage(newState and "Silent Aim: ACTIVADO ["..silentAimKey.."]" or "Silent Aim: DESACTIVADO ["..silentAimKey.."]")
        end
    end
end))

Tabs.Aim:Button({
    Title = "Selector corporal · Silent Aim",
    Desc = "Selecciona cabeza, torso, brazos y piernas con multiselección visual.",
    Callback = function() runtime.OpenBodySelector("SilentAim") end,
})

UIElements.TogSilentAimFOV = Tabs.Aim:Toggle({
    Title = "Filtro de círculo FOV",
    Desc = "Silent Aim solo considera objetivos dentro del círculo configurado.",
    Value = false,
    Callback = function(Value)
        silentAimFovEnabled = Value
        showBottomMessage(Value and "Filtro FOV: ACTIVADO" or "Filtro FOV: DESACTIVADO")
    end,
})

UIElements.TogShowFOV = Tabs.Aim:Toggle({
    Title = "Mostrar Círculo FOV",
    Desc = "Dibuja un círculo en pantalla para saber dónde funciona tu Silent Aim.",
    Value = false,
    Callback = function(Value) fovVisiblePreference = Value end,
})

Tabs.Aim:Section({Title = "Campo de visión"})
UIElements.SliFOVSize = Tabs.Aim:Slider({
    Title = "Tamaño del FOV", 
    Step = 1,
    Value = {Min = 10, Max = 800, Default = 120}, 
    Callback = function(v) fovRadius = v end
})




-- PESTAÑA FINAL: CONFIGURACIÓN (SISTEMA ILIMITADO)
-- ==========================================
Tabs.Config:Section({ Title = "Gestor de Configs" })
local configFolder = "iLunXHub_Configs_Duels_WindUI"
local legacyConfigFolder = "OnyxHub_Configs_Duels_WindUI"
if isfolder and not isfolder(configFolder) then pcall(function() makefolder(configFolder) end) end

local availableConfigs = {"Ninguna"}
local selectedConfig = "Ninguna"
local customConfigName = ""
local configPaths = {}

-- ==========================================
-- CONFIGURACION Y AUTO LOAD
-- Una sola lista: la configuración seleccionada
-- es también la que usará Auto Load.
-- ==========================================
local AUTOLOAD_SETTINGS_FILE = "XeroHub_Autoload_Config.json"
local autoloadEnabled = false
local autoloadConfigName = "Ninguna"

local function loadAutoloadSettings()
    if not (isfile and isfile(AUTOLOAD_SETTINGS_FILE) and readfile) then return end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(AUTOLOAD_SETTINGS_FILE))
    end)

    if ok and type(data) == "table" then
        autoloadEnabled = data.Enabled == true
        autoloadConfigName = tostring(data.ConfigName or "Ninguna")
    end
end

local function saveAutoloadSettings()
    if not writefile then return false end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode({
            Enabled = autoloadEnabled,
            ConfigName = autoloadConfigName
        })
    end)

    if not ok then return false end
    return pcall(writefile, AUTOLOAD_SETTINGS_FILE, encoded)
end

loadAutoloadSettings()

-- La configuración guardada para Auto Load será la misma que se muestra
-- en "Seleccionar Configuración".
if autoloadConfigName ~= "" and autoloadConfigName ~= "Ninguna" then
    selectedConfig = autoloadConfigName
end

configDropdown = Tabs.Config:Dropdown({
    Title = "Seleccionar Configuración",
    Values = availableConfigs,
    Value = selectedConfig or "Ninguna",
    Callback = function(Value)
        selectedConfig = tostring(Value or "Ninguna")

        -- La única selección sirve también para Auto Load.
        autoloadConfigName = selectedConfig
        saveAutoloadSettings()
    end
})

Tabs.Config:Toggle({
    Title = "Auto Load Config",
    Desc = "Carga automáticamente la configuración seleccionada al ejecutar XeroHub.",
    Value = autoloadEnabled,
    Callback = function(Value)
        autoloadEnabled = Value == true
        saveAutoloadSettings()
    end
})

function refreshConfigs()
    local list = {}
    local seen = {}
    configPaths = {}
    if listfiles then
        pcall(function()
            -- El folder anterior también se lee para no perder configuraciones guardadas.
            for _, folder in ipairs({configFolder, legacyConfigFolder}) do
                if not isfolder or isfolder(folder) then
                    for _, file in ipairs(listfiles(folder)) do
                        if file:match("%.json$") then
                            local name = file:match("([^/\\]+)%.json$")
                            if name and not seen[name] then
                                seen[name] = true
                                configPaths[name] = file
                                table.insert(list, name)
                            end
                        end
                    end
                end
            end
        end)
    end
    if #list == 0 then table.insert(list, "Ninguna") end

    -- Sincroniza la lista interna para que Autoload pueda encontrar la config.
    availableConfigs = list
    
    pcall(function()
        configDropdown:Refresh(list)
        if selectedConfig == "Ninguna" or not table.find(list, selectedConfig) then
            configDropdown:Select(list[1])
            selectedConfig = list[1]
        end

        -- La misma lista alimenta "Seleccionar Configuración".
        -- Si había una config guardada para Auto Load, la seleccionamos aquí.
        if autoloadConfigName ~= "Ninguna"
            and table.find(list, autoloadConfigName) then
            selectedConfig = autoloadConfigName
            pcall(function()
                configDropdown:Select(autoloadConfigName)
            end)
        end
    end)
end

Tabs.Config:Button({
    Title = "Actualizar Lista",
    Callback = function()
        refreshConfigs()
        showBottomMessage("Lista de configuraciones actualizada.")
    end
})

Tabs.Config:Input({ 
    Title = "Nombre para Guardar ", 
    Placeholder = "Ej: Config 1, Config 2...", 
    Callback = function(Text) 
        customConfigName = Text 
    end 
})
Tabs.Config:Button({ Title = "Guardar Configuración", Callback = function()
    task.wait(0.1) 
    
    -- Si el usuario escribió un nombre, usamos ese. Si no, sobreescribimos el seleccionado en el dropdown.
    local finalName = customConfigName:gsub("[^%w%s%-]", "") 
    if finalName == "" then finalName = selectedConfig end
    
    if finalName == "" or finalName == "Ninguna" then
        showBottomMessage(" Escribe un nombre válido o selecciona una config para sobreescribir.")
        return
    end
    
    local path = configFolder .. "/" .. finalName .. ".json"
    
    local configData = {
        ConfigName = finalName, 
        Toggles = {
            ["Auto Shoot"] = autoShootEnabled,
            ["AutoShoot Cuchillo"] = autoShootCuchilloEnabled,
            ["Transparencia Hitbox"] = hitboxTransparency,
            ["Silent Aim (Pistola)"] = silentAimPistolaEnabled,
            ["Silent Aim (Cuchillo)"] = silentAimCuchilloEnabled,
            ["Silent Aim (FOV)"] = silentAimFovEnabled,
            ["Mostrar Círculo FOV"] = fovVisiblePreference,
            ["ESP Lineas"] = espLinesEnabled,
            ["ESP Box 2D"] = espSettings.Box,
            ["ESP Barra Vida"] = espSettings.HealthBar,
            ["Btn Flotante AutoShoot"] = asBtn.Visible,
            ["Btn Flotante SilentAim"] = saBtn.Visible,
            ["Aumentar Hitbox"] = hitboxEnabled, 
            ["Hitbox Invisible"] = hitboxInvisible, 
            ["ESP Jugadores"] = espEnabled, 
            ["Mostrar Resplandor (Glow)"] = espSettings.Glow, 
            ["Mostrar Nombre"] = espSettings.Name, 
            ["Mostrar Distancia"] = espSettings.Distance, 
            ["Ocultar mi Nombre (Local)"] = hideNameEnabled, 
            ["Activar Macro"] = macroActivo,
            ["Activar Trigger Bot"] = triggerBotEnabled,
            ["Macro Cuchillo (L2)"] = knifeMacroEnabled,
            ["Trigger Bot"] = triggerBotEnabled
        },
        Sliders = { 
            ["Tamaño del FOV"] = fovRadius, 
            ["Tamaño de Hitbox"] = hitboxSize, 
            ["Delay Equipar Macro"] = macroEquipDelay,
            ["Delay Disparo Macro"] = macroShootDelay,
            ["Delay Equipar Cuchillo"] = knifeEquipDelay,
            ["Delay Lanzamiento Cuchillo"] = knifeThrowDelay,
            ["Dead Zone Aimbot"] = controllerAimDeadZone * 100
        },
        Colors = {
            ["Color de Hitbox"] = {R = hitboxColor.R, G = hitboxColor.G, B = hitboxColor.B}, 
            ["Color del ESP"] = {R = espColor.R, G = espColor.G, B = espColor.B} 
        },
        Extras = {
            -- Los campos antiguos se conservan para compatibilidad con configs viejas.
            ["Parte Aimbot"] = silentAimTargetPart,
            ["Parte AutoShoot"] = autoShootTargetPart,
            ["Partes Aimbot"] = runtime.GetTargetSelectionArray("SilentAim"),
            ["Partes AutoShoot"] = runtime.GetTargetSelectionArray("AutoShoot")
        },
        Interfaz = {
            Tema = runtime.InterfaceTheme or ((Window and Window.GetTheme and Window:GetTheme()) or "Xero")
        },
        Apariencia = runtime.SerializeAppearanceConfig(),
        Sonidos = runtime.SerializeSoundConfig and runtime.SerializeSoundConfig() or nil,
        SonidoSalto = {
            Activado = (getgenv and getgenv().XeroJumpSoundEnabled == true),
            Seleccionado = runtime.JumpSoundSelectedLabel,
        },
    }
    
    if writefile then 
        local sEncode, encodedData = pcall(function() return HttpService:JSONEncode(configData) end)
        if sEncode then
            local writeOk = pcall(function()
                writefile(path, encodedData)
            end)

            if writeOk then
                showBottomMessage(" Guardado como: " .. finalName)

                task.defer(function()
                    pcall(function()
                        refreshConfigs()
                        selectedConfig = finalName
                        autoloadConfigName = finalName
                        saveAutoloadSettings()
                        configDropdown:Select(finalName)
                    end)
                end)
            else
                showBottomMessage(" Error: no se pudo guardar la configuración.")
            end
        else
            showBottomMessage(" Error interno al procesar los datos.")
        end
    else 
        showBottomMessage(" Error: Tu ejecutor no soporta guardar") 
    end
end})

function secureLoadToggle(element, val) 
    if not element or val == nil then return end 
    -- Cargar una config puede cambiar muchos controles de golpe. Silenciamos
    -- esos callbacks y mostramos solamente el resultado final de la carga.
    local wasSuppressed = runtime.SuppressNotifications
    runtime.SuppressNotifications = true
    pcall(function() element:Set(val) end)
    runtime.SuppressNotifications = wasSuppressed
end

local function loadSelectedConfig()
    if selectedConfig == "Ninguna" or selectedConfig == "" then
        showBottomMessage("No hay ninguna configuración seleccionada.")
        return
    end
    
    local path = configPaths[selectedConfig] or (configFolder .. "/" .. selectedConfig .. ".json")
    if isfile and isfile(path) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if success and type(decoded) == "table" then
            
            -- Toggles
             if decoded.Toggles then
                -- 🔥 NUEVOS AGREGADOS CARGA:
                if decoded.Toggles["Auto Shoot"] ~= nil then autoShootEnabled = decoded.Toggles["Auto Shoot"]; secureLoadToggle(UIElements.TogAutoShoot, autoShootEnabled) end
                -- 🔥 AQUÍ CARGAS EL CUCHILLO (Y actualizas el toggle visual)
                if decoded.Toggles["AutoShoot Cuchillo"] ~= nil then 
                    autoShootCuchilloEnabled = decoded.Toggles["AutoShoot Cuchillo"] 
                    secureLoadToggle(UIElements.TogAutoShootCuchillo, autoShootCuchilloEnabled) 
                end
                
                -- Cargar Silent Aim Pistola (con compatibilidad vieja)
                if decoded.Toggles["Silent Aim (Pistola)"] ~= nil then 
                    silentAimPistolaEnabled = decoded.Toggles["Silent Aim (Pistola)"] 
                    secureLoadToggle(UIElements.TogSilentAimPistola, silentAimPistolaEnabled) 
                elseif decoded.Toggles["Silent Aim (Manual)"] ~= nil then 
                    silentAimPistolaEnabled = decoded.Toggles["Silent Aim (Manual)"] 
                    secureLoadToggle(UIElements.TogSilentAimPistola, silentAimPistolaEnabled) 
                end
                
                -- Cargar Silent Aim Cuchillo
                if decoded.Toggles["Silent Aim (Cuchillo)"] ~= nil then 
                    silentAimCuchilloEnabled = decoded.Toggles["Silent Aim (Cuchillo)"] 
                    secureLoadToggle(UIElements.TogSilentAimCuchillo, silentAimCuchilloEnabled) 
                end

                if decoded.Toggles["Silent Aim (FOV)"] ~= nil then silentAimFovEnabled = decoded.Toggles["Silent Aim (FOV)"]; secureLoadToggle(UIElements.TogSilentAimFOV, silentAimFovEnabled) end

                if decoded.Toggles["Mostrar Círculo FOV"] ~= nil then fovVisiblePreference = decoded.Toggles["Mostrar Círculo FOV"]; secureLoadToggle(UIElements.TogShowFOV, fovVisiblePreference) end
                if decoded.Toggles["ESP Lineas"] ~= nil then espLinesEnabled = decoded.Toggles["ESP Lineas"]; secureLoadToggle(UIElements.TogEspLines, espLinesEnabled) end
                if decoded.Toggles["ESP Box 2D"] ~= nil then espSettings.Box = decoded.Toggles["ESP Box 2D"]; secureLoadToggle(UIElements.TogEspBox, espSettings.Box) end
                if decoded.Toggles["ESP Barra Vida"] ~= nil then espSettings.HealthBar = decoded.Toggles["ESP Barra Vida"]; secureLoadToggle(UIElements.TogEspHealth, espSettings.HealthBar) end
                
                -- Botones Flotantes (Usando Set() para que se actulice el toggle visual)
                if decoded.Toggles["Btn Flotante AutoShoot"] ~= nil then secureLoadToggle(UIElements.ToggleAsBtn, decoded.Toggles["Btn Flotante AutoShoot"]) end
                if decoded.Toggles["Btn Flotante SilentAim"] ~= nil then secureLoadToggle(UIElements.ToggleSaBtn, decoded.Toggles["Btn Flotante SilentAim"]) end

                -- EXISTENTES CARGA:
                if decoded.Toggles["Aumentar Hitbox"] ~= nil then hitboxEnabled = decoded.Toggles["Aumentar Hitbox"]; secureLoadToggle(UIElements.TogHitbox, hitboxEnabled) end
                if decoded.Toggles["Hitbox Invisible"] ~= nil then hitboxInvisible = decoded.Toggles["Hitbox Invisible"]; secureLoadToggle(UIElements.TogHbInv, hitboxInvisible) end
                if decoded.Toggles["ESP Jugadores"] ~= nil then espEnabled = decoded.Toggles["ESP Jugadores"]; secureLoadToggle(UIElements.TogEsp, espEnabled) end
                if decoded.Toggles["Mostrar Resplandor (Glow)"] ~= nil then espSettings.Glow = decoded.Toggles["Mostrar Resplandor (Glow)"]; secureLoadToggle(UIElements.TogEspGl, espSettings.Glow) end
                if decoded.Toggles["Mostrar Nombre"] ~= nil then espSettings.Name = decoded.Toggles["Mostrar Nombre"]; secureLoadToggle(UIElements.TogEspNm, espSettings.Name) end
                if decoded.Toggles["Mostrar Distancia"] ~= nil then espSettings.Distance = decoded.Toggles["Mostrar Distancia"]; secureLoadToggle(UIElements.TogEspDs, espSettings.Distance) end
                if decoded.Toggles["Ocultar mi Nombre (Local)"] ~= nil then hideNameEnabled = decoded.Toggles["Ocultar mi Nombre (Local)"]; secureLoadToggle(UIElements.TogHideName, hideNameEnabled) end
                if decoded.Toggles["Activar Macro"] ~= nil then
                    macroActivo = decoded.Toggles["Activar Macro"] == true
                    secureLoadToggle(UIElements.TogMacro, macroActivo)
                end
                if decoded.Toggles["Macro Cuchillo (L2)"] ~= nil then
                    knifeMacroEnabled = decoded.Toggles["Macro Cuchillo (L2)"] == true
                    secureLoadToggle(UIElements.TogKnifeMacro, knifeMacroEnabled)
                if decoded.Toggles["Trigger Bot"] ~= nil then
                    triggerBotEnabled = decoded.Toggles["Trigger Bot"] == true
                    secureLoadToggle(UIElements.TogTriggerBot, triggerBotEnabled)
                end
                if decoded.Toggles["Controller Support"] ~= nil then
                    controllerSupportEnabled = decoded.Toggles["Controller Support"] == true
                    secureLoadToggle(UIElements.TogControllerSupport, controllerSupportEnabled)
                end
                if decoded.Toggles["Compensación Drift L1/R1"] ~= nil then
                    controllerDriftAssistEnabled = decoded.Toggles["Compensación Drift L1/R1"] == true
                    secureLoadToggle(UIElements.TogControllerDriftAssist, controllerDriftAssistEnabled)
                    setControllerDriftAssist(controllerDriftAssistEnabled)
                end
                if decoded.Toggles["Aimbot Controller Support"] ~= nil then
                    controllerAimbotEnabled = (decoded.Toggles["Aimbot Controller Support"] == true) and controllerSupportEnabled
                    secureLoadToggle(UIElements.TogControllerAimbot, controllerAimbotEnabled)
                end
                if decoded.Extras and decoded.Extras["Invertir Stick"] ~= nil then
                    controllerInvertY = decoded.Extras["Invertir Stick"] == true
                    secureLoadToggle(UIElements.TogControllerInvert, controllerInvertY)
                end
                end

                -- FIX AUTOLOAD: algunos builds de WindUI terminan de pintar los
                -- toggles después de Set(). Reaplicamos el estado al siguiente frame
                -- para que visual y variable queden sincronizados.
                local savedMacroState = decoded.Toggles["Activar Macro"]
                local savedKnifeMacroState = decoded.Toggles["Macro Cuchillo (L2)"]
                local savedControllerSupportState = decoded.Toggles["Controller Support"]
                local savedControllerDriftAssistState = decoded.Toggles["Compensación Drift L1/R1"]
                local savedControllerAimbotState = decoded.Toggles["Aimbot Controller Support"]
                local savedControllerInvertState = decoded.Extras and decoded.Extras["Invertir Stick"]
                task.defer(function()
                    task.wait(0.15)
                    if savedMacroState ~= nil then
                        macroActivo = savedMacroState == true
                        pcall(function() UIElements.TogMacro:Set(macroActivo) end)
                    end
                    if savedKnifeMacroState ~= nil then
                        knifeMacroEnabled = savedKnifeMacroState == true
                        pcall(function() UIElements.TogKnifeMacro:Set(knifeMacroEnabled) end)
                    end
                    if savedControllerSupportState ~= nil then
                        controllerSupportEnabled = savedControllerSupportState == true
                        pcall(function() UIElements.TogControllerSupport:Set(controllerSupportEnabled) end)
                        setControllerDeadZoneFilter(controllerSupportEnabled)
                    end
                    if savedControllerInvertState ~= nil then
                        controllerInvertY = savedControllerInvertState == true
                        pcall(function() UIElements.TogControllerInvert:Set(controllerInvertY) end)
                    end
                    if savedControllerDriftAssistState ~= nil then
                        controllerDriftAssistEnabled = savedControllerDriftAssistState == true
                        pcall(function() UIElements.TogControllerDriftAssist:Set(controllerDriftAssistEnabled) end)
                        setControllerDriftAssist(controllerDriftAssistEnabled)
                    end
                    if savedControllerAimbotState ~= nil and controllerSupportEnabled then
                        controllerAimbotEnabled = savedControllerAimbotState == true
                        pcall(function() UIElements.TogControllerAimbot:Set(controllerAimbotEnabled) end)
                    end
                end)
            end
            
            -- Sliders
            if decoded.Sliders then 
                if decoded.Sliders["Transparencia Hitbox"] ~= nil then hitboxTransparency = decoded.Sliders["Transparencia Hitbox"]; secureLoadToggle(UIElements.SliHitboxTrans, hitboxTransparency) end
                if decoded.Sliders["Tamaño del FOV"] ~= nil then fovRadius = decoded.Sliders["Tamaño del FOV"]; secureLoadToggle(UIElements.SliFOVSize, fovRadius) end
                if decoded.Sliders["Tamaño de Hitbox"] ~= nil then hitboxSize = decoded.Sliders["Tamaño de Hitbox"]; secureLoadToggle(UIElements.SliHitbox, hitboxSize) end
                if decoded.Sliders["Delay Equipar Macro"] ~= nil then macroEquipDelay = decoded.Sliders["Delay Equipar Macro"]; secureLoadToggle(UIElements.SliMacroEquip, macroEquipDelay) end
                if decoded.Sliders["Delay Disparo Macro"] ~= nil then macroShootDelay = decoded.Sliders["Delay Disparo Macro"]; secureLoadToggle(UIElements.SliMacroShoot, macroShootDelay) end
                if decoded.Sliders["Delay Equipar Cuchillo"] ~= nil then knifeEquipDelay = decoded.Sliders["Delay Equipar Cuchillo"]; secureLoadToggle(UIElements.SliKnifeEquip, knifeEquipDelay) end
                if decoded.Sliders["Delay Lanzamiento Cuchillo"] ~= nil then knifeThrowDelay = decoded.Sliders["Delay Lanzamiento Cuchillo"]; secureLoadToggle(UIElements.SliKnifeThrow, knifeThrowDelay) end
                if decoded.Sliders["Dead Zone Aimbot"] ~= nil then
                    controllerAimDeadZone = (tonumber(decoded.Sliders["Dead Zone Aimbot"]) or 20) / 100
                    secureLoadToggle(UIElements.SliControllerAimDeadZone, decoded.Sliders["Dead Zone Aimbot"])
                end
                if decoded.Sliders["Dead Zone del Stick"] ~= nil then
                    controllerDeadZone = math.clamp((tonumber(decoded.Sliders["Dead Zone del Stick"]) or 20) / 100, 0, 0.50)
                    secureLoadToggle(UIElements.SliControllerDeadZone, decoded.Sliders["Dead Zone del Stick"])
                end
                if decoded.Sliders["Sensibilidad del Stick"] ~= nil then
                    controllerSensitivity = math.clamp((tonumber(decoded.Sliders["Sensibilidad del Stick"]) or 100) / 100, 0.25, 2.00)
                    secureLoadToggle(UIElements.SliControllerSensitivity, decoded.Sliders["Sensibilidad del Stick"])
                end
                if decoded.Sliders["Sensibilidad de Cámara"] ~= nil then
                    controllerCameraSensitivity = math.clamp((tonumber(decoded.Sliders["Sensibilidad de Cámara"]) or 100) / 100, 0.50, 1.50)
                    secureLoadToggle(UIElements.SliControllerCameraSensitivity, decoded.Sliders["Sensibilidad de Cámara"])
                    applyControllerCameraSensitivity()
                end
                if decoded.Sliders["Fuerza Drift L1/R1"] ~= nil then
                    controllerDriftAssistStrength = math.clamp(tonumber(decoded.Sliders["Fuerza Drift L1/R1"]) or 45, 5, 180)
                    secureLoadToggle(UIElements.SliControllerDriftAssist, controllerDriftAssistStrength)
                end
            end
        
            
            -- Colores
            if decoded.Colors then
                if decoded.Colors["Color de Hitbox"] then
                    local cHitbox = Color3.new(decoded.Colors["Color de Hitbox"].R, decoded.Colors["Color de Hitbox"].G, decoded.Colors["Color de Hitbox"].B)
                    hitboxColor = cHitbox; secureLoadToggle(UIElements.ColHitbox, cHitbox) 
                end
                if decoded.Colors["Color del ESP"] then
                    local cEsp = Color3.new(decoded.Colors["Color del ESP"].R, decoded.Colors["Color del ESP"].G, decoded.Colors["Color del ESP"].B)
                    espColor = cEsp; secureLoadToggle(UIElements.ColEsp, cEsp) 
                end
            end
            
            -- Extras: multiselección corporal + compatibilidad con configs anteriores.
            if decoded.Extras then
                if decoded.Extras["Partes Aimbot"] then
                    runtime.SetTargetSelection("SilentAim", decoded.Extras["Partes Aimbot"])
                elseif decoded.Extras["Parte Aimbot"] then
                    runtime.SetTargetSelection("SilentAim", decoded.Extras["Parte Aimbot"])
                end

                if decoded.Extras["Partes AutoShoot"] then
                    runtime.SetTargetSelection("AutoShoot", decoded.Extras["Partes AutoShoot"])
                elseif decoded.Extras["Parte AutoShoot"] then
                    runtime.SetTargetSelection("AutoShoot", decoded.Extras["Parte AutoShoot"])
                end
            end

            local savedTheme = decoded.Interfaz and decoded.Interfaz.Tema
            if not savedTheme and decoded.Extras then
                savedTheme = decoded.Extras["Tema Interfaz"]
            end
            if savedTheme then
                local normalizedTheme = (tostring(savedTheme) == "Blanco" or tostring(savedTheme) == "White" or tostring(savedTheme) == "Claro") and "Blanco" or "Xero"
                runtime.InterfaceTheme = normalizedTheme
                if Window and Window.SetTheme then
                    Window:SetTheme(normalizedTheme, true)
                elseif WindUI and WindUI.SetTheme then
                    WindUI:SetTheme(normalizedTheme)
                end
                if UIElements.ThemeDropdown then
                    secureLoadToggle(UIElements.ThemeDropdown, normalizedTheme == "Blanco" and "Blanco" or "Oscuro")
                end
            end

            if decoded.Apariencia then
                runtime.LoadAppearanceConfig(decoded.Apariencia)
            end

            -- SKYBOX AUTO-SAVE: solo se aplica si el usuario tenía uno activo.
            if decoded.Skybox and decoded.Skybox.Activado == true and modes then
                pcall(function()
                    if decoded.Skybox.Nombre == "Cielo personalizado" then
                        local custom = decoded.Skybox.Custom
                        if type(custom) == "table" and #custom >= 6 then
                            for index = 1, 6 do
                                skies.Custom[index] = tostring(custom[index])
                            end
                        end
                        modes.customInput = tostring(decoded.Skybox.CustomInput or skies.Custom[1] or "")
                        modes.select("Cielo personalizado")
                    elseif decoded.Skybox.Nombre and decoded.Skybox.Nombre ~= "Ninguno" then
                        modes.select(tostring(decoded.Skybox.Nombre))
                    end
                end)
            end

            if decoded.Sonidos and runtime.LoadSoundConfig then
                runtime.LoadSoundConfig(decoded.Sonidos)
            end

            if decoded.SonidoSalto and decoded.SonidoSalto.Activado == true then
                getgenv().XeroJumpSoundEnabled = true
                local jumpLabel = decoded.SonidoSalto.Seleccionado
                if jumpLabel and runtime.JumpSoundDropdown then
                    runtime.JumpSoundSelectedLabel = jumpLabel
                    pcall(function() runtime.JumpSoundDropdown:Select(jumpLabel) end)
                end
            end

            showBottomMessage("'" .. selectedConfig .. "' cargada con éxito.")
        else 
            showBottomMessage("Error al leer el archivo.") 
        end
    else 
        showBottomMessage("La configuración no existe.") 
    end
end

Tabs.Config:Button({ Title = " Cargar Configuración", Callback = loadSelectedConfig })
-- Cargar la lista al iniciar el script.
-- Auto Load usa exactamente la configuración seleccionada en la única lista.
task.spawn(function()
    task.wait(1)
    refreshConfigs()

    if autoloadEnabled and autoloadConfigName ~= "Ninguna" and autoloadConfigName ~= "" then
        if table.find(availableConfigs, autoloadConfigName) then
            selectedConfig = autoloadConfigName

            pcall(function()
                configDropdown:Select(autoloadConfigName)
            end)

            task.wait(0.25)
            loadSelectedConfig()
        else
            warn("[Xero Autoload] No se encontró la configuración: " .. tostring(autoloadConfigName))
        end
    end
end)

-- ==========================================
-- SONIDO AL SALTAR
-- ==========================================
local jumpSoundEnabled = (getgenv and getgenv().XeroJumpSoundEnabled == true)
local jumpSoundId = ""

local function playJumpSound(character)
    local catalogAssetId = runtime.JumpSoundAssetId
    if type(catalogAssetId) == "string" and catalogAssetId ~= "" then
        jumpSoundId = catalogAssetId
    end

    local enabled = jumpSoundEnabled or (getgenv and getgenv().XeroJumpSoundEnabled == true)
    if not enabled or jumpSoundId == "" then
        return
    end
    if not character or not character.Parent then
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local sound = Instance.new("Sound")
    sound.Name = "XeroJumpSound"
    sound.SoundId = jumpSoundId
    sound.Volume = 1
    sound.Parent = root

    local ok = pcall(function()
        sound:Play()
    end)

    if not ok then
        sound:Destroy()
        return
    end

    sound.Ended:Connect(function()
        if sound.Parent then
            sound:Destroy()
        end
    end)

    task.delay(10, function()
        if sound.Parent then
            sound:Destroy()
        end
    end)
end

local function setupJumpSound(character)
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = character:WaitForChild("Humanoid", 5)
    end
    if not humanoid then
        return
    end

    runtime.Track(humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            playJumpSound(character)
        end
    end))
end

if player.Character then
    task.defer(setupJumpSound, player.Character)
end

runtime.Track(player.CharacterAdded:Connect(function(character)
    task.wait(0.25)
    setupJumpSound(character)
end))

-- El splash sólo existe durante esta ejecución inicial. Abrir y cerrar el hub
-- después de este punto permanece completamente instantáneo.
startupSplashState.Finish()
runtime.NotificationsReady = true
-- XERO_FULL_GENERAL_OPTIMIZATION_2026_09_13
-- XERO_GENERAL_OPTIMIZATION_2026_09_14



-- ==========================================
-- AUTO-SAVE / AUTO-LOAD FINAL
-- ==========================================
-- Este sistema es INDEPENDIENTE de "Auto Load Config".
-- Se restaura siempre al entrar, sin que el usuario tenga que activar AutoLoad.
task.spawn(function()
    task.wait(2.0)

    local loaded = false
    pcall(function()
        if autoCanRead() then
            local okRead = pcall(function() return readfile(AUTO_CONFIG_FILE) end)
            if okRead then
                -- Reutilizamos el mismo cargador completo de configuraciones para
                -- que sonidos, animaciones, apariencia, skybox y toggles se apliquen
                -- exactamente igual que una configuración normal.
                local oldSelected = selectedConfig
                local oldPath = configPaths["__XERO_AUTO__"]
                configPaths["__XERO_AUTO__"] = AUTO_CONFIG_FILE
                selectedConfig = "__XERO_AUTO__"

                -- Los controles no guardados deben arrancar apagados.
                local resetToggles = {
                    UIElements.TogAutoShoot,
                    UIElements.TogAutoShootCuchillo,
                    UIElements.TogSilentAimPistola,
                    UIElements.TogSilentAimCuchillo,
                    UIElements.TogSilentAimFOV,
                    UIElements.TogShowFOV,
                    UIElements.TogEspLines,
                    UIElements.TogEspBox,
                    UIElements.TogEspHealth,
                    UIElements.ToggleAsBtn,
                    UIElements.ToggleSaBtn,
                    UIElements.TogHitbox,
                    UIElements.TogHbInv,
                    UIElements.TogEsp,
                    UIElements.TogEspGl,
                    UIElements.TogEspNm,
                    UIElements.TogEspDs,
                    UIElements.TogHideName,
                    UIElements.TogMacro,
                    UIElements.TogTriggerBot,
                    UIElements.TogKnifeMacro,
                    UIElements.TogControllerAimbot,
                    UIElements.TogControllerSupport,
                    UIElements.TogControllerInvert,
                }
                for _, control in ipairs(resetToggles) do
                    if control then pcall(function() control:Set(false) end) end
                end

                -- Estados internos que algunos controles no exponen directamente.
                macroActivo = false
                knifeMacroEnabled = false
                triggerBotEnabled = false
                controllerAimbotEnabled = false
                controllerSupportEnabled = false
                controllerDeadZone = 0.20
                controllerSensitivity = 1.00
                controllerInvertY = false
                setControllerDeadZoneFilter(false)
                autoShootEnabled = false
                autoShootCuchilloEnabled = false
                silentAimPistolaEnabled = false
                silentAimCuchilloEnabled = false
                silentAimFovEnabled = false
                fovVisiblePreference = false
                espLinesEnabled = false
                espSettings.Box = false
                espSettings.HealthBar = false
                hitboxEnabled = false
                hitboxInvisible = false
                espEnabled = false
                espSettings.Glow = false
                espSettings.Name = false
                espSettings.Distance = false
                hideNameEnabled = false
                fpsBoostEnabled = false

                pcall(function()
                    loadSelectedConfig()
                    if controllerSupportEnabled then
                        setControllerDeadZoneFilter(true)
                    else
                        setControllerDeadZoneFilter(false)
                    end
                    if controllerAimbotEnabled and controllerSupportEnabled then
                        startControllerAimbot()
                    else
                        stopControllerAimbot()
                    end
                    loaded = true
                end)

                selectedConfig = oldSelected
                if oldPath then configPaths["__XERO_AUTO__"] = oldPath else configPaths["__XERO_AUTO__"] = nil end
            end
        end
    end)

    autoConfigLoaded = loaded
    autoSaveReady = true

    if not loaded then
        saveAutoConfig()
    end
end)

-- Guarda cualquier cambio realizado desde la UI.
task.spawn(function()
    local lastState = nil

    while task.wait(0.50) do
        if autoSaveReady then
            local snapshot = autoJsonEncode(buildAutoConfig()) or ""
            if snapshot ~= lastState then
                lastState = snapshot
                queueAutoConfigSave()
            end
        end
    end
end)

