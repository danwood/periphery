import Configuration
import Foundation
import Shared

final class UsedDeclarationMarker: SourceGraphMutator {
    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        removeErroneousProtocolReferences()
        markUsed(graph.retainedDeclarations)

        graph.rootReferences.forEach { markUsed(declarationsReferenced(by: $0)) }

        ignoreUnusedDescendents(in: graph.rootDeclarations,
                                unusedDeclarations: graph.unusedDeclarations)
    }

    // MARK: - Private

    // Removes references from protocol member decls to conforming decls that have a dereferenced ancestor.
    private func removeErroneousProtocolReferences() {
        // Evaluate ancestor dereference status from a stable pre-mutation snapshot to avoid
        // order-dependent behavior when iterating sets and removing references.
        let dereferencedDeclarations = graph.allDeclarations.filter {
            !(graph.isRetained($0) || graph.hasReferences(to: $0))
        }

        let dereferencedAncestors = Set(dereferencedDeclarations)
        var referencesToRemove = Set<Reference>()

        for protocolDecl in graph.declarations(ofKind: .protocol) {
            for memberDecl in protocolDecl.declarations {
                for relatedRef in memberDecl.related {
                    guard let relatedDecl = graph.declaration(withUsr: relatedRef.usr) else { continue }

                    let hasDereferencedAncestor = relatedDecl.ancestralDeclarations.contains {
                        dereferencedAncestors.contains($0)
                    }

                    if hasDereferencedAncestor {
                        referencesToRemove.insert(relatedRef)
                    }
                }
            }
        }

        for reference in referencesToRemove {
            graph.remove(reference)
        }
    }

    private func markUsed(_ declarations: Set<Declaration>) {
        for declaration in declarations {
            guard !graph.isUsed(declaration) else { continue }

            graph.markUsed(declaration)

            for ref in declaration.references {
                markUsed(declarationsReferenced(by: ref))
            }

            for ref in declaration.related {
                markUsed(declarationsReferenced(by: ref))
            }

            // Follow return-type and parameter-type references from child function declarations.
            // A nested type used only as the return or parameter type of a sibling method has no
            // reference occurrence of its own; the index store records the type reference against
            // the method declaration. When the enclosing type is used, walking these references
            // ensures such a nested type is retained rather than falsely flagged as unused.
            for childDecl in declaration.declarations where childDecl.kind.isFunctionKind {
                for ref in childDecl.references where ref.role == .returnType || ref.role == .parameterType {
                    markUsed(declarationsReferenced(by: ref))
                }
            }
        }
    }

    private func declarationsReferenced(by reference: Reference) -> Set<Declaration> {
        var declarations: Set<Declaration> = []

        if let declaration = graph.declaration(withUsr: reference.usr) {
            declarations.insert(declaration)
        }

        return declarations
    }

    private func ignoreUnusedDescendents(in decls: Set<Declaration>, unusedDeclarations: Set<Declaration>) {
        for decl in decls {
            guard !decl.declarations.isEmpty || !decl.unusedParameters.isEmpty
            else { continue }

            if unusedDeclarations.contains(decl) {
                decl.descendentDeclarations.forEach { graph.markIgnored($0) }
            } else {
                ignoreUnusedDescendents(in: decl.declarations,
                                        unusedDeclarations: unusedDeclarations)
            }
        }
    }
}
