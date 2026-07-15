--[[
	RaceHud (cliente)
	-----------------
	Mostra na tela o andamento da corrida: aviso de espera, contagem regressiva,
	"JÁ!", cronômetro durante a corrida, sua colocação ao chegar e o quadro de
	resultados no fim. Tudo dirigido pelo RemoteEvent RaceState.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)
local TrackQuality = require(script.TrackQuality)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

TrackQuality.Start()

-- ── "Juice": sons + efeitos de câmera + confete ────────────────────────
local BASE_FOV = 70

local function playSound(soundId: number?)
	local id = tonumber(soundId) or 0
	if id <= 0 then
		return -- 0 = sem som configurado
	end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(id)
	sound.Volume = tonumber(RaceConfig.Sounds and RaceConfig.Sounds.Volume) or 0.6
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(8, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local fovToken = 0
-- Aumenta o FOV (sensação de velocidade) por `hold` segundos e volta ao normal.
local function fovPunch(extra: number, hold: number, restore: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	fovToken += 1
	local token = fovToken
	TweenService:Create(camera, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = BASE_FOV + extra,
	}):Play()
	task.delay(hold, function()
		if fovToken ~= token then
			return
		end
		local cam = workspace.CurrentCamera
		if cam then
			TweenService:Create(cam, TweenInfo.new(restore, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				FieldOfView = BASE_FOV,
			}):Play()
		end
	end)
end

-- Explosão de confete colorido no personagem (na chegada).
local function celebrate()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 90)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 150)),
	})
	emitter.LightEmission = 0.6
	emitter.Lifetime = NumberRange.new(0.9, 1.6)
	emitter.Speed = NumberRange.new(10, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.Size = NumberSequence.new(1.3)
	emitter.Parent = root
	emitter:Emit(70)
	task.delay(2.5, function()
		emitter:Destroy()
	end)
end

-- ── Helpers de UI ──────────────────────────────────────────────────────
local function withStroke(gui: GuiObject, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.Parent = gui
	return stroke
end

-- "Estica e volta" (efeito de mola) — usado nos painéis aparecendo e nos ticks do combo.
local function pulse(guiObject: GuiObject, fromScale: number, toScale: number, time: number)
	local scale = guiObject:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = guiObject
	scale.Scale = fromScale
	TweenService:Create(
		scale,
		TweenInfo.new(time, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = toScale }
	):Play()
end

-- "Entrada" de painel (surge com um pulinho, tipo game show).
local function popIn(guiObject: GuiObject)
	pulse(guiObject, 0.7, 1, 0.3)
end

local function placeText(place: number): string
	return tostring(place) .. "º"
end

local function formatTime(seconds: number): string
	return string.format("%.1fs", seconds)
end

-- ── GUI ────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "RaceHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- Texto grande central (contagem, JÁ!, mensagens).
local center = Instance.new("TextLabel")
center.Name = "Center"
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.42)
center.Size = UDim2.fromScale(0.8, 0.3)
center.BackgroundTransparency = 1
center.Font = Enum.Font.FredokaOne
center.TextScaled = true
center.TextColor3 = Color3.fromRGB(255, 255, 255)
center.Text = ""
center.Visible = false
withStroke(center, 4)
local centerConstraint = Instance.new("UITextSizeConstraint")
centerConstraint.MaxTextSize = 96
centerConstraint.MinTextSize = 24
centerConstraint.Parent = center
center.Parent = gui

-- Cronômetro no topo.
local timer = Instance.new("TextLabel")
timer.Name = "Timer"
timer.AnchorPoint = Vector2.new(0.5, 0)
timer.Position = UDim2.new(0.5, 0, 0.04, 0)
timer.Size = UDim2.fromScale(0.2, 0.08)
timer.BackgroundTransparency = 1
timer.Font = Enum.Font.FredokaOne
timer.TextScaled = true
timer.TextColor3 = Color3.fromRGB(255, 255, 255)
timer.Text = ""
timer.Visible = false
withStroke(timer, 3)
local timerConstraint = Instance.new("UITextSizeConstraint")
timerConstraint.MaxTextSize = 48
timerConstraint.MinTextSize = 14
timerConstraint.Parent = timer
timer.Parent = gui

-- Banner "Voltando para o Lobby" (contagem ao cruzar a chegada).
local returnBanner = Instance.new("TextLabel")
returnBanner.Name = "ReturnBanner"
returnBanner.AnchorPoint = Vector2.new(0.5, 0.5)
returnBanner.Position = UDim2.fromScale(0.5, 0.66)
returnBanner.Size = UDim2.fromScale(0.6, 0.12)
returnBanner.BackgroundColor3 = Color3.fromRGB(16, 20, 36)
returnBanner.BackgroundTransparency = 0.22
returnBanner.Font = Enum.Font.FredokaOne
returnBanner.TextScaled = true
returnBanner.TextColor3 = Color3.fromRGB(190, 225, 255)
returnBanner.Text = ""
returnBanner.Visible = false
local returnCorner = Instance.new("UICorner")
returnCorner.CornerRadius = UDim.new(0, 14)
returnCorner.Parent = returnBanner
withStroke(returnBanner, 3)
local returnBannerConstraint = Instance.new("UITextSizeConstraint")
returnBannerConstraint.MaxTextSize = 56
returnBannerConstraint.MinTextSize = 16
returnBannerConstraint.Parent = returnBanner
returnBanner.Parent = gui

-- Quadro de resultados.
local results = Instance.new("Frame")
results.Name = "Results"
results.AnchorPoint = Vector2.new(0.5, 0.5)
results.Position = UDim2.fromScale(0.5, 0.5)
results.Size = UDim2.fromScale(0.4, 0.55)
results.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
results.BackgroundTransparency = 0.1
results.Visible = false
Instance.new("UICorner").Parent = results
results.Parent = gui

local resultsTitle = Instance.new("TextLabel")
resultsTitle.Size = UDim2.fromScale(1, 0.15)
resultsTitle.BackgroundTransparency = 1
resultsTitle.Font = Enum.Font.FredokaOne
resultsTitle.TextScaled = true
resultsTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
resultsTitle.Text = "🏁 Resultado"
local resultsTitleConstraint = Instance.new("UITextSizeConstraint")
resultsTitleConstraint.MaxTextSize = 48
resultsTitleConstraint.MinTextSize = 16
resultsTitleConstraint.Parent = resultsTitle
resultsTitle.Parent = results

local resultsList = Instance.new("Frame")
resultsList.Position = UDim2.fromScale(0.05, 0.17)
resultsList.Size = UDim2.fromScale(0.9, 0.8)
resultsList.BackgroundTransparency = 1
resultsList.Parent = results

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0.02, 0)
listLayout.Parent = resultsList

