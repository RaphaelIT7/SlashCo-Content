require("utils")

function BuildPaths()
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

CreateDir("__content_map")

local no_extension = {
	[".vtf"] = true,
	[".vmt"] = true
}
function getVMTRessources(vmt_tbl)
	local tbl = {}
	for k, v in pairs(vmt_tbl) do
		if type(v) == "table" then
			tbl[k] = getVMTRessources(v)
		else
			local n = tonumber(v)
			if not n and not v:match('%[([^*]+)%]') and not (k == "$surfaceprop") then
				if no_extension[v:sub(v:len() - 3)] then
					v = v:sub(0, v:len() - 4)
				end

				if not (v == "env_cubemap") then
					local path = FindFileInList("materials/" .. SafePath(v:lower()) .. ".vmt")
					if path then
						tbl[v] = path
					end

					local path = FindFileInList("materials/" .. SafePath(v:lower()) .. ".vtf") -- Smack both vtf and vmt in there :D
					if path then
						tbl[v] = path
					end

					if not path then
						print("Failed to find: " .. v .. " (" .. SafePath(v:lower()) .. ")")
					end
				end
			end
		end
	end

	return tbl
end

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
local vmfFilePath = "../" .. vmfFile .. "/" .. vmfFile .. ".vmf"
local vmfMaterials, vmfModels = readVMF(vmfFilePath)
LoadAdditionalContentFile("../" .. vmfFile .. "/" .. vmfFile .. ".lua", vmfMaterials, vmfModels)

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
		    				print("[Path] Failed to find " .. name .. " for " .. model .. " (" .. "materials/" .. path .. name .. ".vmt" .. ")")
		    			end
		    		end
	    		end
	    	end

	    	for k, v in pairs(mdl.textures) do
	    		if not found[v.name] then
	    			print("Failed to find " .. v.name .. " for " .. model)
	    		end
	    	end

	    	print(model)
	    end
    end
end

print("\nContent:")
for _, path in pairs(content_list) do
	path = SafePath(path)
	print(path)
	CopyFile(path, "__content_map/" .. GetPathWithoutFirst(path))
end