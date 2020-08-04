//
//  IndexRecordParser.swift
//  stubs
//
//  Created by Andrii Zhuk on 03.08.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation

enum Focus: String {
    case focued = "F"
    case notFocused = "N"
}

enum HTTPMethod: String, Codable {
    case GET
    case HEAD
    case POST
    case PUT
    case DELETE
    case CONNECT
    case OPTIONS
    case TRACE
    case PATCH
}

struct IndexRecord {
    let focus: Focus
    let statusCode: Int
    let stubsFolder: String
    let httpMethod: HTTPMethod
    let url: URL
}

class IndexFileParser {
    private enum Constant {
        static let focusIndex = 0
        static let statusCodeIndex = 1
        static let stubDirectoryIndex = 2
        static let httpMethodIndex = 3
        static let urlIndex = 4
        static let componentsCount = 5
    }

    private let fileManager: FileManager = FileManager()

    func indexRecords(from indexFileURL: URL) -> [IndexRecord] {
        guard let fileContent = fileManager.contents(atPath: indexFileURL.path), let indexFile = String(bytes: fileContent, encoding: .utf8) else {
            printError("Cannot open index file at: \(indexFileURL.absoluteString)")
            return []
        }

        let recordLines = indexFile.split(separator: "\n").compactMap { String($0) }

        var indexRecords = [IndexRecord]()

        for recordLine in recordLines {
            if let record = parseIndexRecord(from: recordLine) {
                indexRecords.append(record)
            }
        }

        return indexRecords
    }

    func parseIndexRecord(from recordLine: String) -> IndexRecord? {
        let nsRecordText = recordLine as NSString
        let components = nsRecordText.components(separatedBy: ",\t")

        if components.count == Constant.componentsCount,
            let focus = Focus(rawValue: components[Constant.focusIndex]),
            let statusCode = Int(components[Constant.statusCodeIndex]),
            let httpMethod = HTTPMethod(rawValue: components[Constant.httpMethodIndex]),
            let url = URL(string: String(components[Constant.urlIndex])) {

            let stubFolder = components[Constant.stubDirectoryIndex]
            let record = IndexRecord(focus: focus,
                                      statusCode: statusCode,
                                      stubsFolder: stubFolder,
                                      httpMethod: httpMethod,
                                      url: url)
            return record
        } else {
            printError("Incorrect line format \(recordLine)")
        }

        return nil
    }
}
