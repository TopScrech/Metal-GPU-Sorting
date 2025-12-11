import ScrechKit

struct ContentView: View {
    @State private var status = "Tap Run to benchmark"
    @State private var cpuTime: Double?
    @State private var cpuParallelTime: Double?
    @State private var gpuTime: Double?
    @State private var sampleCount = 2_000_000
    @State private var isRunning = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("GPU vs CPU Sort")
                .largeTitle(.bold)
            
            Text("Elements: \(sampleCount.formatted(.number.grouping(.automatic)))")
                .secondary()
            
            HStack {
                Button("Run Benchmark", action: runBenchmark)
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                
                Button("Reset") {
                    cpuTime = nil
                    gpuTime = nil
                    status = "Tap Run to benchmark"
                }
                .disabled(isRunning)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Status: \(status)")
                
                if let cpuTime {
                    Text("CPU .sorted(): \(cpuTime, format: .number.precision(.fractionLength(3))) s")
                }
                
                if let cpuParallelTime {
                    Text("CPU Parallel: \(cpuParallelTime, format: .number.precision(.fractionLength(3))) s")
                }
                
                if let gpuTime {
                    Text("GPU Bitonic: \(gpuTime, format: .number.precision(.fractionLength(3))) s")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial)
            .clipShape(.rect(cornerRadius: 12))
        }
        .padding()
    }
    
    private func runBenchmark() {
        isRunning = true
        status = "Generating input…"
        
        let elementCount = sampleCount
        Task.detached { [elementCount] in
            let input = (0..<elementCount).map { _ in UInt32.random(in: .min ... .max) }
            
            let cpuStart = DispatchTime.now()
            let cpuSorted = input.sorted()
            let cpuElapsed = Double(DispatchTime.now().uptimeNanoseconds - cpuStart.uptimeNanoseconds) / 1_000_000_000
            
            let parallelSorter = CPUParallelSorter()
            let cpuParStart = DispatchTime.now()
            let cpuParallelSorted = await parallelSorter.sort(input)
            let cpuParElapsed = Double(DispatchTime.now().uptimeNanoseconds - cpuParStart.uptimeNanoseconds) / 1_000_000_000
            
            var gpuElapsed: Double?
            var gpuStatus: String?
            var outputsMatch = false
            
            if let sorter = try? await GPUSorter() {
                do {
                    let (gpuSorted, time) = try await sorter.sort(input)
                    gpuElapsed = time
                    outputsMatch = (gpuSorted == cpuSorted) && (cpuParallelSorted == cpuSorted)
                } catch {
                    gpuStatus = "GPU sort failed: \(error.localizedDescription)"
                }
            } else {
                gpuStatus = "Metal GPU not available"
            }
            
            await MainActor.run {
                cpuTime = cpuElapsed
                cpuParallelTime = cpuParElapsed
                gpuTime = gpuElapsed
                
                if let gpuElapsed {
                    let gpuSpeedup = cpuElapsed / gpuElapsed
                    let parSpeedup = cpuElapsed / cpuParElapsed
                    let correctness = outputsMatch ? "Outputs match" : "Mismatch!"
                    status = "Done. GPU \(String(format: "%.1fx", gpuSpeedup)) vs parallel CPU \(String(format: "%.1fx", parSpeedup)). \(correctness)"
                    
                } else if let gpuStatus {
                    status = gpuStatus
                } else {
                    status = "CPU complete. GPU unavailable."
                }
                
                isRunning = false
            }
        }
    }
}

#Preview {
    ContentView()
}
