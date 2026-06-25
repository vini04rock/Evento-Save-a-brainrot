--[[
	TrackElements
	-------------
	Power-ups e armadilhas espalhados pela pista, com layout ALEATÓRIO por corrida
	(cada sessão sorteia posições novas = corrida única).

	🟢 Boost (verde): +50% por 3s, só pro PRIMEIRO que pisar (consome).
	🔵 Jump pad (azul): empurra pra frente e pra cima (reutilizável, cooldown por player).
	🔴 Slow (vermelho): -50% por 3s (reutilizável, cooldown por player).
	🟫 Hurdle (muro baixo): atravessa a largura; o player pula por cima.

	Velocidade (boost/slow) usa RacerState (relativo à velocidade-base do player).
	Geometria parenteada numa pasta "TrackElements" no Workspace; Clear() remove tudo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local EventConfig = require(ReplicatedStorage.Shared.EventConfig)
local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RacerState = require(script.Parent.RacerState)

local TrackElements = {}

local FOLDER_NAME = "TrackElements"

local function getBounds()
	local origin = EventConfig.Origin
	local totalLen = EventConfig.GetTotalLength()
	local cfg = RaceConfig.Elements
	local halfWidth = EventConfig.Floor.Width / 2
	return {
		floorTopY = origin.Y,
		centerX = origin.X,
		minZ = origin.Z + cfg.SafeStartStuds,
		maxZ = origin.Z + totalLen - cfg.SafeFinishStuds,
		minX = origin.X - (halfWidth - cfg.LaneMargin),
		maxX = origin.X + (halfWidth - cfg.LaneMargin),
	}
end

local function playerFromHit(hit: BasePart?): Player?
	local char = hit and hit.Parent
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return Players:GetPlayerFromCharacter(char)
	end
	return nil
end

-- Pad plano assentado no chão (verde/azul/vermelho).
local function makePad(name: string, size: Vector3, color: Color3, position: Vector3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Position = position
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- 🟢 Boost: PLACA flutuante semitransparente com símbolo de velocidade (o player atravessa).
-- Flutua na altura do player (bob suave) e mostra o símbolo nas duas faces.
local function makeBoostGate(cfg, position: Vector3, parent: Instance): BasePart
	local color = cfg.Color
	local lightColor = color:Lerp(Color3.fromRGB(255, 255, 255), 0.3)

	local panel = Instance.new("Part")
	panel.Name = "BoostGate"
	panel.Anchored = true
	panel.CanCollide = false
	panel.Size = cfg.Size
	panel.Color = color
	panel.Material = Enum.Material.Neon
	panel.Transparency = 0.55
	panel.CastShadow = false
	panel.Position = position
	panel.Parent = parent

	-- Brilho ambiente.
	local light = Instance.new("PointLight")
	light.Color = lightColor
	light.Brightness = 2.4
	light.Range = 16
	light.Shadows = false
	light.Parent = panel

	-- Faíscas subindo (detalhe "mágico").
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(lightColor, Color3.fromRGB(255, 255, 255))
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Rate = 16
	emitter.Speed = NumberRange.new(1, 3)
	emitter.Acceleration = Vector3.new(0, 4, 0)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = panel

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Parent = panel

		-- Painel arredondado com borda neon.
		local border = Instance.new("Frame")
		border.Name = "Border"
		border.AnchorPoint = Vector2.new(0.5, 0.5)
		border.Position = UDim2.fromScale(0.5, 0.5)
		border.Size = UDim2.fromScale(0.92, 0.86)
		border.BackgroundColor3 = Color3.fromRGB(8, 28, 16)
		border.BackgroundTransparency = 0.3
		border.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 26)
		corner.Parent = border
		local stroke = Instance.new("UIStroke")
		stroke.Color = lightColor
		stroke.Thickness = 6
		stroke.Transparency = 0
		stroke.Parent = border
		local innerGrad = Instance.new("UIGradient")
		innerGrad.Color = ColorSequence.new(color, Color3.fromRGB(10, 40, 22))
		innerGrad.Rotation = 90
		innerGrad.Parent = border

		-- Símbolo de velocidade GRANDE com gradiente + contorno.
		local label = Instance.new("TextLabel")
		label.Name = "Symbol"
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.92, 0.78)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.Text = tostring(cfg.Symbol or ">>")
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(250, 255, 250)
		label.Parent = border
		local labelStroke = Instance.new("UIStroke")
		labelStroke.Color = Color3.fromRGB(16, 78, 38)
		labelStroke.Thickness = 5
		labelStroke.Transparency = 0.05
		labelStroke.Parent = label
		local labelGrad = Instance.new("UIGradient")
		labelGrad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), lightColor)
		labelGrad.Rotation = 90
		labelGrad.Parent = label
	end

	-- Bob flutuante (sobe/desce de leve).
	panel.Position = position + Vector3.new(0, 0.8, 0)
	TweenService:Create(
		panel,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = position - Vector3.new(0, 0.8, 0) }
	):Play()

	return panel
