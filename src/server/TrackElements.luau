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

-- 🟢 Boost: aplica o multiplicador SÓ pro primeiro corredor que pisar (consome o pad).
local function wireBoost(pad: BasePart, cfg)
	local used = false
	pad.Touched:Connect(function(hit)
		if used then
			return
		end
		local player = playerFromHit(hit)
		if not player or not RacerState.IsRacer(player) then
			return
		end
		used = true
		RacerState.ApplyMultiplier(player, cfg.Multiplier, cfg.Duration)
		pad.CanTouch = false
		pad.Transparency = 0.7
		pad.Material = Enum.Material.SmoothPlastic
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
		wireBoost(makePad("BoostPad", cfg.SpeedBoost.Size, cfg.SpeedBoost.Color, randomPadPos(cfg.SpeedBoost.Size), folder), cfg.SpeedBoost)
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
