--!strict
-- ModzUI - Roblox Studio UI Library (ModuleScript)
-- Author: You (customizable)
-- Notes: Designed for legitimate in-game UI. No loadstring required.

local ModzUI = {}
ModzUI.__index = ModzUI

-- ===== Utilities =====
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LOCAL_PLAYER = Players.LocalPlayer
local function getPlayerGui(): PlayerGui
	local pg = LOCAL_PLAYER:FindFirstChildOfClass("PlayerGui")
	if not pg then
		pg = Instance.new("PlayerGui")
		pg.Name = "PlayerGui"
		pg.Parent = LOCAL_PLAYER
	end
	return pg
end

local function clamp(n: number, mn: number, mx: number): number
	if n < mn then return mn end
	if n > mx then return mx end
	return n
end

local function round(n: number, r: number): number
	if r <= 0 then return n end
	return math.floor((n / r) + 0.5) * r
end

local function tween(obj: Instance, t: number, props: {[string]: any}, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function create(className: string, props: {[string]: any}?, children: {Instance}?): Instance
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	return inst
end

local function corner(radius: number)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) }) :: UICorner
end

local function stroke(thickness: number, color: Color3, transparency: number)
	return create("UIStroke", {
		Thickness = thickness,
		Color = color,
		Transparency = transparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	}) :: UIStroke
end

local function pad(px: number, py: number)
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, py),
		PaddingBottom = UDim.new(0, py),
	}) :: UIPadding
end

local function listLayout(paddingPx: number)
	return create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, paddingPx),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		FillDirection = Enum.FillDirection.Vertical
	}) :: UIListLayout
end

local function textSizeFor(desc: string?): number
	if not desc or desc == "" then return 14 end
	return 13
end

-- ===== Theme =====
local DefaultTheme = {
	Bg0 = Color3.fromRGB(9, 12, 20),
	Bg1 = Color3.fromRGB(12, 16, 28),
	Card = Color3.fromRGB(18, 24, 40),
	Card2 = Color3.fromRGB(22, 30, 52),
	Line = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(235, 241, 255),
	Muted = Color3.fromRGB(175, 186, 210),
	Accent = Color3.fromRGB(88, 101, 242),
	Good = Color3.fromRGB(80, 200, 120),
	Bad = Color3.fromRGB(255, 90, 90),
}

-- ===== Option Store =====
local function makeOptionStore()
	local store = {}
	return setmetatable(store, {
		__index = function(t, k)
			-- lazy create
			local opt = rawget(t, k)
			if opt then return opt end
			opt = { Value = nil, Changed = Instance.new("BindableEvent") }
			rawset(t, k, opt)
			return opt
		end
	})
end

-- ===== Window Class =====
type WindowOptions = {
	Title: string?,
	SubTitle: string?,
	Size: UDim2?,
	Theme: {[string]: any}?,
	Acrylic: boolean?,
	MinimizeKey: Enum.KeyCode?,
	Parent: Instance?,
}

type NotifyOptions = {
	Title: string,
	Content: string,
	SubContent: string?,
	Duration: number?,
}

