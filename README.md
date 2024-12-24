# 树德辅助插件

> __自娱自乐，不做任何保证！__  
> 如遇到BUG可反馈至 xhwsd@qq.com 邮箱


## 使用
- 安装`!Libs`插件
- 可选的，安装[SuperMacro](https://ghgo.xyz/https://github.com/xhwsd/SuperMacro/archive/master.zip)插件
- 安装[DaruidTree](https://ghgo.xyz/https://github.com/xhwsd/DaruidTree/archive/master.zip)插件
- 基于插件提供的函数，创建普通或超级宏
- 将宏图标拖至动作条，然后使用宏

> 确保插件最新版本、已适配乌龟服、目录名正确（如删除末尾`-main`等）


## 可用宏

> 使用该系列宏需确保有一个治疗法术（回春术、愈合、治疗之触）在动作条任意位置


### 奶选

> 尝试治疗选择目标

```
/script -- CastSpellByName("愈合")
/script DaruidTree:HealSelect()
```

逻辑描述：
- 已按ALT使用宏，过量治疗当前选择
- 未按ALT使用宏，检验打断施法（省蓝），过量治疗当前选择


### 奶队

> 尝试尽力治疗队伍中生命损失最多的目标

```
/script -- CastSpellByName("愈合")
/script DaruidTree:HealParty(4, 40, 1500)
```

参数列表：
- `@param start? integer` 起始生命损失百分比
- `@param swiftness? integer` 剩余生命等于或小于该百分比时，使用自然迅捷
- `@param swiftmend? integer` 损失生命大于或等于该值时，使用迅捷治愈

逻辑描述：
- 检验打断施法（省蓝）
- 尽力治疗队伍中生命损失最多的目标


### 奶团

> 尝试节省治疗团队中生命损失最多的目标

```
/script -- CastSpellByName("愈合")
/script DaruidTree:HealRaid(6, 4, 40, 1500)
```

参数列表：
- `@param start? integer` 起始生命损失百分比
- `@param rank? integer` 愈合法术等级
- `@param swiftness? integer` 剩余生命等于或小于该百分比时，使用自然迅捷
- `@param swiftmend? integer` 损失生命大于或等于该值时，使用迅捷治愈

逻辑描述：
- 检验打断施法（省蓝）
- 节省治疗团队中生命损失最多的目标


### 奶名

> 尝试治疗名单、团队、队伍、选择中生命损失最多的目标

```
/script -- CastSpellByName("愈合")
/script DaruidTree:HealRoster(2, 40, 1500)
```

参数列表：
- `@param start? integer` 起始生命损失百分比
- `@param swiftness? integer` 剩余生命等于或小于该百分比时，使用自然迅捷
- `@param swiftmend? integer` 损失生命大于或等于该值时，使用迅捷治愈

大致逻辑：
- 检验打断施法（省蓝）
- 补充名单回春术（毛治疗量）
- 尽力治疗奶名中生命损失最多的目标
- 如果名单无损失目标，将尝试奶团（在团）、奶队（在队）、奶选


### 名单

> 将目标加入或移除名单

```
/script DaruidTree:Roster()
```

大致逻辑：
- 选择坦克（友善目标）使用宏 - 将目标加入或删除名单
- 按住ALT使用宏 - 清空名单
- 无目标、非友善目标使用宏 - 输出当前名单


### 节能

> 触发节能

```
/script -- CastSpellByName("精灵之火")
/script DaruidTree:EnergySaving()
```

大致逻辑：
- 对附近进入战斗目标施法精灵之火（按下ALT释放最高级），以此触发节能效果


## 命令
- `/sdfz tsms` - 调试模式：开启或关闭调试模式
- `/sdfz tsdj [等级]` - 等级等级：设置或获取调试等级，等级取值范围`1~3`
