package com.carlauncher.car_launcher.embedding

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class VirtualDisplayAppViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        return VirtualDisplayAppView(
            context = context,
            paneId = (params?.get("paneId") as? Number)?.toInt() ?: viewId,
            packageName = params?.get("packageName") as? String,
            zOrderOnTop = params?.get("zOrderOnTop") as? Boolean ?: false,
        )
    }
}
