import Foundation

enum AppResources {
    private static let sourceResourcesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Resources")

    private static let resourceBundles: [Bundle] = {
        let bundleNames = [
            "masko-code_masko-code",
            "masko_code_masko-code",
            "masko_code_masko_code"
        ]

        var searchDirectories: [URL] = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL
        ].compactMap { $0 }

        if let executableURL = Bundle.main.executableURL {
            let buildDirectory = executableURL.deletingLastPathComponent()

            searchDirectories.append(buildDirectory)
        }

        searchDirectories.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))

        return searchDirectories.flatMap { directory in
            bundleNames.compactMap { bundleName in
                Bundle(url: directory.appendingPathComponent("\(bundleName).bundle"))
            }
        }
    }()

    static func url(forResource name: String, withExtension fileExtension: String?, subdirectory: String? = nil) -> URL? {
        let bundledURLs = resourceBundles.flatMap { bundle in
            bundle.urls(forResourcesWithExtension: fileExtension, subdirectory: subdirectory)?
                .filter { $0.deletingPathExtension().lastPathComponent == name } ?? []
        }

        if let url = bundledURLs.first {
            return url
        }

        if let url = Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: subdirectory) {
            return url
        }

        var directURL = sourceResourcesURL
        if let subdirectory {
            directURL.appendPathComponent(subdirectory)
        }

        let url = fileExtension.map { fileExtension in
            directURL
                .appendingPathComponent(name)
                .appendingPathExtension(fileExtension)
        } ?? directURL.appendingPathComponent(name)

        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
