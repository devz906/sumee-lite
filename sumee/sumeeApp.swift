//
//  sumeeApp.swift
//  sumee
//
//  Created by Getzemani Cruz on 26/11/25.
//

import SwiftUI
import UserNotifications

@main
struct sumeeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasShownWelcome") private var hasShownWelcome: Bool = false
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            if hasShownWelcome {
                ContentView()
            } else {
                WelcomeView {
                    withAnimation {
                        hasShownWelcome = true
                    }
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Clear the badge when the app is active
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Start Logging System
        LogManager.shared.startLogging()
        
        // Request Notification Permissions ONLY if enabled by user
        // Default to false if not set (first launch) - User must enable manually
        // We use a specific key 'isGlobalChatNotificationsEnabled' to force a fresh state logic
        let areNotificationsEnabled = UserDefaults.standard.object(forKey: "isGlobalChatNotificationsEnabled") as? Bool ?? false
        
        if areNotificationsEnabled {
            UNUserNotificationCenter.current().delegate = self
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
                if granted {
                    print("✅ Notification Permission Granted")
                    DispatchQueue.main.async {
                        application.registerForRemoteNotifications()
                    }
                } else if let error = error {
                    print("❌ Notification Permission Error: \(error)")
                }
            }
        } else {
            print("🔕 Notifications are disabled by user preference")
            DispatchQueue.main.async {
                application.unregisterForRemoteNotifications()
            }
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("📲 APNs Device Token: \(token)")

    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for notifications: \(error)")
    }
    
    // Foreground Notification Handler
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}
