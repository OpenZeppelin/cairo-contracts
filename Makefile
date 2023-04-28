.SILENT:
.PHONY: compile
SOURCE_FOLDER=./src/openzeppelin

install:
	git submodule init && git submodule update && cp -rf cairo/corelib .

update:
	git submodule update && cp -rf cairo/corelib .

build:
	cargo build

test:
	cargo run --bin cairo-test -- --starknet $(SOURCE_FOLDER)

format:
	cargo run --bin cairo-format -- --recursive $(SOURCE_FOLDER) --print-parsing-errors

check-format:
	cargo run --bin cairo-format -- --check --recursive $(SOURCE_FOLDER)

starknet-compile:
	mkdir -p artifacts && \
		cargo run --bin starknet-compile -- ${dir} artifacts/$(shell basename $(dir)).json --allowed-libfuncs-list-name experimental_v0.1.0

language-server:
	cargo build --bin cairo-language-server --release
