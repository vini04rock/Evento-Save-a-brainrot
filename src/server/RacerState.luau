--[[
	RacerState
	----------
	Controla a velocidade de cada corredor durante a corrida:
	  - Base   = a velocidade que o player tem no jogo principal (via TeleportData).
	  - Boosts = power-ups de velocidade ACUMULÁVEIS, por TIPO (ver regras abaixo).
	  - Slow   = lentidão (rolo/armadilha), canal próprio multiplicativo (último vence).
	  - Frozen = congelado (largada/contagem ou já chegou) → WalkSpeed 0.

	Regras dos boosts (AddBoost):
	  - Cada TIPO acumula stacks e tem seu próprio multiplicador (verde +50%, mega +100%).
	    Mais coletas de qualquer tipo = mais velocidade (a soma dos tipos).
	  - Timer UNIFICADO: existe UM único cronômetro pros boosts. Qualquer coleta
	    (de qualquer tipo) reseta esse cronômetro pra a duração do que foi pego.
	    Quando ele acaba, TODOS os boosts saem juntos de uma vez.
	    (Assim o multiplicador nunca cai no meio da contagem — evita parecer bug pro
	    jogador. Trade-off: pegar qualquer buff estende o tempo de todos.)

	WalkSpeed efetiva = Frozen and 0 or (base * slow * (1 + Σ (mult_tipo-1) * stacks_tipo)).

	Usado pelo RaceManager (freeze/base) e pelo TrackElements (boost/lentidão).
	Não cria conexões; só mexe no Humanoid quando chamado.
]]

local RacerState = {}

type Boost = { mult: number, stacks: number }
type State = {
	base: number,
	frozen: boolean,
	slowMult: number,
	slowToken: number,
	boosts: { [any]: Boost },
	boostToken: number,
	shieldUntil: number, -- os.clock() até quando o escudo (imunidade a armadilhas) vale
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
		boostToken = 0,
		shieldUntil = 0,
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

-- Soma os stacks de TODOS os tipos de boost ativos (pro combo mostrado no HUD).
function RacerState.GetBoostStacks(player: Player): number
	local s = state[player]
	if not s then
		return 0
	end
	local total = 0
	for _, b in s.boosts do
		total += b.stacks
	end
	return total
end

-- Bônus TOTAL de velocidade dos boosts ativos (fração: 1.5 = +150%), pro HUD mostrar
-- o multiplicador. Mesma conta do `refresh` (Σ (mult-1) * stacks por tipo).
function RacerState.GetBoostBonus(player: Player): number
	local s = state[player]
	if not s then
		return 0
	end
	local bonus = 0
	for _, b in s.boosts do
		bonus += (b.mult - 1) * b.stacks
	end
	return bonus
end

-- Coleta de um boost de velocidade ACUMULÁVEL. `key` identifica o TIPO (use a
-- tabela de config do boost, ex.: RaceConfig.Elements.SpeedBoost). Cada tipo empilha
-- com seu multiplicador; a velocidade é a SOMA dos tipos.
-- Timer UNIFICADO: qualquer coleta reseta o único cronômetro pra `duration`; quando ele
-- acaba, TODOS os boosts saem juntos. `onExpire`, se informado, é chamado (com 0 stacks,
-- porque limpou tudo) nesse momento — o módulo não sabe de rede; quem chamou decide o que
-- fazer (ex.: TrackElements avisa o cliente pro combo do HUD).
function RacerState.AddBoost(player: Player, key: any, mult: number, duration: number, onExpire: ((number) -> ())?)
	local s = state[player]
	if not s then
		return
	end
	local b = s.boosts[key]
	if not b then
		b = { mult = mult, stacks = 0 }
		s.boosts[key] = b
	end
	b.mult = mult
	b.stacks += 1
	refresh(player)

	-- Reseta o cronômetro ÚNICO: só o último token (a última coleta) dispara a expiração.
	s.boostToken += 1
	local token = s.boostToken
	task.delay(duration, function()
		local cur = state[player]
		if cur and cur.boostToken == token then
			table.clear(cur.boosts) -- acabou o tempo: TODOS os boosts saem juntos
			refresh(player)
			if onExpire then
				onExpire(0)
			end
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

-- 🛡️ Escudo: dá imunidade às armadilhas até os próximos `duration` segundos.
-- Pegar outro escudo estende (o mais recente vence, sempre pra frente no tempo).
function RacerState.SetShield(player: Player, duration: number)
	local s = state[player]
	if not s then
		return
	end
	s.shieldUntil = math.max(s.shieldUntil, os.clock() + duration)
end

-- True se o player está com escudo ativo (as armadilhas checam isso e pulam o efeito).
function RacerState.IsShielded(player: Player): boolean
	local s = state[player]
	return s ~= nil and s.shieldUntil > os.clock()
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
