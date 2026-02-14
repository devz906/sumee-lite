import Foundation
import zlib

/// A minimalist ZIP extractor designed for iOS App Store compliance.
/// Supports "Store" (No compression) and "Deflate" methods using native zlib.
struct MiniZip {
    
    enum ZipError: Error {
        case invalidSignature
        case unsupportedMethod
        case decompressionFailed
        case fileWriteFailed
    }
    
    static func unzip(data: Data, to destination: URL) throws {
        var offset = 0
        let totalSize = data.count
        
        while offset < totalSize {
            // 1. Read Local File Header Signature (0x04034b50)
            guard offset + 4 <= totalSize else { break }
            let signature = data.subdata(in: offset..<offset+4)
            
            // Check for Central Directory signature (0x02014b50) -> End of files
            if signature.elementsEqual([0x50, 0x4b, 0x01, 0x02]) { break }
            
            // Validate Local File Header
            guard signature.elementsEqual([0x50, 0x4b, 0x03, 0x04]) else {
                break 
            }
            
            // 2. Parse Header Info
            guard offset + 30 <= totalSize else { throw ZipError.invalidSignature }
            
            let flags = UInt16(data[offset + 6]) | (UInt16(data[offset + 7]) << 8)
            let compressionMethod = UInt16(data[offset + 8]) | (UInt16(data[offset + 9]) << 8)
            var compressedSize = UInt32(data[offset + 18]) | (UInt32(data[offset + 19]) << 8) | (UInt32(data[offset + 20]) << 16) | (UInt32(data[offset + 21]) << 24)
            var uncompressedSize = UInt32(data[offset + 22]) | (UInt32(data[offset + 23]) << 8) | (UInt32(data[offset + 24]) << 16) | (UInt32(data[offset + 25]) << 24)
            let filenameLength = Int(data[offset + 26]) | (Int(data[offset + 27]) << 8)
            let extraFieldLength = Int(data[offset + 28]) | (Int(data[offset + 29]) << 8)
            
            // Check for Data Descriptor (Bit 3)
            let hasDataDescriptor = (flags & 0x08) != 0
            
            // 3. Read Filename
            let filenameStart = offset + 30
            let filenameEnd = filenameStart + filenameLength
            guard filenameEnd <= totalSize else { throw ZipError.invalidSignature }
            
            let filenameData = data.subdata(in: filenameStart..<filenameEnd)
            guard let filename = String(data: filenameData, encoding: .utf8) else {
                // Cannot rescue without filename length
                break
            }
            
            // 4. Extract Data
            let dataStart = filenameEnd + extraFieldLength
            // For data descriptor, we don't know end yet.
            var dataEnd = hasDataDescriptor ? totalSize : (dataStart + Int(compressedSize))
            guard dataEnd <= totalSize else { throw ZipError.invalidSignature }
            
            let fileData = data.subdata(in: dataStart..<dataEnd)
            var decompressedData: Data?
            var bytesConsumed = 0
            
            if compressionMethod == 0 {
                // Store
                if hasDataDescriptor {
                    // Streaming Store not supported easily without scanning for signature
                   print("Skipping \(filename): Streaming STORE not supported")
                   break 
                }
                decompressedData = fileData
                bytesConsumed = Int(compressedSize)
            } else if compressionMethod == 8 {
                // Deflate
                let expectedSize = uncompressedSize > 0 ? Int(uncompressedSize) : 8 * 1024 * 1024
                let result = decompressDeflate(data: fileData, expectedSize: expectedSize)
                decompressedData = result.0
                bytesConsumed = result.1
                
                if hasDataDescriptor {
                
                    let descriptorStart = dataStart + bytesConsumed
                    if descriptorStart + 4 <= totalSize {
                        let potentialSig = data.subdata(in: descriptorStart..<descriptorStart+4)
                        if potentialSig.elementsEqual([0x50, 0x4b, 0x07, 0x08]) {
                            bytesConsumed += 16 // Sig(4)+CRC(4)+Size(4)+Size(4)
                        } else {
 
                            bytesConsumed += 12
                        }
                    }
                }
            } else {
                print("Skipping \(filename): Unsupported compression method \(compressionMethod)")
                break
            }
            
            // 5. Write to Destination
            if let outputData = decompressedData {
                let fileURL = destination.appendingPathComponent(filename)
                
                if filename.hasSuffix("/") {
                    try? FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
                } else {
                    try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    do {
                        try outputData.write(to: fileURL)
                        print("Extracted: \(filename)")
                    } catch {
                        print("Failed to write \(filename): \(error)")
                    }
                }
            }
            
            offset = dataStart + bytesConsumed
        }
    }
    
    private static func decompressDeflate(data: Data, expectedSize: Int) -> (Data?, Int) {
        return data.withUnsafeBytes { inputBytes -> (Data?, Int) in
            guard let inputPointer = inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return (nil, 0) }
            
            var stream = z_stream()
            let statusInit = inflateInit2_(&stream, -15, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
            guard statusInit == Z_OK else {
                print("MiniZip: inflateInit2 failed with status \(statusInit)")
                return (nil, 0)
            }
            
            stream.next_in = UnsafeMutablePointer(mutating: inputPointer)
            stream.avail_in = uInt(data.count)
            
            let chunkSize = 64 * 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
            defer { buffer.deallocate() }
            
            var decompressedData = Data(capacity: expectedSize > 0 ? expectedSize : chunkSize * 4)
            var status: Int32 = Z_OK
            
            repeat {
                stream.next_out = buffer
                stream.avail_out = uInt(chunkSize)
                status = inflate(&stream, Z_NO_FLUSH) // Z_NO_FLUSH allows streaming
                
                if status == Z_OK || status == Z_STREAM_END {
                    let count = chunkSize - Int(stream.avail_out)
                    if count > 0 {
                        decompressedData.append(buffer, count: count)
                    }
                } else if status == Z_BUF_ERROR {
           
                    break
                } else {
                    print("MiniZip: inflate loop failed with status \(status)")
                    inflateEnd(&stream)
                    return (nil, 0)
                }
            } while status == Z_OK
            
            let bytesConsumed = Int(stream.total_in)
            inflateEnd(&stream)
            
            if status == Z_STREAM_END {
                return (decompressedData, bytesConsumed)
            } else {
                return (nil, 0)
            }
        }
    }
}