-- ── Dashboard (velocímetro): velocidade atual + combo de boost + tempo de boost ────
-- Estilo painel de carro, montado 100% em Frames (sem imagem importada), pra combinar
-- com o resto do mapa/HUD, que também é tudo gerado por código.
local ComboMax = (RaceConfig.ComboGauge and RaceConfig.ComboGauge.MaxSegments) or 8

local dashboard = Instance.new("Frame")
dashboard.Name = "Dashboard"
dashboard.AnchorPoint = Vector2.new(0.5, 1)
dashboard.Position = UDim2.fromScale(0.5, 0.985)
dashboard.Size = UDim2.fromScale(0.50, 0.26)
dashboard.BackgroundTransparency = 1
dashboard.Visible = false
dashboard.Parent = gui

-- Flash do painel (reação ao pegar boost/jump pad) — clarão branco rápido sobre o cluster.
local flashOverlay = Instance.new("Frame")
flashOverlay.Name = "Flash"
flashOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
flashOverlay.Position = UDim2.fromScale(0.5, 0.5)
flashOverlay.Size = UDim2.fromScale(1.12, 1.35)
flashOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
flashOverlay.BackgroundTransparency = 1
flashOverlay.BorderSizePixel = 0
flashOverlay.ZIndex = 20
Instance.new("UICorner", flashOverlay).CornerRadius = UDim.new(0, 26)
flashOverlay.Parent = dashboard

local function flash()
	flashOverlay.BackgroundTransparency = 0.82
	TweenService:Create(
		flashOverlay,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	):Play()
end

-- Ajuda a "quadrar" um frame (aspect 1:1 pela altura) — usado no pod e no halo circulares.
local function makeSquare(frame: GuiObject)
	local c = Instance.new("UIAspectRatioConstraint")
	c.AspectRatio = 1
	c.DominantAxis = Enum.DominantAxis.Height
	c.Parent = frame
	return c
end

-- Halo neon pulsante CIRCULAR atrás do velocímetro central (brilho premium/futurista).
-- Camadas translúcidas quadradas (viram círculo) que respiram; quanto mais longe, mais suave.
local haloSpecs = {
	{ scale = 1.02, transparency = 0.55 },
	{ scale = 1.06, transparency = 0.72 },
	{ scale = 1.11, transparency = 0.85 },
	{ scale = 1.16, transparency = 0.93 },
}
local haloLayers = {}
for i, spec in ipairs(haloSpecs) do
	local halo = Instance.new("Frame")
	halo.Name = "Halo_" .. i
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(spec.scale, spec.scale)
	halo.BackgroundColor3 = Color3.fromRGB(70, 150, 255)
	halo.BackgroundTransparency = spec.transparency
	halo.BorderSizePixel = 0
	halo.ZIndex = 1
	Instance.new("UICorner", halo).CornerRadius = UDim.new(1, 0)
	makeSquare(halo)
	local hgrad = Instance.new("UIGradient")
	hgrad.Color = ColorSequence.new(Color3.fromRGB(130, 80, 245), Color3.fromRGB(40, 205, 255))
	hgrad.Rotation = 45
	hgrad.Parent = halo
	halo.Parent = dashboard
	table.insert(haloLayers, { frame = halo, base = spec.transparency, scale = spec.scale })
end

-- ── Módulos laterais (combo e boost) ────────────────────────────────────
-- São 3 "HUDs" soltos: combo à esquerda e boost à direita — ambos SÓ com o
-- elemento (chip/barra) e um halo pulsante atrás (sem caixa retangular).
-- Containers transparentes, encostadinhos perto do pod central.
local leftWing = Instance.new("Frame")
leftWing.Name = "LeftWing"
leftWing.AnchorPoint = Vector2.new(1, 0.5)
leftWing.Position = UDim2.fromScale(0.38, 0.5)
leftWing.Size = UDim2.fromScale(0.2, 1.0)
leftWing.BackgroundTransparency = 1
leftWing.ZIndex = 2
leftWing.Parent = dashboard

local rightWing = Instance.new("Frame")
rightWing.Name = "RightWing"
rightWing.AnchorPoint = Vector2.new(0, 0.5)
rightWing.Position = UDim2.fromScale(0.62, 0.5)
rightWing.Size = UDim2.fromScale(0.14, 1.0)
rightWing.BackgroundTransparency = 1
rightWing.ZIndex = 2
rightWing.Parent = dashboard

-- ── Pod central (velocímetro circular) ──────────────────────────────────
local centerPod = Instance.new("Frame")
centerPod.Name = "CenterPod"
centerPod.AnchorPoint = Vector2.new(0.5, 0.5)
centerPod.Position = UDim2.fromScale(0.5, 0.5)
centerPod.Size = UDim2.fromScale(1, 1)
centerPod.BackgroundColor3 = Color3.fromRGB(8, 10, 20)
centerPod.BackgroundTransparency = 0.05
centerPod.BorderSizePixel = 0
centerPod.ZIndex = 4
Instance.new("UICorner", centerPod).CornerRadius = UDim.new(1, 0)
makeSquare(centerPod)
local podGrad = Instance.new("UIGradient")
podGrad.Color = ColorSequence.new(Color3.fromRGB(20, 16, 42), Color3.fromRGB(6, 22, 40))
podGrad.Rotation = 90
podGrad.Parent = centerPod
local podStroke = Instance.new("UIStroke")
podStroke.Color = Color3.fromRGB(120, 170, 255)
podStroke.Thickness = 2
podStroke.Transparency = 0.2
podStroke.Parent = centerPod
centerPod.Parent = dashboard

-- Reflexo de vidro do pod (meia-lua de luz no topo, atrás dos ticks) — ar de vidro curvo.
local podGloss = Instance.new("Frame")
podGloss.Name = "PodGloss"
podGloss.AnchorPoint = Vector2.new(0.5, 0)
podGloss.Position = UDim2.fromScale(0.5, 0.04)
podGloss.Size = UDim2.fromScale(0.86, 0.46)
podGloss.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
podGloss.BorderSizePixel = 0
podGloss.ZIndex = 4
Instance.new("UICorner", podGloss).CornerRadius = UDim.new(1, 0)
local podGlossGrad = Instance.new("UIGradient")
podGlossGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.86),
	NumberSequenceKeypoint.new(1, 1),
})
podGlossGrad.Rotation = 90
podGlossGrad.Parent = podGloss
podGloss.Parent = centerPod

-- Cores compartilhadas do "takeover" dourado no combo MAX (usadas em setCombo).
local HALO_BLUE = Color3.fromRGB(70, 150, 255)
local GOLD = Color3.fromRGB(255, 205, 60)
local NEON_STROKE_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(155, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 220, 230)),
})
local GOLD_STROKE_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 225, 120)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 180, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 235, 150)),
})

