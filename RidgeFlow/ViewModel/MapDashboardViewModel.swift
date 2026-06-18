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
    
    // 新增：監聽偏軌狀態與定位
    @Published var isOffRouteAlert: Bool = false
    
    private let parser = GPXParserService()
    private let locationTracker = LocationTracker() // 載入定位追蹤器
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 綁定 LocationTracker 的偏軌狀態到 ViewModel 的 @Published 屬性
        locationTracker.$isOffRoute
            .receive(on: DispatchQueue.main)
            .assign(to: \.isOffRouteAlert, on: self)
            .store(in: &cancellables)
            
        // 啟動定位監聽
        locationTracker.startTracking()
    }
    
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
                
                // 🔥 核心關鍵：將軌跡同步給定位追蹤器，開啟偏軌計算
                self.locationTracker.gpxReferenceRoute = coords
                
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
    
    // 供 UI 手動切換省電模式使用
    func changePowerMode(_ mode: PowerSavingMode) {
        locationTracker.applyPowerMode(mode)
    }
}