-- ===== Public: CreateWindow =====
function ModzUI:CreateWindow(opts: WindowOptions)
	local theme = opts.Theme or DefaultTheme
	local size = opts.Size or UDim2.fromOffset(640, 480)
	local minimizeKey = opts.MinimizeKey or Enum.KeyCode.LeftControl
	local acrylic = (opts.Acrylic == nil) and true or opts.Acrylic

	local self = setmetatable({}, ModzUI)

	self.Theme = theme
	self.Options = makeOptionStore()
	self.Tabs = {}
	self.SelectedTab = nil
	self.Unloaded = false

	-- ScreenGui root
	local parent = opts.Parent or getPlayerGui()
	local gui = create("ScreenGui", {
		Name = "ModzUI_" .. tostring(math.random(1000, 9999)),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		Parent = parent,
	})
	self.Gui = gui

	-- Optional blur
	local blur: BlurEffect? = nil
	if acrylic then
		blur = Lighting:FindFirstChild("ModzUI_Blur") :: BlurEffect?
		if not blur then
			blur = Instance.new("BlurEffect")
			blur.Name = "ModzUI_Blur"
			blur.Size = 0
			blur.Parent = Lighting
		end
		tween(blur, 0.25, { Size = 12 })
	end
	self.Blur = blur

	-- Toast holder
	local toastHolder = create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = gui,
	})
	local toastStack = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(320, 1),
		Parent = toastHolder
	})
	listLayout(10).Parent = toastStack

	self.ToastStack = toastStack

	-- Main window
	local root = create("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = size,
		BackgroundColor3 = theme.Bg0,
		Parent = gui
	}, {
		corner(16),
		stroke(1, theme.Line, 0.88),
	})
	self.Root = root

	-- Shadow (fake)
	local shadow = create("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = "rbxassetid://1316045217", -- soft shadow
		ImageTransparency = 0.78,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(10, 10, 118, 118),
		Size = UDim2.new(1, 48, 1, 48),
		Position = UDim2.new(0, -24, 0, -24),
		ZIndex = 0,
		Parent = root
	})
	root.ZIndex = 2

	-- Top bar
	local top = create("Frame", {
		Name = "Top",
		BackgroundColor3 = theme.Bg1,
		Size = UDim2.new(1, 0, 0, 64),
		Parent = root
	}, { corner(16) })
	-- mask bottom corners
	create("Frame", {
		BackgroundColor3 = theme.Bg1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = top
	})

	local title = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Text = opts.Title or "ModzUI",
		TextColor3 = theme.Text,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 18, 0, 12),
		Size = UDim2.new(1, -120, 0, 22),
		Parent = top
	})
	local sub = create("TextLabel", {
		Name = "SubTitle",
		BackgroundTransparency = 1,
		Text = opts.SubTitle or "beautiful, simple, clean",
		TextColor3 = theme.Muted,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 18, 0, 34),
		Size = UDim2.new(1, -120, 0, 18),
		Parent = top
	})

	-- Minimize button
	local minBtn = create("TextButton", {
		Name = "Minimize",
		BackgroundColor3 = theme.Card,
		Text = "—",
		TextColor3 = theme.Text,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(44, 36),
		Parent = top
	}, { corner(12), stroke(1, theme.Line, 0.9) })

	-- Body split
	local body = create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 64),
		Size = UDim2.new(1, 0, 1, -64),
		Parent = root
	})
	self.Body = body

	local sidebar = create("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = theme.Bg1,
		Size = UDim2.new(0, 170, 1, 0),
		Parent = body
	}, { stroke(1, theme.Line, 0.9) })
	corner(16).Parent = sidebar

	-- sidebar fix corners
	create("Frame", {
		BackgroundColor3 = theme.Bg1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.new(0, 16, 1, 0),
		Parent = sidebar
	})

	local tabList = create("Frame", {
		Name = "TabList",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -20, 1, -20),
		Parent = sidebar
	})
	pad(6, 6).Parent = tabList
	listLayout(8).Parent = tabList
	self.TabList = tabList

	local pages = create("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 182, 0, 0),
		Size = UDim2.new(1, -182, 1, 0),
		Parent = body
	})
	self.Pages = pages

	-- Draggable
	do
		local dragging = false
		local dragStart = Vector2.zero
		local startPos = UDim2.new()

		top.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startPos = root.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position - dragStart
				root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)
	end

	-- Minimize behavior
	self.Minimized = false
	local function setMinimized(state: boolean)
		self.Minimized = state
		if state then
			tween(body, 0.18, { Size = UDim2.new(1, 0, 0, 0) })
			tween(root, 0.18, { Size = UDim2.new(root.Size.X.Scale, root.Size.X.Offset, 0, 64) })
		else
			tween(root, 0.18, { Size = size })
			tween(body, 0.18, { Size = UDim2.new(1, 0, 1, -64) })
		end
	end
	minBtn.MouseButton1Click:Connect(function()
		setMinimized(not self.Minimized)
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == minimizeKey then
			setMinimized(not self.Minimized)
		end
	end)

	-- Public API
	function self:AddTab(tabOpts: {Title: string, Icon: string?})
		return self:_addTab(tabOpts.Title, tabOpts.Icon)
	end

	function self:SelectTab(index: number)
		local t = self.Tabs[index]
		if t then
			self:_selectTab(t)
		end
	end

	function self:Notify(n: NotifyOptions)
		self:_notify(n)
	end

	function self:Dialog(d: {Title: string, Content: string, Buttons: {{Title: string, Callback: (() -> ())?}}})
		self:_dialog(d)
	end

	function self:Destroy()
		if self.Unloaded then return end
		self.Unloaded = true
		if self.Blur then
			tween(self.Blur, 0.2, { Size = 0 })
			task.delay(0.25, function()
				if self.Blur and self.Blur.Parent then
					-- don't destroy if other windows might use it
					-- self.Blur:Destroy()
				end
			end)
		end
		if self.Gui then self.Gui:Destroy() end
	end

	return self
