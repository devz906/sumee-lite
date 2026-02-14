import Foundation

//Remember to do the n64 don't forget it

class BoxArtDatabase {
    static let shared = BoxArtDatabase()
    
    // Cache: Console -> List of filenames
    private var databaseCache: [ROMItem.Console: [String]] = [:]
    private let lock = NSLock()
    
    // Levenshtein distance for fuzzy matching
    // Source: https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Levenshtein_distance#Swift
    private func levenshtein(aStr: String, bStr: String) -> Int {
        // ... (omitted, no change needed here as it's pure func)
        let a = Array(aStr)
        let b = Array(bStr)
        
        let m = a.count
        let n = b.count
        
        var d = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 1...m {
            d[i][0] = i
        }
        
        for j in 1...n {
            d[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                d[i][j] = min(
                    d[i - 1][j] + 1,      // deletion
                    d[i][j - 1] + 1,      // insertion
                    d[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return d[m][n]
    }
    
    private func loadDatabase(for console: ROMItem.Console) {
        // Double-Checked Locking Optimization
        lock.lock()
        if databaseCache[console] != nil { 
            lock.unlock()
            return 
        }
        lock.unlock()
        
 
        
        // Re-acquire lock to do the work safely (simplest correct approach)
        lock.lock()
        defer { lock.unlock() }
        
        // Check again in case another thread loaded it while we waited
        if databaseCache[console] != nil { return }
        
        let filename: String
        switch console {
        case .gameboyAdvance:
            filename = "Index-Game Boy Advance-Named_Boxarts"
        case .nintendoDS:
            filename = "Index-Nintendo DS-Named_Boxarts"
        case .playstation:
            filename = "Index-Playstation_Boxarts"
        case .snes:
            filename = "Index-SNES_Boxarts"
        case .nes:
            filename = "Index-NES_Boxarts"
        case .gameboy:
            filename = "Index-gameboy_Boxarts"
        case .gameboyColor:
            filename = "Index-gameboycolor_Boxarts"
        case .segaGenesis:
            filename = "Index-SegaGenesis_Boxarts"
        default:
            print("BoxArtDatabase: No index file known for console \(console)")
            databaseCache[console] = [] // Prevent retry
            return
        }
        
        // Path provided by finding tool: sumee/rooms/...
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) 
                ?? Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "Resources/Data/BoxArt")
                ?? Bundle.main.url(forResource: "sumee/Resources/Data/BoxArt/\(filename)", withExtension: nil) else {
            // Try absolute path if bundle fails (development environment)
            let devPath = "/Users/getzemanicruz/Desktop/SUMEE/sumee/Resources/Data/BoxArt/\(filename)"
            if FileManager.default.fileExists(atPath: devPath) {

                let loaded = parseFileHelper(at: URL(fileURLWithPath: devPath))
                databaseCache[console] = loaded
            } else {
                print(" BoxArtDatabase: Could not locate database file: \(filename)")
                databaseCache[console] = []
            }
            return
        }
        
        let loaded = parseFileHelper(at: url)
        databaseCache[console] = loaded
        print(" BoxArtDatabase loaded for \(console): \(loaded.count) entries")
    }
    
    // Pure helper, no side effects on cache
    private func parseFileHelper(at url: URL) -> [String] {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            return lines.compactMap { line -> String? in
                // Expect format: [IMG] \t Filename.png \t Date ...
                guard line.starts(with: "[IMG]") else { return nil }
                
                // Remove [IMG] prefix
                let cleanStart = line.replacingOccurrences(of: "[IMG]", with: "").trimmingCharacters(in: .whitespaces)
                
                // Rely on .png extension.
                if let range = cleanStart.range(of: ".png") {
                    let endIndex = range.upperBound
                    let filename = String(cleanStart[..<endIndex])
                    return filename.trimmingCharacters(in: .whitespaces)
                }
                
                return nil
            }
        } catch {
            print(" BoxArtDatabase: Failed to load file: \(error)")
            return []
        }
    }
    
    // Remove old parseFile to avoid confusion
    
    func findBestMatch(for romName: String, console: ROMItem.Console) -> String? {
        print(" DB Search: Starting search for '\(romName)' (Console: \(console))")
        
        loadDatabase(for: console)
        
        lock.lock()
        // Securely copy the array reference inside the lock
        guard let filenames = databaseCache[console], !filenames.isEmpty else {
            lock.unlock()
            print(" DB Search: Database is empty or failed to load for \(console).")
            return nil
        }
        lock.unlock()
        
        // 1. Exact Match (checking name + .png)
        let exactName = romName + ".png"
        if filenames.contains(exactName) {
            print(" DB Search: Exact match found -> \(exactName)")
            return exactName
        }
        
        // 2. Fuzzy Match
        // Filter to items that contain at least some part of the name to reduce search space
   
        let romWords = romName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        guard let firstWord = romWords.first?.lowercased() else { 
            print(" DB Search: Could not extract first word from '\(romName)'")
            return nil 
        }
        
        let candidates = filenames.filter { $0.lowercased().contains(firstWord) }
        print(" DB Search: Found \(candidates.count) candidates containing '\(firstWord)'")
        
        let searchSpace = candidates.isEmpty ? filenames : candidates
        if candidates.isEmpty { print(" DB Search: No candidates passed filter. Searching entire DB (slow)...") }
        
        var bestMatch: String? = nil
        var lowestDistance = Int.max
        
        // Optimization: Normalize romName once
        let target = romName.lowercased()
        
        for filename in searchSpace {
            // Remove extension for comparison
            let nameWithoutExt = filename.replacingOccurrences(of: ".png", with: "").lowercased()
            
            let distance = levenshtein(aStr: target, bStr: nameWithoutExt)
            
            // Heuristic: If distance is very small (relative to length), it's a good match
            // Allow some variance for (USA) vs (Europe) tags etc
            if distance < lowestDistance {
                lowestDistance = distance
                bestMatch = filename
            }
        }
        
        // Threshold: If distance is too high (e.g. > 50% length), ignore
        if let match = bestMatch, lowestDistance < max(romName.count / 2, 5) {
            print(" DB Search: Best fuzzy match -> '\(match)' (Distance: \(lowestDistance))")
            return match
        }
        
        print(" DB Search: No result validation passed. Best candidate was '\(bestMatch ?? "none")' (Distance: \(lowestDistance))")
        return nil
    }
}
