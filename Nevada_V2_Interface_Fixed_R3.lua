-- NEVADA V27 | Menú Completo Estable + Silent Aim + Team Check + Botón Flotante
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local requestFn = (syn and syn.request) or (http and http.request) or request or http_request

local OWNER, REPO, BRANCH = "sanxsmov", "Mis-soundsp", "main"
local FOLDERS = {"sounds", "SoundsV2"}
local RAW = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. BRANCH .. "/"
local API_ROOT = "https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/contents/"
local CONFIG_FILE = "nevada_v2_config.json"

local state = {
  macro = false, equipDelay = 0.05, shootDelay = 0.10,
  knifeMacroEnabled = false, knifeEquipDelay = 0.10, knifeThrowDelay = 0.10,
  macro360Enabled = false, 
  macro360Fov = 120, 
  macro360HitChance = 100, 
  macro360Reaction = 0,
  macro360Cooldown = 0.05, 
  selected = {Arma={Name="Ninguno",URL=""}, Saltar={Name="Ninguno",URL=""}, Matar={Name="Ninguno",URL=""}},
  enabled = {Arma=true, Saltar=true, Matar=true}, muted = {Arma=false, Saltar=false, Matar=false},
  folder = FOLDERS[1]
}
local sounds, soundCache, activeTab, soundCategory = {}, {}, "Inicio", "Arma"

-- ==========================================
-- TEAM CHECK Y ANTI-LOBBY
-- ==========================================
local function getPlayerTeam(p)
    if not p then return nil end
    if p.Team and p.Team.Name ~= "" then return p.Team.Name end
    local attr = p:GetAttribute("Team") or p:GetAttribute("team")
    if attr and tostring(attr) ~= "" then return tostring(attr) end
    
    local gui = player:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("Main")
    local frame = main and main:FindFirstChild("MainGameFrame")
    local score = frame and frame:FindFirstChild("IngameScore")
    if score then
        for _, teamName in ipairs({"TeamRed", "TeamBlue"}) do
            local teamFolder = score:FindFirstChild(teamName)
            if teamFolder and teamFolder:FindFirstChild(p.Name) then
                return teamName == "TeamRed" and "Red" or "Blue"
            end
        end
    end
    return nil
end

local function isEnemy(targetPlayer)
    if not targetPlayer or targetPlayer == player then return false end
    local myTeam = getPlayerTeam(player)
    local targetTeam = getPlayerTeam(targetPlayer)
    if myTeam and targetTeam then
        return string.lower(myTeam) ~= string.lower(targetTeam)
    end
    return false -- Si no sabemos el equipo, no disparamos para evitar TeamKill
end

local SAFE_ZONES = {
    {Center = Vector3.new(-320.50, 280.82, 16.00), Radius = 500},
    {Center = Vector3.new(1564.14, -155.45, 40.04), Radius = 300}
}
local function estaEnLobby()
    local character = player.Character
    if not character then return true end
    if character:FindFirstChildOfClass("ForceField") then return true end
    if player.Team then
        local name = player.Team.Name:lower()
        if name:find("lobby") or name:find("spectat") or name:find("menu") then return true end
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if root then
        for _, zone in ipairs(SAFE_ZONES) do
            if (root.Position - zone.Center).Magnitude <= zone.Radius then return true end
        end
    end
    return false
end

