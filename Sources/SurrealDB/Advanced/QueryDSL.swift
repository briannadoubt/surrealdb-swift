import Foundation

/// Sort direction for `OrderBy` query DSL component.
public enum SortDirection: Sendable {
    case ascending
    case descending
}

/// Type-erased query DSL component.
public struct AnyQueryDSLComponent<T: SurrealModel> {
    private let applyClosure: (inout QueryDSLState<T>) -> Void

    init(_ apply: @escaping (inout QueryDSLState<T>) -> Void) {
        self.applyClosure = apply
    }

    func apply(to state: inout QueryDSLState<T>) {
        applyClosure(&state)
    }
}

/// Internal state collected from query DSL components.
public struct QueryDSLState<T: SurrealModel> {
    var selectedFields: [PartialKeyPath<T>]?
    var predicates: [Predicate] = []
    var orderBy: [(keyPath: PartialKeyPath<T>, ascending: Bool)] = []
    var limit: Int?
    var offset: Int?
}

/// Result-builder based query DSL for SurrealModel queries.
@resultBuilder
public enum QueryDSLBuilder<T: SurrealModel> {
    public static func buildBlock(_ components: [AnyQueryDSLComponent<T>]...) -> [AnyQueryDSLComponent<T>] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [AnyQueryDSLComponent<T>]?) -> [AnyQueryDSLComponent<T>] {
        component ?? []
    }

    public static func buildEither(first component: [AnyQueryDSLComponent<T>]) -> [AnyQueryDSLComponent<T>] {
        component
    }

    public static func buildEither(second component: [AnyQueryDSLComponent<T>]) -> [AnyQueryDSLComponent<T>] {
        component
    }

    public static func buildArray(_ components: [[AnyQueryDSLComponent<T>]]) -> [AnyQueryDSLComponent<T>] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: AnyQueryDSLComponent<T>) -> [AnyQueryDSLComponent<T>] {
        [expression]
    }
}

// Select specific model fields.
// swiftlint:disable:next identifier_name
public func Select<T: SurrealModel>(_ fields: PartialKeyPath<T>...) -> AnyQueryDSLComponent<T> {
    AnyQueryDSLComponent { state in
        state.selectedFields = fields.isEmpty ? nil : fields
    }
}

// Add a WHERE predicate.
// swiftlint:disable:next identifier_name
public func Where<T: SurrealModel>(_ predicate: Predicate) -> AnyQueryDSLComponent<T> {
    AnyQueryDSLComponent { state in
        state.predicates.append(predicate)
    }
}

// Add ORDER BY using a model key path.
// swiftlint:disable:next identifier_name
public func OrderBy<T: SurrealModel>(
    _ keyPath: PartialKeyPath<T>,
    _ direction: SortDirection = .ascending
) -> AnyQueryDSLComponent<T> {
    AnyQueryDSLComponent { state in
        state.orderBy.append((keyPath: keyPath, ascending: direction == .ascending))
    }
}

// Add LIMIT.
// swiftlint:disable:next identifier_name
public func Limit<T: SurrealModel>(_ value: Int) -> AnyQueryDSLComponent<T> {
    AnyQueryDSLComponent { state in
        state.limit = value
    }
}

// Add OFFSET/START.
// swiftlint:disable:next identifier_name
public func Offset<T: SurrealModel>(_ value: Int) -> AnyQueryDSLComponent<T> {
    AnyQueryDSLComponent { state in
        state.offset = value
    }
}

extension SurrealDB {
    /// Execute a type-safe query with a Swift result builder.
    ///
    /// Example:
    /// ```swift
    /// let users: [User] = try await db.query(User.self) {
    ///     Select(\User.name, \User.email)
    ///     Where(\User.age >= 18)
    ///     OrderBy(\User.name)
    ///     Limit(25)
    /// }
    /// ```
    nonisolated public func query<T: SurrealModel>(
        _ type: T.Type,
        @QueryDSLBuilder<T> _ build: () -> [AnyQueryDSLComponent<T>]
    ) async throws(SurrealError) -> [T] {
        var state = QueryDSLState<T>()
        for component in build() {
            component.apply(to: &state)
        }

        return try await query(
            T.self,
            select: state.selectedFields,
            where: state.predicates,
            orderBy: state.orderBy,
            limit: state.limit,
            offset: state.offset
        )
    }
}
