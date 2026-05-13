//
//  ContentView.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, AgenteMobile!")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("POC - iPad Agent")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
