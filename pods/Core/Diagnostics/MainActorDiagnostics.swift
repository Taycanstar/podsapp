//
//  MainActorDiagnostics.swift
//  pods
//
//  Created by Dimi Nunez on 10/26/25.
//


//
//  MainActorDiagnostics.swift
//  Pods
//
//  Created by Codex on 10/27/25.
//

import Foundation

enum MainActorDiagnostics {
    /// Logs a warning when code that should be isolated to the main thread is executing elsewhere.
    static func assertIsolated(_ context: String, file: StaticString = #fileID, line: UInt = #line) {
        guard !Thread.isMainThread else { return }

        print("🚨 MainActor violation detected – context: \(context)")
        print("   └── Location: \(file):\(line)")
        print("   └── Thread: \(Thread.current)")

        // Trim the call stack so logs stay readable.
        Thread.callStackSymbols
            .dropFirst(1) // drop the assert frame itself
            .prefix(8)
            .forEach { print("      • \($0)") }
    }
}
