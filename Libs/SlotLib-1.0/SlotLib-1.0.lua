--[[
Name: SlotLib-1.0
Revision: $Rev: 10001 $
Author(s): xhwsd
Website: https://github.com/xhwsd
Description: 插槽相关操作库。
Dependencies: AceLibrary, Gratuity-2.0, SpellCache-1.0
]]

-- 主要版本
local MAJOR_VERSION = "SlotLib-1.0"
--次要版本
local MINOR_VERSION = "$Revision: 10001 $"

-- 检验 AceLibrary
if not AceLibrary then
	error(MAJOR_VERSION .. " requires AceLibrary")
end

-- 检验版本（本库，单实例）
if not AceLibrary:IsNewVersion(MAJOR_VERSION, MINOR_VERSION) then
	return
end

-- 检查依赖库
local function CheckDependency(dependencies)
	for index, value in ipairs(dependencies) do
		if not AceLibrary:HasInstance(value) then 
			error(format("%s requires %s to function properly", MAJOR_VERSION, value))
		end
	end
end
CheckDependency({
	-- 提示解析
	"Gratuity-2.0", 
	-- 法术缓存
	"SpellCache-1.0"
})

-- 引入依赖库
local gratuity = AceLibrary("Gratuity-2.0")
local spellCache = AceLibrary("SpellCache-1.0")

-- 创建库对象
local SlotLib = {}

-- 库激活
-- @param table self 库自身对象
-- @param table oldLib 旧版库对象
-- @param function oldDeactivate 旧版库停用函数
local function activate(self, oldLib, oldDeactivate)

end

-- 外部库加载
-- @param table self 库自身对象
-- @param string major 外部库主版本
-- @param table instance 外部库实例
local function external(self, major, instance)

end

------------------------------------------------

-- 法术缓存
local spellCaches = {}

-- 检验值是否包含于索引数组中
-- @param table array 数组(索引表）
-- @param string|number value 值
-- @return number 返回索引
local function InArray(array, value)
	if type(array) == "table" then
		for index, data in ipairs(array) do
			if data == value then
				return index
			end
		end
	end
end

-- 取插槽法术图标
-- @param number slot 插槽索引
-- @return string 图标纹理
local function GetSpellIcon(slot)
	-- 普通法术没有文本
	if slot and HasAction(slot) and not GetActionText(slot) then
		return GetActionTexture(slot)
	end
end

-- 检验插槽是否为宏
-- @param number slot 插槽索引；从1开始
-- @return boolean 是否为宏
function SlotLib:IsMacro(slot)
	return slot and HasAction(slot) and GetActionText(slot) ~= nil
end

-- 检验插槽是否法术（非宏）
-- @param number slot 插槽索引；从1开始
-- @return boolean 是否为法术
function SlotLib:IsSpell(slot)
	return slot and HasAction(slot) and not GetActionText(slot)
end

-- 取插槽法术信息
-- @param number slot 插槽索引；从1开始
-- @return string 法术名称
-- @return number 法术等级
-- @return number 法术索引；从1开始
function SlotLib:GetSpell(slot)
	-- 仅限法术插槽
	if self:IsSpell(slot) then
		-- 取提示文本
		gratuity:SetAction(slot)
		local spellName, spellRank = gratuity:GetLine(1), gratuity:GetLine(1, true)

		-- 取法术数据
		local sName, _, sId, _, sRank = spellCache:GetSpellData(spellName, spellRank)
		return spellName or sName, sRank or spellRank, sId
	end
end

-- 查找任意一个法术在动作条中的插槽索引
-- @param sting ... 法术名称
-- @return number 插槽索引；1~120
-- @return sting 法术名称
-- @return sting 图标纹理
function SlotLib:FindSpell(...)
	-- 检验法术
	if arg.n == 0 then
		return
	end

	-- 从缓存匹配
	for index = 1, arg.n, 1 do
		if type(arg[index]) == "string" and arg[index] ~= "" then
			local spell = arg[index]
			if spellCaches[spell] then
				local icon, slot = spellCaches[spell].icon, spellCaches[spell].slot
				if icon and slot and icon == GetSpellIcon(slot) then
					return slot
				else
					-- 缓存失效
					spellCaches[spell].slot = nil
				end
			end
		end
	end

	-- 准备法术图标
	local index = 1
	while true do
		-- 取法术名称
		local spell = GetSpellName(index, BOOKTYPE_SPELL)
		if not spell or spell == "" or spell == "充能点" then
			break
		end

		-- 缓存图标
		if InArray(arg, spell) and not spellCaches[spell] then
			local icon = GetSpellTexture(index, BOOKTYPE_SPELL)
			if icon then
				spellCaches[spell] = {icon = icon}
			end
		end

		-- 递增索引
		index = index + 1
	end

	--- 准备法术插槽
	for index = 1, 120 do
		local icon = GetSpellIcon(index)
		if icon then
			-- 匹配法术
			local spell = nil
			for name, data in pairs(spellCaches) do
				if data.icon == icon then
					spell = name
					break
				end
			end

			-- 缓存插槽
			if spell then
				spellCaches[spell].slot = index
				if InArray(arg, spell) then
					return index, spell, icon
				end
			end
		end
	end
end

------------------------------------------------

-- 最终注册库
AceLibrary:Register(SlotLib, MAJOR_VERSION, MINOR_VERSION, activate, external)
SlotLib = nil