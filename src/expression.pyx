# -*- coding: utf-8 -*-
# cython: language_level=3

"""PMKS simbolics.

author: Yuan Chang
copyright: Copyright (C) 2016-2019
license: AGPL
email: pyslvs@gmail.com
"""

cimport cython
from libc.math cimport (
    M_PI,
    atan2,
    hypot,
)
from cpython.object cimport Py_EQ, Py_NE


@cython.final
cdef class VPoint:

    """Symbol of joints."""

    def __cinit__(
        self,
        str links,
        VJoint j_type,
        double angle,
        str color_str,
        double x,
        double y,
        object color_func = None
    ):
        cdef str name
        self.links = tuple([name for name in links.replace(" ", '').split(',') if name])
        self.type = j_type
        self.type_str = ('R', 'P', 'RP')[j_type]
        self.angle = angle

        self.color_str = color_str
        if color_func is None:
            self.color = None
        else:
            self.color = color_func(color_str)

        self.x = x
        self.y = y
        self.c = ndarray(2, dtype=object)

        if self.type in {VJoint.P, VJoint.RP}:
            # Slider current coordinates.
            # [0]: Current node on slot.
            # [1]: Pin.
            self.c[0] = (self.x, self.y)
            self.c[1] = (self.x, self.y)
        else:
            self.c[0] = (self.x, self.y)

        self.__has_offset = False
        self.__offset = 0

    @staticmethod
    def r_joint(links: str, x: double, y: double) -> VPoint:
        """Create by coordinate."""
        return VPoint.c_r_joint(links, x, y)

    @staticmethod
    cdef VPoint c_r_joint(str links, double x, double y):
        return VPoint.__new__(VPoint, links, VJoint.R, 0., '', x, y)

    @staticmethod
    def slider_joint(links: str, type_int: VJoint, angle: double, x: double, y: double) -> VPoint:
        """Create by coordinate."""
        return VPoint.c_slider_joint(links, type_int, angle, x, y)

    @staticmethod
    cdef VPoint c_slider_joint(str links, VJoint type_int, double angle, double x, double y):
        return VPoint.__new__(VPoint, links, type_int, angle, '', x, y)

    def __copy__(self) -> VPoint:
        """Copy method."""
        cdef VPoint vpoint = VPoint.__new__(
            VPoint,
            ", ".join(self.links),
            self.type,
            self.angle,
            self.color_str,
            self.x,
            self.y
        )
        vpoint.move(self.c[0], self.c[1])
        return vpoint

    cpdef VPoint copy(self):
        """Copy method of Python."""
        return self.__copy__()

    def __richcmp__(self, other: VPoint, op: int) -> bint:
        """Rich comparison."""
        if op == Py_EQ:
            return (
                self.links == other.links and
                (self.c == other.c).all() and
                self.type == other.type and
                self.x == other.x and
                self.y == other.y and
                self.angle == other.angle
            )
        elif op == Py_NE:
            return (
                self.links != other.links or
                (self.c != other.c).any() or
                self.type != other.type or
                self.x != other.x or
                self.y != other.y or
                self.angle != other.angle
            )
        else:
            raise TypeError(
                f"'{op}' not support between instances of "
                f"{type(self)} and {type(other)}"
            )

    @property
    def cx(self) -> float:
        """X value of first current coordinate."""
        if self.type == VJoint.R:
            return self.c[0][0]
        else:
            return self.c[1][0]

    @property
    def cy(self) -> float:
        """Y value of first current coordinate."""
        if self.type == VJoint.R:
            return self.c[0][1]
        else:
            return self.c[1][1]

    cpdef void move(self, tuple c1, tuple c2 = None) except *:
        """Change coordinates of this point."""
        cdef double x, y
        x, y = c1
        self.c[0] = (x, y)
        if self.type in {VJoint.P, VJoint.RP}:
            if c2:
                x, y = c2
            self.c[1] = (x, y)

    cpdef void rotate(self, double angle):
        """Change the angle of slider slot by degrees."""
        self.angle = angle % 180

    cpdef void set_offset(self, double offset):
        """Set slider offset."""
        self.__has_offset = True
        self.__offset = offset

    cpdef void disable_offset(self):
        """Disable offset status."""
        self.__has_offset = False

    cpdef double distance(self, VPoint p):
        """Distance between two VPoint."""
        cdef tuple on_links = tuple(set(self.links) & set(p.links))

        cdef double m_x = 0
        cdef double m_y = 0
        cdef double p_x = 0
        cdef double p_y = 0

        if on_links:
            if (self.type == VJoint.R) or (self.links[0] == on_links[0]):
                # self is R joint or at base link.
                m_x = self.c[0][0]
                m_y = self.c[0][1]
            else:
                # At pin joint.
                m_x = self.c[1][0]
                m_y = self.c[1][1]
            if (p.type == VJoint.R) or (p.links[0] == on_links[0]):
                # p is R joint or at base link.
                p_x = p.c[0][0]
                p_y = p.c[0][1]
            else:
                # At pin joint.
                p_x = p.c[1][0]
                p_y = p.c[1][1]
        else:
            m_x = self.c[0][0]
            m_y = self.c[0][1]
            p_x = p.c[0][0]
            p_y = p.c[0][1]
        return hypot(p_x - m_x, p_y - m_y)

    cpdef bint has_offset(self):
        """Return has offset."""
        return self.__has_offset

    cpdef double offset(self):
        """Return target offset."""
        return self.__offset

    cpdef double true_offset(self):
        """Return offset between slot and pin."""
        return hypot(self.c[1][0] - self.c[0][0], self.c[1][1] - self.c[0][1])

    @cython.cdivision
    cpdef double slope_angle(self, VPoint p, int num1 = 2, int num2 = 2):
        """Angle between horizontal line and two point.
        
        num1: me.
        num2: other side.
        [0]: base (slot) link.
        [1]: pin link.
        """
        cdef double x1, y1, x2, y2
        if num1 > 1:
            x2, y2 = self.x, self.y
        else:
            x2, y2 = self.c[num2]
        if num2 > 1:
            x1, y1 = p.x, p.y
        else:
            x1, y1 = p.c[num2]
        return atan2(y1 - y2, x1 - x2) / M_PI * 180

    cpdef bint grounded(self):
        """Return True if the joint is connect with the ground."""
        if self.type == VJoint.R:
            return 'ground' in self.links
        elif self.type in {VJoint.P, VJoint.RP}:
            if self.links:
                return self.is_slot_link('ground')
            else:
                return False

    cpdef bint pin_grounded(self):
        """Return True if the joint has any pin connect with the ground."""
        return 'ground' in self.links[1:]

    cpdef bint same_link(self, VPoint p):
        """Return True if the point is at the same link."""
        return set(self.links) & set(p.links)

    cpdef bint no_link(self):
        """Return True if the point has no link."""
        return not self.links

    cpdef bint is_slot_link(self, str link_name):
        """Return True if the link name is first link."""
        if self.type == VJoint.R:
            return False
        if self.links:
            return link_name == self.links[0]
        else:
            return False

    @property
    def expr(self) -> str:
        """Expression."""
        if self.type != VJoint.R:
            type_text = f"{self.type_str}, A[{self.angle}]"
        else:
            type_text = 'R'
        if self.color_str:
            color = f", color[{self.color_str}]"
        else:
            color = ""
        links_text = ", ".join(name for name in self.links)
        x_text = f"{self.x:.4f}".rstrip('0').rstrip('.')
        y_text = f"{self.y:.4f}".rstrip('0').rstrip('.')
        return f"J[{type_text}{color}, P[{x_text}, {y_text}], L[{links_text}]]"

    def __getitem__(self, i: int) -> float:
        """Get coordinate like this:

        x, y = VPoint(10, 20)
        """
        if self.type == VJoint.R:
            return self.c[0][i]
        else:
            return self.c[1][i]

    def __repr__(self) -> str:
        """Use to generate script."""
        return f"VPoint({self.links}, {int(self.type)}, {self.angle}, {list(self.c)})"


@cython.final
cdef class VLink:

    """Symbol of links."""

    cdef readonly str name, color_str
    cdef readonly tuple color
    cdef readonly tuple points

    def __cinit__(
        self,
        str name,
        str color_str,
        object points,
        object color_func = None
    ):
        self.name = name
        self.color_str = color_str
        if color_func is None:
            self.color = None
        else:
            self.color = color_func(color_str)
        self.points = tuple(points)

    def __contains__(self, point: int) -> bint:
        """Check if point number is in the link."""
        return point in self.points

    def __repr__(self) -> str:
        """Use to generate script."""
        return f"VLink('{self.name}', {self.points}, color_qt)"
