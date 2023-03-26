SHELL = /bin/bash

init:
	git submodule update --init
	python3 -m venv ./.venv
	./.venv/bin/pip install -r ./requirements/build-requirements.txt
	./.venv/bin/pip install -r ./requirements/test-requirements.txt
	./.venv/bin/pip install .

build:
	./.venv/bin/pip install . --force-reinstall

clean:
	rm -rf ./dist
	rm -rf ./build
	rm -rf ./_skbuild
	find ./src/pcre2 -type f -name '*.c' -print0 | xargs -0 rm -vf
	find ./src/pcre2 -type f -name '*.html' -print0 | xargs -0 rm -vf
	find . -type f -name '*.pyc' | xargs rm -r
	find . -type d -name '*.egg-info' | xargs rm -r
	find . -type d -name '*.ipynb_checkpoints' | xargs rm -r

purge:
	rm -rf ./.venv

benchmark:
	./.venv/bin/python ./benchmarks/run_regex_redux.py
