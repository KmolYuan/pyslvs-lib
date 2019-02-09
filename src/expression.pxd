# -*- coding: utf-8 -*-
# cython: language_level=3

"""PMKS symbolics.

author: Yuan Chang
copyright: Copyright (C) 2016-2019
license: AGPL
email: pyslvs@gmail.com
"""

from numpy cimport ndarray


cpdef enum VJoint:
    # Joint types.
    # Actually "class VJoint(IntEnum)" in Python but "enum" in C++.
    R  # Rotate pair
    P  # Prismatic pair
    RP  # Rotate and prismatic pair


cdef class VPoint:

    # VPoint(links, type_int, angle, color_str, x, y, color_func=None)

    # Members
    cdef readonly tuple links
    cdef readonly ndarray c
    cdef readonly VJoint type
    cdef readonly tuple color
    cdef readonly str color_str
    cdef readonly str type_str
    cdef readonly double x, y, angle
    cdef double __offset
    cdef bint __has_offset

    @staticmethod
    cdef VPoint c_r_joint(object links, double x, double y)
    @staticmethod
    cdef VPoint c_slider_joint(object links, VJoint type_int, double angle, double x, double y)

    # Copy method
    cpdef VPoint copy(self)

    # Set values
    cpdef void move(self, tuple c1, tuple c2 = *) except *
    cpdef void rotate(self, double)
    cpdef void set_offset(self, double)
    cpdef void disable_offset(self)

    # Get or calculate values
    cpdef double distance(self, VPoint p)
    cpdef bint has_offset(self)
    cpdef double offset(self)
    cpdef double true_offset(self)
    cpdef double slope_angle(self, VPoint p, int num1 = *, int num2 = *)

    # Link operators.
    cpdef bint grounded(self)
    cpdef bint pin_grounded(self)
    cpdef bint same_link(self, VPoint p)
    cpdef bint no_link(self)
    cpdef bint is_slot_link(self, str link_name)