import SwiftUI

@main
struct FIXXEApp: App {
    @StateObject private var vm = ConverterViewModel()

    init() {
        // язык для съёмки кадров магазина задаётся аргументом запуска
        if !ScreenshotArgs.lang.isEmpty { L10n.chosenLang = ScreenshotArgs.lang }

        // iOS 15: очистка фона List (на iOS 16+ это делает compatHideListBackground)
        if #unavailable(iOS 16.0) {
            UITableView.appearance().backgroundColor = .clear
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                // nil — оформление как в системе; .light/.dark — выбор пользователя
                .preferredColorScheme(vm.colorScheme)
        }
    }
}
