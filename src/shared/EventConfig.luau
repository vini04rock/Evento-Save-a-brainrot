--!strict
--[[
	EventConfig
	-----------
	Fonte ÚNICA de verdade para o mapa do evento.

	Fase atual: só o CHÃO do corredor. Paredes, teto e mecânicas entram depois.

	Coordenadas usadas pelo MapBuilder:
	  - O chão começa em Z = Origin.Z (largada) e cresce no sentido +Z (chegada).
	  - É centralizado no eixo X (largura).
	  - O TOPO do chão fica em Y = Origin.Y (o player anda nessa altura).
]]

local EventConfig = {}

-- Nome do modelo do mapa dentro do Workspace.
EventConfig.MapName = "EventMap"

-- Origem do mapa (topo do chão em Y; largada em Z).
EventConfig.Origin = Vector3.new(0, 0, 0)

-- Chão (tudo em studs).
-- Uma Part no Roblox tem tamanho MÁXIMO de ~2048 studs por eixo, então o chão
-- é feito de vários segmentos emendados em sequência (a partir do spawn, em +Z).
-- Comprimento total = SegmentLength * SegmentCount (ex.: 2000 * 3 = 6000).
EventConfig.Floor = {
	Width = 500, -- largura (eixo X)
	SegmentLength = 2000, -- comprimento de CADA segmento (mantenha <= 2000)
	SegmentCount = 3, -- quantos segmentos emendar (3 x 2000 = 6000 no total)
	Thickness = 4, -- espessura (eixo Y)
	Color = Color3.fromRGB(163, 162, 165), -- cinza neutro clássico
	Material = Enum.Material.Plastic, -- plástico
	Studs = true, -- topo com studs (textura de bolinhas)
}

-- Comprimento total do corredor (calculado a partir dos segmentos).
-- Útil pras mecânicas futuras (linha de chegada, progresso da corrida).
function EventConfig.GetTotalLength(): number
	return EventConfig.Floor.SegmentLength * EventConfig.Floor.SegmentCount
end

-- Linha de largada: faixa verde marcada no chão, no início do corredor.
-- Atravessa toda a largura; "Length" é o comprimento da faixa no sentido Z.
EventConfig.StartLine = {
	Enabled = true,
	Length = 50, -- comprimento da faixa (eixo Z, a direção da corrida)
	Height = 0.4, -- altura da faixa (fica assentada em cima do chão)
	ZOffset = 0, -- onde a faixa começa, a partir do início do corredor
	Color = Color3.fromRGB(120, 230, 120), -- verde claro
	Material = Enum.Material.SmoothPlastic, -- fosco (sem neon)
}

-- Linha de chegada: faixa XADREZ (preto e branco) no FIM do corredor.
-- Os quadrados são gerados em grade; SquareSize controla o tamanho de cada um.
EventConfig.FinishLine = {
	Enabled = true,
	Length = 50, -- comprimento da faixa (eixo Z)
	Height = 0.4, -- altura da faixa (fica assentada em cima do chão)
	SquareSize = 25, -- tamanho de cada quadrado do xadrez
	ZOffset = 0, -- nudge (negativo = mais pra dentro do corredor)
	ColorA = Color3.fromRGB(245, 245, 245), -- branco
	ColorB = Color3.fromRGB(20, 20, 20), -- preto
	Material = Enum.Material.SmoothPlastic,
}

-- Spawn (largada): onde o jogador nasce, no INÍCIO do corredor (Z baixo).
EventConfig.Spawn = {
	Enabled = true,
	Inset = 25, -- distância (em Z) a partir do começo do chão
	Size = Vector3.new(14, 1, 14), -- tamanho do pad de spawn
	Color = Color3.fromRGB(85, 170, 255),
	Transparency = 0, -- 1 = invisível (só funcional)
}

return EventConfig
