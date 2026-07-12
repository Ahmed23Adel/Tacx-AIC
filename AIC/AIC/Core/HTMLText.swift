//
//  HTMLText.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import UIKit

/// Renders the API's HTML description fields (<p>, <em>, <strong>, links)
/// as an AttributedString. The system HTML importer supplies the structure;
/// we then re-font everything to the body text style — preserving only
/// bold/italic traits — so Dynamic Type and dark mode keep working instead
/// of inheriting the importer's fixed Times New Roman.
enum HTMLText {
    static func attributedString(
        fromHTML html: String,
        parse: (Data) throws -> NSAttributedString = HTMLText.parseHTML
    ) -> AttributedString? {
        guard let parsed = try? parse(Data(html.utf8)) else { return nil }

        let imported = NSMutableAttributedString(attributedString: parsed)
        let fullRange = NSRange(location: 0, length: imported.length)

        imported.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            imported.addAttribute(.font, value: bodyFont(preserving: value as? UIFont), range: range)
        }
        imported.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)

        // The importer appends a trailing newline per closing block tag.
        while imported.string.hasSuffix("\n") {
            imported.deleteCharacters(in: NSRange(location: imported.length - 1, length: 1))
        }

        return AttributedString(imported)
    }

    static func bodyFont(preserving font: UIFont?) -> UIFont {
        let body = UIFont.preferredFont(forTextStyle: .body)
        let sourceTraits = font?.fontDescriptor.symbolicTraits ?? []
        let traits = sourceTraits.intersection([.traitBold, .traitItalic])

        guard !traits.isEmpty,
              let descriptor = body.fontDescriptor.withSymbolicTraits(traits) else {
            return body
        }
        return UIFont(descriptor: descriptor, size: 0)
    }

    static func parseHTML(_ data: Data) throws -> NSAttributedString {
        try NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ],
            documentAttributes: nil
        )
    }
}
