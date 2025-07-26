//
//  ResultExtensions.swift
//  DataManager
//
//  Created by 김정민 on 7/25/25.
//

import Foundation
import Combine

// Result 타입이 Data일 때, Data를 디코딩하여 Decodable 타입으로 변환하는 함수
public extension Result where Success == Data {
    /// Result<Data, Error>를 Result<T, Error>로 변환합니다. 실패 시 디코딩 에러를 반환합니다.
    /// - Parameter decoder: Decodable 타입
    /// - Returns: Result<T, Error>
    func decode<T: Decodable>(decoder: T.Type) -> Result<T, Error> {
        do {
            let successData = try get()
            let dataModel = try JSONDecoder().decode(decoder, from: successData)
            return .success(dataModel)
        } catch let error {
            return .failure(error)
        }
    }
}

// Result 타입이 Encodable일 때, Data로 인코딩하는 함수
public extension Result where Success: Encodable {
    // Result<Encodable, Error>를 Result<Data, Error>로 변환합니다. 실패 시 인코딩 에러를 반환합니다.
    func encode() -> Result<Data, Error> {
        do {
            let successDataModel = try get()
            let rawData = try JSONEncoder().encode(successDataModel)
            return .success(rawData)
        } catch let error {
            return .failure(error)
        }
    }
}

// Result의 성공/실패에 따라 각각의 핸들러를 실행하는 함수
public extension Result {
    func fold(
        success successHandler: (Success) -> Void,
        failure failureHandler: (Error) -> Void
    ) {
        switch self {
        case .success(let successValue):
            successHandler(successValue)
        case .failure(let error):
            failureHandler(error)
        }
    }
}

// Result 값을 Combine의 PassthroughSubject로 전달하는 함수
public extension Result {
    func send(through subject: PassthroughSubject<Self, Never>) {
        subject.send(self)
    }
}

// Result의 성공/실패 값을 비동기적으로 변환하는 함수들
public extension Result {
    /// 성공 값을 비동기적으로 변환합니다.
    /// - Parameter transform: 성공 값을 변환하는 비동기 클로저
    /// - Returns: 변환된 Result
    func asyncMap<NewSuccess>(_ transform: (Success) async -> NewSuccess) async -> Result<NewSuccess, Failure> {
        switch self {
        case .success(let success):
            return await .success(transform(success))
        case .failure(let failure):
            return .failure(failure)
        }
    }
    
    /// 실패 값을 비동기적으로 변환합니다.
    /// - Parameter transform: 실패 값을 변환하는 비동기 클로저
    /// - Returns: 변환된 Result
    func asyncMapError(_ transform: (Failure) async -> Failure) async -> Result<Success, Failure> {
        switch self {
        case .success(let success):
            return .success(success)
        case .failure(let failure):
            return await .failure(transform(failure))
        }
    }
}

// Result의 성공/실패 값을 비동기적으로 flatMap하는 함수들
public extension Result {
    /// 성공 값을 비동기적으로 flatMap합니다.
    /// - Parameter transform: 성공 값을 변환하는 비동기 클로저 (Result 반환)
    /// - Returns: 변환된 Result
    func asyncFlatMap<NewSuccess>(_ transform: (Success) async -> Result<NewSuccess, Failure>) async -> Result<NewSuccess, Failure> {
        switch self {
        case .success(let success):
            return await transform(success)
        case .failure(let failure):
            return .failure(failure)
        }
    }
    
    /// 실패 값을 비동기적으로 flatMap합니다.
    /// - Parameter transform: 실패 값을 변환하는 비동기 클로저 (Result 반환)
    /// - Returns: 변환된 Result
    func asyncFlatMapError(_ transform: (Failure) async -> Result<Success, Failure>) async -> Result<Success, Failure> {
        switch self {
        case .success(let success):
            return .success(success)
        case .failure(let failure):
            return await transform(failure)
        }
    }
}
