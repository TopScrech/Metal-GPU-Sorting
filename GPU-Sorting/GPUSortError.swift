enum GPUSortError: Error {
    case noDevice, commandQueue, library, pipeline, bufferCreation
}
