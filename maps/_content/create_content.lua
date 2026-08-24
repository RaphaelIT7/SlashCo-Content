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

local content_list = {}
function RecursiveAdd(tbl)
	for _, path in pairs(tbl) do
		if type(path) == "table" then
			RecursiveAdd(path)
		else
			table.insert(content_list, path)
		end
	end
end

function MaterialContent(path)
	table.insert(content_list, path)

	local tbl = parseVMT(ReadFile(path))
	local res = getVMTRessources(tbl)
	RecursiveAdd(res)
end

local function AddContent(path)
	if FileExists(path) then
		table.insert(content_list, path)
	else
		print("Invalid path! (" .. path .. ")")
	end
end

local vmfFile = ({...})[1]
local vmfFilePath = "../" .. vmfFile .. "/" .. vmfFile
local vmfMaterials, vmfModels = readVMF(vmfFilePath .. ".vmf")
LoadAdditionalContentFile(vmfFilePath .. ".lua", vmfMaterials, vmfModels)


local entProcessFuncs = {
	["ambient_generic"] = function(ent)
		AddContent("sound/" .. ent.message)
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
			AddContent(soundPath)
		end
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
			table.insert(content_list, path)
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
for _, path in pairs(content_list) do
	path = SafePath(path)
	print(path)
	CopyFile(path, (({...})[2] or "__content_map/") .. GetPathWithoutFirst(path))
end