local function esPistola(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return tool:FindFirstChild("showBeam") ~= nil
end

-- ==========================================
-- HOOK RAYCAST (Silent Aim)
-- ==========================================
getgenv().NevadaTargetPart = nil
local oldNamecall
if hookmetamethod and getnamecallmethod and checkcaller then
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() and getgenv().NevadaTargetPart then
            if method == "Raycast" and self == workspace then
                local target = getgenv().NevadaTargetPart
                if target and target.Parent then
                    local origin, direction, p3 = ...
                    if typeof(direction) == "Vector3" and direction.Magnitude > 20 then
                        local camOrigin = workspace.CurrentCamera.CFrame.Position
                        if (origin - camOrigin).Magnitude >= 1 then
                            local newDir = (target.Position - origin).Unit * 5000
                            return oldNamecall(self, origin, newDir, p3)
                        end
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
end

-- ==========================================
-- FUNCIONES DE SONIDO
-- ==========================================
local function playSound(url)
  if type(url) ~= "string" or url == "" then return end
  local asset = soundCache[url]
  if not asset then
    if writefile and isfile and getcustomasset then
      local name = "nevada_" .. (url:match("([^/]+)$") or "sound.mp3")
      name = name:gsub("[^%w%._%-]", "_")
      if not isfile(name) then
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok or type(body) ~= "string" or #body == 0 then return end
        local wrote = pcall(writefile, name, body); if not wrote then return end
      end
      local ok, result = pcall(getcustomasset, name)
      if not ok then return end
      asset = result
    else
      asset = url
    end
    soundCache[url] = asset
  end
  local s = Instance.new("Sound")
  s.SoundId, s.Volume, s.Parent = asset, 1, SoundService
  s:Play()
  s.Ended:Connect(function() s:Destroy() end)
  task.delay(20, function() if s.Parent then s:Destroy() end end)
end

-- ==========================================
-- INTERFAZ GRÁFICA COMPLETA (Optimizada)
-- ==========================================
if playerGui:FindFirstChild("NevadaV2") then playerGui.NevadaV2:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "NevadaV2", false, true
gui.Parent = playerGui

local C = {bg=Color3.fromRGB(7,10,17), panel=Color3.fromRGB(10,14,23), card=Color3.fromRGB(14,19,30), edge=Color3.fromRGB(48,59,78), text=Color3.fromRGB(241,245,255), sub=Color3.fromRGB(164,177,201), blue=Color3.fromRGB(120,157,224), green=Color3.fromRGB(50,220,153), red=Color3.fromRGB(200, 50, 50)}
local function create(class, props, parent)
  local obj = Instance.new(class)
  for k,v in pairs(props or {}) do obj[k] = v end
  obj.Parent = parent
  return obj
end
local function corner(obj, radius) create("UICorner", {CornerRadius=UDim.new(0,radius or 10)}, obj) end
local function stroke(obj, color, thickness) create("UIStroke", {Color=color or C.edge, Thickness=thickness or 1, Transparency=0.2}, obj) end
local function label(parent, text, size, pos, fontSize, color, bold)
  return create("TextLabel", {BackgroundTransparency=1, Text=text, Size=size, Position=pos, Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize=fontSize or 14, TextColor3=color or C.text, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, TextWrapped=true}, parent)
end
local function button(parent, text, size, pos, callback)
  local b=create("TextButton", {Size=size, Position=pos, BackgroundColor3=C.card, Text=text, TextColor3=C.text, Font=Enum.Font.GothamMedium, TextSize=13, AutoButtonColor=true}, parent)
  corner(b,8); stroke(b)
  b.MouseButton1Click:Connect(callback)
  return b
end

local window
local openButton
openButton = button(gui,"NEVADA",UDim2.fromOffset(94,34),UDim2.new(0,14,0.18,0),function() if window then window.Visible=true; openButton.Visible=false end end)
window = create("Frame", {Size=UDim2.new(0.94,0,0.84,0), Position=UDim2.new(0.03,0,0.08,0), BackgroundColor3=C.bg, BorderSizePixel=0, ClipsDescendants=true},gui)
corner(window,16); stroke(window,C.edge,1.3)
local scale = create("UIScale", {Scale=1}, window)
local function fitScale()
  local camera=workspace.CurrentCamera; if not camera then return end
  local v=camera.ViewportSize
  scale.Scale=math.clamp(math.min(v.X/1100,v.Y/680),0.58,1)
end
fitScale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale) end

