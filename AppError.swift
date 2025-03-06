import Foundation

enum AppError: LocalizedError {
    case networkError
    case authError(String)
    case dataError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError: return "No internet connection"
        case .authError(let message): return message
        case .dataError(let message): return message
        }
    }
}
