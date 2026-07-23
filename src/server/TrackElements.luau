--[[
	TrackElements
	-------------
	Power-ups e armadilhas espalhados pela pista, com layout ALEATÓRIO por corrida
	(cada sessão sorteia posições novas = corrida única).

	🟢 Boost (verde): +50% por 3s, só pro PRIMEIRO que pisar (consome).
	🔵 Jump pad (azul): empurra pra frente e pra cima (reutilizável, cooldown por player).
	🔴 Slow (vermelho): -50% por 3s (reutilizável, cooldown por player).
	🟫 Hurdle (muro baixo): atravessa a largura; o player pula por cima.

	Velocidade (boost/slow) usa RacerState (relativo à velocidade-base do player).
	Geometria parenteada numa pasta "TrackElements" no Workspace; Clear() remove tudo.

	Os pads de CHÃO (jump pad, lentidão, ventilador) são quadrados: moldura preta + face
	neon (detecta o toque) + grafismo (seta/listras) + holograma 3D flutuante. Estilo comum
	em RaceConfig.PadStyle — ver makeSquarePad. As placas flutuantes (boost/escudo) continuam
	no makeBoostGate à parte.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local EventConfig = require(ReplicatedStorage.Shared.EventConfig)
local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RacerState = require(script.Parent.RacerState)

local TrackElements = {}

local FOLDER_NAME = "TrackElements"

local function getBounds()
	local origin = EventConfig.Origin
	local totalLen = EventConfig.GetTotalLength()
	local cfg = RaceConfig.Elements
	local halfWidth = EventConfig.Floor.Width / 2
	return {
		floorTopY = origin.Y,
		centerX = origin.X,
		minZ = origin.Z + cfg.SafeStartStuds,
		maxZ = origin.Z + totalLen - cfg.SafeFinishStuds,
		minX = origin.X - (halfWidth - cfg.LaneMargin),
		maxX = origin.X + (halfWidth - cfg.LaneMargin),
	}
end

local function playerFromHit(hit: BasePart?): Player?
	local char = hit and hit.Parent
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return Players:GetPlayerFromCharacter(char)
	end
	return nil
end

-- ── Pads QUADRADOS (jump pad, lentidão, ventilador) ───────────────────────────
-- Carcaça em 3 camadas: moldura preta (base) + face neon (brilha e DETECTA O TOQUE) +
-- grafismo do chão (SurfaceGui) + holograma 3D flutuando por cima.
--
-- Divisão de papéis (o que resolve a leitura da pista):
--   • CHÃO (seta/listras, orientado pelo MUNDO) → responde "pra onde vai" / "cuidado".
--   • HOLOGRAMA 3D (parts Neon, orientado pelo MUNDO) → a seta que aponta a direção REAL.
-- Por que a seta agora pode existir: a regra antiga ("nada de setas") valia pro billboard,
-- que gira com a câmera. Uma seta feita de PARTS (chão e holograma) é orientada pelo mundo
-- e aponta certo de qualquer ângulo.

local PadStyle = RaceConfig.PadStyle or {}

-- Desenha o grafismo na face de cima do pad (SurfaceGui = custo zero de parts).
--   mark = "chevrons" → setas ">>>" (o pad EMPURRA nessa direção; a face é girada pra mundo).
--   mark = "hazard"   → listras diagonais amarelo/preto + símbolo central (zona de "cuidado").
local function paintFace(face: BasePart, mark: string, color: Color3, symbol: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "FaceArt"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.CanvasSize = Vector2.new(400, 400)
	gui.Parent = face

	if mark == "hazard" then
		-- Fundo com listras diagonais (UIGradient de transições abruptas = "faixas").
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = PadStyle.HazardColorA or Color3.fromRGB(250, 200, 40)
		bg.BorderSizePixel = 0
		bg.Parent = gui
		local a = PadStyle.HazardColorA or Color3.fromRGB(250, 200, 40)
		local b = PadStyle.HazardColorB or Color3.fromRGB(22, 22, 26)
		local grad = Instance.new("UIGradient")
		grad.Rotation = 45 -- diagonal (listra de perigo clássica)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, a),
			ColorSequenceKeypoint.new(0.249, a),
			ColorSequenceKeypoint.new(0.25, b),
			ColorSequenceKeypoint.new(0.499, b),
			ColorSequenceKeypoint.new(0.50, a),
			ColorSequenceKeypoint.new(0.749, a),
			ColorSequenceKeypoint.new(0.75, b),
			ColorSequenceKeypoint.new(1.00, b),
		})
		grad.Parent = bg
		-- Símbolo (🐌) por cima das listras, num disco escuro pra destacar.
		local disc = Instance.new("Frame")
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5, 0.5)
		disc.Size = UDim2.fromScale(0.5, 0.5)
		disc.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
		disc.BackgroundTransparency = 0.15
		disc.Parent = gui
		Instance.new("UICorner", disc).CornerRadius = UDim.new(0.5, 0)
		local sym = Instance.new("TextLabel")
		sym.AnchorPoint = Vector2.new(0.5, 0.5)
		sym.Position = UDim2.fromScale(0.5, 0.5)
		sym.Size = UDim2.fromScale(0.8, 0.8)
		sym.BackgroundTransparency = 1
		sym.Font = Enum.Font.FredokaOne
		sym.Text = symbol or "🐌"
		sym.TextScaled = true
		sym.TextColor3 = Color3.fromRGB(255, 255, 255)
		sym.Parent = disc
	else
		-- Chevrons ">>>" apontando pra frente da FACE. A face inteira é girada (yaw) na
		-- criação pra apontar no sentido do mundo, então o desenho é sempre o mesmo.
		local chev = Instance.new("TextLabel")
		chev.AnchorPoint = Vector2.new(0.5, 0.5)
		chev.Position = UDim2.fromScale(0.5, 0.5)
		chev.Size = UDim2.fromScale(0.92, 0.5)
		chev.BackgroundTransparency = 1
		chev.Font = Enum.Font.FredokaOne
		chev.Text = "❯❯❯"
		chev.TextScaled = true
		chev.TextColor3 = Color3.fromRGB(255, 255, 255)
		chev.Rotation = PadStyle.ChevronYaw or 0 -- ajuste fino no Studio (ver PadStyle)
		chev.Parent = gui
		local chevStroke = Instance.new("UIStroke")
		chevStroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.5)
		chevStroke.Thickness = 3
		chevStroke.Parent = chev
	end
