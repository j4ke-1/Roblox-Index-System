--[[
	ChickenIndexClient (LocalScript)
	PLACE IN: StarterGui
    Made by: Atv_pr0 - .j4ke1

	The Chicken Index: a collection screen showing every chicken grouped
	by rarity, with locked silhouette cards for ones you haven't found yet
	and glowing colored cards for ones you have. Shows a progress bar per
	rarity, celebrates completing a full set with a popup, and shows a
	small toast every time you discover something new.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ChickenConfig = require(ReplicatedStorage:WaitForChild("ChickenConfig"))
local remotes = ReplicatedStorage:WaitForChild("ChickenRemotes")
local indexUpdatedEvent = remotes:WaitForChild("IndexUpdated")
local raritySetCompletedEvent = remotes:WaitForChild("RaritySetCompleted")
local newDiscoveryEvent = remotes:WaitForChild("NewChickenDiscovered")
local getIndexFunction = remotes:WaitForChild("GetChickenIndex")

local RARITY_COLORS = {
	Common = Color3.fromRGB(170, 170, 170),
	Uncommon = Color3.fromRGB(85, 255, 85),
	Rare = Color3.fromRGB(0, 170, 255),
	Epic = Color3.fromRGB(170, 85, 255),
	Legendary = Color3.fromRGB(255, 170, 0),
	Mythic = Color3.fromRGB(255, 0, 255),
	Secret = Color3.fromRGB(255, 0, 0),
}

local state = { discovered = {}, completedRarities = {}, multiplier = 1 }
local cardsByName = {}       -- [chickenName] = { frame, checkmark, nameLabel }
local rarityProgress = {}    -- [rarity] = { bar, label, badge }

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChickenIndexGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui


local toggleEvent = ReplicatedStorage:FindFirstChild("ToggleChickenIndex")
if not toggleEvent then
	toggleEvent = Instance.new("BindableEvent")
	toggleEvent.Name = "ToggleChickenIndex"
	toggleEvent.Parent = ReplicatedStorage
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "ChickenIndexFrame"
mainFrame.Size = UDim2.fromOffset(560, 620)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(24, 22, 32)
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(180, 120, 60)
mainStroke.Thickness = 2.5
mainStroke.Transparency = 0.15
mainStroke.Parent = mainFrame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 78)
header.BackgroundColor3 = Color3.fromRGB(120, 70, 30)
header.Parent = mainFrame

local headerGradient = Instance.new("UIGradient")
headerGradient.Color = ColorSequence.new(Color3.fromRGB(175, 115, 55), Color3.fromRGB(95, 55, 25))
headerGradient.Rotation = 90
headerGradient.Parent = header

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 16)
headerCorner.Parent = header

local headerMask = Instance.new("Frame")
headerMask.Size = UDim2.new(1, 0, 0, 16)
headerMask.Position = UDim2.new(0, 0, 1, -16)
headerMask.BackgroundColor3 = header.BackgroundColor3
headerMask.BorderSizePixel = 0
headerMask.ZIndex = 0
headerMask.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.BackgroundTransparency = 1
titleLabel.Size = UDim2.new(1, -60, 0, 32)
titleLabel.Position = UDim2.fromOffset(20, 12)
titleLabel.Text = "🐔 Chicken Index"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 26
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local multiplierLabel = Instance.new("TextLabel")
multiplierLabel.BackgroundTransparency = 1
multiplierLabel.Size = UDim2.new(1, -60, 0, 22)
multiplierLabel.Position = UDim2.fromOffset(20, 46)
multiplierLabel.Text = "Total Income Bonus: +0%"
multiplierLabel.TextColor3 = Color3.fromRGB(255, 220, 130)
multiplierLabel.Font = Enum.Font.GothamBold
multiplierLabel.TextSize = 15
multiplierLabel.TextXAlignment = Enum.TextXAlignment.Left
multiplierLabel.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(38, 38)
closeButton.Position = UDim2.new(1, -50, 0, 20)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = closeButton

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -90)
scrollFrame.Position = UDim2.fromOffset(10, 84)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = mainFrame

local sectionsLayout = Instance.new("UIListLayout")
sectionsLayout.Padding = UDim.new(0, 16)
sectionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
sectionsLayout.Parent = scrollFrame

