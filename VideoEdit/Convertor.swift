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
    let readerQueue = DispatchQueue.init(label: "readerQueue")
    let writerQueue = DispatchQueue.init(label: "writerQueue")
    var reader: AVAssetReader!
    var videoTrack: AVAssetTrack!
    var readerOutput: AVAssetReaderTrackOutput!
    let localPath = NSHomeDirectory() + "/Documents/Convert"
    var writer: AVAssetWriter!
    var writerInput: AVAssetWriterInput!
    var pixelBufferAdepter: AVAssetWriterInputPixelBufferAdaptor!
    var frameArray = Array<[String:Any]>()
    let fileManager = FileManager.default
    var outputPath:URL!

    init(filePath: String) {
        let asset = AVAsset(url: URL.init(fileURLWithPath: filePath))
        reader = try! AVAssetReader(asset: asset)
        videoTrack = asset.tracks(withMediaType: .video).first
        readerOutput = AVAssetReaderTrackOutput(track: videoTrack!, outputSettings: [String(kCVPixelBufferPixelFormatTypeKey):NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)])
        if reader.canAdd(readerOutput) {
            reader.add(readerOutput)
        }
        reader.startReading()
        
        outputPath = URL(fileURLWithPath: localPath + "/output.mp4")
        if fileManager.fileExists(atPath: outputPath.absoluteString) {
            try? fileManager.removeItem(at: outputPath)
        }
        if !fileManager.fileExists(atPath: localPath) {
            try? fileManager.createDirectory(atPath: localPath,withIntermediateDirectories: true)
        }
        print(outputPath.absoluteString)
        writer = try? AVAssetWriter(url: outputPath, fileType: .mp4)
        writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:videoTrack.naturalSize.width,AVVideoHeightKey:videoTrack.naturalSize.height])
        let sourcePixelBufferAttributesDictionary = [String(kCVPixelBufferPixelFormatTypeKey):NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)]
        pixelBufferAdepter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        if writer.canAdd(writerInput) {
            writer.add(writerInput)
        }
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
    }
    
    func convert() {
        //解码写
        readerQueue.async {[weak self] in
            while self?.reader.status == .reading {
                guard let sampleBuffer = self?.readerOutput.copyNextSampleBuffer() else {
                    if self?.reader.status == .failed {
                        print("解码失败！\(String(describing: self?.reader.error))")
                        return
                    }
                    print("解码结束！")
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
//                let bytesPreRow = CVPixelBufferGetBytesPerRow(imageBuffer)
//                let dicAttributes = CVPixelBufferCopyCreationAttributes(imageBuffer)
                let data = Data(bytes: pixelBuffer, count: size)
                guard let localPath = self?.localPath else {
                    break
                }
                let bufferFile = localPath + "/" + String(Int64(CMTimeGetSeconds(timeStamp) * 1000000.0))
                print(String(Int64(CMTimeGetSeconds(timeStamp) * 1000000.0)))
                let bufferUrl = URL(fileURLWithPath: bufferFile, isDirectory: false)
                do {
                    try data.write(to: bufferUrl ,options:.atomicWrite)
                } catch {
                    print("写文件失败！\(error)")
                }
                let frameInfo: [String : Any] = ["fileName":Int64(timeStamp.seconds * 1000000.0),"width":width,"height":height,"size":size]
                self?.frameArray.append(frameInfo)
                
                CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
            }
            
            //读数据
            self?.writerInput.requestMediaDataWhenReady(on: self?.writerQueue ?? DispatchQueue.main) {
                guard let info:Dictionary = self?.frameArray.last else {
                    return
                }
                guard let lastFileName = info["fileName"] as? Int64 else {
                    return
                }
                
                self?.frameArray.reversed().forEach { idx in
                    var done = false
                    while !done {
                        if self?.writerInput.isReadyForMoreMediaData == false {
                            continue
                        }
                        
                        let fileName = idx["fileName"] as! Int64
                        let width = idx["width"] as! Int
                        let height = idx["height"] as! Int
                        let size = idx["size"] as! Int
                        guard let localPath = self?.localPath else {
                            return
                        }
                        let filePath = localPath + "/" + String(fileName)
                        let data:Data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
                        var pixelBuffer: CVPixelBuffer!
                        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, nil, &pixelBuffer)
                        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
                        let pxDataDts = CVPixelBufferGetBaseAddress(pixelBuffer)
                                                
                        let ptr = unsafeBitCast(pxDataDts, to: UnsafeMutablePointer<UInt8>.self)
                        data.copyBytes(to: ptr, count: size)
//                        memcpy(pxDataDts!, ptr, size)
                        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
                        self?.pixelBufferAdepter.append(pixelBuffer!, withPresentationTime: CMTimeMake(value: Int64(lastFileName - fileName) , timescale: 1000000))
                        try? self?.fileManager.removeItem(atPath: filePath)
                        done = true
                    }
                }
                self?.writerInput.markAsFinished()
                self?.writer.finishWriting(completionHandler: {
                    print("转码结束")
                })
            }
        }
    }
}
