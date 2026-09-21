--- Тесты проверок, названных строкой: одна по имени, по одной на элемент
--- списка, по одной на ключ таблицы настроек.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.must.spec')

---@return any
local function spec()
    return helper.part('tnt.must.spec')
end

--- Реестр из трёх типов и одной проверки с аргументами, собранный руками:
--- по нему видно, что берётся из реестра, а что — из самой записи.
---@return any registry
---@return any named
local function small()
    local types = helper.part('tnt.must.types')
    local range = helper.part('tnt.must.range')
    local registry = {
        explain = { string = types.string, number = types.number, table = types.table, between = range.between },
        names = { 'string', 'number', 'table', 'between' },
        labels = { string = 'строка', number = 'число', table = 'таблица' },
    }

    return registry, spec().new(registry)
end

g.test_a_check_is_taken_from_the_registry_by_name = function()
    local _, named = small()

    t.assert_equals(named.kind('узел', 'метка', 'string'), nil)
    t.assert_equals(named.kind(42, 'метка', 'string'), 'метка — строка, а не число')
end

g.test_the_rest_of_the_arguments_reach_the_named_check = function()
    local _, named = small()

    t.assert_equals(named.kind(5, 'вес', 'between', 1, 10), nil)
    t.assert_equals(named.kind(42, 'вес', 'between', 1, 10), 'вес — число от 1 до 10, а не 42')
end

g.test_a_misspelled_name_is_answered_with_the_whole_list = function()
    local _, named = small()

    t.assert_equals(
        named.kind('узел', 'метка', 'strng'),
        'метка: проверки «strng» нет, есть string, number, table, between'
    )
    t.assert_equals(
        named.kind('узел', nil, nil),
        'значение: проверки «nil» нет, есть string, number, table, between'
    )
    t.assert_equals(
        named.kind('узел', 'метка', ''),
        'метка: проверки «» нет, есть string, number, table, between'
    )
end

g.test_a_question_mark_lets_the_argument_be_absent = function()
    -- Как у встроенного `checks`: `?` впереди — аргумент может не прийти.
    local _, named = small()

    t.assert_equals(named.kind(nil, 'метка', '?string'), nil)
    t.assert_equals(named.kind('узел', 'метка', '?string'), nil)
    t.assert_equals(named.kind(42, 'метка', '?string'), 'метка — строка, а не число')
    t.assert_equals(named.kind(nil, 'метка', 'string'), 'метка — строка, а не nil')
end

g.test_a_question_mark_counts_only_in_front = function()
    local _, named = small()

    t.assert_equals(
        named.kind(nil, 'метка', 'string?'),
        'метка: проверки «string?» нет, есть string, number, table, between'
    )
    t.assert_equals(
        named.kind(nil, 'метка', '??'),
        'метка: проверки «?» нет, есть string, number, table, between'
    )
    t.assert_equals(
        named.kind(nil, 'метка', '?|string'),
        'метка: в объединении «?|string» «» — не тип, типы: string, number, table'
    )
end

g.test_a_lone_question_mark_takes_any_value = function()
    -- Как у встроенного `checks`: `?` сам по себе — любое значение,
    -- и отсутствующее тоже.
    local _, named = small()

    for _, value in ipairs({ 'узел', 42, true, {}, print, box.NULL }) do
        t.assert_equals(named.kind(value, 'метка', '?'), nil, tostring(value))
    end

    t.assert_equals(named.kind(nil, 'метка', '?'), nil)
end

g.test_a_lone_question_mark_still_wants_a_list_from_array_of = function()
    -- Любым годится элемент, а не сам аргумент: список обязан быть списком.
    local _, named = small()

    t.assert_equals(named.array_of({ 'узел', 42, {} }, 'адреса', '?'), nil)
    t.assert_equals(
        named.array_of('узел', 'адреса', '?'),
        'адреса — массив, а не строка'
    )
end

g.test_a_lone_question_mark_marks_a_key_known_in_options = function()
    -- Так описывают ключ, значение которого вызывающий проверяет сам:
    -- набор ключей общий, а отказ о значении остаётся своим.
    local _, named = small()
    local known = { build = '?', name = 'string' }

    t.assert_equals(named.options({ name = 'app', build = 'позже' }, 'приложение', known), nil)
    t.assert_equals(named.options({ name = 'app' }, 'приложение', known), nil)
    t.assert_equals(
        named.options({ name = 'app', buid = 1 }, 'приложение', known),
        'приложение: ключа «buid» нет, есть build, name'
    )
    t.assert_equals(
        named.options({ name = 42, build = 'позже' }, 'приложение', known),
        'приложение.name — строка, а не число'
    )
