//
//  ContentView.swift
//  sumee
//
//  Created by ParienteKun on 26/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
     
            HomeView(appLoading: $isLoading)
                .zIndex(0)
            
        }
    }
}

#Preview {
    ContentView()
}
