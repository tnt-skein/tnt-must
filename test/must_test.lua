--- Тесты фасада: что в нём есть, что он возвращает и на чью строку
--- показывает отказ.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.must')

local must = helper.must

--- Типы — то, что объединяется через «|»: у каждого есть подпись.
local KINDS = {
    'string',
    'number',
    'integer',
    'boolean',
    'table',
    'callable',
    'array',
    'uint64',
    'int64',
    'decimal',
    'uuid',
    'tuple',
    'datetime',
    'interval',
    'error',
}

--- Остальные проверки фасада, в порядке объявления.
local OTHERS = {
    'instance_of',
    'positive',
    'non_negative',
    'greater_than',
    'less_than',
    'between',
    'not_empty',
    'matches',
    'length',
    'one_of',
    'kind',
    'array_of',
    'options',
}

--- Все проверки фасада. Списки повторены здесь нарочно: они и есть
--- договор пакета, и молчаливая пропажа проверки из них — это чужой код,
--- который перестанет собираться.
local NAMES = {}

for _, list in ipairs({ KINDS, OTHERS }) do
    for _, name in ipairs(list) do
        table.insert(NAMES, name)
    end
end

--- Отказ разбора кода, написанного так, как его написал бы вызывающий.
---@param source string Тело чанка на Lua; `must` приходит в него аргументом
---@return boolean ok
---@return string raised
local function as_caller(source)
    -- Чанку дано имя файла, которого нет: по нему видно, что место
    -- в сообщении — вызывающего, а не внутренностей пакета.
    local chunk = assert(loadstring('local must = ...; ' .. source, '@/узел/настройка.lua'))
    local ok, raised = pcall(chunk, must)

    return ok, tostring(raised)
end

g.test_every_check_comes_in_three_forms = function()
    for _, name in ipairs(NAMES) do
        t.assert_equals(type(must[name]), 'function', name)
        t.assert_equals(type(must.optional[name]), 'function', name)
        t.assert_equals(type(must.all[name]), 'function', name)
    end
end

g.test_a_good_argument_comes_back_as_it_was = function()
    -- Проверка и присваивание одной строкой: отдельного предложения выше
    -- она не требует.
    local opts = { tag = 'журнал' }

    t.assert_equals(must.table(opts, 'настройки'), opts)
    t.assert_equals(must.string('журнал', 'метка'), 'журнал')
    t.assert_equals(must.optional.string(nil, 'метка'), nil)
    t.assert_equals(must.all.string({ 'a', 'b' }, 'адреса'), { 'a', 'b' })
end

g.test_a_bad_argument_throws = function()
    t.assert_error_msg_equals(
        'метка журнала — строка, а не число',
        must.string,
        42,
        'метка журнала'
    )
    t.assert_error_msg_equals(
        'предел — целое число, а не 1.5',
        must.optional.integer,
        1.5,
        'предел'
    )
    t.assert_error_msg_equals(
        'адреса[2] — строка, а не число',
        must.all.string,
        { 'a', 2 },
        'адреса'
    )
end

g.test_the_message_points_at_the_caller = function()
    -- Иначе человек идёт смотреть во внутренности чужого пакета вместо
    -- своей строки, и от проверки становится хуже, чем без неё.
    local ok, raised = as_caller("must.string(42, 'метка журнала')")

    t.assert_equals(ok, false)
    t.assert_equals(
        raised,
        '/узел/настройка.lua:1: метка журнала — строка, а не число'
    )
end

g.test_a_check_built_from_others_points_at_the_caller_too = function()
    -- Здесь и ломается глубина: `optional` и `all` — это проверка, обёрнутая
    -- проверкой, и брось она сама, место в сообщении съехало бы внутрь
    -- пакета ровно на один кадр.
    local ok, raised = as_caller("must.all.string({'a', 2}, 'адреса')")

    t.assert_equals(ok, false)
    t.assert_equals(raised, '/узел/настройка.lua:1: адреса[2] — строка, а не число')

    ok, raised = as_caller("must.optional.between(42, 'вес', 1, 10)")

    t.assert_equals(ok, false)
    t.assert_equals(raised, '/узел/настройка.lua:1: вес — число от 1 до 10, а не 42')

    ok, raised = as_caller("must.array_of({1, 'a'}, 'веса', 'number')")

    t.assert_equals(ok, false)
    t.assert_equals(raised, '/узел/настройка.lua:1: веса[2] — число, а не строка')
end