local function buildRaritySection(rarity, entries, layoutOrder)
	local color = RARITY_COLORS[rarity] or Color3.new(1, 1, 1)

	local section = Instance.new("Frame")
	section.Name = rarity .. "Section"
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.Size = UDim2.new(1, 0, 0, 0)
	section.BackgroundTransparency = 1
	section.LayoutOrder = layoutOrder
	section.Parent = scrollFrame

	local sectionLayout = Instance.new("UIListLayout")
	sectionLayout.Padding = UDim.new(0, 6)
	sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sectionLayout.Parent = section

	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(1, 0, 0, 30)
	headerBar.BackgroundColor3 = color
	headerBar.BackgroundTransparency = 0.75
	headerBar.LayoutOrder = 1
	headerBar.Parent = section

	local headerBarCorner = Instance.new("UICorner")
	headerBarCorner.CornerRadius = UDim.new(0, 8)
	headerBarCorner.Parent = headerBar

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Size = UDim2.new(0.5, 0, 1, 0)
	rarityLabel.Position = UDim2.fromOffset(10, 0)
	rarityLabel.Text = rarity
	rarityLabel.TextColor3 = color
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextSize = 16
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.Parent = headerBar

	local progressLabel = Instance.new("TextLabel")
	progressLabel.BackgroundTransparency = 1
	progressLabel.Size = UDim2.new(0.35, 0, 1, 0)
	progressLabel.Position = UDim2.new(1, -160, 0, 0)
	progressLabel.Text = "0 / " .. #entries
	progressLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	progressLabel.Font = Enum.Font.Gotham
	progressLabel.TextSize = 13
	progressLabel.TextXAlignment = Enum.TextXAlignment.Right
	progressLabel.Parent = headerBar

	local completeBadge = Instance.new("TextLabel")
	completeBadge.Size = UDim2.fromOffset(90, 22)
	completeBadge.Position = UDim2.new(1, -98, 0.5, 0)
	completeBadge.AnchorPoint = Vector2.new(0, 0.5)
	completeBadge.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	completeBadge.Text = "✓ +5%"
	completeBadge.TextColor3 = Color3.fromRGB(40, 30, 0)
	completeBadge.Font = Enum.Font.GothamBold
	completeBadge.TextSize = 13
	completeBadge.Visible = false
	completeBadge.Parent = headerBar

	local completeBadgeCorner = Instance.new("UICorner")
	completeBadgeCorner.CornerRadius = UDim.new(1, 0)
	completeBadgeCorner.Parent = completeBadge

	local barTrack = Instance.new("Frame")
	barTrack.Size = UDim2.new(1, 0, 0, 6)
	barTrack.BackgroundColor3 = Color3.fromRGB(50, 48, 60)
	barTrack.LayoutOrder = 2
	barTrack.Parent = section

	local barTrackCorner = Instance.new("UICorner")
	barTrackCorner.CornerRadius = UDim.new(1, 0)
	barTrackCorner.Parent = barTrack

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = color
	barFill.BorderSizePixel = 0
	barFill.Parent = barTrack

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(1, 0)
	barFillCorner.Parent = barFill

	local grid = Instance.new("Frame")
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.BackgroundTransparency = 1
	grid.LayoutOrder = 3
	grid.Parent = section

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(100, 108)
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	for i, entry in ipairs(entries) do
		
		local shadow = Instance.new("Frame")
		shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		shadow.BackgroundTransparency = 0.6
		shadow.LayoutOrder = i
		shadow.Parent = grid

		local shadowCorner = Instance.new("UICorner")
		shadowCorner.CornerRadius = UDim.new(0, 12)
		shadowCorner.Parent = shadow

		local card = Instance.new("Frame")
		card.Name = entry.Name
		card.Size = UDim2.new(1, 0, 1, 0)
		card.Position = UDim2.fromOffset(0, -4)
		card.BackgroundColor3 = Color3.fromRGB(42, 40, 52)
		card.Parent = shadow

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 12)
		cardCorner.Parent = card

		local cardGradient = Instance.new("UIGradient")
		cardGradient.Color = ColorSequence.new(Color3.fromRGB(52, 50, 64), Color3.fromRGB(34, 32, 42))
		cardGradient.Rotation = 90
		cardGradient.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = color
		cardStroke.Thickness = 2
		cardStroke.Transparency = 0.35
		cardStroke.Parent = card

		
		local icon = Instance.new("Frame")
		icon.Size = UDim2.fromOffset(60, 60)
		icon.Position = UDim2.new(0.5, 0, 0, 10)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.BackgroundColor3 = Color3.fromRGB(20, 19, 26)
		icon.ClipsDescendants = true
		icon.Parent = card

		local iconCorner = Instance.new("UICorner")
		iconCorner.CornerRadius = UDim.new(1, 0)
		iconCorner.Parent = icon

		local iconRing = Instance.new("UIStroke")
		iconRing.Color = color
		iconRing.Thickness = 1.5
		iconRing.Transparency = 0.4
		iconRing.Parent = icon

		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "ModelViewport"
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.BackgroundTransparency = 1
		viewport.Ambient = Color3.fromRGB(140, 140, 140)
		viewport.LightColor = Color3.fromRGB(255, 255, 255)
		viewport.Parent = icon

		local checkmark = Instance.new("TextLabel")
		checkmark.Name = "Checkmark"
		checkmark.Size = UDim2.fromOffset(20, 20)
		checkmark.Position = UDim2.new(1, -6, 0, 6)
		checkmark.AnchorPoint = Vector2.new(1, 0)
		checkmark.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
		checkmark.Text = "✓"
		checkmark.TextColor3 = Color3.fromRGB(255, 255, 255)
		checkmark.Font = Enum.Font.GothamBold
		checkmark.TextSize = 13
		checkmark.Visible = false
		checkmark.ZIndex = 3
		checkmark.Parent = card

		local checkmarkCorner = Instance.new("UICorner")
		checkmarkCorner.CornerRadius = UDim.new(1, 0)
		checkmarkCorner.Parent = checkmark

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, -8, 0, 32)
		nameLabel.Position = UDim2.new(0.5, 0, 1, -36)
		nameLabel.AnchorPoint = Vector2.new(0.5, 0)
		nameLabel.Text = "???"
		nameLabel.TextColor3 = Color3.fromRGB(140, 140, 145)
		nameLabel.TextWrapped = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextStrokeTransparency = 0.6
		nameLabel.Parent = card

		cardsByName[entry.Name] = {
			shadow = shadow,
			card = card,
			icon = icon,
			viewport = viewport,
			modelLoaded = false,
			checkmark = checkmark,
			nameLabel = nameLabel,
			displayName = entry.DisplayName,
			color = color,
		}
	end

	rarityProgress[rarity] = {
		barFill = barFill,
		progressLabel = progressLabel,
		completeBadge = completeBadge,
		total = #entries,
	}
