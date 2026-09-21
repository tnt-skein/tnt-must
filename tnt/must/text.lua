--- Строки: непустая, по образцу, нужной длины.
---
--- Длина считается в знаках, а не в байтах: «Узел» — это четыре знака
--- и восемь байтов, и предел в байтах обрезал бы кириллицу вдвое раньше,
--- чем ждёт человек, написавший «не длиннее 64». Знаки считает встроенный
--- в Tarantool `utf8`; у строки с битыми байтами знаков не сосчитать —
--- такая меряется байтами.

local utf8 = require('utf8')

local fail = require('tnt.must.fail')
local types = require('tnt.must.types')

local Module = {}

--- Граница длины, если она названа.
---
--- Проверяется тем же набором, что и данные: строка вместо числа иначе
--- всплыла бы сравнением внутри этого файла, и человек пошёл бы читать
--- чужой код вместо своей строки.
---@param limit any
---@param name string|nil Имя аргумента, у которого эта граница
---@param role string Как называется граница в сообщении
---@return string|nil complaint
local function boundary(limit, name, role)
    if limit == nil then
        return nil
    end

    return types.number(limit, fail.about(role, name))
end

--- Непустая строка.
---
--- Пустая строка — не то же, что nil: она проходит проверку типа, доезжает
--- до записи и оставляет поле, которого будто и не было. Пробелы здесь
--- не снимаются: « » — это не пусто, и делать вид, что пусто, значит
--- спорить с тем, что человек набрал.
---@param value any
---@param name string|nil
---@return string|nil complaint
function Module.not_empty(value, name)
    if type(value) ~= 'string' then
        return fail.text(name, 'непустая строка', fail.kind(value))
    end

    if value == '' then
        return fail.text(name, 'непустая строка', 'пустая')
    end

    return nil
end

--- Строка по образцу.
---
--- Образец — шаблон Lua (`%d+`), а не регулярное выражение (`\d+`):
--- регулярных выражений в Tarantool нет, а тащить их ради одной проверки
--- значило бы завести пакету зависимость, которой у него нет.
---
--- Образец ищется где угодно в строке, как это делает `string.find`.
--- Привязка к началу и концу пишется явно: `'^[%w-]+$'`.
---@param value any
---@param name string|nil
---@param pattern string Шаблон Lua
---@return string|nil complaint
function Module.matches(value, name, pattern)
    local missing = types.string(pattern, fail.about('образец', name))

    if missing ~= nil then
        return missing
    end

    local expected = ('строка по образцу %s'):format(pattern)

    if type(value) ~= 'string' then
        return fail.text(name, expected, fail.kind(value))
    end

    if value:find(pattern) == nil then
        return fail.text(name, expected, fail.show(value))
    end

    return nil
end

--- Как назвать требование к длине.
---@param min number|nil
---@param max number|nil
---@return string
local function bounds(min, max)
    if max == nil then
        return ('не меньше %s знаков'):format(min)
    end

    if min == nil then
        return ('не больше %s знаков'):format(max)
    end

    return ('от %s до %s знаков'):format(min, max)
end

--- Строка нужной длины; любая из границ может отсутствовать.
---
--- Обе границы входят в допустимое: `length(value, 'код', 6, 6)` — это
--- ровно шесть знаков.
---@param value any
---@param name string|nil
---@param min number|nil Не короче, знаков
---@param max number|nil Не длиннее, знаков
---@return string|nil complaint
function Module.length(value, name, min, max)
    -- Забытые границы — ошибка в самой проверке, и сказать о ней надо
    -- прямо. Сообщение «строка длиной от nil до nil» человек пойдёт искать
    -- в своих данных, а чинить надо строку, в которой стоит проверка.
    if min == nil and max == nil then
        return ('%s: у проверки длины нет ни одной границы'):format(fail.named(name))
    end

    local wrong = boundary(min, name, 'нижняя граница')
        or boundary(max, name, 'верхняя граница')

    if wrong ~= nil then
        return wrong
    end

    local expected = ('строка длиной %s'):format(bounds(min, max))

    if type(value) ~= 'string' then
        return fail.text(name, expected, fail.kind(value))
    end

    local counted = utf8.len(value) or #value

    if (min ~= nil and counted < min) or (max ~= nil and counted > max) then
        return fail.text(name, expected, tostring(counted))
    end

    return nil
end

return Module
