--- Числовые границы: положительное, неотрицательное, диапазон, больше, меньше.
---
--- Границы включают концы: `between(value, 'вес', 1, 10)` пропускает и 1,
--- и 10. Исключающая граница называется прямо — `greater_than` и
--- `less_than`, — и путать их не с чем.
---
--- Чего ждали, сказано в сообщении целиком: «срок — число больше нуля,
--- а не строка», а не «срок — число, а не строка». Стоит это одинаково,
--- а по второму не видно, что чинить: строку там ждали или что-то ещё.

local fail = require('tnt.must.fail')
local types = require('tnt.must.types')

local Module = {}

--- Сама граница: число, с которым сравнивают.
---
--- Проверяется тем же набором, что и данные: забытая граница иначе всплывёт
--- сравнением с nil внутри этого файла, и человек пойдёт читать чужой код
--- вместо своей строки.
---@param limit any
---@param name string|nil Имя аргумента, у которого эта граница
---@param role string Как называется граница в сообщении
---@return string|nil complaint
local function boundary(limit, name, role)
    return types.number(limit, fail.about(role, name))
end

--- Число, о котором вообще можно сказать «больше» или «меньше».
---
--- NaN отвергается здесь, а не в сравнении ниже: он ложен в любом
--- сравнении, поэтому прошёл бы и `> 0`, и `< 0` — то есть проверку
--- границы миновал бы молча.
---@param value any
---@param name string|nil
---@param expected string Чего ждали — целиком, вместе с границей
---@return string|nil complaint
local function comparable(value, name, expected)
    if type(value) ~= 'number' then
        return fail.text(name, expected, fail.kind(value))
    end

    if value ~= value then
        return fail.text(name, expected, fail.show(value))
    end

    return nil
end

--- Число строго больше границы.
---@param value any
---@param name string|nil
---@param limit number
---@return string|nil complaint
function Module.greater_than(value, name, limit)
    local expected = ('число больше %s'):format(limit)
    local complaint = boundary(limit, name, 'граница') or comparable(value, name, expected)

    if complaint ~= nil then
        return complaint
    end

    if value <= limit then
        return fail.text(name, expected, fail.show(value))
    end

    return nil
end

--- Число строго меньше границы.
---@param value any
---@param name string|nil
---@param limit number
---@return string|nil complaint
function Module.less_than(value, name, limit)
    local expected = ('число меньше %s'):format(limit)
    local complaint = boundary(limit, name, 'граница') or comparable(value, name, expected)

    if complaint ~= nil then
        return complaint
    end

    if value >= limit then
        return fail.text(name, expected, fail.show(value))
    end

    return nil
end

--- Число больше нуля.
---
--- Ноль отвергается не из придирчивости: размер куска, ширина поля и число
--- попыток при нуле уводят цикл в бесконечность либо не делают ничего,
--- и оба исхода объясняются потом долго.
---@param value any
---@param name string|nil
---@return string|nil complaint
function Module.positive(value, name)
    return Module.greater_than(value, name, 0)
end

--- Число не меньше нуля: ноль годится, минус — нет.
---
--- Это про сроки, отступы и счётчики: пустое ожидание осмысленно,
--- отрицательное — нет.
---@param value any
---@param name string|nil
---@return string|nil complaint
function Module.non_negative(value, name)
    local expected = 'число не меньше 0'
    local complaint = comparable(value, name, expected)

    if complaint ~= nil then
        return complaint
    end

    if value < 0 then
        return fail.text(name, expected, fail.show(value))
    end

    return nil
end

--- Число в диапазоне; обе границы входят в него.
---@param value any
---@param name string|nil
---@param low number
---@param high number
---@return string|nil complaint
function Module.between(value, name, low, high)
    local expected = ('число от %s до %s'):format(low, high)
    local complaint = boundary(low, name, 'нижняя граница')
        or boundary(high, name, 'верхняя граница')
        or comparable(value, name, expected)

    if complaint ~= nil then
        return complaint
    end

    if value < low or value > high then
        return fail.text(name, expected, fail.show(value))
    end

    return nil
end

return Module
