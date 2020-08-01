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
        static let modificationRulesFile = "/stubs_config/stubs_modification_rules.json"
    }

    let fileManager = FileManager()

    let urlMatcher: URLMatcher
    let modificationRules: [ModificationRule]

    init(urlMatcher: URLMatcher, modificationRules: [ModificationRule]) {
        self.urlMatcher = urlMatcher
        self.modificationRules = modificationRules
    }

    func modifyStubsForIndexURLs(_ indexURLs: [URL]) {
        print("Finding stubs to modify")

        let stubFilesURLs = indexURLs.compactMap { (indexFileURL) -> [URL] in
            return self.stubsFileURL(for: indexFileURL)
        }
        .flatMap { $0 }

        print("Found \(stubFilesURLs.count) stub files to be modified.")
        print("Start stubs modification")

        var modifiedCounter = 0
        stubFilesURLs.forEach { (stubsURL) in
            if let jsonObject = readStubFile(at: stubsURL) {
                do {
                    let modified = try modifyStubDictionary(jsonObject)
                    saveModified(modified, at: stubsURL)
                    modifiedCounter += 1
                } catch let error {
                    print("Did fail to modify stub at \(stubsURL.absoluteString)")
                    print(error)
                }
            }
        }

        print("\nModification has finished. Modified \(modifiedCounter) file(s)")
    }

    private func stubsFileURL(for indexFileUrl: URL) -> [URL] {
        guard let fileContent = fileManager.contents(atPath: indexFileUrl.path), let indexFile = String(bytes: fileContent, encoding: .utf8) else {
            return []
        }

        let lines = indexFile.split(separator: "\n")

        var stubsFilesUrls = [URL]()

        for line in lines {
            if let stubsURL = responseStubsURLOrNil(for: String(line), indexFileUrl: indexFileUrl) {
                stubsFilesUrls.append(stubsURL)
            }
        }

        return stubsFilesUrls
    }

    private func responseStubsURLOrNil(for line: String, indexFileUrl: URL) -> URL? {
        let nsLine = line as NSString
        let components = nsLine.components(separatedBy: ",\t")

        guard components.count == Constant.componentsCount, let matchingURL = URL(string: String(components[Constant.urlComponentIndex])) else {
            print("Incorrect line format \(line)")
            return nil
        }

        if self.urlMatcher.matchURL(matchingURL) {
            let currentFolderURL = indexFileUrl.deletingLastPathComponent()
            var stubsURL = currentFolderURL.appendingPathComponent(String(components[Constant.stubDirectoryComponentIndex]), isDirectory: true)
            stubsURL.appendPathComponent(Constant.respBodyFileName, isDirectory: false)

            return stubsURL
        }

        return nil
    }

    private func readStubFile(at url: URL) -> [String: Any]? {
        do {
            let fileContent = try Data(contentsOf: url)

            let object = try? JSONSerialization.jsonObject(with: fileContent, options: [])

            guard let dictionary = object as? [String: Any] else {
                print("ERROR: incorrect file structure, \(String(describing: String(bytes: fileContent, encoding: .utf8)))")
                return nil
            }

            return dictionary
        } catch let error {
            print(error)
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
                    throw ModificationError.incorectStructure(description: "Incorrect structure of json entry\n \(dict)\n Missing key \(currentKey)")
                }
                return dict as! T
            } else {
                // This shouldn't happen
                throw ModificationError.incorrectExecutionPath
            }
        } else {
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
                    }
                }

                return dict as! T
            } else if let array = object as? [[String : Any]] {
                let newArray = array.compactMap { (dict) -> [String : Any] in
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
                        }
                    }

                    return copy
                }

                return newArray as! T
            }
        }

        // This shouldn't happen
        throw ModificationError.incorrectExecutionPath
    }

    private func saveModified(_ modifiedDict: [String: Any], at url: URL) {
        do {
            let data = try JSONSerialization.data(withJSONObject: modifiedDict, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url)
            print("Did modify file at \(url.absoluteString)")
        } catch let error {
            print(error)
        }
    }
}
