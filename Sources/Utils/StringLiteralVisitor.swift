import SwiftSyntax

final class StringLiteralVisitor: SyntaxVisitor {
    var stringLiterals = Set<String>()

    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        for segment in node.segments {
            if let text = segment.as(StringSegmentSyntax.self)?.content.text {
                stringLiterals.insert(text)
            }
        }
        return .visitChildren
    }
}
