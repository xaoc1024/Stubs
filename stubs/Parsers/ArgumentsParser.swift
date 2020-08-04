//
//  ArgumentsParser.swift
//  stubs
//
//  Created by Andrii Zhuk on 03.08.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation

class ArgumentsParser {
    enum ModificationOption: String {
        case index = "-i"
        case stubs = "-s"
    }

    struct Arguments {
        let modificationOption: ModificationOption
        let configurationFileURL: URL
        let stubsFolderURL: URL
    }

    private let commonErrorMessage =
    """
        Use -i to modify index file
        Use -s to modify stubs
        For all options specify next paths: `ConfigurationFile` and `StubsPath`.
    """

    private func usage() {
        printError(commonErrorMessage)
    }

    let fileManager = FileManager()

    func parse(arguments: [String]) -> Arguments {
        guard arguments.count == 4 else {
            usage()
            abort()
        }

        let executableFolderPathURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()

        let modificationOption: ModificationOption
        let configurationFileArgument: String
        let stubsFolderArgument: String

        if let option = ModificationOption(rawValue: CommandLine.arguments[1]) {
            modificationOption = option
            configurationFileArgument =  CommandLine.arguments[2]
            stubsFolderArgument = CommandLine.arguments[3]
        } else {
            usage()
            abort()
        }

        guard let configurationFileURL = actualFilePath(for: configurationFileArgument, using: executableFolderPathURL, isDirectory: false),
            let stubsFolderURL = actualFilePath(for: stubsFolderArgument, using: executableFolderPathURL, isDirectory: true) else {
            abort()
        }

        return Arguments(modificationOption: modificationOption,
                         configurationFileURL: configurationFileURL,
                         stubsFolderURL: stubsFolderURL)
    }

    private func actualFilePath(for pathArgument: String, using executableFolderPathURL: URL, isDirectory: Bool) -> URL? {
        let relativePath = executableFolderPathURL.appendingPathComponent(pathArgument).absoluteString
        if fileManager.fileExists(atPath: relativePath) {
            return URL(fileURLWithPath: relativePath, isDirectory: isDirectory)
        } else if fileManager.fileExists(atPath: pathArgument) {
            return URL(fileURLWithPath: pathArgument, isDirectory: isDirectory)
        } else {
            printError("File doesn't exist at path \(pathArgument)")
            return nil
        }
    }
}
