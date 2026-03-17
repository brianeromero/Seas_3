//
//  DisciplinePicker.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/12/26.
//

import SwiftUI


enum Discipline: String, CaseIterable, Identifiable {

    case openMat     // ⭐ NEW
    case bjjGi
    case bjjNoGi
    case mma
    case wrestling
    case judo
    case striking
    case mobility

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openMat: return "Open Mat"
        case .bjjGi: return "Gi"
        case .bjjNoGi: return "No-Gi"
        case .mma: return "MMA"
        case .wrestling: return "Wrestling"
        case .judo: return "Judo"
        case .striking: return "Striking"
        case .mobility: return "Mobility"
        }
    }

    var badgeColor: String {
        switch self {
        case .openMat: return "gray"
        case .bjjGi: return "blue"
        case .bjjNoGi: return "teal"
        case .mma: return "purple"
        case .wrestling: return "orange"
        case .judo: return "indigo"
        case .striking: return "red"
        case .mobility: return "green"
        }
    }
}

enum Style: String, CaseIterable, Identifiable {
    
    case competition
    case advanced

    case sparring
    case drilling
    case fundamentals
    case conditioning

    case muayThai
    case kickboxing
    case kravMaga
    case selfDefense
    case boxing
    case cardioKickboxing
    case stretching
    case flow
    case recovery
    case yoga

    case custom   // ⭐ ADD

    var id: String { rawValue }

    var displayName: String {
        switch self {

        case .competition: return "Competition"
        case .advanced: return "Advanced"

        case .sparring: return "Sparring"
        case .drilling: return "Drilling"
        case .fundamentals: return "Fundamentals"
        case .conditioning: return "Conditioning"


        case .muayThai: return "Muay Thai"
        case .kickboxing: return "Kickboxing"
        case .kravMaga: return "Krav Maga"
        case .selfDefense: return "Self-Defense"

        case .boxing: return "Boxing"
        case .cardioKickboxing: return "Cardio Kickboxing"

        case .stretching: return "Stretching"
        case .flow: return "Flow"
        case .recovery: return "Recovery"
        case .yoga: return "Yoga"


        case .custom: return "Other"
        }
    }
    
    var badgeColor: String {
        switch self {

        case .competition: return "red"
        case .advanced: return "purple"

        case .sparring: return "orange"
        case .drilling: return "blue"
        case .fundamentals: return "green"
        case .conditioning: return "pink"

        case .muayThai: return "red"
        case .kickboxing: return "orange"
        case .boxing: return "brown"
        case .kravMaga: return "purple"
        case .cardioKickboxing: return "pink"
        case .selfDefense: return "orange"

        case .stretching: return "green"
        case .flow: return "blue"
        case .recovery: return "gray"
        case .yoga: return "purple"

        case .custom: return "gray"
        }
    }
}

struct DisciplinePicker: View {

    @Binding var discipline: Discipline

    var body: some View {

        VStack(alignment: .leading, spacing: 6) {

            Picker("Class", selection: $discipline) {

                ForEach(Discipline.allCases) { discipline in
                    Text(discipline.displayName)
                        .tag(discipline)
                }

            }
            .pickerStyle(.menu)

            Text("Gi, NoGi, Open Mat, Wrestling, Judo, Striking, MMA, or Mobility.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}


struct StylePicker: View {

    @Binding var style: Style?
    @Binding var discipline: Discipline
    @Binding var customStyle: String

    var body: some View {

        // ⭐ Don't show style picker for Open Mat
        if discipline != .openMat {

            VStack(alignment: .leading, spacing: 8) {

                Picker("Class Type", selection: $style) {

                    Text("N/A")
                        .tag(nil as Style?)

                    ForEach(Style.styles(for: discipline)) { styleOption in
                        Text(styleOption.displayName)
                            .tag(styleOption as Style?)
                    }
                }
                .pickerStyle(.menu)

                Text("Optional Class Format. Choose Fundamentals, Advanced, Competition, or leave blank.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if style == .custom {
                    TextField("Enter Style", text: $customStyle)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
}

extension Style {

    static func styles(for discipline: Discipline) -> [Style] {

        switch discipline {

        case .bjjGi:
            return [.advanced, .fundamentals, .conditioning, .competition, .drilling, .sparring, .custom]
            
        case .bjjNoGi:
            return [.advanced, .fundamentals, .conditioning, .competition, .drilling, .sparring, .custom]

        case .openMat:
            return []

        case .mma:
            return [.fundamentals, .sparring, .conditioning, .custom]

        case .wrestling:
            return [.fundamentals, .sparring, .drilling, .conditioning, .custom]

        case .judo:
            return [.fundamentals, .sparring, .drilling, .custom]
            
        case .striking:
            return [.muayThai, .kickboxing, .boxing, .kravMaga, .cardioKickboxing, .selfDefense, .custom]

        case .mobility:
            return [.yoga, .flow, .stretching, .recovery, .custom]
            

        }
    }
}
