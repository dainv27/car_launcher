package com.carlauncher.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.homeLayoutStore: DataStore<Preferences> by preferencesDataStore(name = "home_layout")

private val KEY_ROWS = intPreferencesKey("grid_rows")
private val KEY_COLS = intPreferencesKey("grid_cols")
private val KEY_SLOTS = stringPreferencesKey("slot_components")

private const val SLOT_SEP = "\u0001"
private const val SLOT_EMPTY = "\u0000"

data class HomeLayoutState(
    val rows: Int,
    val cols: Int,
    /** Mỗi phần tử là [ComponentName.flattenToString] hoặc null. */
    val slotComponents: List<String?>,
)

fun defaultHomeLayout(): HomeLayoutState {
    val rows = 2
    val cols = 2
    return HomeLayoutState(
        rows = rows,
        cols = cols,
        slotComponents = List(rows * cols) { null },
    )
}

class HomeLayoutRepository(private val context: Context) {

    val layout: Flow<HomeLayoutState> = context.homeLayoutStore.data.map { prefs ->
        val rows = prefs[KEY_ROWS] ?: 2
        val cols = prefs[KEY_COLS] ?: 2
        val count = rows * cols
        val decoded = decodeSlots(prefs[KEY_SLOTS], count)
        HomeLayoutState(rows = rows, cols = cols, slotComponents = decoded)
    }

    suspend fun setGrid(rows: Int, cols: Int) {
        require(rows in 1..4 && cols in 1..4) { "Grid out of bounds" }
        context.homeLayoutStore.edit { prefs ->
            val oldRows = prefs[KEY_ROWS] ?: 2
            val oldCols = prefs[KEY_COLS] ?: 2
            val oldSlots = decodeSlots(prefs[KEY_SLOTS], oldRows * oldCols)
            val newCount = rows * cols
            val merged = List(newCount) { i ->
                if (i < oldSlots.size) oldSlots[i] else null
            }
            prefs[KEY_ROWS] = rows
            prefs[KEY_COLS] = cols
            prefs[KEY_SLOTS] = encodeSlots(merged)
        }
    }

    suspend fun setSlot(index: Int, flatComponent: String?) {
        context.homeLayoutStore.edit { prefs ->
            val rows = prefs[KEY_ROWS] ?: 2
            val cols = prefs[KEY_COLS] ?: 2
            val count = rows * cols
            require(index in 0 until count)
            val slots = decodeSlots(prefs[KEY_SLOTS], count).toMutableList()
            slots[index] = flatComponent
            prefs[KEY_SLOTS] = encodeSlots(slots)
        }
    }
}

private fun encodeSlots(slots: List<String?>): String =
    slots.joinToString(SLOT_SEP) { flat ->
        when (flat) {
            null, "" -> SLOT_EMPTY
            else -> flat
        }
    }

private fun decodeSlots(encoded: String?, targetCount: Int): List<String?> {
    if (encoded.isNullOrBlank()) return List(targetCount) { null }
    val parts = encoded.split(SLOT_SEP)
    return List(targetCount) { i ->
        if (i >= parts.size) null
        else {
            val p = parts[i]
            if (p.isEmpty() || p == SLOT_EMPTY) null else p
        }
    }
}