end

g.test_a_union_passes_what_any_of_its_kinds_passes = function()
    local _, named = small()

    t.assert_equals(named.kind(42, 'вес', 'number|string'), nil)
    t.assert_equals(named.kind('42', 'вес', 'number|string'), nil)
    t.assert_equals(named.kind({}, 'вес', 'number|string|table'), nil)
    t.assert_equals(named.kind(nil, 'вес', '?number|string'), nil)
end

g.test_a_union_names_all_its_kinds_and_the_value_itself = function()
    -- Само значение, а не тип: «целое число или строка, а не 1.5» говорит,
    -- чем не подошло число, а «а не число» рядом с «целое» сбивало бы.
    local _, named = small()

    t.assert_equals(
        named.kind(true, 'вес', 'number|string'),
        'вес — число или строка, а не true'
    )
    t.assert_equals(
        named.kind({}, 'вес', 'number|string'),
        'вес — число или строка, а не таблица'
    )
    t.assert_equals(
        named.kind(0 / 0, 'вес', 'number|string'),
        'вес — число или строка, а не NaN'
    )
    t.assert_equals(
        named.kind(nil, nil, 'number|string'),
        'значение — число или строка, а не nil'
    )
end

g.test_only_kinds_join_a_union = function()
    -- У `between` ожидание зависит от границ, и складывать его не из чего.
    local _, named = small()

    t.assert_equals(
        named.kind(5, 'вес', 'number|between'),
        'вес: в объединении «number|between» «between» — не тип, типы: string, number, table'
    )
    t.assert_equals(
        named.kind(5, 'вес', 'number|strng'),
        'вес: в объединении «number|strng» «strng» — не тип, типы: string, number, table'
    )
end

g.test_an_empty_member_of_a_union_is_a_typo = function()
    -- `gmatch('[^|]+')` проглотил бы её молча.
    local _, named = small()

    t.assert_equals(
        named.kind(5, 'вес', 'number|'),
        'вес: в объединении «number|» «» — не тип, типы: string, number, table'
    )
    t.assert_equals(
        named.kind(5, 'вес', 'number||string'),
        'вес: в объединении «number||string» «» — не тип, типы: string, number, table'
    )
end

g.test_a_parsed_record_is_kept_and_reused = function()
    -- Разбор идёт один раз на запись: `options` разбирает по записи
    -- на каждый ключ при каждом вызове.
    local registry, named = small()

    t.assert_equals(named.kind(42, 'вес', 'number|string'), nil)
    t.assert_equals(named.kind(42, 'вес', 'number'), nil)

    registry.labels.number = nil
    registry.explain.number = nil

    t.assert_equals(named.kind(42, 'вес', 'number|string'), nil)
    t.assert_equals(named.kind(42, 'вес', 'number'), nil)
    t.assert_equals(
        named.kind(42, 'вес', '?number'),
        'вес: проверки «number» нет, есть string, number, table, between'
    )
end

g.test_the_registry_is_read_when_the_check_is_called = function()
    -- Проверки по имени сами входят в реестр, и появиться там они могут
    -- только после сборки.
    local registry, named = small()

    registry.explain.late = named.kind
    table.insert(registry.names, 'late')

    t.assert_equals(named.kind(42, 'вес', 'late', 'string'), 'вес — строка, а не число')
end

g.test_a_list_of_one_kind_takes_the_kind_by_name = function()
    local _, named = small()

    t.assert_equals(named.array_of({ 'a', 'b' }, 'адреса', 'string'), nil)
    t.assert_equals(
        named.array_of({ 'a', 2 }, 'адреса', 'string'),
        'адреса[2] — строка, а не число'
    )
    t.assert_equals(
        named.array_of({ 5, 20 }, 'веса', 'between', 1, 10),
        'веса[2] — число от 1 до 10, а не 20'
    )
    t.assert_equals(
        named.array_of({ 1, 'a', true }, 'веса', 'number|string'),
        'веса[3] — число или строка, а не true'
    )
end

g.test_a_list_is_demanded_before_its_kind_is_checked = function()
    local _, named = small()

    t.assert_equals(
        named.array_of('a', 'адреса', 'string'),
        'адреса — массив, а не строка'
    )
    t.assert_equals(
        named.array_of({ 'a' }, 'адреса', 'strng'),
        'адреса: проверки «strng» нет, есть string, number, table, between'
    )
end

--- Описание настроек, как его написал бы вызывающий.
local SPEC = {
    tag = 'string',
    limit = '?number',
    weight = { 'between', 1, 10 },
    label = { '?string|number' },
}

