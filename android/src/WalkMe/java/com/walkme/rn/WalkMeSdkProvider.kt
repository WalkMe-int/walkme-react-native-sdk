package com.walkme.rn

import android.app.Activity
import android.app.Application
import com.facebook.react.bridge.ReadableMap
import com.walkme.api.WalkMeSdkApi
import com.walkme.api.WalkMeStartOptions
import com.walkme.sdk.WalkMeSDK

internal val sdkInstance: WalkMeSdkApi = WalkMeSDK

/** Start options that exist only in the WalkMe player SDK. */
internal fun applyFlavorOptions(startOptions: WalkMeStartOptions, options: ReadableMap) {
    if (options.hasKey("selfHostedUrl")) options.getString("selfHostedUrl")?.let { startOptions.selfHostedUrl = it }
}

internal fun startSdk(options: WalkMeStartOptions, activity: Activity?, application: Application) {
    if (activity != null) {
        WalkMeSDK.start(activity, options)
    } else {
        WalkMeSDK.start(application, options)
    }
}
