# -*- coding: utf-8 -*-

from typing import (
    Tuple,
    List,
    Sequence,
    FrozenSet,
    Dict,
    Optional,
    Union,
)
from .expression import VPoint, Coordinate

_Coord = Tuple[float, float]


class SolverSystem:

    """Sketch Solve solver."""

    def __init__(
        self,
        vpoints: Sequence[VPoint],
        inputs: Optional[Dict[Tuple[int, int], float]] = None,
        data_dict: Optional[Dict[Union[int, Tuple[int, int]], Union[Coordinate, float]]] = None
    ):
        ...

    def same_points(self, vpoints_: Sequence[VPoint]) -> bool:
        """Return True if two expressions are same."""
        ...

    def show_inputs(self) -> FrozenSet[Tuple[int, int]]:
        """Show the current inputs keys."""
        ...

    def show_data(self) -> FrozenSet[Union[int, Tuple[int, int]]]:
        """Show the current data keys."""
        ...

    def set_inputs(self, inputs: Dict[Tuple[int, int], float]):
        """Set input pairs."""
        ...

    def set_data(self, data_dict: Dict[Union[int, Tuple[int, int]], Union[Coordinate, float]]):
        """Set data."""
        ...

    def solve(self) -> List[Union[_Coord, Tuple[_Coord, _Coord]]]:
        """Solve the expression."""
        ...