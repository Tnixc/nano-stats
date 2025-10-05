//
//  nanoApp.swift
//  nano
//
//  Created by tnixc on 5/10/2025.
//

import SwiftUI

@main
struct nanoApp: App {
    @StateObject private var menuBarModel = MemoryDataModel()

    var body: some Scene {
        MenuBarExtra(menuBarModel.statusBarTitle) {
            MenuBarView(memoryMonitor: menuBarModel)
                .background(.clear)
        }
        .menuBarExtraStyle(.window)
    }
}
