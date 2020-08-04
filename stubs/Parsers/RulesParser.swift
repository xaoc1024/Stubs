//
//  RulesParser.swift
//  stubs
//
//  Created by Andrii Zhuk on 30.07.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation


enum ParsingError: Error {
    case incorrectStructure(description: String)
}

enum JsonPathComponent {
    case key(String)
    case array

    static func pathComponents(from text: String) -> [JsonPathComponent] {
        return text.split(separator: "/")
            .filter { !$0.isEmpty }
            .compactMap {
                if $0 == ":" {
                    return .array
                } else {
                    return .key(String($0))
                }
        }
    }
}

enum Modification {
    case add(dic: [String : Any])
    case remove(keys: [String])
}

struct ModificationRule {
    let path: [String]
    let modification: [Modification]

    func ruleByRemovingTopPathComponent() -> ModificationRule {
        var newPath = path
        newPath.removeFirst()
        return ModificationRule(path: newPath, modification: modification)
    }
}

class RulesParser {
    private enum Constant {
        static let rulesKey = "rules"
        static let pathKey = "path"
        static let addKey = "add"
        static let removeKey = "remove"
    }

    private let fileManager = FileManager()

    func readRules(at rulesObject: [String: Any]) -> [ModificationRule] {
        do {
            return try parseRulesJson(rulesObject)
        } catch let error {
            printError("\(error)")
            abort()
        }
    }

    private func parseRulesJson(_ dic: [String: Any]) throws -> [ModificationRule] {
        guard let rulesObjects = dic[Constant.rulesKey] as? [[String: Any]], !rulesObjects.isEmpty  else {
            throw ParsingError.incorrectStructure(description: "Missing (or empty) \(Constant.rulesKey) in dic: \n \(dic)")
        }

        var rules: [ModificationRule]  = []

        for entry in rulesObjects {
            if let path = entry[Constant.pathKey] as? String {
                let pathComponents = path.split(separator: "/").filter { !$0.isEmpty }.compactMap { String($0) }

                var modifications = [Modification]()

                if let addDict = entry[Constant.addKey] as? [String: Any] {
                    modifications.append(.add(dic: addDict))
                }

                if let removeKeysArray = entry[Constant.removeKey] as? [String] {
                    modifications.append(.remove(keys: removeKeysArray))
                }

                if modifications.isEmpty {
                    throw ParsingError.incorrectStructure(description: "Missing \(Constant.addKey) and \(Constant.removeKey) in entry: \n \(entry)")
                }

                rules.append(ModificationRule(path: pathComponents, modification: modifications))
            }
        }

        return rules
    }
}
