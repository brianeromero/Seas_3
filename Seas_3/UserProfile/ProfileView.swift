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
        Group {
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
                                    Text(profileViewModel.belt.isEmpty ? "Select a belt" : profileViewModel.belt)
                                        .foregroundColor(isEditing ? .primary : .gray)
                                        .disabled(!isEditing)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }

                    // Buttons
                    HStack {
                        Button(action: toggleEdit) {
                            Text(isEditing ? "Cancel" : "Edit")
                        }

                        Button(action: saveChanges) {
                            Text("Save")
                        }
                        .disabled(!isEditing || !profileViewModel.validateProfile())
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
                    .padding(.top, 20)

                    // Navigation to Login
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
        .onAppear {
            Task {
                // Wait briefly to let AuthViewModel populate currentUser
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

                // Use AuthViewModel to get the current user
                authViewModel.getCurrentUser { userInfo in
                    if let userInfo = userInfo {
                        // Update the profileViewModel with all available fields
                        profileViewModel.email = userInfo.email
                        profileViewModel.userName = userInfo.userName
                        profileViewModel.name = userInfo.name
                        profileViewModel.belt = userInfo.belt ?? ""
                        profileViewModel.isVerified = userInfo.isVerified

                        profileViewModel.isProfileLoaded = true
                        
                        // Print all the info for debugging
                        print("Profile loaded for user: \(userInfo.userName)")
                        print("Email: \(userInfo.email)")
                        print("Name: \(userInfo.name)")
                        print("Belt: \(userInfo.belt ?? "None")")
                        print("Is Verified: \(userInfo.isVerified)")
                        print("UserID: \(userInfo.userID.uuidString)")
                    } else {
                        print("User not signed in yet — cannot load profile")
                    }
                }
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
        Task {
            await profileViewModel.updateProfile()
            isEditing = false
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
