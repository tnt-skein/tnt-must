--- Тесты строковых проверок: пустота, образец, длина.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.must.text')

---@return any
local function text()
    return helper.part('tnt.must.text')
end

g.test_an_empty_string_is_not_a_filled_one = function()
    -- Она проходит проверку типа, доезжает до записи и оставляет поле,
    -- которого будто и не было.
    t.assert_equals(text().not_empty('узел', 'метка'), nil)
    t.assert_equals(
        text().not_empty('', 'метка'),
        'метка — непустая строка, а не пустая'
    )
    t.assert_equals(text().not_empty(nil, 'метка'), 'метка — непустая строка, а не nil')
end

g.test_spaces_are_not_emptiness = function()
    -- « » — это не пусто: делать вид, что пусто, значит спорить с тем,
    -- что человек набрал.
    t.assert_equals(text().not_empty(' ', 'метка'), nil)
end

g.test_a_pattern_is_a_lua_pattern = function()
    t.assert_equals(text().matches('storage-001', 'имя узла', '^[%w-]+$'), nil)
    t.assert_equals(
        text().matches('узел 1', 'имя узла', '^[%w-]+$'),
        'имя узла — строка по образцу ^[%w-]+$, а не «узел 1»'
    )
    t.assert_equals(
        text().matches(42, 'имя узла', '^[%w-]+$'),
        'имя узла — строка по образцу ^[%w-]+$, а не число'
    )
end

g.test_a_pattern_without_anchors_is_looked_for_anywhere = function()
    -- Так работает `string.find`, и притворяться, что иначе, дороже:
    -- привязка пишется явно и видна в сообщении об отказе.
    t.assert_equals(text().matches('storage-001', 'имя узла', '%d%d%d'), nil)
end

g.test_a_forgotten_pattern_blames_the_check_itself = function()
    -- Без этого `string.find` отказывает изнутри пакета, и место в отказе
    -- показывает на tnt-must вместо строки с проверкой.
    t.assert_equals(
        text().matches('узел', 'имя узла'),
        'образец для «имя узла» — строка, а не nil'
    )
end

g.test_a_boundary_of_the_wrong_kind_blames_the_check_itself = function()
    t.assert_equals(
        text().length('узел', 'имя', '2'),
        'нижняя граница для «имя» — число, а не строка'
    )
    t.assert_equals(
        text().length('узел', 'имя', 1, '8'),
        'верхняя граница для «имя» — число, а не строка'
    )
end

g.test_length_counts_characters_and_not_bytes = function()
    -- «Узел» — это четыре знака и восемь байтов: предел в байтах обрезал бы
    -- кириллицу вдвое раньше, чем ждёт тот, кто написал «не длиннее».
    t.assert_equals(text().length('Узел', 'имя', 4, 4), nil)
    t.assert_equals(
        text().length('Узел', 'имя', 5, 64),
        'имя — строка длиной от 5 до 64 знаков, а не 4'
    )
end

g.test_a_string_with_broken_bytes_is_measured_in_bytes = function()
    -- Знаков в ней не сосчитать; отказать вовсе значило бы соврать про
    -- длину, а посчитать байты — сказать хоть что-то верное.
    t.assert_equals(text().length(helper.broken(2), 'имя', 4, 4), nil)
end

g.test_a_single_boundary_is_enough = function()
    t.assert_equals(text().length('узел', 'имя', 2), nil)
    t.assert_equals(
        text().length('у', 'имя', 2),
        'имя — строка длиной не меньше 2 знаков, а не 1'
    )
    t.assert_equals(text().length('узел', 'имя', nil, 8), nil)
    t.assert_equals(
        text().length('узел кластера', 'имя', nil, 8),
        'имя — строка длиной не больше 8 знаков, а не 13'
    )
end

g.test_a_length_check_without_boundaries_blames_the_check_itself = function()
    -- Сообщение «строка длиной от nil до nil» человек пойдёт искать
    -- в своих данных, а чинить надо строку, в которой стоит проверка.
    t.assert_equals(
        text().length('узел', 'имя'),
        'имя: у проверки длины нет ни одной границы'
    )
    t.assert_equals(
        text().length('узел'),
        'значение: у проверки длины нет ни одной границы'
    )
end

g.test_length_demands_a_string_first = function()
    t.assert_equals(
        text().length(4, 'имя', 1, 64),
        'имя — строка длиной от 1 до 64 знаков, а не число'
    )
end
