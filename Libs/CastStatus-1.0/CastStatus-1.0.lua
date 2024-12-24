--[[
Name: CastStatus-1.0
Revision: $Rev: 10001 $
Author(s): xhwsd
Website: https://github.com/xhwsd
Description: 施法状态相关操作库。
Dependencies: AceLibrary, AceEvent-2.0, AceHook-2.1, SpellCache-1.0, Gratuity-2.0
]]

-- 主要版本
local MAJOR_VERSION = "CastStatus-1.0"
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

---检查依赖库
--- @param dependencies table 依赖库名称列表
local function CheckDependency(dependencies)
	for index, value in ipairs(dependencies) do
		if not AceLibrary:HasInstance(value) then 
			error(format("%s requires %s to function properly", MAJOR_VERSION, value))
		end
	end
end

CheckDependency({
	-- 事件
	"AceEvent-2.0",
	-- 钩子
	"AceHook-2.1",
	-- 法术缓存
	"SpellCache-1.0",
	-- 提示解析
	"Gratuity-2.0"
})

-- 引入依赖库
local spellCache = AceLibrary("SpellCache-1.0")
-- 提示解析
local gratuity = AceLibrary("Gratuity-2.0")

-- 创建库对象
local CastStatus = {}

---库激活
---@param self table 库自身对象
---@param oldLib table 旧版库对象
---@param oldDeactivate function 旧版库停用函数
local function activate(self, oldLib, oldDeactivate)
	CastStatus = self

	if oldLib then
		oldLib:UnregisterAllEvents()
		oldLib:CancelAllScheduledEvents()
		oldLib:UnhookAll()
	end

	if oldDeactivate then
		oldDeactivate(oldLib)
	end
end

---外部库加载
---@param self table 库自身对象
---@param major string 外部库主版本
---@param instance table 外部库实例
local function external(self, major, instance)
	if major == "AceEvent-2.0" then
		-- 混入事件
		instance:embed(self)

		-- 注册事件
		self:RegisterEvent("SPELLCAST_START")
		self:RegisterEvent("SPELLCAST_STOP")
		self:RegisterEvent("SPELLCAST_FAILED")
		self:RegisterEvent("SPELLCAST_INTERRUPTED", "SPELLCAST_FAILED")
	elseif major == "AceHook-2.1" then
		-- 混入钩子
		instance:embed(self)

		-- 挂接函数
		self:Hook("UseAction")
		self:Hook("CastSpell")
		self:Hook("CastSpellByName")
		-- self:Hook("SpellTargetUnit")
		-- self:Hook("SpellStopTargeting")
		-- self:Hook("TargetUnit")
		-- self:HookScript(WorldFrame, "OnMouseDown")
	end
end

------------------------------------------------

-- 施法
local cast = {
	-- 法术
	spell = "",
	-- 目标
	target = "",
	-- 施法中
	casting = false,
}

---施法开始
function CastStatus:SPELLCAST_START()
	cast.casting = true
	cast.spell = arg1
	-- self:LevelDebug(3, "施法开始；法术：%s；目标：%s", cast.spell, cast.target)
end

---施法停止
function CastStatus:SPELLCAST_STOP()
	cast.casting = false
	-- self:LevelDebug(3, "施法停止；法术：%s；目标：%s", cast.spell, cast.target)
end

---施法失败
function CastStatus:SPELLCAST_FAILED()
	cast.casting = false
	-- self:LevelDebug(3, "施法失败；法术：%s；目标：%s", cast.spell, cast.target)
end

---使用动作条
function CastStatus:UseAction(slotId, checkCursor, onSelf)
	-- self:LevelDebug(3, "UseAction", slotId, checkCursor, onSelf)
	self.hooks.UseAction(slotId, checkCursor, onSelf)

	-- 宏有文本
	if GetActionText(slotId) then
		return
	end

	-- 正在施法
	if self:IsCasting() then
		return
	end

	-- 法术名称
	gratuity:SetAction(slotId)
	local spell = spellCache:GetSpellData(gratuity:GetLine(1), gratuity:GetLine(1, true))
	-- 目标单位
	local unit = onSelf and "player" or (UnitExists("target") and "target" or "player") 
	-- 处理施法
	self:HandleCast(spell, unit)
end

---施展法术
function CastStatus:CastSpell(spellId, spellbookType)
	-- self:LevelDebug(3, "CastSpell", spellId, spellbookType)
	self.hooks.CastSpell(spellId, spellbookType)

	-- 正在施法
	if self:IsCasting() then
		return
	end

	-- 法术名称
	local spell = GetSpellName(spellId, spellbookType)
	-- 目标单位
	local unit = UnitExists("target") and "target" or "player"
	-- 处理施法
	self:HandleCast(spell, unit)
end

---按名称施展法术
function CastStatus:CastSpellByName(spellName, onSelf)
	-- self:LevelDebug(3, "CastSpellByName", spellName, onSelf)
	self.hooks.CastSpellByName(spellName, onSelf)

	-- 正在施法
	if self:IsCasting() then
		return
	end

	-- 法术名称
	local spell = spellCache:GetSpellData(spellName)
	-- 目标单位
	local unit = onSelf and "player" or (UnitExists("target") and "target" or "player") 
	-- 处理施法
	self:HandleCast(spell, unit)
end

---处理施法
---@param spell string 法术名称
---@param unit string 目标单位
function CastStatus:HandleCast(spell, unit)
	cast.spell = spell
	cast.target = UnitName(unit)
end

---取施法状态
---@return boolean casting 是否在施法中
---@return string spell 施法名称
---@return string target 施法目标
function CastStatus:GetStatus()
	return cast.casting, cast.spell, cast.target
end

---是否在施法中
---@return boolean casting 是否在施法中
function CastStatus:IsCasting()
	return cast.casting
end

---取施法名称
---@return string spell 施法名称
function CastStatus:GetSpell()
	return cast.spell
end

---取施法目标
---@return string target 施法目标
function CastStatus:GetTarget()
	return cast.target
end

------------------------------------------------

-- 最终注册库
AceLibrary:Register(CastStatus, MAJOR_VERSION, MINOR_VERSION, activate, nil, external)
CastStatus = nil