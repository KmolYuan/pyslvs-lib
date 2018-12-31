# -*- coding: utf-8 -*-
# cython: language_level=3

"""Sharing position analysis function.

author: Yuan Chang
copyright: Copyright (C) 2016-2018
license: AGPL
email: pyslvs@gmail.com
"""


cdef class Coordinate:
    cdef readonly double x, y

    cpdef double distance(self, Coordinate p)
    cpdef bint is_nan(self)


cdef double radians(double degree) nogil
cpdef tuple plap(Coordinate c1, double d0, double a0, Coordinate c2 = *, bint inverse = *)
cpdef tuple pllp(Coordinate c1, double d0, double d1, Coordinate c2, bint inverse = *)
cpdef tuple plpp(Coordinate c1, double d0, Coordinate c2, Coordinate c3, bint inverse = *)
cpdef tuple pxy(Coordinate c1, double x, double y)

cdef bint legal_crank(Coordinate c1, Coordinate c2, Coordinate c3, Coordinate c4)
cdef str str_between(str s, str front, str back)
cdef str str_before(str s, str front)
