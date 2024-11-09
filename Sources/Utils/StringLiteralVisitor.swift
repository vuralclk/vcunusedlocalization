import SwiftSyntax

/// A visitor that traverses Swift syntax to find all string literals in a source file.
final class StringLiteralVisitor: SyntaxVisitor {
  /// A set to store unique string literals found in the source file.
  var stringLiterals = Set<String>()

  /// Visits each `StringLiteralExprSyntax` node in the syntax tree.
  /// - Parameter node: A syntax node representing a string literal expression.
  /// - Returns: A value indicating whether to continue visiting child nodes.
  override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
    for segment in node.segments {
      if let text = segment.as(StringSegmentSyntax.self)?.content.text {
        stringLiterals.insert(text)
      }
    }
    return .visitChildren
  }
}
