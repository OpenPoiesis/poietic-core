//
//  String+extensions.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 28/03/2025.
//


extension String {
    func titleCase() -> String {
        guard !self.isEmpty else {
            return ""
        }

        if self.contains("_") {
            let words = self.components(separatedBy: "_")
                .filter { !$0.isEmpty }
                .map { $0.capitalized }
            return words.joined(separator: " ")
        }
        else {
            var result = ""
            var index = self.startIndex
            result.append(self[index].uppercased())
            index = self.index(after: index)
            while index < self.endIndex {
                let char = self[index]
                if char.isUppercase {
                    result.append(" ")
                }
                result.append(char)
                index = self.index(after: index)
            }
            
            return result
        }
    }
}
