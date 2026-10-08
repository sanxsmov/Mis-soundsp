-- XeroHub_Sounds_Config_V2.lua
-- Sounds + Config
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local SoundService=game:GetService("SoundService")
local UserInputService=game:GetService("UserInputService")
local Player=Players.LocalPlayer

local API="https://api.github.com/repos/sanxsmov/Mis-soundsp/contents/sounds"
local RAW="https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/sounds/"
local selected={Shoot={Name="Ninguno",URL=""},Kill={Name="Ninguno",URL=""},Jump={Name="Ninguno",URL=""}}
local enabled={Shoot=true,Kill=true,Jump=true}
local catalog={}
local cache={}

local function get(url)
 local ok,r=pcall(function() return game:HttpGet(url) end)
 return ok and r or nil
end

local function play(url)
 if not url or url=="" then return end
 local id=cache[url]
 if not id and writefile and getcustomasset then
  local n="XeroHub_"..(url:match("([^/]+)$") or "sound.mp3")
  if not isfile(n) then
   local d=get(url)
   if d then pcall(function() writefile(n,d) end) end
  end
  if isfile(n) then
   local ok,x=pcall(function() return getcustomasset(n) end)
   if ok then id=x cache[url]=x end
  end
 end
 id=id or url
 local s=Instance.new("Sound")
 s.SoundId=id s.Volume=1 s.Parent=SoundService
 pcall(function() s:Play() end)
 s.Ended:Connect(function() s:Destroy() end)
end

