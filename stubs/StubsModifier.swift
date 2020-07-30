//
//  StubsModifier.swift
//  ChuckStubsAnalyzer
//
//  Created by Andrii Zhuk on 27.07.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation

class StubsModifier {
    struct Configuration {
        let structureMatchingKeys: [String]
        let addDictionary: [String: Any]
        let removeKeys: [String]
    }
    
    private enum Constant {
        static let componentsCount = 5
        static let urlComponentIndex = 4
        static let stubDirectoryComponentIndex = 2
        static let respBodyFileName = "resp_body.json"
        static let modificationRulesFile = "/stubs_config/stubs_modification_rules.json"
    }

    let fileManager = FileManager()

    let urlMatcher: URLMatcher
    let configuration: Configuration

    init(urlMatcher: URLMatcher, configuration: Configuration) {
        self.urlMatcher = urlMatcher
        self.configuration = configuration
    }

    func modifyStubsForIndexURLs(_ indexURLs: [URL]) {
        print("Started modifying stubs")
        for url in indexURLs {
            readIndexFile(indexFileUrl: url)
        }
    }

    private func readIndexFile(indexFileUrl: URL) {
        guard let fileContent = fileManager.contents(atPath: indexFileUrl.path), let indexFile = String(bytes: fileContent, encoding: .utf8) else {
            return
        }

        let lines = indexFile.split(separator: "\n")

        for line in lines {
            if let stubsURL = responseStubsURLOrNil(for: String(line), indexFileUrl: indexFileUrl) {
                modifyStubsForURL(at: stubsURL)
            }
        }
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

    private func modifyStubsForURL(at url: URL) {
        guard let fileContent = fileManager.contents(atPath: url.path) else {
            print("ERROR: cannot read file at url: \(url)")
            return
        }

        let object = try? JSONSerialization.jsonObject(with: fileContent, options: [])

        guard let dictionary = object as? [String: Any] else {
            print("ERROR: incorrect file structure, \(String(describing: String(bytes: fileContent, encoding: .utf8)))")
            return
        }

        for expectedKey in configuration.structureMatchingKeys {
            if dictionary[expectedKey] == nil {
                print("WARNING: file at url \(url) has different structure")
                return
            }
        }

        var copy = dictionary

        copy.merge(configuration.addDictionary) { (value1, value2) -> Any in
            return value1
        }

        for key in configuration.removeKeys {
            copy[key] = nil
        }

        if copy.keys != dictionary.keys {
            do {
                let data = try JSONSerialization.data(withJSONObject: copy, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: url)
                print("Did modify file at \(url)")
            } catch let error {
                print(error)
            }
        }
    }
}

extension StubsModifier {
    static func readStubsModificationConfig(at executableFolderURL: URL) -> StubsModifier.Configuration {
        let modifyFileURL = executableFolderURL.appendingPathComponent(Constant.modificationRulesFile, isDirectory: false)

        do {
            let modifyFileData = try Data(contentsOf: modifyFileURL)
            let object = try JSONSerialization.jsonObject(with: modifyFileData, options: [])

            guard let dictionary = object as? [String: Any] else {
                print("Incorrect structure of modify.json file")
                abort()
            }

            let structureMatchingKeys: [String] = dictionary["match"] as? [String] ?? []
            let addDictionary: [String : Any] = dictionary["add"] as? [String : Any] ?? [:]
            let removeKeys: [String] = dictionary["remove"] as? [String] ?? []

            if addDictionary.isEmpty && removeKeys.isEmpty {
                print("Need to have at least one modification rule")
                abort()
            } else {
                return .init(structureMatchingKeys: structureMatchingKeys, addDictionary: addDictionary, removeKeys: removeKeys)
            }
        } catch let error {
            print(error)
            fatalError()
        }
    }
}
