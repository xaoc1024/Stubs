import Foundation

extension Process {
    static func launch(command: String, arguments: [String]) -> String {
        let process = Process()
        let command = "\(command) \(arguments.joined(separator: " "))"
//        printInfo("Executing: \(command)")
        return process.shell(command: command)
    }

    func shell(command: String) -> String {
        launchPath = "/bin/bash"
        arguments = ["-c", command]

        let outputPipe = Pipe()
        standardOutput = outputPipe
        launch()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let outputData = String(data: data, encoding: String.Encoding.utf8) else {
            return ""
        }

        return outputData.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
