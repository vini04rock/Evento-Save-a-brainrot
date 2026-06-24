--[[
	RacerState
	----------
	Controla a velocidade de cada corredor durante a corrida:
	  - Base   = a velocidade que o player tem no jogo principal (via TeleportData).
	  - Mult   = multiplicador temporário (boost verde = 1.5, lentidão vermelha = 0.5).
	  - Frozen = congelado (largada/contagem ou já chegou) → WalkSpeed 0.

	WalkSpeed efetiva = Frozen and 0 or (Base * Mult).

	Usado pelo RaceManager (freeze/base) e pelo TrackElements (boost/lentidão).
	Não cria conexões; só mexe no Humanoid quando chamado.
]]

local RacerState = {}

-- [player] = { base, mult, frozen, effectToken }
local state: { [Player]: { base: number, mult: number, frozen: boolean, effectToken: number } } = {}

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
	hum.WalkSpeed = s.frozen and 0 or (s.base * s.mult)
end

-- Registra o corredor com a velocidade-base dele (a do jogo principal).
function RacerState.Init(player: Player, baseSpeed: number)
	state[player] = {
		base = math.max(1, baseSpeed),
		mult = 1,
		frozen = false,
		effectToken = 0,
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

-- Aplica um multiplicador temporário (boost/lentidão). O último aplicado vence
-- (não empilha); cada um tem seu próprio prazo via token.
function RacerState.ApplyMultiplier(player: Player, mult: number, duration: number)
	local s = state[player]
	if not s then
		return
	end
	s.mult = mult
	refresh(player)

	s.effectToken += 1
	local token = s.effectToken
	task.delay(duration, function()
		local cur = state[player]
		if cur and cur.effectToken == token then
			cur.mult = 1
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
