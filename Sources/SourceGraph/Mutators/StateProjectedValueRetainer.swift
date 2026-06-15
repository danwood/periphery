import Configuration
import Foundation
import Shared

/// Retains user properties that are referenced only via a synthesized sibling member.
///
/// SwiftUI's `@State`, `@Binding`, and similar property wrappers cause the compiler to
/// synthesize sibling members for a property `foo`, including a projected value `$foo` (e.g. a
/// `SwiftUI.Binding`) and backing storage `_foo`/`__foo`. These synthesized members are marked
/// `implicit` in the index store and are children of the same type as `foo`.
///
/// When `foo` is read only through its projected value — e.g. `Child(value: $foo)` — the index
/// records a reference to the synthesized `$foo` member, not to the user-declared `foo`. As a
/// result `foo` has no incoming references of its own and is falsely reported unused.
///
/// This mutator detects the case by matching the synthesized projected value to its user
/// property by name (`$foo` ↔ `foo`) and, only when that projected value is actually referenced
/// at a use site, retaining the user property. A property that is never read at all has no
/// referenced projected value and therefore remains eligible to be reported unused.
final class StateProjectedValueRetainer: SourceGraphMutator {
    private let graph: SourceGraph
    private static let projectedValuePrefix = "$"

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        for typeDecl in graph.declarations(ofKinds: [.class, .struct, .enum]) {
            let instanceProperties = typeDecl.declarations.filter { $0.kind == .varInstance }
            guard !instanceProperties.isEmpty else { continue }

            let userPropertiesByName = instanceProperties
                .filter { !$0.isImplicit }
                .reduce(into: [String: Declaration]()) { result, decl in
                    result[decl.name] = decl
                }

            guard !userPropertiesByName.isEmpty else { continue }

            for synthesized in instanceProperties where synthesized.isImplicit {
                guard let userProperty = userProperty(for: synthesized.name, in: userPropertiesByName),
                      isReferencedAtUseSite(synthesized)
                else { continue }

                graph.markRetained(userProperty)
            }
        }
    }

    // MARK: - Private

    private func userProperty(for synthesizedName: String, in userProperties: [String: Declaration]) -> Declaration? {
        guard synthesizedName.hasPrefix(Self.projectedValuePrefix) else { return nil }

        let baseName = String(synthesizedName.dropFirst(Self.projectedValuePrefix.count))

        guard !baseName.isEmpty else { return nil }

        return userProperties[baseName]
    }

    /// A synthesized member is auto-retained by the indexer simply for being implicit, so its
    /// retained status alone doesn't indicate use. It is only genuinely used when the index
    /// records an incoming reference originating from a non-implicit declaration, i.e. an actual
    /// use site in user code, as opposed to the implicit cross-references the compiler synthesizes
    /// between a property's own backing members.
    private func isReferencedAtUseSite(_ declaration: Declaration) -> Bool {
        graph.references(to: declaration).contains { reference in
            guard reference.kind != .retained, let parent = reference.parent else { return false }

            return !parent.isImplicit
        }
    }
}