-- Borda de "energia correndo" (gradiente neon girando) + respiração do pod/halo.
local strokeGrad = Instance.new("UIGradient")
strokeGrad.Color = NEON_STROKE_SEQ
strokeGrad.Parent = podStroke
TweenService:Create(
	strokeGrad,
	TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
	{ Rotation = 360 }
):Play()
TweenService:Create(
	podStroke,
	TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Thickness = 4, Transparency = 0.02 }
):Play()
for _, layer in ipairs(haloLayers) do
	TweenService:Create(
		layer.frame,
		TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{
			BackgroundTransparency = math.min(1, layer.base + 0.1),
			Size = UDim2.fromScale(layer.scale + 0.02, layer.scale + 0.02),
		}
	):Play()
end

-- Velocímetro (arco + números + miolo) dentro do pod. Quadrado pra o arco sair círculo.
local gauge = Instance.new("Frame")
gauge.Name = "Gauge"
gauge.AnchorPoint = Vector2.new(0.5, 0.5)
gauge.Position = UDim2.fromScale(0.5, 0.5)
gauge.Size = UDim2.fromScale(0.9, 0.9)
gauge.BackgroundTransparency = 1
gauge.ZIndex = 5
makeSquare(gauge)
gauge.Parent = centerPod

-- Escala de cor do arco (azul → ciano → laranja → vermelho), como a referência.
local function scaleColor(f: number): Color3
	local stops = {
		Color3.fromRGB(60, 150, 255),
		Color3.fromRGB(60, 230, 220),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(255, 70, 70),
	}
	local n = #stops - 1
	local seg = math.clamp(f, 0, 1) * n
	local i = math.min(math.floor(seg), n - 1)
	return stops[i + 1]:Lerp(stops[i + 2], seg - i)
end

-- Marcações densas em arco (sweep de 220° a -40° = 260°, tipo velocímetro).
-- Cada tique tem cor fixa da escala; o combo "preenche" acendendo do começo até o nível atual.
local START_ANGLE, END_ANGLE = 220, -40
local NUM_TICKS = 45
local CENTER_Y = 0.5
local comboTicks = {}
for i = 1, NUM_TICKS do
	local frac = (i - 1) / (NUM_TICKS - 1)
	local angle = START_ANGLE + frac * (END_ANGLE - START_ANGLE)
	local rad = math.rad(angle)
	local dx, dy = math.cos(rad), -math.sin(rad)
	local radius = 0.42
	-- Tiques "maiores" nas 9 posições numeradas (0..ComboMax).
	local isMajor = math.abs(frac * ComboMax - math.floor(frac * ComboMax + 0.5)) < (0.5 / NUM_TICKS)
	local base = scaleColor(frac)

	local tick = Instance.new("Frame")
	tick.Name = "Tick_" .. i
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.fromScale(0.5 + dx * radius, CENTER_Y + dy * radius)
	tick.Size = isMajor and UDim2.fromScale(0.03, 0.13) or UDim2.fromScale(0.018, 0.08)
	tick.Rotation = 90 - angle
	tick.BackgroundColor3 = base:Lerp(Color3.fromRGB(0, 0, 0), 0.55) -- apagado (escuro)
	tick.BackgroundTransparency = 0.35
	tick.BorderSizePixel = 0
	tick.ZIndex = 5
	Instance.new("UICorner", tick).CornerRadius = UDim.new(1, 0)
	tick.Parent = gauge
	table.insert(comboTicks, { frame = tick, base = base })
end

-- Números 0..ComboMax ao redor do arco (a "escala" do velocímetro).
for k = 0, ComboMax do
	local frac = k / ComboMax
	local angle = START_ANGLE + frac * (END_ANGLE - START_ANGLE)
	local rad = math.rad(angle)
	local dx, dy = math.cos(rad), -math.sin(rad)
	local radius = 0.5
	local num = Instance.new("TextLabel")
	num.Name = "Num_" .. k
	num.AnchorPoint = Vector2.new(0.5, 0.5)
	num.Position = UDim2.fromScale(0.5 + dx * radius, CENTER_Y + dy * radius)
	num.Size = UDim2.fromScale(0.1, 0.1)
	num.BackgroundTransparency = 1
	num.Font = Enum.Font.FredokaOne
	num.TextScaled = true
	num.TextColor3 = scaleColor(frac):Lerp(Color3.fromRGB(255, 255, 255), 0.3)
	num.Text = tostring(k)
	num.ZIndex = 5
	num.Parent = gauge
end

-- Miolo central escuro (esconde as pontas internas dos tiques) com a velocidade.
local hub = Instance.new("Frame")
hub.Name = "Hub"
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Position = UDim2.fromScale(0.5, CENTER_Y)
hub.Size = UDim2.fromScale(0.58, 0.58)
hub.BackgroundColor3 = Color3.fromRGB(6, 8, 18)
hub.BorderSizePixel = 0
hub.ZIndex = 6
Instance.new("UICorner", hub).CornerRadius = UDim.new(1, 0)
local hubStroke = Instance.new("UIStroke")
hubStroke.Color = Color3.fromRGB(80, 140, 240)
hubStroke.Thickness = 2
hubStroke.Transparency = 0.3
hubStroke.Parent = hub
local hubGrad = Instance.new("UIGradient")
hubGrad.Color = ColorSequence.new(Color3.fromRGB(24, 30, 60), Color3.fromRGB(6, 10, 22))
hubGrad.Rotation = 90
hubGrad.Parent = hub
hub.Parent = gauge

-- Reflexo de vidro (brilho no topo do miolo) — ar premium/glass.
local hubGloss = Instance.new("Frame")
hubGloss.Name = "Gloss"
hubGloss.AnchorPoint = Vector2.new(0.5, 0)
hubGloss.Position = UDim2.fromScale(0.5, 0.06)
hubGloss.Size = UDim2.fromScale(0.82, 0.42)
hubGloss.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
hubGloss.BorderSizePixel = 0
hubGloss.ZIndex = 6
Instance.new("UICorner", hubGloss).CornerRadius = UDim.new(1, 0)
local glossGrad = Instance.new("UIGradient")
glossGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.72),
	NumberSequenceKeypoint.new(1, 1),
})
glossGrad.Rotation = 90
glossGrad.Parent = hubGloss
hubGloss.Parent = hub

-- Número de velocidade (centro do miolo).
local speedLabel = Instance.new("TextLabel")
speedLabel.Name = "Speed"
speedLabel.AnchorPoint = Vector2.new(0.5, 0.5)
speedLabel.Position = UDim2.fromScale(0.5, 0.42)
speedLabel.Size = UDim2.fromScale(0.82, 0.42)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.FredokaOne
speedLabel.TextScaled = true
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.Text = "0"
speedLabel.ZIndex = 7
withStroke(speedLabel, 3)
speedLabel.Parent = hub

