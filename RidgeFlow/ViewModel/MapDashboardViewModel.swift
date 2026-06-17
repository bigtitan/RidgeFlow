//
//  MapDashboardViewModel.swift
//  RidgeFlow
//
//  Created by Titan Han on 2026/6/17.
//

import SwiftUI
import MapKit
import Combine

@MainActor
class MapDashboardViewModel: ObservableObject {
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var errorMessage: String?
    @Published var isImporting: Bool = false
    
    private let parser = GPXParserService()
    
    // 處理外部檔案匯入
    func importGPX(from url: URL) {
        isImporting = true
        Task {
            do {
                let coords = try await parser.parseGPX(from: url)
                guard !coords.isEmpty else {
                    self.errorMessage = "GPX 檔案中沒有找到有效的軌跡點。"
                    self.isImporting = false
                    return
                }
                
                self.routeCoordinates = coords
                
                // 自動將地圖視角縮放到軌跡的起點
                if let firstCoordinate = coords.first {
                    let region = MKCoordinateRegion(
                        center: firstCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                    self.cameraPosition = .region(region)
                }
            } catch {
                self.errorMessage = "匯入失敗: \(error.localizedDescription)"
            }
            self.isImporting = false
        }
    }
}
