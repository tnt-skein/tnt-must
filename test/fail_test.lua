--- Тесты отказа: из чего сложено сообщение и на кого оно указывает.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.must.fail')

---@return any
local function fail()
    return helper.part('tnt.must.fail')
end

g.test_the_argument_is_named_in_the_message = function()
    t.assert_equals(fail().named('метка журнала'), 'метка журнала')
end

g.test_a_nameless_argument_is_called_a_value = function()
    -- Имя необязательно, но безымянный отказ — это и есть то бесполезное
    -- «строка, а не число», ради которого имя в сообщение и заведено.
    t.assert_equals(fail().named(nil), 'значение')
end

g.test_every_kind_of_value_has_a_russian_name = function()
    -- Сообщение целиком на одном языке: «строка, а не number» посреди
    -- русской фразы спотыкает. Родов у LuaJIT ровно столько, сколько здесь.
    t.assert_equals(fail().kind(nil), 'nil')
    t.assert_equals(fail().kind(true), 'логическое значение')
    t.assert_equals(fail().kind(42), 'число')
    t.assert_equals(fail().kind('узел'), 'строка')
    t.assert_equals(fail().kind({}), 'таблица')
    t.assert_equals(fail().kind(print), 'функция')
    t.assert_equals(fail().kind(io.stdout), 'userdata')
    t.assert_equals(fail().kind(1LL), 'cdata')
    t.assert_equals(fail().kind(coroutine.create(function() end)), 'сопрограмма')
end

g.test_box_null_is_called_by_name_not_by_kind = function()
    -- Так приходит `null` из JSON и msgpack: «а не cdata» о нём не сказало
    -- бы ничего, а «а не box.NULL» показывает, откуда взялось значение.
    t.assert_equals(fail().kind(box.NULL), 'box.NULL')
    t.assert_equals(fail().show(box.NULL), 'box.NULL')
end

g.test_cdata_is_shown_as_it_prints = function()
    -- У чисел, uuid, decimal и datetime `tostring` показывает само значение,
    -- и по нему видно, чем оно не годится: «-1LL» рядом с «целое uint64».
    t.assert_equals(fail().show(-1LL), '-1LL')
    t.assert_equals(fail().show(5ULL), '5ULL')
    t.assert_equals(fail().show(require('decimal').new('1.5')), '1.5')
    t.assert_equals(
        fail().show(require('uuid').fromstr('6d1f9f4e-8c7b-4a4e-9b1a-3f9e2c1d0a7b')),
        '6d1f9f4e-8c7b-4a4e-9b1a-3f9e2c1d0a7b'
    )
end

g.test_a_long_cdata_is_cut_like_a_string = function()
    -- Кортеж печатается целиком, а он бывает и на мегабайт.
    local tuple = box.tuple.new({ ('я'):rep(60) })

    t.assert_equals(fail().show(tuple), ("['%s…"):format(('я'):rep(38)))
end

g.test_an_argument_of_the_check_itself_is_named_apart_from_the_data = function()
    -- «нижняя граница для «вес» — число, а не nil» велит чинить строку
    -- с проверкой; «вес — число, а не nil» отправил бы искать в данных то,
    -- чего там нет.
    t.assert_equals(
        fail().about('нижняя граница', 'вес'),
        'нижняя граница для «вес»'
    )
    t.assert_equals(fail().about('перечень', nil), 'перечень для «значение»')
end

g.test_a_string_is_shown_in_quotes = function()
    -- Кавычки отличают аргумент-строку от аргумента-числа: «а не «3»» и «а не 3»
    -- чинятся по-разному.
    t.assert_equals(fail().show('узел'), '«узел»')
    t.assert_equals(fail().show('3'), '«3»')
    t.assert_equals(fail().show(3), '3')
end

g.test_a_long_string_is_cut_by_characters = function()
    -- Предел меряется знаками: у сорока букв кириллицы восемьдесят байтов,
    -- и байтовый предел обрезал бы их вдвое раньше.
    t.assert_equals(fail().show(('я'):rep(40)), ('«%s»'):format(('я'):rep(40)))
    t.assert_equals(fail().show(('я'):rep(41)), ('«%s…»'):format(('я'):rep(40)))
end

g.test_a_string_with_broken_bytes_is_cut_by_bytes = function()
    -- Знаков в такой строке не сосчитать; она уже испорчена, и обрубок
    -- буквы в сообщении ничего не ухудшит.
    t.assert_equals(fail().show(helper.broken(20)), ('«%s»'):format(helper.broken(20)))
    t.assert_equals(fail().show(helper.broken(21)), ('«%s…»'):format(helper.broken(20)))
end

