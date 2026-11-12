--[[
	Bac à sable Lune : exécute les ModuleScripts de src/ hors de Roblox Studio.
	- injecte les types Roblox (Vector3, CFrame, Instance, Enum...) fournis par @lune/roblox ;
	- émule `script` (script.Parent.Kit, script.Creatures:GetChildren()...) à partir du système de fichiers ;
	- émule `require(<ModuleScript>)`.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Sandbox = {}

local GLOBAL_NAMES = {
	"Axes", "BrickColor", "CFrame", "Color3", "ColorSequence", "ColorSequenceKeypoint", "Enum", "Faces",
	"Font", "Instance", "NumberRange", "NumberSequence", "NumberSequenceKeypoint", "PhysicalProperties",
	"Ray", "Rect", "Region3", "UDim", "UDim2", "Vector2", "Vector3",
}

local workspaceStub = roblox.Instance.new("Model")
workspaceStub.Name = "Workspace"
Sandbox.workspace = workspaceStub

-- Remplaçant déterministe de Random (absent de @lune/roblox)
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed: number?)
	local s = math.floor((seed or os.clock() * 1e6) * 1000) % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return setmetatable({ s = s }, RandomShim)
end
function RandomShim:NextNumber(min: number?, max: number?): number
	self.s = (self.s * 48271) % 2147483647
	local f = self.s / 2147483647
	local lo, hi = min or 0, max or 1
	return lo + (hi - lo) * f
end
function RandomShim:NextInteger(min: number, max: number): number
	return math.floor(self:NextNumber(min, max + 1))
end
Sandbox.Random = RandomShim

local cache: { [string]: any } = {}

local nodeMeta = {}

local function node(path: string)
	return setmetatable({ __path = path }, nodeMeta)
end

local function dirname(path: string): string
	return string.match(path, "^(.*)/[^/]+$") or "."
end

local function basename(path: string): string
	return string.match(path, "([^/]+)$") or path
end

local function moduleFile(path: string): string?
	if fs.isFile(path .. ".luau") then
		return path .. ".luau"
	elseif fs.isDir(path) and fs.isFile(path .. "/init.luau") then
		return path .. "/init.luau"
	end
	return nil
end

nodeMeta.__index = function(self, key)
	local path = rawget(self, "__path")
	if key == "Parent" then
		return node(dirname(path))
	elseif key == "Name" then
		return basename(path)
	elseif key == "ClassName" then
		return if moduleFile(path) then "ModuleScript" else "Folder"
	elseif key == "IsA" then
		return function(_, cls)
			return cls == "ModuleScript" and moduleFile(path) ~= nil
		end
	elseif key == "GetChildren" then
		return function()
			local out = {}
			if fs.isDir(path) then
				local names = fs.readDir(path)
				table.sort(names)
				for _, n in names do
					if n ~= "init.luau" then
						local name = string.gsub(n, "%.luau$", "")
						table.insert(out, node(path .. "/" .. name))
					end
				end
			end
			return out
		end
	elseif key == "FindFirstChild" then
		return function(_, name)
			local p = path .. "/" .. name
			return if moduleFile(p) or fs.isDir(p) then node(p) else nil
		end
	elseif key == "WaitForChild" then
		return function(_, name)
			return node(path .. "/" .. name)
		end
	end
	return node(path .. "/" .. key)
end

local function makeEnv(scriptNode)
	local env = {
		script = scriptNode,
		workspace = workspaceStub,
		typeof = typeof,
		warn = function(...)
			print("[warn]", ...)
		end,
		task = require("@lune/task"),
		Random = RandomShim,
		-- Services factices : seules les fonctions de construction sont exécutées hors de Studio
		game = {
			GetService = function(_, name)
				return { Name = name }
			end,
		},
	}
	for _, name in GLOBAL_NAMES do
		env[name] = (roblox :: any)[name]
	end
	env.require = function(target)
		if type(target) == "table" and rawget(target, "__path") then
			return Sandbox.load(rawget(target, "__path"))
		end
		return require(target)
	end
	return setmetatable(env, { __index = _G })
end

--- Charge le module situé à `path` (sans extension, ou dossier contenant init.luau).
function Sandbox.load(path: string): any
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = moduleFile(path)
	assert(file, "Module introuvable : " .. path)
	local fn = luau.load(fs.readFile(file), {
		debugName = file,
		environment = makeEnv(node(path)),
	})
	local result = fn()
	cache[path] = result
	return result
end

return Sandbox
