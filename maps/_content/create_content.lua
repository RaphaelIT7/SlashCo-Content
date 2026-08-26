require("utils")

function BuildPaths() -- Expose this for BuildFileList to call initially.
	local paths = {}
	local files = ScanDir("../_content")
	for k, folder in pairs(files) do
		if not IsFile(folder) then
			table.insert(paths, folder)
		end
	end

	return paths
end

BuildFileList()

CreateDir(({...})[2] or "__content_map")

local vmfFile = ({...})[1]
local vmfFilePath = "../" .. vmfFile .. "/" .. vmfFile

local function LoadGModContentList()
	local gmodList = {}
	local file = io.open("gmod_content.txt", "r")
	for line in file:lines() do
		gmodList[NormalizePath(line)] = true
	end
	file:close()

	return gmodList
end

gmodContent = LoadGModContentList()

local function LoadGModSoundScriptList()
	local gmodList = {}
	local file = io.open("gmod_soundscripts.txt", "r")
	for line in file:lines() do
		gmodList[line] = true
	end
	file:close()

	return gmodList
end

gmodSoundScripts = LoadGModSoundScriptList()

local contentList = {}
function RecursiveMaterialAdd(tbl)
	for _, path in pairs(tbl) do
		if type(path) == "table" then
			RecursiveMaterialAdd(path)
		else
			AddMaterialFile(NormalizePath(path), true)
		end
	end
end

function AddMaterial(path)
	AddContent(path)

	if gmodContent and gmodContent[path] then return end

	local contents = ReadFile(path)
	if contents then
		local vmt = parseKV(contents)
		local res = getVMTRessources(vmt)
		RecursiveMaterialAdd(res)
	end
end

function AddContent(path)
	if not path then return false end

	if not contentList[path] then
		contentList[path] = true
		table.insert(contentList, path)
		return true
	end

	return false
end

local function FindSoundScape()
	local fullPath = NormalizePath("scripts/soundscapes_" .. vmfFile .. ".txt")
	if FileExists(fullPath) then
		AddContent()
	end
end

local function BuildPath(fileName, rootDir)
	fileName = NormalizePath(fileName)
	if rootDir and not StartsWith(fileName, rootDir) then
		fileName = NormalizePath(rootDir .. fileName)
	end

	return fileName
end

local function AddSingleFile(fileName, rootDir)
	if not fileName then return false end

	fileName = BuildPath(fileName, rootDir)
	if AddContent(fileName) then
		return fileName
	end

	return nil
end

local function AddSoundFile(fileName)
	-- Skip sound scripts
	if gmodSoundScripts[fileName] then return end

	AddSingleFile(fileName, "sound/")
end

local function AddModelFile(fileName)
	-- Does NOT exist!
	if fileName and EndsWith(fileName, ".spr") then return end

	fileName = AddSingleFile(fileName, "models/")
	if not fileName then return end

	if not EndsWith(fileName, ".mdl") then return end
	if gmodContent[fileName] then return end

	local modelPath = fileName:sub(1, -5)
	AddSingleFile(modelPath .. ".dx90.vtx")
	AddSingleFile(modelPath .. ".phy")
	AddSingleFile(modelPath .. ".vvd")

	local mdl = parseMDL(fileName)
	if not mdl then
		print("::warning:: Failed to parse model \"" .. fileName .. "\"")
		return
	end

	local foundMaterials = {}
	for _, textureDirectory in ipairs(mdl.texturedirs or {}) do
		textureDirectory = NormalizePath(textureDirectory)

		for _, texture in ipairs(mdl.textures or {}) do
			local textureName = NormalizePath(texture.name or "")
			if textureName ~= "" and not foundMaterials[textureName] then
				local candidates = {
					"materials/" .. textureDirectory .. textureName .. ".vmt",
					"materials/" .. textureName .. ".vmt"
				}

				for _, candidate in ipairs(candidates) do
					if FileExistsInList(candidate) then
						foundMaterials[textureName] = true
						AddMaterialFile(candidate)
						break
					end
				end

				if not foundMaterials[textureName] then
					print("::warning:: Failed to find material \"" .. textureName .. "\" for model \"" .. fileName .."\"")
				end
			end
		end
	end
end

local function AddVMTFile(fileName)
	fileName = AddSingleFile(fileName, "materials/")
	if fileName then
		AddMaterial(fileName)
	end
end

local function AddVTFFile(fileName)
	AddSingleFile(fileName, "materials/")
end

function AddMaterialFile(fileName, callingVMT)
	if not fileName then return end
	if fileName == "env_cubemap" then return end

	if EndsWith(fileName, ".vtf") then
		AddVTFFile(fileName)
		return
	end

	if EndsWith(fileName, ".vmt") then
		AddVMTFile(fileName)
		return
	end

	if EndsWith(fileName, ".spr") then
		-- Strip .spr as it isn't a valid format!
		fileName = fileName:sub(0, -5)
	end

	-- vmt takes priority and some materials have a vmt that loads vtfs with other names
	-- So either the vmt added the vtf or no vmt existed and then we expect a vtf to exist
	fileName = BuildPath(fileName, "materials/")
	if not callingVMT then
		if not FileExistsInList(fileName .. ".vmt") then
			AddVTFFile(fileName .. ".vtf")
		else
			AddVMTFile(fileName .. ".vmt")
		end
	else
		-- I don't think a vmt can include another vmt?
		AddVTFFile(fileName .. ".vtf")
	end
