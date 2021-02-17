//
//  BaseRequest.swift
//  
//
//  Created by Kerim ÇAĞLAR on 16.02.2021.
//

import Foundation
import Alamofire

protocol BaseRequestProtocol: class {
    var host: String { get }
    var route: String { get }
    var httpMethod: HTTPMethod { get }
    var headers: HTTPHeaders { get }
    var timeOut: TimeInterval { get }
    var showAlertWhenError: Bool { get }
    var isMultiPart: Bool { get }
}

open class BaseRequest: BaseRequestProtocol {
    
    public init() {
        
    }
    
    open var host: String {
        return ""
    }
    
    open var route: String {
        return ""
    }
    
    open var httpMethod: HTTPMethod {
        return .post
    }
    
    open var headers: HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "application/json")
        headers.add(name: "accept", value: "application/json")
        return headers
    }
    
    open var timeOut: TimeInterval {
        return 25
    }
    
    open var multiPartTimeOut: TimeInterval {
        return 30
    }
    
    open var urlString: String {
        return host + route
    }
    
    open var showAlertWhenError: Bool {
        return true
    }
    
    open var isMultiPart: Bool {
        return false
    }
}
