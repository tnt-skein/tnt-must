--- Проверка, названная строкой: `'integer'`, `'?integer'`, `'number|string'`.
---
--- Три проверки берут другую по имени, а не ссылкой: `kind` — одну
--- для значения, `array_of` — одну на каждый элемент списка, `options` —
--- по одной на каждый ключ таблицы настроек. Имя, а не сама проверка,
--- потому что проверка фасада бросает, и вызови её `array_of` сама,
--- сообщение показало бы на строку внутри tnt-must. По имени берётся
--- та её половина, которая только объясняет, — из реестра, который фасад
--- собирает из всех модулей и передаёт сюда аргументом.
---
--- Запись имени — как у встроенного `checks`: `?` впереди разрешает
--- аргументу не приходить, `|` объединяет типы, а `?` сам по себе — любое
--- значение. Объединяются только типы — то, у чего есть подпись: «число
--- или строка» складывается из подписей, а у `between` ожидание зависит
--- от границ, и складывать его не из чего.
---
--- Собранная проверка остаётся проверкой того же типа: возвращает текст
--- отказа либо nil и ничего не бросает.

local choice = require('tnt.must.choice')
local fail = require('tnt.must.fail')
local types = require('tnt.must.types')

--- Проверка, которая объясняет: текст отказа либо nil.
---@alias TntMustExplain fun(value: any, name: string|nil, ...: any): string|nil

--- Реестр проверок фасада: то, что берётся по имени.
---@class TntMustRegistry
---@field explain table<string, TntMustExplain> Проверки по имени
---@field names string[] Имена в порядке объявления — им же перечисляются в отказе
---@field labels table<string, string> Подпись типа; есть только у типов, они и объединяются

--- Проверки, которые берут другую по имени.
---@class TntMustNamed
---@field kind TntMustExplain Одна проверка по имени
---@field array_of TntMustExplain Одна проверка на каждый элемент списка
---@field options TntMustExplain По проверке на каждый ключ таблицы

local Module = {}

--- Запись «любое значение», как у `checks`.
local ANY = '?'

--- Проверка, которой годится всё, и `nil` тоже.
---
--- Нужна описанию настроек: ею помечают ключ, который знаком, а значение
--- которого вызывающий проверяет сам, своим текстом. Так на `options`
--- переходят пакеты, у которых отказы о значениях уже сложились,
--- уходят оператору и сверяются целиком: набор ключей и отказ о чужом
--- ключе у них становятся общими, а отказы о значениях остаются своими.
---@return nil
local function anything()
    return nil
end

--- Отказ о проверке, которой нет в реестре.
---@param registry TntMustRegistry
---@param name string|nil Имя аргумента
---@param text any Что назвали
---@return string
local function unknown(registry, name, text)
    return ('%s: проверки «%s» нет, есть %s'):format(
        fail.named(name),
        tostring(text),
        table.concat(registry.names, ', ')
    )
end

--- Члены объединения: строка, разрезанная по «|».
---
--- Не `gmatch('[^|]+')`: тот молча проглотил бы пустой член в `'string|'`
--- и в `'a||b'`, а это опечатка, о которой надо сказать. Черта дописывается
--- в конец, чтобы каждый член, и пустой тоже, кончался ею.
---@param text string
---@return string[]
local function members_of(text)
    local found = {}

    for member in (text .. '|'):gmatch('([^|]*)|') do
        table.insert(found, member)
    end

    return found
end

--- Объединение типов: годится то, что прошло хотя бы один из них.
---
--- В отказе — само значение, а не тип: «целое число или строка, а не 1.5»
--- говорит, чем не подошло число, а «а не число» рядом с «целое число»
--- сбивало бы с толку.
---@param registry TntMustRegistry
---@param members string[]
---@param text string Объединение целиком, для отказа об опечатке
---@param name string|nil Имя аргумента
---@return TntMustExplain|nil explain
---@return string|nil complaint
local function union(registry, members, text, name)
    local explains = {}
    local labels = {}

    for _, member in ipairs(members) do
        local label = registry.labels[member]

        if label == nil then
            local kinds = {}

            for _, known in ipairs(registry.names) do
                if registry.labels[known] ~= nil then
                    table.insert(kinds, known)
                end
            end

            return nil,
                ('%s: в объединении «%s» «%s» — не тип, типы: %s'):format(
                    fail.named(name),
                    text,
                    member,
                    table.concat(kinds, ', ')
                )
        end

        table.insert(explains, registry.explain[member])
        table.insert(labels, label)
    end

    local expected = table.concat(labels, ' или ')

    return function(value, name_)
        for _, explain in ipairs(explains) do
            if explain(value, name_) == nil then
                return nil
            end
        end

        return fail.text(name_, expected, fail.show(value))
    end
end

