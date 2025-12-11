import Testing
import Metal
@testable import GPU_Sorting

struct GPU_SortingTests {
    /// Smoke test that GPU bitonic sort produces the same output as CPU `.sorted()`.
    @Test func testGPUSortMatchesCPU() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else { return } // allow headless CI to pass
        let input = (0..<1_000).map { _ in UInt32.random(in: .min ... .max) }
        let expected = input.sorted()
        
        let sorter = try GPUSorter()
        let (output, _) = try await sorter.sort(input)
        
        #expect(output == expected)
    }
    
    /// Simple timing and correctness check for Swift's `.sorted()`.
    @Test func testSwiftSortedPerformance() async throws {
        let input = (0..<50_000).map { _ in Int.random(in: .min ... .max) }
        let start = DispatchTime.now()
        let output = input.sorted()
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        
        #expect(output.isSortedAscending)
        #expect(elapsed > 0) // sanity: timing captured
    }

    /// Parallel CPU sorter matches `.sorted()`.
    @Test func testParallelCPUSorter() throws {
        let input = (0..<25_000).map { _ in UInt32.random(in: .min ... .max) }
        let expected = input.sorted()

        let sorter = CPUParallelSorter()
        let output = sorter.sort(input)

        #expect(output == expected)
    }
}

private extension Array where Element: Comparable {
    var isSortedAscending: Bool {
        guard count > 1 else { return true }
        for i in 1..<count where self[i] < self[i - 1] { return false }
        return true
    }
}
