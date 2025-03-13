-- 非德鲁伊退出运行
local _, playerClass = UnitClass("player")
if playerClass ~= "DRUID" then
	return
end

-- 定义插件
DruidTree = AceLibrary("AceAddon-2.0"):new(
	-- 控制台
	"AceConsole-2.0",
	-- 调试
	"AceDebug-2.0",
	-- 数据库
	"AceDB-2.0", 
	-- 小地图菜单
	"FuBarPlugin-2.0"
)
-- DruidTree.hasIcon = "Interface\\Icons\\Ability_Druid_ForceofNature"
-- DruidTree.defaultPosition = "LEFT"
-- DruidTree.defaultMinimapPosition = 210
-- DruidTree.cannotDetachTooltip = true
-- DruidTree.tooltipHiddenWhenEmpty = true
-- DruidTree.hideWithoutStandby = true
-- DruidTree.clickableTooltip = false
-- DruidTree.hasNoColor = true

-- 提示
local Tablet = AceLibrary("Tablet-2.0")
-- 名单库（团队/队伍）
local RosterLib = AceLibrary("RosterLib-2.0")

---@type Wsd-Array-1.0
local Array = AceLibrary("Wsd-Array-1.0")
---@type Wsd-Health-1.0
local Health = AceLibrary("Wsd-Health-1.0")
---@type Wsd-Prompt-1.0
local Prompt = AceLibrary("Wsd-Prompt-1.0")
---@type Wsd-Effect-1.0
local Effect = AceLibrary("Wsd-Effect-1.0")
---@type Wsd-Spell-1.0
local Spell = AceLibrary("Wsd-Spell-1.0")
---@type Wsd-Slot-1.0
local Slot = AceLibrary("Wsd-Slot-1.0")
---@type Wsd-Target-1.0
local Target = AceLibrary("Wsd-Target-1.0")
---@type Wsd-CastStatus-1.0
local CastStatus = AceLibrary("Wsd-CastStatus-1.0")

-- 插件载入
function DruidTree:OnInitialize()
	-- 简洁标题
	self.title = "树德"
	-- 开启调试
	self:SetDebugging(true)
	-- 调试等级
	self:SetDebugLevel(3)
	-- 具体图标
	self.hasIcon = true
	-- 小地图图标
	self:SetIcon("Interface\\Icons\\Ability_Druid_ForceofNature")
	-- 角色独立配置
	-- self.independentProfile = true
	-- 挂载时是否隐藏
	-- self.hideWithoutStandby = false
	-- self:UpdateTooltip()
end

