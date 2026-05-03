package com.carlauncher.home

import android.content.ComponentName
import androidx.compose.ui.graphics.ImageBitmap

data class AppEntry(
    val label: String,
    val component: ComponentName,
    val icon: ImageBitmap,
)
