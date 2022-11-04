SHELL = /bin/bash

venv:
	python3 -m venv ./.venv

init:
	pip3 install -r ./requirements/build-requirements.txt
	pip3 install -r ./requirements/test-requirements.txt
	python3 ./tools/download_libpcre2_release.py

build_lib:
	python3 tools/build_libpcre2.py

build_wheel:
	python3 ./setup.py bdist_wheel

build_sdist:
	python3 ./setup.py sdist

install_wheel:
	pip3 install ./dist/pcre2-*.whl --force-reinstall

install_sdist:
	pip3 install ./dist/pcre2-*.tar.gz --force-reinstall

clean:
	rm -rf ./build
	rm -rf ./dist
	find ./src/pcre2 -type f -name '*.c' -print0 | xargs -0 rm -vf
	find ./src/pcre2 -type f -name '*.html' -print0 | xargs -0 rm -vf
	find . -type d -name '*.egg-info' | xargs rm -r
	find . -type f -name '*.pyc' | xargs rm -r
	find . -type d -name '*.ipynb_checkpoints' | xargs rm -r

purge:
	rm -rf ./.venv

benchmark:
	python3 ./benchmarks/run_regex_redux.py
