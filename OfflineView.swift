import SwiftUI

struct OfflineView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Internet Connection")
                .font(.title2)
                .bold()
            
            Text("Please check your connection and try again")
                .foregroundColor(.gray)
        }
    }
}
