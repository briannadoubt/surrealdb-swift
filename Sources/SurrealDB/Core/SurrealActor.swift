/// Global actor for isolating SurrealDB transport operations.
///
/// This actor ensures thread-safe access to network resources and prevents
/// data races in concurrent operations.
@globalActor
public actor SurrealActor: GlobalActor {
    public static let shared = SurrealActor()

    private init() {}
}
