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

-- 名单
local rosters = {}

-- 插件载入
function DruidTree:OnInitialize()
	-- 动态标题
	self.title = "树德 v" .. GetAddOnMetadata("DruidTree", "Version")
	-- 开启调试
	self:SetDebugging(true)
	-- 调试等级
	self:SetDebugLevel(3)
	-- 菜单图标
	self.hasIcon = true
	self:SetIcon("Interface\\Icons\\Ability_Druid_ForceofNature")
	-- 默认小地图位置
	self.defaultMinimapPosition = 210
	-- 信息可点击
	self.clickableTooltip = true
	-- 隐藏时行为
	self.hideWithoutStandby = true
end

-- 插件打开
function DruidTree:OnEnable()
	self:LevelDebug(3, "插件打开")

	-- 注册数据库
	self:RegisterDB("DruidTreeDB")

	-- 注册默认数据
	self:RegisterDefaults('profile', {
		-- 选择
		select = 2,
		-- 名单
		roster = 2,
		-- 队伍
		party = 4,
		-- 团队
		raid = 4,
		-- 过量
		overdose = {
			-- 迅捷治愈
			swiftmend = 1000,
			-- 自然迅捷
			swiftness = 50,
		},
		-- 尽力
		endeavor = {
			-- 迅捷治愈
			swiftmend = 2000,
			swiftness = 40,
		},
		-- 节省
		economize = {
			-- 愈合
			regrowth = 4,
			-- 迅捷治愈
			swiftmend = 3000,
			-- 自然迅捷
			swiftness = 30,
		},
	})

	-- 定义菜单项或命令
	self.options = {
		type = "group",
		handler = self,
		args = {
			-- 名单
			rosters = {
				type = "group",
				name = "治疗名单",
				desc = "当前治疗名单",
				order = 1,
                args = {
					roster1	= {
						type = "execute",
						name = function ()
							return rosters[1] or '名单1'
						end,
						desc = "点击移出名单",
						order = 1,
						hidden = function ()
							return rosters[1] ~= nil
						end,
						func = function()
							self:RemoveRoster(rosters[1])
						end
					},
					roster2	= {
						type = "execute",
						name = function ()
							return rosters[2] or '名单2'
						end,
						desc = "点击移出名单",
						order = 2,
						hidden = function ()
							return rosters[2] ~= nil
						end,
						func = function()
							self:RemoveRoster(rosters[2])
						end
					},
					roster3	= {
						type = "execute",
						name = function ()
							return rosters[3] or '名单3'
						end,
						desc = "点击移出名单",
						order = 3,
						hidden = function ()
							return rosters[3] ~= nil
						end,
						func = function()
							self:RemoveRoster(rosters[3])
						end
					},
					roster4	= {
						type = "execute",
						name = function ()
							return rosters[4] or '名单4'
						end,
						desc = "点击移出名单",
						order = 4,
						hidden = function ()
							return rosters[4] ~= nil
						end,
						func = function()
							self:RemoveRoster(rosters[4])
						end
					},
					roster5	= {
						type = "execute",
						name = function ()
							return rosters[5] or '名单5'
						end,
						desc = "点击移出名单",
						order = 5,
						hidden = function ()
							return rosters[5] ~= nil
						end,
						func = function()
							self:RemoveRoster(rosters[5])
						end
					}
				}
			},
			join = {
				type = "execute",
				name = "加入名单",
				desc = "将友善目标加入治疗名单",
				order = 2,
				func = function()
					self:JoinRoster()
				end
			},
			clear = {
				type = "execute",
				name = "清空名单",
				desc = "清空治疗名单",
				order = 3,
				func = function()
					self:ClearRoster()
				end
			},
			-- 损失
			select = {
				type = "range",
				name = "选择损失",
				desc = "当选择目标损失百分比大于或等于该值时，确认需要治疗",
				order = 4,
				min = 0,
				max = 100,
				get = function()
					return self.db.profile.select
				end,
				set = function(value)
					self.db.profile.select = value
				end
			},
			roster = {
				type = "range",
				name = "名单损失",
				desc = "当名单成员损失百分比大于或等于该值时，确认需要治疗",
				order = 5,
				min = 0,
				max = 100,
				get = function()
					return self.db.profile.roster
				end,
				set = function(value)
					self.db.profile.roster = value
				end
			},
			party = {
				type = "range",
				name = "队伍损失",
				desc = "当队伍成员损失百分比大于或等于该值时，确认需要治疗",
				order = 6,
				min = 0,
				max = 100,
				get = function()
					return self.db.profile.party
				end,
				set = function(value)
					self.db.profile.party = value
				end
			},
			raid = {
				type = "range",
				name = "团队损失",
				desc = "当团队成员损失百分比大于或等于该值时，确认需要治疗",
				order = 7,
				min = 0,
				max = 100,
				get = function()
					return self.db.profile.raid
				end,
				set = function(value)
					self.db.profile.raid = value
				end
			},
			-- 模式
			overdose = {
				type = "group",
				name = "过量治疗",
				desc = "将在治疗选择时使用该模式",
				order = 8,
				args = {
					swiftmend = {
						type = "text",
						name = "迅捷治愈",
						desc = "当损失大于或等于该值时，可使用迅捷治愈",
						order = 1,
						usage = "请输入大于或等于 0 的整数",
						validate = function(value)
							local number = tonumber(value)
							if type(number) ~= "number" or number >= 0 then
								return "请输入大于或等于 0 的整数"
							end
							return true
						end,
						get = function()
							return self.db.profile.overdose.swiftmend
						end,
						set = function(value)
							self.db.profile.overdose.swiftmend = math.floor(tonumber(value))
						end
					},
					swiftness = {
						type = "range",
						name = "自然迅捷",
						desc = "当剩余百分比小于或等于该值时，可使用自然迅捷",
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
				desc = "将在治疗选择、名单、队伍时使用该模式",
				order = 9,
				args = {
					swiftmend = {
						type = "text",
						name = "迅捷治愈",
						desc = "当损失大于或等于该值时，可使用迅捷治愈",
						order = 1,
						usage = "请输入大于或等于 0 的整数",
						validate = function(value)
							local number = tonumber(value)
							if type(number) ~= "number" or number >= 0 then
								return "请输入大于或等于 0 的整数"
							end
							return true
						end,
						get = function()
							return self.db.profile.endeavor.swiftmend
						end,
						set = function(value)
							self.db.profile.endeavor.swiftmend = math.floor(tonumber(value))
						end
					},
					swiftness = {
						type = "range",
						name = "自然迅捷",
						desc = "当剩余百分比小于或等于该值时，可使用自然迅捷",
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
				desc = "将在治疗团队时使用该模式",
				order = 10,
				args = {
					regrowth = {
						type = "range",
						name = "愈合",
						desc = "限定节省治疗时愈合的等级",
						order = 1,
						min = 1,
						max = 8,
						get = function()
							return self.db.profile.economize.regrowth
						end,
						set = function(value)
							self.db.profile.economize.regrowth = value
						end
					},
					swiftmend = {
						type = "text",
						name = "迅捷治愈",
						desc = "当损失大于或等于该值时，可使用迅捷治愈",
						order = 2,
						usage = "请输入大于或等于 0 的整数",
						validate = function(value)
							local number = tonumber(value)
							if type(number) ~= "number" or number >= 0 then
								return "请输入大于或等于 0 的整数"
							end
							return true
						end,
						get = function()
							return self.db.profile.economize.swiftmend
						end,
						set = function(value)
							self.db.profile.economize.swiftmend = math.floor(tonumber(value))
						end
					},
					swiftness = {
						type = "range",
						name = "自然迅捷",
						desc = "当剩余百分比小于或等于该值时，可使用自然迅捷",
						order = 3,
						min = 0,
						max = 100,
						get = function()
							return self.db.profile.economize.swiftness
						end,
						set = function(value)
							self.db.profile.economize.swiftness = value
						end
					}
				}
			},
			-- 其它
			debug = {
				type = "toggle",
				name = "调试模式",
				desc = "开启或关闭调试模式",
				order = 11,
				get = "IsDebugging",
				set = "SetDebugging"
			},	
			level = {
				type = "range",
				name = "调试等级",
				desc = "设置或获取调试等级",
				order = 12,
				min = 1,
				max = 3,
				get = "GetDebugLevel",
				set = "SetDebugLevel"
			}
		},
	}

	-- 更新小地图菜单
	self.OnMenuRequest = self.options
	self:UpdateTooltip()

	-- 注册命令
	self:RegisterChatCommand({"/DruidTree", "/dt"}, self.options)
end

-- 插件关闭
function DruidTree:OnDisable()
	self:LevelDebug(3, "插件关闭")
end

function DruidTree:OnMenuRequest()

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
	-- 迅捷治愈损失起始
	local swiftmend = self.db.profile.overdose.swiftmend
	-- 自然迅捷剩余起始
	local swiftness = self.db.profile.overdose.swiftness
	
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
	elseif lose >= swiftmend and Spell:IsReady("迅捷治愈") and (Effect:FindName("愈合", unit) or Effect:FindName("回春术", unit)) then
		self:CastSpell("迅捷治愈", unit)
	elseif Health:GetRemaining(unit) <= swiftness and Spell:IsReady("自然迅捷") then
		self:CastSpell("自然迅捷")
	elseif not Effect:FindName("回春术", unit) then
		self:CastSpell("回春术", unit)
	else
		self:CastSpell("愈合", unit)
	end
	return true
end

-- 尽力治疗单位
---@param unit? string 目标单位；缺省为`self:ToHealUnit(unit)`
---@return boolean success 成功返回真，否则返回假
function DruidTree:EndeavorHeal(unit)
	unit = self:ToHealUnit(unit)
	-- 迅捷治愈损失起始
	local swiftmend = self.db.profile.endeavor.swiftmend
	-- 自然迅捷剩余起始
	local swiftness = self.db.profile.endeavor.swiftness
	
	-- 可否治疗
	if not self:CanHeal(unit) then
		self:LevelDebug(3, "尽力治疗，不可治疗；目标：%s", UnitName(unit))
		return false
	end

	-- 生命损失
	local percentage, lose = Health:GetLose(unit)
	if lose <= 0 then
		self:LevelDebug(3, "尽力治疗，未损失生命；目标：%s", UnitName(unit))
		return false
	end

	-- 尽力治疗
	self:LevelDebug(3, "尽力治疗；目标：%s；损失：%d", UnitName(unit), percentage)
	if Effect:FindName("自然迅捷", "player") then
		self:CastSpell(self:AdaptRank("愈合", lose, unit), unit)
	elseif lose >= swiftmend and Spell:IsReady("迅捷治愈") and (Effect:FindName("愈合", unit) or Effect:FindName("回春术", unit)) then
		self:CastSpell("迅捷治愈", unit)
	elseif Health:GetRemaining(unit) <= swiftness and Spell:IsReady("自然迅捷") then
		self:CastSpell("自然迅捷")
	elseif not Effect:FindName("回春术", unit) then
		self:CastSpell(self:AdaptRank("回春术", lose, unit), unit)
	else
		self:CastSpell(self:AdaptRank("愈合", lose, unit), unit)
	end
	return true
end

-- 节省治疗单位
---@param unit? string 目标单位；缺省为`self:ToHealUnit(unit)`
---@return boolean success 成功返回真，否则返回假
function DruidTree:EconomizeHeal(unit)
	unit = self:ToHealUnit(unit)
	-- 愈合等级
	local regrowth = self.db.profile.economize.regrowth
	-- 迅捷治愈损失起始
	local swiftmend = self.db.profile.economize.swiftmend
	-- 自然迅捷剩余起始
	local swiftness = self.db.profile.economize.swiftness

	-- 可否治疗
	if not self:CanHeal(unit) then
		self:LevelDebug(3, "节省治疗，不可治疗；目标：%s", UnitName(unit))
		return false
	end

	-- 生命损失
	local percentage, lose = Health:GetLose(unit)
	if lose <= 0 then
		self:LevelDebug(3, "节省治疗，未损失生命；目标：%s", UnitName(unit))
		return false
	end

	-- 节省治疗
	self:LevelDebug(3, "节省治疗；目标：%s；损失：%d", UnitName(unit), percentage)
	if Effect:FindName("自然迅捷", "player") then
		self:CastSpell(self:AdaptRank("愈合", lose, unit), unit)
	elseif lose >= swiftmend and Spell:IsReady("迅捷治愈") and (Effect:FindName("愈合", unit) or Effect:FindName("回春术", unit)) then
		self:CastSpell("迅捷治愈", unit)
	elseif Health:GetRemaining(unit) <= swiftness and Spell:IsReady("自然迅捷") then
		self:CastSpell("自然迅捷")
	else
		self:CastSpell(string.format("愈合(等级 %d)", regrowth), unit) 
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
	for _, name in ipairs(rosters) do
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
	for _, name in ipairs(rosters) do
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
---@param overdose? boolean 是否过量治疗
---@return boolean success 成功返回真，否则返回假
function DruidTree:HealSelect(overdose)
	overdose = overdose or false
	if overdose then
		-- 过量治疗
		if self:OverdoseHeal() then
			return true
		else
			Prompt:Warning("选择暂无损失")
		end
	else
		-- 打断治疗
		local start = self.db.profile.select
		if self:InterruptHeal(start) then
			return true
		end

		-- 尽力治疗
		if self:EndeavorHeal() then
			return true
		else
			Prompt:Warning("选择暂无损失")
		end
	end
	return false
end

-- 尝试治疗名单中生命损失最多的目标
---@return boolean success 成功返回真，否则返回假
function DruidTree:HealRoster()
	-- 打断治疗
	local start = self.db.profile.roster
	if self:InterruptHeal(start) then
		return true
	end

	-- 补充名单增益
	if self:AddedBuff() then
		return true
	end

	-- 查找名单损失
	local name = self:FindRoster(start)
	if name then
		local unit = RosterLib:GetUnitIDFromName(name)
		if unit then
			-- 尽力治疗单位
			return self:EndeavorHeal(unit)
		elseif Target:ToName(name) then
			-- 尽力治疗目标
			local result = self:EndeavorHeal("target")
			Target:ToLast()
			return result
		end
	else
		Prompt:Warning("名单暂无损失(%s)", start)
	end
	return false
end

-- 尝试尽力治疗队伍中生命损失最多的目标
---@return boolean success 成功返回真，否则返回假
function DruidTree:HealParty()
	-- 打断治疗
	local start = self.db.profile.party
	if self:InterruptHeal(start) then
		return true
	end

	-- 查找队伍损失
	local unit = self:FindParty(start)
	if unit then
		-- 尽力治疗
		return self:EndeavorHeal(unit)
	else
		Prompt:Warning("队伍暂无损失(%s)", start)
	end
	return false
end

-- 尝试节约治疗团队中生命损失最多的目标
---@return boolean success 成功返回真，否则返回假
function DruidTree:HealRaid()
	-- 打断治疗
	local start = self.db.profile.raid
	if self:InterruptHeal(start) then
		return true
	end

	-- 查找团队损失
	local unit = self:FindRaid(start)
	if unit then
		-- 节约治疗
		return self:EconomizeHeal(unit)
	else
		Prompt:Warning("团队暂无损失(%s)", start)
	end
	return false
end

-- 尝试治疗名单、团队、队伍、选择中生命损失最多的目标
---@return boolean success 成功返回真，否则返回假
function DruidTree:Heal()
	if self:HealRoster() then
		-- 治疗名单
		return true
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
		Prompt:Warning("暂无损失(%s)", start)
	end
	return false
end

-- 将当前友善目标加入名单
function DruidTree:JoinRoster()
	if UnitIsFriend("player", "target") then
		local name = UnitName("target")
		local index = Array:InList(rosters, name)
		if index then
			Prompt:Warning("<%s>已在名单中", name)
		else
			Prompt:Info("已将<%s>加入名单", name)
		end
	else
		Prompt:Error("请选择友善目标")
	end
end

-- 将指定名称移出名单
---@param name string 名称
function DruidTree:RemoveRoster(name)
	local index = Array:InList(rosters, name)
	if index then
		table.remove(rosters, index)
		Prompt:Info("已将<%s>移出名单", name)
	else
		Prompt:Warning("<%s>未在名单中")
	end
end

-- 清空当前名单
function DruidTree:ClearRoster()
	rosters = {}
	Prompt:Info("已清空名单")
end