end

-- ===== Internal: Tab Creation =====
function ModzUI:_addTab(title: string, _icon: string?)
	local theme = self.Theme

	local tabBtn = create("TextButton", {
		BackgroundColor3 = theme.Card,
		Text = title,
		TextColor3 = theme.Text,
		TextSize = 14,
		Font = Enum.Font.GothamSemibold,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 42),
		Parent = self.TabList
	}, { corner(12), stroke(1, theme.Line, 0.9), pad(12, 0) })
	tabBtn.TextXAlignment = Enum.TextXAlignment.Left

	local indicator = create("Frame", {
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 18),
		Parent = tabBtn
	}, { corner(9) })
	indicator.BackgroundTransparency = 1

	local page = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageTransparency = 0.3,
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Visible = false,
		Parent = self.Pages
	})
	pad(14, 14).Parent = page
	local layout = listLayout(10)
	layout.Parent = page

	-- auto canvas
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end)

	local tab = {}
	tab.Title = title
	tab.Button = tabBtn
	tab.Page = page
	tab._elements = {}
	tab._theme = theme
	tab._window = self

	-- ===== Components =====
	local function makeCard(height: number?)
		local f = create("Frame", {
			BackgroundColor3 = theme.Card,
			Size = UDim2.new(1, 0, 0, height or 52),
			Parent = page
		}, { corner(14), stroke(1, theme.Line, 0.9) })
		return f
	end

	function tab:AddLabel(text: string)
		local card = makeCard(42)
		local lbl = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = theme.Muted,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -24, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			Parent = card
		})
		return { Frame = card, Label = lbl }
	end

	function tab:AddParagraph(p: {Title: string, Content: string})
		local card = makeCard(86)
		local t = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = p.Title,
			TextColor3 = theme.Text,
			TextSize = 14,
			Font = Enum.Font.GothamSemibold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -24, 0, 18),
			Position = UDim2.new(0, 12, 0, 10),
			Parent = card
		})
		local c = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = p.Content,
			TextColor3 = theme.Muted,
			TextSize = 13,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -24, 1, -34),
			Position = UDim2.new(0, 12, 0, 32),
			Parent = card
		})
		c.TextWrapped = true
		return { Frame = card, Title = t, Content = c }
	end

	function tab:AddButton(b: {Title: string, Description: string?, Callback: (() -> ())?})
		local card = makeCard(56)
		local btn = create("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 1, 0),
			Parent = card
		})

		local t = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = b.Title,
			TextColor3 = theme.Text,
			TextSize = 14,
			Font = Enum.Font.GothamSemibold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0, 10),
			Size = UDim2.new(1, -100, 0, 18),
			Parent = card
		})
		local d = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = b.Description or "",
			TextColor3 = theme.Muted,
			TextSize = textSizeFor(b.Description),
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0, 30),
			Size = UDim2.new(1, -100, 0, 16),
			Parent = card
		})

		local pill = create("Frame", {
			BackgroundColor3 = theme.Card2,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(72, 30),
			Parent = card
		}, { corner(10), stroke(1, theme.Line, 0.9) })
		create("TextLabel", {
			BackgroundTransparency = 1,
			Text = "Run",
			TextColor3 = theme.Text,
			TextSize = 13,
			Font = Enum.Font.GothamSemibold,
			Size = UDim2.new(1, 0, 1, 0),
			Parent = pill
		})

		local function press()
			tween(card, 0.08, { BackgroundColor3 = theme.Card2 })
			task.delay(0.09, function()
				if card.Parent then tween(card, 0.12, { BackgroundColor3 = theme.Card }) end
			end)
			if b.Callback then
				task.spawn(function()
					b.Callback()
				end)
			end
		end

		btn.MouseButton1Click:Connect(press)
		return { Frame = card, Press = press }
	end

	function tab:AddToggle(key: string, o: {Title: string, Default: boolean?, Description: string?})
		local card = makeCard(56)
		local opt = self.Options[key]
		opt.Value = (o.Default == nil) and false or o.Default

		local t = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = o.Title,
			TextColor3 = theme.Text,
			TextSize = 14,
			Font = Enum.Font.GothamSemibold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0, 10),
			Size = UDim2.new(1, -120, 0, 18),
			Parent = card
		})
		local d = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = o.Description or "",
			TextColor3 = theme.Muted,
			TextSize = textSizeFor(o.Description),
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0, 30),
			Size = UDim2.new(1, -120, 0, 16),
			Parent = card
		})

		local switch = create("Frame", {
			BackgroundColor3 = theme.Card2,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(54, 28),
			Parent = card
		}, { corner(14), stroke(1, theme.Line, 0.9) })

		local knob = create("Frame", {
			BackgroundColor3 = theme.Muted,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			Parent = switch
		}, { corner(10) })

		local function render()
			if opt.Value then
				tween(switch, 0.15, { BackgroundColor3 = theme.Accent })
				tween(knob, 0.15, { Position = UDim2.new(1, -24, 0.5, 0), BackgroundColor3 = Color3.fromRGB(255,255,255) })
			else
				tween(switch, 0.15, { BackgroundColor3 = theme.Card2 })
				tween(knob, 0.15, { Position = UDim2.new(0, 4, 0.5, 0), BackgroundColor3 = theme.Muted })
			end
		end
		render()

		local btn = create("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 1, 0),
			Parent = card
		})

		local toggleObj = {}
		function toggleObj:SetValue(v: boolean)
			opt.Value = (v == true)
			render()
			opt.Changed:Fire(opt.Value)
		end
		function toggleObj:OnChanged(fn: (boolean) -> ())
			return opt.Changed.Event:Connect(fn)
		end

		btn.MouseButton1Click:Connect(function()
			toggleObj:SetValue(not opt.Value)
		end)

		return toggleObj
	end

	function tab:AddSlider(key: string, o: {Title: string, Description: string?, Default: number?, Min: number, Max: number, Rounding: number?, Callback: ((number)->())?})
		local card = makeCard(74)
		local opt = self.Options[key]

		local minV, maxV = o.Min, o.Max
		local rounding = o.Rounding or 1
		opt.Value = o.Default or minV

		local t = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = o.Title,
			TextColor3 = theme.Text,
			TextSize = 14,
			Font = Enum.Font.GothamSemibold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0, 10),
			Size = UDim2.new(1, -90, 0, 18),
			Parent = card
		})
		local val = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = tostring(opt.Value),
			TextColor3 = theme.Muted,
			TextSize = 13,
			Font = Enum.Font.GothamSemibold,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 10),
			Size = UDim2.new(0, 70, 0, 18),
			Parent = card
		})

		local track = create("Frame", {
			BackgroundColor3 = theme.Card2,
			Position = UDim2.new(0, 12, 0, 44),
			Size = UDim2.new(1, -24, 0, 10),
			Parent = card
		}, { corner(10), stroke(1, theme.Line, 0.92) })

		local fill = create("Frame", {
			BackgroundColor3 = theme.Accent,
			Size = UDim2.new(0, 0, 1, 0),
			Parent = track
		}, { corner(10) })

		local knob = create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255,255,255),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			Parent = track
		}, { corner(8), stroke(1, theme.Line, 0.9) })

		local dragging = false

		local function setValue(v: number, silent: boolean?)
			v = clamp(v, minV, maxV)
			v = round(v, rounding)
			opt.Value = v
			val.Text = tostring(v)

			local alpha = (v - minV) / (maxV - minV)
			fill.Size = UDim2.new(alpha, 0, 1, 0)
			knob.Position = UDim2.new(alpha, 0, 0.5, 0)

			opt.Changed:Fire(v)
			if (not silent) and o.Callback then o.Callback(v) end
		end

		setValue(opt.Value, true)

		local function updateFromX(x: number)
			local abs = track.AbsolutePosition.X
			local w = track.AbsoluteSize.X
			local a = clamp((x - abs) / w, 0, 1)
			local v = minV + (maxV - minV) * a
			setValue(v)
		end

		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				updateFromX(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				updateFromX(input.Position.X)
			end
		end)

		local sliderObj = {}
		function sliderObj:SetValue(v: number) setValue(v) end
		function sliderObj:OnChanged(fn: (number)->()) return opt.Changed.Event:Connect(fn) end
		return sliderObj
	end

	function tab:AddInput(key: string, o: {Title: string, Default: string?, Placeholder: string?, Numeric: boolean?, Finished: boolean?, Callback: ((string)->())?})
		local card = makeCard(64)
		local opt = self.Options[key]
		opt.Value = o.Default or ""

		local t = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = o.Title,
			TextColor3 = theme.Text,
			TextSize = 14,
			Font = Enum.Font.GothamSemibold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0, 10),
			Size = UDim2.new(1, -24, 0, 18),
			Parent = card
		})

		local box = create("TextBox", {
			BackgroundColor3 = theme.Card2,
			Text = opt.Value,
			PlaceholderText = o.Placeholder or "",
			TextColor3 = theme.Text,
			PlaceholderColor3 = theme.Muted,
			TextSize = 13,
			Font = Enum.Font.Gotham,
			ClearTextOnFocus = false,
			Position = UDim2.new(0, 12, 0, 34),
			Size = UDim2.new(1, -24, 0, 24),
			Parent = card
		}, { corner(10), stroke(1, theme.Line, 0.92), pad(10, 0) })
		box.TextXAlignment = Enum.TextXAlignment.Left

		local function commit(text: string)
			if o.Numeric then
				text = text:gsub("[^%d%.%-]", "")
			end
			opt.Value = text
			opt.Changed:Fire(text)
			if o.Callback then o.Callback(text) end
		end

		if o.Finished then
			box.FocusLost:Connect(function(enterPressed)
				if enterPressed then commit(box.Text) end
			end)
		else
			box:GetPropertyChangedSignal("Text"):Connect(function()
				commit(box.Text)
			end)
		end

		local inputObj = {}
		function inputObj:OnChanged(fn: (string)->()) return opt.Changed.Event:Connect(fn) end
		function inputObj:SetValue(v: string) box.Text = v; commit(v) end
		inputObj.Value = opt.Value
		return inputObj
	end

	function tab:AddDropdown(key: string, o: {Title: string, Description: string?, Values: {string}, Multi: boolean?, Default: any})
		local card = makeCard(62)
		local opt = self.Options[key]
		local multi = (o.Multi == true)

		-- store value: string OR map<string,bool>
		if multi then
			if typeof(o.Default) == "table" then
				-- can be array or map
				local map = {}
				for k, v in pairs(o.Default) do
					if typeof(k) == "number" then map[v] = true else map[k] = (v == true) end
				end
				opt.Value = map
			else
				opt.Value = {}
			end
		else
			if typeof(o.Default) == "number" then
				opt.Value = o.Values[o.Default] or o.Values[1]
			else
				opt.Value = o.Default or o.Values[1]
			end
		end

		local t = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = o.Title,
			TextColor3 = theme.Text,
			TextSize = 14,
			Font = Enum.Font.GothamSemibold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0, 10),
			Size = UDim2.new(1, -48, 0, 18),
			Parent = card
		})

		local display = create("TextLabel", {
			BackgroundTransparency = 1,
			TextColor3 = theme.Muted,
			TextSize = 13,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0, 32),
			Size = UDim2.new(1, -60, 0, 18),
			Parent = card
		})

		local arrow = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = "▾",
			TextColor3 = theme.Muted,
			TextSize = 16,
			Font = Enum.Font.GothamBold,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 2),
			Size = UDim2.fromOffset(20, 20),
			Parent = card
		})

		local btn = create("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 1, 0),
			Parent = card
		})

		local popup = create("Frame", {
			BackgroundColor3 = theme.Bg1,
			Visible = false,
			ClipsDescendants = true,
			Position = UDim2.new(0, 0, 1, 8),
			Size = UDim2.new(1, 0, 0, 0),
			Parent = card
		}, { corner(14), stroke(1, theme.Line, 0.88) })
		pad(10, 10).Parent = popup
		local popList = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = popup })
		local popLayout = listLayout(6); popLayout.Parent = popList
		popLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			local h = math.min(220, popLayout.AbsoluteContentSize.Y)
			popup.Size = UDim2.new(1, 0, 0, h + 20)
		end)

		local function formatValue()
			if multi then
				local picked = {}
				for v, on in pairs(opt.Value) do
					if on then table.insert(picked, v) end
				end
				table.sort(picked)
				if #picked == 0 then return "None" end
				return table.concat(picked, ", ")
			else
				return tostring(opt.Value)
			end
		end

		local function render()
			display.Text = formatValue()
		end
		render()

		local function setSingle(v: string)
			opt.Value = v
			render()
			opt.Changed:Fire(opt.Value)
		end

		local function setMultiMap(map: {[string]: boolean})
			opt.Value = map
			render()
			opt.Changed:Fire(opt.Value)
		end

		-- build items
		local itemButtons = {}
		for _, v in ipairs(o.Values) do
			local item = create("TextButton", {
				BackgroundColor3 = theme.Card,
				Text = v,
				TextColor3 = theme.Text,
				TextSize = 13,
				Font = Enum.Font.Gotham,
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 34),
				Parent = popList
			}, { corner(10), stroke(1, theme.Line, 0.92), pad(10, 0) })
			item.TextXAlignment = Enum.TextXAlignment.Left

			local check = create("TextLabel", {
				BackgroundTransparency = 1,
				Text = multi and "✓" or "",
				TextColor3 = theme.Good,
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				Parent = item
			})
			itemButtons[v] = {Btn = item, Check = check}

			local function updateCheck()
				if multi then
					check.Text = (opt.Value[v] == true) and "✓" or ""
				end
			end

			item.MouseButton1Click:Connect(function()
				if multi then
					local newMap = {}
					for k2, on in pairs(opt.Value) do newMap[k2] = on end
					newMap[v] = not (newMap[v] == true)
					setMultiMap(newMap)
					updateCheck()
				else
					setSingle(v)
					popup.Visible = false
				end
			end)

			updateCheck()
		end

		local open = false
		btn.MouseButton1Click:Connect(function()
			open = not open
			popup.Visible = open
			arrow.Text = open and "▴" or "▾"
		end)

		local dropdownObj = {}
		function dropdownObj:SetValue(v: any)
			if multi then
				local map = {}
				if typeof(v) == "table" then
					for k, state in pairs(v) do map[k] = (state == true) end
				end
				setMultiMap(map)
				for vv, obj in pairs(itemButtons) do
					obj.Check.Text = (opt.Value[vv] == true) and "✓" or ""
				end
			else
				setSingle(tostring(v))
			end
		end
		function dropdownObj:OnChanged(fn: (any)->())
			return opt.Changed.Event:Connect(fn)
		end
		return dropdownObj
	end

	function tab:AddKeybind(key: string, o: {Title: string, Mode: "Always"|"Toggle"|"Hold", Default: string, Callback: ((boolean)->())?, ChangedCallback: ((any)->())?})
		local card = makeCard(56)
		local opt = self.Options[key]

		-- resolve default key
		local function parseKey(s: string)
			if s == "MB1" then return Enum.UserInputType.MouseButton1 end
			if s == "MB2" then return Enum.UserInputType.MouseButton2 end
			local ok, kc = pcall(function() return Enum.KeyCode[s] end)
			if ok and kc then return kc end
			return Enum.KeyCode.LeftControl
		end

		opt.Value = o.Default
		opt.Mode = o.Mode or "Toggle"
		opt.State = false

		local t = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = o.Title,
			TextColor3 = theme.Text,
			TextSize = 14,
			Font = Enum.Font.GothamSemibold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0, 10),
			Size = UDim2.new(1, -160, 0, 18),
			Parent = card
		})

		local pill = create("TextButton", {
			BackgroundColor3 = theme.Card2,
			Text = opt.Value,
			TextColor3 = theme.Text,
			TextSize = 13,
			Font = Enum.Font.GothamSemibold,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(120, 30),
			Parent = card
		}, { corner(10), stroke(1, theme.Line, 0.9) })

		local listening = false
		pill.MouseButton1Click:Connect(function()
			if listening then return end
			listening = true
			pill.Text = "Press a key..."
			local conn; conn = UserInputService.InputBegan:Connect(function(input, gp)
				if gp then return end
				local name = nil
				if input.UserInputType == Enum.UserInputType.Keyboard then
					name = input.KeyCode.Name
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
					name = "MB1"
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
					name = "MB2"
				end
				if name then
					opt.Value = name
					pill.Text = name
					listening = false
					if conn then conn:Disconnect() end
					if o.ChangedCallback then o.ChangedCallback(parseKey(name)) end
					opt.Changed:Fire(opt.Value)
				end
			end)
		end)

		local clickEvent = Instance.new("BindableEvent")
		local function setState(state: boolean)
			opt.State = state
			if o.Callback then o.Callback(state) end
			clickEvent:Fire(state)
		end

		UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			if listening then return end

			local match = false
			if input.UserInputType == Enum.UserInputType.Keyboard then
				match = (input.KeyCode.Name == opt.Value)
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				match = (opt.Value == "MB1")
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				match = (opt.Value == "MB2")
			end

			if not match then return end

			if opt.Mode == "Always" then
				setState(true)
			elseif opt.Mode == "Toggle" then
				setState(not opt.State)
			elseif opt.Mode == "Hold" then
				setState(true)
			end
		end)

		UserInputService.InputEnded:Connect(function(input, gp)
			if gp then return end
			if opt.Mode ~= "Hold" then return end
			local match = false
			if input.UserInputType == Enum.UserInputType.Keyboard then
				match = (input.KeyCode.Name == opt.Value)
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				match = (opt.Value == "MB1")
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				match = (opt.Value == "MB2")
			end
			if match then setState(false) end
		end)

		local keyObj = {}
		function keyObj:GetState() return opt.State end
		function keyObj:SetValue(v: string, mode: string?)
			opt.Value = v
			if mode then opt.Mode = mode end
			pill.Text = opt.Value
			opt.Changed:Fire(opt.Value)
		end
		function keyObj:OnClick(fn: (boolean)->()) return clickEvent.Event:Connect(fn) end
		function keyObj:OnChanged(fn: (string)->()) return opt.Changed.Event:Connect(fn) end
		return keyObj
	end

	-- wire tab click
	tabBtn.MouseButton1Click:Connect(function()
		self:_selectTab(tab)
	end)

	table.insert(self.Tabs, tab)

	-- select first tab by default
	if not self.SelectedTab then
		self:_selectTab(tab)
	end

	return tab