end

-- Holograma 3D flutuante feito de parts Neon (orientado pelo mundo → aponta CERTO sempre).
--   shape = "arrow" → seta (haste + 2 aletas em ∧) apontando pra `dir` (unit, no mundo).
--   shape = "x"     → X (2 barras cruzadas) — pro pad de lentidão, que não tem direção.
-- Todas as parts são Anchored/CanTouch=false (não disparam o pad) e sobem/descem juntas (bob).
local function makeHolo(shape: string, dir: Vector3, position: Vector3, color: Color3, parent: Instance)
	local floatY = PadStyle.HoloFloatY or 7
	local bob = PadStyle.HoloBob or 0.7
	local thick = PadStyle.HoloThickness or 1.4
	local len = PadStyle.HoloArrowLength or 7
	local center = position + Vector3.new(0, floatY, 0)
	local parts = {}

	local function neon(size: Vector3, cf: CFrame)
		local p = Instance.new("Part")
		p.Name = "Holo"
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = 0.1
		p.Size = size
		p.CFrame = cf
		p.Parent = parent
		table.insert(parts, p)
	end

	if shape == "x" then
		local base = CFrame.new(center)
		neon(Vector3.new(len, thick, thick), base * CFrame.Angles(0, 0, math.rad(45)))
		neon(Vector3.new(len, thick, thick), base * CFrame.Angles(0, 0, math.rad(-45)))
	else
		-- lookAt: o -Z da part aponta pra `dir`. Haste ao longo desse eixo, ponta na frente.
		local look = CFrame.lookAt(center, center + dir)
		neon(Vector3.new(thick, thick, len), look) -- haste
		local tip = look * CFrame.new(0, 0, -len / 2) -- ponta (frente = -Z)
		local fin = len * 0.55
		-- Duas aletas abrindo pra trás a partir da ponta, formando o ∧.
		neon(Vector3.new(thick, thick, fin), tip * CFrame.Angles(0, math.rad(35), 0) * CFrame.new(0, 0, fin / 2))
		neon(Vector3.new(thick, thick, fin), tip * CFrame.Angles(0, math.rad(-35), 0) * CFrame.new(0, 0, fin / 2))
	end

	-- Bob: sobe/desce de leve. Tweens com o MESMO TweenInfo começam no mesmo frame → sincronizados.
	local info = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	for _, p in ipairs(parts) do
		TweenService:Create(p, info, { CFrame = p.CFrame + Vector3.new(0, bob, 0) }):Play()
	end
