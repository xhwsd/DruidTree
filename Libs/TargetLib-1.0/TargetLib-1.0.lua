--[[
Name: TargetLib-1.0
Revision: $Rev: 10220 $
Author(s): xhwsd
Website: https://github.com/xhwsd
Description: 目标相关操作库。
Dependencies: AceLibrary
]]

-- 主要版本
local MAJOR_VERSION = "TargetLib-1.0"
--次要版本
local MINOR_VERSION = "$Revision: 10220 $"

-- 检验 AceLibrary
if not AceLibrary then
	error(MAJOR_VERSION .. " requires AceLibrary")
end

-- 检验版本（本库，单实例）
if not AceLibrary:IsNewVersion(MAJOR_VERSION, MINOR_VERSION) then
	return
end

-- 创建库对象
local TargetLib = {}

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

-- 切换目标
local switchTargets = {}

-- 切换到单位目标
-- @param string unit 单位
-- @return boolean 切换到单位成功
function TargetLib:ToUnit(unit)
	if not unit or unit == "" then
		-- DebugError(1, "切换到单位目标无效：单位：%s", unit or "nil")
		return false
	elseif not UnitExists(unit) then
		-- DebugWarning(2, "切换到单位目标不存在：单位：%s", unit)
		return false
	end

	local switch = {
		unit = unit,
		request = UnitName(unit),
		before = UnitName("target"),
	}
	if UnitIsUnit(switch.unit, "target") then
		-- 相同目标
		switch.type = 2
		switch.after = before
	elseif switch.before then
		-- 其他目标
		switch.type = 1
		TargetUnit(switch.unit)
		switch.after = UnitName("target")
		if switch.after ~= switch.request then
			-- DebugError(1, "其他目标切换到单位失败；切换前：%s；切换后：%s；要求：%s", switch.before, switch.after, switch.request)
			return false
		end
	else
		-- 无目标
		switch.type = 0
		TargetUnit(switch.unit)
		switch.after = UnitName("target")
		if switch.after ~= switch.request then
			-- DebugError(1, "无目标切换到单位失败；切换前：%s；切换后：%s；要求：%s", switch.before, switch.after, switch.request)
			return false
		end
	end

	-- 压入切换
	table.insert(switchTargets, 1, switch)
	return true
end

-- 切换到名称目标
-- @param string name 名称
-- @return boolean 成功返回true，否则返回false
function TargetLib:ToName(name)
	if not name or name == "" then
		-- DebugError(1, "切换到名称目标无效；名称：%s", name or "nil")
		return false
	end

	local switch = {
		unit = nil,
		request = name,
		before = UnitName("target"),
	}

	if switch.before == switch.request then
		-- 相同目标
		switch.type = 2
		switch.after = before
	elseif switch.before then
		-- 其他目标
		switch.type = 1
		TargetByName(switch.request)
		switch.after = UnitName("target")
		if switch.after ~= switch.request then
			-- DebugError(1, "其他目标切换到名称失败；切换前：%s；切换后：%s；要求：%s", switch.before, switch.after, switch.request)
			return false
		end
	else
		-- 无目标
		switch.type = 0
		TargetByName(switch.request)
		switch.after = UnitName("target")
		if switch.after ~= switch.request then
			-- DebugError(1, "无目标切换到名称失败；切换前：%s；切换后：%s；要求：%s", switch.before, switch.after, switch.request)
			return false
		end
	end

	-- 压入切换
	table.insert(switchTargets, 1, switch)
	return true
end

-- 恢复到上次目标
-- @return boolean 成功返回true，否则返回false
function TargetLib:ToLast()
	if next(switchTargets) == nil then
		-- DebugWarning(2, "切换目标列表为空")
		return false
	end

	-- 弹出切换
	local switch = table.remove(switchTargets, 1)
	if switch.type == 2 then
		-- 相同目标
		local before = UnitName("target")
		local after = before
		if after ~= switch.before then
			-- DebugError(1, "恢复到相同目标失败；切换前：%s；切换后：%s；要求：%s", before, after, switch.before)
			return false
		end
	elseif switch.type == 1 then
		-- 其他目标
		local before = UnitName("target")
		TargetLastTarget()
		local after = UnitName("target")
		if after ~= switch.before then
			-- DebugError(1, "恢复到其他目标失败；切换前：%s；切换后：%s；要求：%s", before, after, switch.before)
			return false
		end
	else
		-- 无目标
		ClearTarget()
	end
	return true
end

------------------------------------------------

-- 最终注册库
AceLibrary:Register(TargetLib, MAJOR_VERSION, MINOR_VERSION, activate, external)
TargetLib = nil