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
}

return Remotes
