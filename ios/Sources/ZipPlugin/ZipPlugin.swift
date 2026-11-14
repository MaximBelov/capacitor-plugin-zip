import Foundation
import Capacitor

@objc(ZipPlugin)
public class ZipPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ZipPlugin"
    public let jsName = "Zip"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "unzip", returnType: CAPPluginReturnPromise)
    ]

    @objc func unzip(_ call: CAPPluginCall) {
        let destinationArg = call.getString("destination")
        let overwrite = call.getBool("overwrite", true)
        let source: URL
        let destination: URL
        do {
            source = try Unzipper.resolve(call.getString("source"), name: "source")
            destination = try Unzipper.resolve(destinationArg, name: "destination")
        } catch let error as UnzipError {
            call.reject(error.message, error.code)
            return
        } catch {
            call.reject(error.localizedDescription, "INVALID_ARGUMENT")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let count = try Unzipper.unzip(source: source, destination: destination, overwrite: overwrite) { loaded, total in
                    self?.notifyListeners("progress", data: [
                        "destination": destinationArg ?? "",
                        "loaded": loaded,
                        "total": total
                    ])
                }
                call.resolve(["entries": count])
            } catch let error as UnzipError {
                call.reject(error.message, error.code)
            } catch {
                call.reject("Could not unzip \(source.path): \(error.localizedDescription)", "IO", error)
            }
        }
    }
}
