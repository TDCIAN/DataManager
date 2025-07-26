//
//  API.swift
//  DataManager
//
//  Created by 김정민 on 7/25/25.
//

import Foundation

public protocol APIPath {
    var pathString: String { get }
    var parameters: [String: String]? { get }
}

public class API {
    
    public struct APIDomainInfo {
        let scheme: String
        let host: String
        let port: Int?
        let timeout: TimeInterval
        let cachePolicy: NSURLRequest.CachePolicy
        
        public init(
            scheme: String,
            host: String,
            port: Int? = nil,
            timeout: TimeInterval = 10,
            cachePolicy: NSURLRequest.CachePolicy = .returnCacheDataElseLoad
        ) {
            self.scheme = scheme
            self.host = host
            self.port = port
            self.timeout = timeout
            self.cachePolicy = cachePolicy
        }
    }
    
    public enum HTTPMethod {
        case get
        case post(bodyData: Data?)
    }
    
    private let scheme: String
    private let host: String
    private let port: Int?
    private let cachePolicy: NSURLRequest.CachePolicy
    private let timeout: TimeInterval
    
    public init(with domainInfo: APIDomainInfo) {
        self.scheme = domainInfo.scheme
        self.host = domainInfo.host
        self.port = domainInfo.port
        self.timeout = domainInfo.timeout
        self.cachePolicy = domainInfo.cachePolicy
    }
    
    public func request(path: APIPath, method: HTTPMethod) async -> Result<ResponseType, Error> {
        return await withCheckedContinuation { continuation in
            request(path: path.pathString, method: method, parameters: path.parameters) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    private func request(
        path: String,
        method: HTTPMethod,
        parameters: [String: String]? = nil,
        completion: @escaping (Result<ResponseType, Error>) -> Void
    ) {
        
        var urlComponents = URLComponents()
        urlComponents.scheme = scheme
        urlComponents.host = host
        urlComponents.port = port
        urlComponents.path = path
        
        switch method {
        case .get:
            if let parameters {
                urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            }
            
            guard let url = urlComponents.url else {
                completion(.failure(ErrorType.invalidURL))
                return
            }
            
            let urlRequest = URLRequest(
                url: url,
                cachePolicy: cachePolicy,
                timeoutInterval: timeout
            )
            URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
                guard let self else { return }
                completion(self.handleResponseData(with: data))
            }.resume()
            
        case .post(let bodyData):
            guard let url = urlComponents.url else {
                completion(.failure(ErrorType.invalidURL))
                return
            }
            var urlRequest = URLRequest(
                url: url,
                cachePolicy: cachePolicy,
                timeoutInterval: timeout
            )
            urlRequest.httpBody = bodyData
            
            URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
                guard let self else { return }
                completion(handleResponseData(with: data))
            }.resume()
        }
    }
}

extension API {
    private func handleResponseData(with data: Data?) -> Result<ResponseType, Error> {
        guard let data else {
            return .failure(ErrorType.badResponse)
        }
        
        do {
            let deserializedData = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            
            if let jsonDic = deserializedData as? [String: Any] {
                return .success(.jsonDic(dic: jsonDic))
            } else if let jsonArray = deserializedData as? [Any] {
                return .success(.jsonArray(array: jsonArray))
            } else {
                return .failure(ErrorType.invalidFormat)
            }
            
        } catch {
            return .failure(ErrorType.invalidJSON)
        }
    }
}
