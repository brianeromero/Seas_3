//
//  AddNewIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

// MARK: - Import Statements
import SwiftUI
import CoreData
import Combine

struct AddNewIsland: View {
    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    // MARK: - Observed Objects
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var islandDetails = IslandDetails() // Updated to ObservedObject

    // MARK: - State Variables
    @State private var isSaveEnabled = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showToast = false
    @State private var toastMessage = ""

    // MARK: - Initialization
    init(viewModel: PirateIslandViewModel, profileViewModel: ProfileViewModel) {
        self.islandViewModel = viewModel
        self.profileViewModel = profileViewModel
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                islandFormSection
                enteredBySection
                saveButton
                cancelButton
            }
            .navigationBarTitle("Add New Gym", displayMode: .inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                validateFields()
            }
            .overlay(toastOverlay)
        }
    }

    // MARK: - Extracted Views
    private var islandFormSection: some View {
        Section(header: Text("Gym Details")) {
            TextField("Island Name", text: $islandDetails.islandName)
            TextField("Street", text: $islandDetails.street)
            TextField("City", text: $islandDetails.city)
            TextField("State", text: $islandDetails.state)
            TextField("Zip Code", text: $islandDetails.zip)
            TextField("Website", text: $islandDetails.gymWebsite)
                .onChange(of: islandDetails.gymWebsite) { newValue in
                    islandDetails.gymWebsiteURL = URL(string: newValue)
                }
        }
    }

    private var enteredBySection: some View {
        Section(header: Text("Entered By")) {
            Text(profileViewModel.name)
                .foregroundColor(.primary)
                .padding()
        }
    }

    private var saveButton: some View {
        Button("Save") {
            Task {
                await saveIsland()
            }
        }
        .disabled(!isSaveEnabled)
        .padding()
    }

    private var cancelButton: some View {
        Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
        }
        .padding()
    }

    private var toastOverlay: some View {
        Group {
            if showToast {
                withAnimation {
                    ToastView(showToast: $showToast, message: toastMessage)
                        .transition(.move(edge: .bottom))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showToast = false
                            }
                        }
                }
            }
        }
    }

    // MARK: - Private Methods
    private func saveIsland() async {
        guard !islandDetails.islandName.isEmpty,
              !islandDetails.street.isEmpty,
              !islandDetails.city.isEmpty,
              !islandDetails.state.isEmpty,
              !islandDetails.zip.isEmpty else {
            showToast = true
            toastMessage = "Please fill in all fields."
            return
        }

        let result = await islandViewModel.createPirateIslandAsync(
            islandDetails: islandDetails,
            createdByUserId: profileViewModel.name,
            gymWebsiteURL: islandDetails.gymWebsiteURL
        )

        switch result {
        case .success:
            clearFields()
        case .failure(let error):
            showToast = true
            toastMessage = error.localizedDescription
        }
    }

    private func validateFields() {
        isSaveEnabled = !islandDetails.islandName.isEmpty &&
                        !islandDetails.street.isEmpty &&
                        !islandDetails.city.isEmpty &&
                        !islandDetails.state.isEmpty &&
                        !islandDetails.zip.isEmpty
    }

    private func clearFields() {
        islandDetails.islandName = ""
        islandDetails.street = ""
        islandDetails.city = ""
        islandDetails.state = ""
        islandDetails.zip = ""
        islandDetails.gymWebsite = ""
        islandDetails.gymWebsiteURL = nil
    }
}

// MARK: - PreviewProvider
struct AddNewIsland_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let profileViewModel = ProfileViewModel(
            viewContext: PersistenceController.preview.container.viewContext,
            authViewModel: AuthViewModel.shared
        )
        profileViewModel.name = "Brian Romero" // Example name for preview
        return AddNewIsland(
            viewModel: PirateIslandViewModel(persistenceController: persistenceController),
            profileViewModel: profileViewModel
        )
    }
}
