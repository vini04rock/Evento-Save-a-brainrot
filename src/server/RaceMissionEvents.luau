--[[
	RaceMissionEvents (lado da CORRIDA)
	-----------------------------------
	Registra eventos de corrida pra contar MISSÕES no lobby, via DataStore COMPARTILHADO
	(mesmo experience do lobby), como "pendente" — o lobby lê + credita + limpa quando o
	player volta (RaceRewardGrantService).

	DataStore: "PendingRaceMissions_v1", chave = "u_<userId>".
	Valor: { Join = N, Finish = N, Win = N }  (acumula até o lobby creditar).

	  - Join   → entrou no mapa da corrida (ganhe ou perca)  → "Participe de N corridas"
	  - Finish → cruzou a linha de chegada                   → "Complete N corridas"
	  - Win    → terminou em 1º lugar                         → "Vença N corridas"

	Server-authoritative: só o servidor da corrida escreve, o lobby só lê/limpa.
	Não passa nada pelo cliente → não dá pra burlar.
]]

local DataStoreService = game:GetService("DataStoreService")

local RaceMissionEvents = {}

local STORE_NAME = "PendingRaceMissions_v1"
local store: DataStore? = nil

function RaceMissionEvents.Setup()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Evento] DataStore de missões indisponível (missões de corrida não serão contadas):", result)
		store = nil
	end
end

-- Incrementa um contador de evento (acumula com o que já houver pendente).
local function bump(userId: number, field: string)
	if not store then
		return
	end
	local key = "u_" .. tostring(userId)
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(old)
			local data = (typeof(old) == "table") and old or { Join = 0, Finish = 0, Win = 0 }
			data.Join = tonumber(data.Join) or 0
			data.Finish = tonumber(data.Finish) or 0
			data.Win = tonumber(data.Win) or 0
			data[field] = (tonumber(data[field]) or 0) + 1
			return data
		end)
	end)
	if not ok then
		warn("[Evento] Falha ao gravar evento de missão (" .. field .. ") de userId " .. tostring(userId) .. ":", err)
	end
end

-- Entrou na corrida (registrado pra TODO racer no início).
function RaceMissionEvents.RecordJoin(player: Player)
	bump(player.UserId, "Join")
end

-- Cruzou a linha de chegada.
function RaceMissionEvents.RecordFinish(player: Player)
	bump(player.UserId, "Finish")
end

-- Terminou em 1º lugar.
function RaceMissionEvents.RecordWin(player: Player)
	bump(player.UserId, "Win")
end

return RaceMissionEvents
