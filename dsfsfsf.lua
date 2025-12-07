local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

_G.Skillaimbot = false
_G.AimBotSkillPosition = nil
_G.MaxAimDistance = 500
_G.ESPEnabled = false
_G.SpeedEnabled = false
_G.SpeedValue = 1
_G.AutoRaceAbility = false
_G.AutoV4 = false
_G.AntiStun = false

local lockedTarget = nil
local lastTargetPos = nil
local targetVelocity = Vector3.new(0, 0, 0)
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ESP_Folder"
ESPFolder.Parent = game.CoreGui

-- ฟังก์ชันเช็ค Ally (ทีมเดียวกัน)
local function isAlly(player)
    local success, result = pcall(function()
        local AlliesFrame = LocalPlayer.PlayerGui:FindFirstChild("Main")
        if not AlliesFrame then return false end
        
        AlliesFrame = AlliesFrame:FindFirstChild("Allies")
        if not AlliesFrame then return false end
        
        AlliesFrame = AlliesFrame:FindFirstChild("Container")
        if not AlliesFrame then return false end
        
        AlliesFrame = AlliesFrame:FindFirstChild("Allies")
        if not AlliesFrame then return false end
        
        AlliesFrame = AlliesFrame:FindFirstChild("ScrollingFrame")
        if not AlliesFrame then return false end
        
        AlliesFrame = AlliesFrame:FindFirstChild("Frame")
        if not AlliesFrame then return false end
        
        for _, child in pairs(AlliesFrame:GetChildren()) do
            if child.Name == player.Name then
                return true
            end
        end
        
        return false
    end)
    
    return success and result or false
end
local function IsPirateTeam(player)
    if not player.Team then return false end
    local teamName = player.Team.Name:lower()
    return teamName:find("pirate") or teamName:find("โจร")
end

local function IsMarineTeam(player)
    if not player.Team then return false end
    local teamName = player.Team.Name:lower()
    return teamName:find("marine") or teamName:find("navy")
end
local function findNearestTarget()
    local Character = LocalPlayer.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return nil end
    
    local HumanoidRootPart = Character.HumanoidRootPart
    local nearestPlayer = nil
    local shortestDist = _G.MaxAimDistance
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChild("Humanoid")
            
            if root and hum and hum.Health > 0 and player.UserId > 0 then
                -- เช็คทีม: ถ้าเราเป็น Marine ห้ามล็อค Marine ด้วยกัน
                local canTarget = true
                if LocalPlayer.Team and player.Team then
                    if IsMarineTeam(LocalPlayer) and IsMarineTeam(player) then
                        canTarget = false -- Marine ห้ามล็อค Marine
                    end
                end
                
                -- ถ้าเป็นโจร ยังคงเช็ค Ally ตามเดิม
                if IsPirateTeam(LocalPlayer) and isAlly(player) then
                    canTarget = false
                end
                
                if canTarget then
                    local dist = (HumanoidRootPart.Position - root.Position).Magnitude
                    if dist < shortestDist then
                        if player.Parent == Players then
                            shortestDist = dist
                            nearestPlayer = player
                        end
                    end
                end
            end
        end
    end
    
    return nearestPlayer
end

local function isTargetValid(target)
    if not target or not target.Character then return false end
    
    if target.UserId <= 0 or target.Parent ~= Players then return false end
    
    if isAlly(target) then return false end
    
    local Character = LocalPlayer.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return false end
    
    local root = target.Character:FindFirstChild("HumanoidRootPart")
    local hum = target.Character:FindFirstChild("Humanoid")
    
    if not root or not hum or hum.Health <= 0 then return false end
    
    local dist = (Character.HumanoidRootPart.Position - root.Position).Magnitude
    return dist <= _G.MaxAimDistance
end

local function calculateVelocity(currentPos)
    if not lastTargetPos then
        lastTargetPos = currentPos
        return Vector3.new(0, 0, 0)
    end
    
    local velocity = (currentPos - lastTargetPos) * 60
    lastTargetPos = currentPos
    targetVelocity = velocity:Lerp(targetVelocity, 0.6)
    
    return targetVelocity
