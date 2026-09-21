--- Типы значений Tarantool, которые не значения Lua: 64-битные целые,
--- decimal, uuid, кортеж, datetime, интервал, ошибка box.
---
--- Все они — `cdata`, и для `type` неразличимы: `must.integer` отвергает
--- счётчик из `box.info` с тем же «а не cdata», что и кортеж. Приводить
--- их к числу молча нельзя — теряется точность, — а проверять руками
--- через `ffi.istype` в каждом пакете значит написать это восемь раз.
--- Узнаёт тип готовая функция ядра: `decimal.is_decimal`, `uuid.is_uuid`,
--- `box.tuple.is`, `datetime.is_datetime`, `datetime.interval.is_interval`,
--- `box.error.is`; целые различаются `ffi.istype`, как в самом `checks`.
---
--- `uint64` и `int64` берут и число Lua: счётчик из msgpack приходит числом,
--- пока умещается в 2^53, и cdata — когда перестаёт, так что один столбец
--- спейса даёт то и другое. Число годится, пока оно целое и по модулю
--- меньше 2^53: дальше double уже не хранит целые подряд, и число,
--- прошедшее проверку, могло бы оказаться не тем, которое записали.
---
--- Отказ называет значение, а не тип, когда тип подошёл, а само значение —
--- нет: «счётчик — целое uint64, а не -1LL» говорит больше, чем «а не
--- cdata». Всё, что не число и не cdata, называется типом, как везде.

local datetime = require('datetime')
local decimal = require('decimal')
local ffi = require('ffi')
local uuid = require('uuid')

local fail = require('tnt.must.fail')

local Module = {}

--- Как тип называется в сообщении; объединение типов складывает своё
--- ожидание из этих же слов.
Module.LABEL = {
    uint64 = 'целое uint64',
    int64 = 'целое int64',
    decimal = 'decimal',
    uuid = 'UUID',
    tuple = 'кортеж',
    datetime = 'datetime',
    interval = 'интервал datetime',
    error = 'ошибка box.error',
}

local INT64 = ffi.typeof('int64_t')
local UINT64 = ffi.typeof('uint64_t')

--- Первое целое, которое double уже не отличает от соседнего.
local EXACT = 2 ^ 53

--- Верхняя граница знакового 64-битного целого; беззнаковое сверх неё
--- в `int64` не помещается.
local SIGNED_LIMIT = 2 ^ 63

--- Что пришло: значение, если его тип подошёл, иначе — тип.
---@param value any
---@param numbers_fit boolean Годится ли проверке число Lua
---@return string
local function got(value, numbers_fit)
    if type(value) == 'cdata' or (numbers_fit and type(value) == 'number') then
        return fail.show(value)
    end

    return fail.kind(value)
end

--- Число Lua, которое хранит целое без потерь.
---@param value number
---@return boolean
local function exact_whole(value)
    -- NaN не равен своему `math.floor`, бесконечность равна, но по модулю
    -- не меньше любой границы: оба отсеиваются здесь.
    return value == math.floor(value) and math.abs(value) < EXACT
end

--- Целое без знака: число Lua от 0 до 2^53, `uint64_t` либо `int64_t`
--- не меньше нуля.
---@param value any
---@param name string|nil
---@return string|nil complaint
function Module.uint64(value, name)
    if type(value) == 'number' and exact_whole(value) and value >= 0 then
        return nil
    end

    if ffi.istype(UINT64, value) or (ffi.istype(INT64, value) and value >= 0) then
        return nil
    end

    return fail.text(name, Module.LABEL.uint64, got(value, true))
end

--- Целое со знаком: число Lua по модулю меньше 2^53, `int64_t` либо
--- `uint64_t` меньше 2^63.
---@param value any
---@param name string|nil
---@return string|nil complaint
function Module.int64(value, name)
    if type(value) == 'number' and exact_whole(value) then
        return nil
    end

    if ffi.istype(INT64, value) or (ffi.istype(UINT64, value) and value < SIGNED_LIMIT) then
        return nil
    end

    return fail.text(name, Module.LABEL.int64, got(value, true))
end

--- Проверка типа, который узнаёт готовая функция ядра.
---@param label string Как тип назван в сообщении
---@param is fun(value: any): boolean Функция ядра, узнающая тип
---@return fun(value: any, name: string|nil): string|nil
local function recognized_by(label, is)
    return function(value, name)
        if is(value) then
            return nil
        end

        return fail.text(name, label, got(value, false))
    end
end

--- Число decimal.
Module.decimal = recognized_by(Module.LABEL.decimal, decimal.is_decimal)

--- UUID как значение, а не его запись строкой.
Module.uuid = recognized_by(Module.LABEL.uuid, uuid.is_uuid)

--- Кортеж box, а не таблица с полями.
Module.tuple = recognized_by(Module.LABEL.tuple, box.tuple.is)

--- Дата со временем из встроенного `datetime`.
Module.datetime = recognized_by(Module.LABEL.datetime, datetime.is_datetime)

--- Интервал из встроенного `datetime`.
Module.interval = recognized_by(Module.LABEL.interval, datetime.interval.is_interval)

--- Ошибка box — то, что бросает ядро и делает `box.error.new`.
--- `box.error.is` в аннотациях ядра не описан.
---@diagnostic disable-next-line: undefined-field
Module.error = recognized_by(Module.LABEL.error, box.error.is)

return Module
