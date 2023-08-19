.SILENT:
.PHONY: compile
SOURCE_FOLDER=./src

test:
	cairo-test --starknet $(SOURCE_FOLDER)

format:
	cairo-format --recursive $(SOURCE_FOLDER) --print-parsing-errors

check-format:
	cairo-test --check --recursive $(SOURCE_FOLDER)

build:
	scarb build
