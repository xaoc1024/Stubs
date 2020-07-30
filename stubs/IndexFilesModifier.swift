//
//  IndexFilesModifier.swift
//  ChuckStubsAnalyzer
//
//  Created by Andrii Zhuk on 28.07.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation

class IndexFileModifier {
    struct Configuration {
        let addDictionary: [String: Any]
        let removeQueryKeys: [String]
    }

    private enum Constant {
        static let componentsCount = 5
        static let urlComponentIndex = 4
        static let modificationRulesFile = "/stubs_config/index_modification_rules.json"
    }

    let fileManager = FileManager()

    let urlMatcher: URLMatcher
    let configuration: Configuration

    init(urlMatcher: URLMatcher, configuration: Configuration) {
        self.urlMatcher = urlMatcher
        self.configuration = configuration
    }

    func modifyIndexFile(at indexURLs: [URL]) {
        print("Started modifying index.txt files")
        for url in indexURLs {
            readIndexFile(indexFileUrl: url)
        }
    }

    private func readIndexFile(indexFileUrl: URL) {
        guard let fileContent = fileManager.contents(atPath: indexFileUrl.path), let indexFile = String(bytes: fileContent, encoding: .utf8) else {
            return
        }

        let lines = indexFile.split(separator: "\n")
        var wasModified = false
        let modifiedLines: [String] = lines.compactMap {
            if self.matchesRule(String($0)) {
                wasModified = true
                return self.modifyLine(String($0))
            }

            return String($0)
        }

        if wasModified {
            var newIndexFileString = modifiedLines.joined(separator: "\n")
            newIndexFileString += "\n"

            let data = newIndexFileString.data(using: .utf8)
            do {
                try data?.write(to: indexFileUrl)
            } catch let error {
                print("Error during savind modified index file")
                print(error)
            }
        }
    }

    private func matchesRule(_ originalLine: String) -> Bool {
        let nsLine = originalLine as NSString
        let components = nsLine.components(separatedBy: ",\t")

        guard components.count == Constant.componentsCount, let matchingURL = URL(string: String(components[Constant.urlComponentIndex])) else {
            print("Incorrect line format: \(originalLine)")
            return false
        }

        return urlMatcher.matchURL(matchingURL)
    }

    func modifyLine(_ originalLine: String) -> String {
        let nsLine = originalLine as NSString
        let components = nsLine.components(separatedBy: ",\t")

        guard components.count == Constant.componentsCount, let matchingURL = URL(string: String(components[Constant.urlComponentIndex])) else {
            print("Incorrect line format: \(originalLine)")
            return originalLine
        }

        guard var urlComponents = URLComponents(url: matchingURL, resolvingAgainstBaseURL: false) else {
            print("Incorrect url format: \(matchingURL)")
            return originalLine
        }

        var queryItems = urlComponents.queryItems ?? []

        for key in configuration.removeQueryKeys {
            if let removeIndex = queryItems.firstIndex(where: { (item) -> Bool in
                item.name == key
            }) {
                queryItems.remove(at: removeIndex)
            }
        }

        for (key, value) in configuration.addDictionary {
            // Remove key if it is present before adding it again
            if let removeIndex = queryItems.firstIndex(where: { (item) -> Bool in
                item.name == key
            }) {
                queryItems.remove(at: removeIndex)
            }

            queryItems.append(URLQueryItem(name: key, value: String(describing: value)))
        }

        urlComponents.queryItems = queryItems
        guard let modifiedURL = urlComponents.url else {
            print("ERROR: Wasn't able to create url from components: \(urlComponents)")
            return originalLine
        }

        var newComponents = components.compactMap { String($0) }
        newComponents[Constant.urlComponentIndex] = modifiedURL.absoluteString

        return newComponents.joined(separator: ",\t")
    }
}

extension IndexFileModifier {
    static func readIndexFileModificationConfig(at executableFolderURL: URL) -> IndexFileModifier.Configuration {
        let modifyFileURL = executableFolderURL.appendingPathComponent(Constant.modificationRulesFile, isDirectory: false)

        do {
            let modifyFileData = try Data(contentsOf: modifyFileURL)
            let object = try JSONSerialization.jsonObject(with: modifyFileData, options: [])

            guard let dictionary = object as? [String: Any] else {
                print("Incorrect structure of modify.json file")
                abort()
            }

            let addDictionary: [String : Any] = dictionary["add"] as? [String : Any] ?? [:]
            let removeQueryKeys: [String] = dictionary["remove"] as? [String] ?? []

            if addDictionary.isEmpty && removeQueryKeys.isEmpty {
                print("Need to have at least one modification rule")
                abort()
            } else {
                return .init(addDictionary: addDictionary, removeQueryKeys: removeQueryKeys)
            }
        } catch let error {
            print(error)
            fatalError()
        }
    }
}
