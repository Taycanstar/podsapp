import Foundation
import AVFoundation

class VideoCacheManager: NSObject, AVAssetResourceLoaderDelegate {
    static let shared = VideoCacheManager()
    private let cacheDirectory: URL

    override init() {
        let tempDir = NSTemporaryDirectory()
        self.cacheDirectory = URL(fileURLWithPath: tempDir).appendingPathComponent("VideoCache")
        super.init()
        createCacheDirectory()
    }

    private func createCacheDirectory() {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating cache directory: \(error)")
        }
    }

    func cachedURL(for originalURL: URL) -> URL {
        let cacheKey = originalURL.absoluteString.replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appendingPathComponent(cacheKey)
    }

    func clearCache() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path)
            for file in contents {
                let fileURL = cacheDirectory.appendingPathComponent(file)
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("Error clearing cache: \(error)")
        }
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let url = loadingRequest.request.url else { return false }

        let cachedURL = cachedURL(for: url)
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            fulfillRequest(loadingRequest, with: cachedURL)
            return true
        }

        return false
    }

    private func fulfillRequest(_ loadingRequest: AVAssetResourceLoadingRequest, with cachedURL: URL) {
        do {
            let data = try Data(contentsOf: cachedURL)
            loadingRequest.dataRequest?.respond(with: data)
            loadingRequest.finishLoading()
        } catch {
            loadingRequest.finishLoading(with: error)
        }
    }
}


