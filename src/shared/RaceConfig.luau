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

-- Velocidade de caminhada durante a corrida (padrão do Roblox é 16).
-- Mais alto = corrida mais rápida e divertida (e testável num corredor longo).
RaceConfig.RaceWalkSpeed = 60

-- Tempo máximo da corrida (se alguém não chegar, encerra mesmo assim).
RaceConfig.RaceTimeLimitSeconds = 180

-- Quanto tempo mostra o resultado antes de teleportar de volta.
RaceConfig.ResultsSeconds = 8

-- >>> PREENCHA com o PlaceId do seu JOGO PRINCIPAL (pra onde os players voltam).
-- Enquanto for 0 (ou rodando no Studio), o teleporte de volta é pulado. <<<
RaceConfig.MainPlaceId = 0

-- Prêmio em moedas por colocação (índice = posição). Fora da lista, sem prêmio.
RaceConfig.PrizeByPlace = { 100, 50, 25 }

return RaceConfig
