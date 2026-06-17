//
//  Item.swift
//  RidgeFlow
//
//  Created by Titan Han on 2026/6/17.
//

import Foundation
import CoreLocation

actor GPXParserService {
    // 解析從外部傳入的 URL
    func parseGPX(from url: URL) async throws -> [CLLocationCoordinate2D] {
        // 獲取安全存取權限（針對沙盒外的檔案）
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "GPXParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "無法存取檔案"])
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let data = try Data(contentsOf: url)
        return try await parseGPXData(data)
    }
    
    // 實際 XML 解析邏輯
    func parseGPXData(_ data: Data) async throws -> [CLLocationCoordinate2D] {
        let delegate = GPXParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        
        return try await withCheckedThrowingContinuation { continuation in
            if parser.parse() {
                continuation.resume(returning: delegate.coordinates)
            } else {
                let error = parser.parserError ?? NSError(domain: "GPXParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "GPX 解析失敗"])
                continuation.resume(throwing: error)
            }
        }
    }
}

// XMLParser 的代理類別，用來捕捉標籤
private class GPXParserDelegate: NSObject, XMLParserDelegate {
    var coordinates: [CLLocationCoordinate2D] = []
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        // 尋找軌跡點標籤 <trkpt lat="..." lon="...">
        if elementName == "trkpt" || elementName == "wpt" {
            if let latString = attributeDict["lat"], let lat = Double(latString),
               let lonString = attributeDict["lon"], let lon = Double(lonString) {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                coordinates.append(coordinate)
            }
        }
    }
}