end

function ModzUI:_selectTab(tab)
	if self.SelectedTab == tab then return end
	for _, t in ipairs(self.Tabs) do
		t.Page.Visible = false
		t.Button.BackgroundColor3 = self.Theme.Card
	end
	self.SelectedTab = tab
	tab.Page.Visible = true
	tab.Button.BackgroundColor3 = self.Theme.Card2
end

-- ===== Toast Notify =====
function ModzUI:_notify(n: NotifyOptions)
	local theme = self.Theme
	local holder = self.ToastStack

	local card = create("Frame", {
		BackgroundColor3 = theme.Bg1,
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		Parent = holder
	}, { corner(14), stroke(1, theme.Line, 0.88) })
	pad(12, 10).Parent = card

	local title = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = n.Title,
		TextColor3 = theme.Text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = card
	})

	local content = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = n.Content,
		TextColor3 = theme.Muted,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 34),
		Parent = card
	})

	local sub = nil
	if n.SubContent and n.SubContent ~= "" then
		sub = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = n.SubContent,
			TextColor3 = theme.Muted,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 0, 0, 54),
			Size = UDim2.new(1, 0, 0, 18),
			Parent = card
		})
	end

	local targetH = sub and 86 or 72
	card.Size = UDim2.new(1, 0, 0, 0)
	tween(card, 0.18, { Size = UDim2.new(1, 0, 0, targetH) })

	local dur = n.Duration
	if dur == nil then return end
	task.delay(dur, function()
		if not card.Parent then return end
		tween(card, 0.16, { Size = UDim2.new(1, 0, 0, 0) })
		task.delay(0.18, function()
			if card.Parent then card:Destroy() end
		end)
	end)