local function refresh()
 local body=get(API)
 if not body then return end
 local ok,data=pcall(function() return HttpService:JSONDecode(body) end)
 if not ok or type(data)~="table" then return end
 catalog={}
 for _,v in ipairs(data) do
  if type(v)=="table" and type(v.name)=="string" then
   local n=v.name:lower()
   if n:match("%.mp3$") or n:match("%.ogg$") or n:match("%.wav$") then
    catalog[#catalog+1]={Name=v.name,URL=RAW..v.name}
   end
  end
 end
end
refresh()

local function cfg()
 return "XeroHub_Sounds_Config_V2.json"
end
local function save()
 if not writefile then return end
 pcall(function() writefile(cfg(),HttpService:JSONEncode({Selected=selected,Enabled=enabled})) end)
end
local function load()
 if not readfile or not isfile or not isfile(cfg()) then return end
 local ok,d=pcall(function() return HttpService:JSONDecode(readfile(cfg())) end)
 if ok and type(d)=="table" then
  if type(d.Selected)=="table" then for k,v in pairs(d.Selected) do if type(v)=="table" then selected[k]=v end end end
  if type(d.Enabled)=="table" then for k,v in pairs(d.Enabled) do enabled[k]=v==true end end
 end
end
load()

local gui=Instance.new("ScreenGui")
gui.Name="XeroHub_Sounds_Config_V2" gui.ResetOnSpawn=false
pcall(function() gui.Parent=game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=Player:WaitForChild("PlayerGui") end

local main=Instance.new("Frame")
main.Size=UDim2.fromOffset(390,280) main.Position=UDim2.new(.5,-195,.5,-140)
main.BackgroundColor3=Color3.fromRGB(24,24,30) main.BorderSizePixel=0 main.Parent=gui
Instance.new("UICorner",main).CornerRadius=UDim.new(0,10)

local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,-80,0,40) title.Position=UDim2.fromOffset(12,0)
title.BackgroundTransparency=1 title.Text="Nevada — Sounds & Config"
title.TextColor3=Color3.new(1,1,1) title.TextSize=16 title.Font=Enum.Font.GothamBold
title.TextXAlignment=Enum.TextXAlignment.Left title.Parent=main

local mini=Instance.new("TextButton")
mini.Size=UDim2.fromOffset(35,28) mini.Position=UDim2.new(1,-78,0,6) mini.Text="—" mini.Parent=main
local close=Instance.new("TextButton")
close.Size=UDim2.fromOffset(35,28) close.Position=UDim2.new(1,-40,0,6) close.Text="×" close.Parent=main

local st=Instance.new("TextButton")
st.Size=UDim2.fromOffset(180,30) st.Position=UDim2.fromOffset(10,43) st.Text="Sounds" st.Parent=main
local ct=Instance.new("TextButton")
ct.Size=UDim2.fromOffset(180,30) ct.Position=UDim2.fromOffset(195,43) ct.Text="Config" ct.Parent=main

local page=Instance.new("Frame")
page.Size=UDim2.new(1,-20,1,-85) page.Position=UDim2.fromOffset(10,80)
page.BackgroundTransparency=1 page.Parent=main
local sounds=Instance.new("Frame") sounds.Size=UDim2.fromScale(1,1) sounds.BackgroundTransparency=1 sounds.Parent=page
local config=Instance.new("Frame") config.Size=UDim2.fromScale(1,1) config.BackgroundTransparency=1 config.Visible=false config.Parent=page

local buttons={}
local function row(key,text,y)
 local l=Instance.new("TextLabel")
 l.Size=UDim2.fromOffset(85,30) l.Position=UDim2.fromOffset(0,y) l.BackgroundTransparency=1
 l.Text=text l.TextColor3=Color3.new(1,1,1) l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=sounds
 local b=Instance.new("TextButton")
 b.Size=UDim2.fromOffset(245,30) b.Position=UDim2.fromOffset(90,y) b.Text=selected[key].Name b.Parent=sounds buttons[key]=b
 local t=Instance.new("TextButton")
 t.Size=UDim2.fromOffset(45,30) t.Position=UDim2.fromOffset(340,y) t.Text="▶" t.Parent=sounds
 b.MouseButton1Click:Connect(function()
  if #catalog==0 then refresh() end
  if #catalog==0 then return end
  local i=1
  for n,v in ipairs(catalog) do if v.Name==selected[key].Name then i=n+1 break end end
  if i>#catalog then i=1 end
  selected[key]=catalog[i] b.Text=selected[key].Name
 end)
 t.MouseButton1Click:Connect(function() play(selected[key].URL) end)
end
row("Shoot","Disparar",0) row("Kill","Matar",38) row("Jump","Saltar",76)

local rf=Instance.new("TextButton")
rf.Size=UDim2.fromOffset(150,30) rf.Position=UDim2.fromOffset(0,120) rf.Text="Actualizar catálogo" rf.Parent=sounds
rf.MouseButton1Click:Connect(refresh)

local sv=Instance.new("TextButton")
sv.Size=UDim2.fromOffset(150,35) sv.Text="Guardar Config" sv.Parent=config
sv.MouseButton1Click:Connect(save)

local ld=Instance.new("TextButton")
ld.Size=UDim2.fromOffset(150,35) ld.Position=UDim2.fromOffset(160,0) ld.Text="Cargar Config" ld.Parent=config
ld.MouseButton1Click:Connect(function()
 load()
 for k,b in pairs(buttons) do b.Text=selected[k].Name end
end)

st.MouseButton1Click:Connect(function() sounds.Visible=true config.Visible=false end)
ct.MouseButton1Click:Connect(function() sounds.Visible=false config.Visible=true end)
mini.MouseButton1Click:Connect(function()
 page.Visible=not page.Visible
 st.Visible=page.Visible ct.Visible=page.Visible
 main.Size=page.Visible and UDim2.fromOffset(390,280) or UDim2.fromOffset(390,45)
end)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local dragging=false
local startInput,startPos
title.InputBegan:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
  dragging=true startInput=i.Position startPos=main.Position
 end
end)
UserInputService.InputChanged:Connect(function(i)
 if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
  local d=i.Position-startInput
  main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
 end
end)
UserInputService.InputEnded:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)

local function hookCharacter(c)
 local h=c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid",10)
 if h then h.Jumping:Connect(function(active) if active and enabled.Jump then play(selected.Jump.URL) end end) end
end
if Player.Character then hookCharacter(Player.Character) end
Player.CharacterAdded:Connect(hookCharacter)

SoundService.DescendantAdded:Connect(function(o)
 if not o:IsA("Sound") then return end
 local id=tostring(o.SoundId or ""):match("%d+")
 if (id=="10209603" or o.Name=="GunShot") and enabled.Shoot then
  play(selected.Shoot.URL)
 elseif (id=="296102734" or o.Name=="GunKill") and enabled.Kill then
  play(selected.Kill.URL)
 end
end)
