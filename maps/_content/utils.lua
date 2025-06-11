--[[
	This file exposes these functions:
	bool IsFile(file)
	String SafePath(path) 
		Replaces \ with /
	String GetPath(path) 
		Example: somefolder/anotherfolder/file.txt -> somefolder/anotherfolder/
	String GetPathWithoutFirst(path) 
		Example: somefolder/anotherfolder/file.txt -> somefolder/
	Table ScanDir(path, recursive)
		Returns a table with all files in a folder. Set recursive(untested) if it should also get subfolders.
	nil CreateDir(path)
	String ReadFile(file)
	nil WriteFile(file, content)
	nil CopyFile(from, to)
	String RemoveSpaces(input)
	String string.Replace(string, replace, new)
	bool FileExists(file)

	table BuildPaths() 
		Called when the Searchpaths should be created!
		You can override this to return your own searchpaths (use table.insert)
	String FindFile(file)
		Searches in all Searchpaths for a given file and returns if found the path

	table parseMDL(file)
		Returns the contents of a model

	table parseVMT(file)
		Returns the contents of a material

	table getVMTRessources(table)
		Returns a table containing all files a VMT needs
]]

struct = require("struct")

local BinaryFormat = package.cpath:match("%p[\\|/]?%p(%a+)")
if BinaryFormat == "dll" then
    function os.name()
        return "Windows"
    end
elseif BinaryFormat == "so" then
    function os.name()
        return "Linux"
    end
elseif BinaryFormat == "dylib" then
    function os.name()
        return "MacOS"
    end
end
BinaryFormat = nil

function IsFile(dir)
	return string.find(dir, ".", 1, true)
end

function SafePath(path)
	return string.Replace(path, [[\]], [[/]])
end

function GetPath(file)
    local last = 0
    for k=1, 20 do
        local current = string.find(file, "/", last + 1)
        if current == nil then
            break
        end

        last = current
    end

    return string.sub(file, 1, last)
end

function GetPathWithoutFirst(file)
    return string.sub(file, string.find(file, "/") + 1)
end

function ScanDir(directory, recursive) -- NOTE: Recursive is super slow!
    local i, t, popen = 0, {}, io.popen
    local pfile
    if os.name() == "Windows" then
        pfile = popen('dir "'..directory..'" /b /a') -- Windows
    else
        pfile = popen('ls "'..directory..'"') -- Linux
    end

    for filename in pfile:lines() do
        i = i + 1
        local isfile = IsFile(filename)
        if not isfile and recursive then
            t[filename] = ScanDir(directory .. "/" .. filename, recursive)
        else
            t[i] = filename
        end
    end
    pfile:close()
    return t
end


local created_dirs = {}
function CreateDir(name)
	if created_dirs[name] then return end
	if os.name() == "Windows" then
		os.execute('mkdir "' .. string.Replace(name, "/", [[\]]) .. '"')
	else
		os.execute('mkdir -p "' .. name .. '"')
	end

	created_dirs[name] = true
end

function ReadFile(path)
    local file = io.open(path, "rb")
    local content = file:read("*a")
    file:close()
    return content
end

function WriteFile(path, content)
    local file = io.open(path, "wb")
    local content = file:write(content)
    file:close()
end

function CopyFile(from, to)
	CreateDir(GetPath(to))
	WriteFile(to, ReadFile(from))
end

function RemoveSpaces(inputString)
    return inputString:gsub("[%s\t]", "")
end

function string.Replace(str, rep, new)
    local new_str = str
    local last = 0
    for k=1, 10 do
        local found, finish = string.find(new_str, rep, last, true)
        if found then
            new_str = string.sub(new_str, 1, found - 1) .. new .. string.sub(new_str, found + 1)
            last = found + 1
        end
    end

    return new_str
end

function FileExists(filePath)
    local file = io.open(filePath, "r")

    if file then
        io.close(file)
        return true
    else
        return false
    end
end

local content_searchpaths
function BuildPaths()
    return {}
end

function FindFile(name)
	if not content_searchpaths then
		content_searchpaths = BuildPaths() -- Creates all search paths once
	end

    for _, folder in ipairs(content_searchpaths) do
    	if FileExists(folder .. "/" .. name) then
    		return folder .. "/" .. name
    	end
    end
end

local function istable(val)
	return type(val) == "table"
end

