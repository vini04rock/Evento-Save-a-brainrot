--!strict
--[[
	MapBuilder
	----------
	Constrói o mapa do evento por código, lendo o EventConfig.

	Fase atual: só o chão. É de propósito enxuto — paredes/teto/mecânicas
	entram depois, cada um no seu lugar, sem quebrar o que já existe.

	Uso:
		local MapBuilder = require(script.MapBuilder)
		MapBuilder.Build() -- monta (ou remonta) o mapa no Workspace
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.EventConfig)

local MapBuilder = {}

--[[
	Constrói (ou reconstrói) o mapa.
	Idempotente: remove a versão anterior antes de criar a nova.
	Retorna o Model criado.
]]
function MapBuilder.Build(): Model
	local f = Config.Floor
	local origin = Config.Origin

	-- Remove versão anterior (Play-test sempre com o mapa atualizado).
	local existing = workspace:FindFirstChild(Config.MapName)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = Config.MapName

	-- ── Chão (segmentos emendados) ─────────────────────────────────────
	-- Como a Part tem tamanho máx. de ~2048 studs, o chão é feito de vários
	-- segmentos de SegmentLength emendados em sequência a partir do spawn (+Z).
	-- Topo de cada segmento em Y = Origin.Y (centro meia-espessura abaixo).
	local topSurface = if f.Studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	local firstSegment: Part? = nil

	for i = 1, f.SegmentCount do
		local segment = Instance.new("Part")
		segment.Name = "Floor_" .. i
		segment.Anchored = true
		segment.Locked = true
		segment.Size = Vector3.new(f.Width, f.Thickness, f.SegmentLength)
		-- Início deste segmento no eixo Z (o primeiro começa em Origin.Z).
		local segmentStartZ = origin.Z + (i - 1) * f.SegmentLength
		segment.Position = Vector3.new(
			origin.X,
			origin.Y - f.Thickness / 2,
			segmentStartZ + f.SegmentLength / 2
		)
		segment.Color = f.Color
		segment.Material = f.Material
		segment.TopSurface = topSurface
		segment.BottomSurface = Enum.SurfaceType.Smooth
		segment.Parent = model

		if i == 1 then
			firstSegment = segment
		end
	end

	-- ── Linha de largada (faixa verde) ─────────────────────────────────
	-- Atravessa toda a largura do chão, assentada em cima dele, no início.
	if Config.StartLine.Enabled then
		local sl = Config.StartLine
		local line = Instance.new("Part")
		line.Name = "StartLine"
		line.Anchored = true
		line.Locked = true
		line.CanCollide = false -- só marcação, não bloqueia o player
		line.Size = Vector3.new(f.Width, sl.Height, sl.Length)
		-- Bottom encostando no topo do chão (Origin.Y); começa em Origin.Z + ZOffset.
		line.Position = Vector3.new(
			origin.X,
			origin.Y + sl.Height / 2,
			origin.Z + sl.ZOffset + sl.Length / 2
		)
		line.Color = sl.Color
		line.Material = sl.Material
		line.TopSurface = Enum.SurfaceType.Smooth
		line.BottomSurface = Enum.SurfaceType.Smooth
		line.Parent = model
	end

	-- ── Linha de chegada (xadrez preto e branco) ───────────────────────
	-- Grade de quadrados alternados, atravessando a largura, no FIM do corredor.
	if Config.FinishLine.Enabled then
		local fl = Config.FinishLine
		local totalLength = Config.GetTotalLength()

		local folder = Instance.new("Folder")
		folder.Name = "FinishLine"
		folder.Parent = model

		-- Quantos quadrados cabem; ajusta o tamanho da célula pra cobrir exato.
		local columns = math.max(1, math.floor(f.Width / fl.SquareSize))
		local rows = math.max(1, math.floor(fl.Length / fl.SquareSize))
		local cellW = f.Width / columns
		local cellL = fl.Length / rows

		-- A faixa termina no fim do corredor (Origin.Z + comprimento total).
		local bandStartZ = origin.Z + totalLength - fl.Length + fl.ZOffset
		local bandStartX = origin.X - f.Width / 2

		for col = 0, columns - 1 do
			for row = 0, rows - 1 do
				local cell = Instance.new("Part")
				cell.Name = string.format("Finish_%d_%d", col + 1, row + 1)
				cell.Anchored = true
				cell.Locked = true
				cell.CanCollide = false -- só marcação
				cell.Size = Vector3.new(cellW, fl.Height, cellL)
				cell.Position = Vector3.new(
					bandStartX + cellW * (col + 0.5),
					origin.Y + fl.Height / 2,
					bandStartZ + cellL * (row + 0.5)
				)
				cell.Color = if (col + row) % 2 == 0 then fl.ColorA else fl.ColorB
				cell.Material = fl.Material
				cell.TopSurface = Enum.SurfaceType.Smooth
				cell.BottomSurface = Enum.SurfaceType.Smooth
				cell.Parent = folder
			end
		end
	end

	-- ── Spawn (largada) ────────────────────────────────────────────────
	-- Fica no INÍCIO do corredor, centralizado na largura, em cima do chão.
	if Config.Spawn.Enabled then
		local s = Config.Spawn
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "StartSpawn"
		spawn.Anchored = true
		spawn.Locked = true
		spawn.Neutral = true
		spawn.Duration = 0 -- sem ForceField ao nascer
		spawn.Size = s.Size
		-- Bottom do pad encostando no topo do chão (Origin.Y).
		spawn.Position = Vector3.new(origin.X, origin.Y + s.Size.Y / 2, origin.Z + s.Inset)
		spawn.Color = s.Color
		spawn.Transparency = s.Transparency
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.BottomSurface = Enum.SurfaceType.Smooth
		spawn.Parent = model
	end

	model.PrimaryPart = firstSegment
	model.Parent = workspace
	return model
end

return MapBuilder
