export interface WalkMeStartOptions {
  /** WalkMe system GUID (required). */
  systemGuid: string;
  /** Environment name, e.g. `"Production"`. Defaults to `"Production"`. */
  environment?: string;
  /**
   * Data center region.
   * Built-in values: `"prod"` | `"eu"` | `"us01"` | `"eu01"`.
   * Any other string is treated as a custom data center.
   * Defaults to `"prod"`.
   */
  dataCenter?: string;
  /** Whether analytics events are sent. Defaults to `true`. */
  analyticsEnabled?: boolean;
  /** Whether local (device) logs are enabled. Defaults to `false`. */
  localLogsEnabled?: boolean;
}

/** Well-known keys for `setEventUserVars`. */
export interface WalkMeEventUserVars {
  name?: string;
  role?: string;
  type?: string;
  status?: string;
  info?: string;
}

// ── Item-info types ──────────────────────────────────────────────────────────

/**
 * User/device context included in item-info events.
 *
 * Android fields: userAttributesMap, sessionDuration, deviceVersion, deviceId,
 *   deviceModel, deviceOrientation, appVersion, appName, locale, sdkVer,
 *   sessionId, isNewUser, timezone, network, systemName, timestamp
 *
 * iOS fields: userId, osVersion, appVersion, appName, bundleId, network,
 *   timezone, deviceModel, locale, countryCode
 */
export interface WMUserData {
  // Android
  userAttributesMap?: Record<string, unknown>;
  sessionDuration?: number;
  deviceVersion?: string;
  deviceId?: string;
  deviceModel?: string;
  deviceOrientation?: string;
  appVersion?: string;
  appName?: string;
  locale?: string;
  sdkVer?: string;
  sessionId?: string;
  isNewUser?: string;
  timezone?: string;
  network?: string;
  systemName?: string;
  timestamp?: string;
  // iOS
  userId?: string;
  osVersion?: string;
  bundleId?: string;
  countryCode?: string;
}

/**
 * Item context passed to item-info listener callbacks.
 *
 * - `itemId`   — `number` on iOS, `string` on Android
 * - `itemType` — iOS only
 * - `action`   — iOS only
 * - `itemActionType` — Android only
 * - `args`     — Android only, present in `onItemAction` callbacks
 */
export interface WMItemInfo {
  itemId: string | number;
  itemType?: string;
  action?: string;
  itemActionType?: string;
  userData: WMUserData;
  args?: Record<string, string>;
}

/** Analytics event payload. */
export interface WMAnalyticsEvent {
  /**
   * Event type name, e.g. `"play"`, `"click"`, `"activity"`.
   */
  eventName: string;
  /** Full event payload serialized as a JSON string. */
  params: string;
}

/** Callbacks for `setItemInfoListener`. All callbacks are optional. */
export interface WMItemInfoListener {
  onItemPresented?: (itemInfo: WMItemInfo) => void;
  onItemDismissed?: (itemInfo: WMItemInfo) => void;
  /** Android only. */
  onItemAction?: (itemInfo: WMItemInfo) => void;
}

export interface WalkMeSdkInterface {
  /**
   * Start the WalkMe SDK.
   * Must be called before any other SDK method.
   */
  start(options: WalkMeStartOptions): void;

  /** Stop the SDK and release associated resources. */
  stop(): void;

  /** Restart the SDK with the same options as the last `start()` call. */
  restart(): void;

  /**
   * Start a specific WalkMe promotion by its numeric item ID.
   * @param itemId   WalkMe item ID.
   * @param deepLink Optional deep-link URI.
   */
  startItemByID(itemId: number, deepLink?: string | null): void;

  /** Dismiss the currently active WalkMe item. */
  dismissItem(): void;

  /** Set the current end-user identifier. Pass `null` to clear. */
  setUserId(userId: string | null): void;

  /** Set a custom segmentation variable. Pass `null` as value to clear. */
  setVariable(key: string, value: string | null): void;

  /** Set well-known event user vars (name, role, type, status, info). */
  setEventUserVars(vars: WalkMeEventUserVars): void;

  /**
   * Set the display language for WalkMe content.
   * The value must match a language configured in the WalkMe console.
   */
  setLanguage(language: string): void;

  /**
   * Send a custom event to WalkMe.
   * @param name       Event name.
   * @param attributes Optional key-value attributes.
   */
  sendEvent(name: string, attributes?: Record<string, unknown> | null): void;

  /**
   * Register or clear the item-info listener.
   * Pass a listener object to enable; pass `null` to clear.
   *
   * @example
   * WalkMeSDK.setItemInfoListener({
   *   onItemPresented: (info) => console.log('shown', info.itemId),
   *   onItemDismissed: (info) => console.log('dismissed', info.itemId),
   * });
   * // later:
   * WalkMeSDK.setItemInfoListener(null);
   */
  setItemInfoListener(listener: WMItemInfoListener | null): void;

  /**
   * Register or clear the analytics listener.
   * Pass a callback to enable; pass `null` to clear.
   *
   * @example
   * WalkMeSDK.setAnalyticsListener((event) => console.log(event.eventName));
   * // later:
   * WalkMeSDK.setAnalyticsListener(null);
   */
  setAnalyticsListener(listener: ((event: WMAnalyticsEvent) => void) | null): void;
}

declare const WalkMeSDK: WalkMeSdkInterface;
export default WalkMeSDK;
