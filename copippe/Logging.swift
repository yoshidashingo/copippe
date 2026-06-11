import os

extension Logger {
    private static let subsystem = "com.copippe.app"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let app = Logger(subsystem: subsystem, category: "app")
}