end

local function predictPosition(currentPos, velocity)
    local Character = LocalPlayer.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then
        return currentPos
    end
    
    local distance = (Character.HumanoidRootPart.Position - currentPos).Magnitude
    
    -- คำนวณ Prediction อัตโนมัติตามระยะทาง (โหดและตึงมาก!)
    local autoPrediction = 0
    
    if distance < 100 then
        -- ระยะใกล้มาก: ล็อคตรงตัว
        autoPrediction = 0.01
    elseif distance < 200 then
        -- ระยะใกล้: Prediction น้อยมาก
        autoPrediction = 0.02
    elseif distance < 350 then
        -- ระยะกลาง: Prediction ปานกลาง
        autoPrediction = 0.03
    elseif distance < 500 then
        -- ระยะไกล: Prediction สูงขึ้น
        autoPrediction = 0.04
    else
        -- ระยะไกลมาก: Prediction สูงสุด
        autoPrediction = 0.05
    end
    
    -- คำนวณเวลาที่กระสุนจะไปถึง (เร็วและแม่นยำ)
    local projectileSpeed = 400
    local timeToReach = distance / projectileSpeed
    
    -- คำนวณตำแหน่งที่จะยิง
    local prediction = currentPos + (velocity * autoPrediction * timeToReach)
    
    return prediction
end

spawn(function()
    while wait(0.02) do
        if _G.Skillaimbot then
            if not isTargetValid(lockedTarget) then
                local newTarget = findNearestTarget()
                if newTarget and newTarget ~= lockedTarget then
                    lockedTarget = newTarget
                    lastTargetPos = nil
                    targetVelocity = Vector3.new(0, 0, 0)
                elseif not newTarget and lockedTarget then
                    lockedTarget = nil
                    lastTargetPos = nil
                end
            end
            
            if lockedTarget and isTargetValid(lockedTarget) then
                local targetRoot = lockedTarget.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot and lockedTarget.Character.Humanoid.Health > 0 then
                    local currentPos = targetRoot.Position
                    targetVelocity = calculateVelocity(currentPos)
                    _G.AimBotSkillPosition = predictPosition(currentPos, targetVelocity)
                end
            else
                _G.AimBotSkillPosition = nil
            end
        else
            lockedTarget = nil
            _G.AimBotSkillPosition = nil
        end
    end
end)

spawn(function()
    local gg = getrawmetatable(game)
    local old = gg.__namecall
    setreadonly(gg, false)
    
    gg.__namecall = newcclosure(function(...)
        local method = getnamecallmethod()
        local args = {...}
        
        if _G.Skillaimbot and _G.AimBotSkillPosition then
            local self = args[1]
            
            if tostring(method) == "FireServer" or tostring(method) == "InvokeServer" then
                
                for i = 2, #args do
                    local arg = args[i]
                    local argType = typeof(arg)
                    
                    if argType == "Vector3" then
                        args[i] = _G.AimBotSkillPosition
                        break
                        
                    elseif argType == "CFrame" then
                        args[i] = CFrame.new(_G.AimBotSkillPosition)
                        break
                        
                    elseif argType == "table" then
                        if arg.X and arg.Y and arg.Z then
                            args[i] = {
                                X = _G.AimBotSkillPosition.X,
                                Y = _G.AimBotSkillPosition.Y,
                                Z = _G.AimBotSkillPosition.Z
                            }
                            break
                        end
                    end
                end
                
                return old(unpack(args))
            end
        end
        
        return old(...)
    end)
    
    setreadonly(gg, true)
end)



