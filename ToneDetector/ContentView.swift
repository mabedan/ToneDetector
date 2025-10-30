import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = ToneMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Toggle(isOn: Binding(
                    get: { monitor.enabled },
                    set: { _ in monitor.toggle() }
                )) {
                    Text(monitor.enabled ? "Listening…" : "Disabled")
                }
                .toggleStyle(.switch)

                Spacer()

                // Status message if app is disabled due to LLM unavailability
                if let status = monitor.statusMessage, !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                } else {
                    // Agreeableness indicator
                    Group {
                        if let agreeable = monitor.isAgreeable {
                            if agreeable {
                                Text("Agreeable")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                HStack(spacing: 6) {
                                    Text("Disagreeable")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                    if let reason = monitor.disagreeableReason, !reason.isEmpty {
                                        Text("— \(reason)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else {
                            Text("No tone yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            ScrollView {
                Text(monitor.liveText.isEmpty
                     ? "Transcript will appear here…"
                     : monitor.liveText)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.gray.opacity(0.08))
                    .cornerRadius(8)
            }.frame(minHeight: 160)

            // Bad tone transcripts section
            if !monitor.badToneTranscripts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Bad Tone Transcripts")
                            .font(.headline)
                            .foregroundStyle(.red)

                        Spacer()

                        Button("Clear") {
                            monitor.clearBadToneTranscripts()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(monitor.badToneTranscripts.reversed()) { transcript in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(transcript.timestamp, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if let reason = transcript.reason, !reason.isEmpty {
                                            Text("— \(reason)")
                                                .font(.caption)
                                                .foregroundStyle(.red)
                                        }
                                    }

                                    Text(transcript.text)
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(6)
                                        .background(.red.opacity(0.08))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 400)
    }
}

