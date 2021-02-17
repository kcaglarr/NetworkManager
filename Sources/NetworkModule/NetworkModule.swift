import Foundation
import UIKit

public struct NetworkService {
    
    public static let shared = NetworkService()
    public init() {}
    public static var tokenRequestAvailable = false
    
    let operationQueue: OperationQueue = OperationQueue()
    
    public func add(_ operation: Operation & NetworkOperationProtocol) {
        operation.operationState = .ready
        operationQueue.addOperation(operation)
    }
}

// Service Error Object
public struct ServiceErrorr: Codable {
    var errorKey: String?
    var title: String?
    var status: Int?
    var path: String?
}

// Service Error Cases
public enum NetworkError: Error {
    
    public enum ErrorMessageConst {
        static let defaultErrorMessage = "Geçici bir sorun oldu"
        static let defaultConnectionErrorMessage = "internet baglantısı yok"
    }
    
    case operationFailed
    case connectionError
    case serviceError(ServiceErrorr)
    case error(Error)
    
    public var message: String? {
        switch self {
        case .operationFailed:
            return ErrorMessageConst.defaultErrorMessage
        case .connectionError:
            return ErrorMessageConst.defaultConnectionErrorMessage
        case .serviceError(let err):
            return err.errorKey
        case .error(_):
            return ErrorMessageConst.defaultErrorMessage
        }
    }
}

extension NetworkError {
    
    static func showAlert(with error: NetworkError) {
        
        let message = error.message ?? ErrorMessageConst.defaultErrorMessage
        let alert = UIAlertController(title: nil, message:message,  preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default, handler: nil))
        guard let topController = UIApplication.shared.keyWindow?.rootViewController else {return}
        topController.present(alert, animated: true, completion: nil)
    }
}