end

-- ===== Dialog (modal) =====
function ModzUI:_dialog(d)
	local theme = self.Theme
	local overlay = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(0,0,0),
		BackgroundTransparency = 1,
		Size = UDim2.new(1,0,1,0),
		Parent = self.Gui
	})

	local modal = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(420, 220),
		BackgroundColor3 = theme.Bg1,
		Parent = overlay
	}, { corner(16), stroke(1, theme.Line, 0.88) })
	pad(16, 14).Parent = modal

	local t = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = d.Title,
		TextColor3 = theme.Text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = modal
	})

	local c = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = d.Content,
		TextColor3 = theme.Muted,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Position = UDim2.new(0, 0, 0, 30),
		Size = UDim2.new(1, 0, 1, -80),
		Parent = modal
	})

	local btnRow = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 46),
		Parent = modal
	})

	local hl = create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10)
	})
	hl.Parent = btnRow

	local function close()
		tween(overlay, 0.15, { BackgroundTransparency = 1 })
		tween(modal, 0.15, { Size = UDim2.fromOffset(420, 200) })
		task.delay(0.16, function()
			if overlay.Parent then overlay:Destroy() end
		end)
	end

	for i, b in ipairs(d.Buttons or {}) do
		local btn = create("TextButton", {
			BackgroundColor3 = (i == 1) and theme.Accent or theme.Card,
			Text = b.Title,
			TextColor3 = theme.Text,
			TextSize = 13,
			Font = Enum.Font.GothamSemibold,
			AutoButtonColor = false,
			Size = UDim2.fromOffset(110, 36),
			Parent = btnRow
		}, { corner(12), stroke(1, theme.Line, 0.9) })

		btn.MouseButton1Click:Connect(function()
			if b.Callback then task.spawn(b.Callback) end
			close()
		end)
	end

	-- animate in
	overlay.BackgroundTransparency = 1
	tween(overlay, 0.12, { BackgroundTransparency = 0.45 })
	modal.Size = UDim2.fromOffset(420, 200)
	tween(modal, 0.14, { Size = UDim2.fromOffset(420, 220) })
end

return ModzUI