-- 插件打开
function DruidTree:OnEnable()
	self:LevelDebug(3, "插件打开")
	-- 注册数据
	self:RegisterDB("DruidTreeDB")
	-- 注册默认值
	self:RegisterDefaults('profile', {
		-- 治疗选择
		select = {
			-- 打断
			interrupt = true,
			-- 起始
			start = 2
		},
		-- 治疗名单
		roster = {
			-- 打断
			interrupt = true,
			-- 起始
			start = 2,
			-- 回春术
			rejuvenation = true
		},
		-- 治疗队伍
		party = {
			-- 打断
			interrupt = true,
			-- 起始
			start = 4
		},
		-- 治疗团队
		raid = {
			-- 打断
			interrupt = true,
			-- 起始
			start = 4
		},

		-- 过量治疗
		overdose = {
			-- 迅捷治愈
			swiftmend = 1000,
			-- 自然迅捷
			swiftness = 50
		},
		-- 尽力治疗
		endeavor = {
			-- 迅捷治愈
			swiftmend = 2000,
			swiftness = 40
		},
		-- 节省治疗
		economize = {
			-- 迅捷治愈
			swiftmend = 3000,
			-- 自然迅捷
			swiftness = 30,
			-- 愈合
			regrowth = 4
		},

		-- 显示窗口
		show = true,
		-- 名单列表
		rosters = {},
	})
	-- 注册菜单项
	self.OnMenuRequest = {
		type = "group",
		handler = self,
		args = {
			-- 治疗
			select = {
				type = "group",
				name = "治疗选择",
				desc = "治疗选择时，按住ALT过量治疗，否则尽力治疗",
				order = 1,
				args = {
					interrupt = {
						type = "toggle",
						name = "打断治疗",
						desc = "是否打断过量治疗，仅在过量治疗时忽略",
						order = 1,
						get = function()
							return self.db.profile.select.interrupt
						end,
						set = function(value)
							self.db.profile.select.interrupt = value
						end
					},
					start = {
						type = "range",
						name = "起始损失",
						desc = "损失百分比大于或等于该值时治疗，仅在过量治疗时忽略",
						order = 2,
						min = 0,
						max = 100,
						get = function()
							return self.db.profile.select.start
						end,
						set = function(value)
							self.db.profile.select.start = value
						end
					},
				}
			},
			roster = {
				type = "group",
				name = "治疗名单",
				desc = "治疗队伍时尽力治疗",
				order = 2,
				args = {
					interrupt = {
						type = "toggle",
						name = "打断治疗",
						desc = "是否打断过量治疗",
						order = 1,
						get = function()
							return self.db.profile.roster.interrupt
						end,
						set = function(value)
							self.db.profile.roster.interrupt = value
						end
					},
					start = {
						type = "range",
						name = "起始损失",
						desc = "损失百分比大于或等于该值时治疗",
						order = 2,
						min = 0,
						max = 100,
						get = function()
							return self.db.profile.roster.start
						end,
						set = function(value)
							self.db.profile.roster.start = value
						end
					},
					rejuvenation = {
						type = "toggle",
						name = "补回春术",
						desc = "是否补回春术",
						order = 3,
						get = function()
							return self.db.profile.roster.rejuvenation
						end,
						set = function(value)
							self.db.profile.roster.rejuvenation = value
						end
					}
				}
			},
			party = {
				type = "group",
				name = "治疗队伍",
				desc = "治疗队伍时尽力治疗",
				order = 3,
				args = {
					interrupt = {
						type = "toggle",
						name = "打断治疗",
						desc = "是否打断过量治疗",
						order = 1,
						get = function()
							return self.db.profile.party.interrupt
						end,
						set = function(value)
							self.db.profile.party.interrupt = value
						end
					},
					start = {
						type = "range",
						name = "起始损失",
						desc = "损失百分比大于或等于该值时治疗",
						order = 2,
						min = 0,
						max = 100,
						get = function()
							return self.db.profile.party.start
						end,
						set = function(value)
							self.db.profile.party.start = value
						end
					}
				}
			},
			raid = {
				type = "group",
				name = "治疗团队",
				desc = "治疗团队时节省治疗",
				order = 4,
				args = {
					interrupt = {
						type = "toggle",
						name = "打断治疗",
						desc = "是否打断过量治疗",
						order = 1,
						get = function()
							return self.db.profile.raid.interrupt
						end,
						set = function(value)
							self.db.profile.raid.interrupt = value
						end
					},
					start = {
						type = "range",
						name = "起始损失",
						desc = "损失百分比大于或等于该值时治疗",
						order = 2,
						min = 0,
						max = 100,
						get = function()
							return self.db.profile.raid.start
						end,
						set = function(value)
							self.db.profile.raid.start = value
						end
					},
				}
			},
			-- 模式
			overdose = {
				type = "group",
				name = "过量治疗",
				desc = "治疗选择时使用",
				order = 5,
				args = {
					swiftmend = {
						type = "text",
						name = "迅捷治愈",
						desc = "损失大于或等于该值时使用",
						order = 1,
						usage = "请输入大于或等于 0 的整数",
						get = function()
							return self.db.profile.overdose.swiftmend
						end,
						set = function(value)
							local number = tonumber(value)
							if type(number) == "number" and number >= 0 then
								self.db.profile.overdose.swiftmend = math.floor(number)
							else
								Prompt:Error("请输入大于或等于 0 的整数")
							end
						end
					},
					swiftness = {
						type = "range",
						name = "自然迅捷",
						desc = "剩余百分比小于或等于该值时使用",
						order = 2,
						min = 0,
						max = 100,
						get = function()
							return self.db.profile.overdose.swiftness
						end,
						set = function(value)
							self.db.profile.overdose.swiftness = value
						end
					}
				}
			},
			endeavor = {
				type = "group",
				name = "尽力治疗",
				desc = "治疗选择、名单、队伍时使用",
				order = 6,
				args = {
					swiftmend = {
						type = "text",
						name = "迅捷治愈",
						desc = "损失大于或等于该值时使用",
						order = 1,
						usage = "请输入大于或等于 0 的整数",
						get = function()
							return self.db.profile.endeavor.swiftmend
						end,
						set = function(value)
							local number = tonumber(value)
							if type(number) == "number" and number >= 0 then
								self.db.profile.endeavor.swiftmend = math.floor(number)
							else
								Prompt:Error("请输入大于或等于 0 的整数")
							end
						end
					},
					swiftness = {
						type = "range",
						name = "自然迅捷",
						desc = "剩余百分比小于或等于该值时使用",
						order = 2,
						min = 0,
						max = 100,
						get = function()
							return self.db.profile.endeavor.swiftness
						end,
						set = function(value)
							self.db.profile.endeavor.swiftness = value
						end
					}
				}
			},
			economize = {
				type = "group",
				name = "节省治疗",
				desc = "治疗团队时使用",
				order = 7,
				args = {
					swiftmend = {
						type = "text",
						name = "迅捷治愈",
						desc = "损失大于或等于该值时使用",
						order = 1,
						usage = "请输入大于或等于 0 的整数",
						get = function()
							return self.db.profile.economize.swiftmend
						end,
						set = function(value)
							local number = tonumber(value)
							if type(number) == "number" and number >= 0 then
								self.db.profile.economize.swiftmend = math.floor(number)
							else
								Prompt:Error("请输入大于或等于 0 的整数")
							end
						end
					},
					swiftness = {
						type = "range",
						name = "自然迅捷",
						desc = "剩余百分比小于或等于该值时使用",
						order = 2,
						min = 0,
						max = 100,
						get = function()
							return self.db.profile.economize.swiftness
						end,
						set = function(value)
							self.db.profile.economize.swiftness = value
						end
					},
					regrowth = {
						type = "range",
						name = "愈合",
						desc = "限定愈合的法术等级",
						order = 3,
						min = 1,
						max = 8,
						get = function()
							return self.db.profile.economize.regrowth
						end,
						set = function(value)
							self.db.profile.economize.regrowth = value
						end
					}
				}
			},
			-- 其它
			debug = {
				type = "toggle",
				name = "调试模式",
				desc = "开启或关闭调试模式",
				order = 8,
				get = "IsDebugging",
				set = "SetDebugging"
			},	
			level = {
				type = "range",
				name = "调试等级",
				desc = "设置或获取调试等级",
				order = 9,
				min = 1,
				max = 3,
				get = "GetDebugLevel",
				set = "SetDebugLevel"
			}
		}
	}