local function CreateESP(player)
    if player == LocalPlayer then return end
    
    -- เช็คว่าผู้เล่นมีทีมหรือไม่ ถ้าไม่มีทีมไม่แสดง ESP
    if not player.Team or not IsPirateTeam(player) and not IsMarineTeam(player) then
        return
    end
    
    local ESPBox = Instance.new("BillboardGui")
    ESPBox.Name = "ESP_" .. player.Name
    ESPBox.Adornee = nil
    ESPBox.AlwaysOnTop = true
    ESPBox.Size = UDim2.new(0, 200, 0, 80)
    ESPBox.StudsOffset = Vector3.new(0, 3, 0)
    ESPBox.Parent = ESPFolder
    
    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, 0, 0.25, 0)
    NameLabel.Position = UDim2.new(0, 0, 0, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameLabel.TextStrokeTransparency = 0.5
    NameLabel.TextScaled = true
    NameLabel.Font = Enum.Font.SourceSansBold
    NameLabel.Text = player.Name
    NameLabel.Parent = ESPBox
    
    local TeamLabel = Instance.new("TextLabel")
    TeamLabel.Size = UDim2.new(1, 0, 0.25, 0)
    TeamLabel.Position = UDim2.new(0, 0, 0.25, 0)
    TeamLabel.BackgroundTransparency = 1
    TeamLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    TeamLabel.TextStrokeTransparency = 0.5
    TeamLabel.TextScaled = true
    TeamLabel.Font = Enum.Font.SourceSans
    TeamLabel.Text = "No Team"
    TeamLabel.Parent = ESPBox
    
    local HPBarBG = Instance.new("Frame")
    HPBarBG.Size = UDim2.new(0.8, 0, 0.15, 0)
    HPBarBG.Position = UDim2.new(0.1, 0, 0.52, 0)
    HPBarBG.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    HPBarBG.BorderSizePixel = 0
    HPBarBG.Parent = ESPBox
    
    local HPBar = Instance.new("Frame")
    HPBar.Size = UDim2.new(1, 0, 1, 0)
    HPBar.Position = UDim2.new(0, 0, 0, 0)
    HPBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    HPBar.BorderSizePixel = 0
    HPBar.Parent = HPBarBG
    
    local HPLabel = Instance.new("TextLabel")
    HPLabel.Size = UDim2.new(1, 0, 0.25, 0)
    HPLabel.Position = UDim2.new(0, 0, 0.5, 0)
    HPLabel.BackgroundTransparency = 1
    HPLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    HPLabel.TextStrokeTransparency = 0.5
    HPLabel.TextScaled = true
    HPLabel.Font = Enum.Font.SourceSansBold
    HPLabel.Text = "100%"
    HPLabel.Parent = ESPBox
    
    local DistanceLabel = Instance.new("TextLabel")
    DistanceLabel.Size = UDim2.new(1, 0, 0.25, 0)
    DistanceLabel.Position = UDim2.new(0, 0, 0.75, 0)
    DistanceLabel.BackgroundTransparency = 1
    DistanceLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    DistanceLabel.TextStrokeTransparency = 0.5
    DistanceLabel.TextScaled = true
    DistanceLabel.Font = Enum.Font.SourceSansBold
    DistanceLabel.Text = "0 studs"
    DistanceLabel.Parent = ESPBox
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not _G.ESPEnabled or not player.Parent then
            ESPBox:Destroy()
            connection:Disconnect()
            return
        end
        
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") then
            local humanoid = character.Humanoid
            if humanoid.Health > 0 then
                local hrp = character.HumanoidRootPart
                ESPBox.Adornee = hrp
                
                local healthPercent = (humanoid.Health / humanoid.MaxHealth) * 100
                HPLabel.Text = string.format("%.0f HP", humanoid.Health)
                HPBar.Size = UDim2.new(humanoid.Health / humanoid.MaxHealth, 0, 1, 0)
                
                if healthPercent > 60 then
                    HPBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                    HPLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                elseif healthPercent > 30 then
                    HPBar.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
                    HPLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                else
                    HPBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                    HPLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                end
                
                if IsPirateTeam(player) then
                    NameLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                    TeamLabel.Text = "PIRATE"
                    TeamLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                elseif IsMarineTeam(player) then
                    NameLabel.TextColor3 = Color3.fromRGB(0, 150, 255)
                    TeamLabel.Text = "MARINE"
                    TeamLabel.TextColor3 = Color3.fromRGB(0, 150, 255)
                else
                    NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    TeamLabel.Text = "No Team"
                    TeamLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                end
                
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local distance = (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                    DistanceLabel.Text = string.format("%.0fm", distance)
                end
            else
                ESPBox.Adornee = nil
            end
        else
            ESPBox.Adornee = nil
        end
    end)
end
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if _G.ESPEnabled then
            task.wait(1)
            CreateESP(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    local old = ESPFolder:FindFirstChild("ESP_" .. player.Name)
    if old then old:Destroy() end
end)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Onion13Hub"
ScreenGui.Parent = game.CoreGui
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MenuButton = Instance.new("TextButton")
MenuButton.Name = "MenuButton"
MenuButton.Size = UDim2.new(0, 120, 0, 55)
MenuButton.Position = UDim2.new(0, 10, 0, 10)
MenuButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MenuButton.BorderSizePixel = 0
MenuButton.Text = "MENU"
MenuButton.TextColor3 = Color3.fromRGB(0, 255, 100)
MenuButton.TextSize = 22
MenuButton.Font = Enum.Font.GothamBold
MenuButton.Parent = ScreenGui

local MenuCorner = Instance.new("UICorner")
MenuCorner.CornerRadius = UDim.new(0, 12)
MenuCorner.Parent = MenuButton

local AimbotButton = Instance.new("TextButton")
AimbotButton.Name = "AimbotButton"
AimbotButton.Size = UDim2.new(0, 120, 0, 55)
AimbotButton.Position = UDim2.new(0, 10, 0, 75)
AimbotButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
AimbotButton.BorderSizePixel = 0
AimbotButton.Text = "AIMBOT OFF"
AimbotButton.TextColor3 = Color3.fromRGB(255, 50, 50)
AimbotButton.TextSize = 18
AimbotButton.Font = Enum.Font.GothamBold
AimbotButton.Parent = ScreenGui

local AimbotCorner = Instance.new("UICorner")
AimbotCorner.CornerRadius = UDim.new(0, 12)
AimbotCorner.Parent = AimbotButton

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 480)
MainFrame.Position = UDim2.new(0.5, -190, 0.5, -240)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 18)
MainCorner.Parent = MainFrame

