import Foundation
@preconcurrency import Metal

enum GPUSortError: Error {
    case noDevice
    case commandQueue
    case library
    case pipeline
    case bufferCreation
}

/// Simple bitonic sort on GPU using a Metal compute kernel.
/// Input is padded to the next power of two with `UInt32.max` so ordering stays correct when trimmed.
struct GPUSorter {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw GPUSortError.noDevice }
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw GPUSortError.commandQueue }
        self.commandQueue = queue
        guard let library = device.makeDefaultLibrary() else { throw GPUSortError.library }
        guard let function = library.makeFunction(name: "bitonicSort") else { throw GPUSortError.library }
        self.pipeline = try device.makeComputePipelineState(function: function)
    }

    /// Sorts the input on the GPU and returns the sorted output and elapsed seconds.
    func sort(_ input: [UInt32]) async throws -> ([UInt32], Double) {
        let originalCount = input.count
        let paddedCount = nextPowerOfTwo(originalCount)
        let byteCount = paddedCount * MemoryLayout<UInt32>.stride

        guard let buffer = device.makeBuffer(length: byteCount, options: .storageModeShared) else {
            throw GPUSortError.bufferCreation
        }

        // Copy input and pad with UInt32.max
        buffer.contents().bindMemory(to: UInt32.self, capacity: paddedCount)
        buffer.contents().copyMemory(from: input, byteCount: originalCount * MemoryLayout<UInt32>.stride)
        if originalCount < paddedCount {
            let padStart = buffer.contents().advanced(by: originalCount * MemoryLayout<UInt32>.stride)
            let padCount = paddedCount - originalCount
            
            padStart
                .bindMemory(to: UInt32.self, capacity: padCount)
                .initialize(repeating: UInt32.max, count: padCount)
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw GPUSortError.commandQueue
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(buffer, offset: 0, index: 0)

        let threadsPerThreadgroup = MTLSize(width: pipeline.maxTotalThreadsPerThreadgroup, height: 1, depth: 1)

        let start = DispatchTime.now()

        var k = 2
        while k <= paddedCount {
            var j = k >> 1
            while j > 0 {
                var stage = UInt32(k)
                var pass = UInt32(j)
                encoder.setBytes(&stage, length: MemoryLayout<UInt32>.stride, index: 1)
                encoder.setBytes(&pass, length: MemoryLayout<UInt32>.stride, index: 2)

                let threadCount = MTLSize(width: paddedCount, height: 1, depth: 1)
                encoder.dispatchThreads(threadCount, threadsPerThreadgroup: threadsPerThreadgroup)
                encoder.memoryBarrier(scope: .buffers)

                j >>= 1
            }
            k <<= 1
        }

        encoder.endEncoding()

        return try await withCheckedThrowingContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in
                let end = DispatchTime.now()
                let seconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000

                let data = Data(bytesNoCopy: buffer.contents(), count: originalCount * MemoryLayout<UInt32>.stride, deallocator: .none)
                var output = [UInt32](repeating: 0, count: originalCount)
                _ = output.withUnsafeMutableBytes { data.copyBytes(to: $0) }
                continuation.resume(returning: (output, seconds))
            }
            commandBuffer.commit()
        }
    }

    private func nextPowerOfTwo(_ n: Int) -> Int {
        var v = n
        v -= 1
        v |= v >> 1
        v |= v >> 2
        v |= v >> 4
        v |= v >> 8
        v |= v >> 16
        return v + 1
    }
}
