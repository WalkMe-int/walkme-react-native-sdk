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

export interface WalkMeSdkInterface {
  /**
   * Start the WalkMe SDK.
   * Must be called before any other SDK method.
   */
  start(options: WalkMeStartOptions): void;

  /**
   * Stop the SDK and release associated resources.
   */
  stop(): void;

  /**
   * Start a specific WalkMe promotion by its numeric item ID.
   *
   * @param itemId   WalkMe item ID.
   * @param deepLink Optional deep-link URI to open before showing the item.
   */
  startItemByID(itemId: number, deepLink?: string | null): void;

  /**
   * Set the current end-user identifier. Pass `null` to clear.
   */
  setUserId(userId: string | null): void;

  /**
   * Set a custom segmentation variable. Pass `null` as value to clear.
   */
  setVariable(key: string, value: string | null): void;

  /**
   * Set well-known event user vars (name, role, type, status, info).
   */
  setEventUserVars(vars: WalkMeEventUserVars): void;

  /**
   * Set the display language for WalkMe content.
   * The value must match a language configured in the WalkMe console.
   */
  setLanguage(language: string): void;

  /**
   * Send a custom event to WalkMe.
   *
   * @param name       Event name.
   * @param attributes Optional key-value attributes for the event.
   */
  sendEvent(name: string, attributes?: Record<string, unknown> | null): void;
}

declare const WalkMeSDK: WalkMeSdkInterface;
export default WalkMeSDK;
