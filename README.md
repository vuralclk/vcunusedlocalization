# VCUnusedLocalization

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://github.com/YOUR_USERNAME/VCUnusedLocalization)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

VCUnusedLocalization is a command-line tool that helps you identify unused localization keys in your iOS/macOS projects. It scans your project's `.strings` files and Swift source code to detect localization keys that are defined but never used, helping you maintain a cleaner codebase.

## Features

- 🔍 Scans `.strings` files for localization keys
- 📱 Analyzes Swift source files for string literal usage
- 🚀 Fast and efficient with concurrent processing
- 🎯 Excludes specific paths (Pods, Carthage, etc.)
- 💻 Command-line interface with simple usage
- 📊 Detailed progress and result reporting

## Installation

### Homebrew

You can install VCUnusedLocalization using Homebrew:

```bash
brew install vuralclk/vcunusedlocalization/vcunusedlocalization
```

### Manual Installation via Building Binary

```bash
git clone https://github.com/vuralclk/VCUnusedLocalization.git
cd VCUnusedLocalization
swift build -c release
sudo cp .build/release/VCUnusedLocalization /usr/local/bin/vcunusedlocalization
```

## Usage

Basic usage:
```bash
vcunusedlocalization scan --path /path/to/your/project
```

If no path is specified, it will scan the current directory:
```bash
vcunusedlocalization scan
```

## Output

The tool provides detailed output including:
- Total number of localization keys found
- Total number of Swift files scanned
- List of unused localization keys
- Execution time
- Any errors encountered during scanning

Example output:
```
Searching for Localization Keys in .strings files...

Total 150 localization keys found.
Total 45 swift files found.

Searching for unused keys...

Unused Localization Keys:
welcome.unused.key
settings.obsolete.text
profile.deprecated.title

Total 3 unused localization keys found.
Completed in: 0.5s
```

## Requirements

- macOS 10.15 or later
- Swift 5.9 or later

## Dependencies

- [Swift Argument Parser](https://github.com/apple/swift-argument-parser)
- [SwiftSyntax](https://github.com/apple/swift-syntax)

## Architecture

The project follows actor-based concurrency model with Swift's modern concurrency features:

- `FileScanner`: Main actor responsible for coordinating the scanning process
- `LocalizationParser`: Handles parsing of .strings files
- `FileManagerActor`: Manages file system operations
- `ConsoleLogger`: Handles output formatting and logging
- `ProjectAnalyzer`: Coordinates the overall analysis process

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Vural Çelik

## Acknowledgments

- Swift Team for SwiftSyntax
- Apple for Swift Argument Parser
- Special thanks to [Arif Okuyucu](https://github.com/okuyucuarif) for his valuable support and guidance on this project

---

Don't forget to ⭐️ this repo if you find it useful!

