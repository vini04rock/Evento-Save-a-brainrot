--[[
	RacerState
	----------
	Controla a velocidade de cada corredor durante a corrida:
	  - Base   = a velocidade que o player tem no jogo principal (via TeleportData).
	  - Boosts = power-ups de velocidade ACUMULÁVEIS, por TIPO (ver regras abaixo).
	  - Slow   = lentidão (rolo/armadilha), canal próprio multiplicativo (último vence).
	  - Frozen = congelado (largada/contagem ou já chegou) → WalkSpeed 0.

	Regras dos boosts (AddBoost):
	  - Cada TIPO de boost tem 1 timer (que reseta a cada coleta do mesmo tipo)
	    e um contador de stacks. Mais coletas do MESMO tipo = mais velocidade,
	    e o tempo reseta.
	  - Tipos DIFERENTES somam a velocidade, mas têm timers independentes
	    (o tempo não acumula). Quando o timer de um tipo acaba, todos os stacks
	    daquele tipo são removidos de uma vez.

	WalkSpeed efetiva = Frozen and 0 or (base * slow * (1 + Σ (mult_tipo-1) * stacks_tipo)).

	Usado pelo RaceManager (freeze/base) e pelo TrackElements (boost/lentidão).
	Não cria conexões; só mexe no Humanoid quando chamado.
]]

local RacerState = {}

type Boost = { mult: number, stacks: number, token: number }
type State = {
	base: number,
	frozen: boolean,
	slowMult: number,
	slowToken: number,
	boosts: { [any]: Boost },
}

local state: { [Player]: State } = {}

local function getHumanoid(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function refresh(player: Player)
	local s = state[player]
	local hum = getHumanoid(player)
	if not s or not hum then
		return
	end
	if s.frozen then
		hum.WalkSpeed = 0
		return
	end
	-- Soma o bônus de todos os tipos de boost ativos (cada stack soma mult-1).
	local boostBonus = 0
	for _, b in s.boosts do
		boostBonus += (b.mult - 1) * b.stacks
	end
	hum.WalkSpeed = math.max(0, s.base * s.slowMult * (1 + boostBonus))
end

-- Registra o corredor com a velocidade-base dele (a do jogo principal).
function RacerState.Init(player: Player, baseSpeed: number)
	state[player] = {
		base = math.max(1, baseSpeed),
		frozen = false,
		slowMult = 1,
		slowToken = 0,
		boosts = {},
	}
end

-- Congela/descongela (largada, contagem, ou quem já chegou).
function RacerState.SetFrozen(player: Player, frozen: boolean)
	local s = state[player]
	if not s then
		return
	end
	s.frozen = frozen
	local hum = getHumanoid(player)
	if hum then
		hum.JumpHeight = frozen and 0 or 7.2
		hum.JumpPower = frozen and 0 or 50
	end
	refresh(player)
end

-- Coleta de um boost de velocidade ACUMULÁVEL. `key` identifica o TIPO (use a
-- tabela de config do boost, ex.: RaceConfig.Elements.SpeedBoost). Tipos iguais
-- empilham e resetam o timer; tipos diferentes somam mas têm timers próprios.
function RacerState.AddBoost(player: Player, key: any, mult: number, duration: number)
	local s = state[player]
	if not s then
		return
	end
	local b = s.boosts[key]
	if not b then
		b = { mult = mult, stacks = 0, token = 0 }
		s.boosts[key] = b
	end
	b.mult = mult
	b.stacks += 1
	b.token += 1
	local token = b.token
	refresh(player)

	-- Reseta o timer deste tipo: só o último token (a última coleta) expira o tipo.
	task.delay(duration, function()
		local cur = state[player]
		local curBoost = cur and cur.boosts[key]
		if curBoost and curBoost.token == token then
			cur.boosts[key] = nil -- acabou o tempo: remove TODOS os stacks deste tipo
			refresh(player)
		end
	end)
end

-- Aplica uma LENTIDÃO temporária (rolo/armadilha). Canal multiplicativo próprio,
-- separado dos boosts; o último aplicado vence, com seu próprio prazo via token.
function RacerState.ApplyMultiplier(player: Player, mult: number, duration: number)
	local s = state[player]
	if not s then
		return
	end
	s.slowMult = mult
	refresh(player)

	s.slowToken += 1
	local token = s.slowToken
	task.delay(duration, function()
		local cur = state[player]
		if cur and cur.slowToken == token then
			cur.slowMult = 1
			refresh(player)
		end
	end)
end

-- True se o player está registrado como corredor (TrackElements ignora quem não corre).
function RacerState.IsRacer(player: Player): boolean
	return state[player] ~= nil
end

function RacerState.Clear(player: Player)
	state[player] = nil
end

function RacerState.ClearAll()
	table.clear(state)
end

return RacerState
