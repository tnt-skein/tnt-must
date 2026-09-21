rockspec_format = '3.0'

package = 'tnt-must'
version = 'scm-1'

source = {
    url = 'git+https://github.com/tnt-skein/tnt-must.git',
    branch = 'main',
}

description = {
    summary = 'Проверки аргументов: неправильный аргумент роняет вызов на месте',
    detailed = [[
        Проверки аргументов функций для Tarantool. Неправильный аргумент — ошибка
        программиста, поэтому проверка бросает, а не возвращает отказ:
        тому, кто передал число вместо строки, вернуть его некому.

        Отказ называет аргумент по имени и показывает само значение:
        «предел записей — целое число, а не 1.5». Место в сообщении —
        строка вызывающего, а не внутренности пакета; помощник вокруг
        проверки переводит вину на своего вызывающего через must.at(2).

        Проверки: тип значения, в том числе типы Tarantool (uint64, int64,
        decimal, uuid, кортеж, datetime, interval, box.error), числовые
        границы, строки, перечисления, однородные списки, таблица настроек
        по описанию с отказом на незнакомый ключ. Необязательный аргумент —
        optional.*, каждый элемент списка — all.*, объединение типов —
        'number|string'. Для отказов без места — fail.raise и must.explain.

        Зависимостей нет: только то, что встроено в Tarantool. Покрытие
        строк и убитых мутантов — 100 %.
    ]],
    homepage = 'https://github.com/tnt-skein/tnt-must',
    issues_url = 'https://github.com/tnt-skein/tnt-must/issues',
    maintainer = 'tnt-skein',
    license = 'MIT',
    labels = { 'tarantool', 'arguments', 'validation', 'assert', 'contracts' },
}

dependencies = {
    'lua >= 5.1',
}

build = {
    type = 'builtin',
    modules = {
        ['tnt.must'] = 'tnt/must.lua',
        ['tnt.must.fail'] = 'tnt/must/fail.lua',
        ['tnt.must.types'] = 'tnt/must/types.lua',
        ['tnt.must.range'] = 'tnt/must/range.lua',
        ['tnt.must.text'] = 'tnt/must/text.lua',
        ['tnt.must.choice'] = 'tnt/must/choice.lua',
        ['tnt.must.cdata'] = 'tnt/must/cdata.lua',
        ['tnt.must.spec'] = 'tnt/must/spec.lua',
    },
}