end

-- 插件关闭
function DruidTree:OnDisable()
	self:LevelDebug(3, "插件关闭")
end

-- 取标题
function DruidTree:GetTitle()
	-- 置小地图图标点燃标题
	return "树德 v" .. GetAddOnMetadata("DruidTree", "Version")
end

-- 提示更新
function DruidTree:OnTooltipUpdate()
	-- 置小地图图标点燃提示
	Tablet:SetHint("\n鼠标左键 - 显示治疗名单\n鼠标右键 - 显示插件选项")
end

-- 小地图点击
function DruidTree:OnClick(button)
	if button == "LeftButton" then
		-- 左键显示或隐藏名单窗口
		if DruidTreeRosterFrame:IsVisible() then
			DruidTreeRosterFrame:Hide()
			self.db.profile.show = false
		else
			DruidTreeRosterFrame:Show()
			self.db.profile.show = true
		end
	end
end

-- 到治疗单位
---@param unit? string 单位；缺省为（友善目标 > 自己）
---@return string unit 单位
function DruidTree:ToHealUnit(unit)
	-- 缺省单位
	if not unit then
		unit = UnitExists("target") and "target" or "player"
	end

	-- 友善目标 > 自己
	return UnitIsFriend("player", unit) and unit or "player"
end

-- 适配治疗法术等级
---@param name string 法术名称；可选值：回春术、愈合
---@param health integer 目前失血
---@param unit? string 治疗单位
---@return string spell 法术名称(含等级)
function DruidTree:AdaptRank(name, health, unit)
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