end

-- Monta um pad quadrado completo. `opts`:
--   color       = cor da face neon
--   floorMark   = "chevrons" | "hazard"
--   symbol      = símbolo central (usado no "hazard", ex.: 🐌)
--   holo        = "arrow" | "x" | nil (holograma 3D flutuante)
--   dir         = direção do empurrão no mundo (unit) — orienta a face E a seta 3D
-- Retorna a FACE (a part que recebe o Touched).
local function makeSquarePad(name: string, cfg, opts, position: Vector3, parent: Instance): BasePart
	local dim = cfg.Size.X
	local frameThk = PadStyle.FrameThickness or 1.4
	local inset = PadStyle.FaceInset or 0.86
	-- Gira o pad inteiro pra os chevrons apontarem no sentido do mundo (dir).
	-- yaw = ângulo entre +Z e dir: dir=(0,0,1)→0° | dir=(1,0,0)→90° | dir=(-1,0,0)→-90°.
	local dir = opts.dir or Vector3.new(0, 0, 1)
	local yaw = math.deg(math.atan2(dir.X, dir.Z))
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)

	-- Moldura preta (base larga, escura, fosca) — o contraste das referências.
	local frame = Instance.new("Part")
	frame.Name = name
	frame.Anchored = true
	frame.CanCollide = false
	frame.CanTouch = false
	frame.CastShadow = false
	frame.Size = Vector3.new(dim, frameThk, dim)
	frame.Color = PadStyle.FrameColor or Color3.fromRGB(10, 10, 14)
	frame.Material = Enum.Material.SmoothPlastic
	frame.CFrame = base
	frame.Parent = parent

	-- Face neon (encaixada dentro da moldura, levemente saliente). RECEBE O TOQUE.
	local face = Instance.new("Part")
	face.Name = "Face"
	face.Anchored = true
	face.CanCollide = false
	face.CastShadow = false
	face.Size = Vector3.new(dim * inset, frameThk * 1.1, dim * inset)
	face.Color = opts.color
	face.Material = Enum.Material.Neon
	face.Transparency = PadStyle.FaceTransparency or 0.12
	face.CFrame = base * CFrame.new(0, frameThk * 0.15, 0)
	face.Parent = parent

	paintFace(face, opts.floorMark or "chevrons", opts.color, opts.symbol)

	-- Pulso suave na face: faz o pad parecer "vivo".
	TweenService:Create(
		face,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = math.min(1, (PadStyle.FaceTransparency or 0.12) + 0.28) }
	):Play()

	if opts.holo then
		makeHolo(opts.holo, dir, position, opts.color, parent)
	end

	return face
end

