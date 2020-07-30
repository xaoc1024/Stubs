//
//  FilesModifier.swift
//  ChuckStubsAnalyzer
//
//  Created by Andrii Zhuk on 27.07.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation

class IndexFilesFinder {
    private enum Constant {
        static let indexFile = "index.txt"
    }

    let stubsDirURL: URL

    let fileManager = FileManager()

    private(set) var indexURLs: [URL] = [URL]()

    init(stubsDirURL: URL) {
        self.stubsDirURL = stubsDirURL
    }

    func findIndexFileURLs() -> [URL] {
        searchForIndexFiles(at: stubsDirURL)
        return indexURLs
    }

    private func searchForIndexFiles(at dirUrl: URL) {
        guard dirUrl.hasDirectoryPath else {
            return
        }

        guard let contents = try? fileManager.contentsOfDirectory(at: dirUrl, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            print("ERROR: cannot open file at path \(dirUrl.path)")
            return
        }

        let indexURL = contents.first { (url) -> Bool in
            url.lastPathComponent == Constant.indexFile
        }

        if let indexURL = indexURL {
            indexURLs.append(indexURL)
        }
        else {
            for url in contents {
                if url.hasDirectoryPath {
                    searchForIndexFiles(at: url)
                }
            }
        }
    }
}
