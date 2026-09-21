--- Тесты типов Tarantool: что признаётся правильным и что сказано о неправильном.

local t = require('luatest')

local datetime = require('datetime')
local decimal = require('decimal')
local ffi = require('ffi')
local uuid = require('uuid')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.must.cdata')

---@return any
local function cdata()
    return helper.part('tnt.must.cdata')
end

--- Ошибка box, как её делает ядро.
---@return any
local function failure()
    -- Через ссылку без типа: конструктор в аннотациях ядра описан
    -- не полностью, и прямой вызов анализатор считает сомнительным.
    ---@type any
    local box_error = box.error

    return box_error.new({ type = 'ClientError', code = 0, reason = 'нет связи' })
end

--- Первое целое, которое double уже не отличает от соседнего.
local EXACT = 2 ^ 53

g.test_a_counter_from_box_is_an_unsigned_integer_whatever_it_came_as = function()
    -- Счётчик приходит числом, пока умещается в 2^53, и cdata — когда
    -- перестаёт; один столбец спейса даёт то и другое.
    t.assert_equals(cdata().uint64(0, 'счётчик'), nil)
    t.assert_equals(cdata().uint64(EXACT - 1, 'счётчик'), nil)
    t.assert_equals(cdata().uint64(ffi.cast('uint64_t', 5), 'счётчик'), nil)
    t.assert_equals(cdata().uint64(18446744073709551615ULL, 'счётчик'), nil)
    t.assert_equals(cdata().uint64(0LL, 'счётчик'), nil)
    t.assert_equals(cdata().uint64(9223372036854775807LL, 'счётчик'), nil)
end

g.test_a_negative_or_fractional_value_is_not_unsigned = function()
    t.assert_equals(cdata().uint64(-1, 'счётчик'), 'счётчик — целое uint64, а не -1')
    t.assert_equals(cdata().uint64(1.5, 'счётчик'), 'счётчик — целое uint64, а не 1.5')
    t.assert_equals(cdata().uint64(-1LL, 'счётчик'), 'счётчик — целое uint64, а не -1LL')
    t.assert_equals(cdata().uint64('5', 'счётчик'), 'счётчик — целое uint64, а не строка')
    t.assert_equals(cdata().uint64(nil, 'счётчик'), 'счётчик — целое uint64, а не nil')
end

g.test_a_number_past_the_exact_range_is_refused = function()
    -- Дальше 2^53 double не хранит целые подряд: число, прошедшее проверку,
    -- могло бы оказаться не тем, которое записали.
    t.assert_equals(
        cdata().uint64(EXACT, 'счётчик'),
        'счётчик — целое uint64, а не 9.007199254741e+15'
    )
    t.assert_equals(cdata().int64(EXACT, 'сдвиг'), 'сдвиг — целое int64, а не 9.007199254741e+15')
    t.assert_equals(cdata().int64(-EXACT, 'сдвиг'), 'сдвиг — целое int64, а не -9.007199254741e+15')
end

g.test_nan_and_infinity_are_not_integers_of_any_width = function()
    t.assert_equals(cdata().uint64(0 / 0, 'счётчик'), 'счётчик — целое uint64, а не NaN')
    t.assert_equals(cdata().uint64(math.huge, 'счётчик'), 'счётчик — целое uint64, а не inf')
    t.assert_equals(cdata().int64(0 / 0, 'сдвиг'), 'сдвиг — целое int64, а не NaN')
    t.assert_equals(cdata().int64(-math.huge, 'сдвиг'), 'сдвиг — целое int64, а не -inf')
end

g.test_a_signed_integer_takes_both_signs_and_an_unsigned_that_fits = function()
    t.assert_equals(cdata().int64(-EXACT + 1, 'сдвиг'), nil)
    t.assert_equals(cdata().int64(EXACT - 1, 'сдвиг'), nil)
    t.assert_equals(cdata().int64(-1LL, 'сдвиг'), nil)
    t.assert_equals(cdata().int64(9223372036854775807ULL, 'сдвиг'), nil)
end

g.test_an_unsigned_past_the_signed_limit_is_refused = function()
    -- Старший бит у такого значения — знак, и как int64 оно отрицательное.
    t.assert_equals(
        cdata().int64(9223372036854775808ULL, 'сдвиг'),
        'сдвиг — целое int64, а не 9223372036854775808ULL'
    )
    t.assert_equals(cdata().int64(1.5, 'сдвиг'), 'сдвиг — целое int64, а не 1.5')
    t.assert_equals(cdata().int64({}, 'сдвиг'), 'сдвиг — целое int64, а не таблица')
end

g.test_each_kind_of_tarantool_is_recognized_by_the_core = function()
    t.assert_equals(cdata().decimal(decimal.new('1.5'), 'сумма'), nil)
    t.assert_equals(cdata().uuid(uuid.new(), 'идентификатор'), nil)
    t.assert_equals(cdata().tuple(box.tuple.new({ 1 }), 'запись'), nil)
    t.assert_equals(cdata().datetime(datetime.now(), 'отметка'), nil)
    t.assert_equals(cdata().interval(datetime.interval.new({ sec = 1 }), 'срок'), nil)
    t.assert_equals(cdata().error(failure(), 'причина'), nil)
end

g.test_a_lua_value_of_the_same_meaning_is_not_the_kind = function()
    -- Запись uuid строкой, число вместо decimal, таблица вместо кортежа:
    -- всё это надо приводить явно, и проверка говорит, что не привели.
    t.assert_equals(cdata().decimal(1.5, 'сумма'), 'сумма — decimal, а не число')
    t.assert_equals(
        cdata().uuid(uuid.str(), 'идентификатор'),
        'идентификатор — UUID, а не строка'
    )
    t.assert_equals(cdata().tuple({ 1 }, 'запись'), 'запись — кортеж, а не таблица')
    t.assert_equals(cdata().datetime(0, 'отметка'), 'отметка — datetime, а не число')
    t.assert_equals(cdata().interval(1, 'срок'), 'срок — интервал datetime, а не число')
    t.assert_equals(
        cdata().error('нет связи', 'причина'),
        'причина — ошибка box.error, а не строка'
    )
end

g.test_a_cdata_of_another_kind_is_shown_by_its_value = function()
    -- «а не cdata» не сказало бы, что перепутали; «а не 1.5» говорит.
    t.assert_equals(
        cdata().uuid(decimal.new('1.5'), 'идентификатор'),
        'идентификатор — UUID, а не 1.5'
    )
    t.assert_equals(cdata().decimal(5ULL, 'сумма'), 'сумма — decimal, а не 5ULL')
    t.assert_equals(
        cdata().datetime(datetime.interval.new({ sec = 1 }), 'отметка'),
        'отметка — datetime, а не +1 seconds'
    )
end

g.test_box_null_is_no_kind_at_all = function()
    -- Так приходит `null` из JSON, и назван он по имени.
    t.assert_equals(
        cdata().uuid(box.NULL, 'идентификатор'),
        'идентификатор — UUID, а не box.NULL'
    )
    t.assert_equals(
        cdata().uint64(box.NULL, 'счётчик'),
        'счётчик — целое uint64, а не box.NULL'
    )
end

g.test_every_kind_has_a_label_that_its_message_uses = function()
    -- Подпись объявлена один раз: из неё складывается и отказ самой
    -- проверки, и ожидание объединения типов.
    for name, label in pairs(cdata().LABEL) do
        t.assert_equals(type(cdata()[name]), 'function', name)
        t.assert_equals(
            cdata()[name](true, name),
            ('%s — %s, а не логическое значение'):format(name, label)
        )
    end
end
