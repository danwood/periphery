import Foundation

public struct FixtureStruct231 {
    public init() {}

    func makeResult() -> FixtureStruct232 {
        FixtureStruct232()
    }

    func consume(_: FixtureEnum231) {}

    struct FixtureStruct232 {}

    enum FixtureEnum231 {
        case one
    }
}
