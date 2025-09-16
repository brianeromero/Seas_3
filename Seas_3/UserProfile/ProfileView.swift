//
//  ProfileView.swift
//  Seas_3
//

import SwiftUI
import CoreData
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var profileViewModel: ProfileViewModel
    @ObservedObject var authViewModel: AuthViewModel // Keep this for calling signOut()
    @Binding var selectedTabIndex: LoginViewSelection
    @Binding var navigationPath: NavigationPath // <-- ADD THIS LINE

    let setupGlobalErrorHandler: () -> Void // Dummy closure for preview

    private let beltOptions = ["", "White", "Blue", "Purple", "Brown", "Black"]
    @State private var isEditing = false
    @State private var originalEmail: String = ""
    @State private var originalUserName: String = ""
    @State private var originalName: String = ""
    @State private var originalBelt: String = ""
    @State private var showMainContent = false // Keep this state
    @State private var navigateToAdminMenu = false
    @StateObject private var pirateIslandViewModel = PirateIslandViewModel(persistenceController: PersistenceController.shared)
    @State private var showValidationAlert = false
    @State private var validationAlertMessage = ""
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    // Changed to String? for validation messages
    @State private var errorMessages: [ValidationType: String?] = [:]
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email, username, name
    }

    enum ValidationType {
        case email, userName, name, password
    }

    var body: some View {
        // REMOVE THE NavigationStack HERE
        VStack {
            // Add `&& showMainContent` to the condition
            if profileViewModel.isProfileLoaded && showMainContent {
                VStack {
                    Rectangle()
                        .fill(Color(uiColor: .systemGray5))
                        .frame(height: 150)
                        .overlay(
                            Text("Profile")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        )

                    Form {
                        Section(header: Text("Account Information")) {
                            // Email
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Email:")
                                    TextField("Email", text: $profileViewModel.email)
                                        .disabled(!isEditing)
                                        .foregroundColor(isEditing ? .primary : .secondary)
                                        .focused($focusedField, equals: .email)
                                        .onChange(of: profileViewModel.email) {
                                            validateField(.email)
                                        }
                                }
                                if let errorMessage = errorMessages[.email], errorMessage != nil {
                                    Text(errorMessage!)
                                        .foregroundColor(.red)
                                        .font(.footnote)
                                }
                            }

                            // Username
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Username:")
                                    TextField("Username", text: $profileViewModel.userName)
                                        .disabled(!isEditing)
                                        .foregroundColor(isEditing ? .primary : .secondary)
                                        .focused($focusedField, equals: .username)
                                        .onChange(of: profileViewModel.userName) {
                                            validateField(.userName)
                                        }
                                }
                                if let errorMessage = errorMessages[.userName], errorMessage != nil {
                                    Text(errorMessage!)
                                        .foregroundColor(.red)
                                        .font(.footnote)
                                }
                            }

                            // Name
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Name:")
                                    TextField("Name", text: $profileViewModel.name)
                                        .disabled(!isEditing)
                                        .foregroundColor(isEditing ? .primary : .secondary)
                                        .focused($focusedField, equals: .name)
                                        .onChange(of: profileViewModel.name) {
                                            validateField(.name)
                                        }
                                }
                                if let errorMessage = errorMessages[.name], errorMessage != nil {
                                    Text(errorMessage!)
                                        .foregroundColor(.red)
                                        .font(.footnote)
                                }
                            }
                        }

                        // Belt Selection
                        Section(header: HStack {
                            Text("Belt")
                            Text("(Optional)")
                                .foregroundColor(.secondary)
                                .opacity(0.7)
                        }) {
                            Menu {
                                ForEach(beltOptions, id: \.self) { belt in
                                    Button(action: {
                                        profileViewModel.belt = belt
                                    }) {
                                        Text(belt)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(profileViewModel.belt.isEmpty ? "Not selected" : profileViewModel.belt)
                                        .foregroundColor(isEditing ? .primary : .secondary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .disabled(!isEditing)
                        }
                    }

                    // Sign Out Button
                    Button(action: {
                        Task {
                            do {
                                // Replace the old signOut() call with the new function
                                try await authViewModel.logoutAndClearPath(path: $navigationPath)
                            } catch {
                                print("Error signing out from ProfileView: \(error.localizedDescription)")
                                saveAlertMessage = "Failed to sign out: \(error.localizedDescription)"
                                showSaveAlert = true
                            }
                        }
                    }) {
                        Text("Sign Out")
                            .font(.headline)
                            .padding()
                            .frame(minWidth: 335)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(40)
                    }
                    .disabled(isEditing)
                    .padding(.top, 20)
                }
            } else {
                ProgressView("Loading profile...")
                    .foregroundColor(.primary)
            }
        }
        .navigationTitle("Profile") // Keep navigationTitle here
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                    }
                } else {
                    Button("Edit") {
                        toggleEdit()
                    }
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("Cancel") {
                        cancelEditing() // Call cancelEditing to revert changes
                        isEditing.toggle() // Then toggle editing mode
                    }
                }
            }
        }
        .onAppear {
            Task {
                // Small delay to allow the view hierarchy to settle, then load profile
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                await profileViewModel.loadProfile()
                // Set original values once the profile is loaded
                startEditing() // Initialize original values
                showMainContent = true // Set to true after content is loaded and ready
            }
        }
        .alert(isPresented: $showSaveAlert) {
            Alert(title: Text("Save Status"), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
        }
        .alert(isPresented: $showValidationAlert) {
            Alert(title: Text("Validation Error"), message: Text(validationAlertMessage), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Helper Functions

    private func navigateToLoginPage() {
        profileViewModel.resetProfile()
    }

    private func toggleEdit() {
        if isEditing {
            // If currently editing, and we toggle, it means we're cancelling
            cancelEditing()
        } else {
            // If not editing, and we toggle, it means we're starting to edit
            startEditing()
        }
        isEditing.toggle()
    }

    private func startEditing() {
        originalEmail = profileViewModel.email
        originalUserName = profileViewModel.userName
        originalName = profileViewModel.name
        originalBelt = profileViewModel.belt
    }

    private func cancelEditing() {
        profileViewModel.email = originalEmail
        profileViewModel.userName = originalUserName
        profileViewModel.name = originalName
        profileViewModel.belt = originalBelt
        errorMessages = [:] // Clear validation errors on cancel
    }

    private func saveChanges() {
        guard authViewModel.currentUser != nil else {
            saveAlertMessage = "User not authenticated. Please log in first."
            showSaveAlert = true
            return
        }

        validateField(.email)
        validateField(.userName)
        validateField(.name)

        // Check if there are any *non-nil* error messages
        let hasErrors = errorMessages.values.contains { $0 != nil }

        if hasErrors {
            validationAlertMessage = "Please fix the validation errors before saving."
            showValidationAlert = true
            return
        }

        Task {
            do {
                try await profileViewModel.updateProfile()
                saveAlertMessage = "Profile saved successfully!"
                showSaveAlert = true
                isEditing = false
                errorMessages = [:] // Clear validation errors on successful save
            } catch {
                saveAlertMessage = "Failed to save profile: \(error.localizedDescription)"
                showSaveAlert = true
            }
        }
    }

    private func validateField(_ fieldType: ValidationType) {
        switch fieldType {
        case .email:
            errorMessages[.email] = profileViewModel.validateEmail(profileViewModel.email)
        case .userName:
            errorMessages[.userName] = profileViewModel.validateUserName(profileViewModel.userName)
        case .name:
            errorMessages[.name] = profileViewModel.validateName(profileViewModel.name)
        case .password:
            // Assuming you have logic for password changes elsewhere,
            // or pass the correct password field for validation if it's new/confirm
            errorMessages[.password] = profileViewModel.validatePassword(profileViewModel.newPassword)
        }
    }
}
