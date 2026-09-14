import SwiftUI

@main
struct NyerahLocalApp: App {
    @State private var viewModel = ChatViewModel()

    var body: some Scene {
        WindowGroup {
            ChatView(viewModel: viewModel)
        }
    }
}
