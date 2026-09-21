--- Тесты проверок типа: что признаётся правильным и что сказано о неправильном.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.must.types')

---@return any
local function types()
    return helper.part('tnt.must.types')
end

g.test_a_string_is_a_string_even_when_it_is_empty = function()
    t.assert_equals(types().string('узел', 'метка'), nil)
    t.assert_equals(types().string('', 'метка'), nil)
end

g.test_a_number_where_a_string_was_wanted_names_the_argument = function()
    t.assert_equals(
        types().string(42, 'метка журнала'),
        'метка журнала — строка, а не число'
    )
    t.assert_equals(
        types().string(nil, 'метка журнала'),
        'метка журнала — строка, а не nil'
    )
    t.assert_equals(types().string({}, nil), 'значение — строка, а не таблица')
end

g.test_a_number_is_a_number_whole_or_not = function()
    t.assert_equals(types().number(0, 'вес'), nil)
    t.assert_equals(types().number(-1.5, 'вес'), nil)
    -- Бесконечность числом считается: «без предела» ею и записывают.
    t.assert_equals(types().number(math.huge, 'вес'), nil)
end

g.test_nan_is_refused_although_type_calls_it_a_number = function()
    -- Ни одно сравнение с ним не истинно, поэтому дальше он проскочил бы
    -- любую границу и всплыл уже в вычислении.
    t.assert_equals(types().number(0 / 0, 'вес'), 'вес — число, а не NaN')
    t.assert_equals(types().number('3', 'вес'), 'вес — число, а не строка')
end

g.test_a_whole_number_is_an_integer = function()
    t.assert_equals(types().integer(0, 'предел'), nil)
    t.assert_equals(types().integer(-3, 'предел'), nil)
    t.assert_equals(types().integer(1e3, 'предел'), nil)
end

g.test_a_fraction_is_not_an_integer = function()
    t.assert_equals(types().integer(1.5, 'предел'), 'предел — целое число, а не 1.5')
    t.assert_equals(
        types().integer('3', 'предел'),
        'предел — целое число, а не строка'
    )
    t.assert_equals(types().integer(0 / 0, 'предел'), 'предел — целое число, а не NaN')
end

g.test_infinity_is_not_an_integer_although_it_has_no_fraction = function()
    -- `math.floor` возвращает бесконечность как есть, поэтому одной проверки
    -- дробной части мало: без явного отказа она сошла бы за целое.
    t.assert_equals(types().integer(math.huge, 'предел'), 'предел — целое число, а не inf')
    t.assert_equals(types().integer(-math.huge, 'предел'), 'предел — целое число, а не -inf')
end

g.test_a_word_true_is_not_a_boolean = function()
    -- Настройку пишут словом чаще, чем кажется, а строка 'false' истинна
    -- в условии ровно так же, как строка 'true'.
    t.assert_equals(types().boolean(true, 'признак'), nil)
    t.assert_equals(types().boolean(false, 'признак'), nil)
    t.assert_equals(
        types().boolean('true', 'признак'),
        'признак — логическое значение, а не строка'
    )
end

g.test_a_table_is_any_table = function()
    t.assert_equals(types().table({}, 'настройки'), nil)
    t.assert_equals(types().table({ tag = 'x' }, 'настройки'), nil)
    t.assert_equals(
        types().table('tag=x', 'настройки'),
        'настройки — таблица, а не строка'
    )
end

g.test_a_function_and_a_table_with_a_call_are_both_callable = function()
    -- Двойник в проверке и обработчик с состоянием — это обычно таблица
    -- с `__call`, и вызывается она ровно так же, как функция.
    local object = setmetatable({}, {
        __call = function()
            return true
        end,
    })

    t.assert_equals(types().callable(print, 'обработчик'), nil)
    t.assert_equals(types().callable(object, 'обработчик'), nil)
end

g.test_what_cannot_be_called_is_refused = function()
    t.assert_equals(
        types().callable('print', 'обработчик'),
        'обработчик — функция или вызываемая таблица, а не строка'
    )
    t.assert_equals(
        types().callable({}, 'обработчик'),
        'обработчик — функция или вызываемая таблица, а не таблица'
    )
end

g.test_a_hidden_metatable_does_not_make_a_table_callable = function()
    -- `__metatable` подменяет ответ `getmetatable` чем угодно: спрашивать
    -- у него `__call` можно, но верить ответу нельзя.
    local closed = setmetatable({}, { __call = print, __metatable = 'закрыто' })

    t.assert_equals(
        types().callable(closed, 'обработчик'),
        'обработчик — функция или вызываемая таблица, а не таблица'
    )
