import SwiftUI

public struct StateProjectedValueParentView: View {
    @State private var projectedOnlyState = StateModel()
    @State private var neverReadState = StateModel()

    public init() {}

    public var body: some View {
        StateProjectedValueChildView(model: $projectedOnlyState)
    }
}

final class StateModel: ObservableObject {
    var title = ""
}
