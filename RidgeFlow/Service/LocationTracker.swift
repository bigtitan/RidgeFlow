//
//  LocationTracker.swift
//  RidgeFlow
//
//  Created by Titan Han on 2026/6/17.
//


import Foundation
import CoreLocation
import Combine
import UserNotifications  // 解決 UN 開頭的錯誤
import UIKit             // 解決 UINotificationFeedbackGenerator 的錯誤

enum PowerSavingMode {
    case highAccuracy  // 精準模式：地形複雜、即時找路（每秒/每公尺更新）
    case balanced      // 平衡模式：一般推進（每 10 公尺更新）
    case extremeSaving // 極度省電：稜線、常規步道、定點休息（每 50 公尺更新）
}

class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    // 讓 ViewModel 可以訂閱目前位置與偏軌狀態
    @Published var currentUserLocation: CLLocation?
    @Published var isOffRoute: Bool = false
    
    // 儲存當前行程的 GPX 軌跡點（由 ViewModel 傳入比對）
    var gpxReferenceRoute: [CLLocationCoordinate2D] = []
    
    // 偏軌警示閾值（公尺），預設為 50 公尺
    var alertThresholdInMeters: Double = 50.0
    
    override init() {
        super.init()
        locationManager.delegate = self
        
        // 請求權限（登山需要背景定位，必須請求 Always 權限）
        locationManager.requestAlwaysAuthorization()
        
        // 允許背景更新與防止系統自動掛起
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        
        // 預設採用平衡模式
        applyPowerMode(.balanced)
    }
    
    func startTracking() {
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
    }
    
    // 動態切換節能模式
    func applyPowerMode(_ mode: PowerSavingMode) {
        switch mode {
        case .highAccuracy:
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager.distanceFilter = 1.0
            locationManager.pausesLocationUpdatesAutomatically = false
        case .balanced:
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 10.0
            locationManager.activityType = .fitness // 步行模式，定點休息時 iOS 會自動降低頻率省電
            locationManager.pausesLocationUpdatesAutomatically = true
        case .extremeSaving:
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 50.0
            locationManager.activityType = .fitness
            locationManager.pausesLocationUpdatesAutomatically = true
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.currentUserLocation = location
        
        // 如果有載入 GPX 軌跡，進行偏軌演算
        if !gpxReferenceRoute.isEmpty {
            checkOffRouteStatus(currentLocation: location)
        }
    }
    
    // MARK: - 偏軌核心演算法
    private func checkOffRouteStatus(currentLocation: CLLocation) {
        guard gpxReferenceRoute.count > 1 else { return }
        
        var minDistance = Double.infinity
        let p = currentLocation.coordinate
        
        // 遍歷 GPX 軌跡的所有線段 (Segment)
        for i in 0..<(gpxReferenceRoute.count - 1) {
            let a = gpxReferenceRoute[i]
            let b = gpxReferenceRoute[i+1]
            
            // 計算目前位置 P 到線段 AB 的最短距離
            let distance = distanceFromPoint(p: p, toSegmentWithA: a, andB: b)
            if distance < minDistance {
                minDistance = distance
            }
        }
        
        // 判斷是否超過設定門檻 (例如 50 米)
        let offRouteResult = minDistance > alertThresholdInMeters
        
        // 狀態改變時更新，並觸發實機震動
        if offRouteResult != self.isOffRoute {
            DispatchQueue.main.async {
                self.isOffRoute = offRouteResult
                if offRouteResult {
                    self.triggerWarningFeedback()
                }
            }
        }
    }
    
    // 計算點 P 到線段 AB 的最短投影距離（單位：公尺）
    private func distanceFromPoint(p: CLLocationCoordinate2D, toSegmentWithA a: CLLocationCoordinate2D, andB b: CLLocationCoordinate2D) -> Double {
        // 使用簡單的平面投影公式（適合幾百公尺內的短距離計算，效能極高）
        let x = p.longitude, y = p.latitude
        let x1 = a.longitude, y1 = a.latitude
        let x2 = b.longitude, y2 = b.latitude
        
        let A = x - x1
        let B = y - y1
        let C = x2 - x1
        let D = y2 - y1
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        var param = -1.0
        
        if lenSq != 0 { param = dot / lenSq }
        
        var xx, yy: Double
        
        if param < 0 {
            xx = x1
            yy = y1
        } else if param > 1 {
            xx = x2
            yy = y2
        } else {
            xx = x1 + param * C
            yy = y1 + param * D
        }
        
        let closestLocation = CLLocation(latitude: yy, longitude: xx)
        let currentLoc = CLLocation(latitude: p.latitude, longitude: p.longitude)
        
        return currentLoc.distance(from: closestLocation) // 回傳公尺數
    }
    
    // 觸發警示震動與提示
    private func triggerWarningFeedback() {
        // 本地通知
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 偏離步道警示"
        content.body = "您已偏離既定路線超過 50 公尺，請立即確認地圖！"
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(identifier: "OffRouteAlert", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
        // 觸發觸覺震動 (在實機上會有感)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}
