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
    @EnvironmentObject var authenticationState: AuthenticationState

    @StateObject var profileViewModel: ProfileViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var selectedTabIndex: LoginViewSelection
    @Binding var navigationPath: NavigationPath

    let setupGlobalErrorHandler: () -> Void

    private let beltOptions = ["", "White", "Blue", "Purple", "Brown", "Black"]

    @State private var isEditing = false
    @State private var originalEmail = ""
    @State private var originalUserName = ""
    @State private var originalName = ""
    @State private var originalBelt = ""
    @State private var showMainContent = false
    @State private var navigateToAdminMenu = false
    @State private var showValidationAlert = false
    @State private var validationAlertMessage = ""
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var errorMessages: [ValidationType: String?] = [:]

    @FocusState private var focusedField: Field?

    // Delete account
    @State private var confirmDeleteChecked = false
    @State private var deleteMessage: String?
    @State private var deletePassword = ""
    @State private var showDeletePasswordField = false
    
    
    @State private var showSignOutConfirmation = false
    



    enum Field: Hashable { case email, username, name }
    enum ValidationType { case email, userName, name, password }

    var body: some View {
        VStack {
            if profileViewModel.isProfileLoaded && showMainContent {
                profileContent
            } else {
                ProgressView("Loading profile...")
            }
        }
        .navigationTitle("Profile")
        .toolbar { toolbarContent }
        .onAppear { handleAppear() }
        .onChange(of: authViewModel.userIsLoggedIn) { _, newValue in
            handleLoginChange(newValue)
        }
        .alert("Save Status", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveAlertMessage)
        }
        .alert("Validation Error", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationAlertMessage)
        }
    }
}

// MARK: - MAIN CONTENT
extension ProfileView {

    private var profileContent: some View {
        VStack {
            Rectangle()
                .fill(Color(uiColor: .systemGray5))
                .frame(height: 150)
                .overlay(
                    Text("Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                )

            Form {
                accountInfoSection
                beltSection

                if isEditing {
                    deleteAccountSection()
                }
            }

            signOutButton
        }
    }

    // MARK: - Account Info Section
    private var accountInfoSection: some View {
        Section(header: Text("Account Information")) {
            accountField(title: "Email:", text: $profileViewModel.email, error: errorMessages[.email] ?? nil, field: .email)
            accountField(title: "Username:", text: $profileViewModel.userName, error: errorMessages[.userName] ?? nil, field: .username)
            accountField(title: "Name:", text: $profileViewModel.name, error: errorMessages[.name] ?? nil, field: .name)
        }
    }

    private var beltSection: some View {
        Section(header: HStack {
            Text("Belt")
            Text("(Optional)").foregroundColor(.secondary).opacity(0.7)
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
    }

    // MARK: - Delete Account Section
    private func deleteAccountSection() -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $confirmDeleteChecked) {
                    Text("I understand this will permanently delete my account.")
                        .font(.subheadline)
                }

                if confirmDeleteChecked && showDeletePasswordField {
                    SecureField("Enter password to confirm", text: $deletePassword)
                        .textFieldStyle(.roundedBorder)
                }

                if let deleteMessage = deleteMessage {
                    Text(deleteMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button("Delete Account") {
                    Task {
                        guard confirmDeleteChecked else {
                            deleteMessage = "You must check the box to confirm deletion."
                            return
                        }

                        // First tap: show password field
                        if !showDeletePasswordField {
                            showDeletePasswordField = true
                            return
                        }

                        deleteMessage = "Deleting profile..."

                        do {
                            try await authViewModel.deleteUser(recentPassword: deletePassword)

                            // Reset fields
                            deletePassword = ""
                            showDeletePasswordField = false

                            // Clear navigation after delete
                            await MainActor.run {
                                navigationPath.removeLast(navigationPath.count)
                                selectedTabIndex = .login
                            }

                        } catch {
                            deleteMessage = "Failed to delete profile: \(error.localizedDescription)"
                        }
                    }
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(confirmDeleteChecked ? Color.red : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(40)
                .disabled(!confirmDeleteChecked)
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        VStack {
            Button(action: {
                showSignOutConfirmation = true
            }) {
                Text("Sign Out")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(40)
            }
            .disabled(isEditing)
            .padding(.horizontal)
            .padding(.top, 20)
        }
        .alert("Are you sure you want to sign out?",
               isPresented: $showSignOutConfirmation,
               actions: {
                    Button("Sign Out", role: .destructive) {
                        performSignOut()
                    }
                    Button("Cancel", role: .cancel) { }
               },
               message: {
                    Text("You will not have access to all features if you sign out.")
               })
    }

    
    private func performSignOut() {
        Task {
            do {
                try await authViewModel.logoutAndClearPath(path: $navigationPath)

                await MainActor.run {
                    profileViewModel.resetProfile()
                    profileViewModel.isProfileLoaded = false

                    authenticationState.isAuthenticated = false
                    authenticationState.didJustCreateAccount = false

                    // Force AppRootView to show restricted IslandMenu2
                    navigationPath.removeLast(navigationPath.count)
                    selectedTabIndex = .login
                }

                NotificationCenter.default.post(name: .userLoggedOut, object: nil)
            } catch {
                await MainActor.run {
                    saveAlertMessage = "Failed to sign out: \(error.localizedDescription)"
                    showSaveAlert = true
                }
            }
        }
    }


    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
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
                    isEditing = false
                }
            }
        }
    }

    // MARK: - On Appear
    private func handleAppear() {
        Task {
            await MainActor.run { showMainContent = false }

            if authViewModel.userIsLoggedIn {
                await profileViewModel.loadProfile()
            }

            await MainActor.run {
                showMainContent = authViewModel.userIsLoggedIn
            }
        }
    }

    private func handleLoginChange(_ loggedIn: Bool) {
        Task {
            await MainActor.run { showMainContent = false }

            if loggedIn {
                await profileViewModel.loadProfile()
            }

            await MainActor.run { showMainContent = loggedIn }
        }
    }
}

// MARK: - Actions / Validation
extension ProfileView {

    private func toggleEdit() {
        if isEditing { cancelEditing() }
        else { startEditing() }
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

        if errorMessages.values.contains(where: { $0 != nil }) {
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

    private func validateField(_ type: ValidationType) {
        switch type {
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

    // MARK: - Reusable Field
    @ViewBuilder
    private func accountField(title: String, text: Binding<String>, error: String?, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                TextField(title, text: text)
                    .disabled(!isEditing)
                    .foregroundColor(isEditing ? .primary : .secondary)
                    .focused($focusedField, equals: field)
                    .onChange(of: text.wrappedValue) { oldValue, newValue in
                        switch field {
                        case .email: validateField(.email)
                        case .username: validateField(.userName)
                        case .name: validateField(.name)
                        }
                    }
            }
            if let errorMessage = error, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
    }
}
