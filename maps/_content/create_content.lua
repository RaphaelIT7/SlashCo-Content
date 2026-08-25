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

local contentList = {}
function RecursiveAdd(tbl)
	for _, path in pairs(tbl) do
		if type(path) == "table" then
			RecursiveAdd(path)
		else
			contentList[path] = true
			table.insert(contentList, path)
		end
	end
end

function MaterialContent(path)
	contentList[path] = true
	table.insert(contentList, path)

	local tbl = parseVMT(ReadFile(path))
	local res = getVMTRessources(tbl)
	RecursiveAdd(res)
end

local function AddContent(path)
	if not contentList[path] and FileExists(path) then
		contentList[path] = true
		table.insert(contentList, path)
	else
		print("Invalid path! (" .. path .. ")")
	end
end

local function FindSoundScape()
	local fullPath = FindFile("scripts/soundscapes_" .. vmfFile .. ".txt")
	if fullPath then
		AddContent(fullPath)
	end
end

FindSoundScape()

local function AddSingleFile(fileName)
	if not fileName then return end

	local fullPath = FindFile(SafePath(fileName))
	if fullPath then
		AddContent(fullPath)
	end
end

local entProcessFuncs = {
	["ambient_generic"] = function(ent)
		local soundPath = SafePath(ent.message)
		if soundPath:sub(1, 6) ~= "sound/" then
			soundPath = "sound/" .. soundPath
		end

		AddSingleFile(soundPath)
	end,
	["sc_audio_playsound"] = function(ent)
		local soundPath = SafePath(ent.soundPath)
		if soundPath:sub(1, 6) ~= "sound/" then
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
		AddSingleFile(ent.model)
	end,
	["prop_static"] = function(ent)
		AddSingleFile(ent.model)
	end,
	["prop_dynamic"] = function(ent)
		AddSingleFile(ent.model)
	end,
	["prop_dynamic_override"] = function(ent)
		AddSingleFile(ent.model)
	end,
	["prop_door_rotating"] = function(ent)
		AddSingleFile(ent.model)
	end,
	["prop_ragdoll"] = function(ent)
		AddSingleFile(ent.model)
	end,
	["env_sprite"] = function(ent)
		AddSingleFile(ent.model)
	end,
	["info_overlay"] = function(ent)
		AddSingleFile(ent.material)
	end,
	["infodecal"] = function(ent)
		AddSingleFile(ent.texture)
	end,
	["move_rope"] = function(ent)
		AddSingleFile(ent.RopeMaterial)
	end,
	["env_sun"] = function(ent)
		AddSingleFile(ent.material)
		AddSingleFile(ent.overlaymaterial)
	end,
}

local function LoadMapContents()
	local vmf, err = parseVMF(ReadFile(vmfFilePath .. ".vmf"))
	if not vmf then
		error(err)
		return
	end

	for idx, ent in ipairs(vmf.entity) do
		print(idx, ent, ent.classname)
		local entFunc = entProcessFuncs[ent.classname]
		if entFunc then
			entFunc(ent)
		end
	end
end

LoadMapContents()

if false then return end

local vmfMaterials, vmfModels = readVMF(vmfFilePath .. ".vmf")
LoadAdditionalContentFile(vmfFilePath .. ".lua", vmfMaterials, vmfModels)

if not vmfMaterials then
	error("::error:: No map!")
end

print("Materials:")
for _, material in ipairs(vmfMaterials) do
	local path = FindFileInList("materials/" .. material:lower() .. ".vmt")
	if path then
		print(material)
		MaterialContent(path)
	else
		print("Failed to find " .. material:lower())
	end
end

print("\nModels:")
for _, model in ipairs(vmfModels) do
	local path = FindFile(model:lower())
	if path then
		if path:sub(path:len() - 3) == ".vmt" then
			MaterialContent(path:lower())
		else
			local filename = path:sub(0, path:len() - 4)
			contentList[path] = true
			table.insert(contentList, path)
			--AddContent(filename .. ".dx80.vtx")
			AddContent(filename .. ".dx90.vtx")
			AddContent(filename .. ".phy")
			--AddContent(filename .. ".sw.vtx")
			AddContent(filename .. ".vvd")

			local found = {}
			local mdl = parseMDL(path)
			if mdl then
				for _, path in pairs(mdl.texturedirs) do
					path = SafePath(path)
					for _, file in pairs(mdl.textures) do
						local name = SafePath(file.name)
						if not found[name] then
							local file_path = FindFileInList("materials/" .. path .. name .. ".vmt")
							if not file_path then
								file_path = FindFileInList(("materials/" .. path .. name .. ".vmt"):lower())
							end

							if not file_path then
								file_path = FindFileInList(("materials/" .. name .. ".vmt"):lower())
							end

							if file_path then
								found[name] = true
								MaterialContent(file_path)
							end

							if not found[name] then
								print("::warning:: [Path] Failed to find " .. name .. " for " .. model .. " (" .. "materials/" .. path .. name .. ".vmt" .. ")")
							end
						end
					end
				end

				for k, v in pairs(mdl.textures) do
					if not found[v.name] then
						print("::warning:: Failed to find \"" .. v.name .. "\" for \"" .. model .. "\"")
					end
				end
			end

			print("\"" .. model .. "\" - " ..  (mdl and "Valid" or "Invalid"))
		end
	end
end

print("\nContent:")
for _, path in ipairs(contentList) do
	path = SafePath(path)
	print(path)
	CopyFile(path, (({...})[2] or "__content_map/") .. GetPathWithoutFirst(path))
end