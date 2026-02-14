import Foundation
import UIKit

class LogManager {
    static let shared = LogManager()
    
    private init() {}
    
    private let pipe = Pipe()
    private var logFileHandle: FileHandle?
    private var originalStdout: Int32 = STDOUT_FILENO
    private var originalStderr: Int32 = STDERR_FILENO
    
    func startLogging() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        // Define directory: Documents/system/logs
        let logsDir = documentsPath.appendingPathComponent("system/logs")
        
        // Create directory if not exists
        do {
            try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(" Failed to create logs directory: \(error)")
            return
        }
        
        // Clean old logs before creating new one
        cleanOldLogs(at: logsDir)
        
        // Generate filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "sumee_log_\(dateFormatter.string(from: Date())).txt"
        let logFileURL = logsDir.appendingPathComponent(filename)
        
        // Create the file for writing
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
        
        do {
            logFileHandle = try FileHandle(forWritingTo: logFileURL)
        } catch {
            print(" Failed to open log file handle: \(error)")
        }
        
        // Redirect stdout/stderr using Pipe (Tee) to keep Xcode console alive
        // 1. Save original FDs (pointing to Xcode Console)
        originalStdout = dup(STDOUT_FILENO)
        originalStderr = dup(STDERR_FILENO)
        
        // 2. Redirect real stdout/stderr to our Pipe
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        
        // 3. Handle data coming to Pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else { return }
            
            // A. Write to File
            self.logFileHandle?.seekToEndOfFile()
            self.logFileHandle?.write(data)
            
            // B. Write to Original Console (so it shows in Xcode)
            // We use the low-level write to the saved FD to bypass the redirection
            data.withUnsafeBytes { buffer in
                 if let base = buffer.baseAddress {
                     write(self.originalStdout, base, buffer.count)
                 }
            }
        }
        
        print(" Log System Started: \(logFileURL.lastPathComponent)")
        print(" Device: \(UIDevice.current.name) - iOS \(UIDevice.current.systemVersion)")
        print(" App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
        
        // Setup Uncaught Exception Handler
        NSSetUncaughtExceptionHandler { exception in
            print(" CRITICAL: Uncaught Exception: \(exception.name.rawValue)")
            print("Reason: \(exception.reason ?? "Unknown")")
            print("Stack Trace: \(exception.callStackSymbols.joined(separator: "\n"))")
            // Make sure logs are flushed not trivial with Pipe, but we can try
        }
    }
    
    private func cleanOldLogs(at directory: URL) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            // Sort by creation date (newest first)
            let sortedFiles = fileURLs.sorted {
                let date0 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date1 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date0 > date1
            }
            
            // Keep max 10 files
            let maxLogs = 10
            if sortedFiles.count > maxLogs {
                let filesToDelete = sortedFiles.suffix(from: maxLogs)
                for fileURL in filesToDelete {
                    try? FileManager.default.removeItem(at: fileURL)
                    print(" Deleted old log: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print(" Error cleaning logs: \(error)")
        }
    }
}
