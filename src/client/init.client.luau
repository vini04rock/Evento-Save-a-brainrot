--[[
	RaceHud (cliente)
	-----------------
	Mostra na tela o andamento da corrida: aviso de espera, contagem regressiva,
	"JÁ!", cronômetro durante a corrida, sua colocação ao chegar e o quadro de
	resultados no fim. Tudo dirigido pelo RemoteEvent RaceState.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── "Juice": sons + efeitos de câmera + confete ────────────────────────
local BASE_FOV = 70

local function playSound(soundId: number?)
	local id = tonumber(soundId) or 0
	if id <= 0 then
		return -- 0 = sem som configurado
	end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(id)
	sound.Volume = tonumber(RaceConfig.Sounds and RaceConfig.Sounds.Volume) or 0.6
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(8, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local fovToken = 0
-- Aumenta o FOV (sensação de velocidade) por `hold` segundos e volta ao normal.
local function fovPunch(extra: number, hold: number, restore: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	fovToken += 1
	local token = fovToken
	TweenService:Create(camera, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = BASE_FOV + extra,
	}):Play()
	task.delay(hold, function()
		if fovToken ~= token then
			return
		end
		local cam = workspace.CurrentCamera
		if cam then
			TweenService:Create(cam, TweenInfo.new(restore, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				FieldOfView = BASE_FOV,
			}):Play()
		end
	end)
end

-- Explosão de confete colorido no personagem (na chegada).
local function celebrate()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 90)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 150)),
	})
	emitter.LightEmission = 0.6
	emitter.Lifetime = NumberRange.new(0.9, 1.6)
	emitter.Speed = NumberRange.new(10, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.Size = NumberSequence.new(1.3)
	emitter.Parent = root
	emitter:Emit(70)
	task.delay(2.5, function()
		emitter:Destroy()
	end)
end

-- ── Helpers de UI ──────────────────────────────────────────────────────
local function withStroke(gui: GuiObject, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.Parent = gui
	return stroke
end

local function placeText(place: number): string
	return tostring(place) .. "º"
end

local function formatTime(seconds: number): string
	return string.format("%.1fs", seconds)
end

-- ── GUI ────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "RaceHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- Texto grande central (contagem, JÁ!, mensagens).
local center = Instance.new("TextLabel")
center.Name = "Center"
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.42)
center.Size = UDim2.fromScale(0.8, 0.3)
center.BackgroundTransparency = 1
center.Font = Enum.Font.FredokaOne
center.TextScaled = true
center.TextColor3 = Color3.fromRGB(255, 255, 255)
center.Text = ""
center.Visible = false
withStroke(center, 4)
center.Parent = gui

-- Cronômetro no topo.
local timer = Instance.new("TextLabel")
timer.Name = "Timer"
timer.AnchorPoint = Vector2.new(0.5, 0)
timer.Position = UDim2.fromScale(0.5, 0.04)
timer.Size = UDim2.fromScale(0.2, 0.08)
timer.BackgroundTransparency = 1
timer.Font = Enum.Font.FredokaOne
timer.TextScaled = true
timer.TextColor3 = Color3.fromRGB(255, 255, 255)
timer.Text = ""
timer.Visible = false
withStroke(timer, 3)
timer.Parent = gui

-- Quadro de resultados.
local results = Instance.new("Frame")
results.Name = "Results"
results.AnchorPoint = Vector2.new(0.5, 0.5)
results.Position = UDim2.fromScale(0.5, 0.5)
results.Size = UDim2.fromScale(0.4, 0.55)
results.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
results.BackgroundTransparency = 0.1
results.Visible = false
Instance.new("UICorner").Parent = results
results.Parent = gui

local resultsTitle = Instance.new("TextLabel")
resultsTitle.Size = UDim2.fromScale(1, 0.15)
resultsTitle.BackgroundTransparency = 1
resultsTitle.Font = Enum.Font.FredokaOne
resultsTitle.TextScaled = true
resultsTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
resultsTitle.Text = "🏁 Resultado"
resultsTitle.Parent = results

local resultsList = Instance.new("Frame")
resultsList.Position = UDim2.fromScale(0.05, 0.17)
resultsList.Size = UDim2.fromScale(0.9, 0.8)
resultsList.BackgroundTransparency = 1
resultsList.Parent = results

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0.02, 0)
listLayout.Parent = resultsList

