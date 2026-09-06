import Foundation

// The two WalkMe iOS SDK distributions are mutually exclusive: they ship
// overlapping Objective-C classes, so exactly one is linked per build. Which one
// is decided at `pod install` time by `walkme.walkmeMode` in the consuming app's
// package.json (see walkme-react-native-sdk.podspec), which also passes
// `-DWALKME_EDITOR` to Swift for the Power Mode flavor. This mirrors the Android
// `walkmeMode` product flavor exactly.
#if WALKME_EDITOR
import WalkMeEditor
private typealias WalkMeEntryPoint = WalkMePowerMode
#else
import WalkMe
private typealias WalkMeEntryPoint = WalkMeSDK
#endif

/// Architecture-agnostic WalkMe adapter for iOS.
///
/// This is the exact counterpart of Android's `WalkMeSdkBridge`: it owns all of
/// the WalkMe SDK interaction and all payload mapping, and exposes a purely
/// Foundation-typed, `@objc` surface. No WalkMe type crosses this boundary,
/// which is what lets the single Objective-C++ module (`RNWalkMeSdk.mm`) serve
/// both the Legacy Architecture and the New Architecture without duplicating
/// any behavior — and without either architecture needing to know which WalkMe
/// flavor was linked.
@objc(WMRNSdkProvider)
public final class WMRNSdkProvider: NSObject {

    // MARK: - Lifecycle

    @objc(start:)
    public static func start(_ optionsDict: NSDictionary) {
        guard let systemGuid = optionsDict["systemGuid"] as? String else {
            print("[WalkMeSdk] start: 'systemGuid' is required")
            return
        }
        let options = WalkMeStartOptions(systemGuid: systemGuid)
        if let env = optionsDict["environment"] as? String    { options.environment  = env }
        if let dc  = optionsDict["dataCenter"]  as? String    { options.dataCenter   = WalkMeDataCenter(dc) }
        if let on  = optionsDict["analyticsEnabled"] as? Bool { options.analyticMode = on ? .ON : .OFF }
        if let log = optionsDict["localLogsEnabled"] as? Bool { options.logsEnabled  = log }
        WalkMeEntryPoint.start(options: options)
    }

    @objc(stop)
    public static func stop() { WalkMeEntryPoint.stop() }

    @objc(restart)
    public static func restart() { WalkMeEntryPoint.restart() }

    // MARK: - Items

    @objc(startItemByID:deepLink:)
    public static func startItem(byID id: Int, deepLink: String?) {
        WalkMeEntryPoint.startItem(byID: id, deepLink: deepLink)
    }

    @objc(dismissItem)
    public static func dismissItem() { WalkMeEntryPoint.dismissItem() }

    // MARK: - User / content

    @objc(setUserId:)
    public static func setUserId(_ userId: String?) {
        WalkMeEntryPoint.setUserId(userId ?? "")
    }

    @objc(setVariable:value:)
    public static func setVariable(_ key: String, value: String?) {
        WalkMeEntryPoint.setVariable(key: key, value: value ?? "")
    }

    @objc(setEventUserVars:)
    public static func setEventUserVars(_ vars: NSDictionary) {
        let stringVars = (vars as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
        WalkMeEntryPoint.setEventUserVars(stringVars)
    }

    @objc(setLanguage:)
    public static func setLanguage(_ language: String) {
        WalkMeEntryPoint.setLanguage(language)
    }

    @objc(sendEvent:attributes:)
    public static func sendEvent(_ name: String, attributes: NSDictionary?) {
        let stringAttrs = (attributes as? [String: Any])?.compactMapValues { $0 as? String }
        WalkMeEntryPoint.sendEvent(name: name, attributes: stringAttrs)
    }

    // MARK: - Callbacks

    /// Retained for the lifetime of the subscription: `setItemCallbacksDelegate`
    /// does not keep the delegate alive on its own, and the module that asked
    /// for the callbacks is not a `WMItemCallbacksDelegate` any more (it is an
    /// Objective-C++ class that knows nothing about WalkMe types).
    private static var itemCallbacksProxy: ItemCallbacksProxy?

    /// - Parameter handler: called with the JS event name and its body, or
    ///   `nil` to detach. Event names and payload shapes are unchanged from
    ///   previous releases.
    @objc(setItemInfoHandler:)
    public static func setItemInfoHandler(_ handler: ((String, NSDictionary) -> Void)?) {
        guard let handler = handler else {
            WalkMeEntryPoint.setItemCallbacksDelegate(nil)
            itemCallbacksProxy = nil
            return
        }
        let proxy = ItemCallbacksProxy(handler: handler)
        itemCallbacksProxy = proxy
        WalkMeEntryPoint.setItemCallbacksDelegate(proxy)
    }

    @objc(setAnalyticsHandler:)
    public static func setAnalyticsHandler(_ handler: ((NSDictionary) -> Void)?) {
        guard let handler = handler else {
            WalkMeEntryPoint.setAnalyticsHandler(nil)
            return
        }
        WalkMeEntryPoint.setAnalyticsHandler { info in
            handler([
                "eventName": info.eventType.name,
                "params": info.payloadString,
            ] as NSDictionary)
        }
    }
}

// MARK: - WMItemCallbacksDelegate

private final class ItemCallbacksProxy: NSObject, WMItemCallbacksDelegate {

    private let handler: (String, NSDictionary) -> Void

    init(handler: @escaping (String, NSDictionary) -> Void) {
        self.handler = handler
    }

    func itemWillShow(_ itemInfo: WalkMeItemInfo) {
        handler("walkme_item_presented", ItemCallbacksProxy.body(itemInfo))
    }

    func itemDidDismiss(_ itemInfo: WalkMeItemInfo) {
        handler("walkme_item_dismissed", ItemCallbacksProxy.body(itemInfo))
    }

    private static func body(_ info: WalkMeItemInfo) -> NSDictionary {
        var body: [String: Any] = [
            "itemId": info.itemId,
            "itemType": info.itemType,
            "userData": [
                "userId":      info.userData.userId,
                "osVersion":   info.userData.osVersion,
                "appVersion":  info.userData.appVersion,
                "appName":     info.userData.appName,
                "bundleId":    info.userData.bundleId,
                "network":     info.userData.network,
                "timezone":    info.userData.timezone,
                "deviceModel": info.userData.deviceModel,
                "locale":      info.userData.locale,
                "countryCode": info.userData.countryCode,
            ],
        ]
        if let action = info.action { body["action"] = action }
        return body as NSDictionary
    }
}

// MARK: - WMPublicAnalyticsDataInfo helpers

private extension WMPublicEventType {
    var name: String {
        switch self {
        case .play:           return "play"
        case .click:          return "click"
        case .close:          return "close"
        case .sessionStarted: return "sessionStarted"
        case .engagedElement: return "engagedElement"
        case .changeLanguage: return "changeLanguage"
        case .activity:       return "activity"
        case .pageChange:     return "pageChange"
        case .na:             return "na"
        @unknown default:     return "na"
        }
    }
}

private extension WMPublicAnalyticsDataInfo {
    var payloadString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str  = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}
