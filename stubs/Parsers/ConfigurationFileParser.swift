//
//  ConfigurationFileParser.swift
//  stubs
//
//  Created by Andrii Zhuk on 03.08.2020.
//  Copyright © 2020 Andrii Zhuk. All rights reserved.
//

import Foundation
class ConfigurationFile {
    private enum Constant {
        static let indexSearchParametersKey = "index_search_parameters"
        static let stubsModificationRulesKey = "stubs_modification_rules"
        static let indexModificationRulesKey = "index_modification_rules"
    }

    let indexSearchParameters: [String: Any]
    let stubsModificationRules: [String: Any]
    let indexModificationRules: [String: Any]

    init(configurationFileURL: URL) {
        do {
            let rulesFileData = try Data(contentsOf: configurationFileURL)
            let object = try JSONSerialization.jsonObject(with: rulesFileData, options: [])

            guard let dictionary = object as? [String: Any],
                let indexSearchParameters = dictionary[Constant.indexSearchParametersKey] as? [String: Any],
                let stubsModificationRules = dictionary[Constant.stubsModificationRulesKey] as? [String: Any],

            let indexModificationRules = dictionary[Constant.indexModificationRulesKey] as? [String: Any] else {
                printError("Incorrect structure of: \n \(object)")
                abort()
            }

            self.indexSearchParameters = indexSearchParameters
            self.stubsModificationRules = stubsModificationRules
            self.indexModificationRules = indexModificationRules
        } catch _ {
            printError("Wasn't able to read configuration file at url \(configurationFileURL)")
            abort()
        }
    }
}

