//
//  FeatureFlags.swift
//  pods
//
//  Created by Dimi Nunez on 11/8/25.
//


import Foundation

/// Centralized feature flags for runtime toggles.
/// Uses UserDefaults with sensible defaults so QA can flip without a build.
enum FeatureFlags {
    private static let llmKey = "ff_useLLMForWorkoutGeneration"
    private static let researchSelectorKey = "ff_useResearchBackedSelector"

    /// Toggle whether to use the LLM path for workout generation.
    /// Default: false (use deterministic research-based path).
    static var useLLMForWorkoutGeneration: Bool {
        if UserDefaults.standard.object(forKey: llmKey) == nil { return false }
        return UserDefaults.standard.bool(forKey: llmKey)
    }

    /// Toggle whether to use the research-backed selector for exercise ranking.
    /// Default: true.
    static var useResearchBackedSelector: Bool {
        if UserDefaults.standard.object(forKey: researchSelectorKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: researchSelectorKey)
    }

    /// Optional setters to flip at runtime (e.g., in debug tools or tests).
    static func setUseLLMForWorkoutGeneration(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: llmKey)
    }

    static func setUseResearchBackedSelector(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: researchSelectorKey)
    }
}