local Title = Instance.new("Frame")
Title.Size = UDim2.new(1, 0, 0, 60)
Title.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
Title.BorderSizePixel = 0
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 18)
TitleCorner.Parent = Title

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "ONION13"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 24
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Parent = Title

local TitleIcon = Instance.new("TextLabel")
TitleIcon.Size = UDim2.new(0, 40, 1, 0)
TitleIcon.Position = UDim2.new(0, 5, 0, 0)
TitleIcon.BackgroundTransparency = 1
TitleIcon.Text = "🧅"
TitleIcon.TextSize = 30
TitleIcon.Parent = Title

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 45, 0, 45)
CloseButton.Position = UDim2.new(1, -52, 0, 7)
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 24
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = Title

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 12)
CloseCorner.Parent = CloseButton

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -75)
ScrollFrame.Position = UDim2.new(0, 10, 0, 65)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 8
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 100)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 12)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = ScrollFrame

local function createToggleButton(name, icon, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, -10, 0, 50)
    Button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Button.BorderSizePixel = 0
    Button.Text = icon .. " " .. name
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextSize = 17
    Button.Font = Enum.Font.GothamBold
    Button.TextXAlignment = Enum.TextXAlignment.Left
    Button.Parent = ScrollFrame
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 12)
    ButtonCorner.Parent = Button
    
    local ButtonStroke = Instance.new("UIStroke")
    ButtonStroke.Color = Color3.fromRGB(60, 60, 60)
    ButtonStroke.Thickness = 2
    ButtonStroke.Parent = Button

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 15)
    Padding.Parent = Button
    
    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(0, 70, 1, 0)
    Status.Position = UDim2.new(1, -80, 0, 0)
    Status.BackgroundTransparency = 1
    Status.Text = "OFF"
    Status.TextColor3 = Color3.fromRGB(255, 50, 50)
    Status.TextSize = 15
    Status.Font = Enum.Font.GothamBold
    Status.Parent = Button
    
    local isEnabled = false
    Button.MouseButton1Click:Connect(function()
        isEnabled = not isEnabled
        if isEnabled then
            Status.Text = "ON"
            Status.TextColor3 = Color3.fromRGB(0, 255, 100)
        else
            Status.Text = "OFF"
            Status.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
        callback(isEnabled)
    end)
    
    return Button
