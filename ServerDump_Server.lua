--[[
	=====================================================================================
	 Dex++ Server Dump  —  SERVER HALF
	=====================================================================================
	 Put THIS file in the game you own:

	     ServerScriptService  ->  Script  ->  paste everything below

	 or run it through a server-side executor. It needs no executor APIs: it only reads
	 Instances and streams XML to the client that asks for it.

	 Then, in your client executor, open Dex++ and use
	     Save Instance  ->  "Save ServerStorage (.rbxmx)"
	 The file lands in your executor workspace folder (listfiles()), insert it in Studio.

	 ServerStorage / ServerScriptService never replicate to clients, which is exactly why
	 this script has to run on the server. Make sure ALLOWED_USER_IDS is filled in, so
	 only YOU can pull the dump.
	=====================================================================================
]]

-- =============================== CONFIG ===============================
local ALLOWED_USER_IDS = {
	  10148033407,   <-- YOUR UserId. Empty list = any player may request the dump.
}

local TARGETS = { "ServerStorage", "ServerScriptService" }  -- what the client may request
local REMOTE_NAME = "__DexServerStorageDump"                -- must match Dex++'s name
local CHUNK_SIZE = 64 * 1024                                -- bytes per remote chunk
-- ======================================================================

-- >>> DEXDUMP SERIALIZER START
-- Minimal but real .rbxmx (Roblox XML) writer. No executor APIs needed: it only reads
-- instances and streams XML text out through a sink function.
local xmlEscape, fmtNum
do
	local map = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&apos;" }
	xmlEscape = function(s)
		return (tostring(s):gsub("[&<>\"']", map))
	end
	fmtNum = function(n)
		n = tonumber(n) or 0
		if n ~= n or n == math.huge or n == -math.huge then
			return "0"
		end
		return (string.format("%.14g", n))
	end
end

local XML_HEADER = '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'

-- strings that Roblox stores as <Content>
local CONTENT_PROPS = {
	Texture = true, TextureId = true, TextureID = true, MeshId = true, SoundId = true,
	Image = true, ShirtTemplate = true, PantsTemplate = true, Graphic = true,
	TexturePack = true, SkyboxBk = true, SkyboxDn = true, SkyboxFt = true,
	SkyboxLf = true, SkyboxRt = true, SkyboxUp = true, SunTextureId = true,
	MoonTextureId = true,
}
-- numbers Roblox stores as <int>
local INT_PROPS = {
	ZIndex = true, TextSize = true, BorderSizePixel = true, DisplayOrder = true,
	LayoutOrder = true, NumberOfTilesU = true, NumberOfTilesV = true,
}
-- script source
local PROTECTED_PROPS = { Source = true }
-- NumberValue/IntValue need a double/int <Value>
local VALUE_NUMBER_TAG = { NumberValue = "double", IntValue = "int", IntConstrainedValue = "int" }

local PART_PROPS = {
	"Anchored", "CanCollide", "CanTouch", "CanQuery", "CastShadow", "Massless", "Locked",
	"Size", "CFrame", "Transparency", "Reflectance", "BrickColor", "Material",
	"TopSurface", "BottomSurface", "Shape", -- wrong-class props simply fail to read and are skipped
}
local MESHPART_PROPS = { "MeshId", "TextureID", "RenderFidelity", "DoubleSided", "CollisionFidelity" }
local SPECIALMESH_PROPS = { "MeshId", "TextureId", "MeshType", "Scale", "Offset", "VertexColor" }
local SCRIPT_PROPS = { "Source", "Disabled", "RunContext" }
local TOOL_PROPS = { "CanBeDropped", "RequiresHandle", "Enabled", "ToolTip", "TextureId", "Grip" }
local SOUND_PROPS = { "SoundId", "Volume", "Looped", "PlaybackSpeed", "RollOffMode", "PlayOnRemove", "EmitterSize", "TimePosition" }
local DECAL_PROPS = { "Texture", "Transparency", "Face", "Color3", "LocalTransparencyModifier" }
local LIGHT_PROPS = { "Brightness", "Color", "Range", "Enabled", "Shadows", "Angle", "Face" }
local GUI_PROPS = {
	"Size", "Position", "AnchorPoint", "Visible", "ZIndex", "BackgroundColor3",
	"BackgroundTransparency", "BorderSizePixel", "BorderColor3", "BorderMode",
	"ClipsDescendants", "LayoutOrder", "Rotation", "AutomaticSize", "Selectable",
}
local TEXT_PROPS = {
	"Text", "TextColor3", "TextTransparency", "TextSize", "TextScaled", "TextWrapped",
	"TextXAlignment", "TextYAlignment", "RichText", "Font", "FontFace",
	"PlaceholderText", "ClearTextOnFocus", "TextStrokeTransparency", "LineHeight",
}
local IMAGE_PROPS = { "Image", "ImageColor3", "ImageTransparency", "ScaleType", "TileSize", "ResampleMode" }
local LAYOUT_PROPS = {
	"Padding", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder",
	"CellSize", "CellPadding", "StartCorner", "FillDirectionMaxCells",
	"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight",
	"CornerRadius", "AspectRatio", "AspectType", "DominantAxis", "Scale",
	"MaxSize", "MinSize", "MaxTextSize", "MinTextSize",
	"Color", "Transparency", "Offset", "Enabled",
}
local ATTACH_PROPS = { "CFrame", "Position", "Visible", "Orientation", "Axis", "SecondaryAxis" }
local JOINT_PROPS = { "Part0", "Part1", "C0", "C1", "CurrentAngle", "DesiredAngle", "MaxVelocity" }
local LAYER_PROPS = { "Enabled", "ResetOnSpawn", "IgnoreGuiInset", "DisplayOrder", "ZIndexBehavior" }
local ADORN_PROPS = { "Adornee", "Size", "StudsOffset", "AlwaysOnTop", "LightInfluence", "MaxDistance", "Face", "Brightness", "ClipsDescendants" }

