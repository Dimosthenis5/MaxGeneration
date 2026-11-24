import UIKit

/// Weekly progress photos, saved as JPEGs in the app's private Documents/photos folder.
enum PhotoStore {
    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = docs.appendingPathComponent("photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Shrinks the photo to max 1600px and saves it. Returns the file name.
    static func save(_ data: Data, name: String) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let resized = resize(image, maxSide: 1600)
        guard let jpeg = resized.jpegData(compressionQuality: 0.82) else { return nil }
        let file = "\(name)-\(Int(Date().timeIntervalSince1970)).jpg"
        do {
            try jpeg.write(to: folder.appendingPathComponent(file), options: [.atomic])
            return file
        } catch {
            return nil
        }
    }

    static func load(_ file: String) -> UIImage? {
        UIImage(contentsOfFile: folder.appendingPathComponent(file).path)
    }

    static func delete(_ file: String) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(file))
    }

    private static func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

extension Store {
    func setWeekPhoto(_ data: Data, week: Date) {
        guard let file = PhotoStore.save(data, name: "week-\(weekKey(week))") else { return }
        let old = weekLog(week).photoFile
        updateWeekLog(week) { log in log.photoFile = file }
        if let old = old, old != file { PhotoStore.delete(old) }
        award(10, .discipline, "Progress photo 📸", key: "photo:\(weekKey(week))")
    }

    func removeWeekPhoto(week: Date) {
        if let old = weekLog(week).photoFile { PhotoStore.delete(old) }
        updateWeekLog(week) { log in log.photoFile = nil }
    }

    var progressPhotos: [WeekSummary] {
        data.weekLogs
            .filter { $0.value.photoFile != nil }
            .compactMap { pair -> WeekSummary? in
                guard let d = Day.date(from: pair.key) else { return nil }
                return WeekSummary(id: pair.key, start: d, log: pair.value)
            }
            .sorted { $0.start < $1.start }
    }
}