--- Отказ проверки, поставленной в помощнике, которого зовёт чанк:
--- два кадра с выдуманными именами файлов, чтобы по месту в сообщении
--- было видно, на который из них легла вина.
---@param helper_body string Тело помощника; `must` и `value` — его аргументы
---@return string raised
local function as_helper(helper_body)
    local helper_chunk =
        assert(loadstring('local must, value = ...; ' .. helper_body, '@/узел/помощник.lua'))
    local caller =
        assert(loadstring('local helper = ...; local v = helper(42) return v', '@/узел/настройка.lua'))
    -- Переходник к чанку зовёт его хвостом нарочно: LuaJIT снимает такой
    -- кадр со стека, и между помощником и вызывающим не остаётся ничего
    -- своего — уровни считаются ровно так, как их увидит прикладной код.
    local ok, raised = pcall(caller, function(value)
        return helper_chunk(must, value)
    end)

    t.assert_equals(ok, false)

    return tostring(raised)
end

g.test_a_level_moves_the_blame_to_the_caller_of_the_helper = function()
    -- Помощник вокруг проверки виноват не сам: чинить надо строку, где его
    -- позвали. Уровень считается как у `error`: 2 — вызывающий.
    t.assert_equals(
        as_helper("local v = must.at(2).string(value, 'метка') return v"),
        '/узел/настройка.lua:1: метка — строка, а не число'
    )
    t.assert_equals(
        as_helper("local v = must.at(2).optional.between(value, 'вес', 1, 10) return v"),
        '/узел/настройка.lua:1: вес — число от 1 до 10, а не 42'
    )
    t.assert_equals(
        as_helper("local v = must.at(2).all.string({ value }, 'адреса') return v"),
        '/узел/настройка.lua:1: адреса[1] — строка, а не число'
    )
end

g.test_level_one_is_the_facade_itself = function()
    -- Без `at` вина на строке с проверкой — это и есть первый уровень.
    t.assert_is(must.at(1), must)
    t.assert_equals(
        as_helper("local v = must.at(1).string(value, 'метка') return v"),
        '/узел/помощник.lua:1: метка — строка, а не число'
    )
end

g.test_a_set_for_a_level_is_built_once = function()
    -- Помощник зовёт `must.at(2)` на каждом вызове, и собирать полсотни
    -- замыканий каждый раз было бы платой за место в сообщении.
    t.assert_is(must.at(2), must.at(2))
    t.assert_is_not(must.at(2), must.at(3))

    for _, name in ipairs(NAMES) do
        t.assert_equals(type(must.at(2)[name]), 'function', name)
        t.assert_equals(type(must.at(2).optional[name]), 'function', name)
        t.assert_equals(type(must.at(2).all[name]), 'function', name)
    end
end

g.test_a_bad_level_is_refused_at_the_line_with_at = function()
    -- Неправильный уровень — ошибка в строке с `must.at`, и показывать отказ
    -- обязан на неё, а не внутрь пакета: `at` сам себе тот помощник,
    -- ради которого уровень заведён.
    local cases = {
        { source = 'must.at(0)', raised = 'уровень вины — число больше 0, а не 0' },
        { source = 'must.at(1.5)', raised = 'уровень вины — целое число, а не 1.5' },
        { source = "must.at('2')", raised = 'уровень вины — целое число, а не строка' },
        { source = 'must.at()', raised = 'уровень вины — целое число, а не nil' },
    }

    for _, case in ipairs(cases) do
        local ok, raised = as_caller(case.source)

        t.assert_equals(ok, false, case.source)
        t.assert_equals(raised, '/узел/настройка.lua:1: ' .. case.raised, case.source)
    end
end

g.test_a_tail_call_drops_the_frame_and_moves_the_blame = function()
    -- Проверено на 3.8: LuaJIT снимает кадр хвостового вызова со стека
    -- целиком, и `return must.x(...)` показывает на вызывающего той
    -- функции, где стоит проверка. Уровень тут бессилен — кадра нет;
    -- лечит только форма записи: переменная либо скобки.
    t.assert_equals(
        as_helper("return must.string(value, 'метка')"),
        '/узел/настройка.lua:1: метка — строка, а не число'
    )
    t.assert_equals(
        as_helper("return (must.string(value, 'метка'))"),
        '/узел/помощник.lua:1: метка — строка, а не число'
    )
end

g.test_an_absent_optional_argument_passes_every_check = function()
    for _, name in ipairs(NAMES) do
        t.assert_equals(must.optional[name](nil, 'аргумент'), nil, name)
    end
end

g.test_a_homogeneous_list_takes_the_kind_by_name = function()
    t.assert_equals(must.array_of({ 1, 2 }, 'веса', 'number'), { 1, 2 })
    t.assert_error_msg_equals(
        'веса[2] — число больше 0, а не -1',
        must.array_of,
        { 1, -1 },
        'веса',
        'positive'
    )
