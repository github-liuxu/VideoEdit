//
//  Convertor.swift
//  DF
//
//  Created by 刘东旭 on 2021/10/30.
//

import Foundation
import AVFoundation

protocol ConvertorDelegate: AnyObject {
    func finish(error:Error)
}

class Convertor {
    weak var delegate: ConvertorDelegate?
    let writerQueue = DispatchQueue.init(label: "writerQueue")
    var reader: AVAssetReader!
    var videoTrack: AVAssetTrack!
    var readerOutput: AVAssetReaderTrackOutput!
    let localPath = NSHomeDirectory() + "/Documents/.Convert"
    var writer: AVAssetWriter!
    var writerInput: AVAssetWriterInput!
    var pixelBufferAdepter: AVAssetWriterInputPixelBufferAdaptor!
//    let cacheFrameInfo = [Int64:Dictionary<String, Any>]()
    var frameArray = Array<String>()
    init(filePath: String) {
        let asset = AVAsset(url: URL.init(fileURLWithPath: filePath))
        reader = try! AVAssetReader(asset: asset)
        videoTrack = asset.tracks(withMediaType: .video).first
        readerOutput = AVAssetReaderTrackOutput(track: videoTrack!, outputSettings: [String(kCVPixelBufferPixelFormatTypeKey):kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange])
        readerOutput.alwaysCopiesSampleData = true
        readerOutput.supportsRandomAccess = true
        if reader.canAdd(readerOutput) {
            reader.add(readerOutput)
        }
        reader.startReading()
        
        let outputPath = URL(fileURLWithPath: localPath + "/Convert.mp4")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputPath.absoluteString) {
            try? fileManager.removeItem(at: outputPath)
        }
        print(outputPath)
        writer = try? AVAssetWriter(url: outputPath, fileType: .mp4)
        writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:1920,AVVideoHeightKey:1080])
        if writer.canAdd(writerInput) {
            writer.add(writerInput)
        }
        
        pixelBufferAdepter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
    }
    
    func convert() {
        //解码写
        var readDone = false
        while !readDone {
            guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                print("解码失败！")
                break
            }
            
            let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            //写数据
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("CMSampleBufferGetImageBuffer失败！")
                break
            }
            
            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
            
            let pixelBuffer: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddress(imageBuffer)!
            let size = CVPixelBufferGetDataSize(imageBuffer)
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            let bytesPreRow = CVPixelBufferGetBytesPerRow(imageBuffer)
            let dicAttributes = CVPixelBufferCopyCreationAttributes(imageBuffer)
            let data = Data(bytes: pixelBuffer, count: size)
            
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: localPath) {
                try? fileManager.createDirectory(atPath: localPath,withIntermediateDirectories: true)
            }
            
            let bufferFile = localPath + "/\(Int64(timeStamp.seconds * 1000000.0))"
            let bufferUrl = URL(fileURLWithPath: bufferFile, isDirectory: false)
            try? data.write(to: bufferUrl)
            frameArray.append(bufferFile)
            
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        }
        //读编码
        writerSamples()
    }
    
    func writerSamples() {
        //读数据
        writerInput.requestMediaDataWhenReady(on: writerQueue) { [self] in
            self.frameArray.reversed().forEach { idx in
            
                var data:Data = try! Data(contentsOf: URL(fileURLWithPath: idx))
                var pixelBuffer: CVPixelBuffer?
                var pixelPoint = UnsafeMutablePointer<CVPixelBuffer?>(&pixelBuffer)
                //                CVPixelBufferCreate(kCFAllocatorDefault, 1920, 1080, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, nil, pixelPoint)
                var dat = UnsafeMutableRawPointer(&data)
                CVPixelBufferCreateWithBytes(kCFAllocatorDefault, 1920, 1080, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, dat, 1920, nil, nil, nil, pixelPoint)
                //                data?.copyBytes(to: pixelBuffer, count: data?.count)
                //                memcpy(pixelPoint, UnsafeRawPointer(&data), data.count)
                pixelBufferAdepter.append(pixelBuffer!, withPresentationTime: CMTimeMake(value: Int64(idx.replacingOccurrences(of: self.localPath + "/", with: ""))!, timescale: 1000000))
            }
        }
        self.writer.finishWriting {
            print("OK")
        }
    }
    
}
