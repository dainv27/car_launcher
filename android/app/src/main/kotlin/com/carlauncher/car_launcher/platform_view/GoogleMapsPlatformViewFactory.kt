package com.carlauncher.car_launcher.platform_view

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class GoogleMapsPlatformViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(
        context: Context,
        viewId: Int,
        args: Any?,
    ): PlatformView {
        val params = args as? Map<*, *>
        val packageName = params?.get("packageName") as? String
        val autoLaunchFullscreenFallback = params?.get("autoLaunchFullscreenFallback") as? Boolean ?: false
        val fallbackMode = params?.get("fallbackMode") as? String ?: "web"

        return GoogleMapsPlatformView(
            context = context,
            packageName = packageName,
            autoLaunchFullscreenFallback = autoLaunchFullscreenFallback,
            fallbackMode = fallbackMode,
        )
    }
}