end

local function createSlider(name, min, max, default, callback)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, -10, 0, 75)
    Container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Container.BorderSizePixel = 0
    Container.Parent = ScrollFrame
    
    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 12)
    ContainerCorner.Parent = Container
    
    local ContainerStroke = Instance.new("UIStroke")
    ContainerStroke.Color = Color3.fromRGB(60, 60, 60)
    ContainerStroke.Thickness = 2
    ContainerStroke.Parent = Container

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -20, 0, 28)
    Label.Position = UDim2.new(0, 10, 0, 5)
    Label.BackgroundTransparency = 1
    Label.Text = name .. ": " .. default
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextSize = 15
    Label.Font = Enum.Font.GothamBold
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container
    
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1, -20, 0, 28)
    SliderFrame.Position = UDim2.new(0, 10, 0, 38)
    SliderFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    SliderFrame.BorderSizePixel = 0
    SliderFrame.Parent = Container
    
    local SliderCorner = Instance.new("UICorner")
    SliderCorner.CornerRadius = UDim.new(0, 10)
    SliderCorner.Parent = SliderFrame
    
    local SliderBar = Instance.new("Frame")
    SliderBar.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    SliderBar.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    SliderBar.BorderSizePixel = 0
    SliderBar.Parent = SliderFrame
    
    local BarCorner = Instance.new("UICorner")
    BarCorner.CornerRadius = UDim.new(0, 10)
    BarCorner.Parent = SliderBar
    
    local dragging = false
    
    SliderFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    
    SliderFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = math.clamp((input.Position.X - SliderFrame.AbsolutePosition.X) / SliderFrame.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + (max - min) * pos)
            SliderBar.Size = UDim2.new(pos, 0, 1, 0)
            Label.Text = name .. ": " .. value
            callback(value)
        end
    end)
end

createToggleButton("Skill Aimbot", "🎯", function(enabled)
    _G.Skillaimbot = enabled
    if not enabled then
        lockedTarget = nil
        _G.AimBotSkillPosition = nil
    end
end)

createSlider("Aim Distance", 100, 1000, 500, function(value)
    _G.MaxAimDistance = value
end)

createToggleButton("ESP", "👁️", function(enabled)
    _G.ESPEnabled = enabled
    
    if enabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                CreateESP(player)
            end
        end
    else
        for _, esp in pairs(ESPFolder:GetChildren()) do
            esp:Destroy()
        end
    end
end)


createSlider("Speed", 1, 12, 1, function(value)
    _G.SpeedValue = value
end)

createToggleButton("Speed Boost", "⚡", function(enabled)
    _G.SpeedEnabled = enabled
end)

createToggleButton("Auto Race Ability", "💪", function(enabled)
    _G.AutoRaceAbility = enabled
end)

createToggleButton("Auto V4", "⭐", function(enabled)
    _G.AutoV4 = enabled
end)
createToggleButton("Anti-Stun", "🛡️", function(enabled)
    _G.AntiStun = enabled
end)
local JumpButton = Instance.new("TextButton")
JumpButton.Name = "JumpButton"
JumpButton.Size = UDim2.new(0, 85, 0, 85)
JumpButton.Position = UDim2.new(1, -120, 0, 150)
JumpButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
JumpButton.BorderSizePixel = 0
JumpButton.Text = "↑"
JumpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
JumpButton.TextSize = 45
JumpButton.Font = Enum.Font.GothamBold
JumpButton.Parent = ScreenGui