local speedUnit = Instance.new("TextLabel")
speedUnit.Name = "SpeedUnit"
speedUnit.AnchorPoint = Vector2.new(0.5, 0.5)
speedUnit.Position = UDim2.fromScale(0.5, 0.74)
speedUnit.Size = UDim2.fromScale(0.72, 0.14)
speedUnit.BackgroundTransparency = 1
speedUnit.Font = Enum.Font.GothamBold
speedUnit.TextScaled = true
speedUnit.TextColor3 = Color3.fromRGB(150, 195, 255)
speedUnit.Text = "⚡ studs/s"
speedUnit.ZIndex = 7
speedUnit.Parent = hub

-- ── Módulo de COMBO: só o chip + halo pulsante azul atrás (sem caixa) ──────
local comboHeader = Instance.new("TextLabel")
comboHeader.Name = "ComboHeader"
comboHeader.AnchorPoint = Vector2.new(0.5, 0)
comboHeader.Position = UDim2.fromScale(0.5, 0.14)
comboHeader.Size = UDim2.fromScale(0.8, 0.14)
comboHeader.BackgroundTransparency = 1
comboHeader.Font = Enum.Font.GothamBold
comboHeader.TextScaled = true
comboHeader.TextColor3 = Color3.fromRGB(120, 180, 255)
comboHeader.Text = "COMBO"
comboHeader.ZIndex = 3
comboHeader.Parent = leftWing

-- Halo pulsante atrás do chip (mesmo efeito do velocímetro/boost, em azul).
local COMBO_W, COMBO_H = 0.8, 0.42
for _, spec in ipairs({
	{ scale = 1.06, transparency = 0.6 },
	{ scale = 1.14, transparency = 0.76 },
	{ scale = 1.24, transparency = 0.88 },
}) do
	local h = Instance.new("Frame")
	h.Name = "ComboHalo"
	h.AnchorPoint = Vector2.new(0.5, 0.5)
	h.Position = UDim2.fromScale(0.5, 0.5)
	h.Size = UDim2.fromScale(COMBO_W * spec.scale, COMBO_H * spec.scale)
	h.BackgroundColor3 = Color3.fromRGB(70, 150, 255)
	h.BackgroundTransparency = spec.transparency
	h.BorderSizePixel = 0
	h.ZIndex = 2
	Instance.new("UICorner", h).CornerRadius = UDim.new(0, 12)
	h.Parent = leftWing
	TweenService:Create(
		h,
		TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{
			BackgroundTransparency = math.min(1, spec.transparency + 0.1),
			Size = UDim2.fromScale(COMBO_W * spec.scale + 0.03, COMBO_H * spec.scale + 0.03),
		}
	):Play()
end

local comboChip = Instance.new("TextLabel")
comboChip.Name = "ComboChip"
comboChip.AnchorPoint = Vector2.new(0.5, 0.5)
comboChip.Position = UDim2.fromScale(0.5, 0.5)
comboChip.Size = UDim2.fromScale(COMBO_W, COMBO_H)
comboChip.BackgroundColor3 = Color3.fromRGB(14, 18, 34)
comboChip.BackgroundTransparency = 0.1
comboChip.Font = Enum.Font.FredokaOne
comboChip.TextScaled = true
comboChip.TextWrapped = true -- permite 2 linhas: contagem + multiplicador
comboChip.TextColor3 = Color3.fromRGB(120, 200, 255)
comboChip.Text = "⚡x0"
comboChip.ZIndex = 3
Instance.new("UICorner", comboChip).CornerRadius = UDim.new(0, 12)
local COMBO_STROKE_BLUE = Color3.fromRGB(80, 150, 255)
local comboChipStroke = Instance.new("UIStroke")
comboChipStroke.Color = COMBO_STROKE_BLUE
comboChipStroke.Thickness = 2
comboChipStroke.Transparency = 0.35
comboChipStroke.Parent = comboChip
local comboChipPad = Instance.new("UIPadding")
comboChipPad.PaddingTop = UDim.new(0.08, 0)
comboChipPad.PaddingBottom = UDim.new(0.08, 0)
comboChipPad.Parent = comboChip
comboChip.Parent = leftWing

-- "MAX!" — badge que aparece (com pulinho) quando o combo bate o teto.
local maxBadge = Instance.new("TextLabel")
maxBadge.Name = "MaxBadge"
maxBadge.AnchorPoint = Vector2.new(0.5, 1)
maxBadge.Position = UDim2.fromScale(0.5, 0.9)
maxBadge.Size = UDim2.fromScale(0.8, 0.16)
maxBadge.BackgroundTransparency = 1
maxBadge.Font = Enum.Font.FredokaOne
maxBadge.TextScaled = true
maxBadge.TextColor3 = Color3.fromRGB(255, 210, 60)
maxBadge.Text = "MAX!"
maxBadge.Visible = false
maxBadge.ZIndex = 3
withStroke(maxBadge, 3)
maxBadge.Parent = leftWing

-- ── Módulo de BOOST: só a barra (sem caixa), com halo pulsante âmbar atrás ──
local FUEL_W, FUEL_H = 0.52, 0.66 -- proporção da cápsula dentro do container

-- Halo pulsante atrás da barra (mesmo efeito do velocímetro central, em âmbar).
for _, spec in ipairs({
	{ scale = 1.08, transparency = 0.6 },
	{ scale = 1.18, transparency = 0.76 },
	{ scale = 1.3, transparency = 0.88 },
}) do
	local h = Instance.new("Frame")
	h.Name = "BoostHalo"
	h.AnchorPoint = Vector2.new(0.5, 0.5)
	h.Position = UDim2.fromScale(0.5, 0.52)
	h.Size = UDim2.fromScale(FUEL_W * spec.scale, FUEL_H * spec.scale)
	h.BackgroundColor3 = Color3.fromRGB(255, 150, 40)
	h.BackgroundTransparency = spec.transparency
	h.BorderSizePixel = 0
	h.ZIndex = 2
	Instance.new("UICorner", h).CornerRadius = UDim.new(1, 0)
	h.Parent = rightWing
	TweenService:Create(
		h,
		TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{
			BackgroundTransparency = math.min(1, spec.transparency + 0.1),
			Size = UDim2.fromScale(FUEL_W * spec.scale + 0.03, FUEL_H * spec.scale + 0.03),
		}
	):Play()
end