-- 🟢 Boost: PLACA flutuante semitransparente com símbolo de velocidade (o player atravessa).
-- Flutua na altura do player (bob suave) e mostra o símbolo nas duas faces.
local function makeBoostGate(cfg, position: Vector3, parent: Instance): BasePart
	local color = cfg.Color
	local lightColor = color:Lerp(Color3.fromRGB(255, 255, 255), 0.3)

	local panel = Instance.new("Part")
	panel.Name = "BoostGate"
	panel.Anchored = true
	panel.CanCollide = false
	panel.Size = cfg.Size
	panel.Color = color
	panel.Material = Enum.Material.Neon
	panel.Transparency = 0.55
	panel.CastShadow = false
	panel.Position = position
	panel.Parent = parent

	-- Brilho ambiente.
	local light = Instance.new("PointLight")
	light.Color = lightColor
	light.Brightness = 2.4
	light.Range = 16
	light.Shadows = false
	light.Parent = panel

	-- Faíscas subindo (detalhe "mágico").
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(lightColor, Color3.fromRGB(255, 255, 255))
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Rate = 16
	emitter.Speed = NumberRange.new(1, 3)
	emitter.Acceleration = Vector3.new(0, 4, 0)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = panel

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Parent = panel

		-- Painel arredondado com borda neon.
		local border = Instance.new("Frame")
		border.Name = "Border"
		border.AnchorPoint = Vector2.new(0.5, 0.5)
		border.Position = UDim2.fromScale(0.5, 0.5)
		border.Size = UDim2.fromScale(0.92, 0.86)
		border.BackgroundColor3 = Color3.fromRGB(8, 28, 16)
		border.BackgroundTransparency = 0.3
		border.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 26)
		corner.Parent = border
		local stroke = Instance.new("UIStroke")
		stroke.Color = lightColor
		stroke.Thickness = 6
		stroke.Transparency = 0
		stroke.Parent = border
		local innerGrad = Instance.new("UIGradient")
		innerGrad.Color = ColorSequence.new(color, Color3.fromRGB(10, 40, 22))
		innerGrad.Rotation = 90
		innerGrad.Parent = border

		-- Símbolo de velocidade GRANDE com gradiente + contorno.
		local label = Instance.new("TextLabel")
		label.Name = "Symbol"
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.92, 0.78)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.Text = tostring(cfg.Symbol or ">>")
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(250, 255, 250)
		label.Parent = border
		-- Contorno pra dar definição (sem gradiente, pra o emoji manter a cor natural).
		local labelStroke = Instance.new("UIStroke")
		labelStroke.Color = Color3.fromRGB(16, 78, 38)
		labelStroke.Thickness = 4
		labelStroke.Transparency = 0.1
		labelStroke.Parent = label
	end

	-- Bob flutuante (sobe/desce de leve).
	panel.Position = position + Vector3.new(0, 0.8, 0)
	TweenService:Create(
		panel,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = position - Vector3.new(0, 0.8, 0) }
	):Play()

	return panel
end

-- Aplica o boost SÓ pro primeiro corredor que atravessar (a placa some — foi coletada).
local function wireBoost(gate: BasePart, cfg)
	local used = false
	gate.Touched:Connect(function(hit)
		if used then
			return
		end
		local player = playerFromHit(hit)
		if not player or not RacerState.IsRacer(player) then
			return
		end
		used = true
		-- Boost ACUMULÁVEL por tipo: `cfg` é a chave do tipo (SpeedBoost ≠ MegaBoost).
		-- Mesmo tipo empilha e reseta o timer; tipos diferentes somam com timers próprios.
		RacerState.AddBoost(player, cfg, cfg.Multiplier, cfg.Duration, function(stacksLeft)
			-- expirou: atualiza contagem + multiplicador restante (barra não reinicia)
			Remotes.RaceComboState:FireClient(player, stacksLeft, 0, RacerState.GetBoostBonus(player))
		end)
		-- coletou: reinicia a barra + manda contagem e multiplicador total atuais
		Remotes.RaceComboState:FireClient(player, RacerState.GetBoostStacks(player), cfg.Duration, RacerState.GetBoostBonus(player))
		Remotes.RaceBoostFx:FireClient(player, cfg.Duration) -- efeito de velocidade no cliente
		gate.CanTouch = false
		for _, gui in ipairs(gate:GetChildren()) do
			if gui:IsA("SurfaceGui") then
				gui.Enabled = false
			end
		end
		TweenService:Create(gate, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		Debris:AddItem(gate, 0.3)
	end)
end

-- 🛡️ Escudo: concede imunidade às armadilhas + mostra o ForceField (visível a todos) por N seg.
local function grantShield(player: Player, duration: number)
	RacerState.SetShield(player, duration)
	local char = player.Character
	if char then
		local old = char:FindFirstChildOfClass("ForceField") -- troca o visual se pegou outro
		if old then
			old:Destroy()
		end
		local ff = Instance.new("ForceField")
		ff.Visible = true
		ff.Parent = char
		Debris:AddItem(ff, duration)
	end
	Remotes.RaceShield:FireClient(player, duration) -- cue de HUD/som no cliente
end

-- Escudo: placa flutuante (igual ao boost), mas dá imunidade. Consome no 1º toque.
local function wireShield(gate: BasePart, cfg)
	local used = false
	gate.Touched:Connect(function(hit)
		if used then
			return
		end
		local player = playerFromHit(hit)
		if not player or not RacerState.IsRacer(player) then
			return
		end
		used = true
		grantShield(player, cfg.Duration)
		gate.CanTouch = false
		for _, gui in ipairs(gate:GetChildren()) do
			if gui:IsA("SurfaceGui") then
				gui.Enabled = false
			end
		end
		TweenService:Create(gate, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		Debris:AddItem(gate, 0.3)
	end)
end

-- 🔵 Jump pad: empurra pra frente (+Z, sentido da corrida) e pra cima (+Y).
local function wireJumpPad(pad: BasePart, cfg)
	local cooldown: { [Player]: number } = {}
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or not RacerState.IsRacer(player) then
			return
		end
		local now = os.clock()
		if cooldown[player] and (now - cooldown[player]) < cfg.PlayerCooldown then
			return
		end
		cooldown[player] = now
		-- O CLIENTE aplica a velocidade (a posse física do personagem é dele; setar no
		-- servidor não impulsiona de forma confiável). Manda força pra frente (+Z) e pra cima.
		Remotes.RaceJumpPad:FireClient(player, cfg.ForwardForce, cfg.UpForce)
	end)
end

-- 🔴 Slow: aplica lentidão (reutilizável; cooldown por player pra não re-disparar parado em cima).
local function wireSlow(pad: BasePart, cfg)
	local cooldown: { [Player]: number } = {}
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or not RacerState.IsRacer(player) then
			return
		end
		if RacerState.IsShielded(player) then
			return -- 🛡️ escudo ativo: ignora a armadilha
		end
		local now = os.clock()
		if cooldown[player] and (now - cooldown[player]) < cfg.PlayerCooldown then
			return
		end
		cooldown[player] = now
		RacerState.ApplyMultiplier(player, cfg.Multiplier, cfg.Duration)
	end)
