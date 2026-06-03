import Foundation

@objc(RNWalkMeSdk)
class RNWalkMeSdkModule: NSObject {

    @objc func start(_ options: NSDictionary) {
        DispatchQueue.main.async {
            SdkProvider.start(optionsDict: options)
        }
    }

    @objc func stop() {
        SdkProvider.stop()
    }

    @objc func startItemByID(_ itemId: NSNumber, deepLink: String?) {
        SdkProvider.startItem(byID: itemId.intValue, deepLink: deepLink)
    }

    @objc func dismissItem() {
        SdkProvider.dismissItem()
    }

    @objc func setUserId(_ userId: String?) {
        SdkProvider.setUserId(userId ?? "")
    }

    @objc func setVariable(_ key: String, value: String?) {
        SdkProvider.setVariable(key: key, value: value ?? "")
    }

    @objc func setEventUserVars(_ vars: NSDictionary) {
        let stringVars = vars.compactMapValues { $0 as? String }
        SdkProvider.setEventUserVars(stringVars)
    }

    @objc func setLanguage(_ language: String) {
        SdkProvider.setLanguage(language)
    }

    @objc func sendEvent(_ name: String, attributes: NSDictionary?) {
        let stringAttrs = attributes?.compactMapValues { $0 as? String }
        SdkProvider.sendEvent(name: name, attributes: stringAttrs)
    }
}