local sidebar=create("Frame",{Size=UDim2.new(0,190,1,0),BackgroundColor3=Color3.fromRGB(6,9,15),BorderSizePixel=0},window)
local divider=create("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.new(0,190,0,0),BackgroundColor3=C.edge,BorderSizePixel=0},window)
label(sidebar,"▲",UDim2.new(1,0,0,48),UDim2.new(0,0,0,20),29,C.text,true).TextXAlignment=Enum.TextXAlignment.Center
label(sidebar,"N E V A D A",UDim2.new(1,0,0,34),UDim2.new(0,0,0,63),21,C.text,true).TextXAlignment=Enum.TextXAlignment.Center
label(sidebar,"V2",UDim2.new(1,0,0,20),UDim2.new(0,0,0,96),12,C.sub,false).TextXAlignment=Enum.TextXAlignment.Center
local navHolder=create("Frame",{Size=UDim2.new(1,-18,0,220),Position=UDim2.new(0,9,0,140),BackgroundTransparency=1},sidebar)
create("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},navHolder)
label(sidebar,"NEVADA V2\nTu experiencia, sin límites.",UDim2.new(1,-24,0,48),UDim2.new(0,12,1,-62),11,C.sub,false)

local top=create("Frame",{Size=UDim2.new(1,-210,0,68),Position=UDim2.new(0,205,0,0),BackgroundTransparency=1},window)
label(top,"▲",UDim2.fromOffset(48,55),UDim2.new(0,0,0,4),28,C.text,true)
local pageTitle=label(top,"Bienvenido a Nevada",UDim2.new(1,-110,0,30),UDim2.new(0,54,0,10),21,C.text,true)
local pageSubtitle=label(top,"Tu hub todo en uno. Macros, sonidos y más.",UDim2.new(1,-80,0,25),UDim2.new(0,54,0,38),12,C.sub,false)
local minimize=button(window,"—",UDim2.fromOffset(34,30),UDim2.new(1,-80,0,10),function() window.Visible=false; openButton.Visible=true end)
local close=button(window,"×",UDim2.fromOffset(34,30),UDim2.new(1,-42,0,10),function() gui:Destroy() end)
openButton.Visible=false

local dragging, dragStart, startPos = false, nil, nil
local dragArea=top
dragArea.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
    dragging=true; dragStart=input.Position; startPos=window.Position
    input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
  end
end)
UserInputService.InputChanged:Connect(function(input)
  if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
    local d=input.Position-dragStart
    window.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
  end
end)

local content=create("Frame",{Size=UDim2.new(1,-210,1,-82),Position=UDim2.new(0,205,0,72),BackgroundTransparency=1},window)
local pages={}
local function newPage(name)
  local p=create("ScrollingFrame",{Name=name,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.blue,Visible=false,CanvasSize=UDim2.new()},content)
  local l=create("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},p)
  l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() p.CanvasSize=UDim2.new(0,0,0,l.AbsoluteContentSize.Y+16) end)
  pages[name]=p; return p
end
local function card(parent,height)
  local f=create("Frame",{Size=UDim2.new(1,-8,0,height),BackgroundColor3=C.card,BorderSizePixel=0},parent); corner(f,11); stroke(f); return f
end
local function switch(parent,text,initial,callback,y)
  local row=card(parent,48); row.LayoutOrder=y or 1
  label(row,text,UDim2.new(1,-100,1,0),UDim2.new(0,14,0,0),14,C.text,true)
  local b
  b=button(row,initial and "ACTIVADO" or "DESACTIVADO",UDim2.fromOffset(92,30),UDim2.new(1,-104,0.5,-15),function()
    initial=not initial; b.Text=initial and "ACTIVADO" or "DESACTIVADO"; b.BackgroundColor3=initial and C.blue or C.card; callback(initial)
  end)
  b.BackgroundColor3=initial and C.blue or C.card
  return b
end
local function actionCard(parent,title,desc,btnText,fn)
  local f=card(parent,70); label(f,title,UDim2.new(0.66,0,0,27),UDim2.new(0,14,0,7),14,C.text,true); label(f,desc,UDim2.new(0.66,0,0,25),UDim2.new(0,14,0,35),11,C.sub,false)
  button(f,btnText,UDim2.fromOffset(125,34),UDim2.new(1,-139,0.5,-17),fn); return f
end
local function slider(parent,title,minV,maxV,initial,callback)
  local f=card(parent,72); local value=initial
  local txt=label(f,title..": "..tostring(value),UDim2.new(1,-24,0,25),UDim2.new(0,13,0,6),13,C.text,true)
  local bar=button(f,"",UDim2.new(1,-28,0,12),UDim2.new(0,14,0,43),function() end); bar.BackgroundColor3=Color3.fromRGB(33,42,59)
  local fill=create("Frame",{Size=UDim2.new((value-minV)/(maxV-minV),0,1,0),BackgroundColor3=C.blue,BorderSizePixel=0},bar); corner(fill,5)
  local function setFromX(x)
    local p=math.clamp((x-bar.AbsolutePosition.X)/math.max(bar.AbsoluteSize.X,1),0,1); value=math.floor((minV+p*(maxV-minV))*100)/100; fill.Size=UDim2.new(p,0,1,0); txt.Text=title..": "..tostring(value); callback(value)
  end
  bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then setFromX(i.Position.X) end end)
