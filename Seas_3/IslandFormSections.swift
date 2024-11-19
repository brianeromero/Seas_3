import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation

struct CountryAddressFormat {
    let requiredFields: [AddressField]
    let zipValidationRegex: String?
}

let countryAddressFormats: [String: CountryAddressFormat] = {
    var formats = [String: CountryAddressFormat]()
    for (country, fields) in addressFieldRequirements {
        formats[country] = CountryAddressFormat(
            requiredFields: fields.map { AddressField(rawValue: $0.rawValue) ?? .street },
            zipValidationRegex: getZipValidationRegex(for: country)
        )
    }
    return formats
}()

let zipRegexPatterns: [String: String] = [
    // Americas
    "US": "^\\d{5}(-\\d{4})?$", // United States (12345 or 12345-6789)
    "CA": "^([ABCEGHJKLMNPRSTVXY]\\d[ABCEGHJKLMNPRSTVWXYZ] {0,1}\\d[ABCEGHJKLMNPRSTVWXYZ]\\d)$", // Canada (A1A 1A1)
    "BR": "^\\d{8}$", // Brazil (12345678)
    "MX": "^\\d{5}$", // Mexico (12345)
    
    // Europe
    "GB": "^([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9]?[A-Za-z]))))\\s?[0-9][A-Za-z]{2})$", // United Kingdom (Postcode)
    "FR": "^\\d{5}$", // France (12345)
    "DE": "^\\d{5}$", // Germany (12345)
    "ES": "^\\d{5}$", // Spain (12345)
    "IT": "^\\d{5}$", // Italy (12345)
    
    // Asia
    "CN": "^\\d{6}$", // China (123456)
    "JP": "^\\d{3}-\\d{4}$", // Japan (123-4567)
    "IN": "^\\d{6}$", // India (123456)
    "KR": "^\\d{5}-\\d{4}$", // South Korea (12345-6789)
    
    // Africa
    "EG": "^\\d{5}$", // Egypt (12345)
    "ZA": "^\\d{4}$", // South Africa (1234)
    "NG": "^\\d{6}$", // Nigeria (123456)
    
    // Oceania
    "AU": "^\\d{4}$", // Australia (1234)
    
    // Additional countries
    "AE": "^\\d{5}$", // United Arab Emirates (12345)
    "IL": "^\\d{5}$", // Israel (12345)
    "CL": "^\\d{7}$", // Chile (1234567)
    "CO": "^\\d{6}$", // Colombia (123456)
    "TR": "^\\d{5}$", // Turkey (12345)
    "TH": "^\\d{5}$", // Thailand (12345)
    "SA": "^\\d{5}$", // Saudi Arabia (12345)
    "PK": "^\\d{5}$", // Pakistan (12345)
    "VN": "^\\d{6}$", // Vietnam (123456)
    "PH": "^\\d{4}$", // Philippines (1234)
    "ID": "^\\d{5}$", // Indonesia (12345)
    "AR": "^\\d{8}$", // Argentina (12345678)
    "RU": "^\\d{6}$" // Russia (123456)
]

func getZipValidationRegex(for country: String) -> String? {
    return zipRegexPatterns[country]
}

struct IslandFormSections: View {
    @ObservedObject var viewModel: PirateIslandViewModel
    @Binding var islandName: String
    @Binding var street: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zip: String
    @Binding var province: String
    @Binding var postalCode: String
    @Binding var gymWebsite: String
    @Binding var gymWebsiteURL: URL?
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @Binding var selectedCountry: Country?
    @Binding var islandDetails: IslandDetails // Binding to IslandDetails

    @State private var region: String = ""
    @State private var countries: [Country] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showValidationMessage = false
    @State private var postcode: String = ""
    @State private var governorate: String = ""
    @State private var county: String = ""

