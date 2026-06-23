import SwiftUI
import SwiftData

struct NoteEditorView: View {
    var note: Note? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var isProtected = true

    init(note: Note? = nil) {
        self.note = note
        if let note {
            _title = State(initialValue: note.title)
            _content = State(initialValue: note.content)
            _isProtected = State(initialValue: note.isProtected)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Başlık") {
                    TextField("Not başlığı...", text: $title)
                }

                Section("İçerik") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }

                Section {
                    Toggle(isOn: $isProtected) {
                        Label("Yakınlık Koruması", systemImage: "hand.raised.fill")
                    }
                } footer: {
                    Text("Açıkken, içerik yalnızca telefonu yüzünüze tuttuğunuzda görünür.")
                }
            }
            .navigationTitle(note == nil ? "Yeni Not" : "Notu Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .fontWeight(.semibold)
                        .disabled(title.isEmpty && content.isEmpty)
                }
            }
        }
    }

    private func save() {
        if let note {
            note.title = title
            note.content = content
            note.isProtected = isProtected
        } else {
            let newNote = Note(title: title, content: content, isProtected: isProtected)
            modelContext.insert(newNote)
        }
        dismiss()
    }
}