end

local showPage
local home=newPage("Inicio")
local welcome=card(home,108); label(welcome,"Bienvenido a Nevada",UDim2.new(1,-26,0,32),UDim2.new(0,14,0,13),20,C.text,true); label(welcome,"Tu hub todo en uno. Macros, sonidos y más.\nInterfaz Nevada V2",UDim2.new(1,-26,0,45),UDim2.new(0,14,0,51),12,C.sub,false)
actionCard(home,"Sonidos","Catálogo de tu repositorio de GitHub","Abrir sonidos",function() showPage("Sonidos") end)
actionCard(home,"Macro Arma","Disparo rápido automático","Ver macro",function() showPage("Macro") end)
actionCard(home,"Macro Cuchillo","Lanzamiento rápido (L2)","Ver macro",function() showPage("Cuchillo") end)
actionCard(home,"Macro 360","Disparo invisible a todo el cuerpo","Ver Macro 360",function() showPage("Macro360") end)

local macroPage=newPage("Macro")
switch(macroPage,"Activar macro de arma",false,function(v) state.macro=v end)
slider(macroPage,"Tiempo de equipar",0.01,0.50,state.equipDelay,function(v) state.equipDelay=v end)
slider(macroPage,"Tiempo de disparo",0.01,0.50,state.shootDelay,function(v) state.shootDelay=v end)

local knifePage=newPage("Cuchillo")
switch(knifePage,"Activar Macro Cuchillo (L2)",false,function(v) state.knifeMacroEnabled = v end)
slider(knifePage,"Delay al Equipar",0.01,0.50,state.knifeEquipDelay,function(v) state.knifeEquipDelay = v end)
slider(knifePage,"Delay al Lanzar",0.01,0.50,state.knifeThrowDelay,function(v) state.knifeThrowDelay = v end)

-- MACRO 360
local macro360Page = newPage("Macro360")
local toggle360MenuBtn = nil
local floatingBtn = nil

local function setMacro360State(nuevoEstado)
    state.macro360Enabled = nuevoEstado
    if toggle360MenuBtn then
        toggle360MenuBtn.Text = nuevoEstado and "ACTIVADO" or "DESACTIVADO"
        toggle360MenuBtn.BackgroundColor3 = nuevoEstado and C.blue or C.card
    end
    if floatingBtn then
        if nuevoEstado then
            floatingBtn.Text = "MACRO 360: ON"
            floatingBtn.BackgroundColor3 = C.green
            for _,v in pairs(floatingBtn:GetChildren()) do if v:IsA("UIStroke") then v.Color = C.green end end
        else
            floatingBtn.Text = "MACRO 360: OFF"
            floatingBtn.BackgroundColor3 = C.red
            for _,v in pairs(floatingBtn:GetChildren()) do if v:IsA("UIStroke") then v.Color = C.red end end
        end
    end
end

toggle360MenuBtn = switch(macro360Page, "Activar Auto Shoot / Macro 360", false, function(v) setMacro360State(v) end)
slider(macro360Page, "Tamaño del FOV", 10, 500, state.macro360Fov, function(v) state.macro360Fov = v end)
slider(macro360Page, "Probabilidad de acierto (%)", 1, 100, state.macro360HitChance, function(v) state.macro360HitChance = v end)
slider(macro360Page, "Tiempo de reacción (s)", 0, 1, state.macro360Reaction, function(v) state.macro360Reaction = v end)
slider(macro360Page, "Delay entre Disparos (s)", 0.01, 1.0, state.macro360Cooldown, function(v) state.macro360Cooldown = v end)

-- BOTÓN FLOTANTE
floatingBtn = create("TextButton", {Size = UDim2.new(0, 120, 0, 45), Position = UDim2.new(0, 20, 0.5, 0), BackgroundColor3 = C.red, Text = "MACRO 360: OFF", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, ZIndex = 100}, gui)
corner(floatingBtn, 8); stroke(floatingBtn, C.red, 1, 0.5)