end

local chickenIcons = ReplicatedStorage:WaitForChild("ChickenIcons", 10)


local CAMERA_DISTANCE_OVERRIDES = {
	["Exalted Chicken"] = 0.7,
}


local function frameCameraOnModel(camera, model)
	local cframe, size = model:GetBoundingBox()
	local diagonal = size.Magnitude
	local overrideMultiplier = CAMERA_DISTANCE_OVERRIDES[model.Name] or 1
	
	local distance = math.max(diagonal * 1.15 * overrideMultiplier, 2)
	local offset = Vector3.new(1, 0.75, 1).Unit * distance
	camera.CFrame = CFrame.lookAt(cframe.Position + offset, cframe.Position)
	camera.FieldOfView = 45
end

local hiddenAppearanceStorage = Instance.new("Folder")
hiddenAppearanceStorage.Name = "HiddenSurfaceAppearances"
hiddenAppearanceStorage.Parent = ReplicatedStorage

local function setSilhouette(model, silhouette)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if silhouette then
				if part:GetAttribute("OriginalColor") == nil then
					part:SetAttribute("OriginalColor", part.Color)
					part:SetAttribute("OriginalMaterial", part.Material.Name)
				end
				part.Color = Color3.new(0, 0, 0)
				part.Material = Enum.Material.SmoothPlastic
			else
				local originalColor = part:GetAttribute("OriginalColor")
				local originalMaterialName = part:GetAttribute("OriginalMaterial")
				if originalColor then
					part.Color = originalColor
				end
				if originalMaterialName then
					part.Material = Enum.Material[originalMaterialName]
				end
			end
		elseif part:IsA("SurfaceAppearance") then
			if silhouette then
				part.Parent = hiddenAppearanceStorage -- pull it out entirely, its mere presence overrides Color
			end
		elseif part:IsA("Decal") or part:IsA("Texture") then
			if silhouette then
				if part:GetAttribute("OriginalTransparency") == nil then
					part:SetAttribute("OriginalTransparency", part.Transparency)
				end
				part.Transparency = 1
			else
				local originalTransparency = part:GetAttribute("OriginalTransparency")
				if originalTransparency then
					part.Transparency = originalTransparency
				end
			end
		end
	end
