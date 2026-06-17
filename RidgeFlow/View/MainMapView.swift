//
//  MainMapView.swift
//  RidgeFlow
//
//  Created by Titan Han on 2026/6/17.
//


import SwiftUI
import MapKit
import UniformTypeIdentifiers


struct MainMapView: View {
    @StateObject private var viewModel = MapDashboardViewModel()
    @State private var showFileImporter = false // 支援手動點擊按鈕從「檔案 App」選取
    
    var body: some View {
        NavigationStack {
            ZStack {
                // iOS 17+ 原生地圖
                Map(position: $viewModel.cameraPosition) {
                    UserAnnotation() // 顯示使用者當前綠點
                    
                    // 繪製 GPX 軌跡
                    if !viewModel.routeCoordinates.isEmpty {
                        MapPolyline(coordinates: viewModel.routeCoordinates)
                            .stroke(.orange, lineWidth: 5)
                    }
                }
                .mapControls {
                    MapUserLocationButton() // 原生定位按鈕
                    MapCompass()           // 指北針
                }
                
                // 載入中狀態提示
                if viewModel.isImporting {
                    ProgressView("正在解析 GPX 軌跡...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("登山地圖")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showFileImporter = true }) {
                        Image(systemName: "doc.badge.plus")
                    }
                }
            }
            // 監聽情境 1：使用者從 LINE/Files 點選分享至本 App
            .onOpenURL { url in
                viewModel.importGPX(from: url)
            }
            // 監聽情境 2：手動開啟系統檔案選取器
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.init("com.topografix.gpx") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.importGPX(from: url)
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            // 錯誤訊息提示
            .alert("提示", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

#Preview {
    MainMapView()
}
