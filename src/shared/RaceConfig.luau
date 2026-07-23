--!strict
--[[
	RaceConfig
	----------
	Parâmetros do FLUXO da corrida (separado do EventConfig, que é só o mapa).
	Modelo: SESSÃO ÚNICA — o pessoal é teleportado, corre uma vez, e no fim
	volta pro jogo principal.
]]

local RaceConfig = {}

-- Quantos jogadores no mínimo pra começar. 1 = dá pra testar sozinho no Studio.
RaceConfig.MinPlayers = 1

-- Tempo de "saguão" depois de atingir o mínimo, pra esperar o pessoal chegar.
-- 40s (era 5s, 2026-07-17): reduz a chance de alguém chegar DEPOIS da foto dos corredores
-- (ver bugfix do Players.PlayerAdded em RaceManager) — mas o fix real é esse PlayerAdded,
-- isso aqui só diminui a frequência na prática / deixa mais gente correndo junto.
RaceConfig.WaitForPlayersSeconds = 40

-- Contagem regressiva antes da largada (3, 2, 1, JÁ!).
RaceConfig.CountdownSeconds = 3

-- FALLBACK de velocidade. A corrida usa a velocidade que o player tem no jogo principal
-- (enviada pelo lobby via TeleportData). Este valor só é usado quando não há essa info
-- (ex.: testando no Studio, ou jogador que entrou sem passar pelo teleporte do evento).
RaceConfig.RaceWalkSpeed = 60

-- Tempo máximo da corrida (5 min). Quem não terminar até lá é teleportado de volta.
RaceConfig.RaceTimeLimitSeconds = 300

-- Contagem "Voltando para o Lobby em N" ao cruzar a chegada, antes de teleportar (individual).
RaceConfig.FinishReturnDelaySeconds = 3

-- Quanto tempo mostra o resultado antes de teleportar de volta (não usado no modelo individual).
RaceConfig.ResultsSeconds = 8

-- ── Power-ups e armadilhas espalhados pela pista ──────────────────────────────
-- RandomLayout = true: cada corrida sorteia posições novas (layout único por sessão).
--
-- 🎨 LINGUAGEM DE COR (por FUNÇÃO, não por elemento) — a criança aprende jogando:
--    🟢 verde / 🟡 dourado → te AJUDA    (boost, mega boost)
--    🔴 vermelho           → te ATRAPALHA (lentidão, rolo, barra giratória)
--    🔵 azul               → te MOVE      (jump pad, ventilador — ambos empurram)
-- Ao criar um elemento novo, escolha a cor pelo que ele FAZ com o jogador.
--
-- 🔣 Symbol: ícone que flutua acima do pad (BillboardGui sempre virado pra câmera).
-- Use símbolos SEM direção — o billboard gira junto com a câmera, então uma seta
-- apontaria pra tela, não pro mundo. Direção quem mostra é a partícula/o movimento.
-- 🎨 ESTILO COMPARTILHADO dos pads QUADRADOS (jump pad, lentidão, ventilador).
-- Todos usam a mesma "carcaça": moldura preta (base) + face neon (o que brilha e detecta
-- o toque) + holograma 3D flutuando por cima. Mude aqui e os três mudam juntos.
RaceConfig.PadStyle = {
	FrameColor = Color3.fromRGB(10, 10, 14), -- moldura preta em volta da face (contraste)
	FrameThickness = 1.4, -- altura da carcaça (eixo Y) — baixinha, o player passa por cima
	FaceInset = 0.86, -- a face neon ocupa N% do quadrado (o resto vira a borda preta)
	FaceTransparency = 0.12, -- opacidade da face (0 = sólido, 1 = invisível)
	-- Holograma 3D (seta pra jump/ventilador; X pro slow), montado com parts Neon leves.
	HoloFloatY = 7, -- altura do holograma acima do chão do pad
	HoloBob = 0.7, -- quanto o holograma sobe/desce flutuando (amplitude)
	HoloThickness = 1.4, -- grossura das barras do holograma
	HoloArrowLength = 7, -- comprimento da haste da seta
	-- Listras de perigo (só o pad de lentidão): amarelo/preto diagonal (linguagem "cuidado").
	HazardColorA = Color3.fromRGB(250, 200, 40), -- amarelo
	HazardColorB = Color3.fromRGB(22, 22, 26), -- preto
	-- Ajuste fino no Studio: se os chevrons (setas do chão) apontarem pro lado errado,
	-- gire de 90 em 90 (0 / 90 / 180 / 270) até baterem com o holograma 3D (que é sempre certo).
	ChevronYaw = 0,
}

