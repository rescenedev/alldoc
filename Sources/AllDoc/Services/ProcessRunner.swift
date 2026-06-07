import Foundation

struct ProcessResult {
    let stdout: Data
    let stderr: Data
    let exitCode: Int32

    var stdoutString: String { String(decoding: stdout, as: UTF8.self) }
    var stderrString: String { String(decoding: stderr, as: UTF8.self) }
}

enum ProcessRunnerError: Error, LocalizedError {
    case launchFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .launchFailed(let m): return "실행 실패: \(m)"
        case .cancelled:           return "취소됨"
        }
    }
}

/// 여러 파이프 콜백에서 안전하게 출력 바이트를 모으는 누적기.
private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var _out = Data()
    private var _err = Data()

    func appendOut(_ data: Data) { lock.lock(); _out.append(data); lock.unlock() }
    func appendErr(_ data: Data) { lock.lock(); _err.append(data); lock.unlock() }
    var out: Data { lock.lock(); defer { lock.unlock() }; return _out }
    var err: Data { lock.lock(); defer { lock.unlock() }; return _err }
}

/// 외부 CLI(fd/rg/fzf/unzip 등)를 비동기로 실행한다. 취소 시 프로세스를 종료한다.
enum ProcessRunner {
    static func run(
        _ executable: String,
        arguments: [String],
        stdin: Data? = nil,
        currentDirectory: URL? = nil,
        environment: [String: String]? = nil
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectory { process.currentDirectoryURL = currentDirectory }

        var env = ProcessInfo.processInfo.environment
        // CLI 도구가 홈브루 경로를 찾도록 PATH 보강.
        let extra = "/opt/homebrew/bin:/opt/zerobrew/prefix/bin:/usr/local/bin:/usr/bin:/bin"
        env["PATH"] = extra + ":" + (env["PATH"] ?? "")
        if let environment { env.merge(environment) { _, new in new } }
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        let inPipe: Pipe? = stdin != nil ? Pipe() : nil
        if let inPipe { process.standardInput = inPipe }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessResult, Error>) in
                // 출력을 동시에 비워 큰 파이프에서의 데드락을 막는다. (스레드 안전 누적기)
                let buffer = OutputBuffer()

                outPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        handle.readabilityHandler = nil
                    } else {
                        buffer.appendOut(chunk)
                    }
                }
                errPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        handle.readabilityHandler = nil
                    } else {
                        buffer.appendErr(chunk)
                    }
                }

                process.terminationHandler = { proc in
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    let restOut = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let restErr = errPipe.fileHandleForReading.readDataToEndOfFile()
                    buffer.appendOut(restOut)
                    buffer.appendErr(restErr)
                    continuation.resume(returning: ProcessResult(
                        stdout: buffer.out, stderr: buffer.err, exitCode: proc.terminationStatus
                    ))
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: ProcessRunnerError.launchFailed(error.localizedDescription))
                    return
                }

                if let stdin, let inPipe {
                    inPipe.fileHandleForWriting.write(stdin)
                    try? inPipe.fileHandleForWriting.close()
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}
