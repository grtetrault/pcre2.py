SHELL = /bin/bash

init:
	# Create venv, pull dependencies
	python3 -m venv .venv
	./.venv/bin/pip3 install -r ./requirements/build-requirements.txt
	./.venv/bin/pip3 install -r ./requirements/test-requirements.txt
	./.venv/bin/python3 ./tools/download_libpcre2_release.py


build:
	./.venv/bin/python3 setup.py bdist_wheel


install:
	./.venv/bin/pip3 install dist/pcre2*.whl --force-reinstall

clean:
	rm -rf build
	rm -rf dist
	find ./src/pcre2 -type f -name '*.c' -print0 | xargs -0 rm -vf
	find ./src/pcre2 -type f -name '*.html' -print0 | xargs -0 rm -vf
	find . -type d -name '*.egg-info' | xargs rm -r
	find . -type f -name '*.pyc' | xargs rm -r
	find . -type d -name '*.ipynb_checkpoints' | xargs rm -r

purge:
	rm -rf .venv

benchmark:
	./.venv/bin/python3 ./benchmark/run_regex_redux.py
