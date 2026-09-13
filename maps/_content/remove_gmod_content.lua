require("utils")

gmodContent = LoadGModContentList()

for filePath, _ in pairs(gmodContent) do
	if RemoveFile("_content_pack/" .. filePath) then
		print("Removed GMod file \"" .. filePath .. "\"")
	end
end