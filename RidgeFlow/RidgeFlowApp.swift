//
//  RidgeFlowApp.swift
//  RidgeFlow
//
//  Created by Titan Han on 2026/6/17.
//

import SwiftUI
import SwiftData

@main
struct RidgeFlowApp: App {
    var body: some Scene {
        WindowGroup {
            MainMapView() // 👈 直接讓 App 啟動時開啟我們做的新地圖畫面
        }
    }
}
