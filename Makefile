# Проверки пакета: форматирование, линт, тесты, покрытие, мутанты.

LUATEST  := .rocks/bin/luatest
LUACHECK := .rocks/bin/luacheck
COVERAGE_MIN ?= 100

.PHONY: help
help: ## Список целей
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN { FS = ":.*?## " } { printf "  %-12s %s\n", $$1, $$2 }'

.PHONY: deps
deps: ## Поставить инструменты проверок в .rocks
	tt rocks install --server=https://luarocks.org luatest
	tt rocks install --server=https://luarocks.org luacheck 1.2.0
	tt rocks install --server=https://luarocks.org luacov 0.17.0

.PHONY: fmt
fmt: ## Отформатировать код
	stylua .

.PHONY: fmt-check
fmt-check: ## Проверить форматирование, ничего не меняя
	stylua --check .

.PHONY: lint
lint: ## Линт
	$(LUACHECK) . --formatter plain --codes

.PHONY: test
test: ## Прогон проверок
	$(LUATEST) test/

.PHONY: coverage
coverage: ## Проверки с покрытием и порогом
	mkdir -p var && rm -f var/luacov.stats.out
	$(LUATEST) test/ --coverage
	tarantool tools/coverage_gate.lua $(COVERAGE_MIN)

# Мутационное тестирование — утилитой tnt-mutants (github.com/tnt-skein/tnt-mutants).
.PHONY: mutants
mutants: ## Мутационное тестирование изменённых модулей
	tnt-mutants

.PHONY: mutants-all
mutants-all: ## Мутационное тестирование всех модулей
	tnt-mutants $(shell find tnt -name '*.lua' | sort)

.PHONY: check
check: fmt-check lint test coverage ## Все проверки, кроме мутантов

.PHONY: clean
clean: ## Убрать рабочие каталоги
	rm -rf var
