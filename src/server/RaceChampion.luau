--[[
	RaceChampion (lado da CORRIDA)
	------------------------------
	Grava quem VENCEU a última corrida (1º lugar) num DataStore COMPARTILHADO
	(mesmo experience do lobby). O LOBBY lê isso e dá um visual de campeão (coroa/rastro
	dourado) pro jogador até a próxima corrida sobrescrever.

	DataStore: "RaceChampion_v1", chave "current" = { userId, name, at }.
]]

local DataStoreService = game:GetService("DataStoreService")

local RaceChampion = {}

local STORE_NAME = "RaceChampion_v1"
local KEY = "current"
local store: DataStore? = nil

function RaceChampion.Setup()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	store = ok and result or nil
end

-- Define o campeão atual (sobrescreve o anterior).
function RaceChampion.SetChampion(userId: number, name: string)
	if not store then
		return
	end
	pcall(function()
		(store :: DataStore):SetAsync(KEY, { userId = userId, name = name, at = os.time() })
	end)
end

return RaceChampion
