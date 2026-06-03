import { NativeModules } from 'react-native';

const { RNWalkMeSdk } = NativeModules;

if (!RNWalkMeSdk) {
  console.warn(
    '[@walkme/react-native-sdk] Native module not found. ' +
      'Make sure you have linked the library and rebuilt the app.',
  );
}

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

  /**
   * Start a specific item by its numeric ID.
   * @param {number} itemId
   * @param {string} [deepLink] - optional deep-link to open first
   */
  startItemByID(itemId, deepLink) {
    RNWalkMeSdk.startItemByID(itemId, deepLink ?? null);
  },

  /**
   * Set the current user ID. Pass null to clear.
   * @param {string|null} userId
   */
  setUserId(userId) {
    RNWalkMeSdk.setUserId(userId ?? null);
  },

  /**
   * Set a custom segmentation variable. Pass null as value to clear.
   * @param {string}      key
   * @param {string|null} value
   */
  setVariable(key, value) {
    RNWalkMeSdk.setVariable(key, value ?? null);
  },

  /**
   * Set well-known event user vars.
   * @param {{ name?: string, role?: string, type?: string, status?: string, info?: string }} vars
   */
  setEventUserVars(vars) {
    RNWalkMeSdk.setEventUserVars(vars);
  },

  /**
   * Set the display language for WalkMe content.
   * @param {string} language
   */
  setLanguage(language) {
    RNWalkMeSdk.setLanguage(language);
  },

  /**
   * Send a custom event to WalkMe.
   * @param {string} name
   * @param {object} [attributes] - optional key-value event attributes
   */
  sendEvent(name, attributes) {
    RNWalkMeSdk.sendEvent(name, attributes ?? null);
  },
};

export default WalkMeSDK;