g.test_options_pass_when_every_key_is_known_and_fits = function()
    local _, named = small()

    t.assert_equals(named.options({ tag = 'журнал', weight = 5 }, 'настройки', SPEC), nil)
    t.assert_equals(
        named.options({ tag = 'журнал', weight = 5, limit = 10, label = 7 }, 'настройки', SPEC),
        nil
    )
end

g.test_an_unknown_key_is_named_next_to_the_known_ones = function()
    -- Настройка с опечаткой в имени иначе просто не применилась бы.
    local _, named = small()

    t.assert_equals(
        named.options({ tag = 'журнал', weight = 5, limt = 10 }, 'настройки', SPEC),
        'настройки: ключа «limt» нет, есть label, limit, tag, weight'
    )
    t.assert_equals(
        named.options({ [1] = 'журнал' }, nil, SPEC),
        'значение: ключа «1» нет, есть label, limit, tag, weight'
    )
end

g.test_the_first_stray_key_in_alphabetical_order_is_named = function()
    -- Порядок `pairs` меняется от запуска к запуску, а сообщение — нет.
    local _, named = small()

    t.assert_equals(
        named.options({ zzz = 1, aaa = 2 }, 'настройки', SPEC),
        'настройки: ключа «aaa» нет, есть label, limit, tag, weight'
    )
end

g.test_an_unknown_key_is_reported_before_a_bad_value = function()
    local _, named = small()

    t.assert_equals(
        named.options({ tag = 42, limt = 10 }, 'настройки', SPEC),
        'настройки: ключа «limt» нет, есть label, limit, tag, weight'
    )
end

g.test_a_key_is_named_with_the_table_it_lives_in = function()
    local _, named = small()

    t.assert_equals(
        named.options({ tag = 42, weight = 5 }, 'настройки', SPEC),
        'настройки.tag — строка, а не число'
    )
    t.assert_equals(named.options({ tag = 42 }, nil, SPEC), 'значение.tag — строка, а не число')
end

g.test_a_key_without_a_question_mark_is_required = function()
    local _, named = small()

    t.assert_equals(
        named.options({ tag = 'журнал' }, 'настройки', SPEC),
        'настройки.weight — число от 1 до 10, а не nil'
    )
end

g.test_the_keys_are_checked_in_alphabetical_order = function()
    local _, named = small()

    t.assert_equals(
        named.options({ tag = 42, weight = 42 }, 'настройки', SPEC),
        'настройки.tag — строка, а не число'
    )
end

g.test_a_table_entry_carries_the_arguments_of_the_check = function()
    local _, named = small()

    t.assert_equals(
        named.options({ tag = 'журнал', weight = 42 }, 'настройки', SPEC),
        'настройки.weight — число от 1 до 10, а не 42'
    )
    t.assert_equals(
        named.options({ tag = 'журнал', weight = 5, label = true }, 'настройки', SPEC),
        'настройки.label — строка или число, а не true'
    )
end

g.test_a_bad_entry_of_the_description_blames_the_check_itself = function()
    local _, named = small()

    t.assert_equals(
        named.options({ tag = 'журнал' }, 'настройки', { tag = 'strng' }),
        'настройки.tag: проверки «strng» нет, есть string, number, table, between'
    )
    t.assert_equals(
        named.options({ tag = 'журнал' }, 'настройки', { tag = 5 }),
        'настройки.tag: проверки «5» нет, есть string, number, table, between'
    )
    t.assert_equals(
        named.options({ tag = 'журнал' }, 'настройки', { tag = {} }),
        'настройки.tag: проверки «nil» нет, есть string, number, table, between'
    )
    t.assert_equals(
        named.options({ weight = 5 }, 'настройки', { weight = { 'between', '1', 10 } }),
        'нижняя граница для «настройки.weight» — число, а не строка'
    )
end

g.test_the_description_itself_is_demanded = function()
    local _, named = small()

    t.assert_equals(
        named.options({}, 'настройки'),
        'описание для «настройки» — таблица, а не nil'
    )
    t.assert_equals(
        named.options({}, 'настройки', { 'string' }),
        'описание для «настройки» — таблица с ключами-строками, а не таблица с ключом 1'
    )
end

g.test_the_options_must_be_a_table = function()
    local _, named = small()

    t.assert_equals(
        named.options('журнал', 'настройки', SPEC),
        'настройки — таблица, а не строка'
    )
    t.assert_equals(
        named.options(nil, 'настройки', SPEC),
        'настройки — таблица, а не nil'
    )
end
