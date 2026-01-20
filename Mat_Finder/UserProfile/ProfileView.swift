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
    @State private var isNavigatingBack = false

    enum Field: Hashable { case email, username, name }
    enum ValidationType { case email, userName, name, password }

    // MARK: - Derived State
    private var isProfileLoaded: Bool {
        if case .loaded = profileViewModel.loadState { true } else { false }
    }


    var body: some View {
        VStack {
            if isProfileLoaded {
                profileContent
            } else if !authViewModel.userIsLoggedIn {
                Text("You are now logged out")
                    .onAppear {
                        guard !isNavigatingBack else { return }
                        isNavigatingBack = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            navigationPath.removeLast(navigationPath.count)
                        }
                    }
            } else {
                ProgressView("Loading profile...")
            }
        }
        .navigationTitle("Profile")
        .toolbar { toolbarContent }
        .onAppear { handleAppear() }

        // ⏳ Timeout safety
        .task {
            for _ in 0..<50 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if isProfileLoaded { return }
            }

            if authViewModel.userIsLoggedIn && !isProfileLoaded {
                saveAlertMessage = "Profile could not be loaded. Please try again."
                showSaveAlert = true
            }
        }

        // iOS 17-safe
        .onChange(of: profileViewModel.loadState) { _, newValue in
            if case .loaded = newValue {
                showSaveAlert = false
            }
        }

        // Reload if user changes
        .onChange(of: authViewModel.currentUser?.userID) { _, newUserID in
            guard let userID = newUserID else { return }
            Task { await profileViewModel.loadProfile(for: userID) }
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

    // Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if isEditing { Button("Save") { saveChanges() } }
            else { Button("Edit") { toggleEdit() } }
        }

        ToolbarItem(placement: .navigationBarLeading) {
            if isEditing { Button("Cancel") { cancelEditing(); isEditing = false } }
        }
    }

    private func handleAppear() {
        guard authViewModel.userIsLoggedIn,
              let userID = authViewModel.currentUser?.userID else { return }

        Task {
            await profileViewModel.loadProfile(for: userID)
        }
    }

}


// MARK: - Account Info Section
extension ProfileView {

    private var accountInfoSection: some View {
        Section(header: Text("Account Information")) {
            accountField(
                title: "Email:",
                text: $profileViewModel.email,
                error: errorMessages[.email] ?? nil,
                field: .email
            )

            accountField(
                title: "Username:",
                text: $profileViewModel.userName,
                error: errorMessages[.userName] ?? nil,
                field: .username
            )

            accountField(
                title: "Name:",
                text: $profileViewModel.name,
                error: errorMessages[.name] ?? nil,
                field: .name
            )
        }
    }
}


extension ProfileView {

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
}


extension ProfileView {

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

                        if !showDeletePasswordField {
                            showDeletePasswordField = true
                            return
                        }

                        deleteMessage = "Deleting profile..."

                        do {
                            try await authViewModel.deleteUser(recentPassword: deletePassword)

                            deletePassword = ""
                            showDeletePasswordField = false

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
}


extension ProfileView {

    private var signOutButton: some View {
        VStack {
            Button {
                showSignOutConfirmation = true
            } label: {
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
        .alert(
            "Are you sure you want to sign out?",
            isPresented: $showSignOutConfirmation
        ) {
            Button("Sign Out", role: .destructive) {
                performSignOut()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You will not have access to all features if you sign out.")
        }
    }

    private func performSignOut() {
        Task {
            do {
                try await authViewModel.logout()
                profileViewModel.reset()
                navigationPath.removeLast(navigationPath.count)
            } catch {
                saveAlertMessage = "Failed to sign out: \(error.localizedDescription)"
                showSaveAlert = true
            }
        }
    }
}


extension ProfileView {

    private func toggleEdit() {
        if isEditing { cancelEditing() }
        else { startEditing() }
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
        errorMessages = [:]
    }

    private func saveChanges() {
        Task {
            do {
                try await profileViewModel.updateProfile(using: authViewModel)
                saveAlertMessage = "Profile saved successfully!"
                showSaveAlert = true
                isEditing = false
            } catch {
                saveAlertMessage = error.localizedDescription
                showSaveAlert = true
            }
        }
    }
}


extension ProfileView {

    @ViewBuilder
    private func accountField(
        title: String,
        text: Binding<String>,
        error: String?,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: text)
                .disabled(!isEditing)
                .focused($focusedField, equals: field)

            if let error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
    }
}
