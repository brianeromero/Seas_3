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
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var selectedTabIndex: LoginViewSelection
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
    @State private var navigateToLogin = false
    @State private var showValidationAlert = false
    @State private var validationAlertMessage = ""
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var errorMessages: [ValidationType: String] = [:]
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email, username, name
    }

    enum ValidationType {
        case email, userName, name, password
    }

    var body: some View {
        NavigationStack {
            VStack {
                if profileViewModel.isProfileLoaded {
                    VStack {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 150)
                            .overlay(Text("Profile"))
                        
                        Form {
                            Section(header: Text("Account Information")) {
                                // Email
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Email:")
                                        TextField("Email", text: $profileViewModel.email)
                                            .disabled(!isEditing)
                                            .foregroundColor(isEditing ? .primary : .gray)
                                            .focused($focusedField, equals: .email)
                                            .onChange(of: profileViewModel.email) { _ in
                                                validateField(.email)
                                            }
                                    }
                                    if let errorMessage = errorMessages[.email] {
                                        Text(errorMessage)
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
                                            .foregroundColor(isEditing ? .primary : .gray)
                                            .focused($focusedField, equals: .username)
                                            .onChange(of: profileViewModel.userName) { _ in
                                                validateField(.userName)
                                            }
                                    }
                                    if let errorMessage = errorMessages[.userName] {
                                        Text(errorMessage)
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
                                            .foregroundColor(isEditing ? .primary : .gray)
                                            .focused($focusedField, equals: .name)
                                            .onChange(of: profileViewModel.name) { _ in
                                                validateField(.name)
                                            }
                                    }
                                    if let errorMessage = errorMessages[.name] {
                                        Text(errorMessage)
                                            .foregroundColor(.red)
                                            .font(.footnote)
                                    }
                                }
                            }

                            // Belt Selection
                            Section(header: HStack {
                                Text("Belt")
                                Text("(Optional)").foregroundColor(.gray).opacity(0.7)
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
                                            .foregroundColor(isEditing ? .primary : .gray)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .disabled(!isEditing)
                            }
                        }

                        // Sign Out
                        Button(action: {
                            Task {
                                await authViewModel.signOut()
                                navigateToLoginPage()
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

                        NavigationLink(
                            destination: LoginView(
                                islandViewModel: pirateIslandViewModel,
                                profileViewModel: profileViewModel,
                                isSelected: $selectedTabIndex,
                                navigateToAdminMenu: $navigateToAdminMenu,
                                isLoggedIn: $profileViewModel.isLoggedIn
                            )
                            .environment(\.managedObjectContext, viewContext)
                            .environmentObject(authViewModel)
                            .onAppear {
                                setupGlobalErrorHandler()
                            },
                            isActive: $navigateToLogin
                        ) {
                            EmptyView()
                        }
                    }
                } else {
                    ProgressView("Loading profile...")
                }
            }
            .navigationTitle("Profile")
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
                            toggleEdit()
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await profileViewModel.loadProfile()
                }
            }
            .alert(isPresented: $showSaveAlert) {
                Alert(title: Text("Save Status"), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showValidationAlert) {
                Alert(title: Text("Validation Error"), message: Text(validationAlertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - Helper Functions

    private func navigateToLoginPage() {
        profileViewModel.resetProfile()
        navigateToLogin = true
    }

    private func toggleEdit() {
        if isEditing {
            cancelEditing()
        } else {
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
    }

    private func saveChanges() {
        guard authViewModel.currentUser != nil else {
            saveAlertMessage = "User not authenticated. Please log in first."
            showSaveAlert = true
            return
        }

        let isValid = profileViewModel.validateProfile()

        if !isValid {
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
            errorMessages[.password] = profileViewModel.validatePassword(profileViewModel.password)
        }
    }
}
