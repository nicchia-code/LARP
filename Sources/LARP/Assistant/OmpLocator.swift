import Foundation

/// Finds the `omp` executable on the Mac. Replaceable in tests.
protocol OmpLocating: Sendable {
    /// The `omp` executable, or `nil` when it is not found. Looked up again at
    /// every call.
    func locate() async -> URL?
}

/// Looks `omp` up through the user's login shell (`$SHELL -l -c 'command -v omp'`),
/// because apps opened from the Finder do not get the `PATH` of the shell.
struct LoginShellOmpLocator: OmpLocating {
    /// A shell that does not answer in this time counts as `omp` not found.
    static let timeout: TimeInterval = 10

    /// The shell and its arguments are injectable for tests.
    var shell: URL = URL(
        fileURLWithPath: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")

    func locate() async -> URL? {
        let process = Process()
        process.executableURL = shell
        process.arguments = ["-l", "-c", "command -v omp"]
        let output = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let box = ProcessBox(process, output: output)

        let text: String? = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global().async {
                    do {
                        try box.process.run()
                    } catch {
                        continuation.resume(returning: nil)
                        return
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + Self.timeout) {
                        box.terminate()
                    }
                    let data = box.output.fileHandleForReading.readDataToEndOfFile()
                    box.process.waitUntilExit()
                    continuation.resume(
                        returning: box.process.terminationStatus == 0
                            ? String(data: data, encoding: .utf8) : nil)
                }
            }
        } onCancel: {
            box.terminate()
        }

        // A login shell may print its own output first: `command -v` is last.
        guard
            let path = text?.split(whereSeparator: \.isNewline).last
                .map({ $0.trimmingCharacters(in: .whitespaces) }),
            path.hasPrefix("/"),
            FileManager.default.isExecutableFile(atPath: path)
        else { return nil }
        return URL(fileURLWithPath: path)
    }
}

/// A `Process` and its output pipe handed between queues; the process is only
/// started and terminated, the pipe only read.
private final class ProcessBox: @unchecked Sendable {
    let process: Process
    let output: Pipe

    init(_ process: Process, output: Pipe) {
        self.process = process
        self.output = output
    }

    func terminate() {
        if process.isRunning { process.terminate() }
    }
}
