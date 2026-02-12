import SwiftUI

struct ContentView: View {
    @State private var showingWalkScreen = false

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "hand.tap.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("TapSafe")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your silent walk-home guardian")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Button("Start Walk") {
                showingWalkScreen = true
            }
            .padding()
            .frame(maxWidth: 300)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(radius: 6)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingWalkScreen) {
            WalkActiveView()
        }
    }
}

#Preview {
    ContentView()
}
