#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct NativeBetaLearningCard: View {
    var state: BetaLearningState
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(TSDPalette.sage.opacity(0.30))
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.title2)
                        .foregroundStyle(TSDPalette.moss)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text("14 天记忆验证")
                        .font(.headline)
                        .foregroundStyle(TSDPalette.ink)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(TSDPalette.inkSoft)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TSDPalette.moss)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("betaLearning.open")
    }

    private var statusText: String {
        switch state.experiment.phase() {
        case .baseline:
            "看看 TSD 是否真的让一段时间不再模糊"
        case .waiting(let daysRemaining):
            "已开始 · \(daysRemaining) 天后做第二次回忆"
        case .finalFreeRecall:
            "Day 14 已到 · 先凭自己回想"
        case .timelineAssistedRecall:
            state.experiment.didOpenTimelineForFinal
                ? "最后一步 · 记录 Timeline 帮你想起多少"
                : "自由回忆完成 · 再让 Timeline 帮你"
        case .completed:
            "验证完成 · 查看你的记忆变化"
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct NativeBetaLearningCenter: View {
    @Binding var store: NativeShellStore
    @Binding var state: BetaLearningState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    privacyBoundary
                    experimentContent
                    Divider().opacity(0.5)
                    NativeGentleReminderSettings(
                        state: $state,
                        hasMemories: !store.slices.isEmpty
                    )
                }
                .padding(18)
                .padding(.bottom, 28)
            }
            .background(TSDPalette.canvas)
            .navigationTitle("让时间留下证据")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var privacyBoundary: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(TSDPalette.moss)
            Text("只在本机保存次数、日期和 1–5 分量表；不保存你想起了谁、发生了什么，也不读取照片内容。")
                .font(.caption)
                .foregroundStyle(TSDPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(TSDPalette.sage.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("betaLearning.privacyBoundary")
    }

    @ViewBuilder
    private var experimentContent: some View {
        switch state.experiment.phase() {
        case .baseline:
            NativeMemoryAssessmentForm(
                eyebrow: "DAY 0 · 先不看 Timeline",
                title: "凭记忆回想过去两周",
                note: "不用写下内容，只数一数能清楚讲出的具体瞬间。",
                actionTitle: "保存 Day 0",
                actionIdentifier: "betaLearning.baseline.save"
            ) { assessment in
                state.completeBaseline(assessment)
            }
        case .waiting(let daysRemaining):
            waitingView(daysRemaining: daysRemaining)
        case .finalFreeRecall:
            NativeMemoryAssessmentForm(
                eyebrow: "DAY 14 · 仍先不看 Timeline",
                title: "再凭自己回想过去两周",
                note: "这一步完成后，TSD 才会请你打开 Timeline。",
                actionTitle: "保存自由回忆",
                actionIdentifier: "betaLearning.finalFree.save"
            ) { assessment in
                state.completeFinalFreeRecall(assessment)
            }
        case .timelineAssistedRecall:
            assistedRecallView
        case .completed:
            completedView
        }
    }

    private func waitingView(daysRemaining: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("实验已经开始")
                .font(.title2.bold())
                .foregroundStyle(TSDPalette.ink)
            Text("接下来正常使用 TSD。没有连续打卡，也没有欠下的任务。")
                .font(.body)
                .foregroundStyle(TSDPalette.inkSoft)
            Label("\(daysRemaining) 天后，再做一次两分钟回忆", systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TSDPalette.moss)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityIdentifier("betaLearning.waiting")
    }

    @ViewBuilder
    private var assistedRecallView: some View {
        if !state.experiment.didOpenTimelineForFinal {
            VStack(alignment: .leading, spacing: 14) {
                Text("现在，让 Timeline 帮你")
                    .font(.title2.bold())
                    .foregroundStyle(TSDPalette.ink)
                Text("浏览真实切片和影像锚点。回来后只填写又想起了几个瞬间，不必透露内容。")
                    .font(.body)
                    .foregroundStyle(TSDPalette.inkSoft)
                Button {
                    state.markFinalTimelineOpened()
                    store.selectedRoute = .slices
                    dismiss()
                } label: {
                    Label("打开 Timeline", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(TSDPalette.moss)
                .controlSize(.large)
                .accessibilityIdentifier("betaLearning.timeline.open")
            }
        } else {
            NativeAssistedAssessmentForm { additionalCount, blurScore in
                state.completeExperiment(
                    assistedAdditionalMomentCount: additionalCount,
                    assistedBlurScore: blurScore
                )
            }
        }
    }

    private var completedView: some View {
        let baseline = state.experiment.baseline
        let final = state.experiment.finalFreeRecall
        let total = state.experiment.totalFinalMomentCount
        return VStack(alignment: .leading, spacing: 16) {
            Label("这段时间有了轮廓", systemImage: "checkmark.seal.fill")
                .font(.title2.bold())
                .foregroundStyle(TSDPalette.mossDeep)
            HStack(spacing: 12) {
                NativeBetaResultMetric(
                    value: "\(baseline?.specificMomentCount ?? 0)",
                    title: "Day 0 想起"
                )
                NativeBetaResultMetric(
                    value: "\(total ?? final?.specificMomentCount ?? 0)",
                    title: "Day 14 最终"
                )
            }
            Text("其中 Timeline 又唤回 \(state.experiment.assistedAdditionalMomentCount ?? 0) 个具体瞬间。这里不判断生活好坏，只验证记忆是否不再是一团模糊。")
                .font(.body)
                .foregroundStyle(TSDPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("betaLearning.completed")
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeMemoryAssessmentForm: View {
    var eyebrow: String
    var title: String
    var note: String
    var actionTitle: String
    var actionIdentifier: String
    var onSave: (BetaMemoryAssessment) -> Void

    @State private var momentCount = 0
    @State private var detailScore = 3
    @State private var blurScore = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .foregroundStyle(TSDPalette.moss)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(TSDPalette.ink)
            Text(note)
                .font(.body)
                .foregroundStyle(TSDPalette.inkSoft)

            NativeBetaStepper(
                title: "能清楚讲出的具体瞬间",
                value: $momentCount,
                range: 0...100,
                suffix: "个",
                identifier: "betaLearning.assessment.moments"
            )
            NativeBetaStepper(
                title: "细节清楚程度",
                value: $detailScore,
                range: 1...5,
                suffix: "/ 5",
                identifier: "betaLearning.assessment.detail"
            )
            NativeBetaStepper(
                title: "这两周有多模糊",
                value: $blurScore,
                range: 1...5,
                suffix: "/ 5",
                identifier: "betaLearning.assessment.blur"
            )

            Text("模糊度：1 = 很清楚，5 = 像一段重复的日子")
                .font(.caption)
                .foregroundStyle(TSDPalette.inkSoft)
            Button(actionTitle) {
                onSave(BetaMemoryAssessment(
                    specificMomentCount: momentCount,
                    detailScore: detailScore,
                    blurScore: blurScore
                ))
            }
            .buttonStyle(.borderedProminent)
            .tint(TSDPalette.moss)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier(actionIdentifier)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAssistedAssessmentForm: View {
    var onSave: (Int, Int) -> Void
    @State private var additionalCount = 0
    @State private var blurScore = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TIMELINE 辅助后")
                .font(.caption.weight(.bold))
                .foregroundStyle(TSDPalette.moss)
            Text("它又帮你找回多少？")
                .font(.title2.bold())
                .foregroundStyle(TSDPalette.ink)
            NativeBetaStepper(
                title: "额外想起的具体瞬间",
                value: $additionalCount,
                range: 0...100,
                suffix: "个",
                identifier: "betaLearning.assisted.moments"
            )
            NativeBetaStepper(
                title: "现在还有多模糊",
                value: $blurScore,
                range: 1...5,
                suffix: "/ 5",
                identifier: "betaLearning.assisted.blur"
            )
            Button("完成 14 天验证") {
                onSave(additionalCount, blurScore)
            }
            .buttonStyle(.borderedProminent)
            .tint(TSDPalette.moss)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("betaLearning.assisted.save")
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeBetaStepper: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var suffix: String
    var identifier: String

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Text(title)
                    .foregroundStyle(TSDPalette.ink)
                Spacer()
                Text("\(value) \(suffix)")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(TSDPalette.mossDeep)
            }
        }
        .padding(14)
        .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier(identifier)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeBetaResultMetric: View {
    var value: String
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(TSDPalette.mossDeep)
            Text(title)
                .font(.caption)
                .foregroundStyle(TSDPalette.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeGentleReminderSettings: View {
    @Binding var state: BetaLearningState
    var hasMemories: Bool
    @State private var message: String?
    @State private var isUpdating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("温柔提醒")
                        .font(.headline)
                        .foregroundStyle(TSDPalette.ink)
                    Text("不计连续天数，不产生欠账")
                        .font(.caption)
                        .foregroundStyle(TSDPalette.inkSoft)
                }
                Spacer()
                Image(systemName: "bell.badge.waveform")
                    .foregroundStyle(TSDPalette.moss)
            }

            if state.reminders.isEnabled {
                DatePicker("提醒时间", selection: reminderTime, displayedComponents: .hourAndMinute)
                Toggle("周末把占位补清楚", isOn: weekendToggle)
                Toggle("有记忆时，偶尔轻轻回望", isOn: revisitToggle)
            }

            if state.reminders.isEnabled {
                Button("关闭提醒") {
                    Task { await toggleReminders() }
                }
                .buttonStyle(.bordered)
                .tint(TSDPalette.moss)
                .disabled(isUpdating)
                .accessibilityIdentifier("betaLearning.reminders.toggle")
            } else {
                Button("打开温柔提醒") {
                    Task { await toggleReminders() }
                }
                .buttonStyle(.borderedProminent)
                .tint(TSDPalette.moss)
                .disabled(isUpdating)
                .accessibilityIdentifier("betaLearning.reminders.toggle")
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(TSDPalette.inkSoft)
                    .accessibilityIdentifier("betaLearning.reminders.status")
            }
        }
        .padding(16)
        .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .task {
            let authorization = await GentleReminderService.currentAuthorization()
            guard authorization != state.reminders.authorization else { return }
            var preferences = state.reminders
            preferences.authorization = authorization
            if authorization == .denied { preferences.isEnabled = false }
            state.updateReminders(preferences, recordEvent: false)
            if authorization == .denied {
                try? await GentleReminderService.apply(
                    preferences: preferences,
                    hasMemories: hasMemories
                )
            }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(
                    hour: state.reminders.dailyHour,
                    minute: state.reminders.dailyMinute
                )) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                var preferences = state.reminders
                preferences.dailyHour = components.hour ?? preferences.dailyHour
                preferences.dailyMinute = components.minute ?? preferences.dailyMinute
                updateAndApply(preferences)
            }
        )
    }

    private var weekendToggle: Binding<Bool> {
        Binding(
            get: { state.reminders.includesWeekendCompletion },
            set: { enabled in
                var preferences = state.reminders
                preferences.includesWeekendCompletion = enabled
                updateAndApply(preferences)
            }
        )
    }

    private var revisitToggle: Binding<Bool> {
        Binding(
            get: { state.reminders.includesGentleRevisit },
            set: { enabled in
                var preferences = state.reminders
                preferences.includesGentleRevisit = enabled
                updateAndApply(preferences)
            }
        )
    }

    @MainActor
    private func toggleReminders() async {
        isUpdating = true
        defer { isUpdating = false }
        var preferences = state.reminders
        if preferences.isEnabled {
            preferences.isEnabled = false
            state.updateReminders(preferences)
            try? await GentleReminderService.apply(
                preferences: preferences,
                hasMemories: hasMemories
            )
            message = "提醒已关闭。没有中断，也没有欠下任何记录。"
            return
        }

        let authorization = await GentleReminderService.requestAuthorization()
        preferences.authorization = authorization
        preferences.isEnabled = authorization == .granted
        state.updateReminders(preferences)
        guard authorization == .granted else {
            message = "系统没有允许通知。TSD 会保持安静，你仍可随时回来。"
            return
        }
        do {
            try await GentleReminderService.apply(
                preferences: preferences,
                hasMemories: hasMemories
            )
            message = "已安排为无声音、无角标的轻提醒。"
        } catch {
            preferences.isEnabled = false
            state.updateReminders(preferences)
            try? await GentleReminderService.apply(
                preferences: preferences,
                hasMemories: hasMemories
            )
            message = "提醒暂时没有安排成功，请稍后再试。"
        }
    }

    private func updateAndApply(_ preferences: BetaReminderPreferences) {
        state.updateReminders(preferences, recordEvent: false)
        Task {
            try? await GentleReminderService.apply(
                preferences: preferences,
                hasMemories: hasMemories
            )
        }
    }
}
#endif
