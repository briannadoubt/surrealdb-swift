@testable import SurrealDB
import Testing

/// Tests for schema type definitions and SurrealQL generation.
@Suite("Schema Types")
struct SchemaTypesTests {
    // MARK: - FieldType Tests

    @Test("FieldType generates correct SurrealQL for primitives")
    func fieldTypePrimitives() {
        #expect(FieldType.any.toSurrealQL() == "any")
        #expect(FieldType.string.toSurrealQL() == "string")
        #expect(FieldType.int.toSurrealQL() == "int")
        #expect(FieldType.float.toSurrealQL() == "float")
        #expect(FieldType.decimal.toSurrealQL() == "decimal")
        #expect(FieldType.bool.toSurrealQL() == "bool")
        #expect(FieldType.datetime.toSurrealQL() == "datetime")
        #expect(FieldType.duration.toSurrealQL() == "duration")
        #expect(FieldType.uuid.toSurrealQL() == "uuid")
        #expect(FieldType.bytes.toSurrealQL() == "bytes")
        #expect(FieldType.null.toSurrealQL() == "null")
        #expect(FieldType.object.toSurrealQL() == "object")
        #expect(FieldType.number.toSurrealQL() == "number")
    }

    @Test("FieldType generates correct SurrealQL for arrays")
    func fieldTypeArrays() {
        #expect(FieldType.array(of: .string).toSurrealQL() == "array<string>")
        #expect(FieldType.array(of: .int).toSurrealQL() == "array<int>")
        #expect(FieldType.array(of: .bool).toSurrealQL() == "array<bool>")
    }

    @Test("FieldType generates correct SurrealQL for sets")
    func fieldTypeSets() {
        #expect(FieldType.set(of: .string).toSurrealQL() == "set<string>")
        #expect(FieldType.set(of: .int).toSurrealQL() == "set<int>")
    }

    @Test("FieldType generates correct SurrealQL for records")
    func fieldTypeRecords() {
        #expect(FieldType.record(table: nil).toSurrealQL() == "record")
        #expect(FieldType.record(table: "users").toSurrealQL() == "record<users>")
        #expect(FieldType.record(table: "posts").toSurrealQL() == "record<posts>")
    }

    @Test("FieldType generates correct SurrealQL for options")
    func fieldTypeOptions() {
        #expect(FieldType.option(of: .string).toSurrealQL() == "option<string>")
        #expect(FieldType.option(of: .int).toSurrealQL() == "option<int>")
    }

    @Test("FieldType generates correct SurrealQL for nested types")
    func fieldTypeNested() {
        let arrayOfOptionalStrings = FieldType.array(of: .option(of: .string))
        #expect(arrayOfOptionalStrings.toSurrealQL() == "array<option<string>>")

        let optionalArrayOfInts = FieldType.option(of: .array(of: .int))
        #expect(optionalArrayOfInts.toSurrealQL() == "option<array<int>>")

        let arrayOfRecords = FieldType.array(of: .record(table: "users"))
        #expect(arrayOfRecords.toSurrealQL() == "array<record<users>>")
    }

    @Test("FieldType generates correct SurrealQL for geometry types")
    func fieldTypeGeometry() {
        #expect(FieldType.geometry(subtype: nil).toSurrealQL() == "geometry")
        #expect(FieldType.geometry(subtype: .point).toSurrealQL() == "geometry<point>")
        #expect(FieldType.geometry(subtype: .lineString).toSurrealQL() == "geometry<linestring>")
        #expect(FieldType.geometry(subtype: .polygon).toSurrealQL() == "geometry<polygon>")
    }

    // MARK: - SchemaMode Tests

    @Test("SchemaMode generates correct SurrealQL")
    func schemaMode() {
        #expect(SchemaMode.schemaless.toSurrealQL() == "SCHEMALESS")
        #expect(SchemaMode.schemafull.toSurrealQL() == "SCHEMAFULL")
    }

    // MARK: - TableType Tests

    @Test("TableType generates correct SurrealQL")
    func tableType() {
        #expect(TableType.normal.toSurrealQL().isEmpty)
        #expect(TableType.relation(from: "users", to: "posts").toSurrealQL() == "TYPE RELATION IN users OUT posts")
        #expect(TableType.relation(from: "users", to: "users").toSurrealQL() == "TYPE RELATION IN users OUT users")
    }

    // MARK: - IndexType Tests

    @Test("IndexType generates correct SurrealQL")
    func indexType() {
        #expect(IndexType.standard.toSurrealQL().isEmpty)
        #expect(IndexType.unique.toSurrealQL() == "UNIQUE")
    }

    @Test("IndexType generates correct SurrealQL for search indexes")
    func indexTypeSearch() {
        #expect(IndexType.search(analyzer: nil).toSurrealQL() == "SEARCH ANALYZER LIKE")
        #expect(IndexType.search(analyzer: "ascii").toSurrealQL() == "SEARCH ANALYZER ascii")
        #expect(IndexType.fulltext(analyzer: nil).toSurrealQL() == "SEARCH ANALYZER LIKE BM25")
        #expect(IndexType.fulltext(analyzer: "ascii").toSurrealQL() == "SEARCH ANALYZER ascii BM25")
    }

    // MARK: - GeometryType Tests

    @Test("GeometryType generates correct SurrealQL")
    func geometryType() {
        #expect(GeometryType.point.toSurrealQL() == "point")
        #expect(GeometryType.lineString.toSurrealQL() == "linestring")
        #expect(GeometryType.polygon.toSurrealQL() == "polygon")
        #expect(GeometryType.multiPoint.toSurrealQL() == "multipoint")
        #expect(GeometryType.multiLineString.toSurrealQL() == "multilinestring")
        #expect(GeometryType.multiPolygon.toSurrealQL() == "multipolygon")
        #expect(GeometryType.collection.toSurrealQL() == "collection")
    }
}