-- ── Estado do cronômetro ───────────────────────────────────────────────
local raceStartClock: number? = nil
local timerConnection: RBXScriptConnection? = nil

local function stopTimer()
	if timerConnection then
		timerConnection:Disconnect()
		timerConnection = nil
	end
end

local function startTimer()
	stopTimer()
	raceStartClock = os.clock()
	timer.Visible = true
	timerConnection = RunService.RenderStepped:Connect(function()
		if raceStartClock then
			timer.Text = formatTime(os.clock() - raceStartClock)
		end
	end)
end

-- ── Animações simples ──────────────────────────────────────────────────
local function flashCenter(text: string, color: Color3)
	center.Text = text
	center.TextColor3 = color
	center.Visible = true
end

local function buildResults(standings)
	for _, child in resultsList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if #standings == 0 then
		local none = Instance.new("TextLabel")
		none.Size = UDim2.fromScale(1, 0.12)
		none.BackgroundTransparency = 1
		none.Font = Enum.Font.GothamMedium
		none.TextScaled = true
		none.TextColor3 = Color3.fromRGB(220, 220, 220)
		none.Text = "Ninguém chegou 😅"
		none.Parent = resultsList
		return
	end
	for i, entry in standings do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(1, 0.12)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = i
		local medal = if entry.place == 1
			then "🥇"
			elseif entry.place == 2 then "🥈"
			elseif entry.place == 3 then "🥉"
			else "  "
		row.TextColor3 = if entry.place <= 3
			then Color3.fromRGB(255, 215, 0)
			else Color3.fromRGB(230, 230, 230)
		row.Text = string.format(
			"%s %s  %s  (%s)",
			medal,
			placeText(entry.place),
			entry.name,
			formatTime(entry.time)
		)
		row.Parent = resultsList
	end
end

-- ── Reage às mudanças de fase ──────────────────────────────────────────
local function onState(payload)
	local phase = payload.phase

	if phase == "waiting" then
		results.Visible = false
		timer.Visible = false
		local suffix = if payload.n then " (" .. payload.n .. ")" else ""
		flashCenter("Aguardando jogadores..." .. suffix, Color3.fromRGB(180, 220, 255))
	elseif phase == "countdown" then
		flashCenter(tostring(payload.n), Color3.fromRGB(255, 255, 255))
		playSound(RaceConfig.Sounds.CountdownBeep)
	elseif phase == "go" then
		flashCenter("JÁ!", Color3.fromRGB(120, 255, 120))
		playSound(RaceConfig.Sounds.Go)
		startTimer()
		task.delay(1, function()
			if center.Text == "JÁ!" then
				center.Visible = false
			end
		end)
	elseif phase == "finished" then
		stopTimer()
		flashCenter(
			"Você chegou em " .. placeText(payload.place) .. "!",
			Color3.fromRGB(255, 215, 0)
		)
		playSound(RaceConfig.Sounds.Finish)
		celebrate()
	elseif phase == "results" then
		stopTimer()
		center.Visible = false
		timer.Visible = false
		buildResults(payload.standings)
		results.Visible = true
	elseif phase == "returning" then
		results.Visible = false
		flashCenter("Voltando ao jogo...", Color3.fromRGB(180, 220, 255))
	end
end

Remotes.RaceState.OnClientEvent:Connect(onState)

-- Jump pad: o servidor manda; o CLIENTE se impulsiona (a posse física do char é dele,
-- então é aqui que a velocidade "pega"). Força pra cima (sai do chão) + pra frente (+Z).
Remotes.RaceJumpPad.OnClientEvent:Connect(function(forwardForce, upForce)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local vx = root.AssemblyLinearVelocity.X
		root.AssemblyLinearVelocity = Vector3.new(vx, tonumber(upForce) or 80, tonumber(forwardForce) or 110)
		playSound(RaceConfig.Sounds.JumpPad)
		fovPunch(8, 0.12, 0.25) -- "kick" rápido de câmera
	end
end)