end

-- 🟫 Muro baixo (atravessa a largura; o player pula por cima).
local function makeHurdle(width: number, cfg, position: Vector3, parent: Instance): BasePart
	local w = Instance.new("Part")
	w.Name = "Hurdle"
	w.Anchored = true
	w.CanCollide = true
	w.Size = Vector3.new(width, cfg.Height, cfg.Thickness)
	w.Color = cfg.Color
	w.Material = Enum.Material.Wood
	w.Position = position
	w.Parent = parent
	return w
end

-- 🟠 Rolo móvel: bloco que desliza de um lado pro outro (eixo X) atravessando a pista.
-- Encostou = empurrão pra trás (-Z) + lentidão curta. Movimento via tween (vai e volta).
local function makeRoller(cfg, z: number, halfWidth: number, centerX: number, floorTopY: number, parent: Instance, rng: Random)
	local slideMin = centerX - (halfWidth - cfg.SlideMargin)
	local slideMax = centerX + (halfWidth - cfg.SlideMargin)
	local y = floorTopY + cfg.Size.Y / 2
	local startLeft = rng:NextInteger(0, 1) == 0
	local fromX = startLeft and slideMin or slideMax
	local toX = startLeft and slideMax or slideMin

	local roller = Instance.new("Part")
	roller.Name = "Roller"
	roller.Anchored = true
	roller.CanCollide = false
	roller.Size = cfg.Size
	roller.Color = cfg.Color
	roller.Material = Enum.Material.Neon
	roller.Position = Vector3.new(fromX, y, z)
	roller.TopSurface = Enum.SurfaceType.Smooth
	roller.BottomSurface = Enum.SurfaceType.Smooth
	roller.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = cfg.Color
	light.Brightness = 1.6
	light.Range = 12
	light.Shadows = false
	light.Parent = roller

	-- Desincroniza os rolos: tempo levemente diferente por unidade.
	local slideTime = cfg.SlideTime * rng:NextNumber(0.85, 1.15)
	TweenService:Create(
		roller,
		TweenInfo.new(slideTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = Vector3.new(toX, y, z) }
	):Play()

	local cooldown: { [Player]: number } = {}
	roller.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or not RacerState.IsRacer(player) then
			return
		end
		if RacerState.IsShielded(player) then
			return -- 🛡️ escudo ativo: ignora a armadilha
		end
		local now = os.clock()
		if cooldown[player] and (now - cooldown[player]) < cfg.PlayerCooldown then
			return
		end
		cooldown[player] = now
		-- Mesma força/parâmetros do jump pad, porém pra TRÁS (forward negativo). Reusa o
		-- RaceJumpPad (que SETA a velocidade no cliente — forte e confiável, não aditivo).
		local jump = RaceConfig.Elements.JumpPad
		Remotes.RaceJumpPad:FireClient(player, -jump.ForwardForce, jump.UpForce)
		RacerState.ApplyMultiplier(player, cfg.SlowMultiplier, cfg.SlowDuration)
	end)
	return roller
