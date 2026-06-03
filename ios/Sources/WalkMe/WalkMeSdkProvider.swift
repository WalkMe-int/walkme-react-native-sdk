import WalkMe

/// Bridges `SdkProvider` calls to the standard `WalkMeSDK` entry point.
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
        WalkMeSDK.start(options: options)
    }

    static func stop()                                              { WalkMeSDK.stop() }
    static func startItem(byID id: Int, deepLink: String?)          { WalkMeSDK.startItem(byID: id, deepLink: deepLink) }
    static func dismissItem()                                       { WalkMeSDK.dismissItem() }
    static func setUserId(_ userId: String)                         { WalkMeSDK.setUserId(userId) }
    static func setVariable(key: String, value: Any)                { WalkMeSDK.setVariable(key: key, value: value) }
    static func setEventUserVars(_ vars: [String: String])          { WalkMeSDK.setEventUserVars(vars) }
    static func setLanguage(_ language: String)                     { WalkMeSDK.setLanguage(language) }
    static func sendEvent(name: String, attributes: [String: String]?) { WalkMeSDK.sendEvent(name: name, attributes: attributes) }
}
