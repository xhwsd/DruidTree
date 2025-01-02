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

---位与数组
---@param array table 数组(索引表）
---@param data any 数据
---@return integer|nil index 成功返回索引，失败返回空
local function InArray(array, data)
	if type(array) == "table" then
		for index, value in ipairs(array) do
			if value == data then
				return index
			end
		end
	end
end

---取生命损失
---@param unit? string 单位；缺省为`player`
---@return integer percentage 生命损失百分比
---@return integer lose 生命损失
local function HealthLose(unit)
	unit = unit or "player"
	
	-- 生命上限
	local max = UnitHealthMax(unit)
	-- 生命损失
	local lose = max - UnitHealth(unit)
	-- 百分比 = 部分 / 整体 * 100
	return math.floor(lose / max * 100), lose
end

---取生命剩余
---@param unit? string 单位；缺省为`player`
---@return integer percentage 生命剩余百分比
---@return integer residual 生命剩余
local function HealthResidual(unit)
	unit = unit or "player"

	-- 生命剩余
	local residual = UnitHealth(unit)
	-- 百分比 = 部分 / 整体 * 100
	return math.floor(residual / UnitHealthMax(unit) * 100), residual
end

---适配治疗法术等级
---@param name string 法术名称；可选值：回春术、愈合
---@param health integer 目前失血
---@param unit? string 治疗单位
---@return string spell 法术名称(含等级)
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

	-- 最高等级
	return name
end  

---取治疗单位
---@param unit? string 单位；缺省为（友善目标 > 自己）
---@return string unit 单位
local function HealUnit(unit)
	-- 缺省单位
	if not unit then
		unit = UnitExists("target") and "target" or "player"
	end

	-- 友善目标 > 自己
	return UnitIsFriend("player", unit) and unit or "player"
end

---提示通知（注意）
---@param message string 提示信息
---@param... any 可变参数
local function HintNotice(message, ...)
	if arg.n then
		message = string.format(message, unpack(arg))
	end
	UIErrorsFrame:AddMessage(message, 0.0, 1.0, 0.0, 53, 5)
end

---提示警告
---@param message string 提示信息
---@param... any 可变参数
local function HintWarning(message, ...)
	if arg.n then
		message = string.format(message, unpack(arg))
	end
	UIErrorsFrame:AddMessage(message, 1.0, 1.0, 0.0, 53, 5)
end

---施放法术
---@param spell string 法术名称；可包含等级
---@param unit? string 目标单位
---@return boolean success 成功返回真，否则返回假
local function CastSpell(spell, unit)
	if not spell or spell == "" then
		return false
	end
	
	-- 指定单位
	if unit then
		if UnitIsUnit(unit, "player") then
			-- 自我施法
			HintNotice("对自己施放<%s>", spell)
			CastSpellByName(spell, 1)
			return true
		elseif targetSwitch:ToUnit(unit) then
			-- 目标施法
			HintNotice("对<%s>施放<%s>", UnitName(unit), spell)
			CastSpellByName(spell)
			targetSwitch:ToLast()
			return true
		else
			HintWarning("切换到单位<%s>施放<%s>失败", unit, spell)
			return false
		end
	else
		-- 未指定单位
		HintWarning("施放<%s>", spell)
		CastSpellByName(spell)
		return true
	end
end

---插件载入
function DaruidTree:OnInitialize()
	-- 精简标题
	self.title = "树德辅助"
	-- 开启调试
	self:SetDebugging(true)
	-- 调试等级
	self:SetDebugLevel(2)
end

---插件打开
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

---插件关闭
function DaruidTree:OnDisable()
	self:LevelDebug(3, "插件关闭")
end

---打断治疗
---@param start? integer 起始生命损失百分比；缺省为`0`
---@return boolean stop 已打断返回真，未打断返回假
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
			
			-- 检验生命损失
			if lose <= start then
				self:LevelDebug(3, "打断治疗；法术：%s；目标：%s；起始：%d；损失：%d", spell, target, start, lose)
				-- 打断施放
				SpellStopCasting()
				return true
			end
		end
	end
	return false
end

---检验单位可否治疗
---@param unit? string 治疗单位；缺省为`player`
---@return boolean can 是否可治疗
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
	if UnitIsUnit(unit, "player") then
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

	-- 取动作插槽
	local slot = spellSlot:FindSpell("愈合", "回春术", "治疗之触")
	if not slot then
		self:LevelDebug(2, "可否治疗，未在动作条找到40码法术")
		-- 让法术判断
		return true
	end

	-- 法术范围内（40码）
	if targetSwitch:ToUnit(unit) then
		local satisfy = IsActionInRange(slot) == 1
		targetSwitch:ToLast()
		return satisfy
	else
		self:LevelDebug(2, "可否治疗，切换到单位失败；单位：%s", unit)
		-- 让法术判断
		return true
	end
end

-- 过量治疗单位
---@param unit? string 目标单位；缺省为`HealUnit(unit)`
---@param swiftness? integer 剩余生命等于或小于该百分比时，使用自然迅捷；缺省为`40`
---@param swiftmend? integer 损失生命大于或等于该值时，使用迅捷治愈；缺省为`1500`
---@return boolean success 成功返回真，否则返回假
function DaruidTree:OverdoseHeal(unit, swiftness, swiftmend)
	unit = HealUnit(unit)
	swiftness = swiftness or 40
	swiftmend = swiftmend or 1500

	-- 可否治疗
	if not self:CanHeal(unit) then
		self:LevelDebug(3, "过量治疗，不可治疗；目标：%s", UnitName(unit))
		return false
	end

	-- 过量治疗
	local lose, health = HealthLose(unit)
	self:LevelDebug(3, "过量治疗；目标：%s；损失：%d", UnitName(unit), lose)
	if effectCheck:FindName("自然迅捷") then
		CastSpell("愈合", unit)
	elseif HealthResidual(unit) <= swiftness and spellCheck:IsReady("自然迅捷") then
		CastSpell("自然迅捷")
	elseif health >= swiftmend and spellCheck:IsReady("迅捷治愈") and (effectCheck:FindName("愈合", unit) or effectCheck:FindName("回春术", unit)) then
		CastSpell("迅捷治愈", unit)
	elseif not effectCheck:FindName("回春术", unit) then
		CastSpell("回春术", unit)
	else
		CastSpell("愈合", unit)
	end
	return true
end

---节省治疗单位
---@param unit? string 目标单位；缺省为`HealUnit(unit)`
---@param start? integer 起始生命损失百分比；缺省为`6`
---@param rank? integer 愈合法术等级；缺省为`4`
---@param swiftness? integer 剩余生命等于或小于该百分比时，使用自然迅捷；缺省为`40`
---@param swiftmend? integer 损失生命大于或等于该值时，使用迅捷治愈；缺省为`1500`
---@return boolean success 成功返回真，否则返回假
function DaruidTree:EconomizeHeal(unit, start, rank, swiftness, swiftmend)
	unit = HealUnit(unit)
	start = start or 6
	rank = rank or 4
	swiftness = swiftness or 40
	swiftmend = swiftmend or 1500

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
		CastSpell(AdaptRank("愈合", health, unit), unit)
	elseif HealthResidual(unit) <= swiftness and spellCheck:IsReady("自然迅捷") then
		CastSpell("自然迅捷")
	elseif health >= swiftmend and spellCheck:IsReady("迅捷治愈") and (effectCheck:FindName("愈合", unit) or effectCheck:FindName("回春术", unit)) then
		CastSpell("迅捷治愈", unit)
	else
		CastSpell(string.format("愈合(等级 %d)", rank), unit) 
	end
	return true
end

---尽力治疗单位
---@param unit? string 目标单位；缺省为`HealUnit(unit)`
---@param swiftness? integer 剩余生命等于或小于该百分比时，使用自然迅捷；缺省为`40`
---@param swiftmend? integer 损失生命大于或等于该值时，使用迅捷治愈；缺省为`1500`
---@return boolean success 成功返回真，否则返回假
function DaruidTree:EndeavorHeal(unit, swiftness, swiftmend)
	unit = HealUnit(unit)
	swiftness = swiftness or 40
	swiftmend = swiftmend or 1500

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
		CastSpell(AdaptRank("愈合", health, unit), unit)
	elseif HealthResidual(unit) <= swiftness and spellCheck:IsReady("自然迅捷") then
		CastSpell("自然迅捷")
	elseif health >= swiftmend and spellCheck:IsReady("迅捷治愈") and (effectCheck:FindName("愈合", unit) or effectCheck:FindName("回春术", unit)) then
		CastSpell("迅捷治愈", unit)
	elseif not effectCheck:FindName("回春术", unit) then
		CastSpell(AdaptRank("回春术", health, unit), unit)
	else
		CastSpell(AdaptRank("愈合", health, unit), unit)
	end
	return true
end

---查找队伍中损失最多单位
---@param start? integer 起始损失百分比；缺省为`4`
---@return string|nil target 已找到返回单位，未找到否则返回空
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
---@param start? integer 起始生命损失百分比；缺省为`6`
---@return string|nil target 已找到返回单位，未找到否则返回空
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

---查找名单中损失最多名称
---@param start? integer 起始生命损失百分比；缺省为`2`
---@return string|nil target 已找到返回单位，未找到否则返回空
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

---补充名单增益
---@param buff? string 增益名称；缺省为`回春术`
---@param spell? string 法术名称；缺省为`buff`
---@return string|nil target 已补返回名称，未补返回空
function DaruidTree:AddedBuff(buff, spell)
	buff = buff or "回春术"
	spell = spell or buff

	-- 名单查找
	for _, name in ipairs(rosters) do
		local unit = rosterLib:GetUnitIDFromName(name)
		if unit then
			if not effectCheck:FindName(buff, unit) and self:CanHeal(unit) then
				-- 补充增益
				self:LevelDebug(3, "补充名单增益；目标：%s；法术：%s", UnitName(unit), spell)   
				CastSpell(spell, unit)
				return name
			end
		elseif targetSwitch:ToName(name) then
			if not effectCheck:FindName(buff, "target") and self:CanHeal("target") then
				-- 补充增益
				self:LevelDebug(3, "补充名单增益；目标：%s；法术：%s", UnitName("target"), spell)  
				CastSpell(spell, "target")
				targetSwitch:ToLast()
				return name
			else
				targetSwitch:ToLast()
			end
		end
	end
end

---尝试治疗选择目标
---@param swiftness? integer 剩余生命等于或小于该百分比时，使用自然迅捷；缺省为`40`
---@param swiftmend? integer 损失生命大于或等于该值时，使用迅捷治愈；缺省为`1500`
---@return boolean success 成功返回真，否则返回假
function DaruidTree:HealSelect(swiftness, swiftmend)
	swiftness = swiftness or 40
	swiftmend = swiftmend or 1500

	-- 按下ALT
	if IsAltKeyDown() then
		-- 过量治疗
		if self:OverdoseHeal(HealUnit(), swiftness, swiftmend) then
			return true
		else
			HintWarning("选择暂无损失")
		end
	else
		-- 打断治疗
		if self:StopHeal() then
			return true
		end

		-- 尽力治疗
		if self:EndeavorHeal(HealUnit(), swiftness, swiftmend) then
			return true
		else
			HintWarning("选择暂无损失")
		end
	end
	return false
end

---尝试尽力治疗队伍中生命损失最多的目标
---@param start? integer 起始生命损失百分比；缺省为`4`
---@param swiftness? integer 剩余生命等于或小于该百分比时，使用自然迅捷；缺省为`40`
---@param swiftmend? integer 损失生命大于或等于该值时，使用迅捷治愈；缺省为`1500`
---@return boolean success 成功返回真，否则返回假
function DaruidTree:HealParty(start, swiftness, swiftmend)
	start = start or 4
	swiftness = swiftness or 40
	swiftmend = swiftmend or 1500

	-- 打断治疗
	if self:StopHeal(start) then
		return true
	end

	-- 查找队伍损失
	local unit = self:FindParty(start)
	if unit then
		-- 尽力治疗
		return self:EndeavorHeal(unit, swiftness, swiftmend)
	else
		HintWarning("队伍暂无损失(%s)", start)
	end
	return false
end

---尝试节约治疗团队中生命损失最多的目标
---@param start? integer 起始生命损失百分比；缺省为`6`
---@param rank? integer 愈合法术等级；缺省为`4`
---@param swiftness? integer 剩余生命等于或小于该百分比时，使用自然迅捷；缺省为`40`
---@param swiftmend? integer 损失生命大于或等于该值时，使用迅捷治愈；缺省为`1500`
---@return boolean success 成功返回真，否则返回假
function DaruidTree:HealRaid(start, rank, swiftness, swiftmend)
	start = start or 6
	rank = rank or 4
	swiftness = swiftness or 40
	swiftmend = swiftmend or 1500

	-- 打断治疗
	if self:StopHeal(start) then
		return true
	end

	-- 查找团队损失
	local unit = self:FindRaid(start)
	if unit then
		-- 节约治疗
		return self:EconomizeHeal(unit, start, rank, swiftness, swiftmend)
	else
		HintWarning("团队暂无损失(%s)", start)
	end
	return false
end

---尝试治疗名单、团队、队伍、选择中生命损失最多的目标
---@param start? integer 起始生命损失百分比；缺省为`2`
---@param swiftness? integer 剩余生命等于或小于该百分比时，使用自然迅捷；缺省为`40`
---@param swiftmend? integer 损失生命大于或等于该值时，使用迅捷治愈；缺省为`1500`
---@return boolean success 成功返回真，否则返回假
function DaruidTree:HealRoster(start, swiftness, swiftmend)
	start = start or 2
	swiftness = swiftness or 40
	swiftmend = swiftmend or 1500

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
			return self:EndeavorHeal(unit, swiftness, swiftmend)
		elseif targetSwitch:ToName(name) then
			-- 尽力治疗目标
			local result = self:EndeavorHeal("target", swiftness, swiftmend)
			targetSwitch:ToLast()
			return result
		end
	elseif UnitInRaid("player") then
		-- 治疗团队
		return self:HealRaid(nil, nil, swiftness, swiftmend)
	elseif UnitInParty("player") then
		-- 治疗队伍
		return self:HealParty(nil, swiftness, swiftmend)
	elseif self:HealSelect() then
		-- 治疗选择
		return true
	else
		HintWarning("名单暂无损失(%s)", start)
	end
	return false
end

---将目标加入或移除名单
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

---节能：对附近进入战斗目标施法精灵之火（按下ALT释放最高级），以此触发节能效果
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
		HintWarning("节能已存在！")
	end
end
