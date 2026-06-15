#if os(macOS)
    @testable import TestShared
    import XCTest

    final class SwiftUIStateRetentionTest: FixtureSourceGraphTestCase {
        func testRetainsStateReadOnlyViaProjectedValue() {
            let additionalFilesToIndex = [
                FixturesProjectPath.appending("Sources/SwiftUIStateRetentionFixtures/StateProjectedValueChildView.swift"),
            ]

            analyze(retainPublic: true, additionalFilesToIndex: additionalFilesToIndex) {
                assertReferenced(.struct("StateProjectedValueParentView")) {
                    // Read only via its projected value '$projectedOnlyState', passed as a
                    // labeled argument to a child view in another file.
                    self.assertReferenced(.varInstance("projectedOnlyState"))
                    // Never read at all; the fix must not retain this.
                    self.assertNotReferenced(.varInstance("neverReadState"))
                }
            }
        }
    }
#endif
