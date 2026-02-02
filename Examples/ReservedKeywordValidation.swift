#!/usr/bin/env swift

import Foundation

// Example demonstrating reserved keyword validation in SurrealDB Swift SDK
// This example shows how the SDK prevents using SQL keywords as identifiers

/*
 Reserved Keyword Validation
 ============================

 The SurrealDB Swift SDK now validates identifiers (table names, field names, index names)
 against a comprehensive list of reserved SQL keywords to prevent parsing errors.

 Reserved keywords include:
 - Query commands: select, from, where, insert, update, delete, create, etc.
 - Schema definition: table, field, index, type, relation, etc.
 - Data types: string, int, float, bool, datetime, array, object, etc.
 - Control flow: if, else, then, end, for, in, let, return, etc.
 - Logical operators: and, or, not, is, contains, etc.
 - Literals: true, false, null, none, void

 Examples:
 =========

 ❌ INVALID: Using reserved keywords as identifiers

 try db.schema.defineTable("select")  // Error: 'select' is a reserved keyword
 try db.schema.defineTable("from")    // Error: 'from' is a reserved keyword

 try db.schema.defineField("where", on: "users")  // Error: 'where' is a reserved keyword
 try db.schema.defineField("update", on: "users") // Error: 'update' is a reserved keyword

 try db.schema.defineIndex("index", on: "users")  // Error: 'index' is a reserved keyword


 ✅ VALID: Use backtick-quoted identifiers to escape keywords

 try db.schema.defineTable("`select`")  // OK: Backtick-quoted
 try db.schema.defineTable("`from`")    // OK: Backtick-quoted

 try db.schema.defineField("`where`", on: "users")  // OK: Backtick-quoted
 try db.schema.defineField("`update`", on: "users") // OK: Backtick-quoted


 ✅ VALID: Use alternative non-reserved names

 try db.schema.defineTable("selections")      // OK: Not a reserved keyword
 try db.schema.defineTable("user_updates")    // OK: Not a reserved keyword

 try db.schema.defineField("location", on: "users")     // OK: Not a reserved keyword
 try db.schema.defineField("last_updated", on: "users") // OK: Not a reserved keyword


 Benefits:
 =========

 1. Catch errors early at the client level before sending to the database
 2. Provide clear error messages with suggestions for backtick-quoting
 3. Prevent SQL parsing errors and ambiguities
 4. Case-insensitive validation (SELECT, Select, select all rejected)
 5. Works with nested field names (validates each component)


 Error Messages:
 ==============

 When you attempt to use a reserved keyword, you'll get a helpful error:

   "Error: 'select' is a reserved keyword and cannot be used as a table name.
    Use backtick-quoted identifier like `select` instead."

 This makes it clear:
 - What the problem is
 - Where it occurred (table name, field name, etc.)
 - How to fix it (use backticks)


 Implementation:
 ==============

 The validation is implemented in SurrealValidator with:
 - A comprehensive set of 70+ reserved keywords
 - Case-insensitive matching
 - Automatic application in all schema builder methods
 - Support for backtick-quoted escaping
 - Validation of nested field names (e.g., "user.select" is rejected)
*/