end

-- Aplica o boost SÓ pro primeiro corredor que atravessar (a placa some — foi coletada).
local function wireBoost(gate: BasePart, cfg)
	local used = false
	gate.Touched:Connect(function(hit)
		if used then
			return
		end
		local player = playerFromHit(hit)
		if not player or not RacerState.IsRacer(player) then
			return
		end
		used = true
		RacerState.ApplyMultiplier(player, cfg.Multiplier, cfg.Duration)
		gate.CanTouch = false
		for _, gui in ipairs(gate:GetChildren()) do
			if gui:IsA("SurfaceGui") then
				gui.Enabled = false
			end
		end
		TweenService:Create(gate, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		Debris:AddItem(gate, 0.3)
	end)
end

-- 🔵 Jump pad: empurra pra frente (+Z, sentido da corrida) e pra cima (+Y).
local function wireJumpPad(pad: BasePart, cfg)
	local cooldown: { [Player]: number } = {}
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or not RacerState.IsRacer(player) then
			return
		end
		local now = os.clock()
		if cooldown[player] and (now - cooldown[player]) < cfg.PlayerCooldown then
			return
		end
		cooldown[player] = now
		-- O CLIENTE aplica a velocidade (a posse física do personagem é dele; setar no
		-- servidor não impulsiona de forma confiável). Manda força pra frente (+Z) e pra cima.
		Remotes.RaceJumpPad:FireClient(player, cfg.ForwardForce, cfg.UpForce)
	end)
end

-- 🔴 Slow: aplica lentidão (reutilizável; cooldown por player pra não re-disparar parado em cima).
local function wireSlow(pad: BasePart, cfg)
	local cooldown: { [Player]: number } = {}
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or not RacerState.IsRacer(player) then
			return
		end
		local now = os.clock()
		if cooldown[player] and (now - cooldown[player]) < cfg.PlayerCooldown then
			return
		end
		cooldown[player] = now
		RacerState.ApplyMultiplier(player, cfg.Multiplier, cfg.Duration)
	end)
end

-- 🟫 Muro baixo (atravessa a largura; o player pula por cima).
local function makeHurdle(width: number, cfg, position: Vector3, parent: Instance): BasePart
	local w = Instance.new("Part")
	w.Name = "Hurdle"
	w.Anchored = true
	w.CanCollide = true
	w.Size = Vector3.new(width, cfg.Height, cfg.Thickness)
	w.Color = cfg.Color
	w.Material = Enum.Material.Wood
	w.Position = position
	w.Parent = parent
	return w
end

-- Gera o layout (novo a cada chamada). Retorna a pasta criada.
function TrackElements.Generate(): Folder
	TrackElements.Clear()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace

	local b = getBounds()
	local cfg = RaceConfig.Elements
	local rng = Random.new() -- semente nova a cada corrida = layout único

	local function randomPadPos(size: Vector3): Vector3
		return Vector3.new(rng:NextNumber(b.minX, b.maxX), b.floorTopY + size.Y / 2, rng:NextNumber(b.minZ, b.maxZ))
	end

	for _ = 1, cfg.SpeedBoost.Count do
		local pos = Vector3.new(rng:NextNumber(b.minX, b.maxX), b.floorTopY + cfg.SpeedBoost.FloatY, rng:NextNumber(b.minZ, b.maxZ))
		wireBoost(makeBoostGate(cfg.SpeedBoost, pos, folder), cfg.SpeedBoost)
	end
	for _ = 1, cfg.JumpPad.Count do
		wireJumpPad(makePad("JumpPad", cfg.JumpPad.Size, cfg.JumpPad.Color, randomPadPos(cfg.JumpPad.Size), folder), cfg.JumpPad)
	end
	for _ = 1, cfg.Slow.Count do
		wireSlow(makePad("SlowPad", cfg.Slow.Size, cfg.Slow.Color, randomPadPos(cfg.Slow.Size), folder), cfg.Slow)
	end

	local hurdleWidth = EventConfig.Floor.Width
	for _ = 1, cfg.Hurdle.Count do
		local z = rng:NextNumber(b.minZ, b.maxZ)
		makeHurdle(hurdleWidth, cfg.Hurdle, Vector3.new(b.centerX, b.floorTopY + cfg.Hurdle.Height / 2, z), folder)
	end

	return folder
end

function TrackElements.Clear()
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
end

return TrackElements