local fuelArea = Instance.new("Frame")
fuelArea.Name = "FuelArea"
fuelArea.AnchorPoint = Vector2.new(0.5, 0.5)
fuelArea.Position = UDim2.fromScale(0.5, 0.52)
fuelArea.Size = UDim2.fromScale(FUEL_W, FUEL_H)
fuelArea.BackgroundColor3 = Color3.fromRGB(6, 8, 18)
fuelArea.BackgroundTransparency = 0.1
fuelArea.BorderSizePixel = 0
fuelArea.ClipsDescendants = true
fuelArea.ZIndex = 3
Instance.new("UICorner", fuelArea).CornerRadius = UDim.new(1, 0)
local fuelStroke = Instance.new("UIStroke")
fuelStroke.Color = Color3.fromRGB(255, 196, 40)
fuelStroke.Thickness = 2
fuelStroke.Transparency = 0.5
fuelStroke.Parent = fuelArea
fuelArea.Parent = rightWing

local fuelFill = Instance.new("Frame")
fuelFill.Name = "Fill"
fuelFill.AnchorPoint = Vector2.new(0.5, 1)
fuelFill.Position = UDim2.fromScale(0.5, 1)
fuelFill.Size = UDim2.fromScale(1, 0)
fuelFill.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
fuelFill.BorderSizePixel = 0
fuelFill.ZIndex = 4
-- Mesmo arredondamento da cápsula (o ClipsDescendants corta pelo retângulo, não pela
-- borda redonda — sem isso, os cantos quadrados da barra vazam nas pontas da cápsula).
Instance.new("UICorner", fuelFill).CornerRadius = UDim.new(1, 0)
local fuelGrad = Instance.new("UIGradient")
fuelGrad.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 120, 40))
fuelGrad.Rotation = 90
fuelGrad.Parent = fuelFill
fuelFill.Parent = fuelArea

-- Divisórias de "bateria" — SÓ na parte reta da cápsula (as pontas são arredondadas,
-- então divisória cheia lá vazava). Inset na largura pra não encostar na borda.
for _, y in ipairs({ 0.34, 0.5, 0.66 }) do
	local divider = Instance.new("Frame")
	divider.Name = "FuelCell"
	divider.AnchorPoint = Vector2.new(0.5, 0.5)
	divider.Position = UDim2.fromScale(0.5, y)
	divider.Size = UDim2.fromScale(0.82, 0.03)
	divider.BackgroundColor3 = Color3.fromRGB(6, 8, 18)
	divider.BackgroundTransparency = 0.2
	divider.BorderSizePixel = 0
	divider.ZIndex = 5
	divider.Parent = fuelArea
end

-- Ícone do módulo de boost (🔥) no topo do retângulo.
local fuelLabel = Instance.new("TextLabel")
fuelLabel.Name = "FuelHeader"
fuelLabel.AnchorPoint = Vector2.new(0.5, 0)
fuelLabel.Position = UDim2.fromScale(0.5, 0.05)
fuelLabel.Size = UDim2.fromScale(0.7, 0.12)
fuelLabel.BackgroundTransparency = 1
fuelLabel.Font = Enum.Font.FredokaOne
fuelLabel.TextScaled = true
fuelLabel.TextColor3 = Color3.fromRGB(255, 200, 120)
fuelLabel.Text = "🔥"
fuelLabel.ZIndex = 3
fuelLabel.Parent = rightWing

-- Texto de status do boost (segundos restantes / "PRONTO") no rodapé do retângulo.
local fuelText = Instance.new("TextLabel")
fuelText.Name = "FuelText"
fuelText.AnchorPoint = Vector2.new(0.5, 1)
fuelText.Position = UDim2.fromScale(0.5, 0.98)
fuelText.Size = UDim2.fromScale(0.94, 0.12)
fuelText.BackgroundTransparency = 1
fuelText.Font = Enum.Font.FredokaOne
fuelText.TextScaled = true
fuelText.TextColor3 = Color3.fromRGB(120, 140, 170)
fuelText.Text = "PRONTO"
fuelText.ZIndex = 3
withStroke(fuelText, 2)
fuelText.Parent = rightWing

-- ── Wiring do Dashboard ─────────────────────────────────────────────────
local litUpTo = 0
-- Aplica/tira o "takeover" dourado (combo MAX): borda do pod, halo central e chip.
local function setGoldMode(on: boolean)
	strokeGrad.Color = on and GOLD_STROKE_SEQ or NEON_STROKE_SEQ
	comboChipStroke.Color = on and GOLD or COMBO_STROKE_BLUE
	comboChipStroke.Transparency = on and 0.05 or 0.35
	podStroke.Color = on and GOLD or Color3.fromRGB(120, 170, 255)
	for _, layer in ipairs(haloLayers) do
		layer.frame.BackgroundColor3 = on and GOLD or HALO_BLUE
	end
end

local function setCombo(stacks: number, bonus: number?)
	local shown = math.clamp(stacks, 0, ComboMax)
	local frac = if ComboMax <= 0 then 0 else shown / ComboMax
	local newLit = math.floor(frac * NUM_TICKS + 0.5)
	for i, entry in comboTicks do
		local lit = i <= newLit
		local wasLit = i <= litUpTo
		entry.frame.BackgroundColor3 = lit and entry.base or entry.base:Lerp(Color3.fromRGB(0, 0, 0), 0.55)
		entry.frame.BackgroundTransparency = lit and 0 or 0.35
		if lit and not wasLit then
			pulse(entry.frame, 1.6, 1, 0.2)
		end
	end
	litUpTo = newLit

	-- Chip: contagem de stacks + multiplicador total de velocidade (ex.: "⚡x3" / "+150%").
	local pct = math.floor((tonumber(bonus) or 0) * 100 + 0.5)
	if shown > 0 then
		comboChip.Text = pct > 0 and string.format("⚡x%d\n+%d%%", shown, pct) or ("⚡x" .. shown)
		comboChip.TextColor3 = scaleColor(frac):Lerp(Color3.fromRGB(255, 255, 255), 0.25)
		pulse(comboChip, 1.25, 1, 0.18)
	else
		comboChip.Text = "⚡x0"
		comboChip.TextColor3 = Color3.fromRGB(120, 200, 255)
	end

	local maxed = shown >= ComboMax
	if maxed and not maxBadge.Visible then
		maxBadge.Visible = true
		pulse(maxBadge, 0.5, 1, 0.25)
	elseif not maxed then
		maxBadge.Visible = false
	end
	setGoldMode(maxed) -- MAX combo: painel inteiro dourado (feedback game show)
end

-- Cor da velocidade (branco calmo → amarelo → vermelho quanto mais rápido).
local SPEED_WARM = 45 -- a partir daqui começa a "esquentar"
local SPEED_HOT = 95 -- daqui pra cima fica no vermelho
local function speedColor(s: number): Color3
	if s < SPEED_WARM then
		return Color3.fromRGB(240, 248, 255)
	elseif s < SPEED_HOT then
		return Color3.fromRGB(240, 248, 255):Lerp(Color3.fromRGB(255, 210, 70), (s - SPEED_WARM) / (SPEED_HOT - SPEED_WARM))
	else
		return Color3.fromRGB(255, 210, 70):Lerp(Color3.fromRGB(255, 80, 70), math.clamp((s - SPEED_HOT) / 50, 0, 1))
	end
