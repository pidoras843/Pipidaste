-- Кнопка быстрой телепортации по "координатам"
local btnTeleportCoord = Instance.new("TextButton")
btnTeleportCoord.Size = UDim2.new(0.9, 0, 0, 25)
btnTeleportCoord.Position = UDim2.new(0.05, 0, 0.83, 0)
btnTeleportCoord.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
btnTeleportCoord.Text = "ТП по коду (" .. displayBox.Text .. ")"
btnTeleportCoord.TextColor3 = Color3.fromRGB(255, 255, 255)
btnTeleportCoord.Font = Enum.Font.SourceSansBold
btnTeleportCoord.TextSize = 12
btnTeleportCoord.Parent = coordPanel

displayBox:GetPropertyChangedSignal("Text"):Connect(function()
    btnTeleportCoord.Text = "ТП по коду (" .. displayBox.Text .. ")"
end)

btnTeleportCoord.MouseButton1Click:Connect(function()
    if hrp then
        -- Смещение персонажа на основе выставленного числа
        hrp.CFrame = hrp.CFrame + Vector3.new(numValue % 50, 5, (letterIndex * 5))
    end
end)

btnCoordMode.MouseButton1Click:Connect(function()
    coordPanel.Visible = not coordPanel.Visible
end)
