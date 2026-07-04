import SwiftUI
import PhotosUI

struct ComposeView: View {
    let channels: [ChannelDto]
    var onPosted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var selectedChannel: ChannelDto?
    @State private var pollOptions: [String] = []
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isPosting = false
    @State private var errorMessage: String?
    @FocusState private var textFocused: Bool

    private var isPoll: Bool { !pollOptions.isEmpty }
    private var canPost: Bool {
        selectedChannel != nil &&
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (!isPoll || pollOptions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 2)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        channelPicker

                        TextField("いま何してる？匿名で共有しよう", text: $text, axis: .vertical)
                            .font(.body)
                            .lineLimit(5...12)
                            .padding(16)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.cardBorder, lineWidth: 1)
                            )
                            .focused($textFocused)

                        if let imageData, let uiImage = UIImage(data: imageData) {
                            imagePreview(uiImage)
                        }

                        if isPoll {
                            pollEditor
                        }

                        attachmentBar

                        if let errorMessage {
                            Text("⚠️ \(errorMessage)")
                                .font(.footnote)
                                .foregroundStyle(Theme.error)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("新規投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Theme.secondaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text("投稿")
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(Theme.gradient.opacity(canPost ? 1 : 0.35))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .disabled(!canPost || isPosting)
                }
            }
            .onAppear {
                if selectedChannel == nil { selectedChannel = channels.first }
                textFocused = true
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    guard let newItem else { return }
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        // Re-encode as JPEG: keeps uploads small and the backend format list simple.
                        if let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.8) {
                            imageData = jpeg
                            pollOptions = []
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var channelPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(channels) { channel in
                    let isSelected = selectedChannel?.slug == channel.slug
                    Button {
                        selectedChannel = channel
                    } label: {
                        Text("\(channel.emoji) \(channel.nameJa)")
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.card))
                            .foregroundStyle(isSelected ? .white : Theme.secondaryText)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(isSelected ? .clear : Theme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func imagePreview(_ uiImage: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Button {
                imageData = nil
                photoItem = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(8)
        }
    }

    private var pollEditor: some View {
        VStack(spacing: 8) {
            ForEach(pollOptions.indices, id: \.self) { index in
                HStack {
                    TextField("選択肢 \(index + 1)", text: $pollOptions[index])
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )
                    if pollOptions.count > 2 {
                        Button {
                            pollOptions.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
            }
            HStack {
                if pollOptions.count < 4 {
                    Button {
                        pollOptions.append("")
                    } label: {
                        Label("選択肢を追加", systemImage: "plus.circle")
                            .font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(Theme.accent)
                }
                Spacer()
                Button {
                    pollOptions = []
                } label: {
                    Label("アンケートを削除", systemImage: "trash")
                        .font(.footnote)
                }
                .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var attachmentBar: some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("画像", systemImage: "photo")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isPoll ? Theme.secondaryText.opacity(0.4) : Theme.accent)
            }
            .disabled(isPoll)

            Button {
                pollOptions = ["", ""]
                imageData = nil
                photoItem = nil
            } label: {
                Label("アンケート", systemImage: "chart.bar")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(imageData != nil || isPoll ? Theme.secondaryText.opacity(0.4) : Theme.accent)
            }
            .disabled(imageData != nil || isPoll)

            Spacer()

            Text("\(text.count)/1000")
                .font(.caption)
                .foregroundStyle(text.count > 1000 ? Theme.error : Theme.secondaryText)
        }
    }

    private func submit() async {
        guard let channel = selectedChannel else { return }
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }
        do {
            var imageUrl: String?
            if let imageData {
                imageUrl = try await APIClient.shared.uploadImage(imageData, mimeType: "image/jpeg")
            }
            let options = pollOptions
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            _ = try await APIClient.shared.createPost(
                .init(
                    channelSlug: channel.slug,
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageUrl: imageUrl,
                    poll: options.count >= 2 ? .init(options: options) : nil
                )
            )
            onPosted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