end

-- 🎡 Barra giratória: braço que gira no plano horizontal (eixo Y), pivô no centro da pista.
-- Encostou = empurrão pra TRÁS (como o rolo) + lentidão curta. Exige timing pra passar.
local function makeSpinner(cfg, z: number, centerX: number, floorTopY: number, parent: Instance, rng: Random)
	local y = floorTopY + cfg.Height / 2
	local startAngle = rng:NextNumber(0, 360) -- desincroniza as barras

	local arm = Instance.new("Part")
	arm.Name = "Spinner"
	arm.Anchored = true
	arm.CanCollide = false
	arm.Size = Vector3.new(cfg.ArmLength, cfg.Height, cfg.Thickness)
	arm.Color = cfg.Color
	arm.Material = Enum.Material.Neon
	arm.CFrame = CFrame.new(centerX, y, z) * CFrame.Angles(0, math.rad(startAngle), 0)
	arm.TopSurface = Enum.SurfaceType.Smooth
	arm.BottomSurface = Enum.SurfaceType.Smooth
	arm.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = cfg.Color
	light.Brightness = 1.6
	light.Range = 14
	light.Shadows = false
	light.Parent = arm

	-- Gira sem parar (varre a pista). Tempo levemente diferente por unidade.
	local rotTime = cfg.RotationTime * rng:NextNumber(0.85, 1.15)
	TweenService:Create(
		arm,
		TweenInfo.new(rotTime, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Orientation = arm.Orientation + Vector3.new(0, 360, 0) }
	):Play()

	local cooldown: { [Player]: number } = {}
	arm.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or not RacerState.IsRacer(player) then
			return
		end
		if RacerState.IsShielded(player) then
			return -- 🛡️ escudo ativo: ignora a armadilha
		end
		local now = os.clock()
		if cooldown[player] and (now - cooldown[player]) < cfg.PlayerCooldown then
			return
		end
		cooldown[player] = now
		-- Empurrão pra TRÁS + lentidão curta (mesma pegada do rolo).
		local jump = RaceConfig.Elements.JumpPad
		Remotes.RaceJumpPad:FireClient(player, -jump.ForwardForce, jump.UpForce)
		RacerState.ApplyMultiplier(player, cfg.SlowMultiplier, cfg.SlowDuration)
	end)
	return arm
end

