--[[
	RaceManager
	-----------
	Máquina de estados da corrida (autoritativa, no servidor):

	  Esperando -> Contagem -> Correndo -> (cada finalista volta) -> tempo esgota -> resto volta

	Modelo SESSÃO ÚNICA (servidor reservado): roda UMA corrida.
	- Velocidade de cada corredor = a do jogo principal (via TeleportData) — ver RacerState.
	- Power-ups e armadilhas aleatórios pela pista — ver TrackElements.
	- Top 3 a chegar ganham prêmio (PrizeService).
	- Quem chega é teleportado de volta logo após (individual); no fim do tempo (5 min),
	  quem sobrou é teleportado em grupo.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.EventConfig)
local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PrizeService = require(script.Parent.PrizeService)
local RacerState = require(script.Parent.RacerState)
local TrackElements = require(script.Parent.TrackElements)

local RaceManager = {}

-- Lê a velocidade do player a partir do TeleportData do teleporte (mapa userId -> WalkSpeed).
local function getPlayerRaceSpeed(player: Player): number
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if ok and typeof(joinData) == "table" then
		local teleportData = (joinData :: any).TeleportData
		if typeof(teleportData) == "table" and typeof(teleportData.Speeds) == "table" then
			local speed = tonumber(teleportData.Speeds[tostring(player.UserId)])
			if speed and speed > 0 then
				return speed
			end
		end
	end
	return RaceConfig.RaceWalkSpeed -- fallback (Studio / entrou sem teleporte)
end

-- Z a partir do qual se considera "chegou" (entrada da faixa xadrez).
local function getFinishZ(): number
	return Config.Origin.Z + Config.GetTotalLength() - Config.FinishLine.Length
end

local function getRoot(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

-- Coloca cada jogador num spawn da largada (espalha nos pads existentes).
local function moveToStart(players: { Player })
	local map = workspace:FindFirstChild(Config.MapName)
	local spawnsFolder = map and map:FindFirstChild("Spawns")
	local pads = {}
	if spawnsFolder then
		for _, child in spawnsFolder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(pads, child)
			end
		end
	end
	if #pads == 0 then
		return
	end
	for i, player in players do
		local root = getRoot(player)
		if root then
			local pad = pads[((i - 1) % #pads) + 1]
			root.CFrame = pad.CFrame + Vector3.new(0, 4, 0)
		end
	end
end

-- Espera atingir o mínimo de jogadores + um tempinho pro pessoal chegar.
local function waitForPlayers()
	while #Players:GetPlayers() < RaceConfig.MinPlayers do
		Remotes.RaceState:FireAllClients({ phase = "waiting" })
		task.wait(1)
	end
	for n = RaceConfig.WaitForPlayersSeconds, 1, -1 do
		Remotes.RaceState:FireAllClients({ phase = "waiting", n = n })
		task.wait(1)
	end
end

local function runCountdown(racers: { Player })
	for _, player in racers do
		RacerState.SetFrozen(player, true)
	end
	for n = RaceConfig.CountdownSeconds, 1, -1 do
		Remotes.RaceState:FireAllClients({ phase = "countdown", n = n })
		task.wait(1)
	end
	Remotes.RaceState:FireAllClients({ phase = "go" })
	for _, player in racers do
		RacerState.SetFrozen(player, false)
	end
end

-- Teleporta UM player de volta pro lobby (no Studio / sem MainPlaceId, pula).
local function returnPlayer(player: Player)
	if not player or not player.Parent then
		return
	end
	if RaceConfig.MainPlaceId <= 0 or RunService:IsStudio() then
		return
	end
	pcall(function()
		TeleportService:TeleportAsync(RaceConfig.MainPlaceId, { player })
	end)
end

-- Teleporta um grupo de volta (quem sobrou no fim do tempo).
local function returnGroup(players: { Player })
	if #players == 0 then
		return
	end
	if RaceConfig.MainPlaceId <= 0 or RunService:IsStudio() then
		warn("[Evento] MainPlaceId não configurado ou rodando no Studio — teleporte de volta pulado.")
		return
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(RaceConfig.MainPlaceId, players)
	end)
	if not ok then
		warn("[Evento] Falha ao teleportar de volta:", err)
	end
end

-- Corrida: detecta chegada, premia top 3 e teleporta CADA finalista de volta logo após.
-- Quem não terminar até o tempo limite (5 min) volta em grupo.
local function runRace(racers: { Player })
	local finishZ = getFinishZ()
	local racing: { [Player]: boolean } = {}
	for _, player in racers do
		racing[player] = true
	end

	local placeCount = 0
	local finished: { [Player]: boolean } = {}
	local finishOrder = {} -- { { userId, name, place }, ... } — pro placar ao vivo
	local startTime = os.clock()

	local connection
	connection = RunService.Heartbeat:Connect(function()
		for player in racing do
			if finished[player] or not player.Parent then
				continue
			end
			local root = getRoot(player)
			if root and root.Position.Z >= finishZ then
				finished[player] = true
				placeCount += 1
				local place = placeCount
				local raceTime = os.clock() - startTime
				table.insert(finishOrder, { userId = player.UserId, name = player.Name, place = place })

				-- Grava o prêmio pendente (top 3 = pacote+braincoins; demais = consolação em Yen).
				-- O lobby mostra a janela e entrega quando o player fecha (ver RaceRewardGrantService).
				PrizeService.AwardPlace(player, place, raceTime)
				local reward = PrizeService.ResolveReward(place)

				RacerState.SetFrozen(player, true) -- congela quem já chegou
				Remotes.RaceState:FireClient(player, {
					phase = "finished",
					place = place,
					time = raceTime,
					reward = reward, -- { Pack, Braincoins } — pro cliente mostrar
				})

				-- Teleporta esse finalista de volta depois de um tempinho (vê o resultado dele).
				task.delay(RaceConfig.FinishReturnDelaySeconds, function()
					returnPlayer(player)
				end)
			end
		end
	end)

	-- Placar ao vivo (throttled): chegados na ordem de chegada + quem corre por distância.
	local startZ = Config.Origin.Z
	local rankActive = true
	task.spawn(function()
		while rankActive do
			local ranking = {}
			for _, e in ipairs(finishOrder) do
				table.insert(ranking, { userId = e.userId, name = e.name, finished = true, place = e.place })
			end
			local running = {}
			for _, player in ipairs(racers) do
				if player.Parent and not finished[player] then
					local root = getRoot(player)
					table.insert(running, {
						userId = player.UserId,
						name = player.Name,
						z = root and root.Position.Z or startZ,
					})
				end
			end
			table.sort(running, function(a, b)
				return a.z > b.z
			end)
			for _, r in ipairs(running) do
				local progress = math.clamp((r.z - startZ) / math.max(1, finishZ - startZ), 0, 1)
				table.insert(ranking, { userId = r.userId, name = r.name, finished = false, progress = progress })
			end
			Remotes.RaceLiveRanking:FireAllClients(ranking)
			task.wait(0.4)
		end
	end)

	-- Espera todos chegarem OU estourar o tempo limite (5 min).
	while os.clock() - startTime < RaceConfig.RaceTimeLimitSeconds do
		local allDone = true
		for player in racing do
			if player.Parent and not finished[player] then
				allDone = false
				break
			end
		end
		if allDone then
			break
		end
		task.wait(0.2)
	end
	connection:Disconnect()
	rankActive = false

	-- Tempo esgotou (ou todos terminaram): manda de volta quem ainda está aqui e NÃO terminou.
	local stragglers = {}
	for _, player in Players:GetPlayers() do
		if not finished[player] then
			table.insert(stragglers, player)
		end
	end
	if #stragglers > 0 then
		Remotes.RaceState:FireAllClients({ phase = "returning" })
		task.wait(1)
		returnGroup(stragglers)
	end
end

local function runSession()
	-- 1. Espera o pessoal
	waitForPlayers()

	-- 2. Quem está presente corre. Captura a velocidade-base de cada um (do TeleportData).
	local racers = Players:GetPlayers()
	RacerState.ClearAll()
	for _, player in racers do
		RacerState.Init(player, getPlayerRaceSpeed(player))
	end

	-- 3. Layout aleatório de power-ups/armadilhas (novo a cada corrida).
	TrackElements.Generate()

	-- 4. Largada
	moveToStart(racers)
	task.wait(0.5)

	-- 5. Contagem
	runCountdown(racers)

	-- 6. Corrida (com retorno individual ao chegar + retorno em grupo no fim do tempo)
	runRace(racers)

	-- 7. Limpeza
	TrackElements.Clear()
	RacerState.ClearAll()
end

function RaceManager.Start()
	PrizeService.Setup()
	task.spawn(runSession)
end

return RaceManager
