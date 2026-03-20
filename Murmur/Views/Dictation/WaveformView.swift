import SwiftUI

struct WaveformView: View {
    var amplitudes: [Float] = Array(repeating: 0.1, count: 20)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(amplitudes.enumerated()), id: \.offset) { _, amplitude in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.tint)
                    .frame(width: 4, height: max(4, CGFloat(amplitude) * 40))
            }
        }
        .frame(height: 40)
    }
}

#Preview {
    WaveformView(amplitudes: (0..<20).map { _ in Float.random(in: 0.1...1.0) })
        .padding()
}