local draggingBtn = false
local dragStartBtn, startPosBtn
floatingBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingBtn = true; dragStartBtn = input.Position; startPosBtn = floatingBtn.Position end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingBtn and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartBtn
        floatingBtn.Position = UDim2.new(startPosBtn.X.Scale, startPosBtn.X.Offset + delta.X, startPosBtn.Y.Scale, startPosBtn.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingBtn = false end end)
floatingBtn.MouseButton1Click:Connect(function() setMacro360State(not state.macro360Enabled) end)

-- SONIDOS (Carga optimizada)
local soundsPage=newPage("Sonidos")
local categoryBar=card(soundsPage,44)
local categoryButtons={}
local soundListFrame=card(soundsPage,330)
local listSearch=create("TextBox",{Size=UDim2.new(1,-20,0,34),Position=UDim2.new(0,10,0,9),BackgroundColor3=C.panel,Text="",PlaceholderText="Buscar sonido...",PlaceholderColor3=C.sub,TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=13,ClearTextOnFocus=false},soundListFrame); corner(listSearch,8); stroke(listSearch)
local list=create("ScrollingFrame",{Size=UDim2.new(1,-16,1,-54),Position=UDim2.new(0,8,0,48),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new()},soundListFrame)
local listLayout=create("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},list)
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() list.CanvasSize=UDim2.new(0,0,0,listLayout.AbsoluteContentSize.Y+8) end)
local soundDetails=card(soundsPage,168)
local selectedTitle=label(soundDetails,"Seleccionado: Ninguno",UDim2.new(1,-24,0,28),UDim2.new(0,12,0,8),15,C.text,true)
local selectedFile=label(soundDetails,"Archivo: —",UDim2.new(1,-24,0,24),UDim2.new(0,12,0,38),12,C.sub,false)
local function refreshDetails()
  local s=state.selected[soundCategory]; selectedTitle.Text="Seleccionado: "..s.Name; selectedFile.Text="Archivo: "..(s.URL:match("([^/]+)$") or "—")
