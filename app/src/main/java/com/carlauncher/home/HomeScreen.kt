package com.carlauncher.home

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.carlauncher.R
import com.carlauncher.split.SplitPairLauncher

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel,
    modifier: Modifier = Modifier,
) {
    val appsState by viewModel.apps.collectAsStateWithLifecycle()
    val layout by viewModel.layout.collectAsStateWithLifecycle()
    val slots by viewModel.slotEntries.collectAsStateWithLifecycle()
    val context = LocalContext.current

    var pickerSlot by remember { mutableIntStateOf(-1) }
    var showAllApps by remember { mutableStateOf(false) }
    var gridMenuExpanded by remember { mutableStateOf(false) }

    val pickerVisible = pickerSlot >= 0
    val pickSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val allAppsSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(text = stringResource(R.string.home_title)) },
                actions = {
                    IconButton(onClick = { showAllApps = true }) {
                        Icon(
                            imageVector = Icons.Filled.Apps,
                            contentDescription = stringResource(R.string.cd_all_apps),
                        )
                    }
                    Box {
                        IconButton(onClick = { gridMenuExpanded = true }) {
                            Icon(
                                imageVector = Icons.Filled.GridView,
                                contentDescription = stringResource(R.string.cd_choose_layout),
                            )
                        }
                        DropdownMenu(
                            expanded = gridMenuExpanded,
                            onDismissRequest = { gridMenuExpanded = false },
                        ) {
                            GridPresets.all.forEach { (rows, cols, labelRes) ->
                                DropdownMenuItem(
                                    text = { Text(stringResource(labelRes)) },
                                    onClick = {
                                        viewModel.setGrid(rows, cols)
                                        gridMenuExpanded = false
                                    },
                                )
                            }
                        }
                    }
                },
            )
        },
    ) { padding ->
        when (val list = appsState) {
            null -> Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }
            else -> if (list.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(R.string.home_empty),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                val rows = layout.rows
                val cols = layout.cols
                val slotCount = rows * cols
                val isDualPanel = slotCount == 2
                val s0 = slots.getOrNull(0)
                val s1 = slots.getOrNull(1)
                val bothFilled = isDualPanel && s0 != null && s1 != null

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .padding(horizontal = 8.dp, vertical = 8.dp),
                ) {
                    if (isDualPanel) {
                        Row(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            ZoneTile(
                                modifier = Modifier
                                    .weight(1f)
                                    .fillMaxHeight(),
                                entry = s0,
                                onPrimary = {
                                    when {
                                        s0 == null -> pickerSlot = 0
                                        s1 == null -> context.startActivitySafe(s0)
                                        else -> SplitPairLauncher.launch(context, s0, s1)
                                    }
                                },
                                onLong = { pickerSlot = 0 },
                            )
                            ZoneTile(
                                modifier = Modifier
                                    .weight(1f)
                                    .fillMaxHeight(),
                                entry = s1,
                                onPrimary = {
                                    when {
                                        s1 == null -> pickerSlot = 1
                                        s0 == null -> context.startActivitySafe(s1)
                                        else -> SplitPairLauncher.launch(context, s0, s1)
                                    }
                                },
                                onLong = { pickerSlot = 1 },
                            )
                        }
                        if (bothFilled) {
                            Button(
                                onClick = { SplitPairLauncher.launch(context, s0!!, s1!!) },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 10.dp),
                            ) {
                                Text(stringResource(R.string.split_run_both))
                            }
                        }
                    } else {
                        for (r in 0 until rows) {
                            Row(
                                modifier = Modifier
                                    .weight(1f)
                                    .fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                for (c in 0 until cols) {
                                    val index = r * cols + c
                                    val entry = slots.getOrNull(index)
                                    ZoneTile(
                                        modifier = Modifier
                                            .weight(1f)
                                            .fillMaxHeight(),
                                        entry = entry,
                                        onPrimary = {
                                            if (entry == null) {
                                                pickerSlot = index
                                            } else {
                                                context.startActivitySafe(entry)
                                            }
                                        },
                                        onLong = { pickerSlot = index },
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    val resolvedApps = appsState
    if (pickerVisible && resolvedApps != null) {
        ModalBottomSheet(
            onDismissRequest = { pickerSlot = -1 },
            sheetState = pickSheetState,
        ) {
            Text(
                text = stringResource(R.string.sheet_pick_app),
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
            )
            LazyColumn {
                items(
                    items = resolvedApps,
                    key = { "${it.component.packageName}/${it.component.className}" },
                ) { app ->
                    ListItem(
                        headlineContent = {
                            Text(app.label, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        },
                        leadingContent = {
                            Image(
                                bitmap = app.icon,
                                contentDescription = app.label,
                                modifier = Modifier.size(40.dp),
                            )
                        },
                        modifier = Modifier.clickable {
                            viewModel.assignSlot(pickerSlot, app)
                            pickerSlot = -1
                        },
                    )
                }
                item {
                    TextButton(
                        onClick = {
                            viewModel.assignSlot(pickerSlot, null)
                            pickerSlot = -1
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                    ) {
                        Text(stringResource(R.string.slot_clear))
                    }
                }
            }
            Spacer(modifier = Modifier.height(24.dp))
        }
    }

    if (showAllApps && resolvedApps != null) {
        ModalBottomSheet(
            onDismissRequest = { showAllApps = false },
            sheetState = allAppsSheetState,
        ) {
            Text(
                text = stringResource(R.string.sheet_all_apps),
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
            )
            LazyColumn {
                items(
                    items = resolvedApps,
                    key = { "${it.component.packageName}/${it.component.className}" },
                ) { app ->
                    ListItem(
                        headlineContent = {
                            Text(app.label, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        },
                        leadingContent = {
                            Image(
                                bitmap = app.icon,
                                contentDescription = app.label,
                                modifier = Modifier.size(40.dp),
                            )
                        },
                        modifier = Modifier.clickable {
                            context.startActivitySafe(app)
                            showAllApps = false
                        },
                    )
                }
            }
            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ZoneTile(
    entry: AppEntry?,
    onPrimary: () -> Unit,
    onLong: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        when (entry) {
            null -> Box(
                modifier = Modifier
                    .fillMaxSize()
                    .combinedClickable(
                        onClick = onPrimary,
                        onLongClick = onLong,
                    )
                    .padding(12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = stringResource(R.string.zone_add_app),
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            else -> Column(
                modifier = Modifier
                    .fillMaxSize()
                    .combinedClickable(
                        onClick = onPrimary,
                        onLongClick = onLong,
                    )
                    .padding(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Image(
                    bitmap = entry.icon,
                    contentDescription = stringResource(R.string.cd_launch_app),
                    modifier = Modifier.size(56.dp),
                )
                Text(
                    text = entry.label,
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
        }
    }
}

private fun Context.startActivitySafe(entry: AppEntry) {
    val intent = Intent(Intent.ACTION_MAIN).apply {
        addCategory(Intent.CATEGORY_LAUNCHER)
        component = entry.component
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
    }
    try {
        startActivity(intent)
    } catch (_: Exception) {
        // App có thể không còn hoặc bị chặn trên ROM
    }
}
