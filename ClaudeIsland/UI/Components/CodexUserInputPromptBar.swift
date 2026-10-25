import SwiftUI

struct CodexUserInputPromptBar: View {
    let request: CodexUserInputRequest
    let isSubmitting: Bool
    let onSubmit: ([String: [String]]) -> Bool

    @StateObject private var preferences = NotchPreferences.shared
    @StateObject private var draft: CodexUserInputDraft
    @State private var submissionFailed = false

    private var questionIndex: Int { draft.currentQuestionIndex }

    init(
        request: CodexUserInputRequest,
        isSubmitting: Bool,
        onSubmit: @escaping ([String: [String]]) -> Bool
    ) {
        self.request = request
        self.isSubmitting = isSubmitting
        self.onSubmit = onSubmit
        _draft = StateObject(wrappedValue: CodexUserInputDraft(questions: request.questions))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if request.questions.indices.contains(questionIndex) {
                questionContent(request.questions[questionIndex])
            }

            if submissionFailed {
                Label(
                    preferences.language.text(
                        "Could not send the answer. You can still answer in Codex.",
                        "回答未能发送，请仍可在 Codex 原窗口中作答。"
                    ),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.orange.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.28))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("codex.nativeQuestionPrompt")
    }

    private func questionContent(_ question: CodexUserInputQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(question.header.isEmpty ? "Codex" : question.header)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(TerminalColors.amber)
                    Text(preferences.language.text(
                        "Codex native question · \(questionIndex + 1) / \(request.questions.count)",
                        "Codex 原生提问 · \(questionIndex + 1) / \(request.questions.count)"
                    ))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                if question.isSecret {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.48))
                        .accessibilityLabel(preferences.language.text("Secret answer", "保密回答"))
                }
            }

            Text(question.question)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 6) {
                    ForEach(question.selectableOptions) { option in
                        optionButton(option, at: questionIndex)
                    }

                    if question.allowsCustomAnswer {
                        customAnswerField(question, at: questionIndex)
                    }
                }
            }
            .frame(maxHeight: 190)

            HStack(spacing: 8) {
                if questionIndex > 0 {
                    actionButton(
                        preferences.language.text("Back", "上一步"),
                        systemImage: "chevron.left",
                        primary: false
                    ) {
                        draft.move(by: -1)
                        submissionFailed = false
                    }
                }
                Spacer()
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white.opacity(0.8))
                    Text(preferences.language.text("Sending…", "正在发送…"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                } else {
                    actionButton(
                        questionIndex == request.questions.count - 1
                            ? preferences.language.text("Answer", "提交回答")
                            : preferences.language.text("Next", "下一步"),
                        systemImage: questionIndex == request.questions.count - 1
                            ? "paperplane.fill" : "chevron.right",
                        primary: true
                    ) {
                        if questionIndex == request.questions.count - 1 {
                            guard let answers = draft.compiledAnswers else { return }
                            submissionFailed = !onSubmit(answers)
                        } else {
                            draft.move(by: 1)
                            submissionFailed = false
                        }
                    }
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.4)
                }
            }

            Text(preferences.language.text(
                "Sent through Codex app-server; not added as a chat message.",
                "通过 Codex app-server 直接回答，不会伪装成普通聊天消息。"
            ))
            .font(.system(size: 9))
            .foregroundColor(.white.opacity(0.35))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func optionButton(
        _ option: CodexUserInputOption,
        at index: Int
    ) -> some View {
        let isSelected = draft.selectedOptions[index] == option.label
        return Button {
            draft.selectOption(option.label, at: index)
            submissionFailed = false
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? TerminalColors.green : .white.opacity(0.35))
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    if !option.description.isEmpty {
                        Text(option.description)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? TerminalColors.green.opacity(0.14) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func customAnswerField(
        _ question: CodexUserInputQuestion,
        at index: Int
    ) -> some View {
        let placeholder = preferences.language.text("Other answer…", "其他答案…")
        Group {
            if question.isSecret {
                SecureField(placeholder, text: customAnswerBinding(at: index))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(placeholder)
            } else {
                TextField(placeholder, text: customAnswerBinding(at: index), axis: .vertical)
                    .lineLimit(1...4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(placeholder)
            }
        }
    }

    private func customAnswerBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { draft.customAnswers[index, default: ""] },
            set: {
                draft.setCustomAnswer($0, at: index)
                submissionFailed = false
            }
        )
    }

    private var canContinue: Bool {
        if questionIndex == request.questions.count - 1 {
            return draft.compiledAnswers != nil
        }
        return !draft.answer(at: questionIndex).isEmpty
    }

    private func actionButton(
        _ title: String,
        systemImage: String,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(primary ? .black : .white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(primary ? Color.white.opacity(0.95) : Color.white.opacity(0.09))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
