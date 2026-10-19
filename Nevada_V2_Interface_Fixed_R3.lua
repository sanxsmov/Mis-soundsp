-- ==========================================
-- 1. EVASIÓN Y FLAGS (BYPASS)
-- ==========================================
pcall(function()
    local setthread = setthreadidentity or set_thread_identity or setidentity
    if setthread then pcall(function() setthread(8) end) end
    
    if setfflag then
        setfflag("DFIntTaskSchedulerTargetFps", "240")
        setfflag("FFlagDisablePostFx", "True")
        setfflag("FFlagRemoveFog", "True")
        setfflag("FIntRenderShadowIntensity", "0")
    end
end)

-- ==========================================
-- 2. SCRIPT PRINCIPAL (NEVADA V2)
-- ==========================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local requestFn = (syn and syn.request) or (http and http.request) or request or http_request

local OWNER, REPO, BRANCH = "sanxsmov", "Mis-soundsp", "main"
local FOLDERS = {"sounds", "SoundsV2"}
local RAW = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. BRANCH .. "/"
local API_ROOT = "https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/contents/"
local CONFIG_FILE = "nevada_v2_config.json"

local state = {
  macro = false, equipDelay = 0.05, shootDelay = 0.10,
  selected = {Arma={Name="Ninguno",URL=""}, Saltar={Name="Ninguno",URL=""}, Matar={Name="Ninguno",URL=""}},
  enabled = {Arma=true, Saltar=true, Matar=true}, muted = {Arma=false, Saltar=false, Matar=false},
  folder = FOLDERS[1]
}
local sounds, soundCache, activeTab, soundCategory = {}, {}, "Inicio", "Arma"
local refreshCatalog
local connections = {}
local isUnloaded = false
local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

-- FUNCIÓN DE AUDIO (Soporta HTTP, IDs y Assets Locales)
local function playSound(url)
  if isUnloaded or type(url) ~= "string" or url == "" or url == "Ninguno" then return end
  local finalAssetId = url
  if string.find(url, "http") and not string.find(url, "rbxassetid://") then
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
      else asset = url end
      soundCache[url] = asset
    end
    finalAssetId = asset
  elseif string.match(url, "^%d+$") then
    finalAssetId = "rbxassetid://" .. url
  end
  local s = Instance.new("Sound")
  s.SoundId = finalAssetId; s.Volume = 1; s.Parent = SoundService
  s:Play(); s.Ended:Connect(function() s:Destroy() end)
  task.delay(20, function() if s.Parent then s:Destroy() end end)
end

-- INTERFAZ GRÁFICA
if playerGui:FindFirstChild("NevadaV2") then playerGui.NevadaV2:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "NevadaV2", false, true
gui.Parent = playerGui
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)

local C = {bg=Color3.fromRGB(7,10,17), panel=Color3.fromRGB(10,14,23), card=Color3.fromRGB(14,19,30), edge=Color3.fromRGB(48,59,78), text=Color3.fromRGB(241,245,255), sub=Color3.fromRGB(164,177,201), blue=Color3.fromRGB(120,157,224)}
local function create(class, props, parent) local obj = Instance.new(class); for k,v in pairs(props or {}) do obj[k] = v end; obj.Parent = parent; return obj end
local function corner(obj, radius) create("UICorner", {CornerRadius=UDim.new(0,radius or 10)}, obj) end
local function stroke(obj, color, thickness) create("UIStroke", {Color=color or C.edge, Thickness=thickness or 1, Transparency=0.2}, obj) end
local function label(parent, text, size, pos, fontSize, color, bold) return create("TextLabel", {BackgroundTransparency=1, Text=text, Size=size, Position=pos, Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize=fontSize or 14, TextColor3=color or C.text, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, TextWrapped=true}, parent) end
local function button(parent, text, size, pos, callback) local b=create("TextButton", {Size=size, Position=pos, BackgroundColor3=C.card, Text=text, TextColor3=C.text, Font=Enum.Font.GothamMedium, TextSize=13, AutoButtonColor=true}, parent); corner(b,8); stroke(b); b.MouseButton1Click:Connect(callback); return b end

