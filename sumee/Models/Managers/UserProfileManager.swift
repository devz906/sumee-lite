import Foundation
import Combine

struct UserProfile: Codable {
    var playTimeStats: [String: TimeInterval] = [:] // Key: ROM ID (UUID String), Value: Seconds
    var lastPlayed: [String: Date] = [:] // Optional: Track last played date
}

class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    @Published var profile: UserProfile = UserProfile()
    
    private let fileName = "user_profile.json"
    
    private init() {
        loadProfile()
    }
    
    // MARK: - API
    
    func getPlayTime(for romID: UUID) -> TimeInterval {
        return profile.playTimeStats[romID.uuidString] ?? 0
    }
    
    func addPlayTime(for romID: UUID, duration: TimeInterval) {
        let key = romID.uuidString
        let current = profile.playTimeStats[key] ?? 0
        profile.playTimeStats[key] = current + duration
        profile.lastPlayed[key] = Date()
        
        saveProfile()
        
        // Notify UI update if needed
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Persistence
    
    private func getFileURL() -> URL? {
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return docURL.appendingPathComponent(fileName)
    }
    
    private func saveProfile() {
        guard let url = getFileURL() else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try JSONEncoder().encode(self.profile)
                try data.write(to: url, options: .atomic)
                print("User Profile saved: \(self.fileName)")
            } catch {
                print(" Failed to save user profile: \(error)")
            }
        }
    }
    
    private func loadProfile() {
        guard let url = getFileURL() else { return }
        
        if !FileManager.default.fileExists(atPath: url.path) {
            print(" Creating new user profile")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
            self.profile = decoded
            print(" Loaded User Profile (Stats for \(decoded.playTimeStats.count) games)")
        } catch {
            print(" Failed to load user profile: \(error)")
        }
    }
}
