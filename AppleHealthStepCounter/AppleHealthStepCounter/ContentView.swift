import SwiftUI

struct ContentView: View {
    @StateObject private var manager = HealthKitManager()
    @State private var dailyGoal: Int = 10_000
    @State private var showGoalEditor = false

    private var progress: Double {
        min(Double(manager.stepCount) / Double(dailyGoal), 1.0)
    }

    private var progressColor: Color {
        switch progress {
        case 0..<0.4: return .red
        case 0.4..<0.7: return .orange
        case 0.7..<1.0: return .yellow
        default: return .green
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                if !manager.isHealthKitAvailable {
                    unavailableView
                } else if !manager.isAuthorized {
                    authorizationView
                } else {
                    stepCountView
                }
            }
            .padding()
            .navigationTitle("Step Counter")
            .toolbar {
                if manager.isAuthorized {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Goal: \(dailyGoal.formatted())") {
                            showGoalEditor = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showGoalEditor) {
                GoalEditorView(dailyGoal: $dailyGoal)
            }
        }
        .task {
            await manager.requestAuthorization()
        }
    }

    private var stepCountView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 22)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 22, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

                VStack(spacing: 6) {
                    Text("\(manager.stepCount.formatted())")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.4), value: manager.stepCount)
                    Text("steps today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 280, height: 280)

            statsCard

            Button {
                Task { await manager.fetchTodaySteps() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            if let error = manager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var statsCard: some View {
        VStack(spacing: 12) {
            statRow(
                icon: "flag.fill",
                label: "Goal",
                value: "\(dailyGoal.formatted()) steps"
            )
            Divider()
            statRow(
                icon: "figure.walk",
                label: "Remaining",
                value: remainingText,
                valueColor: remainingColor
            )
            Divider()
            statRow(
                icon: "chart.bar.fill",
                label: "Progress",
                value: "\(Int(progress * 100))%",
                valueColor: progressColor
            )
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statRow(icon: String, label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
        }
    }

    private var remainingText: String {
        let remaining = max(dailyGoal - manager.stepCount, 0)
        return remaining == 0 ? "Goal reached!" : "\(remaining.formatted()) steps"
    }

    private var remainingColor: Color {
        max(dailyGoal - manager.stepCount, 0) == 0 ? .green : .primary
    }

    private var authorizationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 72))
                .foregroundStyle(.red)
            Text("Connect Apple Health")
                .font(.title2.bold())
            Text("Allow access to your step data to start tracking your daily activity in real time.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Allow Health Access") {
                Task { await manager.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)

            if let error = manager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange)
            Text("HealthKit Unavailable")
                .font(.title2.bold())
            Text("Apple Health is not available on this device.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

struct GoalEditorView: View {
    @Binding var dailyGoal: Int
    @Environment(\.dismiss) private var dismiss
    @State private var goalText = ""

    private let presets = [5_000, 7_500, 10_000, 12_500, 15_000, 20_000]

    var body: some View {
        NavigationStack {
            Form {
                Section("Custom Goal") {
                    TextField("Number of steps", text: $goalText)
                        .keyboardType(.numberPad)
                }
                Section("Presets") {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            dailyGoal = preset
                            dismiss()
                        } label: {
                            HStack {
                                Text("\(preset.formatted()) steps")
                                Spacer()
                                if preset == dailyGoal {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Daily Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let value = Int(goalText), value > 0 {
                            dailyGoal = value
                        }
                        dismiss()
                    }
                }
            }
            .onAppear { goalText = "\(dailyGoal)" }
        }
    }
}

#Preview {
    ContentView()
}