-- 施放法术
---@param spell string 法术名称；可包含等级
---@param unit? string 目标单位
---@return boolean success 成功返回真，否则返回假
function DruidTree:CastSpell(spell, unit)
	if not spell or spell == "" then
		return false
	end
	
	-- 指定单位
	if unit then
		if UnitIsUnit(unit, "player") then
			-- 自我施法
			Prompt:Info("对自己施放<%s>", spell)
			CastSpellByName(spell, 1)
			return true
		elseif Target:ToUnit(unit) then
			-- 目标施法
			Prompt:Info("对<%s>施放<%s>", UnitName(unit), spell)
			CastSpellByName(spell)
			Target:ToLast()
			return true
		else
			Prompt:Warning("切换到单位<%s>施放<%s>失败", unit, spell)
			return false
		end
	else
		-- 未指定单位
		Prompt:Warning("施放<%s>", spell)
		CastSpellByName(spell)
		return true
	end
end

-- 打断治疗
---@param start? integer 起始生命损失百分比；缺省为`0`
---@return boolean stop 已打断返回真，未打断返回假
function DruidTree:InterruptHeal(start)
	start = start or 0

	-- 正在施法中
	local casting, spell, target = CastStatus:GetStatus()
	if casting then
		-- 匹配法术
		if Array:InList({"愈合", "治疗之触"}, spell) then
			-- 取生命损失
			local lose = 0
			if target == UnitName("player") then
				-- 自己
				lose = Health:GetLose("player")
			else
				local unit = RosterLib:GetUnitIDFromName(target)
				if unit then
					-- 单位
					lose = Health:GetLose(unit)
				elseif Target:ToName(target) then
					-- 名称
					lose = Health:GetLose("target")
					Target:ToLast()
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

-- 检验单位可否治疗
---@param unit? string 治疗单位；缺省为`player`
---@return boolean can 是否可治疗
function DruidTree:CanHeal(unit)
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
	local slot = Slot:FindSpell("愈合", "回春术", "治疗之触")
	if not slot then
		self:LevelDebug(2, "可否治疗，未在动作条找到40码法术")
		-- 让法术判断
		return true
	end

	-- 法术范围内（40码）
	if Target:ToUnit(unit) then
		local satisfy = IsActionInRange(slot) == 1
		Target:ToLast()
		return satisfy
	else
		self:LevelDebug(2, "可否治疗，切换到单位失败；单位：%s", unit)
		-- 让法术判断
		return true
	end
end

-- 过量治疗单位
---@param unit? string 目标单位；缺省为`self:ToHealUnit(unit)`
---@return boolean success 成功返回真，否则返回假
function DruidTree:OverdoseHeal(unit)
	unit = self:ToHealUnit(unit)

	-- 可否治疗
	if not self:CanHeal(unit) then
		self:LevelDebug(3, "过量治疗，不可治疗；目标：%s", UnitName(unit))
		return false
	end

	-- 过量治疗
	local percentage, lose = Health:GetLose(unit)
	self:LevelDebug(3, "过量治疗；目标：%s；损失：%d", UnitName(unit), percentage)
	if Effect:FindName("自然迅捷") then
		self:CastSpell("愈合", unit)
	elseif lose >= self.db.profile.overdose.swiftmend and Spell:IsReady("迅捷治愈") and (Effect:FindName("愈合", unit) or Effect:FindName("回春术", unit)) then
		self:CastSpell("迅捷治愈", unit)
	elseif Health:GetRemaining(unit) <= self.db.profile.overdose.swiftness and Spell:IsReady("自然迅捷") then
		self:CastSpell("自然迅捷")
	elseif not Effect:FindName("回春术", unit) then
		self:CastSpell("回春术", unit)
	else
		self:CastSpell("愈合", unit)
	end
	return true
