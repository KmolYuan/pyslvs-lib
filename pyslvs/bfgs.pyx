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


ctypedef fused T:
    double
    Line


cdef inline T *end_ptr(clist[T] *t_list):
    """Get last pointer."""
    return &t_list.back()


cdef inline void _sort_pairs(dict data_dict):
    """Sort the pairs in data_dict."""
    cdef object k
    for k in data_dict:
        if type(k) is tuple:
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

    cdef void build_expression(self):
        """Build the expression for solver."""
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
                tmp_ptr = end_ptr(&self.constants)
                self.constants.push_back(y)
                self.points.push_back([tmp_ptr, end_ptr(&self.constants)])
                continue

            if vpoint.grounded():
                if i in self.data_dict:
                    # Known coordinates.
                    coord = self.data_dict[i]
                    self.constants.push_back(coord.x)
                    tmp_ptr = end_ptr(&self.constants)
                    self.constants.push_back(coord.y)
                    self.points.push_back([tmp_ptr, end_ptr(&self.constants)])
                    continue

                x, y = vpoint.c[0]
                self.constants.push_back(x)
                tmp_ptr = end_ptr(&self.constants)
                self.constants.push_back(y)
                if vpoint.type in {VJoint.P, VJoint.RP}:
                    self.sliders[i] = <int>self.slider_bases.size()
                    # Base point (slot) is fixed.
                    self.slider_bases.push_back([tmp_ptr, end_ptr(&self.constants)])
                    # Slot point (slot) is movable.
                    self.params.push_back(x + cos(vpoint.angle))
                    tmp_ptr = end_ptr(&self.params)
                    self.params.push_back(y + sin(vpoint.angle))
                    self.slider_slots.push_back([tmp_ptr, end_ptr(&self.params)])
                    # Pin is movable.
                    x, y = vpoint.c[1]
                    if vpoint.has_offset() and vpoint.true_offset() <= 0.1:
                        if vpoint.offset() > 0:
                            x += 0.1
                            y += 0.1
                        else:
                            x -= 0.1
                            y -= 0.1
                    self.params.push_back(x)
                    tmp_ptr = end_ptr(&self.params)
                    self.params.push_back(y)
                    self.points.push_back([tmp_ptr, end_ptr(&self.params)])
                else:
                    self.points.push_back([tmp_ptr, end_ptr(&self.constants)])
                continue

            if i in self.data_dict:
                # Known coordinates.
                coord = self.data_dict[i]
                self.constants.push_back(coord.x)
                tmp_ptr = end_ptr(&self.constants)
                self.constants.push_back(coord.y)
                self.points.push_back([tmp_ptr, end_ptr(&self.constants)])
                continue

            x, y = vpoint.c[0]
            self.params.push_back(x)
            tmp_ptr = end_ptr(&self.params)
            self.params.push_back(y)
            if vpoint.type in {VJoint.P, VJoint.RP}:
                self.sliders[i] = <int>self.slider_bases.size()
                # Base point (slot) is movable.
                self.slider_bases.push_back([tmp_ptr, end_ptr(&self.params)])
                # Slot point (slot) is movable.
                self.params.push_back(x + cos(vpoint.angle))
                tmp_ptr = end_ptr(&self.params)
                self.params.push_back(y + sin(vpoint.angle))
                self.slider_slots.push_back([tmp_ptr, end_ptr(&self.params)])
                if vpoint.pin_grounded():
                    # Pin is fixed.
                    x, y = vpoint.c[1]
                    self.constants.push_back(x)
                    tmp_ptr = end_ptr(&self.constants)
                    self.constants.push_back(y)
                    self.points.push_back([tmp_ptr, end_ptr(&self.constants)])
                else:
                    # Pin is movable.
                    x, y = vpoint.c[1]
                    if vpoint.has_offset() and vpoint.true_offset() <= 0.1:
                        if vpoint.offset() > 0:
                            x += 0.1
                            y += 0.1
                        else:
                            x -= 0.1
                            y -= 0.1
                    self.params.push_back(x)
                    tmp_ptr = end_ptr(&self.params)
                    self.params.push_back(y)
                    self.points.push_back([tmp_ptr, end_ptr(&self.params)])
                continue

            # Point is movable.
            self.points.push_back([tmp_ptr, end_ptr(&self.params)])

        # Link constraints
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
                    self.constants.push_back(self.data_dict[frozen_pair])
                else:
                    self.constants.push_back(vp1.distance(vp2))

                self.cons_list.push_back(P2PDistanceConstraint(p1, p2, end_ptr(&self.constants)))

            for c in vlink.points[2:]:
                if c in self.data_dict:
                    # Known coordinate.
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
                        self.constants.push_back(self.data_dict[frozen_pair])
                    else:
                        self.constants.push_back(vp1.distance(vp2))

                    self.cons_list.push_back(P2PDistanceConstraint(p1, p2, end_ptr(&self.constants)))

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
            slider_slot = end_ptr(&self.slider_lines)
            if vp1.grounded():
                # Slot is grounded.
                self.constants.push_back(_radians(vp1.angle))
                self.cons_list.push_back(LineInternalAngleConstraint(slider_slot, end_ptr(&self.constants)))
                self.cons_list.push_back(PointOnLineConstraint(p1, slider_slot))
                if vp1.has_offset():
                    p2 = &self.slider_bases[b]
                    if vp1.offset():
                        self.constants.push_back(vp1.offset())
                        self.cons_list.push_back(P2PDistanceConstraint(p2, p1, end_ptr(&self.constants)))
                    else:
                        self.cons_list.push_back(PointOnPointConstraint(p2, p1))
            else:
                # Slider between links.
                for name in vp1.links[:1]:
                    vlink = self.vlinks[name]
                    # A base link friend.
                    c = vlink.points[0]
                    if c == a:
                        if len(vlink.points) < 2:
                            # If no any friend.
                            continue
                        c = vlink.points[1]

                    vp2 = self.vpoints[c]
                    if vp2.is_slot_link(vlink.name):
                        # c is a slider, and it is be connected with slot link.
                        p2 = &self.slider_bases[self.sliders[c]]
                    else:
                        # c is a R joint or it is not connected with slot link.
                        p2 = &self.points[c]
                    self.slider_lines.push_back([&self.slider_bases[b], p2])
                    self.constants.push_back(_radians(vp1.slope_angle(vp2) - vp1.angle))
                    self.cons_list.push_back(InternalAngleConstraint(
                        slider_slot,
                        end_ptr(&self.slider_lines),
                        end_ptr(&self.constants)
                    ))
                    self.cons_list.push_back(PointOnLineConstraint(p1, slider_slot))

                    if vp1.has_offset():
                        p2 = &self.slider_bases[b]
                        if vp1.offset():
                            self.constants.push_back(vp1.offset())
                            self.cons_list.push_back(P2PDistanceConstraint(p2, p1, end_ptr(&self.constants)))
                        else:
                            self.cons_list.push_back(PointOnPointConstraint(p2, p1))

            if vp1.type != VJoint.P:
                continue

            for name in vp1.links[1:]:
                vlink = self.vlinks[name]
                # A base link friend.
                c = vlink.points[0]
                if c == a:
                    if len(vlink.points) < 2:
                        # If no any friend.
                        continue
                    c = vlink.points[1]

                vp2 = self.vpoints[c]
                if vp2.is_slot_link(vlink.name):
                    # c is a slider, and it is be connected with slot link.
                    p2 = &self.slider_bases[self.sliders[c]]
                else:
                    # c is a R joint or it is not connected with slot link.
                    p2 = &self.points[c]
                self.slider_lines.push_back([p1, p2])
                self.constants.push_back(_radians(vp1.slope_angle(vp2) - vp1.angle))
                self.cons_list.push_back(InternalAngleConstraint(
                    slider_slot,
                    end_ptr(&self.slider_lines),
                    end_ptr(&self.constants)
                ))

        # Angle constraints
        cdef clist[Line] handles
        cdef double angle
        for (b, d), angle in self.inputs.items():
            if b == d:
                continue
            handles.push_back([&self.points[b], &self.points[d]])
            self.constants.push_back(_radians(angle))
            self.cons_list.push_back(LineInternalAngleConstraint(
                end_ptr(&handles),
                end_ptr(&self.constants)
            ))

    cpdef list solve(self):
        """Solve the expression."""
        # Pointer of parameters
        cdef size_t params_count = <int>self.params.size()
        cdef double **params_ptr = <double **>PyMem_Malloc(sizeof(double *) * params_count)
        cdef clist[double].iterator it = self.params.begin()
        cdef size_t i
        for i in range(params_count):
            params_ptr[i] = &cython.operator.dereference(cython.operator.postincrement(it))

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
