--!strict
--[[
	Remotes
	-------
	Cria/obtém os RemoteEvents do evento. No SERVIDOR cria; no CLIENTE espera.
	Assim tanto faz quem requer primeiro.

	Eventos:
	  RaceState (Servidor -> Cliente): avisa as mudanças de fase da corrida.
	    Payloads (campo .phase):
	      { phase = "waiting", n = <segundos> }
	      { phase = "countdown", n = <numero> }
	      { phase = "go" }
	      { phase = "finished", place = <n>, time = <segundos> }   (FireClient)
	      { phase = "results", standings = { {name, place, time}, ... } }
	      { phase = "returning" }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "RaceRemotes"

local function getFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function getRemoteEvent(folder: Instance, name: string): RemoteEvent
	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		return remote :: RemoteEvent
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

local folder = getFolder()

local Remotes = {
	RaceState = getRemoteEvent(folder, "RaceState"),
	-- Jump pad: servidor manda o cliente se impulsionar (cliente tem a posse física do char,
	-- então setar velocidade no servidor não funciona de forma confiável).
	-- Payload: (forwardForce: number, upForce: number)
	RaceJumpPad = getRemoteEvent(folder, "RaceJumpPad"),
	-- Placar ao vivo (Servidor -> Cliente): lista ordenada de 1º ao último, atualiza durante a corrida.
	-- Payload: { { userId, name, finished, place?, progress? }, ... }
	RaceLiveRanking = getRemoteEvent(folder, "RaceLiveRanking"),
	-- Efeito de velocidade (Servidor -> Cliente): mostra o "juice" do boost por N segundos.
	-- Payload: (duration: number)
	RaceBoostFx = getRemoteEvent(folder, "RaceBoostFx"),
	-- Empurrão genérico (Servidor -> Cliente): o cliente aplica um impulso de velocidade.
	-- Usado pelo rolo móvel (empurra pra trás) e pelo ventilador lateral (empurra pro lado).
	-- Payload: (vx: number, vy: number, vz: number)  — componentes do impulso em studs/s.
	RacePush = getRemoteEvent(folder, "RacePush"),
	-- Combo de boost (Servidor -> Cliente): avisa o dashboard sobre stacks de boost ativos.
	-- Payload: (stacks: number, duration: number, bonus: number).
	--   duration > 0 = acabou de coletar um boost (reinicia a barra de tempo no cliente).
	--   duration == 0 = um tipo de boost expirou (só atualiza a contagem de stacks).
	--   bonus = fração do bônus total de velocidade (1.5 = +150%), pro chip mostrar o multiplicador.
	RaceComboState = getRemoteEvent(folder, "RaceComboState"),
	-- Escudo (Servidor -> Cliente): avisa o cliente que pegou o escudo (cue de HUD/som).
	-- Payload: (duration: number). O visual em volta do char (ForceField) é criado no servidor.
	RaceShield = getRemoteEvent(folder, "RaceShield"),
}

return Remotes
