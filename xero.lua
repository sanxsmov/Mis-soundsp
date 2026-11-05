print("1. Iniciando prueba...")
local url = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
local exito, source = pcall(function() return game:HttpGet(url) end)

if not exito or not source or #source < 1000 then
    warn("❌ ERROR EN PASO 1: El ejecutor no puede descargar la UI desde GitHub.")
    warn("Código de error:", source)
    return
end
print("2. Descarga exitosa. Tamaño:", #source)

local chunk, err = loadstring(source)
if not chunk then
    warn("❌ ERROR EN PASO 2: El código descargado está dañado y no compila.")
    warn("Error:", err)
    return
end
print("3. Compilación exitosa. Intentando iniciar la UI...")

local ok, WindUI = pcall(chunk)
if not ok or not WindUI then
    warn("❌ ERROR EN PASO 3: La UI se descargó pero falló al iniciarse internamente.")
    warn("Error interno:", WindUI)
    return
end
print("4. ✅ WindUI cargada. Creando ventana de prueba...")

local testWindow = WindUI:CreateWindow({
    Title = "PRUEBA EXITOSA",
    Subtitle = "Tu ejecutor funciona",
    Size = UDim2.fromOffset(400, 250)
})
print("5. 🎉 ¡TODO FUNCIONA PERFECTO!")
