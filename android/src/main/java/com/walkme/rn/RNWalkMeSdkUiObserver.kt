package com.walkme.rn

import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.UIManager
import com.facebook.react.bridge.UIManagerListener
import com.facebook.react.uimanager.UIManagerModule
import java.util.concurrent.atomic.AtomicBoolean

// TODO(WalkMe API): confirm the external-UI-listener interface names in com.walkme.api.
// The old native SDK exposed ABBI.WMExternalUiListener { setExternalDelegate(WMExternalUiDelegate) }
// and WMExternalUiDelegate { onExternalViewChanged() }. Update the two imports below and the
// `WMExternalUiListener` / `WMExternalUiDelegate` references once the new names are confirmed.
import com.walkme.api.WMExternalUiListener
import com.walkme.api.WMExternalUiDelegate

/**
 * Listens to React Native view-hierarchy updates (UIManager dispatches) and notifies the
 * WalkMe SDK that the visible UI changed. Relevant e.g. for stack navigation, where screen
 * transitions happen without a native Activity change.
 *
 * Port of RNWalkMeSDKUiManager from the legacy react-native-walkme-sdk.
 */
internal class RNWalkMeSdkUiObserver(
    private val reactContext: ReactApplicationContext,
) : UIManagerListener, WMExternalUiListener {

    companion object {
        private const val TAG = "WalkMeSDK"
        private const val DEBOUNCE_MS = 1000L
    }

    private val uiThreadHandler = Handler(Looper.getMainLooper())
    private val isViewChanged = AtomicBoolean(false)
    private var workerThread: HandlerThread? = null
    private var workerHandler: Handler? = null
    private var delegate: WMExternalUiDelegate? = null

    fun startObserving() {
        ensureWorker()
        uiThreadHandler.post {
            try {
                paperUiManager()?.addUIManagerEventListener(this)
            } catch (e: Exception) {
                Log.e(TAG, "failed to add UIManager event listener: ${e.message}")
            }
        }
    }

    fun stopObserving() {
        workerThread?.quitSafely()
        workerThread = null
        workerHandler = null
        uiThreadHandler.post {
            try {
                paperUiManager()?.removeUIManagerEventListener(this)
            } catch (e: Exception) {
                Log.e(TAG, "failed to remove UIManager event listener: ${e.message}")
            }
        }
    }

    // ── UIManagerListener ────────────────────────────────────────────────────
    // Paper (legacy arch) notifies via willDispatchViewUpdates (from onBatchComplete).
    // Fabric is intentionally not supported yet — the SDK's element capture and bridge
    // behavior require dedicated work before the new architecture can be supported.

    override fun willDispatchViewUpdates(uiManager: UIManager) = notifyViewChanged()

    override fun didMountItems(uiManager: UIManager) = Unit
    override fun didDispatchMountItems(uiManager: UIManager) = Unit
    override fun didScheduleMountItems(uiManager: UIManager) = Unit
    override fun willMountItems(uiManager: UIManager) = Unit

    private fun notifyViewChanged() {
        if (!isViewChanged.get()) {
            workerHandler?.postDelayed({
                try {
                    isViewChanged.set(false)
                    delegate?.onExternalViewChanged()
                } catch (e: Exception) {
                    Log.e(TAG, "failed to call onExternalViewChanged: ${e.message}")
                }
            }, DEBOUNCE_MS)
        }
        isViewChanged.set(true)
    }

    // ── WMExternalUiListener (WalkMe SDK injects its delegate here) ──────────

    override fun setExternalDelegate(delegate: WMExternalUiDelegate?) {
        this.delegate = delegate
    }

    // ── Internals ────────────────────────────────────────────────────────────

    private fun ensureWorker() {
        if (workerThread?.isAlive == true) return
        try {
            val thread = HandlerThread("RNWalkMeSdkUiObserver").also { it.start() }
            workerThread = thread
            workerHandler = Handler(thread.looper)
        } catch (e: Exception) {
            Log.e(TAG, "failed to start worker thread: ${e.message}")
        }
    }

    /** Returns the Paper (legacy architecture) UIManager, or null if unavailable. */
    private fun paperUiManager(): UIManagerModule? =
        reactContext.getNativeModule(UIManagerModule::class.java)
}
