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
RaceConfig.WaitForPlayersSeconds = 5

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
RaceConfig.Elements = {
	RandomLayout = true,
	SafeStartStuds = 300, -- não coloca nada nos primeiros N studs (depois da largada)
	SafeFinishStuds = 300, -- nem nos últimos N studs (antes da chegada)
	LaneMargin = 70, -- folga das paredes ao posicionar no eixo X

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
		Color = Color3.fromRGB(70, 150, 255),
		Size = Vector3.new(20, 1, 20),
	},
	-- 🔴 Lentidão: chão vermelho. -50% de velocidade por 3s (reutilizável, com cooldown).
	Slow = {
		Count = 16,
		Multiplier = 0.5,
		Duration = 3,
		PlayerCooldown = 1.5,
		Color = Color3.fromRGB(235, 70, 70),
		Size = Vector3.new(20, 1, 20),
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
		Size = Vector3.new(10, 1, 10),
		SideForce = 216, -- empurrão lateral (studs/s) — +80% (era 120)
		UpForce = 8, -- só pra "destacar" do chão e o empurrão pegar
		PlayerCooldown = 0.8,
		Color = Color3.fromRGB(150, 220, 255),
	},
}

-- PlaceId do JOGO PRINCIPAL / lobby (pra onde os players voltam no fim da corrida).
-- "Save a Brainrot (BETA)" = 90667727140026 (mesmo experience: 9974657761).
RaceConfig.MainPlaceId = 90667727140026

-- Prêmio por colocação (índice = posição). Pack = id do pacote no jogo principal.
-- A entrega é cross-place: a corrida grava um "prêmio pendente" num DataStore e o LOBBY
-- entrega quando o player volta (ver PrizeService + o RaceRewardGrantService no lobby).
RaceConfig.PrizeByPlace = {
	{ Pack = "BrainrotPack2", Braincoins = 25 }, -- 1º
	{ Pack = "BrainrotPack1", Braincoins = 12 }, -- 2º
	{ Pack = "BrainrotPack1", Braincoins = 6 }, -- 3º
}

-- Consolação pra quem TERMINA fora do top 3 (reduz frustração infantil): Yen.
RaceConfig.FinishConsolationYen = 15000

-- 🔊 Sons do evento. Cole os SoundIds da sua Toolbox/Library (só o número ou rbxassetid://...).
-- 0 = sem som (o sistema toca silêncio). O resto do "juice" (efeitos visuais) funciona sem isso.
RaceConfig.Sounds = {
	CountdownBeep = 6238869231, -- bip a cada número da contagem
	Go = 140419294351439, -- som do "JÁ!" (largada)
	Boost = 83211426606907, -- ao pegar a placa de velocidade
	JumpPad = 101314601670996, -- ao usar o jump pad
	Finish = 1844442542, -- ao cruzar a chegada
	Volume = 0.6,
}

return RaceConfig
