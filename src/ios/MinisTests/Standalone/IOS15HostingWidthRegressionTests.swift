// Regression guards for the iOS 15 UIHostingController fallback.
// The fallback must measure SwiftUI with the cell's finite width proposal.

import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("  ✅ \(label)") }
    else { print("  ❌ \(label)"); failures += 1 }
}

let root = FileManager.default.currentDirectoryPath
let path = URL(fileURLWithPath: root)
    .appendingPathComponent("src/ios/Agent/MessageList/MessageListInfrastructure.swift")
let source = (try? String(contentsOf: path, encoding: .utf8)) ?? ""
guard !source.isEmpty else {
    print("❌ source not found: \(path.path)")
    exit(1)
}

let fallback = source.components(separatedBy: "private final class LegacyHostingContentView")
    .dropFirst().first ?? ""
check("fallback derives a finite width before measuring", fallback.contains("let proposedWidth")
      && fallback.contains("bounds.width > 0"))
check("fallback gives SwiftUI an explicit width proposal", fallback.contains("controller.view.sizeThatFits(")
      && fallback.contains("CGSize(width: proposedWidth"))
let intrinsic = fallback.components(separatedBy: "override var intrinsicContentSize").dropFirst().first ?? ""
check("fallback does not use unconstrained Auto Layout sizing", !intrinsic.contains("systemLayoutSizeFitting("))
check("width changes invalidate the measured height", fallback.contains("previousWidth != bounds.width")
      && fallback.contains("invalidateIntrinsicContentSize()"))

print(failures == 0 ? "\n✅ ALL PASS" : "\n❌ \(failures) FAILED")
exit(failures == 0 ? 0 : 1)