end

-- 尽力治疗单位
---@param start? integer 起始损失百分比；缺省为`2`
---@param unit? string 目标单位；缺省为`self:ToHealUnit(unit)`
---@return boolean success 成功返回真，否则返回假
function DruidTree:EndeavorHeal(start, unit)
	start = start or 2
	unit = self:ToHealUnit(unit)

	-- 可否治疗
	if not self:CanHeal(unit) then
		self:LevelDebug(3, "尽力治疗，不可治疗；目标：%s", UnitName(unit))
		return false
	end

	-- 生命损失
	local percentage, lose = Health:GetLose(unit)
	if percentage < start then
		self:LevelDebug(3, "尽力治疗，未达到起始损失；目标：%s；起始：%d；损失：%d", UnitName(unit), start, percentage)
		return false
	end

	-- 尽力治疗
	self:LevelDebug(3, "尽力治疗；目标：%s；起始：%d；损失：%d", UnitName(unit), start, percentage)
	if Effect:FindName("自然迅捷", "player") then
		self:CastSpell(self:AdaptRank("愈合", lose, unit), unit)
	elseif lose >= self.db.profile.endeavor.swiftmend and Spell:IsReady("迅捷治愈") and (Effect:FindName("愈合", unit) or Effect:FindName("回春术", unit)) then
		self:CastSpell("迅捷治愈", unit)
	elseif Health:GetRemaining(unit) <= self.db.profile.endeavor.swiftness and Spell:IsReady("自然迅捷") then
		self:CastSpell("自然迅捷")
	elseif not Effect:FindName("回春术", unit) then
		self:CastSpell(self:AdaptRank("回春术", lose, unit), unit)
	else
		self:CastSpell(self:AdaptRank("愈合", lose, unit), unit)
	end
	return true
end

-- 节省治疗单位
---@param start? integer 起始损失百分比；缺省为`4`
---@param unit? string 目标单位；缺省为`self:ToHealUnit(unit)`
---@return boolean success 成功返回真，否则返回假
function DruidTree:EconomizeHeal(start, unit)
	start = start or 4
	unit = self:ToHealUnit(unit)

	-- 可否治疗
	if not self:CanHeal(unit) then
		self:LevelDebug(3, "节省治疗，不可治疗；目标：%s", UnitName(unit))
		return false
	end

	-- 生命损失
	local percentage, lose = Health:GetLose(unit)
	if percentage < start then
		self:LevelDebug(3, "节省治疗，未达到起始损失；目标：%s；起始：%d；损失：%d", UnitName(unit), start, percentage)
		return false
	end

	-- 节省治疗
	self:LevelDebug(3, "节省治疗；目标：%s；起始：%d；损失：%d", UnitName(unit), start, percentage)
	if Effect:FindName("自然迅捷", "player") then
		self:CastSpell(self:AdaptRank("愈合", lose, unit), unit)
	elseif lose >= self.db.profile.economize.swiftmend and Spell:IsReady("迅捷治愈") and (Effect:FindName("愈合", unit) or Effect:FindName("回春术", unit)) then
		self:CastSpell("迅捷治愈", unit)
	elseif Health:GetRemaining(unit) <= self.db.profile.economize.swiftness and Spell:IsReady("自然迅捷") then
		self:CastSpell("自然迅捷")
	else
		self:CastSpell(string.format("愈合(等级 %d)", self.db.profile.economize.regrowth), unit) 
	end
	return true
end

-- 查找名单中损失最多名称
---@param start? integer 起始生命损失百分比；缺省为`2`
---@return string target 已找到返回单位，未找到否则返回空
function DruidTree:FindRoster(start)
	start = start or 2

	-- 名单查找
	local max, target = 0
	for _, name in ipairs(self.db.profile.rosters) do
		local unit = RosterLib:GetUnitIDFromName(name)
		if unit then
			-- 单位匹配
			local lose = Health:GetLose(unit)
			if lose >= start and lose > max and self:CanHeal(unit) then
				max = lose
				target = name
			end
		elseif Target:ToName(name) then
			-- 名称匹配
			local lose = Health:GetLose("target")
			if lose >= start and lose > max and self:CanHeal("target") then
				max = lose
				target = name
			end
			Target:ToLast()
		end 
	end
	return target