local window, openButton
openButton = button(gui,"NEVADA",UDim2.fromOffset(94,34),UDim2.new(0,14,0.18,0),function() if window and not isUnloaded then window.Visible=true; openButton.Visible=false end end)
window = create("Frame", {Size=UDim2.new(0.94,0,0.84,0), Position=UDim2.new(0.03,0,0.08,0), BackgroundColor3=C.bg, BorderSizePixel=0, ClipsDescendants=true},gui)
corner(window,16); stroke(window,C.edge,1.3)
local scale = create("UIScale", {Scale=1}, window)
local function fitScale() local v=camera.ViewportSize; scale.Scale=math.clamp(math.min(v.X/1100,v.Y/680),0.58,1) end
fitScale(); connections[#connections+1] = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)

local sidebar=create("Frame",{Size=UDim2.new(0,190,1,0),BackgroundColor3=Color3.fromRGB(6,9,15),BorderSizePixel=0},window)
local divider=create("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.new(0,190,0,0),BackgroundColor3=C.edge,BorderSizePixel=0},window)
label(sidebar,"▲",UDim2.new(1,0,0,48),UDim2.new(0,0,0,20),29,C.text,true).TextXAlignment=Enum.TextXAlignment.Center
label(sidebar,"N E V A D A",UDim2.new(1,0,0,34),UDim2.new(0,0,0,63),21,C.text,true).TextXAlignment=Enum.TextXAlignment.Center
local navHolder=create("Frame",{Size=UDim2.new(1,-18,0,220),Position=UDim2.new(0,9,0,140),BackgroundTransparency=1},sidebar)
create("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},navHolder)

local top=create("Frame",{Size=UDim2.new(1,-210,0,68),Position=UDim2.new(0,205,0,0),BackgroundTransparency=1},window)
local pageTitle=label(top,"Bienvenido a Nevada",UDim2.new(1,-110,0,30),UDim2.new(0,54,0,10),21,C.text,true)
local minimize=button(window,"—",UDim2.fromOffset(34,30),UDim2.new(1,-80,0,10),function() if not isUnloaded then window.Visible=false; openButton.Visible=true end end)
local close=button(window,"×",UDim2.fromOffset(34,30),UDim2.new(1,-42,0,10),function() if not isUnloaded then state.macro = false; window.Visible = false; openButton.Visible = true end end)
openButton.Visible=false

local dragging, dragStart, startPos = false, nil, nil
local dragArea=top
dragArea.InputBegan:Connect(function(input) if isUnloaded then return end; if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true; dragStart=input.Position; startPos=window.Position; input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end) end end)
connections[#connections+1] = UserInputService.InputChanged:Connect(function(input) if isUnloaded then return end; if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then local d=input.Position-dragStart; window.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)

local content=create("Frame",{Size=UDim2.new(1,-210,1,-82),Position=UDim2.new(0,205,0,72),BackgroundTransparency=1},window)
local pages={}
local function newPage(name) local p=create("ScrollingFrame",{Name=name,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.blue,Visible=false,CanvasSize=UDim2.new()},content); local l=create("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},p); connections[#connections+1] = l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() p.CanvasSize=UDim2.new(0,0,0,l.AbsoluteContentSize.Y+16) end); pages[name]=p; return p end
local function card(parent,height) local f=create("Frame",{Size=UDim2.new(1,-8,0,height),BackgroundColor3=C.card,BorderSizePixel=0},parent); corner(f,11); stroke(f); return f end
local function switch(parent,text,initial,callback,y) local row=card(parent,48); row.LayoutOrder=y or 1; label(row,text,UDim2.new(1,-100,1,0),UDim2.new(0,14,0,0),14,C.text,true); local b; b=button(row,initial and "ACTIVADO" or "DESACTIVADO",UDim2.fromOffset(92,30),UDim2.new(1,-104,0.5,-15),function() if isUnloaded then return end; initial=not initial; b.Text=initial and "ACTIVADO" or "DESACTIVADO"; b.BackgroundColor3=initial and C.blue or C.card; callback(initial) end); b.BackgroundColor3=initial and C.blue or C.card; return b end
local function actionCard(parent,title,desc,btnText,fn) local f=card(parent,70); label(f,title,UDim2.new(0.66,0,0,27),UDim2.new(0,14,0,7),14,C.text,true); label(f,desc,UDim2.new(0.66,0,0,25),UDim2.new(0,14,0,35),11,C.sub,false); button(f,btnText,UDim2.fromOffset(125,34),UDim2.new(1,-139,0.5,-17),fn); return f end

local showPage
local home=newPage("Inicio")
local welcome=card(home,108); label(welcome,"Bienvenido a Nevada",UDim2.new(1,-26,0,32),UDim2.new(0,14,0,13),20,C.text,true); label(welcome,"Tu hub todo en uno. Macros, sonidos y más.\nInterfaz Nevada V2",UDim2.new(1,-26,0,45),UDim2.new(0,14,0,51),12,C.sub,false)
actionCard(home,"Sonidos","Catálogo de tu repositorio de GitHub","Abrir sonidos",function() showPage("Sonidos") end)
actionCard(home,"Macro","Control de activación y tiempos","Ver macro",function() showPage("Macro") end)

local macroPage=newPage("Macro")
switch(macroPage,"Activar macro",false,function(v) state.macro=v end)
local function slider(parent,title,minV,maxV,initial,callback)
  local f=card(parent,72); local value=initial
  local txt=label(f,title..": "..string.format("%.2f s",value),UDim2.new(1,-24,0,25),UDim2.new(0,13,0,6),13,C.text,true)
  local bar=button(f,"",UDim2.new(1,-28,0,12),UDim2.new(0,14,0,43),function() end); bar.BackgroundColor3=Color3.fromRGB(33,42,59)
  local fill=create("Frame",{Size=UDim2.new((value-minV)/(maxV-minV),0,1,0),BackgroundColor3=C.blue,BorderSizePixel=0},bar); corner(fill,5)
  local function setFromX(x) if isUnloaded then return end; local p=math.clamp((x-bar.AbsolutePosition.X)/math.max(bar.AbsoluteSize.X,1),0,1); value=round2(minV+p*(maxV-minV)); fill.Size=UDim2.new(p,0,1,0); txt.Text=title..": "..string.format("%.2f s",value); callback(value) end
  bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then setFromX(i.Position.X) end end)
  connections[#connections+1] = UserInputService.InputChanged:Connect(function(i) if isUnloaded then return end; if i.UserInputType==Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then setFromX(i.Position.X) end end)
end
slider(macroPage,"Tiempo de equipar",0.01,0.50,state.equipDelay,function(v) state.equipDelay=v end)
slider(macroPage,"Tiempo de disparo",0.01,0.50,state.shootDelay,function(v) state.shootDelay=v end)

local soundsPage=newPage("Sonidos")
local categoryBar=card(soundsPage,44)
local categoryButtons={}
local soundListFrame=card(soundsPage,330)
local listSearch=create("TextBox",{Size=UDim2.new(1,-20,0,34),Position=UDim2.new(0,10,0,9),BackgroundColor3=C.panel,Text="",PlaceholderText="Buscar sonido...",PlaceholderColor3=C.sub,TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=13,ClearTextOnFocus=false},soundListFrame); corner(listSearch,8); stroke(listSearch)
local list=create("ScrollingFrame",{Size=UDim2.new(1,-16,1,-54),Position=UDim2.new(0,8,0,48),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new()},soundListFrame)
local listLayout=create("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},list)
connections[#connections+1] = listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() list.CanvasSize=UDim2.new(0,0,0,listLayout.AbsoluteContentSize.Y+8) end)
local soundDetails=card(soundsPage,168)
local selectedTitle=label(soundDetails,"Seleccionado: Ninguno",UDim2.new(1,-24,0,28),UDim2.new(0,12,0,8),15,C.text,true)
local selectedFile=label(soundDetails,"Archivo: —",UDim2.new(1,-24,0,24),UDim2.new(0,12,0,38),12,C.sub,false)
local function refreshDetails() local s=state.selected[soundCategory]; selectedTitle.Text="Seleccionado: "..s.Name; selectedFile.Text="Archivo: "..(s.URL:match("([^/]+)$") or "—") end
local function clearSoundRows() for _,ch in ipairs(list:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end end
local function refreshSoundList()
  if isUnloaded then return end
  clearSoundRows(); local q=listSearch.Text:lower()
  for _,s in ipairs(sounds) do
    if q=="" or s.Name:lower():find(q,1,true) then
      local row=create("Frame",{Size=UDim2.new(1,-4,0,43),BackgroundColor3=C.panel,BorderSizePixel=0},list); corner(row,7)
      label(row,s.Name,UDim2.new(0.55,0,1,0),UDim2.new(0,10,0,0),13,C.text,true)
      button(row,"▶ Probar",UDim2.fromOffset(82,29),UDim2.new(1,-176,0.5,-14),function() if not isUnloaded then playSound(s.URL) end end)
      button(row,"Elegir",UDim2.fromOffset(76,29),UDim2.new(1,-86,0.5,-14),function() if isUnloaded then return end; state.selected[soundCategory]={Name=s.Name,URL=s.URL}; refreshDetails() end)
    end
  end
end
connections[#connections+1] = listSearch:GetPropertyChangedSignal("Text"):Connect(refreshSoundList)
local function makeCategory(name,x) local b=button(categoryBar,name,UDim2.new(1/3,-8,0,32),UDim2.new(x,4,0.5,-16),function() if isUnloaded then return end; soundCategory=name; refreshDetails(); refreshSoundList(); for k,v in pairs(categoryButtons) do v.BackgroundColor3=(k==name) and C.blue or C.card end end); categoryButtons[name]=b end
makeCategory("Arma",0); makeCategory("Saltar",1/3); makeCategory("Matar",2/3)
local soundToggle=switch(soundsPage,"Activar este sonido",true,function(v) state.enabled[soundCategory]=v end)
local muteToggle=switch(soundsPage,"Silenciar este sonido",false,function(v) state.muted[soundCategory]=v end)
local githubStatus=label(soundsPage,"Catálogo: buscando archivos MP3 en GitHub…",UDim2.new(1,-8,0,28),UDim2.new(0,4,0,0),12,C.sub,false)

local configPage=newPage("Configuración")
actionCard(configPage,"Cerrar Script (Unload)","Destruye la interfaz y detiene todas las funciones","Unload",function() if isUnloaded then return end; isUnloaded = true; state.macro = false; for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end; pcall(function() gui:Destroy() end) end)

local navNames={"Inicio","Macro","Sonidos","Configuración"}
local navIcons={Inicio="⌂",Macro="◎",Sonidos="♫",["Configuración"]="⚙"}
showPage=function(name) if isUnloaded then return end; activeTab=name; for n,p in pairs(pages) do p.Visible=(n==name) end; pageTitle.Text=(name=="Inicio") and "Bienvenido a Nevada" or name; for _,obj in ipairs(navHolder:GetChildren()) do if obj:IsA("TextButton") then obj.BackgroundColor3=(obj.Name==name) and Color3.fromRGB(29,39,57) or Color3.fromRGB(6,9,15) end end end
for i,name in ipairs(navNames) do local b=button(navHolder,navIcons[name].."   "..name,UDim2.new(1,0,0,43),UDim2.new(),function() showPage(name) end); b.Name=name; b.LayoutOrder=i; b.TextXAlignment=Enum.TextXAlignment.Left; b.TextSize=14; b.BackgroundColor3=(name=="Inicio") and Color3.fromRGB(29,39,57) or Color3.fromRGB(6,9,15); b.Position=UDim2.new() end
showPage("Inicio")

local function fetchFolder(folder)
  if not requestFn then return false end
  local ok,res=pcall(function() return requestFn({Url=API_ROOT..folder,Method="GET",Headers={ ["User-Agent"]="NevadaV2" }}) end)
  if not ok or not res or (res.StatusCode~=200 and res.StatusCode~=201) or type(res.Body)~="string" then return false end
  local parsedOk,data=pcall(function() return HttpService:JSONDecode(res.Body) end)
  if not parsedOk or type(data)~="table" then return false end
  local found={}
  for _,item in ipairs(data) do if item.type=="file" and type(item.name)=="string" and item.name:lower():match("%.mp3$") then local url=item.download_url or (RAW..folder.."/"..item.name); table.insert(found,{Name=item.name:gsub("%.[Mm][Pp]3$",""),URL=url,File=item.name}) end end
  if #found>0 then sounds=found; state.folder=folder; return true end
  return false
end

refreshCatalog=function()
  if isUnloaded then return end
  githubStatus.Text="Catálogo: buscando archivos MP3 en GitHub…"
  local loaded=false
  for _,folder in ipairs(FOLDERS) do if fetchFolder(folder) then loaded=true; break end end
  table.sort(sounds,function(a,b) return a.Name:lower()<b.Name:lower() end)
  if not loaded then githubStatus.Text="No se pudo leer el catálogo." else githubStatus.Text="GitHub conectado · "..#sounds.." sonidos." end
  refreshSoundList()
end
task.spawn(refreshCatalog)

local boundTools={} local lastCustomShot=0
local function bindTool(tool) if isUnloaded or not tool:IsA("Tool") or boundTools[tool] then return end; boundTools[tool]=true end
local function setupCharacter(char)
  if isUnloaded then return end
  local hum=char:WaitForChild("Humanoid",5)
  if hum then connections[#connections+1] = hum.Jumping:Connect(function(jumping) if isUnloaded then return end; if jumping and state.enabled.Saltar and not state.muted.Saltar and state.selected.Saltar.URL~="" then playSound(state.selected.Saltar.URL) end end) end
  connections[#connections+1] = char.ChildAdded:Connect(bindTool)
  for _,obj in ipairs(char:GetChildren()) do bindTool(obj) end
end
if player.Character then setupCharacter(player.Character) end
connections[#connections+1] = player.CharacterAdded:Connect(setupCharacter)

local ORIGINAL_SHOT="10209603" local ORIGINAL_KILL="296102734"
local watchedSounds=setmetatable({}, {__mode="k"}) local mutedOriginals=setmetatable({}, {__mode="k"})
local function soundDigits(sound) return tostring(sound.SoundId or ""):match("(%d+)") end
local function isTargetShot(obj) local id=soundDigits(obj); if id==ORIGINAL_SHOT then return true end; return obj.Name:lower()=="gunshot" and obj:FindFirstAncestorWhichIsA("Tool")~=nil end
local function watchNativeSound(obj)
  if isUnloaded or not obj:IsA("Sound") or watchedSounds[obj] then return end
  watchedSounds[obj]=true
  local function check()
    if isUnloaded or not obj.Parent then return end
    local id=soundDigits(obj)
    local category=(isTargetShot(obj) and "Arma") or ((id==ORIGINAL_KILL or obj.Name:lower()=="gunkill") and "Matar" or nil)
    if not category then return end
    local custom=state.selected[category]
    if not state.enabled[category] or state.muted[category] or not custom or custom.URL=="" then return end
    if not mutedOriginals[obj] then mutedOriginals[obj]=obj.Volume; pcall(function() obj.Volume=0 end) elseif obj.Volume~=0 then pcall(function() obj.Volume=0 end) end
    if category=="Arma" then lastCustomShot=os.clock() end
    playSound(custom.URL)
  end
  connections[#connections+1] = obj.Played:Connect(function() task.defer(check) end)
  connections[#connections+1] = obj:GetPropertyChangedSignal("Playing"):Connect(function() if obj.Playing or obj.IsPlaying then task.defer(check) end end)
  connections[#connections+1] = obj:GetPropertyChangedSignal("SoundId"):Connect(function() task.defer(check) end)
  connections[#connections+1] = obj:GetPropertyChangedSignal("Name"):Connect(function() task.defer(check) end)
  connections[#connections+1] = obj:GetPropertyChangedSignal("Volume"):Connect(function() if mutedOriginals[obj]~=nil and obj.Parent and obj.Volume~=0 then pcall(function() obj.Volume=0 end) end end)
  if obj.IsPlaying or obj.Playing then task.defer(check) end
end
local function scanSoundTree(root) if isUnloaded or not root then return end; if root:IsA("Sound") then watchNativeSound(root) end; for _,obj in ipairs(root:GetDescendants()) do if obj:IsA("Sound") then watchNativeSound(obj) end end; connections[#connections+1] = root.DescendantAdded:Connect(watchNativeSound) end
scanSoundTree(workspace); scanSoundTree(SoundService); scanSoundTree(playerGui); scanSoundTree(workspace.CurrentCamera)
connections[#connections+1] = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() scanSoundTree(workspace.CurrentCamera) end)

-- MACRO ORIGINAL
local macroBusy=false local lastMacro=0
local function runMacro()
  if isUnloaded or not state.macro or macroBusy then return end
  local char=player.Character; if not char then return end
  local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return end
  local backpack=player:FindFirstChildOfClass("Backpack"); if not backpack then return end
  local tool=char:FindFirstChildOfClass("Tool")
  if not tool then for _,item in ipairs(backpack:GetChildren()) do if item:IsA("Tool") and (item.Name:lower():find("pistol") or item.Name:lower():find("gun") or item.Name:lower():find("sheriff") or item.Name:lower():find("revolver")) then tool=item; break end end end
  if not tool then return end
  local now=os.clock() local requiredGap=math.max(0.01, tonumber(state.shootDelay) or 0.10)
  if now-lastMacro<requiredGap then return end
  macroBusy=true; lastMacro=now
  task.spawn(function()
    local shouldHolster=false
    local ok,err=pcall(function()
      if isUnloaded or not state.macro or player.Character~=char then return end
      if tool.Parent==backpack then hum:EquipTool(tool); shouldHolster=true end
      task.wait(math.max(0.01, tonumber(state.equipDelay) or 0.05))
      if not isUnloaded and state.macro and player.Character==char and hum.Health>0 and tool.Parent==char then shouldHolster=true; tool:Activate(); task.wait(math.max(0.01, tonumber(state.shootDelay) or 0.10)); pcall(function() tool:Deactivate() end) end
    end)
    if not isUnloaded and shouldHolster and player.Character==char and hum.Parent==char then pcall(function() hum:UnequipTools() end) end
    macroBusy=false
  end)
end
connections[#connections+1] = UserInputService.InputBegan:Connect(function(input,processed) if isUnloaded or processed then return end; if input.UserInputType==Enum.UserInputType.MouseButton1 or input.KeyCode==Enum.KeyCode.ButtonR2 then runMacro() end end)

-- SONIDO DE MUERTE GLOBAL
local function setupGlobalDeathSound(targetPlayer)
    local function onCharacterAdded(character)
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then humanoid.Died:Connect(function() if state.enabled.Matar and not state.muted.Matar and state.selected.Matar.URL ~= "" then playSound(state.selected.Matar.URL) end end) end
    end
    if targetPlayer.Character then onCharacterAdded(targetPlayer.Character) end
    targetPlayer.CharacterAdded:Connect(onCharacterAdded)
end
for _, otherPlayer in ipairs(Players:GetPlayers()) do if otherPlayer ~= player then setupGlobalDeathSound(otherPlayer) end end
Players.PlayerAdded:Connect(function(newPlayer) if newPlayer ~= player then setupGlobalDeathSound(newPlayer) end end)

-- ==========================================
-- AUTO-SHOOT INDETECTABLE (SILENT AIM + VIRTUALUSER)
-- ==========================================
local autoAimActive = false
local autoShootCooldown = 0
local silentAimTarget = nil

-- Hook de Raycast con newcclosure (Oculto al anti-cheat)
local oldNamecall
if newcclosure then
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if not checkcaller() and silentAimTarget and silentAimTarget.Parent then
            local method = getnamecallmethod()
            if self == workspace and method == "Raycast" then
                local origin, direction, params = ...
                if typeof(direction) == "Vector3" and direction.Magnitude > 5 then
                    -- Jitter (Temblor humano)
                    local aimPos = silentAimTarget.Position + Vector3.new(math.random(-10, 10)/100, math.random(-10, 10)/100, math.random(-10, 10)/100)
                    return oldNamecall(self, origin, (aimPos - origin).Unit * 5000, params)
                end
            end
        end
        return oldNamecall(self, ...)
    end))
else
    -- Fallback si el ejecutor no tiene newcclosure
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not checkcaller() and silentAimTarget and silentAimTarget.Parent then
            local method = getnamecallmethod()
            if self == workspace and method == "Raycast" then
                local origin, direction, params = ...
                if typeof(direction) == "Vector3" and direction.Magnitude > 5 then
                    local aimPos = silentAimTarget.Position + Vector3.new(math.random(-10, 10)/100, math.random(-10, 10)/100, math.random(-10, 10)/100)
                    return oldNamecall(self, origin, (aimPos - origin).Unit * 5000, params)
                end
            end
        end
        return oldNamecall(self, ...)
    end)
end

-- Botón Flotante
local floatGui = Instance.new("ScreenGui"); floatGui.Name = "NevadaFloatGui"; floatGui.ResetOnSpawn = false; floatGui.Parent = playerGui
local floatBtn = Instance.new("TextButton"); floatBtn.Size = UDim2.new(0, 130, 0, 50); floatBtn.Position = UDim2.new(0, 20, 0.3, 0); floatBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15); floatBtn.Text = "Auto-Shoot: OFF"; floatBtn.TextColor3 = Color3.fromRGB(255, 50, 50); floatBtn.Font = Enum.Font.GothamBold; floatBtn.TextSize = 14; floatBtn.Parent = floatGui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(0, 10); Instance.new("UIStroke", floatBtn).Color = Color3.fromRGB(255, 255, 255)
local draggingFloat, dragStartFloat, startPosFloat = false, nil, nil
floatBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingFloat = true; dragStartFloat = input.Position; startPosFloat = floatBtn.Position end end)
UserInputService.InputChanged:Connect(function(input) if draggingFloat and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then local delta = input.Position - dragStartFloat; floatBtn.Position = UDim2.new(startPosFloat.X.Scale, startPosFloat.X.Offset + delta.X, startPosFloat.Y.Scale, startPosFloat.Y.Offset + delta.Y) end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingFloat = false end end)
floatBtn.MouseButton1Click:Connect(function() autoAimActive = not autoAimActive; if autoAimActive then floatBtn.Text = "Auto-Shoot: ON"; floatBtn.TextColor3 = Color3.fromRGB(0, 255, 100) else floatBtn.Text = "Auto-Shoot: OFF"; floatBtn.TextColor3 = Color3.fromRGB(255, 50, 50) end end)

local function isInLobby()
    for _, obj in ipairs(playerGui:GetDescendants()) do if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then local txt = obj.Text:lower(); if obj.Visible and (txt:find("tienda") or txt:find("shop") or txt:find("inventario") or txt:find("código") or txt:find("code")) then return true end end end
    local char = player.Character; if char and char:FindFirstChildOfClass("ForceField") then return true end
    return false
end
local function isGun(tool) if not tool or not tool:IsA("Tool") then return false end; local name = string.lower(tool.Name); if string.find(name, "knife") or string.find(name, "cuchillo") or string.find(name, "sword") or string.find(name, "espada") or string.find(name, "melee") then return false end; if string.find(name, "gun") or string.find(name, "pistol") or string.find(name, "revolver") or string.find(name, "sheriff") or string.find(name, "arma") or string.find(name, "colt") then return true end; return false end

RunService.Heartbeat:Connect(function()
    if not autoAimActive or not player.Character then return end
    if tick() - autoShootCooldown < 0.15 then return end 
    if isInLobby() then return end
    local char = player.Character; local hrp = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChildOfClass("Humanoid"); if not hrp or not hum then return end
    local armaEnMano = char:FindFirstChildOfClass("Tool"); if armaEnMano and not isGun(armaEnMano) then armaEnMano = nil end
    local closestEnemy = nil; local shortestDist = math.huge
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local enemyHum = otherPlayer.Character:FindFirstChildOfClass("Humanoid")
            if enemyHum and enemyHum.Health > 0 and (player.Team == nil or otherPlayer.Team == nil or player.Team ~= otherPlayer.Team) then
                local enemyHrp = otherPlayer.Character.HumanoidRootPart; local dist = (enemyHrp.Position - hrp.Position).Magnitude
                if dist < 300 and dist < shortestDist then
                    local raycastParams = RaycastParams.new(); raycastParams.FilterDescendantsInstances = {char, camera}; raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                    local result = workspace:Raycast(camera.CFrame.Position, (enemyHrp.Position - camera.CFrame.Position), raycastParams)
                    if not result or result.Instance:IsDescendantOf(otherPlayer.Character) then shortestDist = dist; closestEnemy = enemyHrp end
                end
            end
        end
    end
    if closestEnemy then
        if not armaEnMano then local backpack = player:FindFirstChildOfClass("Backpack"); if backpack then for _, item in ipairs(backpack:GetChildren()) do if isGun(item) then pcall(function() hum:EquipTool(item) end); task.wait(0.1); armaEnMano = item; break end end end end
        if armaEnMano and armaEnMano.Parent == char and isGun(armaEnMano) then
            silentAimTarget = closestEnemy
            
            -- 🔥 AQUÍ ESTÁ EL TRUCO: VIRTUALUSER en vez de Activate() 🔥
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton1(Vector2.new(0,0))
            end)
            
            -- Un pequeño delay humano para que el Anti-Cheat lo vea natural
            task.wait(math.random(8, 15) / 100) 
            
            silentAimTarget = nil 
            autoShootCooldown = tick() 
        end
    else
        silentAimTarget = nil
    end
end)
