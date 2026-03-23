/// Stages in the AI editing pipeline. Each stage can be individually enabled/disabled.
public enum EditingStage: String, Sendable, CaseIterable, Codable {
    case fillerRemoval
    case backtrackCorrection
    case grammarCorrection
    case toneAdaptation
    case commandExecution
    case snippetExpansion
}
