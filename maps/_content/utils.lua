--[[
	This file exposes these functions:
	bool IsFile(file)
	String NormalizePath(path) 
		Replaces \ with / and Trims any spaces and makes it lowercase
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

	nil LoadAdditionalContentFile(string luaFile)
		Searches for any "model", "[modelPath]" occurances in the Lua file and adds thoes models to be included in the content.
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

local pattern_escape_replacements = { -- Gmod my <3
	["("] = "%(",
	[")"] = "%)",
	["."] = "%.",
	["%"] = "%%",
	["+"] = "%+",
	["-"] = "%-",
	["*"] = "%*",
	["?"] = "%?",
	["["] = "%[",
	["]"] = "%]",
	["^"] = "%^",
	["$"] = "%$",
	["\0"] = "%z"
}
function string.PatternSafe(str)
	return string.gsub(str, ".", pattern_escape_replacements)
end

function string.Trim(s, char)
	if char then
		char = string.PatternSafe(char)
	else
		char = "%s"
	end

	return string.match(s, "^" .. char .. "*(.-)" .. char .. "*$") or s
end

function IsFile(dir)
	return string.find(dir, ".", 1, true)
end

function NormalizePath(path)
	return string.lower(string.Trim(string.Replace(string.Replace(path, [[\]], [[/]]), [[//]], [[/]])))
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

local contentList = {}
function ReadFile(path)
	if contentList[path] then
		-- From normalized to disk path
		path = contentList[path]
	end

	local file = io.open(path, "rb")
	if file then
		local content = file:read("*a")
		file:close()
		return content
	end

	return nil
end

function WriteFile(path, content)
	if not content then return false end

	local file = io.open(path, "wb")
	if file then
		local content = file:write(content)
		file:close()
		return true
	end

	return false
end

function CopyFile(from, to)
	CreateDir(GetPath(to))
	return WriteFile(to, ReadFile(from))
end

function RemoveSpaces(inputString)
	return inputString:gsub("[%s\t]", "")
end

function string.Replace(str, rep, new)
	local new_str = str
	local rep_length = rep:len()
	local last = 0
	for k=1, 10 do
		local found, finish = string.find(new_str, rep, last, true)
		if found then
			new_str = string.sub(new_str, 1, found - 1) .. new .. string.sub(new_str, found + rep_length)
			last = found + 1
		end
	end

	return new_str
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
	return str:sub(#str - #find + 1) == find
end

function StartsWith(str, find)
	return str:sub(1, #find) == find
end

function BuildFilePath(fileList, contentList, folderPath, rootFolder)
	local relativeFolderPath = folderPath:sub(#rootFolder+2)
	for folderName, fileName in pairs(fileList) do -- folderName is only valid if fileName is a table.
		if istable(fileName) then
			BuildFilePath(fileName, contentList, folderPath == "" and (folderPath .. folderName) or (folderPath .. "/" .. folderName), rootFolder)
		else
			local entryName = relativeFolderPath == "" and (relativeFolderPath .. fileName) or (relativeFolderPath .. "/" .. fileName)
			contentList[NormalizePath(entryName)] = folderPath .. "/" .. fileName
		end
	end
end

function BuildFileList()
	if not content_searchpaths then
		content_searchpaths = BuildPaths() -- Creates all search paths once
	end

	for _, folder in ipairs(content_searchpaths) do
		BuildFilePath(ScanDir(folder, true), contentList, folder, folder)
	end
end

function FileExistsInList(filePath)
	if gmodContent and gmodContent[filePath] then
		return true
	end

	return contentList[filePath] ~= nil
end

function GetFileFromList(filePath)
	return contentList[filePath]
end

function FileExists(filePath)
	if contentList[filePath] then
		return true
	end

	local file = io.open(filePath, "r")

	if file then
		io.close(file)
		return true
	else
		return false
	end
end

--[[
	Model reader
]]
local readerror = false
local function ReadFloat(file)
	local val = file:read(4)
	if not val then readerror = true return end

	return struct.unpack("f", val)
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
	local val = file:read(4)
	if not val then readerror = true return end

	return struct.unpack("i", val)
end

local function ReadByte(file)
	local val = file:read(1)
	if not val then readerror = true return end

	return struct.unpack("b", val)
end

local function Read64String(file)
	local val = file:read(64)
	if not val then readerror = true return end

	return struct.unpack("s", val)
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

function PrintTable(tbl, indent)
	indent = indent or 0
	local str = ""
	for k=1, indent do
		str = str .. "	"
	end

	for k, v in pairs(tbl) do
		if type(v) == "table" then
			print(str .. k .. " = {")
			PrintTable(v, indent + 1)
			print(str .. "}")
		else
			if type(v) == "string" then
				print(str .. k .. ' = "' .. v .. '"')
			else
				print(str .. k .. " = " .. tostring(v))
			end
		end
	end
end

NewLine = [[

]]

function FindFiles(glob)
	if not content_searchpaths then
		content_searchpaths = BuildPaths()
	end

	if next(contentList) == nil then
		BuildFileList()
	end

	glob = NormalizePath(glob):lower()

	local pattern = {}
	for position = 1, #glob do
		local character = glob:sub(position, position)
		if character == "*" then
			table.insert(pattern, ".*")
		elseif character == "?" then
			table.insert(pattern, ".")
		else
			local safePattern = string.PatternSafe(character)
			table.insert(pattern, safePattern)
		end
	end

	pattern = "^" .. table.concat(pattern) .. "$"

	local matches = {}
	local found = {}
	for normalizedPath, realPath in pairs(contentList) do
		if not found[realPath] and normalizedPath:lower():match(pattern) then
			found[realPath] = true
			table.insert(matches, realPath)
		end
	end

	return matches
end

--[[
	Map reader
]]
function parseKV(input)
	local position = 1
	local length = #input
	local line = 1
	local function skipWhitespace()
		while position <= length do
			local character = input:sub(position, position)

			if character == " " or character == "\t" or
			   character == "\r" or character == "\n" then
				if character == "\n" then
					line = line + 1
				end
				position = position + 1

			elseif character == "/" and input:sub(position + 1, position + 1) == "/" then
				position = position + 2

				while position <= length and input:sub(position, position) ~= "\n" do
					position = position + 1
				end
			else
				break
			end
		end
	end

	local function readToken()
		skipWhitespace()

		if position > length then
			return nil
		end

		local character = input:sub(position, position)
		if character == "{" or character == "}" then
			position = position + 1
			return character
		end

		if character == '"' then
			position = position + 1

			local value = {}
			while position <= length do
				character = input:sub(position, position)
				if character == '"' then
					position = position + 1
					return table.concat(value)
				end

				if character == "\\" then
					position = position + 1

					if position > length then
						return nil, "unterminated escape sequence"
					end

					value[#value + 1] = character
				else
					value[#value + 1] = character

					if character == "\n" then
						line = line + 1
					end

					position = position + 1
				end
			end

			return nil, "unterminated quoted string"
		end

		local tokenStart = position
		while position <= length do
			character = input:sub(position, position)

			if character == " " or character == "\t" or
			   character == "\r" or character == "\n" or
			   character == "{" or character == "}" then
				break
			end

			if character == "/" and input:sub(position + 1, position + 1) == "/" then
				break
			end

			position = position + 1
		end

		return input:sub(tokenStart, position - 1)
	end

	local function addValue(object, key, value)
		local existingValue = object[key]
		if existingValue == nil then
			object[key] = value
		elseif existingValue.__array then
			existingValue[#existingValue + 1] = value
		else
			object[key] = {
				__array = true,
				existingValue,
				value
			}
		end
	end

	local function parseBlock()
		local object = {}
		while true do
			local key, keyError = readToken()
			if keyError then
				return nil, keyError
			end

			if key == nil then
				return nil, "unexpected end of file; expected '}'"
			end

			if key == "}" then
				return object
			end

			if key == "{" then
				return nil, "unexpected '{'"
			end

			local value, valueError = readToken()
			if valueError then
				return nil, valueError
			end

			if value == nil then
				return nil, "unexpected end of file after key '" .. key .. "'"
			end

			if value == "{" then
				value, valueError = parseBlock()

				if valueError then
					return nil, valueError
				end
			elseif value == "}" then
				return nil, "unexpected '}' after key '" .. key .. "'"
			end

			addValue(object, key, value)
		end
	end

	if input:sub(1, 3) == "\239\187\191" then
		input = input:sub(4)
		length = #input
	end

	local root = {}
	while true do
		local key, keyError = readToken()
		if keyError then
			return nil, keyError
		end

		if key == nil then
			return root
		end

		if key == "{" or key == "}" then
			return nil, ("VMF parse error at line %d: unexpected '%s'"):format(line, key)
		end

		local openingBrace, valueError = readToken()
		if valueError then
			return nil, valueError
		end

		if openingBrace ~= "{" then
			return nil, ("VMF parse error at line %d: expected '{' after '%s'"):format(line, key)
		end

		local object, blockError = parseBlock()
		if blockError then
			return nil, ("VMF parse error at line %d: %s"):format(line, blockError)
		end

		addValue(root, key, object)
	end
end

function parseMDL(filePath)
	if not filePath or filePath:sub(-4) ~= ".mdl" then
		print("::warning:: Not a model you retarded code :< - \"" .. (filePath or "") .. "\"")
		return
	end

	if contentList[filePath] then
		filePath = contentList[filePath]
	end

	local file = io.open(filePath, "rb")
	if not file then
		print("::warning:: Could not open .mdl file. \"" .. filePath .. "\"")
		return
	end

	readerror = false
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

		if readerror then return nil end

		for i = 1, 64 do
			mdl.secondaryheader.unknown[i] = ReadInt(file)
		end
	end

	if readerror then return nil end

	if (mdl.header.texturedir_count or -1) > 0 then
		file:seek("set", mdl.header.texturedir_offset)
		mdl.texturedirs = {}

		if readerror then return nil end

		local dirs = {}
		for k=1, mdl.header.texturedir_count do
			dirs[k] = ReadInt(file)
		end

		if readerror then return nil end
		for k, offset in pairs(dirs) do
			file:seek("set", offset)

			mdl.texturedirs[k] = ReadString(file)
		end
	end

	if readerror then return nil end
	if (mdl.header.texture_count or -1) > 0 then
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
			if readerror then return nil end

			mstudiotexture_t.unused2 = {}
			for i = 1, 10 do
				mstudiotexture_t.unused2[i] = ReadInt(file)
			end

			if readerror then return nil end
			if mstudiotexture_t.name_offset > 0 then
				local offset = file:seek()
				file:seek("set", offset - 64 + mstudiotexture_t.name_offset)
				mstudiotexture_t.name = ReadString(file)
				file:seek("set", offset)
			end

			if readerror then return nil end
			table.insert(mdl.textures, mstudiotexture_t)
		end
	end

	file:close()

	return mdl
end

--[[
	Material reader
]]
local vmtMaterialKeys = {
	["$basetexture"] = true,
	["$basetexture2"] = true,
	["$basetexturetransform"] = false,

	["$bumpmap"] = true,
	["$bumpmap2"] = true,

	["$normalmap"] = true,
	["$normalmap2"] = true,

	["$detail"] = true,
	["$detail2"] = true,

	["$blendmodulatetexture"] = true,
	["$blendmodulatetexture2"] = true,

	["$envmap"] = true,
	["$envmapmask"] = true,

	["$phongexponenttexture"] = true,

	["$selfillummask"] = true,

	["$selfillumtexture"] = true,

	["$emissiveblendtexture"] = true,
	["$emissiveblendbasetexture"] = true,
	["$emissiveblendflowtexture"] = true,

	["$fleshinteriortexture"] = true,
	["$fleshsubsurfaceTexture"] = true,

	["$sheenmap"] = true,

	["$lightwarptexture"] = true,
}

local no_extension = {
	[".vtf"] = true,
	[".vmt"] = true
}
function getVMTRessources(vmt)
	local results = {}
	for _, entry in pairs(vmt) do
		for key, material in pairs(entry) do
			if vmtMaterialKeys[key] then
				-- We must later filter out env_cubemap
				table.insert(results, material)
			end
		end
	end

	return results
end

function getFileName(filePath)
	return filePath:match(".*/([^/]+)%.vmf")
end

-- Simple function, it reads a file, line by line and searches for any "model", "[model file]" occurences, this for example is used by Momo's Map Manipulation Tool where it sets the key values.
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