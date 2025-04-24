//
//  ProfileView.swift
//  Seas_3
//

import SwiftUI
import CoreData
import Firebase

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var profileViewModel: ProfileViewModel
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
        case email
        case username
        case name
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
                                    VStack(alignment: .leading) {
                                        // Email
                                        HStack(alignment: .top) {
                                            Text("Email:")
                                            TextField("Email", text: $profileViewModel.email)
                                                .disabled(!isEditing)
                                                .foregroundColor(isEditing ? .primary : .gray)
                                                .focused($focusedField, equals: .email)
                                                .onChange(of: profileViewModel.email) { _ in
                                                    validateField(.email)
                                                    print("Email changed to: \(profileViewModel.email)")
                                                }

                                            if let errorMessage = errorMessages[.email] {
                                                Text(errorMessage)
                                                    .foregroundColor(.red)
                                                    .font(.footnote)
                                            }
                                        }

                                        // Username
                                        HStack(alignment: .top) {
                                            Text("Username:")
                                            TextField("Username", text: $profileViewModel.userName)
                                                .disabled(!isEditing)
                                                .foregroundColor(isEditing ? .primary : .gray)
                                                .focused($focusedField, equals: .username)
                                                .onChange(of: profileViewModel.userName) { _ in
                                                    validateField(.userName)
                                                    print("Username changed to: \(profileViewModel.userName)")
                                                }

                                            if let errorMessage = errorMessages[.userName] {
                                                Text(errorMessage)
                                                    .foregroundColor(.red)
                                                    .font(.footnote)
                                            }
                                        }

                                        // Name
                                        HStack(alignment: .top) {
                                            Text("Name:")
                                            TextField("Name", text: $profileViewModel.name)
                                                .disabled(!isEditing)
                                                .foregroundColor(isEditing ? .primary : .gray)
                                                .focused($focusedField, equals: .name)
                                                .onChange(of: profileViewModel.name) { _ in
                                                    validateField(.name)
                                                    print("Name changed to: \(profileViewModel.name)")
                                                }

                                            if let errorMessage = errorMessages[.name] {
                                                Text(errorMessage)
                                                    .foregroundColor(.red)
                                                    .font(.footnote)
                                            }
                                        }
                                    }
                                }

                                // Belt Selection
                                Section(header: HStack {
                                    Text("Belt")
                                    Text("(Optional)")
                                        .foregroundColor(.gray)
                                        .opacity(0.7)
                                }) {
                                    Menu {
                                        ForEach(beltOptions, id: \.self) { belt in
                                            Button(action: {
                                                profileViewModel.belt = belt
                                                print("Belt selected: \(belt)")
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
                            authViewModel.signOut {
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
                        .padding(.top, 20)                    // Navigation Link to Login
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

                    if let userInfo = await authViewModel.getCurrentUser() {
                        profileViewModel.email = userInfo.email
                        profileViewModel.userName = userInfo.userName
                        profileViewModel.name = userInfo.name
                        profileViewModel.belt = userInfo.belt ?? ""
                        profileViewModel.isVerified = userInfo.isVerified
                        profileViewModel.isProfileLoaded = true
                    } else {
                        print("User not signed in yet — cannot load profile")
                    }
                }
            }
            .alert(isPresented: $showSaveAlert) {
                Alert(title: Text("Save Status"),
                      message: Text(saveAlertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showValidationAlert) {
                Alert(
                    title: Text("Validation Error"),
                    message: Text(validationAlertMessage),
                    dismissButton: .default(Text("OK"))
                )
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
        print("Save changes button tapped")
        guard let user = authViewModel.currentUser else {
            print("User not authenticated - cannot save changes")
            saveAlertMessage = "User not authenticated. Please log in first."
            showSaveAlert = true
            return
        }
        
        print("Authenticated user: \(user.userID ?? "Unknown User")")
        print("Validating profile...")
        let isValid = profileViewModel.validateProfile()
        print("Validation result: \(isValid)")
        print("Validation passed: \(isValid)")

        if !isValid {
            print("Validation failed - showing alert")
            validationAlertMessage = "Please fix the validation errors before saving."
            showValidationAlert = true
            return
        }

        print("Validation succeeded - proceeding with profile update")
        Task {
            do {
                print("Calling updateProfile()")
                try await profileViewModel.updateProfile()
                print("Profile update completed successfully")
                saveAlertMessage = "Profile saved successfully!"
                showSaveAlert = true
                isEditing = false
                print("Profile saved and editing mode disabled")
            } catch {
                print("Error during profile update: \(error.localizedDescription)")
                saveAlertMessage = "Failed to save profile: \(error.localizedDescription)"
                showSaveAlert = true
                print("Error alert will be shown to user")
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
        print("Error for \(fieldType): \(errorMessages[fieldType] ?? "No error")")
    }
}


// MARK: - Preview

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let viewContext = PersistenceController.preview.viewContext
        let profileViewModel = ProfileViewModel(viewContext: viewContext)
        let authViewModel = AuthViewModel()

        profileViewModel.email = "example@email.com"
        profileViewModel.userName = "john_doe"
        profileViewModel.name = "John Doe"
        profileViewModel.belt = "Black"
        profileViewModel.showPasswordChange = false

        @State var selectedTabIndex: LoginViewSelection = .login

        return NavigationView {
            ProfileView(
                profileViewModel: profileViewModel,
                authViewModel: authViewModel,
                selectedTabIndex: $selectedTabIndex,
                setupGlobalErrorHandler: {}
            )
        }
        .previewDisplayName("Profile View Preview")
    }
}
