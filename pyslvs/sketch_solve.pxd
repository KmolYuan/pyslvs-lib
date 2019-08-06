# -*- coding: utf-8 -*-
# cython: language_level=3

"""Wrapper header of BFGS algorithm.
If you need to use container to carry floating point data,
std::list is recommended instead of std::vector.

author: Yuan Chang
copyright: Copyright (C) 2016-2019
license: AGPL
email: pyslvs@gmail.com
"""

cdef extern from "bfgs_solver/solve.h" nogil:

    int Rough
    int Fine
    int MaxIterations

    int Success
    int NoSolution

    struct Point:
        double *x
        double *y

    struct Line:
        Point *p1
        Point *p2

    struct Arc:
        double *startAngle
        double *endAngle
        double *rad
        Point *center

    struct Circle:
        Point *center
        double *rad

    enum ConstraintType:
        pass

    struct Constraint:
        ConstraintType type
        Point *point1
        Point *point2
        Line *line1
        Line *line2
        Line *SymLine
        Circle *circle1
        Circle *circle2
        Arc *arc1
        Arc *arc2
        double *parameter

    Constraint PointOnPointConstraint(Point *, Point *);
    Constraint P2PDistanceConstraint(Point *, Point *, double *)
    Constraint P2PDistanceVertConstraint(Point *, Point *, double *)
    Constraint P2PDistanceHorzConstraint(Point *, Point *, double *)
    Constraint PointOnLineConstraint(Point *, Line *)
    Constraint P2LDistanceConstraint(Point *, Line *, double *)
    Constraint P2LDistanceVertConstraint(Point *, Line *, double *)
    Constraint P2LDistanceHorzConstraint(Point *, Line *, double *)
    Constraint VerticalConstraint(Line *)
    Constraint HorizontalConstraint(Line *)
    Constraint TangentToCircleConstraint(Line *, Circle *)
    Constraint TangentToArcConstraint(Line *, Arc *)
    Constraint ArcRulesConstraint(Arc *)
    Constraint LineLengthConstraint(Line *)
    Constraint EqualLegnthConstraint(Line *, Line *)
    Constraint ArcRadiusConstraint(Arc *, double *)
    Constraint EqualRadiusArcsConstraint(Arc *, Arc *)
    Constraint EqualRadiusCirclesConstraint(Circle *, Circle *)
    Constraint EqualRadiusCircArcConstraint(Circle *, Arc *)
    Constraint ConcentricArcsConstraint(Arc *, Arc *)
    Constraint ConcentricCirclesConstraint(Circle *, Circle *)
    Constraint ConcentricCircArcConstraint(Circle *, Arc *)
    Constraint CircleRadiusConstraint(Circle *, double *)
    Constraint InternalAngleConstraint(Line *, Line *, double *)
    Constraint ExternalAngleConstraint(Line *, Line *, double *)
    Constraint PerpendicularConstraint(Line *, Line *)
    Constraint ParallelConstraint(Line *, Line *)
    Constraint ColinearConstraint(Line *, Line *)
    Constraint PointOnCircleConstraint(Point *, Circle *)
    Constraint PointOnArcConstraint(Point *, Arc *)
    Constraint PointOnLineMidpointConstraint(Point *, Line *)
    Constraint PointOnArcMidpointConstraint(Point *, Arc *)
    Constraint PointOnCircleQuadConstraint(Point *, Circle *, double *)
    Constraint SymmetricPointsConstraint(Point *, Point *, Line *)
    Constraint SymmetricLinesConstraint(Line *, Line *, Line *)
    Constraint SymmetricCirclesConstraint(Circle *, Circle *, Line *)
    Constraint SymmetricArcsConstraint(Arc *, Arc *, Line *)
    Constraint LineInternalAngleConstraint(Line *, double *)
    Constraint LineExternalAngleConstraint(Line *, double *)

    int solve(double **, const size_t, Constraint *, const size_t, int)
    void derivatives(double **, double *, int, Constraint *, int)
