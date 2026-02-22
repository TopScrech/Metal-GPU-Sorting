import Foundation

/// Simple parallel merge sort using Swift Concurrency
nonisolated struct CPUParallelSorter {
    private let minChunk = 20_000
    
    func sort(_ input: [UInt32]) async -> [UInt32] {
        await parallelSort(input, depth: ProcessInfo.processInfo.processorCount)
    }
    
    private func parallelSort(_ input: [UInt32], depth: Int) async -> [UInt32] {
        let count = input.count
        guard count > 1 else { return input }
        
        if count <= minChunk || depth <= 1 {
            return input.sorted()
        }
        
        let mid = count / 2
        let leftSlice = Array(input[..<mid])
        let rightSlice = Array(input[mid...])
        
        async let leftResult = parallelSort(leftSlice, depth: depth / 2)
        async let rightResult = parallelSort(rightSlice, depth: depth / 2)
        
        return merge(await leftResult, await rightResult)
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