end

local FUEL_ACTIVE = Color3.fromRGB(255, 196, 40)
local FUEL_LOW = Color3.fromRGB(255, 70, 70)

local fuelTween: Tween? = nil
local boostEndsAt: number? = nil
local boostTotal = 0
local function restartFuel(duration: number)
	if fuelTween then
		fuelTween:Cancel()
	end
	boostTotal = math.max(0.05, duration)
	boostEndsAt = os.clock() + boostTotal
	fuelFill.Size = UDim2.fromScale(1, 1)
	fuelTween = TweenService:Create(
		fuelFill,
		TweenInfo.new(boostTotal, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 0) }
	)
	fuelTween:Play()
	pulse(fuelArea, 1.15, 1, 0.2)
end

local function resetDashboard()
	setCombo(0)
	if fuelTween then
		fuelTween:Cancel()
		fuelTween = nil
	end
	boostEndsAt = nil
	fuelFill.Size = UDim2.fromScale(1, 0)
	fuelText.Text = "PRONTO"
	fuelText.TextColor3 = Color3.fromRGB(120, 140, 170)
	fuelStroke.Color = FUEL_ACTIVE
	fuelStroke.Transparency = 0.6
end

Remotes.RaceComboState.OnClientEvent:Connect(function(stacks, duration, bonus)
	setCombo(tonumber(stacks) or 0, tonumber(bonus) or 0)
	local dur = tonumber(duration) or 0
	if dur > 0 then
		restartFuel(dur)
		pulse(speedLabel, 1.35, 1, 0.2) -- "pop" no número ao pegar boost
		flash() -- clarão de reação (game show)
	end
end)

-- Loop de render: velocidade reativa (número + aro do miolo) e estado do medidor de boost.
local smoothedSpeed = 0
RunService.RenderStepped:Connect(function()
	if not dashboard.Visible then
		return
	end
	local now = os.clock()

	-- Velocidade atual (física real do personagem, plano horizontal), suavizada.
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local horizontalSpeed = 0
	if root and root:IsA("BasePart") then
		local v = (root :: BasePart).AssemblyLinearVelocity
		horizontalSpeed = Vector2.new(v.X, v.Z).Magnitude
	end
	smoothedSpeed += (horizontalSpeed - smoothedSpeed) * 0.25
	speedLabel.Text = tostring(math.floor(smoothedSpeed + 0.5))

	-- Número muda de cor com a velocidade; o aro do miolo acende conforme acelera.
	local col = speedColor(smoothedSpeed)
	speedLabel.TextColor3 = col
	local heat = math.clamp((smoothedSpeed - SPEED_WARM) / (SPEED_HOT - SPEED_WARM), 0, 1)
	hubStroke.Color = col
	hubStroke.Thickness = 2 + heat * 2
	hubStroke.Transparency = 0.35 - heat * 0.3

	-- Medidor de boost: segundos restantes, glow ativo e piscada vermelha no fim.
	if boostEndsAt then
		local remaining = boostEndsAt - now
		if remaining <= 0 then
			boostEndsAt = nil
			fuelText.Text = "PRONTO"
			fuelText.TextColor3 = Color3.fromRGB(120, 140, 170)
			fuelStroke.Color = FUEL_ACTIVE
			fuelStroke.Transparency = 0.6
		else
			fuelText.Text = string.format("%.1fs", remaining)
			if remaining <= 1.2 then
				-- Últimos instantes: pisca vermelho.
				local blink = math.sin(now * 22) * 0.5 + 0.5
				fuelStroke.Color = FUEL_LOW
				fuelStroke.Transparency = 0.1 + blink * 0.4
				fuelText.TextColor3 = FUEL_LOW
			else
				fuelStroke.Color = FUEL_ACTIVE
				fuelStroke.Transparency = 0.1
				fuelText.TextColor3 = Color3.fromRGB(255, 220, 140)
			end
		end
	end
end)

-- ── Estado do cronômetro ───────────────────────────────────────────────
local raceStartClock: number? = nil
local timerConnection: RBXScriptConnection? = nil

local function stopTimer()
	if timerConnection then
		timerConnection:Disconnect()
		timerConnection = nil
	end
end

local function startTimer()
	stopTimer()
	raceStartClock = os.clock()
	timer.Visible = true
	timerConnection = RunService.RenderStepped:Connect(function()
		if raceStartClock then
			timer.Text = formatTime(os.clock() - raceStartClock)
		end
	end)
end

-- ── Animações simples ──────────────────────────────────────────────────
local function flashCenter(text: string, color: Color3)
	center.Text = text
	center.TextColor3 = color
	center.Visible = true
	pulse(center, 1.3, 1, 0.22)
end

local function buildResults(standings)
	for _, child in resultsList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if #standings == 0 then
		local none = Instance.new("TextLabel")
		none.Size = UDim2.fromScale(1, 0.12)
		none.BackgroundTransparency = 1
		none.Font = Enum.Font.GothamMedium
		none.TextScaled = true
		none.TextColor3 = Color3.fromRGB(220, 220, 220)
		none.Text = "Ninguém chegou 😅"
		local noneConstraint = Instance.new("UITextSizeConstraint")
		noneConstraint.MaxTextSize = 28
		noneConstraint.MinTextSize = 12
		noneConstraint.Parent = none
		none.Parent = resultsList
		return
	end
	for i, entry in standings do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(1, 0.12)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		local rowConstraint = Instance.new("UITextSizeConstraint")
		rowConstraint.MaxTextSize = 24
		rowConstraint.MinTextSize = 10
		rowConstraint.Parent = row
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = i
		local medal = if entry.place == 1
			then "🥇"
			elseif entry.place == 2 then "🥈"
			elseif entry.place == 3 then "🥉"
			else "  "
		row.TextColor3 = if entry.place <= 3
			then Color3.fromRGB(255, 215, 0)
			else Color3.fromRGB(230, 230, 230)
		row.Text = string.format(
			"%s %s  %s  (%s)",
			medal,
			placeText(entry.place),
			entry.name,
			formatTime(entry.time)
		)
		row.Parent = resultsList
	end
end

-- Contagem "Voltando para o Lobby em N" ao cruzar a chegada (o servidor teleporta no fim).
local returnToken = 0
local function startReturnCountdown(seconds)
	seconds = math.max(1, math.floor(tonumber(seconds) or 3))
	returnToken += 1
	local myToken = returnToken
	returnBanner.Visible = true
	task.spawn(function()
		for n = seconds, 1, -1 do
			if returnToken ~= myToken then
				return
			end
			returnBanner.Text = "🏁 Voltando para o Lobby em " .. n
			task.wait(1)
		end
		if returnToken == myToken then
			returnBanner.Text = "🏁 Voltando para o Lobby..."
		end
	end)
