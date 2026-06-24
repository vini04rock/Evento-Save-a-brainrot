--[[
	RaceManager
	-----------
	Máquina de estados da corrida (autoritativa, no servidor):

	  Esperando -> Contagem -> Correndo -> Resultado -> Volta

	Modelo SESSÃO ÚNICA: roda uma corrida e teleporta todo mundo de volta.
	Detecção de chegada: compara a posição Z do jogador com a entrada da
	faixa de chegada (usa EventConfig.GetTotalLength()).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.EventConfig)
local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PrizeService = require(script.Parent.PrizeService)

local RaceManager = {}

-- Z a partir do qual se considera "chegou" (entrada da faixa xadrez).
local function getFinishZ(): number
	return Config.Origin.Z + Config.GetTotalLength() - Config.FinishLine.Length
end

local function getHumanoid(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function getRoot(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function setFrozen(player: Player, frozen: boolean)
	local hum = getHumanoid(player)
	if not hum then
		return
	end
	if frozen then
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
		hum.JumpPower = 0
	else
		hum.WalkSpeed = RaceConfig.RaceWalkSpeed
		hum.JumpHeight = 7.2
		hum.JumpPower = 50
	end
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
		setFrozen(player, true)
	end
	for n = RaceConfig.CountdownSeconds, 1, -1 do
		Remotes.RaceState:FireAllClients({ phase = "countdown", n = n })
		task.wait(1)
	end
	Remotes.RaceState:FireAllClients({ phase = "go" })
	for _, player in racers do
		setFrozen(player, false)
	end
end

-- Roda a corrida e devolve o ranking de chegada (lista ordenada).
local function runRace(racers: { Player })
	local finishZ = getFinishZ()
	local racing: { [Player]: boolean } = {}
	for _, player in racers do
		racing[player] = true
	end

	local standings = {} -- { { player, name, place, time }, ... }
	local finished: { [Player]: boolean } = {}
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
				local place = #standings + 1
				table.insert(standings, {
					player = player,
					name = player.Name,
					place = place,
					time = os.clock() - startTime,
				})

				local prize = RaceConfig.PrizeByPlace[place]
				if prize then
					PrizeService.Award(player, prize)
				end

				Remotes.RaceState:FireClient(player, {
					phase = "finished",
					place = place,
					time = os.clock() - startTime,
				})
				setFrozen(player, true) -- congela quem já chegou
			end
		end
	end)

	-- Espera todos chegarem ou estourar o tempo limite.
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
	return standings
end

local function returnAll()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end

	Remotes.RaceState:FireAllClients({ phase = "returning" })
	task.wait(1)

	if RaceConfig.MainPlaceId <= 0 or RunService:IsStudio() then
		warn(
			"[Evento] MainPlaceId não configurado ou rodando no Studio — "
				.. "teleporte de volta pulado."
		)
		return
	end

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(RaceConfig.MainPlaceId, players)
	end)
	if not ok then
		warn("[Evento] Falha ao teleportar de volta:", err)
	end
end

local function runSession()
	-- 1. Espera o pessoal
	waitForPlayers()

	-- 2. Quem está presente agora é quem corre
	local racers = Players:GetPlayers()
	moveToStart(racers)
	task.wait(0.5)

	-- 3. Contagem
	runCountdown(racers)

	-- 4. Corrida
	local standings = runRace(racers)

	-- 5. Resultado (envia versão "limpa", sem o objeto Player)
	local resultData = {}
	for _, entry in standings do
		table.insert(resultData, {
			name = entry.name,
			place = entry.place,
			time = entry.time,
		})
	end
	Remotes.RaceState:FireAllClients({ phase = "results", standings = resultData })
	task.wait(RaceConfig.ResultsSeconds)

	-- 6. Volta pro jogo principal
	returnAll()
end

function RaceManager.Start()
	PrizeService.Setup()
	task.spawn(runSession)
end

return RaceManager
