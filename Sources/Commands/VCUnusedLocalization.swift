import ArgumentParser

@main
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct VCUnusedLocalization: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "vcunusedlocalization",
        abstract: "Scans all files in the project to detect unused localization keys",
        subcommands: [ScanCommand.self]
    )
}
