# -*- coding: utf-8 -*-
# cython: language_level=3, embedsignature=True, cdivision=True

"""Wrapper of BFGS algorithm.

Note of Pointer:
+ In Cython, pointer is more convenient then array.
    Because we can not "new" them or using "const" decorator on size_t.
+ There is NO pointer's "get value" operator in Cython,
    please use "index" operator.
+ Pointers can be plus with C's Integer, but not Python's.
    So please copy or declare to C's Integer.

author: Yuan Chang
copyright: Copyright (C) 2016-2019
license: AGPL
email: pyslvs@gmail.com
"""

from typing import Sequence, Set
cimport cython
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.math cimport M_PI, cos, sin
from libcpp.pair cimport pair
from .sketch_solve cimport (
    Rough,
    Success,
    PointOnPointConstraint,
    P2PDistanceConstraint,
    InternalAngleConstraint,
    PointOnLineConstraint,
    LineInternalAngleConstraint,
    solve,
)
from .expression cimport (
    get_vlinks,
    VJoint,
    VPoint,
    VLink,
    Coordinate,
)


cdef inline double *de_refer_post_inc(clist[double].iterator &it):
    """Implement &(*it) in C++."""
    return &cython.operator.dereference(cython.operator.postincrement(it))


cdef inline void _sort_pairs(dict data_dict):
    """Sort the pairs in data_dict."""
    cdef object k
    for k in data_dict:
        if isinstance(k, (Sequence, Set)) and len(k) == 2:
            data_dict[frozenset(k)] = data_dict.pop(k)


cdef inline double _radians(double degree):
    """Degrees to radians."""
    return degree / 180 * M_PI


