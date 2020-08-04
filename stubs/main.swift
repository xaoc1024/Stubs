//
//  main.swift
//  ChuckStubsAnalyzer
//
//  Created by Andrii Zhuk on 23.07.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation

func printError(_ error: String) {
    print("\u{001B}[0;31m\(error)")
}

func printInfo(_ info: String) {
    print("\u{001B}[0;0m\(info)")
}

let arguments = ArgumentsParser().parse(arguments: CommandLine.arguments)

let configurationFile = ConfigurationFile(configurationFileURL: arguments.configurationFileURL)

let indexRecordsFinder = IndexRecordsFinder(indexSearchParametersObject: configurationFile.indexSearchParameters)
let indexFilesFinder = IndexFilesFinder(stubsDirURL: arguments.stubsFolderURL)

let indexFiles = indexFilesFinder.findIndexFileURLs()
printInfo("Found \(indexFiles.count) index files.")

let indexFileParser = IndexFileParser()

if !indexFiles.isEmpty {
    switch arguments.modificationOption {
    case .index:
        let indexFileModifier = IndexFileModifier(indexRecordsMatcher: indexRecordsFinder, indexFileParser: indexFileParser, modificationRulesObject: configurationFile.indexModificationRules)
        indexFileModifier.modifyIndexFile(at: indexFiles)

    case .stubs:
        let modificationRules = RulesParser().readRules(at: configurationFile.stubsModificationRules)
        let stubsModifier = StubsModifier(indexRecordsMatcher: indexRecordsFinder, indexFileParser: indexFileParser, modificationRules: modificationRules)
        stubsModifier.modifyStubsForIndexURLs(indexFiles)
    }
}