end

local function hideReturnCountdown()
	returnToken += 1
	returnBanner.Visible = false
end

-- ── Reage às mudanças de fase ──────────────────────────────────────────
local function onState(payload)
	local phase = payload.phase

	if phase == "waiting" then
		results.Visible = false
		timer.Visible = false
		dashboard.Visible = false
		hideReturnCountdown()
		local suffix = if payload.n then " (" .. payload.n .. ")" else ""
		flashCenter("Aguardando jogadores..." .. suffix, Color3.fromRGB(180, 220, 255))
	elseif phase == "countdown" then
		dashboard.Visible = false
		resetDashboard()
		flashCenter(tostring(payload.n), Color3.fromRGB(255, 255, 255))
		playSound(RaceConfig.Sounds.CountdownBeep)
	elseif phase == "go" then
		flashCenter("JÁ!", Color3.fromRGB(120, 255, 120))
		playSound(RaceConfig.Sounds.Go)
		startTimer()
		dashboard.Visible = true
		popIn(dashboard)
		task.delay(1, function()
			if center.Text == "JÁ!" then
				center.Visible = false
			end
		end)
	elseif phase == "finished" then
		stopTimer()
		dashboard.Visible = false
		flashCenter(
			"Você chegou em " .. placeText(payload.place) .. "!",
			Color3.fromRGB(255, 215, 0)
		)
		playSound(RaceConfig.Sounds.Finish)
		celebrate()
		startReturnCountdown(payload.returnSeconds or 3)
	elseif phase == "results" then
		stopTimer()
		center.Visible = false
		timer.Visible = false
		dashboard.Visible = false
		buildResults(payload.standings)
		results.Visible = true
		popIn(results)
	elseif phase == "returning" then
		dashboard.Visible = false
		results.Visible = false
		flashCenter("Voltando ao jogo...", Color3.fromRGB(180, 220, 255))
	end
end

Remotes.RaceState.OnClientEvent:Connect(onState)

-- Jump pad: o servidor manda; o CLIENTE se impulsiona (a posse física do char é dele,
-- então é aqui que a velocidade "pega"). Força pra cima (sai do chão) + pra frente (+Z).
Remotes.RaceJumpPad.OnClientEvent:Connect(function(forwardForce, upForce)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local vx = root.AssemblyLinearVelocity.X
		root.AssemblyLinearVelocity = Vector3.new(vx, tonumber(upForce) or 80, tonumber(forwardForce) or 110)
		playSound(RaceConfig.Sounds.JumpPad)
		fovPunch(8, 0.12, 0.25) -- "kick" rápido de câmera
		if (tonumber(forwardForce) or 0) > 0 then
			flash() -- clarão de reação só no jump pad (não no empurrão do rolo, que vem negativo)
		end
	end
end)

-- Boost (placa de velocidade): som + sensação de velocidade (FOV puxado) pela duração.
Remotes.RaceBoostFx.OnClientEvent:Connect(function(duration)
	playSound(RaceConfig.Sounds.Boost)
	fovPunch(14, tonumber(duration) or 3, 0.4)
end)

-- Empurrão genérico: o servidor manda e o CLIENTE aplica o impulso (posse física do char é dele).
-- Usado pelo rolo móvel (pra trás) e pelo ventilador lateral (pro lado). É ADITIVO ao movimento atual.
Remotes.RacePush.OnClientEvent:Connect(function(vx, vy, vz)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = root.AssemblyLinearVelocity
			+ Vector3.new(tonumber(vx) or 0, tonumber(vy) or 0, tonumber(vz) or 0)
		fovPunch(6, 0.12, 0.22) -- leve kick de câmera no impacto
	end
end)

-- ── Placar de posições AO VIVO (direita da tela) ───────────────────────
local rankMedals = { [1] = "🥇", [2] = "🥈", [3] = "🥉" }

local rankPanel = Instance.new("Frame")
rankPanel.Name = "Ranking"
rankPanel.AnchorPoint = Vector2.new(1, 0.5)
rankPanel.Position = UDim2.new(0.99, 0, 0.46, 0)
rankPanel.Size = UDim2.fromScale(0.2, 0.52)
rankPanel.BackgroundColor3 = Color3.fromRGB(16, 20, 36)
rankPanel.BackgroundTransparency = 0.22
rankPanel.BorderSizePixel = 0
rankPanel.Visible = false
Instance.new("UICorner").Parent = rankPanel
local rankPanelStroke = Instance.new("UIStroke")
rankPanelStroke.Color = Color3.fromRGB(255, 213, 92)
rankPanelStroke.Thickness = 2
rankPanelStroke.Transparency = 0.35
rankPanelStroke.Parent = rankPanel
rankPanel.Parent = gui

local rankTitle = Instance.new("TextLabel")
rankTitle.Size = UDim2.fromScale(1, 0.1)
rankTitle.BackgroundTransparency = 1
rankTitle.Font = Enum.Font.FredokaOne
rankTitle.TextScaled = true
rankTitle.TextColor3 = Color3.fromRGB(255, 224, 130)
rankTitle.Text = "🏁 Posições"
local rankTitleConstraint = Instance.new("UITextSizeConstraint")
rankTitleConstraint.MaxTextSize = 22
rankTitleConstraint.MinTextSize = 10
rankTitleConstraint.Parent = rankTitle
rankTitle.Parent = rankPanel

local rankList = Instance.new("Frame")
rankList.Position = UDim2.fromScale(0.04, 0.12)
rankList.Size = UDim2.fromScale(0.92, 0.86)
rankList.BackgroundTransparency = 1
rankList.Parent = rankPanel
local rankLayout = Instance.new("UIListLayout")
rankLayout.SortOrder = Enum.SortOrder.LayoutOrder
rankLayout.Padding = UDim.new(0.015, 0)
rankLayout.Parent = rankList

local function buildRanking(list)
	for _, child in rankList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if type(list) ~= "table" or #list == 0 then
		rankPanel.Visible = false
		return
	end
	if not rankPanel.Visible then
		rankPanel.Visible = true
		popIn(rankPanel)
	end
	for i, entry in list do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(1, 0.072)
		row.BackgroundColor3 = Color3.fromRGB(8, 12, 26)
		row.BackgroundTransparency = 0.35
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamBold
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextScaled = true
		row.LayoutOrder = i
		local rankNum = (entry.finished and entry.place) or i
		local badge = rankMedals[rankNum] or (tostring(rankNum) .. "º")
		local check = entry.finished and " ✓" or ""
		row.Text = string.format("  %s %s%s", badge, tostring(entry.name), check)
		local isLocal = entry.userId == player.UserId
		row.TextColor3 = if isLocal
			then Color3.fromRGB(130, 255, 160)
			elseif entry.finished then Color3.fromRGB(255, 224, 130)
			else Color3.fromRGB(225, 232, 245)
		if isLocal then
			row.BackgroundColor3 = Color3.fromRGB(28, 60, 36)
			row.BackgroundTransparency = 0.12
		end
		Instance.new("UICorner").Parent = row
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 16
		constraint.MinTextSize = 8
		constraint.Parent = row
		row.Parent = rankList
	end
