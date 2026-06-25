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

-- Quanto tempo o finalista vê o resultado dele antes de ser teleportado de volta (individual).
RaceConfig.FinishReturnDelaySeconds = 4

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
		Symbol = ">>", -- símbolo de velocidade mostrado na placa
	},
	-- 🔵 Jump pad: chão azul. Empurra pra frente e pra cima (reutilizável).
	JumpPad = {
		Count = 14,
		ForwardForce = 330, -- +200% (era 110)
		UpForce = 240, -- +200% (era 80)
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

return RaceConfig