RaceConfig.Elements = {
	RandomLayout = true,
	SafeStartStuds = 300, -- não coloca nada nos primeiros N studs (depois da largada)
	SafeFinishStuds = 300, -- nem nos últimos N studs (antes da chegada)
	-- Folga das paredes ao sortear o X dos pads. Alcance = ±(Floor.Width/2 − LaneMargin).
	-- 25 (era 70): os pads têm ~10 de "raio", então 70 era folga demais e deixava uma faixa
	-- morta de 70 studs em cada parede — tudo parecia amontoado no meio. Com 25 eles espalham
	-- por quase toda a largura (borda do pad a ~15 studs da parede). Aumente se encostarem.
	LaneMargin = 25,

	-- Checkpoints da corrida (frações do percurso, 0..1). FONTE ÚNICA: os ARCOS de % e as
	-- BARRAS GIRATÓRIAS nascem exatamente nesses pontos (cada arco tem sua barra ali).
	-- Mude/adicione frações e os dois acompanham juntos, sempre espaçados (nunca sobrepõem).
	Checkpoints = { 0.25, 0.5, 0.75 },

	-- 🟢 Bônus: PLACA flutuante semitransparente com símbolo de velocidade (o player atravessa).
	-- +50% de velocidade por 3s. SÓ pro PRIMEIRO que atravessar (consome/some).
	SpeedBoost = {
		Count = 16,
		Multiplier = 1.5,
		Duration = 3,
		Color = Color3.fromRGB(60, 230, 110),
		Size = Vector3.new(16, 9, 0.6), -- largura(X) x altura(Y) x espessura(Z, fina)
		FloatY = 6, -- centro da placa acima do chão (flutua na altura do player)
		Symbol = "⚡", -- símbolo de velocidade mostrado na placa
	},
	-- 🔵 Jump pad: chão azul. Empurra pra frente e pra cima (reutilizável).
	JumpPad = {
		Count = 14,
		ForwardForce = 330, -- forte pra frente
		UpForce = 70, -- só um pulinho pra sair do chão (reduzido de 240)
		PlayerCooldown = 0.6, -- anti-spam por jogador
		Color = Color3.fromRGB(70, 150, 255), -- azul = te move
		Size = Vector3.new(20, 1, 20), -- X = diâmetro do disco | Y = espessura
		Symbol = "🚀", -- "te lança". Não precisa de seta: o empurrão é sempre pra frente.
	},
	-- 🔴 Lentidão: chão vermelho. -50% de velocidade por 3s (reutilizável, com cooldown).
	Slow = {
		Count = 16,
		Multiplier = 0.5,
		Duration = 3,
		PlayerCooldown = 1.5,
		Color = Color3.fromRGB(235, 70, 70), -- vermelho = te atrapalha
		Size = Vector3.new(20, 1, 20), -- X = diâmetro do disco | Y = espessura
		Symbol = "🐌", -- lesma = "isso te deixa lento"
	},
	-- 🟫 Muro baixo: o player tem que PULAR por cima (atravessa toda a largura).
	Hurdle = {
		Count = 12,
		Height = 5, -- baixo o suficiente pra pular (JumpHeight da corrida = 7.2)
		Thickness = 3,
		Color = Color3.fromRGB(120, 90, 60),
	},
	-- ⭐ Mega boost (raro): placa dourada com +100% por 4s (mais forte que a verde).
	-- Usa a MESMA placa flutuante do SpeedBoost (1º que pega consome).
	MegaBoost = {
		Count = 4,
		Multiplier = 2.0,
		Duration = 4,
		Color = Color3.fromRGB(255, 205, 50),
		Size = Vector3.new(16, 9, 0.6),
		FloatY = 6,
		Symbol = "⭐",
	},
	-- 🟠 Rolo móvel: bloco que desliza de um lado pro outro (eixo X) atravessando a pista.
	-- Encostou = empurrão pra trás (-Z) + lentidão curta. Exige timing pra desviar.
	Roller = {
		Count = 8,
		Size = Vector3.new(55, 13, 90), -- largo (X) e comprido (Z), baixinho (Y)
		SlideMargin = 8, -- folga das paredes no trajeto lateral
		SlideTime = 5.33, -- 30% da velocidade anterior (era 1.6 → tempo ÷ 0.3 = mais lento)
		-- Encostou = empurrão pra TRÁS com a MESMA força/params do jump pad
		-- (RaceConfig.Elements.JumpPad, com o sentido invertido) + lentidão curta.
		SlowMultiplier = 0.6, -- -40% por um tiquinho
		SlowDuration = 1.2,
		PlayerCooldown = 1.0,
		Color = Color3.fromRGB(255, 120, 40),
	},
	-- 💨 Ventilador lateral: pad no chão que SOPRA o player pro lado (em direção à parede).
	-- Direção sorteada por ventilador. Usa o empurrão no cliente (RacePush), como o jump pad.
	SideFan = {
		Count = 10,
		-- 20×20 (era 10): quadrado igual aos outros pads, pra a moldura + seta ficarem legíveis.
		-- Consequência ACEITA: a área de efeito fica ~5× maior (disco Ø10 → quadrado 20×20),
		-- então a pista fica mais caótica/imprevisível — decisão de balanceamento, não só visual.
		Size = Vector3.new(20, 1, 20),
		SideForce = 216, -- empurrão lateral (studs/s) — +80% (era 120)
		UpForce = 8, -- só pra "destacar" do chão e o empurrão pegar
		PlayerCooldown = 0.8,
		Color = Color3.fromRGB(150, 220, 255), -- azul (claro) = te move, irmão do jump pad
		Symbol = "💨", -- pra QUE LADO sopra, quem mostra é a partícula de vento
	},
	-- 🛡️ Escudo: PLACA flutuante (igual ao boost) que dá IMUNIDADE às armadilhas por N segundos.
	-- SÓ pro PRIMEIRO que atravessar (consome/some). Enquanto ativo, lentidão/rolo/ventilador/
	-- barra giratória não afetam o player (mostra um ForceField em volta dele).
	Shield = {
		Count = 6,
		Duration = 6,
		Color = Color3.fromRGB(80, 200, 255),
		Size = Vector3.new(16, 9, 0.6), -- mesma placa flutuante do boost
		FloatY = 6,
		Symbol = "🛡️",
	},
	-- 🎡 Barra giratória: braço que gira no plano horizontal (eixo Y) varrendo a pista.
	-- Encostou = empurrão pra TRÁS (reusa a força do jump pad, como o rolo) + lentidão curta.
	-- Exige timing: passe quando o braço estiver alinhado com a direção da corrida.
	Spinner = {
		-- Sem Count: nasce UMA barra em cada checkpoint (ver Elements.Checkpoints acima) —
		-- hoje 3 (25/50/75%), cada uma bem no arco. Quer mais/menos? Mexa na lista Checkpoints.
		ArmLength = 340, -- comprimento total do braço (varre a largura)
		Thickness = 10, -- espessura do braço
		Height = 14,
		RotationTime = 3.0, -- tempo de uma volta completa (menor = gira mais rápido)
		SlowMultiplier = 0.6, -- -40% por um tiquinho ao encostar
		SlowDuration = 1.2,
		PlayerCooldown = 1.0,
		Color = Color3.fromRGB(200, 90, 255),
	},
}

