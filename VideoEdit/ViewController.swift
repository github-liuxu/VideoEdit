//
//  ViewController.swift
//  DF
//
//  Created by 刘东旭 on 2021/10/30.
//

import UIKit
import Foundation
import AVFoundation

class ViewController: UIViewController {

    var fileReader: LDXFileReader!
    var timer: Timer!
    @IBOutlet weak var preview: Preview!
    var duration: Int64 = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let filePath = Bundle.main.path(forResource: "test", ofType: "mp4")
        let asset = AVAsset(url: URL.init(fileURLWithPath: filePath!))
        fileReader = LDXFileReader(asset: asset)
        duration = Int64(CMTimeGetSeconds(asset.duration) * 1000000.0)

        let sampleBuffer:CMSampleBuffer? = fileReader.decodeFrame(time: 0)
        if sampleBuffer == nil {
            return
        }
        preview.enqueue(sampleBuffer!)

    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        let value = Int64(sender.value * Float(duration))
        let sampleBuffer:CMSampleBuffer? = fileReader.decodeFrame(time: value)
        if sampleBuffer == nil {
            return
        }
        preview.enqueue(sampleBuffer!)
    }

    // Convert CIImage to CGImage
    func convert(cmage:CIImage) -> UIImage
    {
         let context:CIContext = CIContext.init(options: nil)
         let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
         let image:UIImage = UIImage.init(cgImage: cgImage)
         return image
    }
    
    var convert: Convertor!
    var con: Convert!
    @IBAction func daofangClick(_ sender: Any) {
        let filePath = Bundle.main.path(forResource: "test", ofType: "mp4")
//        convert = Convertor(filePath: filePath!)
//        convert.convert()
        con = Convert(filePath!)
        con.convert()
    }
}

