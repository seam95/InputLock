import SwiftUI

struct ControlCenterContainerView: View {
    @ObservedObject var state: AppState

    var body: some View {
        MainDashboardView(state: state)
            .frame(width: 460)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color(nsColor: .windowBackgroundColor))
            .onAppear {
                state.refreshInputSources()
            }
    }
}