-- PlaceId do JOGO PRINCIPAL / lobby (pra onde os players voltam no fim da corrida).
-- "Save a Brainrot (BETA)" = 90667727140026 (mesmo experience: 9974657761).
RaceConfig.MainPlaceId = 90667727140026

-- Prêmio por colocação (índice = posição), em RACE COINS (moeda do evento).
-- A entrega é cross-place: a corrida grava um "prêmio pendente" num DataStore e o LOBBY
-- entrega quando o player volta (ver PrizeService + o RaceRewardGrantService no lobby).
-- IMPORTANTE: TODO finalista (inclusive o pódio) ganha +FinishRaceCoins por completar.
-- Estes valores são o EXTRA do pódio (somam com o FinishRaceCoins de participação).
-- Total final: 1º = 85+15 = 100 | 2º = 45+15 = 60 | 3º = 20+15 = 35 | fora do pódio = 15.
-- (rebalanceado 2026-07-05: participação mais generosa pro F2P, razão 1º/participação ~6,7×)
RaceConfig.PrizeByPlace = {
	{ RaceCoins = 85 }, -- 1º → 100 total
	{ RaceCoins = 45 }, -- 2º → 60 total
	{ RaceCoins = 20 }, -- 3º → 35 total
}

-- Race Coins que TODO jogador que cruza a linha de chegada ganha (soma com o do pódio).
-- Ex.: 1º = 85 + 15 = 100 | fora do pódio = 15.
RaceConfig.FinishRaceCoins = 15

-- 🏎️ Dashboard do HUD (velocímetro): quantos segmentos o arco de combo mostra no máximo.
-- Empilhou mais boosts que isso? O arco fica cheio e pulsa "MAX!" em vez de estourar a escala.
RaceConfig.ComboGauge = {
	MaxSegments = 8,
}

-- 🔊 Sons do evento. Cole os SoundIds da sua Toolbox/Library (só o número ou rbxassetid://...).
-- 0 = sem som (o sistema toca silêncio). O resto do "juice" (efeitos visuais) funciona sem isso.
RaceConfig.Sounds = {
	CountdownBeep = 6238869231, -- bip a cada número da contagem
	Go = 140419294351439, -- som do "JÁ!" (largada)
	Boost = 83211426606907, -- ao pegar a placa de velocidade
	JumpPad = 101314601670996, -- ao usar o jump pad
	Shield = 0, -- ao pegar o escudo (0 = sem som; cole um SoundId se quiser)
	Finish = 1844442542, -- ao cruzar a chegada
	Volume = 0.6,
}

return RaceConfig