--- Проверка по записи имени.
---
--- Разобранная запись запоминается: `options` разбирает по записи
--- на каждый ключ при каждом вызове, а записей в коде — считаные.
--- Одиночный `?` не разбирается вовсе: объединения из него не сложить,
--- а «не приходить» ему и так разрешено.
---@param registry TntMustRegistry
---@param cache table<string, TntMustExplain>
---@param text any Запись: имя, `?имя`, `тип|тип`
---@param name string|nil Имя аргумента — для отказа об опечатке
---@return TntMustExplain|nil explain
---@return string|nil complaint
local function resolve(registry, cache, text, name)
    if type(text) ~= 'string' then
        return nil, unknown(registry, name, text)
    end

    if text == ANY then
        return anything
    end

    if cache[text] ~= nil then
        return cache[text]
    end

    local body = text:match('^%?(.*)')
    local optional = body ~= nil

    body = body or text

    local members = members_of(body)
    local explain, complaint

    if #members == 1 then
        explain = registry.explain[body]
        complaint = unknown(registry, name, body)
    else
        explain, complaint = union(registry, members, text, name)
    end

    if explain == nil then
        return nil, complaint
    end

    if optional then
        explain = choice.maybe(explain)
    end

    cache[text] = explain

    return explain
end

--- Ключи описания настроек по порядку.
---
--- Порядок — алфавитный, а не `pairs`: первым называется первый неправильный
--- ключ, и от запуска к запуску это обязан быть один и тот же.
---@param spec table
---@param name string|nil Имя аргумента, у которого это описание
---@return string[]|nil keys
---@return string|nil complaint
local function keys_of(spec, name)
    local keys = {}

    for key in pairs(spec) do
        if type(key) ~= 'string' then
            return nil,
                fail.text(
                    fail.about('описание', name),
                    'таблица с ключами-строками',
                    ('таблица с ключом %s'):format(fail.show(key))
                )
        end

        table.insert(keys, key)
    end

    table.sort(keys)

    return keys
end

--- Ключи таблицы, которых нет в описании, по порядку.
---@param value table
---@param spec table
---@return string[]
local function strays_of(value, spec)
    local strays = {}

    for key in pairs(value) do
        if spec[key] == nil then
            table.insert(strays, tostring(key))
        end
    end

    table.sort(strays)

    return strays
end

--- Проверки, которые берут другую по имени, поверх реестра.
---
--- Реестр читается при вызове, а не при сборке: эти три проверки сами
--- попадают в него, и `options` вправе описать вложенные настройки как
--- `{ 'options', { … } }`, а список — как `{ 'array_of', 'string' }`.
---@param registry TntMustRegistry
---@return TntMustNamed
function Module.new(registry)
    local cache = {}

    --- Одна проверка по имени: `must.kind(v, 'вес', 'number|string')`.
    ---@param value any
    ---@param name string|nil
    ---@param text string Запись имени
    ---@return string|nil complaint
    local function kind(value, name, text, ...)
        local explain, complaint = resolve(registry, cache, text, name)

        if explain == nil then
            return complaint
        end

        return explain(value, name, ...)
    end

    --- Однородный список: тип элементов назван именем проверки.
    ---@param list any
    ---@param name string|nil
    ---@param text string Запись имени
    ---@return string|nil complaint
    local function array_of(list, name, text, ...)
        local explain, complaint = resolve(registry, cache, text, name)

        if explain == nil then
            return complaint
        end

        return choice.each(explain)(list, name, ...)
    end

    --- Один ключ настроек по его описанию: имя проверки либо таблица
    --- с именем и аргументами — `{ 'between', 1, 10 }`.
    ---@param given any Значение ключа
    ---@param key_name string Имя ключа в сообщении
    ---@param entry any Описание ключа
    ---@return string|nil complaint
    local function check_entry(given, key_name, entry)
        if type(entry) ~= 'table' then
            return kind(given, key_name, entry)
        end

        return kind(given, key_name, entry[1], unpack(entry, 2))
    end

    --- Таблица настроек по описанию: незнакомый ключ — отказ, каждый
    --- известный проверяется своей проверкой.
    ---
    --- Незнакомый ключ называется раньше неправильного значения: настройка
    --- с опечаткой в имени иначе просто не применилась бы, и «ключа «limt»
    --- нет» чаще и есть то, что случилось. Ключ без `?` в описании
    --- обязателен: отсутствующий отказывает как «а не nil».
    ---@param value any
    ---@param name string|nil
    ---@param spec table Описание: ключ — запись проверки
    ---@return string|nil complaint
    local function options(value, name, spec)
        local complaint = types.table(spec, fail.about('описание', name)) or types.table(value, name)

        if complaint ~= nil then
            return complaint
        end

        local keys, wrong = keys_of(spec, name)

        if keys == nil then
            return wrong
        end

        local strays = strays_of(value, spec)

        if strays[1] ~= nil then
            return ('%s: ключа «%s» нет, есть %s'):format(
                fail.named(name),
                strays[1],
                table.concat(keys, ', ')
            )
        end

        for _, key in ipairs(keys) do
            -- Ключу с `?` годится всё, и имя для отказа, которого не будет,
            -- ему не собирается: `options` стоит и на горячем пути, у повторов
            -- — на каждом вызове, а сборка строки там дороже самой проверки.
            if spec[key] ~= ANY then
                local bad = check_entry(value[key], ('%s.%s'):format(fail.named(name), key), spec[key])

                if bad ~= nil then
                    return bad
                end
            end
        end

        return nil
    end

    return { kind = kind, array_of = array_of, options = options }
end

return Module
