--[[
	RaceRecords (lado da CORRIDA)
	-----------------------------
	Registra os tempos de corrida em DataStores COMPARTILHADOS (mesmo experience do lobby):
	  - RaceBestTimes_v1  (chave "u_<userId>" = melhor tempo em ms do jogador)  → recorde pessoal
	  - RaceGlobalTop_v1  (chave "top" = lista ordenada dos 10 melhores)        → ranking global

	Record() devolve se foi NOVO RECORDE pessoal e o melhor tempo atual (em segundos),
	pra a janela de resultados do lobby mostrar "🏆 Novo recorde!".
]]

local DataStoreService = game:GetService("DataStoreService")

local RaceRecords = {}

local BEST_STORE_NAME = "RaceBestTimes_v1"
local GLOBAL_STORE_NAME = "RaceGlobalTop_v1"
local GLOBAL_KEY = "top"
local TOP_SIZE = 10

local bestStore = nil
local globalStore = nil

function RaceRecords.Setup()
	local ok1, s1 = pcall(function()
		return DataStoreService:GetDataStore(BEST_STORE_NAME)
	end)
	bestStore = ok1 and s1 or nil
	local ok2, s2 = pcall(function()
		return DataStoreService:GetDataStore(GLOBAL_STORE_NAME)
	end)
	globalStore = ok2 and s2 or nil
end

-- Lê o top-10 global (lista { {userId, name, timeMs}, ... } ordenada do mais rápido).
function RaceRecords.GetGlobalTop()
	if not globalStore then
		return {}
	end
	local data
	local ok = pcall(function()
		data = globalStore:GetAsync(GLOBAL_KEY)
	end)
	return (ok and typeof(data) == "table") and data or {}
end

-- Registra o tempo do jogador. Retorna (isNewRecord: boolean, bestTimeSeconds: number).
function RaceRecords.Record(userId: number, name: string, timeSeconds: number): (boolean, number)
	local timeMs = math.floor((tonumber(timeSeconds) or 0) * 1000)
	if timeMs <= 0 then
		return false, 0
	end

	local isNewRecord = false
	local bestMs = timeMs

	-- Recorde pessoal.
	if bestStore then
		pcall(function()
			bestStore:UpdateAsync("u_" .. tostring(userId), function(old)
				local oldMs = tonumber(old)
				if oldMs == nil or timeMs < oldMs then
					isNewRecord = true
					bestMs = timeMs
					return timeMs
				end
				bestMs = oldMs
				return oldMs
			end)
		end)
	end

	-- Ranking global (mantém o melhor por jogador, ordenado, top 10).
	if globalStore then
		pcall(function()
			globalStore:UpdateAsync(GLOBAL_KEY, function(old)
				local list = (typeof(old) == "table") and old or {}
				for i = #list, 1, -1 do
					if typeof(list[i]) ~= "table" or list[i].userId == userId then
						table.remove(list, i)
					end
				end
				table.insert(list, { userId = userId, name = name, timeMs = bestMs })
				table.sort(list, function(a, b)
					return (tonumber(a.timeMs) or math.huge) < (tonumber(b.timeMs) or math.huge)
				end)
				while #list > TOP_SIZE do
					table.remove(list)
				end
				return list
			end)
		end)
	end

	return isNewRecord, bestMs / 1000
end

return RaceRecords
