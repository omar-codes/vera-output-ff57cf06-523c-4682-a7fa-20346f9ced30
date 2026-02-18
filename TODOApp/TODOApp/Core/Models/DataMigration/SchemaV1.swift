// Core/Models/DataMigration/SchemaV1.swift
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [TaskItem.self, TaskList.self]
    }
}
