//
//  NetworkOperation.swift
//  
//
//  Created by Kerim ÇAĞLAR on 16.02.2021.
//

import Foundation
import Alamofire

fileprivate enum NetworkConstants {
    static let unauthorizedCode = 401
}

public enum OperationState: String {
    case none
    case ready
    case exacuting
    case finished
}

public protocol NetworkOperationProtocol: class {
    var operationState: OperationState { get set }
}

open class NetworkOperation<T,M>: Operation, NetworkOperationProtocol where T: Decodable, M: Encodable  {
    
    open var operationState: OperationState = .none {
        willSet {
            willChangeValue(forKey: newValue.rawValue)
        }
        didSet {
            didChangeValue(forKey: operationState.rawValue)
        }
    }
    
    open lazy var session: Session = {
        
        let configuration = URLSessionConfiguration.af.default
        let session = Session(configuration: configuration)
        
        return session
    }()
    
    
//    This session will be used for long waiting times and upload Uses
        open lazy var multiPartSession: Session = {
            
            let configuration = URLSessionConfiguration.af.default
            let session = Session(configuration: configuration)
            
            return session
        }()
    
    open var request: BaseRequest
    open var requestModel: M?
    open var completion: ((Result<T, Error>) -> Void)?
    open lazy var jsonDecoder: JSONDecoder = {
        let decoder : JSONDecoder = JSONDecoder();
        let dateFormatter : DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }()
    
    public init(request: BaseRequest,
         requestModel: M?,
         completion: ((Result<T, Error>) -> Void)? = nil) {
        
        self.request = request
        self.requestModel = requestModel
        self.completion = completion
        operationState = .none
    }
    
    open override func start() {
        if (NetworkReachabilityManager.default?.isReachable ?? true) == false {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.request.showAlertWhenError {
                    NetworkError.showAlert(with: NetworkError.connectionError)
                }
                self.completion?(Result.failure(NetworkError.connectionError))
                self.operationState = .finished
            }
            
        } else if !isExecuting {
            operationState = .exacuting
            performRequest()
        }
    }
    
    // MARK: -
    open override var isReady: Bool {
        return operationState == .ready
    }
    
    open override var isExecuting: Bool {
        return operationState == .exacuting
    }
    
    open override var isFinished: Bool {
        return operationState == .finished
    }
    
    open override var isAsynchronous: Bool {
        return true
    }
    
}

extension NetworkOperation {
    
    // Request
    public func performRequest() {
        print("performing request to url \(request.urlString)")
        print("request params: \(String(describing: requestModel))")
        
        let req: DataRequest! = performDataRequest()
        
        let emptyResponseCodes: Set<Int> = [201, 204, 205]
        
        let serializer = DataResponseSerializer(dataPreprocessor: DataResponseSerializer.defaultDataPreprocessor,
                                                emptyResponseCodes: emptyResponseCodes,
                                                emptyRequestMethods: DataResponseSerializer.defaultEmptyRequestMethods)
        
        req.response(queue: DispatchQueue.main, responseSerializer: serializer) { [weak self] (response) in
            guard let self = self else { return }
            self.handleResponse(response: response)
        }
    }
    
    public func performDataRequest() -> DataRequest {
        
        let req = session.request(request.urlString,
                             method: request.httpMethod,
                             parameters: requestModel,
                             encoder: JSONParameterEncoder.default,
                             headers: request.headers,
                             requestModifier: nil)
        
        return req
    }

    
    // Response
    public func handleResponse(response: DataResponse<Data, AFError>) {
 
        print("handle response with status code \(String(describing: response.response?.statusCode)) and error \(String(describing: response.error?.errorDescription))")
        
        switch response.response?.statusCode ?? 500 {
        case 200..<299: // Success with data or empty
            self.handleResponse(data: response.data)
            
        default:  // Network or Service Errors
            
            let errorStr = createErrorStr(response: response)
            self.handleError(data: response.data, error: response.error, code: response.response?.statusCode ?? 500, errorStr: errorStr)
        }
    }
    
    public func createErrorStr(response: DataResponse<Data, AFError>) -> String {
        
        var  str = ""
        
        if let req = response.request {
            
            str = req.description + "#" // url
            
            if let headerDict = req.allHTTPHeaderFields { // headers
                
                for i in headerDict {
                    
                    str = str + i.key + "=" + i.value
                }
                
                str = str + "#"
            }
            
            if let bodyData = req.httpBody { // body
                
                str = str + String(decoding: bodyData, as: UTF8.self) + "#"
            }
        }
        
        
        if let errData = response.data {
            
            str =  str + "result: custom error response: \(String(decoding: errData, as: UTF8.self))"
        }else {
            
            str =  str + "result: error: \(String(describing: response.error))"
        }
        
        return str
    }
    
    // Success result
    public func handleResponse(data: Data?) {
        if let data = data {
            print("result: success: \(String(decoding: data, as: UTF8.self))")
            
            do {
                let decodedObject = try jsonDecoder.decode(T.self, from: data)
                completion?(Result.success(decodedObject))
                operationState = .finished
            } catch {
                let err = AFError.responseSerializationFailed(reason: .decodingFailed(error: error))
                print("result: error json parse: \(err)")
                completion?(Result.failure(err))
                operationState = .finished
            }
            
        } else {
            print("result: empty success")
            completion?(Result.success(BaseResponse() as! T))
            operationState = .finished
        }
    }
    
    // Failed result
    public func handleError(data: Data?, error: AFError?, code: Int, errorStr:String) {
        if let data = data {
            print("result: custom error response: \(String(decoding: data, as: UTF8.self))")
            
            do {
                let decodedObject = try jsonDecoder.decode(ServiceErrorr.self, from: data)
                let serviceError = NetworkError.serviceError(decodedObject)
                
                if self.request.showAlertWhenError {
                    if code >= 500 {
                        NetworkError.showAlert(with: NetworkError.operationFailed)
                    } else {
                        if decodedObject.errorKey == "already_exists_tckn" || decodedObject.errorKey == "already_exists_passport" {
                            //zaten diğer tarafta alert gidiyor burda
                        } else {
                            NetworkError.showAlert(with: serviceError)
                        }
                    }
                    completion?(Result.failure(serviceError))
                    operationState = .finished
                    
                }
                
            } catch {
                let err = AFError.responseSerializationFailed(reason: .decodingFailed(error: error))
                print("result: error json parse: \(err)")
                completion?(Result.failure(err))
                operationState = .finished
            }
            
        } else {
            print("result: error: \(String(describing: error))")
            if self.request.showAlertWhenError {
                NetworkError.showAlert(with: NetworkError.operationFailed)
            }
            completion?(Result.failure(NetworkError.operationFailed))
            operationState = .finished
        }
    }
    
}
