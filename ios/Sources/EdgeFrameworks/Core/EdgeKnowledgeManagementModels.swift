public struct EdgeKnowledgeCollectionSummary:
    Equatable,
    Sendable
{
    public let collection: EdgeKnowledgeCollection
    public let sourceCount: Int
    public let documentCount: Int
    public let lastIndexedAtMilliseconds: Int64?

    public init(
        collection: EdgeKnowledgeCollection,
        sourceCount: Int,
        documentCount: Int,
        lastIndexedAtMilliseconds: Int64?
    ) {
        self.collection = collection
        self.sourceCount = sourceCount
        self.documentCount = documentCount
        self.lastIndexedAtMilliseconds =
            lastIndexedAtMilliseconds
    }
}

public enum EdgeKnowledgeManagerError:
    Error,
    Equatable,
    Sendable
{
    case collectionNotFound(String)
}