-- 🏁 Arco de checkpoint: landmark visual que o player atravessa (não bloqueia).
-- Mostra a % do percurso (combina com a barra de progresso do HUD).
local function makeArch(z: number, halfWidth: number, floorTopY: number, pillarH: number, label: string, parent: Instance)
	local archColor = Color3.fromRGB(120, 200, 255)
	local pillarW = 6
	local edgeX = halfWidth - 6
	local y = floorTopY + pillarH / 2

	local function pillar(x: number)
		local p = Instance.new("Part")
		p.Name = "ArchPillar"
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Size = Vector3.new(pillarW, pillarH, pillarW)
		p.Color = archColor
		p.Material = Enum.Material.Neon
		p.Position = Vector3.new(x, y, z)
		p.Parent = parent
	end
	pillar(-edgeX)
	pillar(edgeX)

	local beam = Instance.new("Part")
	beam.Name = "ArchBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CastShadow = false
	beam.Size = Vector3.new(edgeX * 2 + pillarW, pillarW, pillarW * 1.4)
	beam.Color = archColor
	beam.Material = Enum.Material.Neon
	beam.Position = Vector3.new(0, floorTopY + pillarH, z)
	beam.Parent = parent

	-- Placa flutuante com a % (sempre virada pra câmera), logo acima da viga.
	local bb = Instance.new("BillboardGui")
	bb.Name = "ArchLabel"
	bb.Size = UDim2.fromOffset(320, 130)
	bb.StudsOffset = Vector3.new(0, 12, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 2000
	bb.Adornee = beam
	bb.Parent = beam
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.FredokaOne
	txt.Text = label
	txt.TextColor3 = Color3.fromRGB(255, 255, 255)
	txt.TextStrokeColor3 = Color3.fromRGB(20, 60, 110)
	txt.TextStrokeTransparency = 0.2
	txt.TextScaled = true
	txt.Parent = bb
end

-- 💨 Ventilador lateral: pad no chão que sopra o player pro lado (dir = -1 ou +1 no eixo X).
local function makeSideFan(cfg, position: Vector3, dir: number, parent: Instance): BasePart
	-- Pad quadrado com seta (chão + holograma 3D) apontando pro lado que sopra. A partícula
	-- de vento (abaixo) reforça a direção. `dir` no eixo X vira o vetor-mundo do empurrão.
	local pad = makeSquarePad("SideFan", cfg, {
		color = cfg.Color,
		floorMark = "chevrons",
		holo = "arrow",
		dir = Vector3.new(dir, 0, 0),
	}, position, parent)

	local light = Instance.new("PointLight")
	light.Color = cfg.Color
	light.Brightness = 1.2
	light.Range = 10
	light.Shadows = false
	light.Parent = pad

	-- A face do pad é GIRADA (yaw) pra a seta apontar pro lado certo, e EmissionDirection
	-- é relativo à part — direto nela, o vento sairia torto. Este Attachment tem WorldCFrame
	-- sem rotação, então os eixos do emitter voltam a bater com os do mundo (Right = +X)
	-- independente de como a face esteja girada.
	local windOrigin = Instance.new("Attachment")
	windOrigin.Name = "WindOrigin"
	windOrigin.Parent = pad
	windOrigin.WorldCFrame = CFrame.new(position)

	-- "Vento" visível saindo pro lado (dica pro jogador).
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(cfg.Color, Color3.fromRGB(255, 255, 255))
	emitter.LightEmission = 0.5
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Rate = 18
	emitter.Speed = NumberRange.new(12, 18)
	emitter.Acceleration = Vector3.new(dir * 30, 0, 0)
	emitter.EmissionDirection = (dir > 0) and Enum.NormalId.Right or Enum.NormalId.Left
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Size = NumberSequence.new(2)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = windOrigin

	local cooldown: { [Player]: number } = {}
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or not RacerState.IsRacer(player) then
			return
		end
		if RacerState.IsShielded(player) then
			return -- 🛡️ escudo ativo: ignora a armadilha
		end
		local now = os.clock()
		if cooldown[player] and (now - cooldown[player]) < cfg.PlayerCooldown then
			return
		end
		cooldown[player] = now
		Remotes.RacePush:FireClient(player, dir * cfg.SideForce, cfg.UpForce, 0) -- empurra pro lado
	end)
	return pad
end

