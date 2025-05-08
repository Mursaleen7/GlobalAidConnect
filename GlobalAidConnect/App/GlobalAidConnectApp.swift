//
//  GlobalAidConnectApp.swift
//  GlobalAidConnect
//
//  Created by Mursaleen Sakoskar on 07/05/2025.
//

import SwiftUI

@main
struct GlobalAidConnectApp: App {
    // StateObject ensures our service persists across view updates
    @StateObject private var apiService = ApiService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(apiService) // Inject the service to make it available throughout the app
        }
    }
}