end

-- 查找队伍中损失最多单位
---@param start? integer 起始损失百分比；缺省为`4`
---@return string target 已找到返回单位，未找到否则返回空
function DruidTree:FindParty(start)
	start = start or 4

	-- 检验自己（优先）
	local unit = "player"
	local lose = Health:GetLose(unit)
	local max, target = 0
	if lose >= start then
		max = lose
		target = unit
	end

	-- 查找队伍（不含自己）
	for index = GetNumPartyMembers(), 1, -1 do
		unit = "party" .. index
		lose = Health:GetLose(unit)
		if lose >= start and lose > max and self:CanHeal(unit) then
			max = lose
			target = unit
		end
	end
	return target
end

-- 查找团队中损失最多单位
---@param start? integer 起始生命损失百分比；缺省为`6`
---@return string target 已找到返回单位，未找到否则返回空
function DruidTree:FindRaid(start)
	start = start or 6

	-- 团队查找
	local max, target = 0
	for index = GetNumRaidMembers(), 1, -1 do
		local unit = "raid" .. index
		local lose = Health:GetLose(unit)
		if lose >= start and lose > max and self:CanHeal(unit) then
			max = lose
			target = unit
		end
	end
	return target
end

-- 补充名单增益
---@param buff? string 增益名称；缺省为`回春术`
---@param spell? string 法术名称；缺省为`buff`
---@return string target 已补返回名称，未补返回空
function DruidTree:AddedBuff(buff, spell)
	buff = buff or "回春术"
	spell = spell or buff

	-- 名单查找
	for _, name in ipairs(self.db.profile.rosters) do
		local unit = RosterLib:GetUnitIDFromName(name)
		if unit then
			if not Effect:FindName(buff, unit) and self:CanHeal(unit) then
				-- 补充增益
				self:LevelDebug(3, "补充名单增益；目标：%s；法术：%s", UnitName(unit), spell)   
				self:CastSpell(spell, unit)
				return name
			end
		elseif Target:ToName(name) then
			if not Effect:FindName(buff, "target") and self:CanHeal("target") then
				-- 补充增益
				self:LevelDebug(3, "补充名单增益；目标：%s；法术：%s", UnitName("target"), spell)  
				self:CastSpell(spell, "target")
				Target:ToLast()
				return name
			else
				Target:ToLast()
			end
		end
	end
end

-- 尝试治疗选择目标
---@return boolean success 成功返回真，否则返回假
function DruidTree:HealSelect()
	-- 按下ALT
	if IsAltKeyDown() then
		-- 过量治疗
		if self:OverdoseHeal() then
			return true
		end
	else
		-- 打断治疗
		if self.db.profile.select.interrupt and self:InterruptHeal() then
			return true
		end

		-- 尽力治疗
		if self:EndeavorHeal(self.db.profile.select.start) then
			return true
		end
	end
	return false
end

-- 尝试治疗名单中生命损失最多的目标
---@return boolean success 成功返回真，否则返回假
function DruidTree:HealRoster()
	-- 打断治疗
	if self.db.profile.roster.interrupt and self:InterruptHeal() then
		return true
	end

	-- 补充名单增益
	if self.db.profile.roster.rejuvenation and self:AddedBuff() then
		return true
	end

	-- 查找名单损失
	local start = self.db.profile.roster.start
	local name = self:FindRoster(start)
	if name then
		local unit = RosterLib:GetUnitIDFromName(name)
		if unit then
			-- 尽力治疗单位
			return self:EndeavorHeal(start, unit)
		elseif Target:ToName(name) then
			-- 尽力治疗目标
			local result = self:EndeavorHeal(start, "target")
			Target:ToLast()
			return result
		end
	end
	return false
end

-- 尝试尽力治疗队伍中生命损失最多的目标
---@return boolean success 成功返回真，否则返回假
function DruidTree:HealParty()
	-- 打断治疗
	if self.db.profile.party.interrupt and self:InterruptHeal() then
		return true
	end

	-- 查找队伍损失
	local start = self.db.profile.party.start
	local unit = self:FindParty(start)
	if unit then
		-- 尽力治疗
		return self:EndeavorHeal(start, unit)
	end
	return false
