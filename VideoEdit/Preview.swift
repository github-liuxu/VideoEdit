//
//  Preview.swift
//  DF
//
//  Created by 刘东旭 on 2021/11/13.
//

import Foundation
import UIKit
import AVFoundation

class Preview: UIView {
    override class var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }
    
    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        let sampleBufferDisplayLayer: AVSampleBufferDisplayLayer = layer as! AVSampleBufferDisplayLayer
        sampleBufferDisplayLayer.flushAndRemoveImage()
        sampleBufferDisplayLayer.enqueue(sampleBuffer)
    }
    
}
