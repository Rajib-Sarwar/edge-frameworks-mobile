import EdgeFrameworks
import Foundation

struct EquipmentAsset: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var manufacturer: String
    var modelNumber: String
    var serialNumber: String
    var siteName: String
    var lastServiceAt: Date?
    var sourceCount: Int
    var serviceNoteCount: Int
    var photoCount: Int
    var recentIssue: String?

    var knowledgeCollection: EdgeKnowledgeCollection {
        EdgeKnowledgeCollection(
            id: id,
            name: name,
            metadata: [
                "equipmentID": id,
                "manufacturer": manufacturer,
                "modelNumber": modelNumber,
                "serialNumber": serialNumber,
                "siteName": siteName
            ]
        )
    }
}