end

g.test_a_list_of_lists_is_all_of_a_kind_of_list = function()
    t.assert_equals(must.all.array_of({ { 'a' }, { 'b' } }, 'группы', 'string'), { { 'a' }, { 'b' } })
    t.assert_error_msg_equals(
        'группы[2][1] — строка, а не число',
        must.all.array_of,
        { { 'a' }, { 2 } },
        'группы',
        'string'
    )
end

g.test_a_misspelled_kind_is_answered_with_the_whole_list = function()
    -- Список — весь реестр в порядке объявления, вместе с проверками
    -- по имени: `options` вправе описать ключ как `{ 'array_of', 'string' }`.
    t.assert_error_msg_equals(
        ('веса: проверки «strng» нет, есть %s'):format(table.concat(NAMES, ', ')),
        must.array_of,
        { 1 },
        'веса',
        'strng'
    )
end

g.test_a_union_of_kinds_is_written_with_a_bar = function()
    t.assert_equals(must.kind(42, 'вес', 'number|string'), 42)
    t.assert_equals(must.kind('42', 'вес', 'number|string'), '42')
    t.assert_equals(must.array_of({ 1, 'a' }, 'веса', 'number|string'), { 1, 'a' })
    t.assert_error_msg_equals(
        'вес — число или строка, а не true',
        must.kind,
        true,
        'вес',
        'number|string'
    )
    t.assert_error_msg_equals(
        'счётчик — целое uint64 или decimal, а не 1.5',
        must.kind,
        1.5,
        'счётчик',
        'uint64|decimal'
    )
end

g.test_every_kind_joins_a_union_and_nothing_else_does = function()
    local kinds = table.concat(KINDS, ', ')

    for _, name in ipairs(KINDS) do
        t.assert_equals(must.optional.kind(nil, 'аргумент', name .. '|string'), nil, name)
    end

    for _, name in ipairs(NAMES) do
        local kind_of_it = false

        for _, kind in ipairs(KINDS) do
            kind_of_it = kind_of_it or kind == name
        end

        if not kind_of_it then
            t.assert_error_msg_equals(
                ('аргумент: в объединении «string|%s» «%s» — не тип, типы: %s'):format(
                    name,
                    name,
                    kinds
                ),
                must.kind,
                nil,
                'аргумент',
                'string|' .. name
            )
        end
    end
end

g.test_a_counter_from_box_passes_as_an_unsigned_integer = function()
    -- Ради этого типы cdata и заведены: `integer` такой счётчик отвергает.
    local counter = require('ffi').cast('uint64_t', 5)

    t.assert_equals(must.uint64(counter, 'счётчик'), counter)
    t.assert_equals(must.uint64(5, 'счётчик'), 5)
    t.assert_error_msg_equals(
        'счётчик — целое число, а не cdata',
        must.integer,
        counter,
        'счётчик'
    )
    t.assert_error_msg_equals('счётчик — целое uint64, а не -1LL', must.uint64, -1LL, 'счётчик')
end

g.test_an_object_is_recognized_by_the_type_of_its_metatable = function()
    local connection = setmetatable({}, { __type = 'Connection' })

    t.assert_equals(must.instance_of(connection, 'соединение', 'Connection'), connection)
    t.assert_error_msg_equals(
        'соединение — Connection, а не таблица',
        must.instance_of,
        {},
        'соединение',
        'Connection'
    )
end

--- Описание настроек журнала, как его написал бы вызывающий.
local LOG_SPEC = {
    tag = 'not_empty',
    limit = '?integer',
    level = { 'one_of', { 'debug', 'info', 'error' } },
    hosts = { 'array_of', 'string' },
    tls = { '?options', { cert = 'string', key = 'string' } },
}

g.test_options_are_checked_by_a_description = function()
    local opts = { tag = 'журнал', level = 'info', hosts = { 'a' } }

    t.assert_equals(must.options(opts, 'настройки', LOG_SPEC), opts)
    t.assert_error_msg_equals(
        'настройки: ключа «limt» нет, есть hosts, level, limit, tag, tls',
        must.options,
        { tag = 'журнал', level = 'info', hosts = {}, limt = 5 },
        'настройки',
        LOG_SPEC
    )
    t.assert_error_msg_equals(
        'настройки.limit — целое число, а не строка',
        must.options,
        { tag = 'журнал', level = 'info', hosts = {}, limit = '5' },
        'настройки',
        LOG_SPEC
    )
    t.assert_error_msg_equals(
        'настройки.level — одно из «debug», «info», «error», а не «warn»',
        must.options,
        { tag = 'журнал', level = 'warn', hosts = {} },
        'настройки',
        LOG_SPEC
    )
    t.assert_error_msg_equals(
        'настройки.hosts[2] — строка, а не число',
        must.options,
        { tag = 'журнал', level = 'info', hosts = { 'a', 2 } },
        'настройки',
        LOG_SPEC
    )
