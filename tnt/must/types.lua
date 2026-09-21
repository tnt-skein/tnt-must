--- Тип значения: то, что проверяют чаще всего остального.
---
--- Каждая проверка возвращает текст отказа либо nil и ничего не бросает:
--- бросает переходник из `fail`, и только он знает, на какую строку
--- показывать. Проверки собираются друг из друга (`optional`, `all`,
--- `array_of`), и бросок из середины сборки указал бы не туда.
---
--- `number` отвергает NaN, а `integer` — ещё и бесконечность. Оба
--- проходят `type(value) == 'number'` и оба ведут себя не как число:
--- NaN ложен в любом сравнении, поэтому проскочит любую границу,
--- а бесконечность `math.floor` возвращает как есть, поэтому сойдёт
--- за целое. Всплывают они уже в вычислении — далеко от того аргумента,
--- которым пришли.

local fail = require('tnt.must.fail')

local Module = {}

--- Как тип называется в сообщении.
---
--- Объявлено один раз и снаружи: объединение типов («число или строка»)
--- складывает своё ожидание из этих же слов, и второй список разошёлся
--- бы с первым на первой же правке.
Module.LABEL = {
    string = 'строка',
    number = 'число',
    integer = 'целое число',
    boolean = 'логическое значение',
    table = 'таблица',
    callable = 'функция или вызываемая таблица',
    array = 'массив',
}

--- Строка.
---@param value any
---@param name string|nil Как назвать аргумент в сообщении
---@return string|nil complaint
function Module.string(value, name)
    if type(value) ~= 'string' then
        return fail.text(name, Module.LABEL.string, fail.kind(value))
    end

    return nil
end

--- Число, кроме NaN.
---@param value any
---@param name string|nil
---@return string|nil complaint
function Module.number(value, name)
    if type(value) ~= 'number' then
        return fail.text(name, Module.LABEL.number, fail.kind(value))
    end

    if value ~= value then
        return fail.text(name, Module.LABEL.number, fail.show(value))
    end

    return nil
end

--- Целое число: без дробной части и не бесконечность.
---
--- Числа cdata (`1LL`, счётчики `box`) целыми здесь не считаются: у них
--- тип `cdata`, а не `number`. Приводить их молча значит однажды получить
--- потерю точности там, где её никто не искал, — `tonumber` вызывает тот,
--- кто знает, что делает.
---@param value any
---@param name string|nil
---@return string|nil complaint
function Module.integer(value, name)
    if type(value) ~= 'number' then
        return fail.text(name, Module.LABEL.integer, fail.kind(value))
    end

    -- NaN отсеивается первым же сравнением: он не равен сам себе, в том
    -- числе и своему `math.floor`.
    if value ~= math.floor(value) or math.abs(value) == math.huge then
        return fail.text(name, Module.LABEL.integer, fail.show(value))
    end

    return nil
end

--- Логическое значение.
---
--- Проверка нужна там, где настройку пишут словом: `sync = 'true'` —
--- это строка, и она истинна в условии, как истинна и строка 'false'.
---@param value any
---@param name string|nil
---@return string|nil complaint
function Module.boolean(value, name)
    if type(value) ~= 'boolean' then
        return fail.text(name, Module.LABEL.boolean, fail.kind(value))
    end

    return nil
end

--- Таблица — любая, и список, и словарь.
---@param value any
---@param name string|nil
---@return string|nil complaint
function Module.table(value, name)
    if type(value) ~= 'table' then
        return fail.text(name, Module.LABEL.table, fail.kind(value))
    end

    return nil
end

--- То, что можно вызвать: функция либо таблица с метаметодом `__call`.
---
--- Одного `type(value) == 'function'` мало: двойник в проверке и обработчик
--- с состоянием — это обычно таблица с `__call`, и вызывается она ровно
--- так же. Отвергать её значит требовать замыкания там, где оно не нужно.
---@param value any
---@param name string|nil
---@return string|nil complaint
function Module.callable(value, name)
    if type(value) == 'function' then
        return nil
    end

    local meta = getmetatable(value)

    if meta ~= nil and meta.__call ~= nil then
        return nil
    end

    return fail.text(name, Module.LABEL.callable, fail.kind(value))
end

--- Список: ключи 1..n подряд и ничего сверх них.
---
--- Массив и словарь в Lua — одна и та же таблица, и отличить их можно
--- только пересчётом. Проверка нужна там, где по значению потом пойдёт
--- `ipairs`: словарь он обойдёт вхолостую, а дыру в середине примет
--- за конец списка — и обе беды выглядят как «данные пропали», а не как
--- ошибка в аргументе.
---@param value any
---@param name string|nil
---@return string|nil complaint
function Module.array(value, name)
    if type(value) ~= 'table' then
        return fail.text(name, Module.LABEL.array, fail.kind(value))
    end

    local counted = 0

    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key ~= math.floor(key) then
            return fail.text(name, Module.LABEL.array, ('таблица с ключом %s'):format(fail.show(key)))
        end

        counted = counted + 1
    end

    -- Длина `#value` у дырявой таблицы выбирается произвольно, поэтому
    -- места пересчитываются по числу ключей: их столько же, сколько нужно,
    -- а идут они не подряд.
    for index = 1, counted do
        if value[index] == nil then
            return fail.text(
                name,
                Module.LABEL.array,
                ('таблица с дырой на месте %d'):format(index)
            )
        end
    end

    return nil
end

--- Объект названного типа: у его метатаблицы поле `__type` с этим именем.
---
--- Так типы объявляет встроенный `checks`: `setmetatable(obj, { __type =
--- 'Connection' })`, и проверка `checks('Connection')` узнаёт объект по
--- имени. Это не наследование — сравнивается ровно одно поле, и объект
--- с `__type = 'Pool'` за `Connection` не сойдёт: в отказе тогда стоит
--- его собственное имя типа, а не «таблица».
---
--- Метатаблица берётся через `getmetatable`, и `__metatable` подменяет
--- её ответ чем угодно: не таблица — значит, имени типа нет.
---@param value any
---@param name string|nil
---@param typename string Имя типа в `__type`
---@return string|nil complaint
function Module.instance_of(value, name, typename)
    local complaint = Module.string(typename, fail.about('имя типа', name))

    if complaint ~= nil then
        return complaint
    end

    local meta = getmetatable(value)
    local actual = nil

    if type(meta) == 'table' then
        actual = meta.__type
    end

    if actual == typename then
        return nil
    end

    if type(actual) == 'string' then
        return fail.text(name, typename, actual)
    end

    return fail.text(name, typename, fail.kind(value))
end

return Module
