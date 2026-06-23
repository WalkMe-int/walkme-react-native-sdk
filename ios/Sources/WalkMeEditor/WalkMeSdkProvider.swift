import WalkMe
import WalkMeEditor

/// Bridges `SdkProvider` calls to the `WalkMePowerMode` entry point.
enum SdkProvider {

    static func start(optionsDict: NSDictionary) {
        guard let systemGuid = optionsDict["systemGuid"] as? String else {
            print("[WalkMeSdk] start: 'systemGuid' is required")
            return
        }
        let options = WalkMeStartOptions(systemGuid: systemGuid)
        if let env = optionsDict["environment"] as? String    { options.environment  = env }
        if let dc  = optionsDict["dataCenter"]  as? String    { options.dataCenter   = WalkMeDataCenter(dc) }
        if let on  = optionsDict["analyticsEnabled"] as? Bool { options.analyticMode = on ? .ON : .OFF }
        if let log = optionsDict["localLogsEnabled"] as? Bool { options.logsEnabled  = log }
        WalkMePowerMode.start(options: options)
    }

    static func stop()                                                  { WalkMePowerMode.stop() }
    static func restart()                                               { WalkMePowerMode.restart() }
    static func startItem(byID id: Int, deepLink: String?)              { WalkMePowerMode.startItem(byID: id, deepLink: deepLink) }
    static func dismissItem()                                           { WalkMePowerMode.dismissItem() }
    static func setUserId(_ userId: String)                             { WalkMePowerMode.setUserId(userId) }
    static func setVariable(key: String, value: Any)                    { WalkMePowerMode.setVariable(key: key, value: value) }
    static func setEventUserVars(_ vars: [String: String])              { WalkMePowerMode.setEventUserVars(vars) }
    static func setLanguage(_ language: String)                         { WalkMePowerMode.setLanguage(language) }
    static func sendEvent(name: String, attributes: [String: String]?)  { WalkMePowerMode.sendEvent(name: name, attributes: attributes) }
    static func setItemCallbacksDelegate(_ delegate: WMItemCallbacksDelegate?) { WalkMePowerMode.setItemCallbacksDelegate(delegate) }
    static func setAnalyticsHandler(_ handler: ((WMPublicAnalyticsDataInfo) -> Void)?) { WalkMePowerMode.setAnalyticsHandler(handler) }
}
