import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var currentStep = 0

    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case 0:
                    WelcomeStepView { currentStep = 1 }
                case 1:
                    MicPermissionStepView { currentStep = 2 }
                case 2:
                    AccessibilityPermissionStepView { currentStep = 3 }
                case 3:
                    GlobeKeyStepView { currentStep = 4 }
                default:
                    AllSetStepView {
                        onboardingCompleted = true
                    }
                }
            }
            .frame(width: 480, height: 360)
        }
    }
}

#Preview {
    OnboardingView()
}
