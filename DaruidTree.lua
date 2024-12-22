-- 非德鲁伊退出运行
local _, playerClass = UnitClass("player")
if playerClass ~= "DRUID" then
	return
end

-- 定义插件
DaruidTree = AceLibrary("AceAddon-2.0"):new(
	-- 控制台
	"AceConsole-2.0",
	-- 调试
	"AceDebug-2.0"
)

-- 名单库（团队/队伍）
local rosterLib = AceLibrary("RosterLib-2.0")
-- 法术缓存
local spellCache = AceLibrary("SpellCache-1.0")

-- 效果检查
local effectCheck = AceLibrary("EffectCheck-1.0")
-- 法术检查
local spellCheck = AceLibrary("SpellCheck-1.0")
-- 法术插槽
local spellSlot = AceLibrary("SpellSlot-1.0")
-- 目标切换
local targetSwitch = AceLibrary("TargetSwitch-1.0")
-- 施法状态
local castStatus = AceLibrary("CastStatus-1.0")

-- 名单
local rosters = {}

-- 位与数组
-- @param table array 数组(索引表）
-- @param string|number data 数据
-- @return number 成功返回索引，失败返回nil
local function InArray(array, data)
	if type(array) == "table" then
		for index, value in ipairs(array) do
			if value == data then
				return index
			end
		end
	end
end

-- 取生命损失
-- @param string unit = "player" 单位
-- @return number 生命损失百分比
-- @return number 生命损失
local function HealthLose(unit)
	unit = unit or "player"
	
	-- 生命上限
	local max = UnitHealthMax(unit)
	-- 生命损失
	local lose = max - UnitHealth(unit)
	-- 百分比 = 部分 / 整体 * 100
	return math.floor(lose / max * 100), lose
end

-- 取生命剩余
-- @param string unit = "player" 单位
-- @return number 生命剩余百分比
-- @return number 生命剩余
local function HealthResidual(unit)
	unit = unit or "player"

	-- 生命剩余
	local residual = UnitHealth(unit)
	-- 百分比 = 部分 / 整体 * 100
	return math.floor(residual / UnitHealthMax(unit) * 100), residual
end

-- 适配治疗法术等级
-- @param string name 法术名称；可选值：回春术、愈合
-- @param number health 目前失血
-- @param string unit = nil 治疗单位
-- @return string 法术名称(含等级)
local function AdaptRank(name, health, unit)
	-- 法术规则
	local spells = {
		["回春术"] = {
			{limit = 200, spell = "回春术(等级 4)"},
			{limit = 300, spell = "回春术(等级 5)"},
			{limit = 400, spell = "回春术(等级 6)"},
			{limit = 500, spell = "回春术(等级 7)"},
			{limit = 600, spell = "回春术(等级 8)"},
			{limit = 700, spell = "回春术(等级 9)"},
			{limit = 900, spell = "回春术(等级 10)"}
		},
		["愈合"] = {
			{limit = 700, spell = "愈合(等级 3)"},
			{limit = 900, spell = "愈合(等级 4)"},
			{limit = 1100, spell = "愈合(等级 5)"},
			{limit = 1300, spell = "愈合(等级 6)"},
			{limit = 1600, spell = "愈合(等级 7)"},
			{limit = 2100, spell = "愈合(等级 8)"}
		}
	}

	-- 匹配等级
	if spells[name] then
		for _, rule in ipairs(spells[name]) do
			if health < rule.limit then
				return rule.spell
			end
		end
	end
	return name
end  

-- 取治疗单位
-- @param string unit = nil 单位；缺省为（友善目标 > 自己）
-- @return string 单位
local function HealUnit(unit)
	-- 缺省单位
	if not unit then
		unit = UnitExists("target") and "target" or "player"
	end

	-- 友善目标 > 自己
	return UnitIsFriend("player", unit) and unit or "player"
end

-- 施法提示
-- @param string spell 法术名称；可包含等级
-- @param string unit = nil 目标单位
local function CastHint(spell, unit)
	if not spell or spell == "" then
		return
	end
	
	-- 指定单位
	if unit then
		if UnitIsUnit(unit, "player") then
			-- 自我施法
			CastSpellByName(spell, 1)
			UIErrorsFrame:AddMessage(string.format("对自己施放<%s>", spell), 0.0, 1.0, 0.0, 53, 5)
		elseif targetSwitch:ToUnit(unit) then
			-- 目标施法
			CastSpellByName(spell)
			targetSwitch:ToLast()
			UIErrorsFrame:AddMessage(string.format("对<%s>施放<%s>", UnitName(unit), spell), 0.0, 1.0, 0.0, 53, 5)
		end
	else
		-- 未指定单位
		CastSpellByName(spell)
		UIErrorsFrame:AddMessage(string.format("施放<%s>", spell), 0.0, 1.0, 0.0, 53, 5)
	end
end

-- 插件载入
function DaruidTree:OnInitialize()
	-- 精简标题
	self.title = "树德辅助"
	-- 开启调试
	self:SetDebugging(true)
	-- 调试等级
	self:SetDebugLevel(2)
end

-- 插件打开
function DaruidTree:OnEnable()
	self:LevelDebug(3, "插件打开")

	-- 注册命令
	self:RegisterChatCommand({"/SDFZ", '/DaruidTree'}, {
		type = "group",
		args = {
			tsms = {
				name = "调试模式",
				desc = "开启或关闭调试模式",
				type = "toggle",
				get = "IsDebugging",
				set = "SetDebugging"
			},
			tsdj = {
				name = "调试等级",
				desc = "设置或获取调试等级",
				type = "range",
				min = 1,
				max = 3,
				get = "GetDebugLevel",
				set = "SetDebugLevel"
			}
		},
	})
end

-- 插件关闭
function DaruidTree:OnDisable()
	self:LevelDebug(3, "插件关闭")
end

-- 打断治疗
-- @param number start = 0 起始生命损失百分比
-- @param boolean 已打断返回true，未打断返回false
function DaruidTree:StopHeal(start)
	start = start or 0
	
	-- 正在施法中
	local casting, spell, target = castStatus:GetStatus()
	if casting then
		-- 匹配法术
		if InArray({"愈合", "治疗之触"}, spell) then
			-- 取生命损失
			local lose = 0
			if target == UnitName("player") then
				-- 自己
				lose = HealthLose("player")
			else
				local unit = rosterLib:GetUnitIDFromName(target)
				if unit then
					-- 单位
					lose = HealthLose(unit)
				elseif targetSwitch:ToName(target) then
					-- 名称
					lose = HealthLose("target")
					targetSwitch:ToLast()
				end
			end
			
			if lose <= start then
				self:LevelDebug(3, "打断治疗；法术：%s；目标：%s；起始：%d；损失：%d", spell, target, start, lose)
				-- 测试发现对NPC愈合时无法真正打断 xhwsd@qq.com 2024-11-15
				SpellStopCasting()
				return true
			end
		end
	end
	return false
end

-- 检验单位可否治疗
-- @param string unit = "player" 治疗单位
-- @return boolean 是否可治疗
function DaruidTree:CanHeal(unit)
	unit = unit or "player"

	-- 单位不存在
	if not UnitExists(unit) then
		return false
	end

	-- 死亡或灵魂
	if UnitIsDeadOrGhost(unit) then
		return false
	end

	-- 自己
	if UnitIsPlayer(unit) then
		return true
	end

	-- 离线
	if not UnitIsConnected(unit) then
		return false
	end

	-- 客户端不可见
	if not UnitIsVisible(unit) then
		return false
	end

	-- 无法协助
	if not UnitCanAssist("player", unit) then
		return false
	end

	-- 跟随范围内（28码）
	if CheckInteractDistance(unit, 4) then
		return true
	end

	-- 法术范围内（40码）
	local slot = spellSlot:FindSpell("愈合", "回春术", "治疗之触")
	if slot and targetSwitch:ToUnit(unit) then
		local satisfy = IsActionInRange(slot) == 1
		targetSwitch:ToLast()
		return satisfy
	end

	-- 让法术判断
	return true
end

-- 过量治疗单位
-- @param string unit = HealUnit(unit) 目标单位
-- @return boolean 成功返回true，否则返回false
function DaruidTree:OverdoseHeal(unit)
	unit = HealUnit(unit)

	-- 可否治疗
	if not self:CanHeal(unit) then
		self:LevelDebug(3, "过量治疗，不可治疗；目标：%s", UnitName(unit))
		return false
	end

	-- 过量治疗
	local lose, health = HealthLose(unit)
	self:LevelDebug(3, "过量治疗；目标：%s；损失：%d", UnitName(unit), lose)
	if effectCheck:FindName("自然迅捷") then
		CastHint("愈合", unit)
	elseif HealthResidual(unit) <= 40 and spellCheck:IsReady("自然迅捷") then
		CastHint("自然迅捷")
	elseif health >= 15000 and spellCheck:IsReady("迅捷治愈") and (effectCheck:FindName("愈合", unit) or effectCheck:FindName("回春术", unit)) then
		CastHint("迅捷治愈", unit)
	elseif not effectCheck:FindName("回春术", unit) then
		CastHint("回春术", unit)
	else
		CastHint("愈合", unit)
	end
	return true
end

-- 节省治疗单位
-- @param string unit = HealUnit(unit) 目标单位
-- @param number start = 6 起始生命损失百分比
-- @param number rank = 4 愈合法术等级
-- @return boolean 成功返回true，否则返回false
function DaruidTree:EconomizeHeal(unit, start, rank)
	unit = HealUnit(unit)
	start = start or 6
	rank = rank or 4

	-- 可否治疗
	if not self:CanHeal(unit) then
		self:LevelDebug(3, "节省治疗，不可治疗；目标：%s", UnitName(unit))
		return false
	end

	-- 起始损失
	local lose, health = HealthLose(unit)
	if lose < start then
		self:LevelDebug(3, "节省治疗，损失不足；目标：%s；起始：%d；损失：%d", UnitName(unit), start, lose)
		return false
	end

	-- 节省治疗
	self:LevelDebug(3, "节省治疗；目标：%s；起始：%d；损失：%d", UnitName(unit), start, lose)
	if effectCheck:FindName("自然迅捷", "player") then
		CastHint(AdaptRank("愈合", health, unit), unit)
	elseif HealthResidual(unit) <= 40 and spellCheck:IsReady("自然迅捷") then
		CastHint("自然迅捷")
	elseif health >= 15000 and spellCheck:IsReady("迅捷治愈") and (effectCheck:FindName("愈合", unit) or effectCheck:FindName("回春术", unit)) then
		CastHint("迅捷治愈", unit)
	else
		CastHint(string.format("愈合(等级 %d)", rank), unit) 
	end
	return true
end

-- 尽力治疗单位
-- @param string unit = HealUnit(unit) 目标单位
-- @return boolean 成功返回true，否则返回false
function DaruidTree:EndeavorHeal(unit)
	unit = HealUnit(unit)

	-- 可否治疗
	if not self:CanHeal(unit) then
		self:LevelDebug(3, "尽力治疗，不可治疗；目标：%s", UnitName(unit))
		return false
	end

	-- 起始损失
	local lose, health = HealthLose(unit)
	if health <= 0 then
		self:LevelDebug(3, "尽力治疗，未损失生命；目标：%s", UnitName(unit))
		return false
	end

	-- 尽力治疗
	self:LevelDebug(3, "尽力治疗；目标：%s；损失：%d", UnitName(unit), lose)
	if effectCheck:FindName("自然迅捷", "player") then
		CastHint(AdaptRank("愈合", health, unit), unit)
	elseif HealthResidual(unit) <= 40 and spellCheck:IsReady("自然迅捷") then
		CastHint("自然迅捷")
	elseif health >= 1500 and spellCheck:IsReady("迅捷治愈") and (effectCheck:FindName("愈合", unit) or effectCheck:FindName("回春术", unit)) then
		CastHint("迅捷治愈", unit)
	elseif not effectCheck:FindName("回春术", unit) then
		CastHint(AdaptRank("回春术", health, unit), unit)
	else
		CastHint(AdaptRank("愈合", health, unit), unit)
	end
	return true
end

-- 查找队伍中损失最多单位
-- @param number start = 4 起始损失
-- @return string|nil 已找到返回单位，未找到否则返回nil
function DaruidTree:FindParty(start)
	start = start or 4

	-- 检验自己（优先）
	local unit = "player"
	local lose = HealthLose(unit)
	local max, target = 0
	if lose >= start then
		max = lose
		target = unit
	end

	-- 查找队伍（不含自己）
	for index = GetNumPartyMembers(), 1, -1 do
		unit = "party" .. index
		lose = HealthLose(unit)
		if lose >= start and lose > max and self:CanHeal(unit) then
			max = lose
			target = unit
		end
	end
	return target
end

-- 查找团队中损失最多单位
-- @param number start = 6 起始损失
-- @return string|nil 已找到返回单位，未找到否则返回nil
function DaruidTree:FindRaid(start)
	start = start or 6

	-- 团队查找
	local max, target = 0
	for index = GetNumRaidMembers(), 1, -1 do
		local unit = "raid" .. index
		local lose = HealthLose(unit)
		if lose >= start and lose > max and self:CanHeal(unit) then
			max = lose
			target = unit
		end
	end
	return target
end

-- 查找名单中损失最多名称
-- @param number start = 2 起始损失
-- @return string|nil 已找到返回名称，未找到否则返回nil
function DaruidTree:FindRoster(start)
	start = start or 2

	-- 名单查找
	local max, target = 0
	for _, name in ipairs(rosters) do
		local unit = rosterLib:GetUnitIDFromName(name)
		if unit then
			-- 单位匹配
			local lose = HealthLose(unit)
			if lose >= start and lose > max and self:CanHeal(unit) then
				max = lose
				target = name
			end
		elseif targetSwitch:ToName(name) then
			-- 名称匹配
			local lose = HealthLose("target")
			if lose >= start and lose > max and self:CanHeal("target") then
				max = lose
				target = name
			end
			targetSwitch:ToLast()
		end 
	end
	return target
end

-- 补充名单增益
-- @param string buff = "回春术" 增益名称
-- @param string spell = buff 法术名称
-- @return string|nil 已补返回名称，未补返回nil
function DaruidTree:AddedBuff(buff, spell)
	buff = buff or "回春术"
	spell = spell or buff

	-- 名单查找
	local target
	for _, name in ipairs(rosters) do
		local unit = rosterLib:GetUnitIDFromName(name)
		if unit then
			if not effectCheck:FindName(buff, unit) and self:CanHeal(unit) then
				target = name
				break
			end
		elseif targetSwitch:ToName(name) then
			if not effectCheck:FindName(buff, "target") and self:CanHeal("target") then
				targetSwitch:ToLast()
				target = name
				break
			else
				targetSwitch:ToLast()
			end
		end
	end

	-- 补充增益
	if target and targetSwitch:ToName(target) then
		self:LevelDebug(3, "补充名单增益；目标：%s；法术：%s", UnitName("target"), spell)   
		CastHint(spell, "target")
		targetSwitch:ToLast()
	end
	return target
end

-- 尝试治疗选择目标
-- @return boolean 成功返回true，否则返回false
function DaruidTree:HealSelect()
	-- 按下ALT
	if IsAltKeyDown() then
		-- 过量治疗
		if self:OverdoseHeal(HealUnit()) then
			return true
		else
			UIErrorsFrame:AddMessage("选择暂无损失", 1.0, 1.0, 0.0, 53, 5)
		end
	else
		-- 打断治疗
		if self:StopHeal() then
			return true
		end

		-- 尽力治疗
		if self:EndeavorHeal(HealUnit()) then
			return true
		else
			UIErrorsFrame:AddMessage("选择暂无损失", 1.0, 1.0, 0.0, 53, 5)
		end
	end
	return false
end

-- 尝试尽力治疗队伍中生命损失最多的目标
-- @param number start = 4 起始生命损失百分比
-- @return boolean 成功返回true，否则返回false
function DaruidTree:HealParty(start)
	start = start or 4

	-- 打断治疗
	if self:StopHeal(start) then
		return true
	end
	
	-- 查找队伍损失
	local unit = self:FindParty(start)
	if unit then
		-- 尽力治疗
		return self:EndeavorHeal(unit)
	else
		UIErrorsFrame:AddMessage(string.format("队伍暂无损失(%s)", start), 1.0, 1.0, 0.0, 53, 5)
	end
	return false
end

-- 尝试节约治疗团队中生命损失最多的目标
-- @param number start = 6 起始生命损失百分比
-- @param number rank = 4 愈合法术等级
-- @return boolean 成功返回true，否则返回false
function DaruidTree:HealRaid(start, rank)
	start = start or 6
	rank = rank or 4

	-- 打断治疗
	if self:StopHeal(start) then
		return true
	end

	-- 查找团队损失
	local unit = self:FindRaid(start)
	if unit then
		-- 节约治疗
		return self:EconomizeHeal(unit, start, rank)
	else
		UIErrorsFrame:AddMessage(string.format("团队暂无损失(%s)", start), 1.0, 1.0, 0.0, 53, 5)
	end
	return false
end

-- 尝试治疗名单、团队、队伍、选择中生命损失最多的目标
-- @param number start = 2 起始生命损失百分比
-- @return boolean 成功返回true，否则返回false
function DaruidTree:HealRoster(start)
	start = start or 2

	-- 打断治疗
	if self:StopHeal(start) then
		return true
	end

	-- 补充名单增益
	if self:AddedBuff() then
		return true
	end

	-- 查找名单损失
	local name = self:FindRoster(start)
	if name then
		local unit = rosterLib:GetUnitIDFromName(name)
		if unit then
			-- 尽力治疗单位
			return self:EndeavorHeal(unit)
		elseif targetSwitch:ToName(name) then
			-- 尽力治疗目标
			local result = self:EndeavorHeal("target")
			targetSwitch:ToLast()
			return result
		end
	elseif UnitInRaid("player") then
		-- 治疗团队
		return self:HealRaid()
	elseif UnitInParty("player") then
		-- 治疗队伍
		return self:HealParty()
	elseif self:HealSelect() then
		-- 治疗选择
		return true
	else
		UIErrorsFrame:AddMessage(string.format("名单暂无损失(%s)", start), 1.0, 1.0, 0.0, 53, 5)
	end
	return false
end

-- 将目标加入或移除名单
function DaruidTree:Roster()
	if IsAltKeyDown() then
		-- 名单清空
		rosters = {}
		print("名单：已清空！")
	elseif UnitIsFriend("player", "target") then
		-- 名单增删
		-- 增删名称
		local name = UnitName("target")
		local index = InArray(rosters, name)
		if index then
			table.remove(rosters, index)
			print(string.format(
				"已将<%s>移出名单：%s",
				name,
				next(rosters) and table.concat(rosters, "；") or "空的！"
			))
		else
			table.insert(rosters, 1, name)
			print(string.format(
				"已将<%s>加入名单：%s",
				name,
				table.concat(rosters, "；")
			))
		end
	else
		-- 名单列出
		print(string.format(
			"名单：%s",
			next(rosters) and table.concat(rosters, "；") or "空的！"
		))
	end
end

-- 节能：对附近进入战斗目标施法精灵之火（按下ALT释放最高级），以此触发节能效果
function DaruidTree:EnergySaving()
	-- 打断施法
	SpellStopCasting()

	-- 检验效果
	if not effectCheck:FindName("节能施法") then
		-- 检验目标
		if UnitCanAttack("player", "target") and UnitAffectingCombat("target") then
			-- 释放精灵之火
			if IsAltKeyDown() then
				CastSpellByName("精灵之火")
			else
				CastSpellByName("精灵之火(等级 1)")
			end
		else
			-- 切换目标
			TargetNearestEnemy()
		end
	else
		UIErrorsFrame:AddMessage("节能已存在！", 1.0, 1.0, 0.0, 53, 5)
	end
end
