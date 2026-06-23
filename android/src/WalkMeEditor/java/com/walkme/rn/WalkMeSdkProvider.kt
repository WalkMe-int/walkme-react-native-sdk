package com.walkme.rn

import android.app.Activity
import android.app.Application
import com.walkme.api.WalkMeSdkApi
import com.walkme.api.WalkMeStartOptions
import com.walkme.pm.WalkmeSdkPowerMode

internal val sdkInstance: WalkMeSdkApi = WalkmeSdkPowerMode

internal fun startSdk(options: WalkMeStartOptions, activity: Activity?, application: Application) {
    if (activity != null) {
        WalkmeSdkPowerMode.start(activity, options)
    } else {
        WalkmeSdkPowerMode.start(application, options)
    }
}