-- Gera o layout (novo a cada chamada). Retorna a pasta criada.
function TrackElements.Generate(): Folder
	TrackElements.Clear()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace

	local b = getBounds()
	local cfg = RaceConfig.Elements
	local rng = Random.new() -- semente nova a cada corrida = layout único

	local function randomPadPos(size: Vector3): Vector3
		return Vector3.new(rng:NextNumber(b.minX, b.maxX), b.floorTopY + size.Y / 2, rng:NextNumber(b.minZ, b.maxZ))
	end

	for _ = 1, cfg.SpeedBoost.Count do
		local pos = Vector3.new(rng:NextNumber(b.minX, b.maxX), b.floorTopY + cfg.SpeedBoost.FloatY, rng:NextNumber(b.minZ, b.maxZ))
		wireBoost(makeBoostGate(cfg.SpeedBoost, pos, folder), cfg.SpeedBoost)
	end
	for _ = 1, cfg.JumpPad.Count do
		local c = cfg.JumpPad
		-- 🚀 Empurra sempre pra FRENTE (+Z): seta no chão + holograma 3D apontando pra chegada.
		local pad = makeSquarePad("JumpPad", c, {
			color = c.Color,
			floorMark = "chevrons",
			holo = "arrow",
			dir = Vector3.new(0, 0, 1),
		}, randomPadPos(c.Size), folder)
		wireJumpPad(pad, c)
	end
	for _ = 1, cfg.Slow.Count do
		local c = cfg.Slow
		-- 🐌 Sem direção: listras de perigo + 🐌 no chão, e um X neon 3D flutuando ("zona ruim").
		local pad = makeSquarePad("SlowPad", c, {
			color = c.Color,
			floorMark = "hazard",
			symbol = tostring(c.Symbol or "🐌"),
			holo = "x",
		}, randomPadPos(c.Size), folder)
		wireSlow(pad, c)
	end

	local hurdleWidth = EventConfig.Floor.Width
	for _ = 1, cfg.Hurdle.Count do
		local z = rng:NextNumber(b.minZ, b.maxZ)
		makeHurdle(hurdleWidth, cfg.Hurdle, Vector3.new(b.centerX, b.floorTopY + cfg.Hurdle.Height / 2, z), folder)
	end

	-- ⭐ Mega boost (raro): mesma placa flutuante do boost, dourada e mais forte.
	for _ = 1, cfg.MegaBoost.Count do
		local pos = Vector3.new(rng:NextNumber(b.minX, b.maxX), b.floorTopY + cfg.MegaBoost.FloatY, rng:NextNumber(b.minZ, b.maxZ))
		wireBoost(makeBoostGate(cfg.MegaBoost, pos, folder), cfg.MegaBoost)
	end

	-- 🟠 Rolo móvel: desliza no eixo X atravessando a pista.
	local halfWidth = EventConfig.Floor.Width / 2
	for _ = 1, cfg.Roller.Count do
		local z = rng:NextNumber(b.minZ, b.maxZ)
		makeRoller(cfg.Roller, z, halfWidth, b.centerX, b.floorTopY, folder, rng)
	end

	-- 💨 Ventilador lateral: empurra pro lado (direção sorteada por unidade).
	for _ = 1, cfg.SideFan.Count do
		local pos = randomPadPos(cfg.SideFan.Size)
		local dir = (rng:NextInteger(0, 1) == 0) and -1 or 1
		makeSideFan(cfg.SideFan, pos, dir, folder)
	end

	-- 🛡️ Escudo: mesma placa flutuante do boost, dá imunidade às armadilhas.
	for _ = 1, cfg.Shield.Count do
		local pos = Vector3.new(rng:NextNumber(b.minX, b.maxX), b.floorTopY + cfg.Shield.FloatY, rng:NextNumber(b.minZ, b.maxZ))
		wireShield(makeBoostGate(cfg.Shield, pos, folder), cfg.Shield)
	end

	-- Checkpoints da corrida (frações do percurso): FONTE ÚNICA usada pelos ARCOS de %
	-- E pelas BARRAS GIRATÓRIAS. Assim cada arco tem sua barra bem ali, sempre em sincronia
	-- (mude a lista e os dois acompanham juntos). Fora do fully-random = nunca se sobrepõem.
	local totalLen = EventConfig.GetTotalLength()
	local checkpointFracs = cfg.Checkpoints or { 0.25, 0.5, 0.75 }

	-- 🎡 Barra giratória: uma em cada checkpoint (o arco marca; a barra é o obstáculo ali).
	for _, frac in ipairs(checkpointFracs) do
		local z = EventConfig.Origin.Z + totalLen * frac
		makeSpinner(cfg.Spinner, z, b.centerX, b.floorTopY, folder, rng)
	end

	-- 🏁 Arcos de checkpoint (landmarks nos mesmos pontos das barras — casam com a barra de progresso).
	-- Altura do arco = 60% da parede lateral, pra o número ficar bem acima da metade (não colado no chão).
	local wallHeight = (EventConfig.Walls and EventConfig.Walls.Height) or 400
	local archPillarH = wallHeight * 0.6
	for _, frac in ipairs(checkpointFracs) do
		local z = EventConfig.Origin.Z + totalLen * frac
		makeArch(z, halfWidth, b.floorTopY, archPillarH, string.format("%d%%", math.floor(frac * 100)), folder)
	end

	return folder
end

function TrackElements.Clear()
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
end

return TrackElements
