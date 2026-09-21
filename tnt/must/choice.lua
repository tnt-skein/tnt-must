--- Проверки, которые говорят не про одно значение.
---
--- `one_of` сверяет со списком допустимых, `each` проходит по списку
--- целиком, `maybe` разрешает аргументу не приходить вовсе. Последние две
--- собираются из других проверок — из них фасад делает `all.*`
--- и `optional.*`, а `spec` — проверки, названные по имени.
---
--- Собранная проверка остаётся проверкой того же типа: она возвращает
--- текст отказа либо nil и ничего не бросает. Бросок посреди сборки
--- показал бы на строку внутри tnt-must вместо строки вызывающего.

local fail = require('tnt.must.fail')
local types = require('tnt.must.types')

local Module = {}

--- Одно из перечисленного.
---
--- Сравнение по `==` и без приведения: `'1'` — не то же, что `1`, и
--- считать их одним значит однажды пропустить строку туда, где ждут число.
---@param value any
---@param name string|nil
---@param allowed any[] Список допустимых значений
---@return string|nil complaint
function Module.one_of(value, name, allowed)
    local complaint = types.array(allowed, fail.about('перечень', name))

    if complaint ~= nil then
        return complaint
    end

    local shown = {}

    for _, candidate in ipairs(allowed) do
        if candidate == value then
            return nil
        end

        table.insert(shown, fail.show(candidate))
    end

    return fail.text(name, ('одно из %s'):format(table.concat(shown, ', ')), fail.show(value))
end

--- Проверка каждого элемента списка — из проверки одного элемента.
---
--- Имя элемента — имя списка с номером: «узлы[2] — строка, а не число»
--- говорит, какой именно элемент чинить, а «узлы — строка, а не число»
--- отправляет искать глазами.
---
--- Отказ возвращается первый: список аргументов проверяют не затем, чтобы
--- собрать все ошибки разом, — это дело `tnt-validate`, — а затем, чтобы
--- не идти дальше с неправильным аргументом.
---@param explain fun(value: any, name: string|nil, ...: any): string|nil
---@return fun(list: any, name: string|nil, ...: any): string|nil
function Module.each(explain)
    return function(list, name, ...)
        local complaint = types.array(list, name)

        if complaint ~= nil then
            return complaint
        end

        for index, item in ipairs(list) do
            local bad = explain(item, ('%s[%d]'):format(fail.named(name), index), ...)

            if bad ~= nil then
                return bad
            end
        end

        return nil
    end
end

--- Аргумент, которого может не быть.
---
--- nil проходит, всё остальное проверяется как обычно. Без такой обёртки
--- необязательный аргумент обкладывают условием в вызывающем, и условие
--- это однажды напишут наоборот.
---@param explain fun(value: any, name: string|nil, ...: any): string|nil
---@return fun(value: any, name: string|nil, ...: any): string|nil
function Module.maybe(explain)
    return function(value, name, ...)
        if value == nil then
            return nil
        end

        return explain(value, name, ...)
    end
end

return Module
