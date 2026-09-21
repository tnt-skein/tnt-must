--- Общие средства проверок пакета.
---
--- Сообщения сравниваются целиком и дословно: текст отказа — это и есть
--- то, ради чего пакет написан, и «где-то там сказано про строку» его
--- не проверяет. Места вызова в начале сообщения при этом нет: `pcall`
--- зовёт проверку сам, а `error(msg, 2)` упирается в его C-кадр, о котором
--- Lua сказать нечего. Что место появляется, когда проверку зовут из кода
--- на Lua, проверяется отдельно и нарочно.
---
--- Исходники грузятся с диска, а не через `require`: у Tarantool свой
--- загрузчик `.rocks`, он идёт раньше `package.path` и подсунул бы
--- установленную копию пакета, если она есть. Проверки тогда шли бы
--- против вчерашнего кода, а покрытие считалось бы по нему. Поэтому
--- файлы читаются сами, в порядке зависимостей, и кладутся
--- в `package.loaded` под именами модулей: `require` изнутри пакета
--- находит их первыми.

local fio = require('fio')

local helper = {}

--- Модули пакета в порядке зависимостей.
helper.MODULES = {
    { name = 'tnt.must.fail', path = 'tnt/must/fail.lua' },
    { name = 'tnt.must.types', path = 'tnt/must/types.lua' },
    { name = 'tnt.must.range', path = 'tnt/must/range.lua' },
    { name = 'tnt.must.text', path = 'tnt/must/text.lua' },
    { name = 'tnt.must.choice', path = 'tnt/must/choice.lua' },
    { name = 'tnt.must.cdata', path = 'tnt/must/cdata.lua' },
    { name = 'tnt.must.spec', path = 'tnt/must/spec.lua' },
    { name = 'tnt.must', path = 'tnt/must.lua' },
}

--- Части пакета: имя модуля → его таблица.
---
--- Грузятся один раз на процесс: своего состояния у пакета нет — ни
--- настроек, ни подменяемых средств, — и перезагружать его незачем.
--- А цена перезагрузки заметная: мутационный прогон гоняет набор тысячи раз.
---@type table<string, any>
local PARTS = {}

for _, module in ipairs(helper.MODULES) do
    local chunk, failure = loadfile(fio.abspath(module.path))

    if chunk == nil then
        error(('исходник %s не читается: %s'):format(module.name, tostring(failure)))
    end

    local value = chunk()

    -- Пустое значение в `package.loaded` для `require` значит «не загружен»,
    -- и следующий модуль списка молча взял бы зависимость из `.rocks`.
    if value == nil then
        error(('исходник %s не вернул модуль'):format(module.name))
    end

    package.loaded[module.name] = value
    PARTS[module.name] = value
end

--- Фасад пакета, собранный из исходников.
helper.must = PARTS['tnt.must']

--- Отдельный модуль пакета.
---@param name string
---@return any
function helper.part(name)
    local part = PARTS[name]

    if part == nil then
        error(('модуль %s не из пакета tnt-must'):format(name))
    end

    return part
end

--- Строка с битыми байтами: знаков в ней не сосчитать.
---@param times integer Сколько раз повторить неправильную пару байтов
---@return string
function helper.broken(times)
    return ('\xff\xfe'):rep(times)
end

return helper
