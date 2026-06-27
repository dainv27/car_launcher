package com.carlauncher.car_launcher

import android.service.notification.NotificationListenerService

/**
 * NotificationListener service required for MediaSessionManager.getActiveSessions()
 * to work. This service needs to be declared in AndroidManifest.xml and the user
 * must grant notification access permission in Settings.
 */
class NotificationListener : NotificationListenerService() {
    // Empty implementation — we only need the service to be registered
    // for MediaSessionManager.getActiveSessions() to return sessions.
}
