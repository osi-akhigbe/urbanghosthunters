import Foundation

struct NFCTagRecord: Decodable, Equatable {
    let id: UUID
    let uid: String
    let totem_type: String?
    let key_name: String?
    let label: String

    var resolvedTotemType: TotemType? {
        guard let raw = totem_type else { return nil }
        return TotemType(rawValue: raw)
    }

    var isTotemTag: Bool { totem_type != nil }
    var isKeyTag: Bool   { key_name != nil }
}
