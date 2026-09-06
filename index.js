import { NativeEventEmitter, TurboModuleRegistry } from 'react-native';

/**
 * Resolve the native module in a way that works on every React Native
 * architecture.
 *
 * `TurboModuleRegistry.get()` asks the TurboModule proxy first (New
 * Architecture / Bridgeless) and transparently falls back to `NativeModules`
 * (Legacy Architecture). It returns `null` — rather than throwing, the way
 * `getEnforcing()` does — when the module is absent, which preserves this
 * package's historical "warn once, then no-op on listener setters" behavior.
 *
 * The module name and its method signatures are declared once, for Codegen, in
 * `src/NativeWalkMeSdk.ts`. That spec is what generates the TurboModule
 * interfaces both native implementations conform to; keep the two in sync.
 */
const RNWalkMeSdk = TurboModuleRegistry.get('RNWalkMeSdk');

if (!RNWalkMeSdk) {
  console.warn(
    '[@walkme-mobile/react-native-sdk] Native module not found. ' +
      'Make sure you have linked the library and rebuilt the app.',
  );
}

const emitter = RNWalkMeSdk ? new NativeEventEmitter(RNWalkMeSdk) : null;

// Subscriptions managed internally so the customer gets the same
// set/clear API as the native SDK.
let _itemInfoSubs = [];
let _analyticsSub = null;

const WalkMeSDK = {
  /**
   * Start the WalkMe SDK.
   * @param {object}  options
   * @param {string}  options.systemGuid         - WalkMe system GUID (required)
   * @param {string}  [options.environment]      - e.g. "Production" (default)
   * @param {string}  [options.dataCenter]       - "prod" | "eu" | "us01" | "eu01" | custom (default "prod")
   * @param {boolean} [options.analyticsEnabled] - default true
   * @param {boolean} [options.localLogsEnabled] - default false
   */
  start(options) {
    RNWalkMeSdk.start(options);
  },

  stop() {
    RNWalkMeSdk.stop();
  },

  restart() {
    RNWalkMeSdk.restart();
  },

  /**
   * Start a specific item by its numeric ID.
   * @param {number} itemId
   * @param {string} [deepLink]
   */
  startItemByID(itemId, deepLink) {
    RNWalkMeSdk.startItemByID(itemId, deepLink ?? null);
  },

  dismissItem() {
    RNWalkMeSdk.dismissItem();
  },

  /** @param {string|null} userId */
  setUserId(userId) {
    RNWalkMeSdk.setUserId(userId ?? null);
  },

  /** @param {string} key  @param {string|null} value */
  setVariable(key, value) {
    RNWalkMeSdk.setVariable(key, value ?? null);
  },

  /** @param {{ name?, role?, type?, status?, info? }} vars */
  setEventUserVars(vars) {
    RNWalkMeSdk.setEventUserVars(vars);
  },

  /** @param {string} language */
  setLanguage(language) {
    RNWalkMeSdk.setLanguage(language);
  },

  /**
   * @param {string} name
   * @param {object} [attributes]
   */
  sendEvent(name, attributes) {
    RNWalkMeSdk.sendEvent(name, attributes ?? null);
  },

  /**
   * Register or clear the item-info listener.
   *
   * Pass an object with optional callbacks to enable; pass `null` to clear.
   *
   * @param {{ onItemPresented?, onItemDismissed?, onItemAction? } | null} listener
   */
  setItemInfoListener(listener) {
    if (!RNWalkMeSdk) return;

    // Remove any previous subscriptions
    _itemInfoSubs.forEach(s => s.remove());
    _itemInfoSubs = [];

    const hasCallback = listener && (
      listener.onItemPresented || listener.onItemDismissed || listener.onItemAction
    );

    if (!hasCallback) {
      RNWalkMeSdk.setItemInfoListener(false);
      return;
    }

    RNWalkMeSdk.setItemInfoListener(true);
    if (listener.onItemPresented) {
      _itemInfoSubs.push(emitter.addListener('walkme_item_presented', listener.onItemPresented));
    }
    if (listener.onItemDismissed) {
      _itemInfoSubs.push(emitter.addListener('walkme_item_dismissed', listener.onItemDismissed));
    }
    if (listener.onItemAction) {
      _itemInfoSubs.push(emitter.addListener('walkme_item_action', listener.onItemAction));
    }
  },

  /**
   * Register or clear the analytics listener.
   *
   * Pass a callback to enable; pass `null` to clear.
   *
   * @param {((event: { eventName: string, params: string }) => void) | null} listener
   */
  setAnalyticsListener(listener) {
    if (!RNWalkMeSdk) return;

    if (_analyticsSub) {
      _analyticsSub.remove();
      _analyticsSub = null;
    }

    if (!listener) {
      RNWalkMeSdk.setAnalyticsListener(false);
      return;
    }

    RNWalkMeSdk.setAnalyticsListener(true);
    _analyticsSub = emitter.addListener('walkme_analytics_event', listener);
  },
};

export default WalkMeSDK;