    init(
        viewModel: PirateIslandViewModel,
        islandName: Binding<String>,
        street: Binding<String>,
        city: Binding<String>,
        state: Binding<String>,
        zip: Binding<String>,
        province: Binding<String>,
        postalCode: Binding<String>,
        gymWebsite: Binding<String>,
        gymWebsiteURL: Binding<URL?>, // Binding for URL
        selectedCountry: Binding<Country?>,
        showAlert: Binding<Bool>,
        alertMessage: Binding<String>,
        islandDetails: Binding<IslandDetails> // Binding for IslandDetails
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _islandName = islandName
        _street = street
        _city = city
        _state = state
        _zip = zip
        _province = province
        _postalCode = postalCode
        _gymWebsite = gymWebsite
        _gymWebsiteURL = gymWebsiteURL
        _selectedCountry = selectedCountry
        _showAlert = showAlert
        _alertMessage = alertMessage
        _islandDetails = islandDetails
    }

    
    var body: some View {
        VStack(spacing: 10) {
            UnifiedCountryPickerView(selectedCountry: $selectedCountry)
            islandDetailsSection
            websiteSection
        }
        .padding()
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear(perform: fetchCountries)
    }


    var islandDetailsSection: some View {
        Section(header: Text("Gym Details").fontWeight(.bold)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gym Name")
                TextField("Enter Gym Name", text: $islandName)
                    .onChange(of: islandName) { newValue in
                        print("Island Name changed: \(newValue)")
                        Task {
                            await validateGymDetails() // You can call your validation here
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // Dynamically render required fields based on selected country
                ForEach(requiredFields(for: selectedCountry), id: \.self) { field in
                    addressField(for: field)
                }

                if showValidationMessage {
                    Text("Required fields for \(String(describing: selectedCountry?.name.common)) are missing.")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
    }
    
    func requiredFields(for country: Country?) -> [AddressField] {
        // Return an empty list if the country is nil
        guard let country = country else { return [] }

        // Attempt to retrieve the address format for the given country code (cca2)
        if let format = countryAddressFormats[country.cca2] {
            // Return the required fields for the country-specific address format
            return format.requiredFields
        }

        // Default fallback for unsupported or unlisted countries
        return [.street, .city, .state, .postalCode]
    }


    // Inside IslandFormSections
    func addressField(for field: AddressField) -> some View {
        VStack(alignment: .leading) {
            Text(field.rawValue.capitalized)
            TextField("Enter \(field.rawValue.capitalized)",
                      text: AddressBindingHelper.binding(for: field, islandDetails: $islandDetails))
            .onChange(of: AddressBindingHelper.binding(for: field, islandDetails: $islandDetails).wrappedValue) { _ in
                Task {
                    await validateGymDetails()
                }
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .modifierForField(field)
        }
    }
    

    func binding(for field: AddressField) -> Binding<String> {
        switch field {
        case .street:
            return $street
        case .city:
            return $city
        case .postalCode, .postcode:
            return $postalCode
        case .pincode:
            return $postalCode // Assuming `pincode` maps to `postalCode`
        case .zip:
            return $zip
        case .state:
            return $state
        case .province:
            return $province
        case .region, .district, .department, .emirate:
            return $region // Bind region if available, else provide a placeholder
        case .county:
            return $county
        case .governorate:
            return $governorate
        case .neighborhood:
            return .constant("") // Placeholder for neighborhood
        case .complement:
            return .constant("") // Placeholder for complement
        case .block:
            return .constant("") // Placeholder for block
        case .apartment:
            return .constant("") // Placeholder for apartment
        case .country:
            return .constant("") // Placeholder for country (or implement actual binding if available)
        @unknown default:
            fatalError("Unhandled AddressField: \(field.rawValue)")
        }
    }


    var websiteSection: some View {
        Section(header: Text("Gym Website").fontWeight(.bold)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gym Website/Facebook/Instagram")
                TextField("Enter Website or Facebook or Instagram URL", text: $gymWebsite, onEditingChanged: { _ in
                    processWebsiteURL()
                })
                .keyboardType(.URL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
        }
    }

    func fetchCountries() {
        // Replace this with your actual country fetching logic (API or hardcoded data)
        CountryService.shared.fetchCountries { fetchedCountries in
            if let fetchedCountries = fetchedCountries {
                DispatchQueue.main.async {
                    self.countries = fetchedCountries.sorted { $0.name.common < $1.name.common }
                    self.selectedCountry = self.countries.first { $0.cca2 == "US" } ?? self.countries.first!
                }
            }
        }
    }

    func validateGymDetails() async {
        guard !islandName.isEmpty else {
            setError("Gym name is required.")
            return
        }

        guard let selectedCountry = selectedCountry else {
            setError("Select a country.")
            return
        }

        let requiredFields = requiredFields(for: selectedCountry)
        let allFieldsValid = requiredFields.allSatisfy { !binding(for: $0).wrappedValue.isEmpty }
        let zipValid = isValidZip(zip, regex: countryAddressFormats[selectedCountry.cca2]?.zipValidationRegex)

        if !(allFieldsValid && zipValid) {
            setError("Required fields for \(selectedCountry.name.common) are missing or invalid.")
        } else {
            await updateIslandLocation()
        }
    }



    func setError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func updateIslandLocation() async {
        // Update island location data in view model
        do {
            try await viewModel.saveIslandData(
                islandName,
                street,
                city,
                state,
                zip,
                website: gymWebsiteURL
            )
        } catch {
            self.errorMessage = "Error updating island location: \(error.localizedDescription)"
            self.showError = true
        }
    }
    
    func isValidZip(_ zip: String, regex: String?) -> Bool {
        guard let regex = regex else { return true }
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: zip)
    }

    func validateGymNameAndAddress() -> Bool {
        // Validation logic to ensure fields are not empty
        return !islandName.isEmpty && !street.isEmpty && !city.isEmpty && !state.isEmpty && !zip.isEmpty
    }

    private func validateAddress() -> Bool {
        !street.isEmpty && !city.isEmpty && !state.isEmpty && !zip.isEmpty && isValidZip(zip, regex: countryAddressFormats[selectedCountry?.cca2 ?? "US"]?.zipValidationRegex)
    }


    func processWebsiteURL() {
        guard !gymWebsite.isEmpty else {
            gymWebsiteURL = nil
            return
        }
        let strippedURL = stripProtocol(from: gymWebsite)
        let fullURLString = "https://" + strippedURL // Default to HTTPS

        if validateURL(fullURLString) {
            gymWebsiteURL = URL(string: fullURLString)
        } else {
            showAlert = true
            alertMessage = "Invalid URL format"
            gymWebsite = ""
            gymWebsiteURL = nil
        }
    }


    private func stripProtocol(from urlString: String) -> String {
        if urlString.lowercased().starts(with: "http://") {
            return String(urlString.dropFirst(7))
        } else if urlString.lowercased().starts(with: "https://") {
            return String(urlString.dropFirst(8))
        }
        return urlString
    }

    private func validateURL(_ urlString: String) -> Bool {
        return URL(string: urlString) != nil
    }


    private func validateFields() -> Bool {
        guard !islandName.isEmpty else {
            errorMessage = "Gym name is required."
            return false
        }

        guard !street.isEmpty, !city.isEmpty, !state.isEmpty, !zip.isEmpty else {
            errorMessage = "Street, city, state, and zip are required when gym name is entered."
            return false
        }

        return true
    }

    func saveButtonAction() async {
        if !validateFields() {
            showError = true
        } else {
            do {
                // Ensure gymWebsiteURL is passed properly
                try await viewModel.saveIslandData(
                    islandName,
                    street,
                    city,
                    state,
                    zip,
                    website: gymWebsiteURL
                )
                print("Island data saved successfully")
            } catch {
                print("Error saving island data: \(error.localizedDescription)")
                self.errorMessage = "Error saving island data: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }

    func fetchAddressFromGymName(_ gymName: String) async {
        guard !gymName.isEmpty else { return }
        
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(gymName)
            guard let placemark = placemarks.first else { return }

            // Update address fields with resolved location data
            if let streetName = placemark.thoroughfare {
                street = streetName
            }
            if let cityName = placemark.locality {
                city = cityName
            }
            if let stateName = placemark.administrativeArea {
                state = stateName
            }
            if let postalCode = placemark.postalCode {
                zip = postalCode
            }
            if let countryName = placemark.country {
                selectedCountry = Country(name: Country.Name(common: countryName), cca2: "US")
            }

        } catch {
            self.errorMessage = "Failed to fetch address: \(error.localizedDescription)"
            self.showError = true
        }
    }
}

extension View {
    func modifierForField(_ field: AddressField) -> some View {
        switch field {
        case .zip, .postalCode, .postcode, .pincode:
            return self.keyboardType(.numberPad).eraseToAnyView()
        case .region, .district, .department, .emirate, .governorate:
            return self.autocapitalization(.allCharacters).eraseToAnyView()
        case .neighborhood, .complement, .apartment:
            return self.autocapitalization(.sentences).eraseToAnyView()
        default:
            return self.eraseToAnyView()
        }
    }
}



extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}

struct IslandFormSections_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Empty form
            VStack {
                IslandFormSections(
                    viewModel: PirateIslandViewModel(persistenceController: PersistenceController.preview),
                    islandName: .constant(""),
                    street: .constant(""),
                    city: .constant(""),
                    state: .constant(""),
                    zip: .constant(""),
                    province: .constant(""),
                    postalCode: .constant(""),
                    gymWebsite: .constant(""),
                    gymWebsiteURL: .constant(nil),
                    selectedCountry: .constant(Country(name: Country.Name(common: "United States"), cca2: "US")),
                    showAlert: .constant(false),
                    alertMessage: .constant(""),
                    islandDetails: .constant(IslandDetails()) // Use .constant with a placeholder IslandDetails object
                )
            }
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Empty Form")

            // Filled form (US)
            VStack {
                IslandFormSections(
                    viewModel: PirateIslandViewModel(persistenceController: PersistenceController.preview),
                    islandName: .constant("My Gym"),
                    street: .constant("123 Main St"),
                    city: .constant("Anytown"),
                    state: .constant("CA"),
                    zip: .constant("12345"),
                    province: .constant(""),
                    postalCode: .constant(""),
                    gymWebsite: .constant("example.com"),
                    gymWebsiteURL: .constant(URL(string: "https://example.com")),
                    selectedCountry: .constant(Country(name: Country.Name(common: "United States"), cca2: "US")),
                    showAlert: .constant(false),
                    alertMessage: .constant(""),
                    islandDetails: .constant(IslandDetails()) // Add the islandDetails binding here
                )
            }
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Filled Form (US)")

            // Filled form (Canada)
            VStack {
                IslandFormSections(
                    viewModel: PirateIslandViewModel(persistenceController: PersistenceController.preview),
                    islandName: .constant("My Gym"),
                    street: .constant("123 Main St"),
                    city: .constant("Anytown"),
                    state: .constant("ON"),
                    zip: .constant(""),
                    province: .constant("Ontario"),
                    postalCode: .constant("M5V"),
                    gymWebsite: .constant("example.com"),
                    gymWebsiteURL: .constant(URL(string: "https://example.com")),
                    selectedCountry: .constant(Country(name: Country.Name(common: "Canada"), cca2: "CA")),
                    showAlert: .constant(false),
                    alertMessage: .constant(""),
                    islandDetails: .constant(IslandDetails()) // Add the islandDetails binding here
                )
            }
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Filled Form (Canada)")

            // Invalid form
            VStack {
                IslandFormSections(
                    viewModel: PirateIslandViewModel(persistenceController: PersistenceController.preview),
                    islandName: .constant("My Gym"),
                    street: .constant(""),
                    city: .constant(""),
                    state: .constant(""),
                    zip: .constant(""),
                    province: .constant(""),
                    postalCode: .constant(""),
                    gymWebsite: .constant("example.com"),
                    gymWebsiteURL: .constant(URL(string: "https://example.com")),
                    selectedCountry: .constant(Country(name: Country.Name(common: "United States"), cca2: "US")),
                    showAlert: .constant(false),
                    alertMessage: .constant(""),
                    islandDetails: .constant(IslandDetails()) // Add the islandDetails binding here
                )
            }
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Invalid Form")
        }
    }
}