-- Boost (placa de velocidade): som + sensação de velocidade (FOV puxado) pela duração.
Remotes.RaceBoostFx.OnClientEvent:Connect(function(duration)
	playSound(RaceConfig.Sounds.Boost)
	fovPunch(14, tonumber(duration) or 3, 0.4)
end)

-- Empurrão genérico: o servidor manda e o CLIENTE aplica o impulso (posse física do char é dele).
-- Usado pelo rolo móvel (pra trás) e pelo ventilador lateral (pro lado). É ADITIVO ao movimento atual.
Remotes.RacePush.OnClientEvent:Connect(function(vx, vy, vz)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = root.AssemblyLinearVelocity
			+ Vector3.new(tonumber(vx) or 0, tonumber(vy) or 0, tonumber(vz) or 0)
		fovPunch(6, 0.12, 0.22) -- leve kick de câmera no impacto
	end
end)

-- ── Placar de posições AO VIVO (direita da tela) ───────────────────────
local rankMedals = { [1] = "🥇", [2] = "🥈", [3] = "🥉" }

local rankPanel = Instance.new("Frame")
rankPanel.Name = "Ranking"
rankPanel.AnchorPoint = Vector2.new(1, 0.5)
rankPanel.Position = UDim2.new(0.99, 0, 0.46, 0)
rankPanel.Size = UDim2.fromScale(0.2, 0.52)
rankPanel.BackgroundColor3 = Color3.fromRGB(16, 20, 36)
rankPanel.BackgroundTransparency = 0.22
rankPanel.BorderSizePixel = 0
rankPanel.Visible = false
Instance.new("UICorner").Parent = rankPanel
local rankPanelStroke = Instance.new("UIStroke")
rankPanelStroke.Color = Color3.fromRGB(255, 213, 92)
rankPanelStroke.Thickness = 2
rankPanelStroke.Transparency = 0.35
rankPanelStroke.Parent = rankPanel
rankPanel.Parent = gui

local rankTitle = Instance.new("TextLabel")
rankTitle.Size = UDim2.fromScale(1, 0.1)
rankTitle.BackgroundTransparency = 1
rankTitle.Font = Enum.Font.FredokaOne
rankTitle.TextScaled = true
rankTitle.TextColor3 = Color3.fromRGB(255, 224, 130)
rankTitle.Text = "🏁 Posições"
rankTitle.Parent = rankPanel

local rankList = Instance.new("Frame")
rankList.Position = UDim2.fromScale(0.04, 0.12)
rankList.Size = UDim2.fromScale(0.92, 0.86)
rankList.BackgroundTransparency = 1
rankList.Parent = rankPanel
local rankLayout = Instance.new("UIListLayout")
rankLayout.SortOrder = Enum.SortOrder.LayoutOrder
rankLayout.Padding = UDim.new(0.015, 0)
rankLayout.Parent = rankList

local function buildRanking(list)
	for _, child in rankList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if type(list) ~= "table" or #list == 0 then
		rankPanel.Visible = false
		return
	end
	rankPanel.Visible = true
	for i, entry in list do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(1, 0.072)
		row.BackgroundColor3 = Color3.fromRGB(8, 12, 26)
		row.BackgroundTransparency = 0.35
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamBold
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextScaled = true
		row.LayoutOrder = i
		local rankNum = (entry.finished and entry.place) or i
		local badge = rankMedals[rankNum] or (tostring(rankNum) .. "º")
		local check = entry.finished and " ✓" or ""
		row.Text = string.format("  %s %s%s", badge, tostring(entry.name), check)
		local isLocal = entry.userId == player.UserId
		row.TextColor3 = if isLocal
			then Color3.fromRGB(130, 255, 160)
			elseif entry.finished then Color3.fromRGB(255, 224, 130)
			else Color3.fromRGB(225, 232, 245)
		if isLocal then
			row.BackgroundColor3 = Color3.fromRGB(28, 60, 36)
			row.BackgroundTransparency = 0.12
		end
		Instance.new("UICorner").Parent = row
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 16
		constraint.MinTextSize = 8
		constraint.Parent = row
		row.Parent = rankList
	end
end

Remotes.RaceLiveRanking.OnClientEvent:Connect(buildRanking)