end

local function loadModelIcon(ui, chickenName, discovered)
	if ui.modelLoaded or not chickenIcons then
		return
	end
	local template = chickenIcons:FindFirstChild(chickenName)
	if not template then
		return
	end

	local model = template:Clone()
	model.Parent = ui.viewport
	setSilhouette(model, not discovered)
	ui.model = model

	local camera = Instance.new("Camera")
	camera.Parent = ui.viewport
	ui.viewport.CurrentCamera = camera
	frameCameraOnModel(camera, model)

	ui.modelLoaded = true
end

local function refreshCard(name)
	local ui = cardsByName[name]
	if not ui then
		return
	end
	local discovered = state.discovered[name] == true
	loadModelIcon(ui, name, discovered) -- always loaded, regardless of discovery state

	if discovered then
		ui.checkmark.Visible = true
		ui.nameLabel.Text = ui.displayName
		ui.nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		ui.card.BackgroundTransparency = 0
		if ui.model then
			setSilhouette(ui.model, false) -- reveal true colors
		end
	else
		ui.checkmark.Visible = false
		ui.nameLabel.Text = "???"
		ui.nameLabel.TextColor3 = Color3.fromRGB(120, 120, 125)
	end
end

local function refreshRarityProgress(rarity)
	local progress = rarityProgress[rarity]
	if not progress then
		return
	end

	local found = 0
	for name, ui in pairs(cardsByName) do
		if state.discovered[name] and ui.color == RARITY_COLORS[rarity] then
			found += 1
		end
	end

	local alpha = progress.total > 0 and (found / progress.total) or 0
	TweenService:Create(progress.barFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.new(alpha, 0, 1, 0),
	}):Play()

	progress.progressLabel.Text = found .. " / " .. progress.total
	progress.completeBadge.Visible = state.completedRarities[rarity] == true
end

local function refreshAll()
	for name in pairs(cardsByName) do
		refreshCard(name)
	end
	for rarity in pairs(rarityProgress) do
		refreshRarityProgress(rarity)
	end

	local bonusPercent = math.floor((state.multiplier - 1) * 100 + 0.5)
	multiplierLabel.Text = "Total Income Bonus: +" .. bonusPercent .. "%"
end

local popupContainer = Instance.new("Frame")
popupContainer.Size = UDim2.fromScale(1, 1)
popupContainer.BackgroundTransparency = 1
popupContainer.Parent = screenGui

local function showToast(text, accentColor, big)
	local toast = Instance.new("Frame")
	toast.Size = big and UDim2.fromOffset(340, 70) or UDim2.fromOffset(280, 52)
	toast.Position = UDim2.new(0.5, 0, 0, big and 100 or 60)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundColor3 = Color3.fromRGB(28, 26, 36)
	toast.Parent = popupContainer

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 12)
	toastCorner.Parent = toast

	local toastStroke = Instance.new("UIStroke")
	toastStroke.Color = accentColor
	toastStroke.Thickness = 2
	toastStroke.Parent = toast

	local toastLabel = Instance.new("TextLabel")
	toastLabel.Size = UDim2.new(1, -20, 1, -10)
	toastLabel.Position = UDim2.fromOffset(10, 5)
	toastLabel.BackgroundTransparency = 1
	toastLabel.Text = text
	toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	toastLabel.TextWrapped = true
	toastLabel.Font = Enum.Font.GothamBold
	toastLabel.TextSize = big and 18 or 14
	toastLabel.Parent = toast

	toast.BackgroundTransparency = 1
	toastLabel.TextTransparency = 1
	toastStroke.Transparency = 1
	local fadeIn = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { BackgroundTransparency = 0.05 })
	local fadeInStroke = TweenService:Create(toastStroke, TweenInfo.new(0.3), { Transparency = 0 })
	local fadeInLabel = TweenService:Create(toastLabel, TweenInfo.new(0.3), { TextTransparency = 0 })
	fadeIn:Play()
	fadeInStroke:Play()
	fadeInLabel:Play()

	task.delay(big and 3.5 or 2.5, function()
		local fadeOut = TweenService:Create(toast, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		local fadeOutStroke = TweenService:Create(toastStroke, TweenInfo.new(0.5), { Transparency = 1 })
		local fadeOutLabel = TweenService:Create(toastLabel, TweenInfo.new(0.5), { TextTransparency = 1 })
		fadeOut:Play()
		fadeOutStroke:Play()
		fadeOutLabel:Play()
		fadeOut.Completed:Connect(function()
			toast:Destroy()
		end)
	end)
end

local closePanelsEvent = ReplicatedStorage:FindFirstChild("ClosePanelsExcept")
if not closePanelsEvent then
	closePanelsEvent = Instance.new("BindableEvent")
	closePanelsEvent.Name = "ClosePanelsExcept"
	closePanelsEvent.Parent = ReplicatedStorage
end

local restingPosition = mainFrame.Position
local hiddenPosition = restingPosition + UDim2.fromOffset(0, 40)

local isOpen = false

local function setOpen(open)
	isOpen = open
	if open then
		mainFrame.Position = hiddenPosition
		mainFrame.Visible = true
		TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = restingPosition,
		}):Play()
	else
		local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = hiddenPosition,
		})
		closeTween:Play()
		closeTween.Completed:Connect(function()
			if not isOpen then
				mainFrame.Visible = false
				mainFrame.Position = restingPosition -- reset for next open/for OpenShop.lua's direct toggle
			end
		end)
	end
