package com.walkme.rn

import android.app.Activity
import android.app.Application
import android.util.Log
import com.facebook.react.bridge.ReadableMap
import com.walkme.api.WalkMeSdkApi
import com.walkme.api.WalkMeStartOptions
import com.walkme.pm.WalkmeSdkPowerMode

internal val sdkInstance: WalkMeSdkApi = WalkmeSdkPowerMode

/** Player-only start options don't exist in WalkMeEditor; warn instead of silently dropping them. */
internal fun applyFlavorOptions(startOptions: WalkMeStartOptions, options: ReadableMap) {
    if (options.hasKey("selfHostedUrl")) {
        Log.w("WalkMeSdk", "start: 'selfHostedUrl' is not supported in WalkMeEditor mode; ignoring")
    }
}

internal fun startSdk(options: WalkMeStartOptions, activity: Activity?, application: Application) {
    if (activity != null) {
        WalkmeSdkPowerMode.start(activity, options)
    } else {
        WalkmeSdkPowerMode.start(application, options)
    }
}
