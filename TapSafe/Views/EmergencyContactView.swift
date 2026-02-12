//
//  EmergencyContactView.swift
//  TapSafe
//
//  Set or edit emergency contact (name + phone).
//

import SwiftUI

struct EmergencyContactView: View {
    @Binding var contact: EmergencyContact?
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var phoneNumber: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    TextField("Phone", text: $phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Emergency Contact")
                } footer: {
                    Text("If you don’t respond to a check-in, we’ll open a message to this contact with your GPS location.")
                }
            }
            .navigationTitle("Emergency Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveContact()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let c = contact {
                    name = c.name
                    phoneNumber = c.phoneNumber
                }
            }
        }
    }
    
    private func saveContact() {
        contact = EmergencyContact(
            name: name.trimmingCharacters(in: .whitespaces),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespaces)
        )
        dismiss()
    }
}

#Preview {
    EmergencyContactView(contact: .constant(nil))
}
