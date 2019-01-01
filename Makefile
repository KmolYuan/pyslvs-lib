# Pyslvs Makefile

# author: Yuan Chang
# copyright: Copyright (C) 2016-2019
# license: AGPL
# email: pyslvs@gmail.com

ifeq ($(OS),Windows_NT)
    SHELL = cmd
endif

all: build

# Submodule files
ADESIGN_PXD = $(notdir $(wildcard Adesign/src/*.pxd))

.PHONY: build

# Into package folder
build: src/*.pyx src/*.pxd Adesign/src/*.pyx Adesign/src/*.pxd src/bfgs_solver/*.cpp
ifeq ($(OS),Windows_NT)
	copy Adesign\src\*.pxd src
	-rename __init__.py .__init__.py
	python setup.py build_ext --inplace
	-rename .__init__.py __init__.py
	del $(addprefix src\,$(ADESIGN_PXD))
else
	cp -p Adesign/src/*.pxd src
	-mv __init__.py .__init__.py
	python3 setup.py build_ext --inplace
	-mv .__init__.py __init__.py
	rm $(addprefix src/,$(ADESIGN_PXD))
endif

test: build
ifeq ($(OS),Windows_NT)
	python test.py
else
	python3 test.py
endif

clean:
ifeq ($(OS),Windows_NT)
	-rename .__init__.py __init__.py
	-del *.pyd /q
	-rd build /s /q
	-del src\*.c /q
	-del src\*.cpp /q
else
	-mv .__init__.py __init__.py
	-rm -f *.so
	-rm -fr build
	-rm -f src/*.c
	-rm -f src/*.cpp
endif
