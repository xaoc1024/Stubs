//
//  StubsModifier.swift
//  ChuckStubsAnalyzer
//
//  Created by Andrii Zhuk on 27.07.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation

enum ModificationError: Error {
    case incorectStructure(description: String)
    case incorrectExecutionPath
}

class StubsModifier {

    private enum Constant {
        static let componentsCount = 5
        static let urlComponentIndex = 4
        static let stubDirectoryComponentIndex = 2
        static let respBodyFileName = "resp_body.json"
    }

    let fileManager = FileManager()

    let indexRecordsMatcher: IndexRecordsFinder
    let indexFileParser: IndexFileParser
    let modificationRules: [ModificationRule]

    init(indexRecordsMatcher: IndexRecordsFinder, indexFileParser: IndexFileParser, modificationRules: [ModificationRule]) {
        self.indexRecordsMatcher = indexRecordsMatcher
        self.modificationRules = modificationRules
        self.indexFileParser = indexFileParser
    }

    func modifyStubsForIndexURLs(_ indexURLs: [URL]) {
        printInfo("Finding stubs to modify")


        let stubFilesURLs = indexURLs.compactMap { (indexFileURL) -> [URL] in
            autoreleasepool {
                return self.stubsFileURLs(for: indexFileURL)
            }
        }
        .flatMap { $0 }

        printInfo("Found \(stubFilesURLs.count) stub files to be modified.")
        printInfo("Start stubs modification")

        var modifiedCounter = 0
        stubFilesURLs.forEach { (stubsURL) in
            autoreleasepool {
                if let jsonObject = readStubFile(at: stubsURL) {
                    do {
                        let modified = try modifyStubDictionary(jsonObject)
                        saveModifiedStubDictionary(modified, at: stubsURL)
                        modifiedCounter += 1
                    } catch let error {
                        printError("Did fail to modify stub at \(stubsURL.absoluteString)")
                        print(error)
                    }
                }
            }
        }

        printInfo("\nModification has finished. Modified \(modifiedCounter) file(s)")
    }

    private func stubsFileURLs(for indexFileUrl: URL) -> [URL] {
        let records = indexFileParser.indexRecords(from: indexFileUrl)

        let indexFileFolderURL = indexFileUrl.deletingLastPathComponent()

        let stubsFilesUrls = records.filter { (record) -> Bool in
            return indexRecordsMatcher.isRecordMatchingParameters(record: record)
        }
        .compactMap { (record) -> URL in
            var stubsURL = indexFileFolderURL.appendingPathComponent(record.stubsFolder, isDirectory: true)
            stubsURL.appendPathComponent(Constant.respBodyFileName, isDirectory: false)
            return stubsURL
        }

        return stubsFilesUrls
    }

    private func readStubFile(at url: URL) -> [String: Any]? {
        do {
            let fileContent = try Data(contentsOf: url)

            let object = try? JSONSerialization.jsonObject(with: fileContent, options: [])

            guard let dictionary = object as? [String: Any] else {
                printError("Incorrect file structure, \(String(describing: String(bytes: fileContent, encoding: .utf8)))")
                return nil
            }

            return dictionary
        } catch let error {
            printError("\(error)")
        }

        return nil
    }


    private func modifyStubDictionary(_ dictionary: [String: Any]) throws -> [String: Any] {
        var copy = dictionary

        for rule in modificationRules {
            copy = try applyRule(rule, object: copy)
        }

        return copy
    }

    private func applyRule<T>(_ rule: ModificationRule, object: T) throws -> T {
        // Traverse and apply rules recursively until the subject key to modify has been discovered.
        if let currentKey = rule.path.first {
            guard var dict = object as? [String: Any] else {
                throw ModificationError.incorrectExecutionPath
            }

            if let dictEntry = dict[currentKey] as? [String: Any] {
                let modifiedEntry = try applyRule(rule.ruleByRemovingTopPathComponent(), object: dictEntry)
                dict[currentKey] = modifiedEntry
            } else if let arrayEntry = dict[currentKey] as? [[String: Any]] {
                let newArray = try arrayEntry.compactMap {
                    try applyRule(rule.ruleByRemovingTopPathComponent(), object: $0)
                }
                dict[currentKey] = newArray
            } else {
                // Return the entry unmodified. Do not interrupt this process as the next entry may have an appropriate structure.
                // This is possible for `Offer` responses, where the `facetValues` array has a different structure for different facets.
            }

            return dict as! T
        }

        // Replace the data structure
        if var dict = object as? [String: Any] {
            for modification in rule.modification {
                switch modification {
                case .add(let addDict):
                    dict.merge(addDict) { (value1, value2) -> Any in
                        return value2
                    }

                case .remove(let keys):
                    for key in keys {
                        dict[key] = nil
                    }

                case .transform(let script):
                    if let object = try? executeScript(script, json: dict) as? [String: Any] {
                        dict = object
                    }
                    else {
                        printError("Failed to transform dictionary for rule: \(rule.printablePath)")
                    }
                }
            }

            return dict as! T
        } else if let array = object as? [[String: Any]] {
            let newArray = array.compactMap { (dict) -> [String: Any] in
                var copy = dict

                for modification in rule.modification {
                    switch modification {
                    case .add(let addDict):
                        copy.merge(addDict) { (value1, value2) -> Any in
                            return value2
                        }

                    case .remove(let keys):
                        for key in keys {
                            copy[key] = nil
                        }

                    case .transform(let script):
                        if let object = try? executeScript(script, json: dict) as? [String: Any] {
                            return object
                        }
                        else {
                            printError("Failed to transform dictionary for rule: \(rule.printablePath)")
                        }
                    }
                }

                return copy
            }

            return newArray as! T
        }

        throw ModificationError.incorrectExecutionPath
    }

    private func executeScript(_ script: String, json: [String: Any]) throws -> Any {
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        let jsonB64 = jsonData.base64EncodedString()
        let newJson = Process.launch(command: script, arguments: [jsonB64])
        let newJsonObject = try JSONSerialization.jsonObject(with: newJson.data(using: .utf8)!, options: [])
        return newJsonObject
    }

    private func saveModifiedStubDictionary(_ modifiedDict: [String: Any], at url: URL) {
        do {
            let data = try JSONSerialization.data(withJSONObject: modifiedDict, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url)
            printInfo("Modified file at \(url.absoluteString)")
        } catch let error {
            printError("Failed to modify file \(url.absoluteString) with error: \(error)")
        }
    }
}
