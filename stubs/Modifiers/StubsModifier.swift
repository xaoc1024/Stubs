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
                        let modified = try modifyStub(jsonObject)
                        saveModified(modified, at: stubsURL)
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
                printError("ERROR: incorrect file structure, \(String(describing: String(bytes: fileContent, encoding: .utf8)))")
                return nil
            }

            return dictionary
        } catch let error {
            printError("\(error)")
        }

        return nil
    }

    private func modifyStub(_ dictionary: [String: Any]) throws -> [String: Any] {
        var copy = dictionary

        for rule in modificationRules {
            copy = try applyRule(rule, object: copy)
        }

        return copy
    }

    private func applyRule<T>(_ rule: ModificationRule, object: T) throws -> T {
        if let currentKey = rule.path.first {
            if var dict = object as? [String: Any] {
                if let dictEntry = dict[currentKey] as? [String: Any] {
                    let modifiedEntry = try applyRule(rule.ruleByRemovingTopPathComponent(), object: dictEntry)
                    dict[currentKey] = modifiedEntry
                } else if let arrayEntry = dict[currentKey] as? [[String: Any]] {
                    let newArray = try arrayEntry.compactMap {
                        try applyRule(rule.ruleByRemovingTopPathComponent(), object: $0)
                    }
                    dict[currentKey] = newArray
                } else {
                    // return not modified entry. Do not interupt this process, as probably the next entry will have appropriate structure.
                    // This case is possible for offer response, where `facetValues` array has different structure for different facets.
                    return dict as! T
                }
                return dict as! T
            } else {
                // This shouldn't happen
                throw ModificationError.incorrectExecutionPath
            }
        } else {
            if let dict = object as? [String: Any] {
                return modifyDictionary(dict, using: rule.modification) as! T
            } else if let array = object as? [[String : Any]] {
                return modifyArray(array, using: rule.modification) as! T
            }
        }

        // This shouldn't happen
        throw ModificationError.incorrectExecutionPath
    }

    private func modifyDictionary(_ dict: [String: Any], using modifications: [Modification]) -> [String: Any] {
        var copy = dict
        for modification in modifications {
            switch modification {
            case .add(let addDict):
                copy.merge(addDict) { (value1, value2) -> Any in
                    return value2
                }

            case .remove(let keys):
                for key in keys {
                    copy[key] = nil
                }
            }
        }

        return copy
    }

    private func modifyArray(_ array: [[String: Any]], using modifications: [Modification]) -> [[String: Any]] {
        return array.compactMap { (dict) -> [String : Any] in
            return modifyDictionary(dict, using: modifications)
        }
    }

    private func saveModified(_ modifiedDict: [String: Any], at url: URL) {
        do {
            let data = try JSONSerialization.data(withJSONObject: modifiedDict, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url)
            printInfo("Did modify file at \(url.absoluteString)")
        } catch let error {
            printError("\(error)")
        }
    }
}
