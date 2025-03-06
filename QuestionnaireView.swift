import SwiftUI

struct QuestionnaireView: View {
    @AppStorage("hasCompletedQuestionnaire") private var hasCompletedQuestionnaire = false
    @AppStorage("questionnaireAnswers") private var savedAnswers = Data()
        @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentPage = 0
    @Binding var showQuestionnaire: Bool
    @State private var answers: [Int: String] = [:]
    @Environment(\.dismiss) private var dismiss
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255)
    )
    
    private let questions = [
        Question(
            title: "What is your gender?",
            options: ["Male", "Female", "Other"]
        ),
        Question(
            title: "What is your age?",
            options: ["Under 18", "18-24", "25-34", "35-44", "45-54", "55+"]
        ),
        Question(
            title: "What is your occupation?",
            options: ["Student", "Employed", "Freelancer", "Entrepreneur", "Unemployed", "Retired"]
        ),
        Question(
            title: "Why do you want to track your mood?",
            options: [
                "Want to understand myself better",
                "Want to improve mental health",
                "Doctor/therapist recommended",
                "Track therapy effectiveness",
                "Just curious to try"
            ]
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("About You")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Tell us about yourself")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "person.fill.questionmark")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, getSafeAreaTop())
                    .padding(.bottom, 24)
                    .background(
                        colors.secondary
                            .cornerRadius(30, corners: [.bottomLeft, .bottomRight])
                    )
                    
                    TabView(selection: $currentPage) {
                        ForEach(questions.indices, id: \.self) { index in
                            QuestionView(
                                question: questions[index],
                                selectedAnswer: answers[index],
                                onSelect: { answer in
                                    answers[index] = answer
                                }
                            )
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(maxHeight: .infinity)
                    
                    VStack(spacing: 20) {
                        // Progress Indicators
                        HStack(spacing: 8) {
                            ForEach(0..<questions.count, id: \.self) { index in
                                Circle()
                                    .fill(currentPage == index ? colors.secondary : colors.secondary.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                    .animation(.spring(), value: currentPage)
                            }
                        }
                        
                        // Next/Complete Button
                        Button(action: {
                            if currentPage < questions.count - 1 {
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                let answersDict = [
                                    "gender": answers[0] ?? "",
                                    "age": answers[1] ?? "",
                                    "occupation": answers[2] ?? "",
                                    "reason": answers[3] ?? ""
                                ]
                                if let encoded = try? JSONEncoder().encode(answersDict) {
                                    UserDefaults.standard.set(encoded, forKey: "questionnaireAnswers")
                                }
                                
                                UserDefaults.standard.set(true, forKey: "hasCompletedQuestionnaire")
                                        withAnimation {
                                            showQuestionnaire = false
                                                hasCompletedQuestionnaire = true
                                                dismiss()
                                            
                                        }
                            }
                        }) {
                            Text(currentPage < questions.count - 1 ? "Next" : "Complete")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(answers[currentPage] != nil ? colors.secondary : colors.secondary.opacity(0.5))
                                .cornerRadius(16)
                        }
                        .disabled(answers[currentPage] == nil)
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 60)
                }
            }
            .navigationBarHidden(true)
            .ignoresSafeArea()
        }
    }
    
    private func getSafeAreaTop() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}

struct Question: Identifiable {
    let id = UUID()
    let title: String
    let options: [String]
}

struct QuestionView: View {
    let question: Question
    let selectedAnswer: String?
    let onSelect: (String) -> Void
    
    private let colors = (
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255)
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text(question.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(colors.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
            
            VStack(spacing: 12) {
                ForEach(question.options, id: \.self) { option in
                    Button(action: { onSelect(option) }) {
                        HStack {
                            Text(option)
                                .font(.headline)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if selectedAnswer == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(colors.secondary)
                            }
                        }
                        .foregroundColor(colors.secondary)
                        .padding()
                        .background(colors.buttonBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    QuestionnaireView(showQuestionnaire: .constant(true))
}
