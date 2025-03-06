import SwiftUI

struct AccountDeletedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        text: Color.primary,
        textSecondary: Color.secondary
    )
    
    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "trash.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(colors.secondary)
                
                VStack(spacing: 12) {
                    Text("Account Deleted")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(colors.secondary)
                    
                    Text("Your account has been successfully deleted.")
                        .font(.system(size: 16))
                        .foregroundColor(colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                Button(action: {
                    authViewModel.shouldShowAccountDeletedMessage = false
                    authViewModel.isLoggedIn = false
                        authViewModel.isProfileComplete = false
                }) {
                    Text("OK")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colors.secondary)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

struct AccountDeletedView_Previews: PreviewProvider {
    static var previews: some View {
        AccountDeletedView()
            .environmentObject(AuthViewModel())
    }
}