end

local entProcessFuncs = {
	["ambient_generic"] = function(ent)
		AddSoundFile(ent.message)
	end,
	["sc_audio_playsound"] = function(ent)
		local soundPath = NormalizePath(ent.soundPath)
		if not StartsWith(soundPath, "sound/") then
			soundPath = "sound/" .. soundPath
		end

		if soundPath:find("*") then
			for _, filePath in ipairs(FindFiles(soundPath)) do
				AddContent(filePath)
			end
		else
			AddSingleFile(soundPath)
		end
	end,
	["prop_physics"] = function(ent)
		AddModelFile(ent.model)
	end,
	["prop_static"] = function(ent)
		AddModelFile(ent.model)
	end,
	["prop_dynamic"] = function(ent)
		AddModelFile(ent.model)
	end,
	["prop_dynamic_override"] = function(ent)
		AddModelFile(ent.model)
	end,
	["prop_door_rotating"] = function(ent)
		AddModelFile(ent.model)
	end,
	["prop_ragdoll"] = function(ent)
		AddModelFile(ent.model)
	end,
	["env_sprite"] = function(ent)
		AddModelFile(ent.model)
	end,
	["info_overlay"] = function(ent)
		AddMaterialFile(ent.material)
	end,
	["infodecal"] = function(ent)
		AddMaterialFile(ent.texture)
	end,
	["env_beam"] = function(ent)
		AddMaterialFile(ent.texture)
	end,
	["move_rope"] = function(ent)
		AddMaterialFile(ent.RopeMaterial)
	end,
	["env_sun"] = function(ent)
		AddMaterialFile(ent.material)
		AddMaterialFile(ent.overlaymaterial)
	end,
	["env_smokestack"] = function(ent)
		AddMaterialFile(ent.SmokeMaterial)
	end,
	["func_button"] = function(ent)
		AddMaterialFile(ent.SmokeMaterial)
	end,
}

local function AddSolid(geo)
	if not geo then return end

	for _, side in ipairs(geo.side or {}) do
		AddMaterialFile(side.material)
	end
end

local function GuessContent(ent)
	-- AddSingleFile has a nil check
	AddMaterialFile(ent.material)
	AddMaterialFile(ent.texture)
	AddMaterialFile(ent.texturename) -- env_projectedtexture
	AddModelFile(ent.model)
	AddModelFile(ent.shootmodel)
	AddMaterialFile(ent.overlaymaterial)
	AddMaterialFile(ent.RopeMaterial)
	AddMaterialFile(ent.SmokeMaterial)
	AddSolid(ent.solid) -- func_brush can have them as a example
end

local function ParseEntities(vmf)
	for idx, ent in ipairs(vmf.entity) do
		print(idx, ent, ent.classname)
		local entFunc = entProcessFuncs[ent.classname]
		if entFunc then
			entFunc(ent)
		else
			GuessContent(ent)
		end
	end
end

local skyboxSides = {
	"bk",
	"dn",
	"ft",
	"lf",
	"rt",
	"up",

	"bbk",
	"bdn",
	"bft",
	"blf",
	"brt",
	"bup",

	"cbk",
	"cdn",
	"cft",
	"clf",
	"crt",
	"cup",

	"hdrbk",
	"hdrdn",
	"hdrft",
	"hdrlf",
	"hdrrt",
	"hdrup",

	"bhdrbk",
	"bhdrdn",
	"bhdrft",
	"bhdrlf",
	"bhdrrt",
	"bhdrup",
}

local function AddSkyBox(fileName)
	if not fileName then return end

	local foundAny = false
	fileName = NormalizePath("materials/skybox/" .. fileName)
	for _, option in ipairs(skyboxSides) do
		local vmtPath = NormalizePath(fileName .. option .. ".vmt")
		if FileExistsInList(vmtPath) then
			AddVMTFile(vmtPath)
			foundAny = true
		else
			local vtfPath = NormalizePath(fileName .. option .. ".vtf")
			if FileExistsInList(vtfPath) then
				AddVMTFile(vtfPath)
				foundAny = true
			end
		end
	end

	if not foundAny then
		print("::warning:: Failed to find skybox \"" .. fileName .. "\"")
	end
end

local function ParseWorld(vmf)
	AddSkyBox(vmf.world.skyname)

	for _, solid in ipairs(vmf.world.solid) do
		AddSolid(solid)
	end

	--PrintTable(vmf.world)
end

local vmf, err = parseKV(ReadFile(vmfFilePath .. ".vmf"))
if not vmf then
	error(err)
	return
end

FindSoundScape()
ParseEntities(vmf)
ParseWorld(vmf)

--PrintTable(contentList)

local function CleanContentList()
	local gmodList = LoadGModContentList()

	local idx = 0
	while idx <= #contentList do
		local filePath = contentList[idx]
		if gmodList[filePath] then
			table.remove(contentList, idx)
			contentList[filePath] = nil
			print("Removing GMod file from content list \"" .. filePath .. "\"")
		else
			idx = idx + 1
		end
	end
end

CleanContentList()

print("\nContent:")
for _, path in ipairs(contentList) do
	print(path)
	local fullPath = GetFileFromList(path) or path
	if not CopyFile(fullPath, (({...})[2] or "__content_map/") .. GetPathWithoutFirst(fullPath)) then
		print("::warning:: Missing content file \"" .. path .. "\"")
	end
end