--!strict
--[[
	Servidor (entry point)
	----------------------
	Ponto de entrada do servidor. Por enquanto, só monta o chão do mapa.
	As mecânicas (corrida, linha de chegada, premiação) entram aqui depois.
]]

local MapBuilder = require(script.MapBuilder)

MapBuilder.Build()
print("[Evento] Chão construído.")