end

-- 尝试节约治疗团队中生命损失最多的目标
---@return boolean success 成功返回真，否则返回假
function DruidTree:HealRaid()
	-- 打断治疗
	if self.db.profile.raid.interrupt and self:InterruptHeal() then
		return true
	end

	-- 查找团队损失
	local start = self.db.profile.raid.start
	local unit = self:FindRaid(start)
	if unit then
		-- 节约治疗
		return self:EconomizeHeal(start, unit)
	end
	return false
end

-- 尝试治疗名单、团队、队伍、选择中生命损失最多的目标
---@return boolean success 成功返回真，否则返回假
function DruidTree:Heal()
	if self:HealRoster() then
		-- 治疗名单
		return true
	elseif UnitInRaid("player") and self:HealRaid() then
		-- 治疗团队
		return true
	elseif UnitInParty("player") and self:HealParty() then
		-- 治疗队伍
		return true
	elseif self:HealSelect() then
		-- 治疗选择
		return true
	end
	return false
end

-- 载入名单框架
function DruidTree:OnLoadRosterFrame(this)
	-- 初始显示仓库
	if self.db.profile.show then
		DruidTreeRosterFrame:Show()
	end
end

-- 更新名单框架
function DruidTree:OnUpdateRosterFrame(this)
	local parentName = this:GetName()
	local UpButton = getglobal(parentName .. "UpButton")
	local DownButton = getglobal(parentName .. "DownButton")
	local size = table.getn(self.db.profile.rosters)
	if (size < 11) then
		-- 不足多页
		this.Offset = 0
		UpButton:Hide()
		DownButton:Hide()
	else
		if (this.Offset <= 0) then
			-- 首页
			this.Offset = 0
			UpButton:Hide()
			DownButton:Show()
		elseif (this.Offset >= (size - 10)) then
			-- 尾页
			this.Offset = (size - 10)
			UpButton:Show()
			DownButton:Hide()
		else
			-- 中页
			UpButton:Show()
			DownButton:Show()
		end
	end

	for index = 1, 10 do
		local RosterButton = getglobal(parentName .. "RosterButton" .. index)
		RosterButton:SetID(index + this.Offset)
		RosterButton.UpdateYourself = true
		if (index <= size) then
			RosterButton:Show()
		else
			RosterButton:Hide()
		end
	end
end

-- 单击加入按钮
function DruidTree:OnClickJoinButton(this)
	if UnitIsFriend("player", "target") then
		local name = UnitName("target")
		if Array:InList(self.db.profile.rosters, name) then
			Prompt:Warning("<%s>已在名单中", name)
		else
			table.insert(self.db.profile.rosters, name)
			DruidTreeRosterFrame.UpdateYourself = true
			Prompt:Info("已将<%s>加入名单", name)
		end
	else
		Prompt:Error("请选择友善目标")
	end
end

-- 单击清空按钮
function DruidTree:OnClickClearButton(this)
	self.db.profile.rosters = {}
	DruidTreeRosterFrame.UpdateYourself = true
	Prompt:Info("已清空名单")
end

-- 更新名单按钮
function DruidTree:OnUpdateRosterButton(this)
	local parentName = this:GetName()
	local NameText = getglobal(parentName .. "NameText")
	local index = tonumber(this:GetID())
	local name = self.db.profile.rosters[index]
	if name then
		NameText:SetText(index .. " - " .. name)
	else
		NameText:SetText("错误 - 索引异常")
	end
end

-- 单击名单按钮
function DruidTree:OnClickRosterButton(this)
	local index = tonumber(this:GetID())
	local name = self.db.profile.rosters[index]
	if name then
		table.remove(self.db.profile.rosters, index)
		DruidTreeRosterFrame.UpdateYourself = true
		Prompt:Info("已将<%s>移出名单", name)
	else
		Prompt:Warning("名单索引<%d>异常", index)
	end
end
