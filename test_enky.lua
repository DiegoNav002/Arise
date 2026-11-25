-- Prueba rápida para verificar que tu executor funciona
print("ENKY TEST OK")
local g = game:GetService("CoreGui")
local s = Instance.new("ScreenGui", g)
s.Name = "ENKY_TEST"
local t = Instance.new("TextLabel", s)
t.Size = UDim2.new(0, 220, 0, 44)
t.Position = UDim2.new(0.5, -110, 0.5, -22)
t.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
t.TextColor3 = Color3.new(1, 1, 1)
t.Text = "ENKY TEST OK"
t.Font = Enum.Font.GothamBold
t.TextSize = 16
