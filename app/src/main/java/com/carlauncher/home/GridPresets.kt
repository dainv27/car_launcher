package com.carlauncher.home

import com.carlauncher.R

object GridPresets {
    val all: List<Triple<Int, Int, Int>> = listOf(
        Triple(1, 2, R.string.grid_1x2),
        Triple(2, 1, R.string.grid_2x1),
        Triple(2, 2, R.string.grid_2x2),
        Triple(2, 3, R.string.grid_2x3),
        Triple(3, 2, R.string.grid_3x2),
        Triple(3, 3, R.string.grid_3x3),
    )
}