g.test_nan_is_called_by_name = function()
    -- Печатается он на разных сборках по-разному («nan», «-nan»), а это
    -- лишний повод усомниться в своих глазах посреди сообщения об ошибке.
    t.assert_equals(fail().show(0 / 0), 'NaN')
end

g.test_a_value_without_a_readable_form_is_shown_by_its_kind = function()
    -- Адрес таблицы в памяти человеку не говорит ничего.
    t.assert_equals(fail().show(true), 'true')
    t.assert_equals(fail().show(nil), 'nil')
    t.assert_equals(fail().show({}), 'таблица')
    t.assert_equals(fail().show(print), 'функция')
end

g.test_the_message_names_the_argument_what_was_wanted_and_what_came = function()
    t.assert_equals(
        fail().text('метка журнала', 'строка', 'число'),
        'метка журнала — строка, а не число'
    )
    t.assert_equals(
        fail().text(nil, 'строка', 'число'),
        'значение — строка, а не число'
    )
end

g.test_a_check_that_says_nothing_lets_the_value_through = function()
    local check = fail().raising(function()
        return nil
    end)

    t.assert_equals(check('узел', 'метка'), 'узел')
end

g.test_the_check_gets_the_name_and_the_rest_of_the_arguments = function()
    local seen = {}

    local check = fail().raising(function(value, name, low, high)
        seen = { value = value, name = name, low = low, high = high }

        return nil
    end)

    check(5, 'вес', 1, 10)

    t.assert_equals(seen, { value = 5, name = 'вес', low = 1, high = 10 })
end

g.test_a_complaint_becomes_a_thrown_error = function()
    local check = fail().raising(function()
        return 'метка журнала — строка, а не число'
    end)

    t.assert_error_msg_equals(
        'метка журнала — строка, а не число',
        check,
        42,
        'метка журнала'
    )
end

--- Проверка, которая отказывает всегда одним и тем же текстом.
---@param level integer|nil
---@return fun(value: any, name: string|nil, ...: any): any
local function always_failing(level)
    return fail().raising(function()
        return 'отказ'
    end, level)
end

--- Отказ проверки, позванной из помощника, которого позвали из чанка:
--- два кадра Lua с выдуманными именами файлов, чтобы по месту в сообщении
--- было видно, на который из них показывает уровень.
---@param check fun(value: any, name: string|nil, ...: any): any
---@return string raised
local function raised_through_helper(check)
    -- Помощник берёт значение в переменную нарочно: хвостовой вызов снял бы
    -- его кадр со стека, и уровни считались бы уже без него.
    local helper_chunk = assert(
        loadstring(
            'local check = ...; return function(value) local v = check(value, "метка") return v end',
            '@/узел/помощник.lua'
        )
    )
    local wrapper = helper_chunk(check)
    local caller =
        assert(loadstring('local helper = ...; local v = helper(42) return v', '@/узел/настройка.lua'))
    local ok, raised = pcall(caller, wrapper)

    t.assert_equals(ok, false)

    return tostring(raised)
end

g.test_without_a_level_the_check_blames_the_line_it_stands_on = function()
    t.assert_equals(raised_through_helper(always_failing(nil)), '/узел/помощник.lua:1: отказ')
    t.assert_equals(raised_through_helper(always_failing(1)), '/узел/помощник.lua:1: отказ')
end

g.test_the_level_is_counted_as_in_error = function()
    -- Двойка — вызывающий той функции, где стоит проверка: ровно то,
    -- что `error(msg, 2)` значит для самого помощника.
    t.assert_equals(raised_through_helper(always_failing(2)), '/узел/настройка.lua:1: отказ')
end

g.test_a_level_deeper_than_the_stack_leaves_the_message_without_a_place = function()
    -- Так же ведёт себя `error`: кадра нет — места нет, а сообщение целое.
    t.assert_equals(raised_through_helper(always_failing(1000)), 'отказ')
end

--- Что бросил `raise`, позванный из чанка с выдуманным именем файла.
---@param value any
---@return any raised
local function raised_from_chunk(value)
    local chunk = assert(
        loadstring('local raise, value = ...; raise(value) return "не бросил"', '@/узел/ядро.lua')
    )
    local ok, raised = pcall(chunk, fail().raise, value)

    t.assert_equals(ok, false)

    return raised
end

g.test_raise_throws_the_text_without_any_place = function()
    -- Уровень 1 приписал бы место внутри пакета, уровень 2 — строку
    -- вызывающего; текст уходит в alerts, и места там не нужно никакого.
    t.assert_equals(
        raised_from_chunk('модель users: поля id нет'),
        'модель users: поля id нет'
    )
end

g.test_raise_throws_an_object_as_it_is = function()
    -- Объект отказа не превращается в строку: ловящий сверяет его поля.
    local refusal = { code = 'conflict' }

    t.assert_is(raised_from_chunk(refusal), refusal)
end
