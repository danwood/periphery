import SwiftUI

struct StateProjectedValueChildView: View {
    @Binding var model: StateModel

    var body: some View {
        Text(model.title)
    }
}
