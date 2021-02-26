//
//  IndexFilesModifier.swift
//  ChuckStubsAnalyzer
//
//  Created by Andrii Zhuk on 28.07.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation

class IndexFileModifier {
    struct ModificationRules {
        let addDictionary: [String: Any]
        let removeQueryKeys: [String]
        let shouldRemoveLine: Bool
    }

    private enum Constant {
        static let componentsCount = 5
        static let urlComponentIndex = 4
    }

    let fileManager = FileManager()

    let indexRecordsMatcher: IndexRecordsFinder
    let indexFileParser: IndexFileParser
    let modificationRules: ModificationRules

    init(indexRecordsMatcher: IndexRecordsFinder, indexFileParser: IndexFileParser, modificationRulesObject: [String: Any]) {
        self.indexRecordsMatcher = indexRecordsMatcher
        self.indexFileParser = indexFileParser

        let addDictionary: [String : Any] = modificationRulesObject["add"] as? [String : Any] ?? [:]
        let removeQueryKeys: [String] = modificationRulesObject["remove"] as? [String] ?? []
        let shouldRemoveLine: Bool? = modificationRulesObject["shouldRemoveLine"] as? Bool

        if addDictionary.isEmpty && removeQueryKeys.isEmpty && (shouldRemoveLine != true) {
            fatalError("Need to have at least one modification rule in object\n\(modificationRulesObject)")
        } else {
            self.modificationRules = .init(addDictionary: addDictionary, removeQueryKeys: removeQueryKeys, shouldRemoveLine: shouldRemoveLine ?? false)
        }
    }

    func modifyIndexFile(at indexURLs: [URL]) {
        printInfo("Started modifying index.txt files")
        var counter = 0
        for url in indexURLs {
            autoreleasepool {
                if self.readAndModifyIndexFile(indexFileUrl: url) {
                    counter += 1
                }
            }
        }

        printInfo("Did modify \(counter) files")
    }

    private func readAndModifyIndexFile(indexFileUrl: URL) -> Bool {
        guard let fileContent = fileManager.contents(atPath: indexFileUrl.path), let indexFile = String(bytes: fileContent, encoding: .utf8) else {
            return false
        }

        let lines = indexFile.split(separator: "\n")
        var wasModified = false
        let modifiedLines: [String] = lines.compactMap {
            if self.matchesRule(String($0)) {
                wasModified = true
                if self.modificationRules.shouldRemoveLine {
                    self.removeDataForLine(String($0), indexFileUrl: indexFileUrl)
                    return nil
                }
                else {
                    return self.modifyLine(String($0))
                }
            }

            return String($0)
        }

        if wasModified {
            var newIndexFileString = modifiedLines.joined(separator: "\n")
            newIndexFileString += "\n"

            let data = newIndexFileString.data(using: .utf8)
            do {
                try data?.write(to: indexFileUrl)
                printInfo("Did modify index file at \(indexFileUrl.absoluteString)")
                return true
            } catch let error {
                printError("Error during savind modified index file")
                printError("\(error)")
                return false
            }
        }

        return wasModified
    }

    private func matchesRule(_ originalLine: String) -> Bool {
        guard let record = indexFileParser.parseIndexRecord(from: originalLine) else {
            printError("Incorrect line format: \(originalLine)")
            return false
        }

        return indexRecordsMatcher.isRecordMatchingParameters(record: record)
    }

    func removeDataForLine(_ originalLine: String, indexFileUrl: URL) {
        guard let record = indexFileParser.parseIndexRecord(from: originalLine) else {
            printError("Incorrect line format: \(originalLine)")
            return
        }

        let indexFileFolderURL = indexFileUrl.deletingLastPathComponent()
        let stubsFolderURL = indexFileFolderURL.appendingPathComponent(record.stubsFolder, isDirectory: true)
        do {
            try fileManager.removeItem(at: stubsFolderURL)
            printInfo("Removed data at path: \(stubsFolderURL)")
        } catch let error {
            printError("Wasn't able to remove folder at URL: \(stubsFolderURL.absoluteString)\nGot an error: \(error)")
        }

    }

    func modifyLine(_ originalLine: String) -> String {
        let nsLine = originalLine as NSString
        let lineComponents = nsLine.components(separatedBy: ",\t")

        guard lineComponents.count == Constant.componentsCount, let matchingURL = URL(string: String(lineComponents[Constant.urlComponentIndex])) else {
            printError("ERROR: Incorrect line format: \(originalLine)")
            return originalLine
        }

        guard var urlComponents = URLComponents(url: matchingURL, resolvingAgainstBaseURL: false) else {
            printError("ERROR: Incorrect url format: \(matchingURL)")
            return originalLine
        }

        var queryItems = urlComponents.queryItems ?? []

        for key in modificationRules.removeQueryKeys {
            if let removeIndex = queryItems.firstIndex(where: { (item) -> Bool in
                item.name == key
            }) {
                queryItems.remove(at: removeIndex)
            }
        }

        for (key, value) in modificationRules.addDictionary {
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
            printError("ERROR: Wasn't able to create url from components: \(urlComponents)")
            return originalLine
        }

        var newComponents = lineComponents.compactMap { String($0) }
        newComponents[Constant.urlComponentIndex] = modifiedURL.absoluteString

        return newComponents.joined(separator: ",\t")
    }
}
