package com.walkme.rn

import android.app.Activity
import android.app.Application
import com.walkme.api.WalkMeSdkApi
import com.walkme.api.WalkMeStartOptions
import com.walkme.sdk.WalkMeSDK

internal val sdkInstance: WalkMeSdkApi = WalkMeSDK

internal fun startSdk(options: WalkMeStartOptions, activity: Activity?, application: Application) {
    if (activity != null) {
        WalkMeSDK.start(activity, options)
    } else {
        WalkMeSDK.start(application, options)
    }
}
