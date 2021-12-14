//
//  LDXFileReader.swift
//  DF
//
//  Created by 刘东旭 on 2021/10/30.
//

import Foundation
import AVFoundation

class LDXFileReader {
    var reader: AVAssetReader!
    var videoTrack: AVAssetTrack!
    var readerOutput: AVAssetReaderTrackOutput!
    var cacheSampleBuffer: CMSampleBuffer?
    var cacheSampleBufferTime: Int64 = 0
    var cacheSampleBufferDecodeTime: Int64 = 0
    init(asset: AVAsset) {
        reader = try! AVAssetReader(asset: asset)
        videoTrack = asset.tracks(withMediaType: .video).first
        readerOutput = AVAssetReaderTrackOutput(track: videoTrack!, outputSettings: [String(kCVPixelBufferPixelFormatTypeKey):kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange])
        readerOutput.alwaysCopiesSampleData = true
        readerOutput.supportsRandomAccess = true
        if reader.canAdd(readerOutput) {
            reader.add(readerOutput)
        }
        
        reader.timeRange = CMTimeRangeMake(start: .zero, duration: videoTrack.minFrameDuration)
        reader.startReading()
        while true {
            let sampleBuffer = readerOutput.copyNextSampleBuffer()
            if sampleBuffer != nil {
                CMSampleBufferInvalidate(sampleBuffer!)
            } else {
                break
            }
        }
    }
    
    func decodeFrame(time:Int64) -> CMSampleBuffer? {
//        print("decodeFrameTime:\(time)")
        if cacheSampleBuffer != nil && time == cacheSampleBufferTime {
            return cacheSampleBuffer
        }
        readerOutput.reset(forReadingTimeRanges: [NSValue(timeRange: CMTimeRangeMake(start: CMTimeMake(value: time, timescale: 1000000), duration: videoTrack.minFrameDuration))])
        
        var done = false
        while !done {
            let sampleBuffer = readerOutput.copyNextSampleBuffer()
            if sampleBuffer == nil {
                done = true
            } else {
                cacheSampleBuffer = sampleBuffer
                let presentTime = CMSampleBufferGetPresentationTimeStamp(cacheSampleBuffer!)
                cacheSampleBufferTime = Int64(CMTimeGetSeconds(presentTime) * 1000000)
//                print("cacheSampleBufferTime:\(cacheSampleBufferTime)")
            }
        }
        
        if cacheSampleBuffer == nil {
            print("解码失败！")
            checkReaderStatus()
        }
        return cacheSampleBuffer
    }
    
    func checkReaderStatus() {
        switch reader.status {
        case .unknown:
            print("未知状态")
            break
        case .reading:
            print("读取状态")
            break
        case .completed:
            print("完成状态")
            break
        case .failed:
            print("失败状态")
            break
        case .cancelled:
            print("取消状态")
            break
        default:
            print("未知状态")
            break
        }
    }
}
