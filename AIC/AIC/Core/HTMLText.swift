//
//  HTMLText.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import UIKit


enum HTMLText {
    static func attributedString(fromHTML html: String) -> AttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }
        guard let imported = try? NSMutableAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ],
            documentAttributes: nil
        ) else { return nil }

        let fullRange = NSRange(location: 0, length: imported.length)

        imported.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            guard let importedFont = value as? UIFont else { return }
            let body = UIFont.preferredFont(forTextStyle: .body)
            var traits = importedFont.fontDescriptor.symbolicTraits
            traits.formIntersection([.traitBold, .traitItalic])
            let descriptor = body.fontDescriptor.withSymbolicTraits(traits) ?? body.fontDescriptor
            imported.addAttribute(.font, value: UIFont(descriptor: descriptor, size: 0), range: range)
        }
        imported.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)

        while imported.string.hasSuffix("\n") {
            imported.deleteCharacters(in: NSRange(location: imported.length - 1, length: 1))
        }

        return AttributedString(imported)
    }
}