end

g.test_nested_options_are_described_in_place = function()
    -- Реестр читается при вызове, и `options` видит себя.
    t.assert_error_msg_equals(
        'настройки.tls.key — строка, а не nil',
        must.options,
        { tag = 'журнал', level = 'info', hosts = {}, tls = { cert = 'a' } },
        'настройки',
        LOG_SPEC
    )
    t.assert_error_msg_equals(
        'настройки.tls: ключа «ca» нет, есть cert, key',
        must.options,
        { tag = 'журнал', level = 'info', hosts = {}, tls = { cert = 'a', key = 'b', ca = 'c' } },
        'настройки',
        LOG_SPEC
    )
end

g.test_options_point_at_the_caller_like_every_other_check = function()
    local ok, raised = as_caller("must.options({ tag = 42 }, 'настройки', { tag = 'string' })")

    t.assert_equals(ok, false)
    t.assert_equals(
        raised,
        '/узел/настройка.lua:1: настройки.tag — строка, а не число'
    )

    ok, raised = as_caller("must.kind(true, 'вес', 'number|string')")

    t.assert_equals(ok, false)
    t.assert_equals(
        raised,
        '/узел/настройка.lua:1: вес — число или строка, а не true'
    )
end

g.test_explain_gives_the_text_of_a_refusal_instead_of_throwing = function()
    -- Пакет, который бросает сам и без места, берёт отсюда текст: место
    -- ему не нужно, а бросок фасада приписал бы его.
    local fields = { name = 'string', build = '?' }

    t.assert_equals(must.explain.options({ name = 'app' }, 'приложение', fields), nil)
    t.assert_equals(
        must.explain.options({ name = 'app', buid = 1 }, 'приложение', fields),
        'приложение: ключа «buid» нет, есть build, name'
    )
    t.assert_equals(
        must.explain.options({ name = 42 }, 'приложение', fields),
        'приложение.name — строка, а не число'
    )
    t.assert_equals(must.explain.kind(5, 'вес', 'between', 1, 10), nil)
    t.assert_equals(
        must.explain.kind(42, 'вес', 'between', 1, 10),
        'вес — число от 1 до 10, а не 42'
    )
    t.assert_equals(
        must.explain.array_of({ 'a', 2 }, 'адреса', 'string'),
        'адреса[2] — строка, а не число'
    )
end

g.test_explain_holds_the_same_named_checks_the_facade_throws_from = function()
    -- Текст один и тот же: брошенный фасадом отказ — это текст `explain`
    -- с местом вызывающего впереди.
    local ok, raised = as_caller("must.options({ limt = 5 }, 'настройки', { limit = '?integer' })")

    t.assert_equals(ok, false)
    t.assert_equals(
        raised,
        '/узел/настройка.lua:1: '
            .. must.explain.options({ limt = 5 }, 'настройки', { limit = '?integer' })
    )
end

g.test_box_null_is_absent_for_optional_and_named_for_the_rest = function()
    -- `box.NULL` равен `nil`, и `optional` его пропускает, как `nil`;
    -- обязательному аргументу он не годится и назван по имени.
    t.assert_equals(must.optional.uuid(box.NULL, 'идентификатор'), box.NULL)
    t.assert_error_msg_equals(
        'идентификатор — строка, а не box.NULL',
        must.string,
        box.NULL,
        'идентификатор'
    )
end

g.test_the_checks_read_as_the_calling_code_would_write_them = function()
    -- Тот самый набор, ради которого пакет и написан: проверка настроек
    -- в начале функции, целиком и подряд.
    local function configure(opts)
        must.table(opts, 'настройки')
        must.not_empty(opts.tag, 'метка журнала')
        must.optional.integer(opts.limit, 'предел записей')
        must.one_of(opts.level, 'уровень', { 'debug', 'info', 'error' })
        must.all.string(opts.hosts, 'адреса')

        return opts
    end

    t.assert_equals(configure({ tag = 'журнал', level = 'info', hosts = { 'a' } }).tag, 'журнал')
    t.assert_error_msg_contains(
        'настройки — таблица, а не строка',
        configure,
        'журнал'
    )
    t.assert_error_msg_contains(
        'метка журнала — непустая строка, а не nil',
        configure,
        {}
    )
end
