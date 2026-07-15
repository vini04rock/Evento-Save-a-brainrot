--!strict
--[[
	MapBuilder
	----------
	Constrói o mapa do evento por código, lendo o EventConfig.

	Monta: chão (segmentado), paredes laterais + tampas, teto, linha de largada
	(verde), linha de chegada (xadrez) e spawns. Tudo parametrizado pela config;
	as cores por zona vêm da EventConfig.Palette. Mecânicas entram depois.

	Uso:
		local MapBuilder = require(script.MapBuilder)
		MapBuilder.Build() -- monta (ou remonta) o mapa no Workspace
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.EventConfig)

local MapBuilder = {}

-- Cor da "zona" do segmento i (cicla a paleta se houver mais segmentos).
local function zoneColor(i: number): Color3
	local palette = Config.Palette
	return palette[((i - 1) % #palette) + 1]
end

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
		-- Cor da zona em tom pastel (mais claro), pra largada verde e a
		-- chegada xadrez continuarem bem visíveis em cima do chão.
		segment.Color = if f.UsePalette
			then zoneColor(i):Lerp(Color3.new(1, 1, 1), 0.5)
			else f.Color
		segment.Material = f.Material
		segment.TopSurface = topSurface
		segment.BottomSurface = Enum.SurfaceType.Smooth
		-- Não tem nada embaixo do chão pra receber sombra dele; poupa o custo
		-- de sombra em cima de uma laje enorme (bom pra mobile/console).
		segment.CastShadow = false
		segment.Parent = model

		if i == 1 then
			firstSegment = segment
		end
	end

	-- ── Paredes laterais (segmentadas) ─────────────────────────────────
	-- Uma parede por segmento, em cada lado, rentes à borda do chão.
	if Config.Walls.Enabled then
		local w = Config.Walls
		local folder = Instance.new("Folder")
		folder.Name = "Walls"
		folder.Parent = model

		local wallOffsetX = f.Width / 2 + w.Thickness / 2
		local wallCenterY = origin.Y + w.Height / 2

		local sides = {
			{ name = "Left", x = origin.X - wallOffsetX },
			{ name = "Right", x = origin.X + wallOffsetX },
		}

		for _, side in sides do
			for i = 1, f.SegmentCount do
				local segmentStartZ = origin.Z + (i - 1) * f.SegmentLength
				local wall = Instance.new("Part")
				wall.Name = string.format("Wall%s_%d", side.name, i)
				wall.Anchored = true
				wall.Locked = true
				wall.Size = Vector3.new(w.Thickness, w.Height, f.SegmentLength)
				wall.Position =
					Vector3.new(side.x, wallCenterY, segmentStartZ + f.SegmentLength / 2)
				wall.Color = if w.UsePalette then zoneColor(i) else w.Color
				wall.Material = w.Material
				wall.TopSurface = Enum.SurfaceType.Smooth
				wall.BottomSurface = Enum.SurfaceType.Smooth
				-- Paredes de 400 de altura ao longo dos 6000 studs seriam a maior
				-- fonte de custo de sombra do mapa; puramente visual, sem sombra
				-- projetada elas continuam lendo bem (mapa colorido e bem iluminado).
				wall.CastShadow = false
				wall.Parent = folder
			end
		end

		-- Tampas das pontas (início e fim). Largura cobre também a espessura
		-- das paredes laterais, fechando os cantos.
		local capWidth = f.Width + w.Thickness * 2
		local totalLength = Config.GetTotalLength()

		local caps = {}
		if w.StartCap then
			table.insert(caps, {
				name = "WallStart",
				z = origin.Z - w.Thickness / 2,
				color = if w.UsePalette then zoneColor(1) else w.Color,
			})
		end
		if w.FinishCap then
			table.insert(caps, {
				name = "WallFinish",
				z = origin.Z + totalLength + w.Thickness / 2,
				color = if w.UsePalette then zoneColor(f.SegmentCount) else w.Color,
			})
		end

		for _, cap in caps do
			local wall = Instance.new("Part")
			wall.Name = cap.name
			wall.Anchored = true
			wall.Locked = true
			wall.Size = Vector3.new(capWidth, w.Height, w.Thickness)
			wall.Position = Vector3.new(origin.X, wallCenterY, cap.z)
			wall.Color = cap.color
			wall.Material = w.Material
			wall.TopSurface = Enum.SurfaceType.Smooth
			wall.BottomSurface = Enum.SurfaceType.Smooth
			wall.CastShadow = false
			wall.Parent = folder
		end
	end

	-- ── Teto (segmentado) ──────────────────────────────────────────────
	-- Apoiado em cima das paredes; cobre a largura inteira (com a espessura
	-- das paredes) pra fechar certinho com elas.
	if Config.Ceiling.Enabled then
		local ce = Config.Ceiling
		local wallThickness = Config.Walls.Thickness
		local wallHeight = Config.Walls.Height

		local folder = Instance.new("Folder")
		folder.Name = "Ceiling"
		folder.Parent = model

		local ceilingWidth = f.Width + wallThickness * 2
		local ceilingY = origin.Y + wallHeight + ce.Thickness / 2

		for i = 1, f.SegmentCount do
			local segmentStartZ = origin.Z + (i - 1) * f.SegmentLength
			local part = Instance.new("Part")
			part.Name = "Ceiling_" .. i
			part.Anchored = true
			part.Locked = true
			part.Size = Vector3.new(ceilingWidth, ce.Thickness, f.SegmentLength)
			part.Position =
				Vector3.new(origin.X, ceilingY, segmentStartZ + f.SegmentLength / 2)
			part.Color = ce.Color
			part.Material = ce.Material
			part.Transparency = ce.Transparency
			part.CastShadow = false -- mantém o corredor iluminado
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Parent = folder
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

	-- ── Spawns (largada) ───────────────────────────────────────────────
	-- Vários spawns invisíveis espalhados pela largura, em cima da faixa verde.
	if Config.Spawn.Enabled then
		local s = Config.Spawn
		local folder = Instance.new("Folder")
		folder.Name = "Spawns"
		folder.Parent = model

		local usableWidth = f.Width - s.Margin * 2
		local spawnZ = origin.Z + s.ZOffset
		local spawnY = origin.Y + s.Size.Y / 2

		for i = 1, s.Count do
			-- Distribui igualmente ao longo da largura.
			local t = if s.Count == 1 then 0.5 else (i - 1) / (s.Count - 1)
			local x = origin.X - usableWidth / 2 + t * usableWidth

			local spawn = Instance.new("SpawnLocation")
			spawn.Name = "Spawn_" .. i
			spawn.Anchored = true
			spawn.Locked = true
			spawn.Neutral = true
			spawn.Duration = 0 -- sem ForceField ao nascer
			spawn.CanCollide = false -- invisível e sem degrau
			spawn.Transparency = s.Transparency
			spawn.Size = s.Size
			spawn.Position = Vector3.new(x, spawnY, spawnZ)
			spawn.TopSurface = Enum.SurfaceType.Smooth
			spawn.BottomSurface = Enum.SurfaceType.Smooth
			spawn.Parent = folder
		end
	end

	model.PrimaryPart = firstSegment
	model.Parent = workspace
	return model
end

return MapBuilder
