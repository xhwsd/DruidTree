--[[
Name: Wsd-Array-1.0
Revision: $Rev: 10001 $
Author(s): xhwsd
Website: https://github.com/xhwsd
Description: 数组相关库。
Dependencies:
]]

-- 主要版本
local MAJOR_VERSION = "Wsd-Array-1.0"
-- 次要版本
local MINOR_VERSION = "$Revision: 10001 $"

-- 数组相关库。
---@class Wsd-Array-1.0
local Library = {}

-- 库激活
---@param self table 库自身对象
---@param oldLib table 旧版库对象
---@param oldDeactivate function 旧版库停用函数
local function activate(self, oldLib, oldDeactivate)

end

-- 外部库加载
---@param self table 库自身对象
---@param major string 外部库主版本
---@param instance table 外部库实例
local function external(self, major, instance)

end

--------------------------------

-- 检验是否是索引表，可使用`ipairs`遍历
---@param data any 数据
---@return boolean is 是否是
function Library:isList(data)
    if type(data) ~= "table" then
        return false
    end

    local count = 0
    for key, _ in pairs(data) do
        if type(key) ~= "number" or key < 1 or math.floor(key) ~= key then
            return false
        end

        if key > count then
            count = key
        end
    end

    for index = 1, count do
        if data[index] == nil then
            return false
        end
    end
    return true
end

-- 检验是否是关联表，可使用`pairs`遍历
---@param data any 数据
---@return boolean is 是否是
function Library:isAssoc(data)
    if type(data) ~= "table" then
        return false
    end

    for key, _ in pairs(data) do
        if type(key) ~= "number" or math.floor(key) ~= key then
            return true
        end
    end
    return false
end

-- 数据位与列表
---@param list table 列表(索引表）
---@param data any 数据
---@return integer|nil index 成功返回索引，失败返回空
function Library:InList(list, data)
	if type(list) == "table" then
		for index, value in ipairs(list) do
			if value == data then
				return index
			end
		end
	end
end

-- 数据位与关联
---@param assoc table 关联(关联表）
---@param data any 数据
---@return string|nil key 成功返回键，失败返回空
function Library:InAssoc(assoc, data)
	if type(assoc) == "table" then
		for key, value in pairs(assoc) do
			if value == data then
				return key
			end
		end
	end
end

--------------------------------

-- 最终注册库
AceLibrary:Register(Library, MAJOR_VERSION, MINOR_VERSION, activate, nil, external)
Library = nil