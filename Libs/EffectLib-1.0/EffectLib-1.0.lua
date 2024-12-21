--[[
Name: EffectLib-1.0
Revision: $Rev: 10220 $
Author(s): xhwsd
Website: https://github.com/xhwsd
Description: 效果相关操作库。
Dependencies: AceLibrary
]]

-- 主要版本
local MAJOR_VERSION = "EffectLib-1.0"
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
local EffectLib = {}

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

-- 查找单位效果名称
-- @param string name 效果名称
-- @param string unit = "player" 目标单位；额外还支持`mainhand`、`offhand`
-- @return string 效果类型；可选值：`mainhand`、`offhand`、`buff`、`debuff`
-- @return number 效果索引；从1开始
-- @return string 效果文本
function EffectLib:FindName(name, unit)
	unit = unit or "player"

	if not name then
		return
	end

	-- 适配单位
	auratooltip:SetOwner(UIParent, "ANCHOR_NONE")
	if string.lower(unit) == "mainhand" then
		-- 主手
		auratooltip:ClearLines()
		auratooltip:SetInventoryItem("player", GetInventorySlotInfo("MainHandSlot"));
		for index = 1, auratooltip:NumLines() do
			local text = getglobal("auratooltipTextLeft" .. index):GetText() or ""
			if string.find(text, name) then
				return "mainhand", index, text
			end
		end
	elseif string.lower(unit) == "offhand" then
		-- 副手
		auratooltip:ClearLines()
		auratooltip:SetInventoryItem("player", GetInventorySlotInfo("SecondaryHandSlot"))
		for index = 1, auratooltip:NumLines() do
			local text = getglobal("auratooltipTextLeft" .. index):GetText() or ""
			if string.find(text, name) then
				return "offhand", index, text
			end
		end
	else
		-- 增益
		local index = 1
		while UnitBuff(unit, index) do 
			auratooltip:ClearLines()
			auratooltip:SetUnitBuff(unit, index)
			local text = auratooltipTextLeft1:GetText() or ""
			if string.find(text, name) then
				return "buff", index, text
			end
			index = index + 1
		end

		-- 减益
		local index = 1
		while UnitDebuff(unit, index) do
			auratooltip:ClearLines()
			auratooltip:SetUnitDebuff(unit, index)
			local text = auratooltipTextLeft1:GetText() or ""
			if string.find(text, name) then
				return "debuff", index, text
			end
			index = index + 1
		end
	end
end

-- 查找单位效果图标
-- @param string icon 效果图标
-- @param string unit = "player" 目标单位；额外还支持`mainhand`、`offhand`
-- @return string 效果类型
function EffectLib:FindIcon(icon, unit)
	
end

------------------------------------------------

-- 最终注册库
AceLibrary:Register(EffectLib, MAJOR_VERSION, MINOR_VERSION, activate, nil, external)
EffectLib = nil