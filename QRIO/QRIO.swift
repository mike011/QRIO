//
//  QRIO.swift
//  Nodes
//
//  Created by Chris on 30/06/16.
//  Copyright © 2016 Nodes. All rights reserved.
//

import UIKit
import AVFoundation
import CoreImage

public class QRInput: NSObject, AVCaptureMetadataOutputObjectsDelegate {
	private var session: AVCaptureSession?
	private var previewLayer: AVCaptureVideoPreviewLayer?
	
	public var imageScanCompletionBlock: ((string: String) -> ())?
	
	
	public func scanForQRImage(previewIn previewContainer: UIView? = nil, rectOfInterest: CGRect? = nil, completion: ((string: String) -> ())) {
		session = AVCaptureSession()
		let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
		
		do {
			let input = try AVCaptureDeviceInput(device: device)
			session?.addInput(input)
		} catch {
			// Trying to run in simulator
			return
		}
		
		let output = AVCaptureMetadataOutput()
		output.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
		session?.addOutput(output)
		output.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
		
		imageScanCompletionBlock = completion
		
		if let previewContainer = previewContainer {
			previewLayer = AVCaptureVideoPreviewLayer(session: session)
			previewContainer.layer.addSublayer(previewLayer!)
			previewLayer!.frame = previewContainer.bounds
			previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
			
		}
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) { [weak self] in
			self?.session?.startRunning()
		}
		
		if let rectOfInterest = rectOfInterest, previewLayer = previewLayer {
			output.rectOfInterest = previewLayer.metadataOutputRectOfInterestForRect(rectOfInterest)
		}
	}
	
	public func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
		var QRCode: String?
		for metadata in metadataObjects as! [AVMetadataObject] {
			if metadata.type == AVMetadataObjectTypeQRCode {
				QRCode = (metadata as! AVMetadataMachineReadableCodeObject).stringValue
			}
		}
		if let code = QRCode {
			imageScanCompletionBlock?(string: code)
		}
	}
	
	public func finish() {
		imageScanCompletionBlock = nil
		if let session = session {
			session.stopRunning()
			for input in session.inputs{
				session.removeInput(input as! AVCaptureInput)
			}
			for output in session.outputs{
				session.removeOutput(output as! AVCaptureOutput)
			}
		}
		previewLayer?.removeFromSuperlayer()
		previewLayer = nil
	}
}


public extension UIImage {
	public static func QRImageFromString(string: String, containingViewSize: CGSize? = nil, correctionLevel: String = "L") -> UIImage? {
		let stringData = string.dataUsingEncoding(NSISOLatin1StringEncoding)
		let filter = CIFilter(name: "CIQRCodeGenerator")
		filter?.setValue(stringData, forKey: "inputMessage")
		filter?.setValue(correctionLevel, forKey: "inputCorrectionLevel")
		
		guard let resultImage = filter?.outputImage else { return nil }
		
		var scaleX = resultImage.extent.size.width
		var scaleY = resultImage.extent.size.height
		if let size = containingViewSize {
			scaleX = size.width / resultImage.extent.size.width
			scaleY = size.height / resultImage.extent.size.height
		}
		
		let qrImage = resultImage.imageByApplyingTransform(CGAffineTransformMakeScale(scaleX, scaleY))
		let context = CIContext()
		if let tempImage: CGImageRef = context.createCGImage(qrImage, fromRect: qrImage.extent) {
			return UIImage(CGImage: tempImage)
		}
		return nil
	}
}
