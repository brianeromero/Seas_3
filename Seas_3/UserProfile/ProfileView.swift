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
    
    private let beltOptions = ["White", "Blue", "Purple", "Brown", "Black"]
    @State private var isEditing = false
    
    init(profileViewModel: ProfileViewModel) {
        _profileViewModel = ObservedObject(wrappedValue: profileViewModel)
    }
    
    var body: some View {
        VStack {
            // Canvas preview (replace with your actual preview)
            Rectangle()
                .fill(Color.gray)
                .frame(height: 150)
                .overlay(Text("Profile"))
            
            Form {
                Section(header: Text("Account Information")) {
                    HStack(alignment: .top) {
                        Text("Email:")
                        TextField("Email", text: $profileViewModel.email)
                            .disabled(!isEditing)
                            .foregroundColor(isEditing ? .primary : .gray)
                    }
                    
                    HStack(alignment: .top) {
                        Text("Username:")
                        TextField("Username", text: $profileViewModel.userName)
                            .disabled(!isEditing)
                            .foregroundColor(isEditing ? .primary : .gray)
                    }
                    
                    HStack(alignment: .top) {
                        Text("Name:")
                        TextField("Name", text: $profileViewModel.name)
                            .disabled(!isEditing)
                            .foregroundColor(isEditing ? .primary : .gray)
                    }
                }
                
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
                            }) {
                                Text(belt)
                            }
                        }
                    } label: {
                        HStack {
                            // Belt
                            Text(profileViewModel.belt.isEmpty ? "Select a belt" : profileViewModel.belt)
                                .foregroundColor(isEditing ? .primary : .gray)
                                .disabled(!isEditing)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("Password")) {
                    Toggle(isOn: $profileViewModel.showPasswordChange) {
                        Text("Change Password")
                    }
                    .disabled(!isEditing)
                    
                    if profileViewModel.showPasswordChange {
                        HStack(alignment: .top) {
                            Text("New Password:")
                            SecureField("New Password", text: $profileViewModel.newPassword)
                                .disabled(!isEditing)
                                .foregroundColor(isEditing ? .primary : .gray)
                        }
                        
                        HStack(alignment: .top) {
                            Text("Confirm Password:")
                            SecureField("Confirm Password", text: $profileViewModel.confirmPassword)
                                .disabled(!isEditing)
                                .foregroundColor(isEditing ? .primary : .gray)
                        }
                    }
                }
            }
            
            HStack {
                Button(action: {
                    isEditing.toggle()
                }) {
                    Text(isEditing ? "Cancel" : "Edit")
                }
                
                Button(action: {
                    Task {
                        await profileViewModel.updateProfile()
                        isEditing = false
                    }
                }) {
                    Text("Save")
                }
                .disabled(!isEditing)
            }
        }
        .onAppear {
            profileViewModel.loadProfile()
        }
    }
}


struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let viewContext = PersistenceController.preview.viewContext
        let profileViewModel = ProfileViewModel(viewContext: viewContext)
        
        // Set mock data for preview
        profileViewModel.email = "example@email.com"
        profileViewModel.userName = "john_doe"
        profileViewModel.name = "John Doe"
        profileViewModel.belt = "Black"
        profileViewModel.showPasswordChange = false
        
        return NavigationView {
            ProfileView(profileViewModel: profileViewModel)
        }
        .previewDisplayName("Profile View Preview")
    }
}