function EndsWith(str, find)
	return str:sub(#str - #find - 1) == find
end

function BuildFilePath(tbl, list, path)
    for k, v in pairs(tbl) do
    	if istable(v) then
    		BuildFilePath(v, list, path == "" and (path .. k) or (path .. "/" .. k))
    	else
    		local p = path == "" and (path .. v) or (path .. "/" .. v)
    		list[p] = p
    		list[SafePath(p)] = p
    		list[SafePath(p):lower()] = p
    	end
    end
end

local content_filelist = {}
function BuildFileList()
	if not content_searchpaths then
		content_searchpaths = BuildPaths() -- Creates all search paths once
	end

	for _, folder in ipairs(content_searchpaths) do
    	BuildFilePath(ScanDir(folder, true), content_filelist, folder)
    end

    --for k, v in pairs(content_filelist) do
    --	print(k, v)
    --end
end

local missing = {}
function FindFileInList(name)
	if missing[name] then return end

	for str, real in pairs(content_filelist) do
		local found, finish = string.find(str, name)
        if found then
        	return real
        end

        local found, finish = string.find(str, name:lower())
        if found then
        	return real
        end
	end

	local ret = FindFile(name)
	if ret then
		return ret
	end

	missing[name] = true
end

--[[
	Model reader
]]
local function ReadFloat(file)
	return struct.unpack("f", file:read(4))
end

local function ReadVector(file)
	local tbl = {
		ReadFloat(file),
		ReadFloat(file),
		ReadFloat(file),
	}

	return tbl
end

local function ReadInt(file)
	return struct.unpack("i", file:read(4))
end

local function ReadByte(file)
	return struct.unpack("b", file:read(1))
end

local function Read64String(file)
	return struct.unpack("s", file:read(64))
end

local function ReadString(file)
	local str = ""
	local char = file:read(1)

	while char and char ~= "\0" do
	    str = str .. char
	    char = file:read(1)
	end

	return str
end

--[[
	Map reader
]]
function readVMF(filePath)
    local file = io.open(filePath, "r")

    if not file then
        print("Error: Could not open .vmf file.")
        return
    end

    local invmaterials = {}
	local invmodels = {}

    local materials = {}
    local models = {}

    local inMaterialBlock = false
    local inModelBlock = false

    for line in file:lines() do
        local mat = line:match('"material"%s+"([^"]+)"')
        if mat and not invmaterials[mat] then
        	table.insert(materials, mat)
        	invmaterials[mat] = true
        end

        local mod = line:match('"model"%s+"([^"]+)"')
        if mod and not invmodels[mod] then
        	table.insert(models, mod)
        	invmodels[mod] = true
        end
    end

    file:close()

    return materials, models
end

function parseMDL(filePath)
    local file = io.open(filePath, "rb")

    if not file then
        print("Error: Could not open .mdl file.")
        return
    end

    local mdl = {
    	header = { -- studiohdr_t struct
	        id = file:read(4),
	        version = ReadInt(file),
	        checksum = ReadInt(file),
	        name = Read64String(file),

	        dataLength = ReadInt(file),

	        eyeposition = ReadVector(file),
	        illumposition = ReadVector(file),
	        hull_min = ReadVector(file),
	        hull_max = ReadVector(file),
	        view_bbmin = ReadVector(file),
	        view_bbmax = ReadVector(file),

	        flags = ReadInt(file),
	        
	        bone_count = ReadInt(file),
	        bone_offset = ReadInt(file),

	        bonecontroller_count = ReadInt(file),
	        bonecontroller_offset = ReadInt(file),

	        hitbox_count = ReadInt(file),
	        hitbox_offset = ReadInt(file),

	        localanim_count = ReadInt(file),
	        localanim_offset = ReadInt(file),

	        localseq_count = ReadInt(file),
	        localseq_offset = ReadInt(file),

	        activitylistversion = ReadInt(file),
	        eventsindexed = ReadInt(file),

	        texture_count = ReadInt(file), -- Important. VMT filenames (mstudiotexture_t)
	        texture_offset = ReadInt(file),

	        texturedir_count = ReadInt(file),
	        texturedir_offset = ReadInt(file),

	        skinreference_count = ReadInt(file),
	        skinrfamily_count = ReadInt(file),
	        skinreference_index = ReadInt(file),

	        bodypart_count = ReadInt(file),
	        bodypart_offset = ReadInt(file),

	        attachment_count = ReadInt(file),
	        attachment_offset = ReadInt(file),

	        localnode_count = ReadInt(file),
	        localnode_index = ReadInt(file),
	        localnode_name_index = ReadInt(file),

	        flexdesc_count = ReadInt(file),
	        flexdesc_index = ReadInt(file),

	        flexcontroller_count = ReadInt(file),
	        flexcontroller_index = ReadInt(file),

	        flexrules_count = ReadInt(file),
	        flexrules_index = ReadInt(file),

	        ikchain_count = ReadInt(file),
	        ikchain_index = ReadInt(file),

	        mouths_count = ReadInt(file),
	        mouths_index = ReadInt(file),

	        localposeparam_count = ReadInt(file),
	        localposeparam_index = ReadInt(file),

	        surfaceprop_index = ReadInt(file),

	        keyvalue_index = ReadInt(file),
	        keyvalue_count = ReadInt(file),

	        iklock_count = ReadInt(file),
	        iklock_index = ReadInt(file),

	        mass = ReadFloat(file),

	        contents = ReadInt(file),

	        includemodel_count = ReadInt(file),
	        includemodel_index = ReadInt(file),

	        virtualModel = ReadInt(file),

	        animblocks_name_index = ReadInt(file),
	        animblocks_count = ReadInt(file),
	        animblocks_index = ReadInt(file),

	        animblockModel = ReadInt(file),

	        bonetablename_index = ReadInt(file),

	        vertex_base = ReadInt(file),
	        offset_base = ReadInt(file),

	        directionaldotproduct = ReadByte(file),

	        rootLod = ReadByte(file),

	        numAllowedRootLods = ReadByte(file),

	        unused0 = ReadByte(file),
	        unused1 = ReadInt(file),

	        flexcontrollerui_count = ReadInt(file),
	        flexcontrollerui_index = ReadInt(file),

	        vertAnimFixedPointScale = ReadFloat(file),

	        unused2 = ReadInt(file),

	        studiohdr2index = ReadInt(file),

	        unused3 = ReadInt(file),
	    }
	}

    if mdl.header.studiohdr2index > 0 then
    	file:seek("set", mdl.header.studiohdr2index)
    	mdl.secondaryheader = { -- studiohdr2_t struct
    		srcbonetransform_count = ReadInt(file),
    		srcbonetransform_index = ReadInt(file),

    		illumpositionattachmentindex = ReadInt(file),

    		flMaxEyeDeflection = ReadFloat(file),

    		linearbone_index = ReadInt(file),
    		unknown = {},
    	}

    	for i = 1, 64 do
		    mdl.secondaryheader.unknown[i] = ReadInt(file)
		end
    end

    if mdl.header.texturedir_count > 0 then
    	file:seek("set", mdl.header.texturedir_offset)
    	mdl.texturedirs = {}

    	local dirs = {}
    	for k=1, mdl.header.texturedir_count do
    		dirs[k] = ReadInt(file)
    	end

    	for k, offset in pairs(dirs) do
    		file:seek("set", offset)

    		mdl.texturedirs[k] = ReadString(file)
    	end
    end

    if mdl.header.texture_count > 0 then
    	file:seek("set", mdl.header.texture_offset)
    	mdl.textures = {}

    	for k=1, mdl.header.texture_count do
    		local mstudiotexture_t = {}
		    mstudiotexture_t.name_offset = ReadInt(file)
		    mstudiotexture_t.flags = ReadInt(file)
		    mstudiotexture_t.used = ReadInt(file)
		    mstudiotexture_t.unused = ReadInt(file)
		    mstudiotexture_t.material = ReadInt(file)
		    mstudiotexture_t.client_material = ReadInt(file)

		    mstudiotexture_t.unused2 = {}
		    for i = 1, 10 do
		        mstudiotexture_t.unused2[i] = ReadInt(file)
		    end

		    if mstudiotexture_t.name_offset > 0 then
		    	local offset = file:seek()
		        file:seek("set", offset - 64 + mstudiotexture_t.name_offset)
		        mstudiotexture_t.name = ReadString(file)
		        file:seek("set", offset)
		    end

		    table.insert(mdl.textures, mstudiotexture_t)
    	end
    end

    file:close()

    return mdl
end

--[[
	Material reader
]]
function parseVMT(vmtContent)
	local lines = {}
	local scope = {}
	local vmtTable = {}
	local currentMaterial

	local current_tbl = nil
	for line in vmtContent:gmatch("[^\r\n]+") do
		if line:match("//") then
			local pos = string.find(line, "//")
			line = line:sub(0, pos - 1)
		end

		if line:match("{") then
			if not current_tbl then
				current_tbl = vmtTable
			else
				table.insert(scope, current_tbl)
				local new_tbl = {}
				current_tbl[RemoveSpaces(lines[#lines])] = new_tbl
				current_tbl = new_tbl
			end
		end

		if line:match("}") then
			current_tbl = scope[#scope]
			scope[#scope] = nil
		end

		local key, value = line:match([["([^"]+)"%s+([^%*]+)]]) -- "([^"]+)"\s([^*]+)
		if not key then
			key, value = line:match([[([^%s]+)%s([^%*]+)]]) -- ([^%s]+)\s([^*]+) (Match things like $bumpmap without "")
		end

		if key then
			if value then
				local val_match = value:match([["([^"]+)"]])
				if val_match then -- Read strings properly
					value = val_match:lower()
				end

				current_tbl[RemoveSpaces(key)] = value
			else
				error("WHAT TF. HOW TF. WHY TF.")
			end
		end

		table.insert(lines, line)
	end

	return vmtTable
end

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
					local path = FindFile("materials/" .. SafePath(v:lower()) .. ".vmt")
					if path then
						tbl[v] = path
					end

					local path = FindFile("materials/" .. SafePath(v:lower()) .. ".vtf") -- Smack both vtf and vmt in there :D
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

function getFileName(filePath)
	return filePath:match(".*/([^/]+)%.vmf")
end

local function findLuaModelEntries(filename)
	local file = io.open(filename, "r")
	if not file then
		return nil
	end

	local matches = {}
	local pattern = [["model"%s*,%s*"([^"]+)"]]
	for line in file:lines() do
		for match in line:gmatch(pattern) do
			if not matches[match] and match:sub(1, 1) ~= "*" then
				matches[match] = true
				table.insert(matches, match)
			end
		end
	end

	file:close()
	return matches
end

function LoadAdditionalContentFile(filePath, materials, models)
	local entries = findLuaModelEntries(filePath)

	for _, entry in ipairs(entries or {}) do
		table.insert(models, entry)
	end
end