local JumpCorner = Instance.new("UICorner")
JumpCorner.CornerRadius = UDim.new(1, 0)
JumpCorner.Parent = JumpButton

local JumpStroke = Instance.new("UIStroke")
JumpStroke.Color = Color3.fromRGB(0, 150, 255)
JumpStroke.Thickness = 3
JumpStroke.Parent = JumpButton

local isJumpHolding = false
local isJumpDragging = false
local jumpDragStart = nil
local jumpStartPos = nil
local jumpPressTime = 0

JumpButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        jumpDragStart = input.Position
        jumpStartPos = JumpButton.Position
        isJumpDragging = false
        jumpPressTime = tick()
        
        wait(0.05)
        if not isJumpDragging and jumpDragStart then
            isJumpHolding = true
            
            local Character = LocalPlayer.Character
            if Character and Character:FindFirstChild("Humanoid") then
                Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

JumpButton.InputChanged:Connect(function(input)
    if jumpDragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = (input.Position - jumpDragStart).Magnitude
        if delta > 20 then
            isJumpDragging = true
            isJumpHolding = false
            local offset = input.Position - jumpDragStart
            JumpButton.Position = UDim2.new(jumpStartPos.X.Scale, jumpStartPos.X.Offset + offset.X, jumpStartPos.Y.Scale, jumpStartPos.Y.Offset + offset.Y)
        end
    end
end)

JumpButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isJumpHolding = false
        jumpDragStart = nil
        isJumpDragging = false
        jumpPressTime = 0
    end
end)

RunService.Heartbeat:Connect(function()
    if isJumpHolding and not isJumpDragging then
        local Character = LocalPlayer.Character
        if Character and Character:FindFirstChild("HumanoidRootPart") then
            local hrp = Character.HumanoidRootPart
            hrp.Velocity = Vector3.new(hrp.Velocity.X, 200, hrp.Velocity.Z)
        end
    end
end)

local aimbotDragStart = nil
local aimbotStartPos = nil
local isAimbotDragging = false

AimbotButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        aimbotDragStart = input.Position
        aimbotStartPos = AimbotButton.Position
        isAimbotDragging = false
    end
end)

AimbotButton.InputChanged:Connect(function(input)
    if aimbotDragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = (input.Position - aimbotDragStart).Magnitude
        if delta > 15 then
            isAimbotDragging = true
            local offset = input.Position - aimbotDragStart
            AimbotButton.Position = UDim2.new(aimbotStartPos.X.Scale, aimbotStartPos.X.Offset + offset.X, aimbotStartPos.Y.Scale, aimbotStartPos.Y.Offset + offset.Y)
        end
    end
end)

AimbotButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if not isAimbotDragging then
            _G.Skillaimbot = not _G.Skillaimbot
            if _G.Skillaimbot then
                AimbotButton.TextColor3 = Color3.fromRGB(0, 255, 100)
                AimbotButton.Text = "AIMBOT ON"
            else
                AimbotButton.TextColor3 = Color3.fromRGB(255, 50, 50)
                AimbotButton.Text = "AIMBOT OFF"
                lockedTarget = nil
                _G.AimBotSkillPosition = nil
            end
        end
        
        aimbotDragStart = nil
        isAimbotDragging = false
    end
end)

local menuDragStart = nil
local menuStartPos = nil
local isMenuDragging = false

MenuButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        menuDragStart = input.Position
        menuStartPos = MenuButton.Position
        isMenuDragging = false
    end
end)

MenuButton.InputChanged:Connect(function(input)
    if menuDragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = (input.Position - menuDragStart).Magnitude
        if delta > 15 then
            isMenuDragging = true
            local offset = input.Position - menuDragStart
            MenuButton.Position = UDim2.new(menuStartPos.X.Scale, menuStartPos.X.Offset + offset.X, menuStartPos.Y.Scale, menuStartPos.Y.Offset + offset.Y)
        end
    end
end)

MenuButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if not isMenuDragging then
            MainFrame.Visible = not MainFrame.Visible
        end
        
        menuDragStart = nil
        isMenuDragging = false
    end
end)

CloseButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.LeftControl then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

local draggingMain = false
local mainDragStart = nil
local mainStartPos = nil

Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingMain = true
        mainDragStart = input.Position
        mainStartPos = MainFrame.Position
    end
end)

Title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingMain = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingMain and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - mainDragStart
        MainFrame.Position = UDim2.new(mainStartPos.X.Scale, mainStartPos.X.Offset + delta.X, mainStartPos.Y.Scale, mainStartPos.Y.Offset + delta.Y)
    end
end)

RunService.Heartbeat:Connect(function()
    if _G.SpeedEnabled then
        local Character = LocalPlayer.Character
        if Character and Character:FindFirstChild("Humanoid") and Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = Character.Humanoid
            local hrp = Character.HumanoidRootPart
            
            if humanoid.MoveDirection.Magnitude > 0 then
                local moveDirection = humanoid.MoveDirection
                hrp.CFrame = hrp.CFrame + (moveDirection * (_G.SpeedValue * 0.5))
            end
        end
    end
end)

spawn(function()
    while wait(0.1) do
        if _G.AutoRaceAbility then
            pcall(function()
                local args = {"ActivateAbility"}
                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommE"):FireServer(unpack(args))
            end)
        end
    end
end)

spawn(function()
    while wait(0.5) do
        if _G.AutoV4 then
            pcall(function()
                local Character = LocalPlayer.Character
                if Character then
                    local RaceEnergy = Character:FindFirstChild("RaceEnergy")
                    local RaceTransformed = Character:FindFirstChild("RaceTransformed")
                    
                    if RaceEnergy and RaceTransformed then
                        if tonumber(RaceEnergy.Value) == 1 and RaceTransformed.Value == false then
                            local VirtualInputManager = game:GetService("VirtualInputManager")
                            VirtualInputManager:SendKeyEvent(true, "Y", false, game)
                            wait(0.1)
                            VirtualInputManager:SendKeyEvent(false, "Y", false, game)
                        end
                    end
                end
            end)
        end
    end
end)
spawn(function()
    while wait(0.01) do
        if _G.AntiStun then
            pcall(function()
                local Character = LocalPlayer.Character
                if Character then
                    local Stun = Character:FindFirstChild("Stun")
                    if Stun then
                        Stun.Value = 0
                    end
                end
            end)
        end
    end
end)
Players.PlayerAdded:Connect(function(player)
    if _G.ESPEnabled then
        wait(1)
        CreateESP(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local esp = ESPFolder:FindFirstChild("ESP_" .. player.Name)
    if esp then
        esp:Destroy()
    end
end)

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 10)
end)

local Credit = Instance.new("TextLabel")
Credit.Size = UDim2.new(0, 250, 0, 35)
Credit.Position = UDim2.new(0.5, -125, 1, -45)
Credit.BackgroundTransparency = 1
Credit.Text = "Made by Onion13"
Credit.TextColor3 = Color3.fromRGB(0, 255, 100)
Credit.TextSize = 18
Credit.Font = Enum.Font.GothamBold
Credit.TextStrokeTransparency = 0.3
Credit.Parent = ScreenGui

print("🧅 Onion13 Hub - Auto Prediction Version!")
print("✅ Prediction Slider ถูกลบออกแล้ว")
print("🎯 Aimbot คำนวณ Prediction อัตโนมัติตามระยะทาง!")
print("📏 ระยะใกล้ (0-100m) = 1% Prediction")
print("📏 ระยะกลาง (100-350m) = 2-4% Prediction")
print("📏 ระยะไกล (350-500m+) = 6-8% Prediction")
print("⚡ ตึงและแม่นขึ้นอัตโนมัติ!")
