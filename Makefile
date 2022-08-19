SHELL = /bin/bash

build:
	python3 setup.py build_ext --force
	python3 setup.py build
	python3 setup.py bdist_wheel

install:
	echo $(PCRE2_PYTHON_PACKAGE_VERSION)
	pip3 install dist/pcre2-0.0.1-cp310-cp310-macosx_12_0_arm64.whl --force-reinstall

clean:
	rm -rf build
	rm -rf dist
	find ./pcre2 -type f -name '*.c' -print0 | xargs -0 rm -vf
	find ./pcre2 -type f -name '*.html' -print0 | xargs -0 rm -vf

clean-build-install:
	$(MAKE) clean
	$(MAKE) build
	$(MAKE) install
