--[[
	PrizeService (lado da CORRIDA)
	------------------------------
	Grava o prêmio do jogador num DataStore COMPARTILHADO (mesmo experience do lobby),
	como "prêmio pendente". O LOBBY entrega quando o player volta (RaceRewardGrantService).

	Por que não entregar aqui: os dados do player (Braincoins, pacotes) vivem no sistema
	de progresso do LOBBY. Entregar a partir daqui (servidor da corrida) arriscaria conflito
	de save. O padrão seguro é: corrida GRAVA pendente → lobby LÊ + concede + limpa.

	DataStore: "PendingRaceRewards_v1", chave = "u_<userId>".
	Valor: { RaceCoins = N, Place = N, Time = N, ... }  (RaceCoins acumula entre corridas
	não recebidas). O lobby credita via PlayerProgressManager.AddRaceCoins.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)

local PrizeService = {}

local STORE_NAME = "PendingRaceRewards_v1"
local store: DataStore? = nil

function PrizeService.Setup()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Evento] DataStore indisponível (prêmios não serão gravados):", result)
		store = nil
	end
end

-- Resolve os RACE COINS de uma colocação: bônus do pódio (se houver) + o de finalista.
-- Todo mundo que CRUZA A CHEGADA ganha FinishRaceCoins; o pódio soma o extra por cima.
-- Ex.: 1º = 55 + 5 = 60 | fora do pódio = 5.
function PrizeService.ResolveReward(place: number): { RaceCoins: number }
	local finishCoins = tonumber(RaceConfig.FinishRaceCoins) or 0
	local podium = RaceConfig.PrizeByPlace[place]
	local podiumCoins = podium and (tonumber(podium.RaceCoins) or 0) or 0
	return { RaceCoins = podiumCoins + finishCoins }
end

-- Grava o prêmio da colocação como pendente (acumula com o que já houver).
-- raceTime/place/recorde também ficam salvos pra a janela de resultados no lobby (último valor vence).
function PrizeService.AwardPlace(player: Player, place: number, raceTime: number?, newRecord: boolean?, bestTime: number?)
	if not store then
		return
	end
	local reward = PrizeService.ResolveReward(place)
	if reward.RaceCoins <= 0 then
		return
	end

	local key = "u_" .. tostring(player.UserId)
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(old)
			local data = (typeof(old) == "table") and old or {}
			data.RaceCoins = (tonumber(data.RaceCoins) or 0) + reward.RaceCoins
			data.Place = place
			data.Time = tonumber(raceTime) or data.Time or 0
			data.NewRecord = newRecord == true
			data.BestTime = tonumber(bestTime) or data.BestTime or 0
			return data
		end)
	end)
	if not ok then
		warn("[Evento] Falha ao gravar prêmio pendente de " .. tostring(player.Name) .. ":", err)
	end
end

return PrizeService
