//
//  DataManager.swift
//  DataManager
//
//  Created by 김정민 on 7/25/25.
//

import Foundation

// 데이터 관리 및 캐싱을 담당하는 싱글톤 액터 클래스
public actor DataManager {
    // DataManager의 기본 인스턴스(싱글톤)
    public static let `default` = DataManager()
    
    // 외부에서 인스턴스 생성을 막기 위한 private 생성자
    private init() { }
    
    // 메모리 캐시(NSCache)를 초기화 (최대 용량 제한)
    private lazy var memoryCache: NSCache<AnyObject, AnyObject> = {
        let cache = NSCache<AnyObject, AnyObject>()
        cache.totalCostLimit = 100_000_000
        return cache
    }()
}

// 데이터 관련 에러 타입 정의
public extension DataManager {
    enum ErrorType: Error {
        case noData // 데이터가 없음
        case noFilePath // 파일 경로가 없음
        case fileNotFound // 파일을 찾을 수 없음
    }
}

// 데이터 저장 위치 및 저장 방식 타입 정의
public extension DataManager {
    
    // 데이터 저장 위치 타입 (캐시/문서)
    enum DataLocationType {
        case cache
        case document
        
        // 각 위치에 해당하는 디렉토리 경로 반환
        public var directoryPath: String? {
            switch self {
            case .cache:
                return NSSearchPathForDirectoriesInDomains(
                    .cachesDirectory,
                    .userDomainMask,
                    true
                ).first
                
            case .document:
                return NSSearchPathForDirectoriesInDomains(
                    .documentDirectory,
                    .userDomainMask,
                    true
                ).first
            }
        }
    }
    
    // 데이터 저장 방식 타입 (캐시/문서 + 데이터)
    enum DataStorageType {
        case cache(data: Data)
        case document(data: Data)
        
        // 저장 위치의 디렉토리 경로 반환
        public var directoryPath: String? {
            locationType.directoryPath
        }
        
        // 저장할 데이터 반환
        public var data: Data {
            switch self {
            case .cache(let data), .document(let data):
                return data
            }
        }
        
        // 내부적으로 저장 위치 타입 반환
        private var locationType: DataLocationType {
            switch self {
            case .cache:
                return .cache
            case .document:
                return .document
            }
        }
    }
}

// 캐시 접근 및 저장 함수
public extension DataManager {
    // 캐시 또는 파일에서 데이터 로드
    func loadObject(
        object: DataLocationType,
        forKey key: String
    ) -> Result<Data, Error> {
        
        let cacheKey = NSString(string: key)
        
        // 메모리 캐시에 데이터가 있으면 반환
        if let cachedData = memoryCache.object(forKey: cacheKey) as? Data {
            return .success(cachedData)
        }
        
        // 디렉토리 경로가 없으면 에러 반환
        guard let directoryPath = object.directoryPath else {
            return .failure(ErrorType.noFilePath)
        }
        
        // 파일에서 데이터 로드 시도
        return loadFile(from: directoryPath, forKey: key)
    }
    
    // 데이터 캐시 및 파일에 저장
    func saveObject(
        object: DataStorageType,
        forKey key: String
    ) {
        let cacheKey = NSString(string: key)
        let cacheData = NSData(data: object.data)
        
        // 메모리 캐시에 데이터 저장
        memoryCache.setObject(cacheData, forKey: cacheKey)
        
        // 디렉토리 경로가 없으면 파일 저장 생략
        guard let directoryPath = object.directoryPath else { return }
        
        // 파일 저장은 비동기로 처리
        Task {
            await saveFile(data: object.data, to: directoryPath, forKey: key)
        }
    }
}

// 파일 입출력 관련 함수
extension DataManager {
    // 파일에서 데이터 로드
    private func loadFile(
        from directoryPath: String,
        forKey fileName: String
    ) -> Result<Data, Error> {
        var data: Data?
        
        if #available(iOS 16.0, *) {
            let directoryURL = URL(filePath: directoryPath)
            let fileURL = directoryURL.appendingPathComponent(fileName)
            data = try? Data(contentsOf: fileURL)
            
        } else {
            // iOS 16 미만 버전 대응
            let directoryURL = URL(fileURLWithPath: directoryPath)
            let fileURL = directoryURL.appendingPathComponent(fileName)
            data = try? Data(contentsOf: fileURL)
        }
        
        if let data {
            return .success(data)
        } else {
            return .failure(ErrorType.fileNotFound)
        }
    }
    
    // 파일에 데이터 저장 (비동기)
    private func saveFile(
        data: Data,
        to directoryPath: String,
        forKey fileName: String
    ) async {
        if #available(iOS 16.0, *) {
            let directoryURL = URL(filePath: directoryPath)
            let fileURL = directoryURL.appendingPathComponent(fileName)
            
            do {
                // 디렉토리가 없으면 생성
                if !checkDirectory(directoryPath: directoryURL.path) {
                    try FileManager.default.createDirectory(
                        at: directoryURL,
                        withIntermediateDirectories: true
                    )
                }
                try data.write(to: fileURL)
            } catch let error {
                print("### DataManager - saveFile - error: \(error.localizedDescription)")
            }
        } else {
            // iOS 16 미만 버전 대응
            let directoryURL = URL(fileURLWithPath: directoryPath)
            let fileURL = directoryURL.appendingPathComponent(fileName)
            
            do {
                // 디렉토리가 없으면 생성
                if !checkDirectory(directoryPath: directoryURL.path) {
                    try FileManager.default.createDirectory(
                        at: directoryURL,
                        withIntermediateDirectories: true
                    )
                }
                try data.write(to: fileURL)
            } catch let error {
                print("### DataManager - saveFile - error: \(error.localizedDescription)")
            }
        }
    }
}

// 디렉토리 존재 여부 확인 함수
extension DataManager {
    private func checkDirectory(directoryPath: String) -> Bool {
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(
            atPath: directoryPath,
            isDirectory: &isDirectory
        ) || isDirectory.boolValue == false {
            return false
        }
        
        return true
    }
}
