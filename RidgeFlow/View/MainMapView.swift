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
                // 1. 修正點：將地圖內容完整補上
                Map(position: $viewModel.cameraPosition) {
                    
                    // 👉 關鍵 A：在這裡繪製 GPX 軌跡線
                    if !viewModel.routeCoordinates.isEmpty {
                        MapPolyline(coordinates: viewModel.routeCoordinates)
                            .stroke(.blue, lineWidth: 5) // 明亮的藍色與 5 級粗細
                    }
                    
                    // 👉 關鍵 B：在地圖上顯示藍色目前位置小圓點（登山防迷核心）
                    UserAnnotation()
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                // 👉 關鍵 C：強制刷新機制
                // 當匯入新 GPX，點的數量改變時，強制讓 Map 元件重新渲染，防止 MapKit 偷懶不畫線
                .id(viewModel.routeCoordinates.count)
                
                // 👉 新增：偏軌紅色警示橫幅
                if viewModel.isOffRouteAlert {
                    VStack {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                            Text("注意：您已偏離迷路！請切回正軌")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .shadow(radius: 5)
                        
                        Spacer() // 頂到最上方
                    }
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.default, value: viewModel.isOffRouteAlert)
                }
                
                // 載入中的進度條提示（可選）
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
