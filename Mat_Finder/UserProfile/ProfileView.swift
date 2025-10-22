//
//  ProfileView.swift
//  Mat_Finder
//

import SwiftUI
import CoreData
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore



struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var profileViewModel: ProfileViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var selectedTabIndex: LoginViewSelection
    @Binding var navigationPath: NavigationPath

    let setupGlobalErrorHandler: () -> Void

    private let beltOptions = ["", "White", "Blue", "Purple", "Brown", "Black"]
    @State private var isEditing = false
    @State private var originalEmail: String = ""
    @State private var originalUserName: String = ""
    @State private var originalName: String = ""
    @State private var originalBelt: String = ""
    @State private var showMainContent = false
    @State private var navigateToAdminMenu = false
    @StateObject private var pirateIslandViewModel = PirateIslandViewModel(persistenceController: PersistenceController.shared)
    @State private var showValidationAlert = false
    @State private var validationAlertMessage = ""
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var errorMessages: [ValidationType: String?] = [:]
    @FocusState private var focusedField: Field?

    // MARK: - Delete Account Section
    @State private var confirmDeleteChecked = false
    @State private var deleteMessage: String?
    @State private var deletePassword: String = ""           // password for reauth
    @State private var showDeletePasswordField: Bool = false // show password field after first click

    enum Field: Hashable {
        case email, username, name
    }

    enum ValidationType {
        case email, userName, name, password
    }

    var body: some View {
        VStack {
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
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Email:")
                                    TextField("Email", text: $profileViewModel.email)
                                        .disabled(!isEditing)
                                        .foregroundColor(isEditing ? .primary : .secondary)
                                        .focused($focusedField, equals: .email)
                                        .onChange(of: profileViewModel.email) { _ in
                                            validateField(.email)
                                        }
                                }
                                if let errorMessage = errorMessages[.email], errorMessage != nil {
                                    Text(errorMessage!)
                                        .foregroundColor(.red)
                                        .font(.footnote)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Username:")
                                    TextField("Username", text: $profileViewModel.userName)
                                        .disabled(!isEditing)
                                        .foregroundColor(isEditing ? .primary : .secondary)
                                        .focused($focusedField, equals: .username)
                                        .onChange(of: profileViewModel.userName) { _ in
                                            validateField(.userName)
                                        }
                                }
                                if let errorMessage = errorMessages[.userName], errorMessage != nil {
                                    Text(errorMessage!)
                                        .foregroundColor(.red)
                                        .font(.footnote)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Name:")
                                    TextField("Name", text: $profileViewModel.name)
                                        .disabled(!isEditing)
                                        .foregroundColor(isEditing ? .primary : .secondary)
                                        .focused($focusedField, equals: .name)
                                        .onChange(of: profileViewModel.name) { _ in
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

                        Section(header: HStack {
                            Text("Belt")
                            Text("(Optional)")
                                .foregroundColor(.secondary)
                                .opacity(0.7)
                        }) {
                            Menu {
                                ForEach(beltOptions, id: \.self) { belt in
                                    Button(belt) { profileViewModel.belt = belt }
                                }
                            } label: {
                                HStack {
                                    Text(profileViewModel.belt.isEmpty ? "Not selected" : profileViewModel.belt)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                }
                            }
                            .disabled(!isEditing)
                        }

                        // Delete Account Section
                        if isEditing {
                            Section {
                                VStack(alignment: .leading, spacing: 10) {
                                    Toggle(isOn: $confirmDeleteChecked) {
                                        Text("I understand this will permanently delete my account.")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                    }

                                    if confirmDeleteChecked && showDeletePasswordField {
                                        SecureField("Enter password to confirm", text: $deletePassword)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }

                                    if let deleteMessage = deleteMessage {
                                        Text(deleteMessage)
                                            .foregroundColor(.red)
                                            .font(.footnote)
                                    }

                                    Button(action: {
                                        Task {
                                            guard confirmDeleteChecked else {
                                                deleteMessage = "You must check the box to confirm deletion."
                                                return
                                            }

                                            // Show password field on first click
                                            if !showDeletePasswordField {
                                                showDeletePasswordField = true
                                                return
                                            }

                                            deleteMessage = "Deleting profile..."
                                            do {
                                                try await authViewModel.deleteUser(recentPassword: deletePassword)
                                                // Navigate back to login page
                                                navigationPath.removeLast(navigationPath.count)
                                                selectedTabIndex = .login
                                            } catch {
                                                deleteMessage = "Failed to delete profile: \(error.localizedDescription)"
                                            }
                                        }
                                    }) {
                                        Text("Delete Account")
                                            .font(.headline)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(confirmDeleteChecked ? Color.red : Color.gray)
                                            .foregroundColor(.white)
                                            .cornerRadius(40)
                                    }
                                    .disabled(!confirmDeleteChecked)
                                }
                                .padding(.vertical, 10)
                            }
                        }
                    }

                    // Sign Out button
                    Button(action: {
                        Task {
                            do {
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
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") { saveChanges() }
                } else {
                    Button("Edit") { toggleEdit() }
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("Cancel") {
                        cancelEditing()
                        isEditing.toggle()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await profileViewModel.loadProfile()
                showMainContent = true
            }
        }
        .onChange(of: authViewModel.userIsLoggedIn) { isLoggedIn in
            if isLoggedIn {
                Task {
                    showMainContent = false
                    await profileViewModel.loadProfile()
                    showMainContent = true
                }
            } else {
                showMainContent = false
                profileViewModel.resetProfile()
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
    private func toggleEdit() {
        if isEditing { cancelEditing() } else { startEditing() }
        isEditing.toggle()
    }

    private func startEditing() {
        profileViewModel.email = profileViewModel.currentUser?.email ?? ""
        profileViewModel.userName = profileViewModel.currentUser?.userName ?? ""
        profileViewModel.name = profileViewModel.currentUser?.name ?? ""
        profileViewModel.belt = profileViewModel.currentUser?.belt ?? ""

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
        errorMessages = [:]
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

        let hasErrors = errorMessages.values.contains { $0 != nil }
        if hasErrors {
            validationAlertMessage = "Please fix the validation errors before saving."
            showValidationAlert = true
            return
        }

        profileViewModel.currentUser?.email = profileViewModel.email
        profileViewModel.currentUser?.userName = profileViewModel.userName
        profileViewModel.currentUser?.name = profileViewModel.name
        profileViewModel.currentUser?.belt = profileViewModel.belt

        Task {
            do {
                try await profileViewModel.updateProfile()
                saveAlertMessage = "Profile saved successfully!"
                showSaveAlert = true
                isEditing = false
                errorMessages = [:]
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
            errorMessages[.password] = profileViewModel.validatePassword(profileViewModel.newPassword)
        }
    }
}
