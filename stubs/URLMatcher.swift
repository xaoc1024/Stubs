//
//  URLMatcher.swift
//  ChuckStubsAnalyzer
//
//  Created by Andrii Zhuk on 27.07.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation

class URLMatcher {
    private enum Constant {
        static let matcherFilePath = "/stubs_config/url_matching_rules.json"
    }

    struct Components: Codable {
        let scheme: String?
        let host: String?
        let path: String?
        let queryKeys: [String]?
        let port: Int?
    }

    let matcherComponents: Components
    
    init(urlComponents: Components) {
        self.matcherComponents = urlComponents
    }

    func matchURL(_ currentURL: URL) -> Bool {
        guard let currentURLComponent = URLComponents(url: currentURL, resolvingAgainstBaseURL: false) else {
            return false
        }

        if matcherComponents.scheme != nil &&  matcherComponents.scheme != currentURLComponent.scheme {
            return false
        }

        if matcherComponents.host != nil &&  matcherComponents.host != currentURLComponent.host {
            return false
        }

        if let path = matcherComponents.path, path != currentURLComponent.path {
            if !matchesPathRegExpr(regexPath: path, pathToMatch: currentURLComponent.path) {
                return false
            }
        }

        if matcherComponents.port != nil &&  matcherComponents.port != currentURLComponent.port {
            return false
        }

        // Match query items
        if let queryKeys = matcherComponents.queryKeys {
            if queryKeys.isEmpty {
                guard currentURLComponent.queryItems == nil || currentURLComponent.queryItems?.isEmpty == true else {
                    return false
                }

                return true
            }

            if let currentQueryItems = currentURLComponent.queryItems {
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

extension URLMatcher {
    static func readURLMatchingRulesFile(at executableFolderURL: URL) ->  URLMatcher.Components {
        let matcherFileURL = executableFolderURL.appendingPathComponent(Constant.matcherFilePath, isDirectory: false)
        do {
            let matcherFileData = try Data(contentsOf: matcherFileURL)
            let matcherComponents = try JSONDecoder().decode(URLMatcher.Components.self, from: matcherFileData)
            return matcherComponents
        } catch let error {
            print(error)
            abort()
        }
    }
}