end

g.test_an_array_is_a_table_with_keys_in_a_row = function()
    t.assert_equals(types().array({}, 'узлы'), nil)
    t.assert_equals(types().array({ 'a', 'b', 'c' }, 'узлы'), nil)
    t.assert_equals(types().array('a', 'узлы'), 'узлы — массив, а не строка')
end

g.test_a_dictionary_is_not_an_array_and_the_stray_key_is_named = function()
    -- `ipairs` обошёл бы такую таблицу вхолостую, и это выглядит как
    -- «данные пропали», а не как ошибка в аргументе.
    t.assert_equals(
        types().array({ name = 'x' }, 'узлы'),
        'узлы — массив, а не таблица с ключом «name»'
    )
    t.assert_equals(
        types().array({ [1.5] = 'x' }, 'узлы'),
        'узлы — массив, а не таблица с ключом 1.5'
    )
    t.assert_equals(
        types().array({ [0] = 'x' }, 'узлы'),
        'узлы — массив, а не таблица с ключом 0'
    )
end

g.test_a_hole_in_the_middle_is_named_by_its_place = function()
    -- Дыру `ipairs` принимает за конец списка: половина аргументов теряется
    -- без единого слова.
    t.assert_equals(
        types().array({ 'a', nil, 'c' }, 'узлы'),
        'узлы — массив, а не таблица с дырой на месте 2'
    )
    t.assert_equals(
        types().array({ [2] = 'b' }, 'узлы'),
        'узлы — массив, а не таблица с дырой на месте 1'
    )
end

g.test_every_kind_has_a_label_that_its_message_uses = function()
    -- Подпись объявлена один раз: из неё складывается и отказ самой
    -- проверки, и ожидание объединения типов.
    for name, label in pairs(types().LABEL) do
        t.assert_equals(type(types()[name]), 'function', name)
        t.assert_equals(types()[name](io.stdout, name), ('%s — %s, а не userdata'):format(name, label))
    end
end

g.test_an_object_is_recognized_by_the_type_name_of_its_metatable = function()
    -- Так типы объявляет встроенный `checks`: `__type` в метатаблице.
    local connection = setmetatable({}, { __type = 'Connection' })

    t.assert_equals(types().instance_of(connection, 'соединение', 'Connection'), nil)
    t.assert_equals(
        types().instance_of({}, 'соединение', 'Connection'),
        'соединение — Connection, а не таблица'
    )
    t.assert_equals(
        types().instance_of('conn', 'соединение', 'Connection'),
        'соединение — Connection, а не строка'
    )
end

g.test_an_object_of_another_type_is_named_by_its_own_type = function()
    -- «а не Pool» говорит, что перепутали, а «а не таблица» — нет.
    local pool = setmetatable({}, { __type = 'Pool' })

    t.assert_equals(
        types().instance_of(pool, 'соединение', 'Connection'),
        'соединение — Connection, а не Pool'
    )
end

g.test_a_type_name_that_is_not_a_string_does_not_count = function()
    -- Сравнивается ровно одно поле, и число в нём — не имя типа.
    local odd = setmetatable({}, { __type = 5 })

    t.assert_equals(
        types().instance_of(odd, 'соединение', 'Connection'),
        'соединение — Connection, а не таблица'
    )
    t.assert_equals(
        types().instance_of(odd, 'соединение', 5),
        'имя типа для «соединение» — строка, а не число'
    )
end

g.test_a_hidden_metatable_has_no_type_name = function()
    -- `__metatable` подменяет ответ `getmetatable` чем угодно, и у строки
    -- имени типа не спросить.
    local closed = setmetatable({}, { __type = 'Connection', __metatable = 'закрыто' })

    t.assert_equals(
        types().instance_of(closed, 'соединение', 'Connection'),
        'соединение — Connection, а не таблица'
    )
    t.assert_equals(
        types().instance_of(1LL, 'соединение', 'Connection'),
        'соединение — Connection, а не cdata'
    )
end

g.test_the_type_name_is_an_argument_of_the_check_itself = function()
    t.assert_equals(
        types().instance_of({}, 'соединение'),
        'имя типа для «соединение» — строка, а не nil'
    )
end
