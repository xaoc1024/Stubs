//
//  URLMatcher.swift
//  ChuckStubsAnalyzer
//
//  Created by Andrii Zhuk on 27.07.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation

struct MatchingParameters: Codable {
    let scheme: String?
    let host: String?
    let path: String?
    let queryKeys: [String]?
    let port: Int?
    let statusCode: Int?
    let httpMethod: HTTPMethod?
}

class IndexRecordsFinder {
    private let matchingParameters: MatchingParameters

    init(indexSearchParametersObject: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: indexSearchParametersObject, options: [])
            let matchingParameters = try JSONDecoder().decode(MatchingParameters.self, from: data)
            self.matchingParameters = matchingParameters
        } catch _ {
            printError("Was not able to parse matching parameters from object:\n\(indexSearchParametersObject)")
            abort()
        }
    }

    func indexRecordsMatchingParameters(records: [IndexRecord]) -> [IndexRecord] {
        var mathcingRecords = [IndexRecord]()

        for record in records {
            if isRecordMatchingParameters(record: record) {
                mathcingRecords.append(record)
            }
        }

        return mathcingRecords
    }

    func isRecordMatchingParameters(record: IndexRecord) -> Bool {
        if matchingParameters.statusCode != nil &&  matchingParameters.statusCode != record.statusCode {
            return false
        }

        if matchingParameters.httpMethod != nil &&  matchingParameters.httpMethod != record.httpMethod {
            return false
        }

        guard let matchedURLComponents = URLComponents(url: record.url, resolvingAgainstBaseURL: false) else {
            return false
        }

        if matchingParameters.scheme != nil &&  matchingParameters.scheme != matchedURLComponents.scheme {
            return false
        }

        if matchingParameters.host != nil &&  matchingParameters.host != matchedURLComponents.host {
            return false
        }

        if let path = matchingParameters.path, path != matchedURLComponents.path {
            if !matchesPathRegExpr(regexPath: path, pathToMatch: matchedURLComponents.path) {
                return false
            }
        }

        if matchingParameters.port != nil &&  matchingParameters.port != matchedURLComponents.port {
            return false
        }

        // Match query items
        if let queryKeys = matchingParameters.queryKeys {
            if queryKeys.isEmpty {
                guard matchedURLComponents.queryItems == nil || matchedURLComponents.queryItems?.isEmpty == true else {
                    return false
                }

                return true
            }

            if let currentQueryItems = matchedURLComponents.queryItems {
                let queryItemNames = currentQueryItems.compactMap { $0.name }

                for key in queryKeys {
                    if !queryItemNames.contains(key) {
                        return false
                    }
                }
            } else {
                return false
            }
        }

        return true
    }

    private func matchesPathRegExpr(regexPath: String, pathToMatch: String) -> Bool {
        do {
            let range = NSRange(location: 0, length: pathToMatch.utf16.count)

            let regex = try NSRegularExpression(pattern: regexPath, options: [.caseInsensitive])
            return regex.firstMatch(in: pathToMatch, options: [], range: range) != nil
        } catch _ {
            return false
        }
    }
}
