import Foundation
import React
import WalkMeEditor

@objc(RNWalkMeSdk)
class RNWalkMeSdkModule: RCTEventEmitter, WMItemCallbacksDelegate {

    override func supportedEvents() -> [String]! {
        return ["walkme_item_presented", "walkme_item_dismissed", "walkme_analytics_event"]
    }

    @objc func start(_ options: NSDictionary) {
        DispatchQueue.main.async {
            SdkProvider.start(optionsDict: options)
        }
    }

    @objc func stop() { SdkProvider.stop() }
    @objc func restart() { SdkProvider.restart() }

    @objc func startItemByID(_ itemId: NSNumber, deepLink: String?) {
        SdkProvider.startItem(byID: itemId.intValue, deepLink: deepLink)
    }

    @objc func dismissItem() { SdkProvider.dismissItem() }

    @objc func setUserId(_ userId: String?) {
        SdkProvider.setUserId(userId ?? "")
    }

    @objc func setVariable(_ key: String, value: String?) {
        SdkProvider.setVariable(key: key, value: value ?? "")
    }

    @objc func setEventUserVars(_ vars: NSDictionary) {
        let stringVars = (vars as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
        SdkProvider.setEventUserVars(stringVars)
    }

    @objc func setLanguage(_ language: String) {
        SdkProvider.setLanguage(language)
    }

    @objc func sendEvent(_ name: String, attributes: NSDictionary?) {
        let stringAttrs = (attributes as? [String: Any])?.compactMapValues { $0 as? String }
        SdkProvider.sendEvent(name: name, attributes: stringAttrs)
    }

    // Dispatched to main so this runs AFTER start()'s queued block on the same
    // serial queue. Otherwise this runs synchronously before start() and the
    // delegate is dropped when start() initializes the SDK.
    @objc func setItemInfoListener(_ enable: Bool) {
        DispatchQueue.main.async {
            SdkProvider.setItemCallbacksDelegate(enable ? self : nil)
        }
    }

    // Dispatched to main for the same reason as setItemInfoListener: it must run
    // after start() so the handler is attached to the initialized analytics
    // manager rather than being wiped by start().
    @objc func setAnalyticsListener(_ enable: Bool) {
        DispatchQueue.main.async { [weak self] in
            if enable {
                SdkProvider.setAnalyticsHandler { [weak self] info in
                    self?.sendEvent(withName: "walkme_analytics_event", body: [
                        "eventName": info.eventType.name,
                        "params": info.payloadString,
                    ])
                }
            } else {
                SdkProvider.setAnalyticsHandler(nil)
            }
        }
    }

    // MARK: – WMItemCallbacksDelegate

    func itemWillShow(_ itemInfo: WalkMeItemInfo) {
        sendEvent(withName: "walkme_item_presented", body: itemInfoBody(itemInfo))
    }

    func itemDidDismiss(_ itemInfo: WalkMeItemInfo) {
        sendEvent(withName: "walkme_item_dismissed", body: itemInfoBody(itemInfo))
    }

    private func itemInfoBody(_ info: WalkMeItemInfo) -> [String: Any] {
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
        return body
    }
}

// MARK: – WMPublicAnalyticsDataInfo helpers

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
