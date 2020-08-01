//
//  main.swift
//  ChuckStubsAnalyzer
//
//  Created by Andrii Zhuk on 23.07.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation

enum ModificationParameters: String {
    case index = "-i"
    case stubs = "-s"
}

let commonErrorMessage =
"""
    Use -i to modify index file
    Use -s to modify stubs
"""

if CommandLine.argc < 2 {
    print("No parameters specified." + "\n" + commonErrorMessage)
    abort()
}

var parameters = Set<ModificationParameters>()

for i in 1..<Int(CommandLine.argc) {
    if let parameter = ModificationParameters(rawValue: CommandLine.arguments[i]) {
        parameters.insert(parameter)
    } else {
        print("Incorrect parameter \(CommandLine.arguments[i])" + "\n" + commonErrorMessage)
        abort()
    }
}

let executableFolderPathURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()

let stubsDirURL = executableFolderPathURL

let matherComponents = URLMatcher.readURLMatchingRulesFile(at: executableFolderPathURL)
let modificationRules = RulesParser().readRules(at: executableFolderPathURL)
let indexModificationRulesConfig = IndexFileModifier.readIndexFileModificationConfig(at: executableFolderPathURL)

let urlMatcher = URLMatcher(urlComponents: matherComponents)
let stubsModifier = StubsModifier(urlMatcher: urlMatcher, modificationRules: modificationRules)

let indexFileModifier = IndexFileModifier(urlMatcher: urlMatcher, configuration: indexModificationRulesConfig)

let indexFileFinder = IndexFilesFinder(stubsDirURL: stubsDirURL)
let indexFiles = indexFileFinder.findIndexFileURLs()

parameters.forEach { (parameter) in
    switch parameter {
    case .index:
        indexFileModifier.modifyIndexFile(at: indexFiles)
    case .stubs:
        stubsModifier.modifyStubsForIndexURLs(indexFiles)
    }
}
