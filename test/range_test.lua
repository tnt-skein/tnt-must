--- Тесты числовых границ: что попадает в допустимое и что сказано о том,
--- что не попало.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.must.range')

---@return any
local function range()
    return helper.part('tnt.must.range')
end

g.test_greater_than_demands_a_strict_excess = function()
    t.assert_equals(range().greater_than(6, 'срок', 5), nil)
    t.assert_equals(range().greater_than(5, 'срок', 5), 'срок — число больше 5, а не 5')
    t.assert_equals(range().greater_than(4, 'срок', 5), 'срок — число больше 5, а не 4')
end

g.test_less_than_demands_a_strict_shortfall = function()
    t.assert_equals(range().less_than(4, 'срок', 5), nil)
    t.assert_equals(range().less_than(5, 'срок', 5), 'срок — число меньше 5, а не 5')
    t.assert_equals(range().less_than(6, 'срок', 5), 'срок — число меньше 5, а не 6')
end

g.test_the_message_says_what_was_wanted_and_not_just_a_number = function()
    -- «срок — число, а не строка» стоит столько же, а чинить по нему
    -- нечего: какое там ждали число, из него не видно.
    t.assert_equals(
        range().greater_than('5', 'срок', 5),
        'срок — число больше 5, а не строка'
    )
    t.assert_equals(range().less_than(nil, 'срок', 5), 'срок — число меньше 5, а не nil')
end

g.test_nan_does_not_slip_past_a_boundary = function()
    -- Он ложен в любом сравнении: и `> 0`, и `< 0` — поэтому границу
    -- миновал бы молча.
    t.assert_equals(range().greater_than(0 / 0, 'срок', 5), 'срок — число больше 5, а не NaN')
    t.assert_equals(
        range().positive(0 / 0, 'размер куска'),
        'размер куска — число больше 0, а не NaN'
    )
    t.assert_equals(
        range().non_negative(0 / 0, 'отступ'),
        'отступ — число не меньше 0, а не NaN'
    )
    t.assert_equals(range().between(0 / 0, 'вес', 1, 10), 'вес — число от 1 до 10, а не NaN')
end

g.test_a_forgotten_boundary_blames_the_check_itself = function()
    -- Иначе она всплывёт сравнением с nil внутри пакета, и человек пойдёт
    -- читать чужой код вместо своей строки — ровно то, ради чего пакет
    -- и написан.
    t.assert_equals(
        range().greater_than(5, 'срок'),
        'граница для «срок» — число, а не nil'
    )
    t.assert_equals(range().less_than(5, 'срок'), 'граница для «срок» — число, а не nil')
    t.assert_equals(
        range().between(5, 'вес', nil, 10),
        'нижняя граница для «вес» — число, а не nil'
    )
    t.assert_equals(
        range().between(5, 'вес', 1),
        'верхняя граница для «вес» — число, а не nil'
    )
    t.assert_equals(
        range().greater_than(5, nil, '4'),
        'граница для «значение» — число, а не строка'
    )
end

g.test_zero_is_not_positive = function()
    -- Размер куска, ширина поля и число попыток при нуле уводят цикл
    -- в бесконечность либо не делают ничего, и оба исхода объясняются долго.
    t.assert_equals(range().positive(1, 'размер куска'), nil)
    t.assert_equals(range().positive(0.5, 'размер куска'), nil)
    t.assert_equals(
        range().positive(0, 'размер куска'),
        'размер куска — число больше 0, а не 0'
    )
    t.assert_equals(
        range().positive(-2, 'размер куска'),
        'размер куска — число больше 0, а не -2'
    )
end

g.test_zero_is_not_negative = function()
    t.assert_equals(range().non_negative(0, 'отступ'), nil)
    t.assert_equals(range().non_negative(0.5, 'отступ'), nil)
    t.assert_equals(
        range().non_negative(-0.5, 'отступ'),
        'отступ — число не меньше 0, а не -0.5'
    )
    t.assert_equals(
        range().non_negative('0', 'отступ'),
        'отступ — число не меньше 0, а не строка'
    )
end

g.test_both_ends_of_a_range_are_allowed = function()
    t.assert_equals(range().between(1, 'вес', 1, 10), nil)
    t.assert_equals(range().between(10, 'вес', 1, 10), nil)
    t.assert_equals(range().between(0.5, 'вес', 1, 10), 'вес — число от 1 до 10, а не 0.5')
    t.assert_equals(range().between(10.5, 'вес', 1, 10), 'вес — число от 1 до 10, а не 10.5')
    t.assert_equals(
        range().between({}, 'вес', 1, 10),
        'вес — число от 1 до 10, а не таблица'
    )
end