end
local function clearSoundRows() for _,ch in ipairs(list:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end end
local function refreshSoundList()
  clearSoundRows(); local q=listSearch.Text:lower()
  for _,s in ipairs(sounds) do
    if q=="" or s.Name:lower():find(q,1,true) then
      local row=create("Frame",{Size=UDim2.new(1,-4,0,43),BackgroundColor3=C.panel,BorderSizePixel=0},list); corner(row,7)
      label(row,s.Name,UDim2.new(0.55,0,1,0),UDim2.new(0,10,0,0),13,C.text,true)
      button(row,"▶ Probar",UDim2.fromOffset(82,29),UDim2.new(1,-176,0.5,-14),function() playSound(s.URL) end)
      button(row,"Elegir",UDim2.fromOffset(76,29),UDim2.new(1,-86,0.5,-14),function()
        state.selected[soundCategory]={Name=s.Name,URL=s.URL}; refreshDetails()
      end)
    end
  end
end
listSearch:GetPropertyChangedSignal("Text"):Connect(refreshSoundList)
local function makeCategory(name,x)
  local b=button(categoryBar,name,UDim2.new(1/3,-8,0,32),UDim2.new(x,4,0.5,-16),function()
    soundCategory=name; refreshDetails(); refreshSoundList()
    for k,v in pairs(categoryButtons) do v.BackgroundColor3=(k==name) and C.blue or C.card end
  end)
  categoryButtons[name]=b
end
makeCategory("Arma",0); makeCategory("Saltar",1/3); makeCategory("Matar",2/3)
local soundToggle=switch(soundsPage,"Activar este sonido",true,function(v) state.enabled[soundCategory]=v end)
local muteToggle=switch(soundsPage,"Silenciar este sonido",false,function(v) state.muted[soundCategory]=v end)
local githubStatus=label(soundsPage,"Catálogo: buscando archivos MP3 en GitHub…",UDim2.new(1,-8,0,28),UDim2.new(0,4,0,0),12,C.sub,false)

local configPage=newPage("Configuración")
actionCard(configPage,"Guardar configuración","Guarda selección de sonidos y opciones","Guardar",function()
  if not (writefile and isfile) then githubStatus.Text="Guardar: este ejecutor no ofrece writefile."; return end
  local ok, encoded=pcall(function() return HttpService:JSONEncode(state) end)
  if ok and pcall(writefile,CONFIG_FILE,encoded) then githubStatus.Text="Configuración guardada." else githubStatus.Text="No se pudo guardar." end
end)
actionCard(configPage,"Cargar configuración","Restaura los valores guardados","Cargar",function()
  if not (readfile and isfile) or not isfile(CONFIG_FILE) then githubStatus.Text="No hay configuración guardada."; return end
  local ok, decoded=pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
  if ok and type(decoded)=="table" then
    if type(decoded.macro)=="boolean" then state.macro=decoded.macro end
    if type(decoded.knifeMacroEnabled)=="boolean" then state.knifeMacroEnabled=decoded.knifeMacroEnabled end
    if type(decoded.macro360Enabled)=="boolean" then state.macro360Enabled=decoded.macro360Enabled end
    if tonumber(decoded.macro360Fov) then state.macro360Fov=math.clamp(decoded.macro360Fov,10,500) end
    if tonumber(decoded.macro360HitChance) then state.macro360HitChance=math.clamp(decoded.macro360HitChance,1,100) end
    if tonumber(decoded.macro360Reaction) then state.macro360Reaction=math.clamp(decoded.macro360Reaction,0,1) end
    if tonumber(decoded.macro360Cooldown) then state.macro360Cooldown=math.clamp(decoded.macro360Cooldown,0.01,1.0) end
    if tonumber(decoded.equipDelay) then state.equipDelay=math.clamp(decoded.equipDelay,0.01,0.5) end
    if tonumber(decoded.shootDelay) then state.shootDelay=math.clamp(decoded.shootDelay,0.01,0.5) end
    if tonumber(decoded.knifeEquipDelay) then state.knifeEquipDelay=math.clamp(decoded.knifeEquipDelay,0.01,0.5) end
    if tonumber(decoded.knifeThrowDelay) then state.knifeThrowDelay=math.clamp(decoded.knifeThrowDelay,0.01,0.5) end
    for _,k in ipairs({"Arma","Saltar","Matar"}) do
      if type(decoded.selected)=="table" and type(decoded.selected[k])=="table" then state.selected[k]=decoded.selected[k] end
      if type(decoded.enabled)=="table" and type(decoded.enabled[k])=="boolean" then state.enabled[k]=decoded.enabled[k] end
      if type(decoded.muted)=="table" and type(decoded.muted[k])=="boolean" then state.muted[k]=decoded.muted[k] end
    end
    refreshDetails(); refreshSoundList(); githubStatus.Text="Configuración cargada."
  else githubStatus.Text="Archivo inválido." end
end)
actionCard(configPage,"Actualizar catálogo","Vuelve a consultar GitHub","Actualizar",function() if refreshCatalog then task.spawn(refreshCatalog) end end)

local navNames={"Inicio","Macro","Cuchillo","Macro360","Sonidos","Configuración"}
local navIcons={Inicio="⌂",Macro="◎",Cuchillo="🔪",Macro360="🎯",Sonidos="♫",["Configuración"]="⚙"}
showPage=function(name)
  activeTab=name
  for n,p in pairs(pages) do p.Visible=(n==name) end
  pageTitle.Text=(name=="Inicio") and "Bienvenido a Nevada" or name
  pageSubtitle.Text=(name=="Inicio") and "Tu hub todo en uno. Macros, sonidos y más." or "Nevada V2 — controles y ajustes"
  for _,obj in ipairs(navHolder:GetChildren()) do if obj:IsA("TextButton") then obj.BackgroundColor3=(obj.Name==name) and Color3.fromRGB(29,39,57) or Color3.fromRGB(6,9,15) end end
end
for i,name in ipairs(navNames) do
  local b=button(navHolder,navIcons[name].."   "..name,UDim2.new(1,0,0,43),UDim2.new(),function() showPage(name) end)
  b.Name=name; b.LayoutOrder=i; b.TextXAlignment=Enum.TextXAlignment.Left; b.TextSize=14; b.BackgroundColor3=(name=="Inicio") and Color3.fromRGB(29,39,57) or Color3.fromRGB(6,9,15); b.Position=UDim2.new()
end
showPage("Inicio")

-- ==========================================
-- LÓGICA DE MACROS Y BUCLE
-- ==========================================
local macroBusy=false
local function runMacro()
  if not state.macro or macroBusy then return end
  local char=player.Character; if not char then return end
  local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return end
  local backpack=player:FindFirstChildOfClass("Backpack"); if not backpack then return end
  local tool=char:FindFirstChildOfClass("Tool")
  if not tool then
    for _,item in ipairs(backpack:GetChildren()) do
      if item:IsA("Tool") then tool=item; break end
    end
  end
  if not tool then return end
  macroBusy=true
  task.spawn(function()
    pcall(function()
      if tool.Parent==backpack then hum:EquipTool(tool); task.wait(state.equipDelay) end
      if tool.Parent==char then tool:Activate(); task.wait(state.shootDelay); pcall(function() tool:Deactivate() end) end
      pcall(function() hum:UnequipTools() end)
    end)
    macroBusy=false
  end)
end

local knifeBusy = false
local function runKnifeMacro()
  if not state.knifeMacroEnabled or knifeBusy then return end
  local character = player.Character
  local humanoid = character and character:FindFirstChildOfClass("Humanoid")
  local knife = nil
  for _, item in ipairs(character:GetChildren()) do if item:IsA("Tool") and item:FindFirstChild("Throw") then knife = item break end end
  if not knife and character:FindFirstChildOfClass("Backpack") then
      for _, item in ipairs(character:FindFirstChildOfClass("Backpack"):GetChildren()) do if item:IsA("Tool") and item:FindFirstChild("Throw") then knife = item break end end
  end
  if not (knife and humanoid) then return end
  
  knifeBusy = true
  task.spawn(function()
    pcall(function()
        if knife.Parent ~= character then humanoid:EquipTool(knife); task.wait(0.1) end
        pcall(function() knife:Activate() end)
        task.wait(state.knifeThrowDelay)
        pcall(function() if humanoid and humanoid.Parent then humanoid:UnequipTools() end end)
    end)
    knifeBusy = false
  end)
end

UserInputService.InputBegan:Connect(function(input, processed)
  if processed then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.KeyCode==Enum.KeyCode.ButtonR2 then runMacro() end
  if input.KeyCode == Enum.KeyCode.L2 then runKnifeMacro() end
end)

task.spawn(function()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    while task.wait(0.05) do 
        if state.macro360Enabled and not estaEnLobby() then
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local bestPart, bestDist = nil, math.huge
            local myPos = char.HumanoidRootPart.Position
            for _, p in ipairs(Players:GetPlayers()) do
                if isEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local eHum = p.Character:FindFirstChildOfClass("Humanoid")
                    if eHum and eHum.Health > 0 and not p.Character:FindFirstChildOfClass("ForceField") then
                        local dist = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
                        if dist < state.macro360Fov and dist < bestDist then
                            params.FilterDescendantsInstances = { char, p.Character }
                            local ray = workspace:Raycast(myPos, p.Character.HumanoidRootPart.Position - myPos, params)
                            if not ray then
                                for _, part in ipairs(p.Character:GetChildren()) do
                                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Humanoid" then
                                        local partDist = (part.Position - myPos).Magnitude
                                        if partDist < bestDist then
                                            local pRay = workspace:Raycast(myPos, part.Position - myPos, params)
                                            if not pRay or pRay.Instance:IsDescendantOf(p.Character) then bestDist = partDist; bestPart = part end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if bestPart then
                local backpack = player:FindFirstChildOfClass("Backpack")
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and not esPistola(tool) then tool = nil end
                if not tool and backpack then for _, item in ipairs(backpack:GetChildren()) do if esPistola(item) then tool = item; break end end end
                if tool then
                    local wasEq = (tool.Parent == char)
                    if not wasEq then hum:EquipTool(tool); task.wait(0.05) end
                    if tool.Parent == char then
                        getgenv().NevadaTargetPart = bestPart
                        pcall(function() tool:Activate() end)
                        task.wait(0.05)
                        pcall(function() tool:Deactivate() end)
                        getgenv().NevadaTargetPart = nil
                        if not wasEq then pcall(function() hum:UnequipTools() end) end
                    end
                end
                task.wait(state.macro360Cooldown)
            end
        end
    end
end)
