//
//  ContentView.swift
//  open-sidenotes
//
//  Created by 李晨洋 on 2024/12/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var noteStore = NoteStore()
    @State private var selectedNote: Note?
    @State private var newTitle: String = ""
    @State private var newContent: String = ""
    @State private var isEditing: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // 笔记列表
            VStack(alignment: .leading) {
                HStack {
                    Text("Notes")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        newTitle = ""
                        newContent = ""
                        isEditing = false
                        selectedNote = nil
                    }) {
                        Image(systemName: "plus")
                    }
                }
                .padding([.top, .horizontal])
                List(selection: $selectedNote) {
                    ForEach(noteStore.notes) { note in
                        VStack(alignment: .leading) {
                            Text(note.title).font(.body).bold()
                            Text(note.content).font(.caption).lineLimit(1)
                        }
                        .tag(note as Note?)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedNote = note
                            newTitle = note.title
                            newContent = note.content
                            isEditing = true
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let note = noteStore.notes[index]
                            noteStore.deleteNote(note)
                            if selectedNote == note {
                                selectedNote = nil
                                isEditing = false
                            }
                        }
                    }
                }
            }
            .frame(width: 220)
            .background(Color(.windowBackgroundColor))
            Divider()
            // 编辑/新建区
            VStack(alignment: .leading) {
                if isEditing || selectedNote == nil {
                    TextField("Title", text: $newTitle)
                        .font(.title2)
                        .padding(.top)
                    TextEditor(text: $newContent)
                        .font(.body)
                        .border(Color.gray.opacity(0.2))
                    HStack {
                        if isEditing, let note = selectedNote {
                            Button("Save") {
                                noteStore.updateNote(note, title: newTitle, content: newContent)
                            }
                            Button("Delete") {
                                noteStore.deleteNote(note)
                                selectedNote = nil
                                isEditing = false
                            }
                            .foregroundColor(.red)
                        } else {
                            Button("Add Note") {
                                noteStore.addNote(title: newTitle, content: newContent)
                                newTitle = ""
                                newContent = ""
                            }
                        }
                        Spacer()
                    }
                } else {
                    Text("Select or create a note")
                        .foregroundColor(.secondary)
                        .padding()
                }
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
