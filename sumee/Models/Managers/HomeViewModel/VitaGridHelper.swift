import Foundation
import CoreGraphics

struct VitaGridHelper {
    // Vita Pattern: 3, 2, 3, 2...
    // This creates the honeycomb effect.
    // Total per page: 10 items fits nicely (3+2+3+2 = 10)
    static let maxItemsPerPage = 10
    
    struct GridPosition: Equatable {
        let row: Int
        let col: Int
        let index: Int
    }
    
    // Returns the number of items allowed in a specific row
    static func itemsPerRow(_ row: Int) -> Int {
        // Pattern: 3, 4, 3
        // Row 0: 3
        // Row 1: 4
        // Row 2: 3
        // Row 3: 3 (Next page)
        let patternIndex = row % 3
        return patternIndex == 1 ? 4 : 3
    }
    
    static let itemsPerPage = 10 // 3 + 4 + 3    
    // Calculates the row and column for a flat index
    static func getPosition(for index: Int) -> GridPosition {
        var remainingIndex = index
        var currentRow = 0
        
        while true {
            let capacity = itemsPerRow(currentRow)
            if remainingIndex < capacity {
                return GridPosition(row: currentRow, col: remainingIndex, index: index)
            }
            remainingIndex -= capacity
            currentRow += 1
        }
    }
    
    // Calculates the flat index for a row/col
    static func getIndex(row: Int, col: Int) -> Int {
        var index = 0
        for r in 0..<row {
            index += itemsPerRow(r)
        }
        return index + col
    }
    
    // Navigation Logic this will update over the time, logic can be better.
    // Up/Down needs "Nearest Neighbor" logic due to staggered layout
    // Row 0 (3):  0   1   2
    // Row 1 (2):    3   4
    // Row 2 (3):  5   6   7
    
    /* Mapping:
       Down from 0 -> 3
       Down from 1 -> 3 or 4 (Based on proximity, usually split. Let's say Left-biased: 3, Right-biased: 4)
       Down from 2 -> 4
       
       Up from 3 -> 0 or 1
       Up from 4 -> 1 or 2
    */
    
    static func navigate(from index: Int, direction: GameControllerManager.Direction, totalItems: Int) -> Int {
        let pos = getPosition(for: index)
        var targetRow = pos.row
        var targetCol = pos.col
        
        switch direction {
        case .left:
            if targetCol > 0 {
                return getIndex(row: targetRow, col: targetCol - 1)
            } else {
 
                if index > 0 { return index - 1 }
                return index
            }
            
        case .right:
            if targetCol < itemsPerRow(targetRow) - 1 {
                // Check if next index exists in totalItems
                let nextIdx = getIndex(row: targetRow, col: targetCol + 1)
                if nextIdx < totalItems { return nextIdx }
            }
            // Linear wrap forward
            if index < totalItems - 1 { return index + 1 }
            return index
            
        case .up:
            if targetRow > 0 {
                let prevRow = targetRow - 1
                let prevRowCapacity = itemsPerRow(prevRow)
                let currentRowCapacity = itemsPerRow(targetRow)
                
                // Staggered Mapping
                var newCol = targetCol
                
                if prevRowCapacity > currentRowCapacity {
                    // Moving from small row (2) to big row (3)

                    
                    if targetCol == 0 { newCol = 0 } // Left side -> Left side
                    else { newCol = 2 } // Right side -> Right side
                    // Middle (1) is tricky.
         
                } else {
                    // Moving from big row (3) to small row (2)
                   
                    
                    if targetCol == 0 { newCol = 0 }
                    else if targetCol == 2 { newCol = 1 }
                    else {

                        newCol = 0 
                    }
                }
                
                // Clamp
                if newCol >= prevRowCapacity { newCol = prevRowCapacity - 1 }
                
                let idx = getIndex(row: prevRow, col: newCol)
                if idx < totalItems { return idx }
            }
            return index
            
        case .down:
            let nextRow = targetRow + 1
            // Check if next row exists effectively (infinite abstract grid, but bounded by items)
            // Need to verify if the computed index is within totalItems
            
            let nextRowCapacity = itemsPerRow(nextRow)
            let currentRowCapacity = itemsPerRow(targetRow)
            
            var newCol = targetCol
            
            if nextRowCapacity < currentRowCapacity {
                // Big (3) to Small (2)
             
                if targetCol == 0 { newCol = 0 }
                else if targetCol == 2 { newCol = 1 }
                else { newCol = 0 } // Middle -> Left
            } else {
                // Small (2) to Big (3)
             
                if targetCol == 0 { newCol = 0 }
                else { newCol = 2 } // 1 -> 2
            }
            
            // Clamp
            if newCol >= nextRowCapacity { newCol = nextRowCapacity - 1 }
            
            let idx = getIndex(row: nextRow, col: newCol)
            if idx < totalItems { return idx }
            return index
        }
    }
}
