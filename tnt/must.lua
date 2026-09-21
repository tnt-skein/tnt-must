--- Проверки аргументов: неправильный аргумент роняет вызов на месте.
---
---
---     local must = require('tnt.must')
---
---     function Module.configure(opts)
---         must.table(opts, 'настройки')
---         must.not_empty(opts.tag, 'метка журнала')
---         must.optional.integer(opts.limit, 'предел записей')
---         must.one_of(opts.level, 'уровень', { 'debug', 'info', 'error' })
---         must.all.string(opts.hosts, 'адреса')
---     end
---
---     -- настройки — таблица, а не строка
---     -- метка журнала — непустая строка, а не nil
---     -- уровень — одно из «debug», «info», «error», а не «warn»
---     -- адреса[2] — строка, а не число
---
--- То же самое одним описанием, с отказом на незнакомый ключ:
---
---     must.options(opts, 'настройки', {
---         tag = 'not_empty',
---         limit = '?integer',
---         level = { 'one_of', { 'debug', 'info', 'error' } },
---         hosts = { 'array_of', 'string' },
---     })
---
---     -- настройки: ключа «limt» нет, есть hosts, level, limit, tag
---     -- настройки.limit — целое число, а не строка
---
--- Проверка возвращает само значение, поэтому её пишут и присваиванием:
--- `local tag = must.string(opts.tag, 'метка')`.
---
--- Место в сообщении — строка вызывающего, а не строка внутри пакета:
--- как это устроено и почему иначе нельзя, написано в `tnt/must/fail.lua`.
--- Помощник, который заворачивает проверку, переводит вину на свою строку
--- вызова уровнем: `must.at(2).string(v, 'метка')` — как `error(msg, 2)`.
---
--- Пакету, который бросает сам — без места, через `fail.raise`, — место
--- не нужно вовсе, а нужен текст. Его отдаёт `must.explain`: там те же
--- `kind`, `array_of` и `options`, только вместо броска — текст отказа
--- либо nil:
---
---     local complaint = must.explain.options(spec, 'приложение', FIELDS)
---
---     if complaint ~= nil then
---         fail.raise(complaint)
---     end
---
--- Зависимостей у пакета нет: только встроенное в Tarantool — `utf8`,
--- `ffi`, `decimal`, `uuid`, `datetime` и `box.tuple` для типов cdata.
--- Он ядро — его возьмут все, — и лишняя зависимость расползлась бы по
--- всему дереву. Настроек тоже нет, поэтому нет ни `configure`, ни `new`,
--- ни `default`, ни `status`.

local cdata = require('tnt.must.cdata')
local choice = require('tnt.must.choice')
local fail = require('tnt.must.fail')
local range = require('tnt.must.range')
local spec = require('tnt.must.spec')
local text = require('tnt.must.text')
local types = require('tnt.must.types')

--- Проверка аргумента: возвращает само значение, а на неправильном бросает.
---@alias TntMustCheck fun(value: any, name?: string, ...): any

--- Набор проверок; один и тот же у фасада, у `optional` и у `all`.
---@class TntMustChecks
---@field string TntMustCheck
---@field number TntMustCheck
---@field integer TntMustCheck
---@field boolean TntMustCheck
---@field table TntMustCheck
---@field callable TntMustCheck
---@field array TntMustCheck
---@field uint64 TntMustCheck
---@field int64 TntMustCheck
---@field decimal TntMustCheck
---@field uuid TntMustCheck
---@field tuple TntMustCheck
---@field datetime TntMustCheck
---@field interval TntMustCheck
---@field error TntMustCheck
---@field instance_of TntMustCheck
---@field positive TntMustCheck
---@field non_negative TntMustCheck
---@field greater_than TntMustCheck
---@field less_than TntMustCheck
---@field between TntMustCheck
---@field not_empty TntMustCheck
---@field matches TntMustCheck
---@field length TntMustCheck
---@field one_of TntMustCheck
---@field kind TntMustCheck
---@field array_of TntMustCheck
---@field options TntMustCheck

--- Набор проверок с одним уровнем вины на всех: сами по себе,
--- необязательные и по всему списку.
---@class TntMustFacade : TntMustChecks
---@field optional TntMustChecks Аргумент, которого может не быть
---@field all TntMustChecks Каждый элемент списка

--- Фасад пакета.
---@class TntMust : TntMustFacade
---@field at fun(level: integer): TntMustFacade Те же проверки с другим уровнем вины
---@field explain TntMustNamed Проверки по имени без броска: текст отказа либо nil

--- Реестр проверок: по нему собирается фасад, и из него же проверка
--- берётся по имени — в `kind`, `array_of` и `options`.
---
--- Порядок объявления виден снаружи: им же перечисляются известные
--- проверки в отказе об опечатке. Идут они так, как о них думают: тип,
--- типы Tarantool, границы, строки, перечисление, проверки по имени.
---@type TntMustRegistry
local registry = { explain = {}, names = {}, labels = {} }