end

toggleEvent.Event:Connect(function()
	if isOpen then
		setOpen(false)
		return
	end
	closePanelsEvent:Fire("Index")
	setOpen(true)
end)
closeButton.MouseButton1Click:Connect(function()
	setOpen(false)
end)
closePanelsEvent.Event:Connect(function(openingId)
	if openingId ~= "Index" and isOpen then
		setOpen(false)
	end
end)

local function playDiscoverySound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/bell.wav" -- built-in Roblox sound, always available
	sound.Volume = 1
	sound.PlaybackSpeed = 1.3
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

local function showDiscoveryPopup(displayName)
	playDiscoverySound()

	local popup = Instance.new("Frame")
	popup.Size = UDim2.fromOffset(460, 110)
	popup.Position = UDim2.new(0.5, 0, 0.72, 0) -- lower on screen, not the top
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = Color3.fromRGB(25, 60, 35)
	popup.Parent = popupContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = popup

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(60, 200, 100), Color3.fromRGB(30, 130, 60))
	gradient.Rotation = 90
	gradient.Parent = popup

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 3
	stroke.Parent = popup

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 1, -16)
	label.Position = UDim2.fromOffset(12, 8)
	label.BackgroundTransparency = 1
	label.Text = "🐣 NEW CHICKEN DISCOVERED! 🐣\n" .. displayName
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = popup

	popup.Size = UDim2.fromOffset(0, 0)
	local openTween = TweenService:Create(popup, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(460, 110),
	})
	openTween:Play()

	task.delay(3, function()
		local closeTween = TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
		})
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		closeTween:Play()
		closeTween.Completed:Connect(function()
			popup:Destroy()
		end)
	end)
end

indexUpdatedEvent.OnClientEvent:Connect(function(data)
	state.discovered = data.discovered or {}
	state.completedRarities = data.completedRarities or {}
	state.multiplier = data.multiplier or 1
	refreshAll()
end)

newDiscoveryEvent.OnClientEvent:Connect(function(chickenName)
	local ui = cardsByName[chickenName]
	local displayName = ui and ui.displayName or chickenName
	showDiscoveryPopup(displayName)
end)

raritySetCompletedEvent.OnClientEvent:Connect(function(rarity, multiplier)
	local color = RARITY_COLORS[rarity] or Color3.fromRGB(255, 200, 40)
	showToast("🎉 " .. rarity .. " Set Complete!\nPermanent income bonus increased!", color, true)
end)

task.spawn(function()
	local ok, data = pcall(function()
		return getIndexFunction:InvokeServer()
	end)
	if not ok or not data then
		warn("[ChickenIndexClient] Failed to fetch index data from server.")
		return
	end

	state.discovered = data.discovered or {}
	state.completedRarities = data.completedRarities or {}
	state.multiplier = data.multiplier or 1

	local order = 1
	for _, rarity in ipairs(ChickenConfig.RarityOrder) do
		local entries = data.catalog[rarity]
		if entries and #entries > 0 then
			buildRaritySection(rarity, entries, order)
			order += 1
		end
	end

	refreshAll()
end)
