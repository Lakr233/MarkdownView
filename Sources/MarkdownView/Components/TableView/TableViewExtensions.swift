//
//  TableViewExtensions.swift
//  MarkdownView
//
//  Created by ktiays on 2025/1/27.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import UIKit

extension TableView: MarkdownAttributedStringRepresentable {
    func markdownAttributedStringRepresentation() -> NSAttributedString {
        let attributedString = NSMutableAttributedString()

        for row in contents {
            let rowString = NSMutableAttributedString()

            for cell in row {
                rowString.append(cell)
                rowString.append(NSAttributedString(string: "\t"))
            }

            attributedString.append(rowString)

            if row != contents.last {
                attributedString.append(NSAttributedString(string: "\n"))
            }
        }

        return attributedString
    }
}
