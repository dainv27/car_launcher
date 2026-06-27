package com.carlauncher.car_launcher.embedding

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class EmbeddedAppPaneFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val paneId = (params?.get("paneId") as? Number)?.toInt() ?: viewId
        val packageName = params?.get("packageName") as? String
        return EmbeddedAppPaneView(context, paneId, packageName)
    }
}