end

-- ── Toast de mudança de posição (centro, parte de cima) ─────────────────
local posToast = Instance.new("TextLabel")
posToast.Name = "PosToast"
posToast.AnchorPoint = Vector2.new(0.5, 0.5)
posToast.Position = UDim2.fromScale(0.5, 0.26)
posToast.Size = UDim2.fromScale(0.5, 0.09)
posToast.BackgroundTransparency = 1
posToast.Font = Enum.Font.FredokaOne
posToast.TextScaled = true
posToast.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
posToast.TextStrokeTransparency = 0.4
posToast.TextTransparency = 1
posToast.Parent = gui
local posToastConstraint = Instance.new("UITextSizeConstraint")
posToastConstraint.MaxTextSize = 42
posToastConstraint.MinTextSize = 18
posToastConstraint.Parent = posToast

local posToastToken = 0
local function showPosToast(text, color)
	posToastToken += 1
	local myToken = posToastToken
	posToast.Text = text
	posToast.TextColor3 = color
	posToast.TextTransparency = 1
	posToast.Position = UDim2.fromScale(0.5, 0.30)
	TweenService:Create(
		posToast,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ TextTransparency = 0, Position = UDim2.fromScale(0.5, 0.26) }
	):Play()
	task.delay(1.3, function()
		if posToastToken ~= myToken then
			return
		end
		TweenService:Create(posToast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end)
end

local lastLocalRank = nil
local function updatePositionToast(list)
	if type(list) ~= "table" then
		return
	end
	local rank, finished
	for i, entry in ipairs(list) do
		if entry.userId == player.UserId then
			rank = (entry.finished and entry.place) or i
			finished = entry.finished
			break
		end
	end
	-- Sem o player na lista ou já terminou → zera a base (e não avisa).
	if not rank or finished then
		lastLocalRank = nil
		return
	end
	if lastLocalRank and rank ~= lastLocalRank then
		if rank < lastLocalRank then
			showPosToast(string.format("▲ Subiu pra %dº!", rank), Color3.fromRGB(120, 255, 150))
		else
			showPosToast(string.format("▼ Caiu pra %dº", rank), Color3.fromRGB(255, 120, 120))
		end
	end
	lastLocalRank = rank
end

-- ── Barra de progresso até a chegada (topo) ─────────────────────────────
local progBar = Instance.new("Frame")
progBar.Name = "Progress"
progBar.AnchorPoint = Vector2.new(0.5, 0)
progBar.Position = UDim2.new(0.5, 0, 0.04, 0)
progBar.Size = UDim2.fromScale(0.46, 0.036)
progBar.BackgroundColor3 = Color3.fromRGB(16, 20, 36)
progBar.BackgroundTransparency = 0.25
progBar.BorderSizePixel = 0
progBar.Visible = false
Instance.new("UICorner").Parent = progBar
local progStroke = Instance.new("UIStroke")
progStroke.Color = Color3.fromRGB(255, 213, 92)
progStroke.Thickness = 2
progStroke.Transparency = 0.4
progStroke.Parent = progBar
progBar.Parent = gui

local progFill = Instance.new("Frame")
progFill.AnchorPoint = Vector2.new(0, 0.5)
progFill.Position = UDim2.fromScale(0, 0.5)
progFill.Size = UDim2.fromScale(0, 1)
progFill.BackgroundColor3 = Color3.fromRGB(120, 230, 140)
progFill.BorderSizePixel = 0
Instance.new("UICorner").Parent = progFill
local progGrad = Instance.new("UIGradient")
progGrad.Color = ColorSequence.new(Color3.fromRGB(120, 230, 140), Color3.fromRGB(90, 200, 255))
progGrad.Parent = progFill
progFill.Parent = progBar

local progLabel = Instance.new("TextLabel")
progLabel.Size = UDim2.fromScale(1, 1)
progLabel.BackgroundTransparency = 1
progLabel.Font = Enum.Font.GothamBold
progLabel.TextScaled = true
progLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
progLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
progLabel.TextStrokeTransparency = 0.5
progLabel.Text = "🏁 0%"
progLabel.Parent = progBar
local progLabelC = Instance.new("UITextSizeConstraint")
progLabelC.MaxTextSize = 16
progLabelC.MinTextSize = 8
progLabelC.Parent = progLabel

local function updateProgress(list)
	local prog, finished
	for i, entry in ipairs(list) do
		if entry.userId == player.UserId then
			prog = entry.finished and 1 or (tonumber(entry.progress) or 0)
			finished = entry.finished
			break
		end
	end
	if prog == nil then
		progBar.Visible = false
		return
	end
	progBar.Visible = true
	prog = math.clamp(prog, 0, 1)
	TweenService:Create(progFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(prog, 1) }):Play()
	progLabel.Text = finished and "🏁 Chegou!" or string.format("🏁 %d%%", math.floor(prog * 100))
end

Remotes.RaceLiveRanking.OnClientEvent:Connect(function(list)
	buildRanking(list)
	updatePositionToast(list)
	updateProgress(list)
end)

-- 🛡️ Escudo: som + toast ao pegar (o ForceField em volta do char vem do servidor).
Remotes.RaceShield.OnClientEvent:Connect(function()
	playSound(RaceConfig.Sounds.Shield)
	showPosToast("🛡️ Escudo!", Color3.fromRGB(120, 220, 255))
end)

-- ── Safe-area (notch/status bar) ────────────────────────────────────────
-- A ScreenGui usa IgnoreGuiInset = true (HUD ocupa a tela toda, sem a topbar
-- do Roblox), então em celulares com notch/status bar os elementos colados no
-- topo (Timer e Progress bar) precisam de um respiro manual — senão ficam
-- atrás da área de sistema. GuiService:GetGuiInset() dá essa altura.
local function getTopInset(): number
	local ok, topLeftInset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	return (ok and typeof(topLeftInset) == "Vector2") and topLeftInset.Y or 0
end

local function applyTopSafeArea()
	local inset = getTopInset()
	timer.Position = UDim2.new(0.5, 0, 0.04, inset)
	progBar.Position = UDim2.new(0.5, 0, 0.04, inset)
end

applyTopSafeArea()
-- Recalcula ao girar a tela (mobile) ou mudar a resolução (o inset muda de tamanho).
local currentCamera = workspace.CurrentCamera
if currentCamera then
	currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyTopSafeArea)
end
