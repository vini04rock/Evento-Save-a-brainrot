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

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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
	elseif phase == "go" then
		flashCenter("JÁ!", Color3.fromRGB(120, 255, 120))
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
