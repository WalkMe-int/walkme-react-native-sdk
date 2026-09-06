package com.walkmeexample

import android.app.Application
import com.facebook.react.PackageList
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.ReactNativeApplicationEntryPoint.loadReactNative
import com.facebook.react.defaults.DefaultReactHost.getDefaultReactHost

class MainApplication : Application(), ReactApplication {

  override val reactHost: ReactHost by lazy {
    getDefaultReactHost(
      context = applicationContext,
      packageList =
        PackageList(this).packages.apply {
          // Packages that cannot be autolinked yet can be added manually here, for example:
          // add(MyReactNativePackage())
        },
      // false unless the build was run with -PuseDevServer=true, so the APK
      // never depends on a Metro server running on the developer's machine.
      useDevSupport = BuildConfig.USE_DEV_SERVER,
    )
  }

  override fun onCreate() {
    super.onCreate()
    loadReactNative(this)
  }
}
