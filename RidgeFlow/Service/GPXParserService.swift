//
//  GPXParserService.swift
//  RidgeFlow
//
//  Created by Titan Han on 2026/6/17.
//

import Foundation
import CoreLocation

final class GPXParserService: Sendable {
    
    func parseGPX(from url: URL) async throws -> [CLLocationCoordinate2D] {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "GPXParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "無法存取檔案"])
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let data = try Data(contentsOf: url)
        return try await parseGPXData(data)
    }
    
    // 將解析核心引導至 @MainActor 執行，因為 XMLParserDelegate 在 iOS 17+ 綁定主執行緒隔離
    // 別擔心！XMLParser 解析文字檔速度極快，在主執行緒執行不會造成感官卡頓
    @MainActor
    func parseGPXData(_ data: Data) async throws -> [CLLocationCoordinate2D] {
        let delegate = GPXParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        
        if parser.parse() {
            return delegate.coordinates
        } else {
            throw parser.parserError ?? NSError(domain: "GPXParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "GPX 解析失敗"])
        }
    }
}

// 既然服務要求在 @MainActor 執行，Delegate 也名正言順地綁定 @MainActor，完美符合 Swift 6 規範
@MainActor
private final class GPXParserDelegate: NSObject, XMLParserDelegate {
    var coordinates: [CLLocationCoordinate2D] = []
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "trkpt" || elementName == "wpt" {
            if let latString = attributeDict["lat"], let lat = Double(latString),
               let lonString = attributeDict["lon"], let lon = Double(lonString) {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                coordinates.append(coordinate)
            }
        }
    }
}
