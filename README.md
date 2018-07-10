[![Version](https://img.shields.io/badge/version-18.07.0-yellow.svg)](https://github.com/KmolYuan/pyslvs/releases/latest)
[![Build Status](https://travis-ci.org/KmolYuan/pyslvs.svg)](https://travis-ci.org/KmolYuan/pyslvs)

# Pyslvs Libraries

A no-GUI module of mechanism synthesis system and a 2D geometric constraint solver.

## Build and Test

Enter directory and execute the Makefile. Then, run the unit test script after compiling.

```bash
cd pyslvs
make
python test_pyslvs.py
```

## Module parts

Pyslvs libraries is divided into two following sections:

+ Solver:
    Geometric solver and verification functions.

+ Synthesis:
    Mechanism synthesis system that including several random algorithm and enumeration algorithm, dependent with geometric solver.

Most of classes and functions can be work with a generic Python format (just like a list of coordinates or string-like expression), and you also can cut in at any step.

### Solver

In Pyslvs, expression is mainly to [PMKS](http://designengrlab.github.io/PMKS/), which is more 

+ **parser** module:
    Analysis expression from strings, turn into symbols object. There also including highlighting function with [Pygments](http://pygments.org/).

+ **tinycadlib** library:
    Particular solution takes more faster then constraint solving. There also including expression object classes.

+ **triangulation** library:
    Autometic configuration algorithm for particular solution function in "tinycadlib".

+ **bfgs** library:
    Python wrapper of [Sketchsolve](https://code.google.com/archive/p/sketchsolve/). A simple and fast constraint solver with BFGS algorithm.

### Synthesis

+ **number** library:
    Number synthesis function for searching solutions of the number of joints and links.

+ **topologic** library:
    Graph combination algorithm.

+ **planarlinkage** library:
    Dimensional synthesis verification function objects.

#### Adesign

[Adesign](https://github.com/KmolYuan/Adesign) module: Cython algorithms libraries provide evolution designing.

+ **rga** library:
    Real-coded genetic algorithm for dimensional synthesis.

+ **firefly** library:
    Firefly algorithm for dimensional synthesis.

+ **de** library:
    Differential Evolution for dimensional synthesis.
