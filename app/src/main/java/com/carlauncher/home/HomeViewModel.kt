package com.carlauncher.home

import android.app.Application
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.core.graphics.drawable.toBitmap
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.carlauncher.data.HomeLayoutRepository
import com.carlauncher.data.HomeLayoutState
import com.carlauncher.data.defaultHomeLayout
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.min
import kotlinx.coroutines.ExperimentalCoroutinesApi

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModel(application: Application) : AndroidViewModel(application) {

    private val repository = HomeLayoutRepository(application)

    private val _apps = MutableStateFlow<List<AppEntry>?>(null)
    val apps: StateFlow<List<AppEntry>?> = _apps.asStateFlow()

    val layout: StateFlow<HomeLayoutState> = repository.layout.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5_000),
        defaultHomeLayout(),
    )

    val slotEntries: StateFlow<List<AppEntry?>> = combine(layout, _apps) { lay, appsList ->
        lay to appsList
    }.flatMapLatest { (lay, appsList) ->
        flow {
            emit(
                withContext(Dispatchers.IO) {
                    val pm = getApplication<Application>().packageManager
                    val cache = appsList.orEmpty()
                    lay.slotComponents.map { flat ->
                        if (flat.isNullOrBlank()) {
                            null
                        } else {
                            val cn = runCatching { ComponentName.unflattenFromString(flat) }.getOrNull()
                                ?: return@map null
                            cache.find { it.component == cn }
                                ?: resolveEntrySync(pm, cn)
                        }
                    }
                },
            )
        }
    }.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5_000),
        emptyList(),
    )

    init {
        loadApps()
    }

    fun loadApps() {
        viewModelScope.launch {
            val loaded = withContext(Dispatchers.IO) {
                val pm = getApplication<Application>().packageManager
                val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_LAUNCHER)
                }
                val resolves = pm.queryIntentActivities(launcherIntent, PackageManager.MATCH_DEFAULT_ONLY)
                resolves
                    .asSequence()
                    .distinctBy { "${it.activityInfo.packageName}/${it.activityInfo.name}" }
                    .mapNotNull { resolve ->
                        val iconDrawable = try {
                            resolve.loadIcon(pm)
                        } catch (_: PackageManager.NameNotFoundException) {
                            return@mapNotNull null
                        }
                        val bmp = iconDrawable.toBitmapSafely() ?: return@mapNotNull null
                        val label = resolve.loadLabel(pm)?.toString()
                            ?: resolve.activityInfo.packageName
                        AppEntry(
                            label = label,
                            component = ComponentName(
                                resolve.activityInfo.packageName,
                                resolve.activityInfo.name,
                            ),
                            icon = bmp.asImageBitmap(),
                        )
                    }
                    .sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.label })
                    .toList()
            }
            _apps.value = loaded
        }
    }

    fun setGrid(rows: Int, cols: Int) {
        viewModelScope.launch {
            repository.setGrid(rows, cols)
        }
    }

    fun assignSlot(index: Int, entry: AppEntry?) {
        viewModelScope.launch {
            repository.setSlot(index, entry?.component?.flattenToString())
        }
    }

    private fun resolveEntrySync(pm: PackageManager, cn: ComponentName): AppEntry? {
        return try {
            val ai = pm.getActivityInfo(cn, PackageManager.MATCH_DEFAULT_ONLY)
            val iconDrawable = ai.loadIcon(pm)
            val bmp = iconDrawable.toBitmapSafely() ?: return null
            val label = ai.loadLabel(pm)?.toString() ?: cn.packageName
            AppEntry(
                label = label,
                component = cn,
                icon = bmp.asImageBitmap(),
            )
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
    }

    private fun android.graphics.drawable.Drawable.toBitmapSafely(): Bitmap? {
        val intrinsicWidth = intrinsicWidth.takeIf { it > 0 } ?: 1
        val intrinsicHeight = intrinsicHeight.takeIf { it > 0 } ?: 1
        val maxPx = 144
        val w = min(intrinsicWidth, maxPx)
        val h = min(intrinsicHeight, maxPx)
        return try {
            toBitmap(width = w, height = h)
        } catch (_: Exception) {
            null
        }
    }
}
