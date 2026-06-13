import AppKit

@MainActor
final class ClipboardImageCache {
    static let shared = ClipboardImageCache()

    /// 全尺寸图片缓存（详情面板用），容量小
    private let detailCache: NSCache<NSUUID, NSImage>

    /// 缩略图缓存（列表行用），容量大
    private let thumbnailCache: NSCache<NSUUID, NSImage>

    private init() {
        detailCache = NSCache()
        detailCache.countLimit = 5
        detailCache.totalCostLimit = 50 * 1024 * 1024  // 50 MB

        thumbnailCache = NSCache()
        thumbnailCache.countLimit = 200
    }

    /// 获取详情面板全尺寸图片，未命中时通过 loader 加载
    func detailImage(for entryID: UUID, loader: () -> NSImage?) -> NSImage? {
        let key = entryID as NSUUID
        if let cached = detailCache.object(forKey: key) {
            return cached
        }
        guard let image = loader() else { return nil }
        let cost = estimateImageCost(image)
        detailCache.setObject(image, forKey: key, cost: cost)
        return image
    }

    /// 获取列表行缩略图，未命中时从 data 创建
    func thumbnailImage(for entryID: UUID, data: Data?) -> NSImage? {
        let key = entryID as NSUUID
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        guard let data, let image = NSImage(data: data) else { return nil }
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    func clearAll() {
        detailCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }

    private func estimateImageCost(_ image: NSImage) -> Int {
        guard let rep = image.representations.first else { return 0 }
        return rep.pixelsWide * rep.pixelsHigh * 4
    }
}
