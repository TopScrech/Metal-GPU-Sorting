import Foundation

/// Simple parallel merge sort using DispatchQueues.
struct CPUParallelSorter {
    private let minChunk = 20_000
    private let queue = DispatchQueue.global(qos: .userInitiated)
    
    func sort(_ input: [UInt32]) -> [UInt32] {
        return parallelSort(input, depth: ProcessInfo.processInfo.processorCount)
    }
    
    private func parallelSort(_ input: [UInt32], depth: Int) -> [UInt32] {
        let count = input.count
        guard count > 1 else { return input }
        
        // Use serial sort when small or no more parallel depth
        if count <= minChunk || depth <= 1 {
            return input.sorted()
        }
        
        let mid = count / 2
        let leftSlice = Array(input[..<mid])
        let rightSlice = Array(input[mid...])
        
        var leftResult: [UInt32] = []
        var rightResult: [UInt32] = []
        let group = DispatchGroup()
        
        group.enter()
        queue.async {
            leftResult = parallelSort(leftSlice, depth: depth / 2)
            group.leave()
        }
        
        group.enter()
        queue.async {
            rightResult = parallelSort(rightSlice, depth: depth / 2)
            group.leave()
        }
        
        group.wait()
        return merge(leftResult, rightResult)
    }
    
    private func merge(_ left: [UInt32], _ right: [UInt32]) -> [UInt32] {
        var merged: [UInt32] = []
        merged.reserveCapacity(left.count + right.count)
        
        var i = 0
        var j = 0
        
        while i < left.count && j < right.count {
            if left[i] <= right[j] {
                merged.append(left[i]); i += 1
            } else {
                merged.append(right[j]); j += 1
            }
        }
        
        if i < left.count {
            merged.append(contentsOf: left[i...])
        }
        
        if j < right.count {
            merged.append(contentsOf: right[j...])
        }
        
        return merged
    }
}