cdef class SolverSystem:

    """Sketch Solve solver."""

    def __cinit__(self, object vpoints_, dict inputs = None, dict data_dict = None):
        """Solving function from vpoint list.

        + vpoints: Sequence[VPoint]
        + inputs: {(b0, d0): a0, (b1, d1): a1, ...}

        Known coordinates import from data_dict.
        + data_dict: {0: Coordinate(10.0, 20.0), ..., (0, 2): 30.0, ...}
        """
        self.vpoints = list(vpoints_)
        self.vlinks = {vlink.name: vlink for vlink in get_vlinks(self.vpoints)}
        self.inputs = inputs
        self.data_dict = data_dict
        if self.inputs is None:
            self.inputs = {}
        if self.data_dict is None:
            self.data_dict = {}

        _sort_pairs(self.data_dict)
        self.build_expression()

    cpdef bint same_points(self, object vpoints_):
        """Return True if two expressions are same."""
        cdef int i
        cdef VPoint p1, p2
        for i, p1 in enumerate(vpoints_):
            p2 = self.vpoints[i]
            if p1.links != p2.links:
                return False
        return True

    cpdef frozenset show_inputs(self):
        """Show the current inputs keys."""
        return frozenset(self.inputs)

    cpdef frozenset show_data(self):
        """Show the current data keys."""
        return frozenset(self.data_dict)

    cdef void build_expression(self):
        """Build the expression for solver at first time."""
        # Point parameters
        cdef int i
        cdef double x, y
        cdef double *tmp_ptr
        cdef VPoint vpoint
        cdef Coordinate coord
        for i, vpoint in enumerate(self.vpoints):
            if vpoint.no_link():
                x, y = vpoint.c[0]
                self.constants.push_back(x)
                tmp_ptr = &self.constants.back()
                self.constants.push_back(y)
                self.points.push_back([tmp_ptr, &self.constants.back()])
                continue

            if vpoint.grounded():
                if i in self.data_dict:
                    # Known coordinates
                    coord = self.data_dict[i]
                    self.data_values.push_back(coord.x)
                    tmp_ptr = &self.data_values.back()
                    self.data_values.push_back(coord.y)
                    self.points.push_back([tmp_ptr, &self.data_values.back()])
                    continue

                x, y = vpoint.c[0]
                self.constants.push_back(x)
                tmp_ptr = &self.constants.back()
                self.constants.push_back(y)
                if vpoint.type in {VJoint.P, VJoint.RP}:
                    self.sliders[i] = <int>self.slider_bases.size()
                    # Base point (slot) is fixed
                    self.slider_bases.push_back([tmp_ptr, &self.constants.back()])
                    # Slot point (slot) is movable
                    self.params.push_back(x + cos(vpoint.angle))
                    tmp_ptr = &self.params.back()
                    self.params.push_back(y + sin(vpoint.angle))
                    self.slider_slots.push_back([tmp_ptr, &self.params.back()])
                    # Pin is movable
                    x, y = vpoint.c[1]
                    if vpoint.has_offset() and vpoint.true_offset() <= 0.1:
                        if vpoint.offset() > 0:
                            x += 0.1
                            y += 0.1
                        else:
                            x -= 0.1
                            y -= 0.1
                    self.params.push_back(x)
                    tmp_ptr = &self.params.back()
                    self.params.push_back(y)
                    self.points.push_back([tmp_ptr, &self.params.back()])
                else:
                    self.points.push_back([tmp_ptr, &self.constants.back()])
                continue

            if i in self.data_dict:
                # Known coordinates
                coord = self.data_dict[i]
                self.data_values.push_back(coord.x)
                tmp_ptr = &self.data_values.back()
                self.data_values.push_back(coord.y)
                self.points.push_back([tmp_ptr, &self.data_values.back()])
                continue

            x, y = vpoint.c[0]
            self.params.push_back(x)
            tmp_ptr = &self.params.back()
            self.params.push_back(y)
            if vpoint.type in {VJoint.P, VJoint.RP}:
                self.sliders[i] = <int>self.slider_bases.size()
                # Base point (slot) is movable
                self.slider_bases.push_back([tmp_ptr, &self.params.back()])
                # Slot point (slot) is movable
                self.params.push_back(x + cos(vpoint.angle))
                tmp_ptr = &self.params.back()
                self.params.push_back(y + sin(vpoint.angle))
                self.slider_slots.push_back([tmp_ptr, &self.params.back()])
                if vpoint.pin_grounded():
                    # Pin is fixed
                    x, y = vpoint.c[1]
                    self.constants.push_back(x)
                    tmp_ptr = &self.constants.back()
                    self.constants.push_back(y)
                    self.points.push_back([tmp_ptr, &self.constants.back()])
                else:
                    # Pin is movable
                    x, y = vpoint.c[1]
                    if vpoint.has_offset() and vpoint.true_offset() <= 0.1:
                        if vpoint.offset() > 0:
                            x += 0.1
                            y += 0.1
                        else:
                            x -= 0.1
                            y -= 0.1
                    self.params.push_back(x)
                    tmp_ptr = &self.params.back()
                    self.params.push_back(y)
                    self.points.push_back([tmp_ptr, &self.params.back()])
                continue

            # Point is movable
            self.points.push_back([tmp_ptr, &self.params.back()])

        # Link constraints
        # (automatic fill up the link length options of data keys)
        cdef int a, b, c, d
        cdef frozenset frozen_pair
        cdef VPoint vp1, vp2
        cdef Point *p1
        cdef Point *p2
        cdef VLink vlink
        for vlink in self.vlinks.values():
            if len(vlink.points) < 2:
                continue
            if vlink.name == 'ground':
                continue

            a = vlink.points[0]
            b = vlink.points[1]
            if (a not in self.data_dict) or (b not in self.data_dict):
                vp1 = self.vpoints[a]
                vp2 = self.vpoints[b]

                if a not in self.data_dict and vp1.is_slot_link(vlink.name):
                    p1 = &self.slider_bases[self.sliders[a]]
                else:
                    p1 = &self.points[a]

                if b not in self.data_dict and vp2.is_slot_link(vlink.name):
                    p2 = &self.slider_bases[self.sliders[b]]
                else:
                    p2 = &self.points[b]

                frozen_pair = frozenset({a, b})
                if frozen_pair in self.data_dict:
                    x = self.data_dict[frozen_pair]
                else:
                    x = vp1.distance(vp2)
                    self.data_dict[frozen_pair] = x
                self.data_values.push_back(x)
                self.cons_list.push_back(P2PDistanceConstraint(p1, p2, &self.data_values.back()))

            for c in vlink.points[2:]:
                if c in self.data_dict:
                    # Known coordinate
                    continue
                for d in (a, b):
                    vp1 = self.vpoints[c]
                    vp2 = self.vpoints[d]

                    if vp1.is_slot_link(vlink.name):
                        p1 = &self.slider_bases[self.sliders[c]]
                    else:
                        p1 = &self.points[c]

                    if (d not in self.data_dict) and vp2.is_slot_link(vlink.name):
                        p2 = &self.slider_bases[self.sliders[d]]
                    else:
                        p2 = &self.points[d]

                    frozen_pair = frozenset({c, d})
                    if frozen_pair in self.data_dict:
                        x = self.data_dict[frozen_pair]
                    else:
                        x = vp1.distance(vp2)
                        self.data_dict[frozen_pair] = x
                    self.data_values.push_back(x)
                    self.cons_list.push_back(P2PDistanceConstraint(p1, p2, &self.data_values.back()))

        # Slider constraints
        cdef str name
        cdef Line *slider_slot
        cdef pair[int, int] slider
        for slider in self.sliders:
            a = slider.first
            b = slider.second
            # Base point
            vp1 = self.vpoints[a]
            p1 = &self.points[a]
            # Base slot
            self.slider_lines.push_back([&self.slider_bases[b], &self.slider_slots[b]])
            slider_slot = &self.slider_lines.back()
            if vp1.grounded():
                # Slot is grounded.
                self.constants.push_back(_radians(vp1.angle))
                self.cons_list.push_back(LineInternalAngleConstraint(slider_slot, &self.constants.back()))
                self.cons_list.push_back(PointOnLineConstraint(p1, slider_slot))
                if vp1.has_offset():
                    p2 = &self.slider_bases[b]
                    if vp1.offset():
                        self.constants.push_back(vp1.offset())
                        self.cons_list.push_back(P2PDistanceConstraint(p2, p1, &self.constants.back()))
                    else:
                        self.cons_list.push_back(PointOnPointConstraint(p2, p1))
            else:
                # Slider between links
                for name in vp1.links[:1]:
                    vlink = self.vlinks[name]
                    # A base link friend
                    c = vlink.points[0]
                    if c == a:
                        if len(vlink.points) < 2:
                            # If no any friend
                            continue
                        c = vlink.points[1]

                    vp2 = self.vpoints[c]
                    if vp2.is_slot_link(vlink.name):
                        # c is a slider, and it is be connected with slot link
                        p2 = &self.slider_bases[self.sliders[c]]
                    else:
                        # c is a R joint or it is not connected with slot link
                        p2 = &self.points[c]
                    self.slider_lines.push_back([&self.slider_bases[b], p2])
                    self.constants.push_back(_radians(vp1.slope_angle(vp2) - vp1.angle))
                    self.cons_list.push_back(InternalAngleConstraint(
                        slider_slot,
                        &self.slider_lines.back(),
                        &self.constants.back()
                    ))
                    self.cons_list.push_back(PointOnLineConstraint(p1, slider_slot))

                    if vp1.has_offset():
                        p2 = &self.slider_bases[b]
                        if vp1.offset():
                            self.constants.push_back(vp1.offset())
                            self.cons_list.push_back(P2PDistanceConstraint(p2, p1, &self.constants.back()))
                        else:
                            self.cons_list.push_back(PointOnPointConstraint(p2, p1))

            if vp1.type != VJoint.P:
                continue

            for name in vp1.links[1:]:
                vlink = self.vlinks[name]
                # A base link friend
                c = vlink.points[0]
                if c == a:
                    if len(vlink.points) < 2:
                        # If no any friend
                        continue
                    c = vlink.points[1]

                vp2 = self.vpoints[c]
                if vp2.is_slot_link(vlink.name):
                    # c is a slider, and it is be connected with slot link
                    p2 = &self.slider_bases[self.sliders[c]]
                else:
                    # c is a R joint or it is not connected with slot link
                    p2 = &self.points[c]
                self.slider_lines.push_back([p1, p2])
                self.constants.push_back(_radians(vp1.slope_angle(vp2) - vp1.angle))
                self.cons_list.push_back(InternalAngleConstraint(
                    slider_slot,
                    &self.slider_lines.back(),
                    &self.constants.back()
                ))

        # Angle constraints
        cdef double angle
        for (b, d), angle in self.inputs.items():
            if b == d:
                continue
            self.handles.push_back([&self.points[b], &self.points[d]])
            self.inputs_angle.push_back(_radians(angle))
            self.cons_list.push_back(LineInternalAngleConstraint(
                &self.handles.back(),
                &self.inputs_angle.back()
            ))

    cpdef void set_inputs(self, dict inputs):
        """Set input pairs."""
        if self.inputs is None or inputs is None:
            raise ValueError(f"do not accept modifications")
        if not self.show_inputs() >= set(inputs):
            raise ValueError(f"format must be {set(self.inputs)}, not {set(inputs)}")

        self.inputs.update(inputs)

        # Set values
        cdef int b, d
        cdef double angle
        cdef double *handle
        cdef clist[double].iterator it = self.inputs_angle.begin()
        for (b, d), angle in self.inputs.items():
            if b == d:
                continue
            handle = de_refer_post_inc(it)
            handle[0] = _radians(angle)

    cpdef void set_data(self, dict data_dict):
        """Set data."""
        if self.data_dict is None or data_dict is None:
            raise ValueError(f"do not accept modifications")
        _sort_pairs(data_dict)
        if not self.show_data() >= set(data_dict):
            raise ValueError(f"format must be {set(self.data_dict)}, not {set(data_dict)}")

        self.data_dict.update(data_dict)
        cdef size_t n = 0

        # Set values
        cdef int i
        cdef double *handle
        cdef VPoint vpoint
        cdef Coordinate coord
        cdef clist[double].iterator it = self.data_values.begin()
        for i, vpoint in enumerate(self.vpoints):
            if vpoint.grounded():
                if i in self.data_dict:
                    # Known coordinates.
                    coord = self.data_dict[i]
                    handle = de_refer_post_inc(it)
                    handle[0] = coord.x
                    handle = de_refer_post_inc(it)
                    handle[0] = coord.y
            if i in self.data_dict:
                # Known coordinates.
                coord = self.data_dict[i]
                handle = de_refer_post_inc(it)
                handle[0] = coord.x
                handle = de_refer_post_inc(it)
                handle[0] = coord.y

        cdef int a, b, c, d
        cdef frozenset frozen_pair
        cdef VLink vlink
        for vlink in self.vlinks.values():
            if len(vlink.points) < 2:
                continue
            if vlink.name == 'ground':
                continue

            a = vlink.points[0]
            b = vlink.points[1]
            if (a not in self.data_dict) or (b not in self.data_dict):
                handle = de_refer_post_inc(it)
                handle[0] = self.data_dict[frozenset({a, b})]
            for c in vlink.points[2:]:
                if c in self.data_dict:
                    # Known coordinate
                    continue
                for d in (a, b):
                    handle = de_refer_post_inc(it)
                    handle[0] = self.data_dict[frozenset({c, d})]

    cpdef list solve(self):
        """Solve the expression."""
        # Pointer of parameters
        cdef size_t params_count = <int>self.params.size()
        cdef double **params_ptr = <double **>PyMem_Malloc(sizeof(double *) * params_count)
        cdef clist[double].iterator it = self.params.begin()
        cdef size_t i
        for i in range(params_count):
            params_ptr[i] = de_refer_post_inc(it)

        # Pointer of constraints
        cdef size_t cons_count = <int>self.cons_list.size()
        cdef Constraint *cons = <Constraint *>PyMem_Malloc(sizeof(Constraint) * cons_count)
        i = 0
        cdef Constraint con
        for con in self.cons_list:
            cons[i] = con
            i += 1

        # Solve
        cdef int flag = solve(params_ptr, params_count, cons, cons_count, Rough)

        cdef list solved_points
        if flag == Success:
            solved_points = []
            for i, vpoint in enumerate(self.vpoints):
                if vpoint.type == VJoint.R:
                    solved_points.append((self.points[i].x[0], self.points[i].y[0]))
                else:
                    solved_points.append((
                        (self.slider_bases[self.sliders[i]].x[0], self.slider_bases[self.sliders[i]].y[0]),
                        (self.points[i].x[0], self.points[i].y[0])
                    ))

        PyMem_Free(params_ptr)
        PyMem_Free(cons)

        if flag == Success:
            return solved_points
        else:
            raise ValueError("no valid solutions were found from initialed values")