--- Объявляет проверку.
---@param name string
---@param explain TntMustExplain
---@param label string|nil Подпись типа — только у типов, они объединяются через «|»
local function declare(name, explain, label)
    registry.explain[name] = explain
    registry.labels[name] = label
    table.insert(registry.names, name)
end

--- Объявляет типы модуля: подпись у каждого лежит в его `LABEL`, и это
--- та же подпись, из которой складывается ожидание объединения.
---@param module table
---@param names string[]
local function declare_kinds(module, names)
    for _, name in ipairs(names) do
        declare(name, module[name], module.LABEL[name])
    end
end

declare_kinds(types, { 'string', 'number', 'integer', 'boolean', 'table', 'callable', 'array' })
declare_kinds(cdata, { 'uint64', 'int64', 'decimal', 'uuid', 'tuple', 'datetime', 'interval', 'error' })
declare('instance_of', types.instance_of)
declare('positive', range.positive)
declare('non_negative', range.non_negative)
declare('greater_than', range.greater_than)
declare('less_than', range.less_than)
declare('between', range.between)
declare('not_empty', text.not_empty)
declare('matches', text.matches)
declare('length', text.length)
declare('one_of', choice.one_of)

-- Проверки по имени собираются поверх реестра и сами в него входят:
-- реестр читается при вызове, и `options` может описать вложенные
-- настройки как `{ 'options', { … } }`.
local named = spec.new(registry)

declare('kind', named.kind)
declare('array_of', named.array_of)
declare('options', named.options)

--- Весь набор проверок разом, обёрнутый одним и тем же способом.
---
--- Проверка объявлена один раз, а видов у неё три: сама по себе,
--- необязательная и по всему списку. Писать их порознь значило бы
--- переписать три раза одно и то же и однажды разойтись в сообщениях.
---@param wrap fun(explain: any): any Чем обернуть проверку перед броском
---@param level integer Уровень вины у всех проверок набора
---@return TntMustChecks
local function group_of(wrap, level)
    local group = {}

    for _, name in ipairs(registry.names) do
        group[name] = fail.raising(wrap(registry.explain[name]), level)
    end

    -- Приведение, а не объявление: поля появляются в цикле, и вывести
    -- их из пустой таблицы анализатору неоткуда.
    return group --[[@as TntMustChecks]]
end

--- Проверка как она есть: снаружи этого набора её ничем не оборачивают.
---@param explain any
---@return any
local function plain(explain)
    return explain
end

--- Все три вида проверок с одним уровнем вины.
---@param level integer
---@return TntMustFacade
local function facade_at(level)
    local facade = group_of(plain, level) --[[@as TntMustFacade]]

    facade.optional = group_of(choice.maybe, level)
    facade.all = group_of(choice.each, level)

    return facade
end

local Module = facade_at(fail.DEFAULT_LEVEL) --[[@as TntMust]]

--- Проверки по имени без броска: текст отказа либо nil.
---
--- Ради пакетов, которые бросают сами. Отказ, уходящий оператору
--- в alerts или сверяемый целиком, бросается `fail.raise` без места,
--- а фасад приписал бы место — и у пакета стало бы два вида отказов.
--- Одиночные проверки такой пакет берёт прямо из модулей
--- (`tnt.must.types`, `range`, `choice`), а эти три собраны поверх
--- реестра фасада, и взять их больше неоткуда. Через `kind` видна
--- любая проверка реестра: `must.explain.kind(v, 'вес', 'between', 1, 10)`.
Module.explain = named

--- Наборы по уровню: собранный однажды набор служит всем вызовам с этим
--- уровнем, иначе `must.at(2).string(...)` в помощнике собирало бы полсотни
--- замыканий на каждый вызов.
local facades = { [fail.DEFAULT_LEVEL] = Module }

--- Уровень вины: целое число больше нуля, как второй аргумент `error`.
---@param value any
---@param name string|nil
---@return string|nil complaint
local function explain_level(value, name)
    return types.integer(value, name) or range.positive(value, name)
end

--- Отказ о неправильном уровне показывает на строку с `must.at(...)`: `at` —
--- ровно такой помощник, ради которого уровень и заведён, и здесь он нужен
--- ему самому.
local need_level = fail.raising(explain_level, 2)

--- Те же проверки, но вина — на другой строке.
---
--- Уровень считается как у `error`: 1 — строка с проверкой (то же, что
--- `must` без `at`), 2 — вызывающий той функции, где она стоит. Нужно
--- помощнику вокруг проверки: `local function need_tag(v)
--- must.at(2).string(v, 'метка') end` показывает не на себя, а на того,
--- кто его позвал. Хвостовым вызовом (`return must.at(2)...`) помощник
--- ушёл бы со стека сам, и вина съехала бы ещё на кадр — см. `fail.lua`.
---@param level integer
---@return TntMustFacade
function Module.at(level)
    need_level(level, 'уровень вины')

    if facades[level] == nil then
        facades[level] = facade_at(level)
    end

    return facades[level]
end

return Module
