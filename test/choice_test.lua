--- Тесты проверок, которые говорят не про одно значение: перечисление,
--- список целиком, необязательный аргумент.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.must.choice')

---@return any
local function choice()
    return helper.part('tnt.must.choice')
end

---@return any
local function types()
    return helper.part('tnt.must.types')
end

g.test_a_listed_value_goes_through = function()
    t.assert_equals(choice().one_of('info', 'уровень', { 'debug', 'info', 'error' }), nil)
end

g.test_an_unlisted_value_is_shown_next_to_the_whole_list = function()
    -- Перечисление коротко, и показать его целиком дешевле, чем отправить
    -- человека искать список в документе.
    t.assert_equals(
        choice().one_of('warn', 'уровень', { 'debug', 'info', 'error' }),
        'уровень — одно из «debug», «info», «error», а не «warn»'
    )
end

g.test_a_string_one_is_not_the_number_one = function()
    -- Сравнение по `==` и без приведения: иначе чужая строка однажды
    -- пройдёт туда, где ждут число.
    t.assert_equals(choice().one_of('1', 'вес', { 1, 2 }), 'вес — одно из 1, 2, а не «1»')
    t.assert_equals(choice().one_of(1, 'вес', { 1, 2 }), nil)
end

g.test_a_lone_value_instead_of_a_list_blames_the_check_itself = function()
    t.assert_equals(
        choice().one_of('info', 'уровень', 'info'),
        'перечень для «уровень» — массив, а не строка'
    )
end

g.test_every_element_of_a_list_is_checked = function()
    local all_strings = choice().each(types().string)

    t.assert_equals(all_strings({ 'a', 'b' }, 'адреса'), nil)
    t.assert_equals(all_strings({}, 'адреса'), nil)
end

g.test_the_element_is_named_by_its_place_in_the_list = function()
    -- «адреса — строка, а не число» отправляет искать глазами, какой
    -- именно из них чинить.
    local all_strings = choice().each(types().string)

    t.assert_equals(all_strings({ 'a', 2 }, 'адреса'), 'адреса[2] — строка, а не число')
    t.assert_equals(all_strings({ 'a', 2 }, nil), 'значение[2] — строка, а не число')
end

g.test_a_list_is_demanded_before_its_elements = function()
    local all_strings = choice().each(types().string)

    t.assert_equals(all_strings('a', 'адреса'), 'адреса — массив, а не строка')
    t.assert_equals(
        all_strings({ name = 'a' }, 'адреса'),
        'адреса — массив, а не таблица с ключом «name»'
    )
end

g.test_the_rest_of_the_arguments_reach_every_element = function()
    local range = helper.part('tnt.must.range')
    local all_weights = choice().each(range.between)

    t.assert_equals(all_weights({ 5, 7 }, 'веса', 1, 10), nil)
    t.assert_equals(all_weights({ 5, 20 }, 'веса', 1, 10), 'веса[2] — число от 1 до 10, а не 20')
end

g.test_a_missing_optional_argument_is_not_an_error = function()
    local maybe_string = choice().maybe(types().string)

    t.assert_equals(maybe_string(nil, 'метка'), nil)
    t.assert_equals(maybe_string('узел', 'метка'), nil)
    t.assert_equals(maybe_string(42, 'метка'), 'метка — строка, а не число')
end
