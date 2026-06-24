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

-- Paleta de cores por ZONA (uma cor por segmento). Dá a sensação de progresso
-- na corrida: o player vê a pista mudando de cor até a chegada. Cores alegres
-- (jogo infantil). Se houver mais segmentos que cores, a paleta se repete.
EventConfig.Palette = {
	Color3.fromRGB(0, 162, 255), -- zona 1: azul céu
	Color3.fromRGB(255, 193, 7), -- zona 2: amarelo
	Color3.fromRGB(255, 82, 145), -- zona 3: rosa
}

-- Chão (tudo em studs).
-- Uma Part no Roblox tem tamanho MÁXIMO de ~2048 studs por eixo, então o chão
-- é feito de vários segmentos emendados em sequência (a partir do spawn, em +Z).
-- Comprimento total = SegmentLength * SegmentCount (ex.: 2000 * 3 = 6000).
EventConfig.Floor = {
	Width = 500, -- largura (eixo X)
	SegmentLength = 2000, -- comprimento de CADA segmento (mantenha <= 2000)
	SegmentCount = 3, -- quantos segmentos emendar (3 x 2000 = 6000 no total)
	Thickness = 4, -- espessura (eixo Y)
	Color = Color3.fromRGB(163, 162, 165), -- usado só se UsePalette = false
	Material = Enum.Material.Plastic, -- plástico
	Studs = true, -- topo com studs (textura de bolinhas)
	UsePalette = true, -- colore por zona (tom pastel da cor da zona)
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

-- Paredes laterais (esquerda e direita), ao longo de todo o comprimento.
-- Também são SEGMENTADAS (uma por segmento do chão) por causa do limite ~2048.
EventConfig.Walls = {
	Enabled = true,
	Height = 400, -- altura em Y
	Thickness = 4, -- espessura
	Color = Color3.fromRGB(150, 155, 165), -- usado só se UsePalette = false
	Material = Enum.Material.SmoothPlastic,
	StartCap = true, -- parede fechando o INÍCIO (atrás da largada)
	FinishCap = true, -- parede fechando o FIM (na chegada)
	UsePalette = true, -- paredes na cor viva da zona (acompanham o chão)
}

-- Teto por cima do corredor. Também SEGMENTADO (limite ~2048). Fica apoiado
-- em cima das paredes (na altura Walls.Height). Vidro claro pra manter o
-- corredor bem iluminado e dar um ar de galeria.
EventConfig.Ceiling = {
	Enabled = true,
	Thickness = 4, -- espessura (eixo Y)
	Color = Color3.fromRGB(205, 238, 255), -- azul bem claro
	Material = Enum.Material.Glass,
	Transparency = 0.5, -- 0 = opaco, 1 = invisível
}

-- Spawns (largada): vários pontos espalhados pela LARGURA, em cima da faixa
-- verde, no início do corredor. Invisíveis (só funcionais).
EventConfig.Spawn = {
	Enabled = true,
	Count = 12, -- quantos spawns espalhar pela largura
	Margin = 30, -- folga das paredes laterais ao distribuir
	ZOffset = 25, -- posição em Z (em cima da faixa verde de largada)
	Size = Vector3.new(8, 1, 8), -- tamanho de cada spawn
	Transparency = 1, -- 1 = invisível
}

return EventConfig