local propCache = {}
local function propsFor(inst)
	local className = inst.ClassName
	local cached = propCache[className]
	if cached then
		return cached
	end

	local list = { "Archivable" }
	local seen = {}
	local function add(props)
		for _, name in ipairs(props) do
			if not seen[name] then
				seen[name] = true
				list[#list + 1] = name
			end
		end
	end

	local function isA(class)
		local ok, result = pcall(function()
			return inst:IsA(class)
		end)
		return ok and result
	end

	if isA("BasePart") then
		add(PART_PROPS)
	end
	if isA("MeshPart") then
		add(MESHPART_PROPS)
	end
	if isA("SpecialMesh") or isA("BevelMesh") then
		add(SPECIALMESH_PROPS)
	end
	if isA("LuaSourceContainer") then
		add(SCRIPT_PROPS)
	end
	if isA("Tool") then
		add(TOOL_PROPS)
	end
	if isA("Sound") then
		add(SOUND_PROPS)
	end
	if isA("Decal") then
		add(DECAL_PROPS)
	end
	if isA("Light") then
		add(LIGHT_PROPS)
	end
	if isA("GuiObject") or isA("LayerCollector") then
		add(GUI_PROPS)
	end
	if isA("GuiObject") and (isA("TextLabel") or isA("TextButton") or isA("TextBox")) then
		add(TEXT_PROPS)
	end
	if isA("ImageLabel") or isA("ImageButton") then
		add(IMAGE_PROPS)
	end
	if isA("UILayout") or isA("UIConstraint") or isA("UIGradient") or isA("UIPadding")
		or isA("UICorner") or isA("UIScale") or isA("UIListLayout") or isA("UIGridLayout")
		or isA("UITableLayout") or isA("UIPageLayout") or isA("UIAspectRatioConstraint")
		or isA("UISizeConstraint") or isA("UITextSizeConstraint") or isA("UIGridStyleLayout")
	then
		add(LAYOUT_PROPS)
	end
	if isA("Attachment") then
		add(ATTACH_PROPS)
	end
	if isA("JointInstance") then
		add(JOINT_PROPS)
	end
	if isA("LayerCollector") then
		add(LAYER_PROPS)
	end
	if isA("BillboardGui") or isA("SurfaceGui") or isA("ScreenGui") then
		add(ADORN_PROPS)
	end
	if isA("ValueBase") then
		add({ "Value" })
	end
	if isA("Model") then
		add({ "PrimaryPart", "WorldPivotData" })
	end
	if isA("Humanoid") then
		add({ "RigType", "DisplayName", "Health", "MaxHealth", "WalkSpeed", "JumpPower", "AutoRotate", "DisplayDistanceType" })
	end
	if isA("Animation") then
		add({ "AnimationId", "Speed" })
	end

	propCache[className] = list
	return list
end

local function vector3XML(tag, v)
	return "<"
		.. tag
		.. ">"
		.. string.format("<X>%s</X><Y>%s</Y><Z>%s</Z>", fmtNum(v.X), fmtNum(v.Y), fmtNum(v.Z))
		.. "</"
		.. tag
		.. ">"
end

-- returns the XML tag for one property, or nil when the type cannot be written
local function propToXML(inst, name, value, refOf)
	local valueType = typeof(value)

	if valueType == "string" then
		if PROTECTED_PROPS[name] then
			return '<ProtectedString name="' .. name .. '">' .. xmlEscape(value) .. "</ProtectedString>"
		end
		if CONTENT_PROPS[name] then
			return '<Content name="' .. name .. '">' .. xmlEscape(value) .. "</Content>"
		end
		return '<string name="' .. name .. '">' .. xmlEscape(value) .. "</string>"
	elseif valueType == "boolean" then
		return '<bool name="' .. name .. '">' .. (value and "true" or "false") .. "</bool>"
	elseif valueType == "number" then
		local tagName = INT_PROPS[name] and "int" or "float"
		if name == "Value" and VALUE_NUMBER_TAG[inst.ClassName] then
			tagName = VALUE_NUMBER_TAG[inst.ClassName]
		end
		return "<" .. tagName .. ' name="' .. name .. '">' .. fmtNum(value) .. "</" .. tagName .. ">"
	elseif valueType == "EnumItem" then
		return '<token name="' .. name .. '">' .. tostring(value.Value) .. "</token>"
	elseif valueType == "Vector3" then
		return '<Vector3 name="' .. name .. '">'
			.. string.format("<X>%s</X><Y>%s</Y><Z>%s</Z>", fmtNum(value.X), fmtNum(value.Y), fmtNum(value.Z))
			.. "</Vector3>"
	elseif valueType == "Vector2" then
		return '<Vector2 name="' .. name .. '">'
			.. string.format("<X>%s</X><Y>%s</Y>", fmtNum(value.X), fmtNum(value.Y))
			.. "</Vector2>"
	elseif valueType == "CFrame" then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
		return '<CoordinateFrame name="' .. name .. '">'
			.. string.format(
				"<X>%s</X><Y>%s</Y><Z>%s</Z><R00>%s</R00><R01>%s</R01><R02>%s</R02><R10>%s</R10><R11>%s</R11><R12>%s</R12><R20>%s</R20><R21>%s</R21><R22>%s</R22>",
				fmtNum(x), fmtNum(y), fmtNum(z), fmtNum(r00), fmtNum(r01), fmtNum(r02),
				fmtNum(r10), fmtNum(r11), fmtNum(r12), fmtNum(r20), fmtNum(r21), fmtNum(r22)
			)
			.. "</CoordinateFrame>"
	elseif valueType == "Color3" then
		return '<Color3 name="' .. name .. '">'
			.. string.format("<R>%s</R><G>%s</G><B>%s</B>", fmtNum(value.R), fmtNum(value.G), fmtNum(value.B))
			.. "</Color3>"
	elseif valueType == "BrickColor" then
		return '<BrickColor name="' .. name .. '">' .. tostring(value.Number) .. "</BrickColor>"
	elseif valueType == "UDim" then
		return '<UDim name="' .. name .. '">'
			.. string.format("<S>%s</S><O>%s</O>", fmtNum(value.Scale), fmtNum(value.Offset))
			.. "</UDim>"
	elseif valueType == "UDim2" then
		return '<UDim2 name="' .. name .. '">'
			.. string.format(
				"<XS>%s</XS><XO>%s</XO><YS>%s</YS><YO>%s</YO>",
				fmtNum(value.X.Scale), fmtNum(value.X.Offset), fmtNum(value.Y.Scale), fmtNum(value.Y.Offset)
			)
			.. "</UDim2>"
	elseif valueType == "NumberRange" then
		return '<NumberRange name="' .. name .. '">'
			.. string.format("<Min>%s</Min><Max>%s</Max>", fmtNum(value.Min), fmtNum(value.Max))
			.. "</NumberRange>"
	elseif valueType == "NumberSequence" then
		local parts = { '<NumberSequence name="' .. name .. '"><K>' .. #value.Keypoints .. "</K>" }
		for _, keypoint in ipairs(value.Keypoints) do
			parts[#parts + 1] = string.format(
				"<NumberSequenceKeypoint><envelope>%s</envelope><time>%s</time><value>%s</value></NumberSequenceKeypoint>",
				fmtNum(keypoint.Envelope), fmtNum(keypoint.Time), fmtNum(keypoint.Value)
			)
		end
		parts[#parts + 1] = "</NumberSequence>"
		return table.concat(parts)
	elseif valueType == "ColorSequence" then
		local parts = { '<ColorSequence name="' .. name .. '"><K>' .. #value.Keypoints .. "</K>" }
		for _, keypoint in ipairs(value.Keypoints) do
			parts[#parts + 1] = string.format(
				"<ColorSequenceKeypoint><time>%s</time><value><R>%s</R><G>%s</G><B>%s</B></value></ColorSequenceKeypoint>",
				fmtNum(keypoint.Time), fmtNum(keypoint.Value.R), fmtNum(keypoint.Value.G), fmtNum(keypoint.Value.B)
			)
		end
		parts[#parts + 1] = "</ColorSequence>"
		return table.concat(parts)
	elseif valueType == "Rect" then
		return '<Rect name="' .. name .. '">'
			.. string.format(
				"<min><X>%s</X><Y>%s</Y></min><max><X>%s</X><Y>%s</Y></max>",
				fmtNum(value.Min.X), fmtNum(value.Min.Y), fmtNum(value.Max.X), fmtNum(value.Max.Y)
			)
			.. "</Rect>"
	elseif valueType == "Instance" then
		local referent = refOf[value]
		if not referent then
			return nil
		end
		return '<Ref name="' .. name .. '">' .. referent .. "</Ref>"
	elseif valueType == "Faces" then
		return '<Faces name="' .. name .. '">'
			.. string.format(
				"<Top>%s</Top><Bottom>%s</Bottom><Left>%s</Left><Right>%s</Right><Front>%s</Front><Back>%s</Back>",
				tostring(value.Top), tostring(value.Bottom), tostring(value.Left),
				tostring(value.Right), tostring(value.Front), tostring(value.Back)
			)
			.. "</Faces>"
	elseif valueType == "Axes" then
		return '<Axes name="' .. name .. '">'
			.. string.format("<X>%s</X><Y>%s</Y><Z>%s</Z>", tostring(value.X), tostring(value.Y), tostring(value.Z))
			.. "</Axes>"
	end

	return nil
end

-- root -> XML text, streamed through sink(chunkString)
-- returns stats = { instances, props, skippedProps, skippedClasses }
local function serializeInstanceTree(root, sink, options)
	options = options or {}
	local chunkSize = options.chunkSize or 65536
	local maxDepth = options.maxDepth or 600

	local refOf = {}
	local counter = 0
	local skippedProps = 0
	local propCount = 0
	local skippedClasses = {}

	-- pass 1: stable referents for the whole tree
	do
		local stack = { root }
		local seen = {}
		while #stack > 0 do
			local inst = table.remove(stack)
			if not seen[inst] then
				seen[inst] = true
				refOf[inst] = "RBX" .. counter
				counter = counter + 1
				local kids = inst:GetChildren()
				for i = #kids, 1, -1 do
					stack[#stack + 1] = kids[i]
				end
			end
		end
	end

	local buffer, bufferLength = {}, 0
	local function flush()
		if bufferLength > 0 then
			sink(table.concat(buffer))
			buffer, bufferLength = {}, 0
		end
	end
	local function write(text)
		buffer[#buffer + 1] = text
		bufferLength = bufferLength + #text
		if bufferLength >= chunkSize then
			flush()
		end
	end

	local emit
	emit = function(inst, depth)
		if depth > maxDepth then
			return
		end
		write('<Item class="' .. xmlEscape(inst.ClassName) .. '" referent="' .. refOf[inst] .. '"><Properties>')
		write('<string name="Name">' .. xmlEscape(inst.Name) .. "</string>")

		local props = propsFor(inst)
		local recognised = false
		for _, name in ipairs(props) do
			local ok, value = pcall(function()
				return inst[name]
			end)
			if ok and value ~= nil then
				local tag = propToXML(inst, name, value, refOf)
				if tag then
					propCount = propCount + 1
					recognised = true
					write(tag)
				else
					skippedProps = skippedProps + 1
				end
			end
		end
		if not recognised and #props == 1 then
			local className = inst.ClassName
			skippedClasses[className] = (skippedClasses[className] or 0) + 1
		end

		write("</Properties>")
		local kids = inst:GetChildren()
		for _, kid in ipairs(kids) do
			emit(kid, depth + 1)
		end
		write("</Item>")
	end

	write(XML_HEADER)
	emit(root, 0)
	write("</roblox>")
	flush()

	return {
		instances = counter,
		props = propCount,
		skippedProps = skippedProps,
		skippedClasses = skippedClasses,
	}
end
-- <<< DEXDUMP SERIALIZER END

-- ======================================================================
--              TREE DESCRIPTION (class + name only, for the Explorer)
-- ======================================================================
-- The .rbxmx export contains every property. This is the lightweight version:
-- just the structure, so Dex can rebuild it locally and you can click through it.
local function buildTreeDescription(inst, depth, maxDepth, counter)
	counter[1] = counter[1] + 1
	local node = { c = inst.ClassName, n = inst.Name }
	if depth < maxDepth then
		local kids = inst:GetChildren()
		if #kids > 0 then
			local list = {}
			for _, child in ipairs(kids) do
				list[#list + 1] = buildTreeDescription(child, depth + 1, maxDepth, counter)
			end
			node.k = list
		end
	end
	return node
end

-- character-level robustness: replace bytes that JSON encoders choke on
local function sanitizeString(text)
	return (tostring(text):gsub("[%z\1-\8\11\12\14-\31\127]", "?"))
end

local function sanitizeTree(node)
	node.n = sanitizeString(node.n)
	if node.k then
		for _, child in ipairs(node.k) do
			sanitizeTree(child)
		end
	end
	return node
end

-- ======================================================================
--                          SERVER PLUMBING
-- ======================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function allowlistReady()
	return #ALLOWED_USER_IDS > 0
end

local function isAllowed(player)
	if not allowlistReady() then
		return true
	end
	for _, id in ipairs(ALLOWED_USER_IDS) do
		if player.UserId == id then
			return true
		end
	end
	return false
end

local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if remote and not remote:IsA("RemoteEvent") then
	remote:Destroy()
	remote = nil
end
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = REMOTE_NAME
	remote.Parent = ReplicatedStorage
end

local busy = false

remote.OnServerEvent:Connect(function(player, action, targetName)
	if action ~= "request" and action ~= "requesttree" then
		return
	end
	local isTree = (action == "requesttree")
	if not isAllowed(player) then
		remote:FireClient(player, "denied", targetName, "this dump is locked to its owner")
		warn("[DexDump] denied " .. player.Name .. " (" .. player.UserId .. ")")
		return
	end
	if busy then
		remote:FireClient(player, "busy", targetName, "another dump is running")
		return
	end

	local service
	for _, name in ipairs(TARGETS) do
		if name == targetName then
			local ok, found = pcall(function()
				return game:GetService(name)
			end)
			if ok then
				service = found
			end
		end
	end
	if not service then
		remote:FireClient(player, "error", targetName, "unknown target " .. tostring(targetName))
		return
	end

	busy = true
	print("[DexDump] " .. player.Name .. " requested " .. targetName .. (isTree and " (tree)" or "") .. " ...")

	-- lightweight structure-only stream for the in-Dex Explorer view
	if isTree then
		task.spawn(function()
			remote:FireClient(player, "treeBegin", targetName)
			task.wait()

			local counter = { 0 }
			local okBuild, description = pcall(function()
				local tree = buildTreeDescription(service, 0, 200, counter)
				return sanitizeTree(tree)
			end)
			if not okBuild then
				busy = false
				warn("[DexDump] tree build failed: " .. tostring(description))
				remote:FireClient(player, "error", targetName, tostring(description))
				return
			end

			local okJson, json = pcall(function()
				return game:GetService("HttpService"):JSONEncode(description)
			end)
			if not okJson then
				busy = false
				warn("[DexDump] tree encode failed: " .. tostring(json))
				remote:FireClient(player, "error", targetName, tostring(json))
				return
			end

			local offset, length = 1, #json
			while offset <= length do
				local chunk = string.sub(json, offset, offset + CHUNK_SIZE - 1)
				remote:FireClient(player, "treeChunk", targetName, chunk)
				offset = offset + CHUNK_SIZE
				task.wait()
			end

			busy = false
			remote:FireClient(player, "treeDone", targetName, counter[1])
			print(string.format("[DexDump] %s tree sent: %d instances, %.1f KB", targetName, counter[1], length / 1024))
		end)
		return
	end

	task.spawn(function()
		remote:FireClient(player, "begin", targetName)
		task.wait()

		local function pump(chunk)
			remote:FireClient(player, "chunk", targetName, chunk)
			task.wait()
		end

		local ok, stats = pcall(serializeInstanceTree, service, pump, { chunkSize = CHUNK_SIZE })
		busy = false

		if not ok then
			warn("[DexDump] serialize failed: " .. tostring(stats))
			remote:FireClient(player, "error", targetName, tostring(stats))
			return
		end

		remote:FireClient(player, "done", targetName, stats.instances, stats.props, stats.skippedProps)
		print(string.format(
			"[DexDump] %s sent: %d instances, %d properties (%d unsupported values skipped)",
			targetName, stats.instances, stats.props, stats.skippedProps
		))
	end)
end)

print("[DexDump] server half ready  |  targets: " .. table.concat(TARGETS, ", "))
if not allowlistReady() then
	warn("[DexDump] ALLOWED_USER_IDS is EMPTY -> any player can request the dump. Fill in your UserId.")
end
