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
    let stubsModificationRules: [String: Any]?
    let indexModificationRules: [String: Any]?

    init(configurationFileURL: URL) {
        do {
            let rulesFileData = try Data(contentsOf: configurationFileURL)
            let object = try JSONSerialization.jsonObject(with: rulesFileData, options: [])

            guard let dictionary = object as? [String: Any],
                  let indexSearchParameters = dictionary[Constant.indexSearchParametersKey] as? [String: Any] else {
                fatalError("index_search_parameters must exist within the configuration structure: \n \(object)")
            }

            self.indexSearchParameters = indexSearchParameters
            self.stubsModificationRules = dictionary[Constant.stubsModificationRulesKey] as? [String: Any]
            self.indexModificationRules = dictionary[Constant.indexModificationRulesKey] as? [String: Any]

            if stubsModificationRules == nil && indexModificationRules == nil {
                fatalError("No modification rules were configured. Add `stubs_modification_rules` or `index_modification_rules` to the configuration.")
            }
        } catch _ {
            fatalError("Wasn't able to read configuration file at url \(configurationFileURL)")
        }
    }
}

