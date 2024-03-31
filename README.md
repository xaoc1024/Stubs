# Stubs
This is command line MacOS utilite which is used to modify JSON files for Chuck stub server following proviced rools. 

To run stubs modifed use the same `make` command as running chuck. Added support of 2 new commands:
`make modify-stubs` - modify stubs using stubs tool and configuration in configuration.json
`make modify-index` - modify index file urls parameters using stubs tool and configuration in cconfiguration.json

In the Configurtion file there are 3 configuration sections: 

index_search_parameters
stubs_modification_rules
index_modification_rules

1.  index_search_parameters - In this section specify fields to match desired url. If some field is missing (or null) - it will be ignored during matching process. 
This section can have next parameters: 
	scheme: String - HTTP, HTTPS.

	host: String - e.g secure.nordstorm.com, api.nordstrom.com, etc

	path: String - Path parameter suports Regualr Expression (NOT Wildcard, but indeed regular expression!!!!111oneoneone) matching. For example, /disco/keyword/.*/offers will match URL with any keyword. 

	queryKeys: [String] - If queryKeys field is epmty ([]) - it will match the url, that doesn't have parameters, if field is missing (or null) - the presence of parameters will be ignored. 

	port: Int - Port parameter here is for consistency with URLComponent, that is used in the code, but I do not recomment specifying it as most of index files do not have it, and those one which have - use 443 port for https protocol (JFI). 

	statusCode: Int - Number, 200, 201, 404, etc.

	httpMethod: String  - GET, POST, PUT, etc.


NOTE: In current implementation if url from index file has more query parameters than specified in `queryKeys` - the rest of them will be ignored and the url will be considered as match if it has the parameters specified in this file.

2. stubs_modification_rules - The structure of the section is the next: 
'rules' is the top element, the value of this key is array, that has a rule how and what to modify. It consist of the next keys:
	- path - Required. The path to the entry that should be modified. (if is has an array on it's way, you can just ignore it, as the code will iterate through the array)

	- add -  Optional. Specify desired dictionary and their values that should be added to the stubs for the given endpoint at a given path. When specified field is already present in the stub JSON, it is possible to configure whether it should be replaced or ignored. This can be helpfull if there is a need to add missing field, but preserve existing ones.

	- remove - Optional. Specify keys should be removed from the stubs for given endpoint at a given path.

NOTE: 'add' and 'remove' fields can be missing, but there should be at least one `add` or `remove` section. Otherwise there is nothing to modify.

3. index_modification_rules - The structure of the section is the next: 
	- `add`  -  specify desired query parameters and their values that are needed to be added to the URL in the index file; This should be one level object, like [Strign: String], [String: Int]. 
	NOTE: Bool is serialized as 0 and 1, so if you need true or false, specify it as a string "true", "false"

	- `remove` -  specify keys that should be removed from url in the index file for given record

NOTE: Any of mentioned field can be missing, but it should have at least one `add` or `remove` section. Otherwise there is nothing to modify.
