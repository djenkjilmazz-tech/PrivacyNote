import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle("PrivacyNote")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                NoteEditorView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.doc")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
            Text("Gizli Notunuz Yok")
                .font(.title2.weight(.semibold))
            Text("Notlarınız yakınlık sensörü ile korunur.\nOkumak için telefonu yüzünüze yaklaştırın.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showingEditor = true
            } label: {
                Label("İlk Notu Oluştur", systemImage: "plus")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
    }

    private var notesList: some View {
        List {
            ForEach(notes) { note in
                NavigationLink {
                    NoteDetailView(note: note)
                } label: {
                    NoteRowView(note: note)
                }
            }
            .onDelete(perform: deleteNotes)
        }
        .listStyle(.insetGrouped)
    }

    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(notes[index])
            }
        }
    }
}

private struct NoteRowView: View {
    let note: Note

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(note.isProtected ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: note.isProtected ? "lock.fill" : "doc.text.fill")
                    .foregroundStyle(note.isProtected ? .orange : .blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Başlıksız" : note.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}
