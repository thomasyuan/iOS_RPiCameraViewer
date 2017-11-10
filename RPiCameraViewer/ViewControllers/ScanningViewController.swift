// Copyright © 2017 Shawn Baker using the MIT License.
import UIKit

class ScanningViewController: UIViewController
{
	// outlets
	@IBOutlet weak var messageLabel: UILabel!
	@IBOutlet weak var progressView: UIProgressView!
	@IBOutlet weak var statusLabel: UILabel!
	@IBOutlet weak var cancelButton: Button!
	
	// constants
	let NO_DEVICE = -1
	let NUM_THREADS = 40
	let DISMISS_TIMEOUT = 1.5
	let app = UIApplication.shared.delegate as! AppDelegate
	let semaphore = DispatchSemaphore(value: 1)
	
	// variables
	var network = Utils.getNetworkName()
	var ipAddress = Utils.getIPAddress()
	var device = 0
	var numDone = 0
	var newCameras = [Camera]()
	var scanning = true

	//**********************************************************************
	// viewDidLoad
	//**********************************************************************
    override func viewDidLoad()
    {
        super.viewDidLoad()
		
		messageLabel.text = String(format: "scanningOnPort".local, app.settings.source.port)
		progressView.progress = 0
		progressView.transform = progressView.transform.scaledBy(x: 1, y: 2)
		statusLabel.text = String(format: "newCamerasFound".local, 0)
		cancelButton.addTarget(self, action:#selector(handleCancelButtonTouchUpInside), for: .touchUpInside)
		
		if !ipAddress.isEmpty
		{
			let octets = ipAddress.split(separator: ".")
			for _ in 1...NUM_THREADS
			{
				DispatchQueue.global(qos: .background).async
				{
					var dev: Int = self.getNextDevice()
					while self.scanning && dev != self.NO_DEVICE
					{
						let address = String(format: "%@.%@.%@.%d", String(octets[0]), String(octets[1]), String(octets[2]), dev)
						if address != self.ipAddress
						{
							let socket = openSocket(address, Int32(self.app.settings.source.port), Int32(self.app.settings.scanTimeout))
							if (socket >= 0)
							{
								self.addCamera(address)
								closeSocket(socket)
							}
						}
						self.doneDevice(dev);
						dev = self.getNextDevice()
					}
				}
			}
		}
    }
	
	//**********************************************************************
	// handleCancelButtonTouchUpInside
	//**********************************************************************
	@objc func handleCancelButtonTouchUpInside(_ sender: UIButton)
	{
		scanning = false
		self.performSegue(withIdentifier: "UpdateCameras", sender: self)
    }
	
	//**********************************************************************
	// getNextDevice
	//**********************************************************************
	func getNextDevice() -> Int
	{
		var nextDevice = NO_DEVICE
		semaphore.wait()
		if device < 254
		{
			device += 1
			nextDevice = device
		}
		semaphore.signal()
		return nextDevice
	}
	
	//**********************************************************************
	// doneDevice
	//**********************************************************************
	func doneDevice(_ device: Int)
	{
		semaphore.wait()
		numDone += 1
		setStatus(numDone == 254)
		semaphore.signal()
	}

	//**********************************************************************
	// addCamera
	//**********************************************************************
	func addCamera(_ address: String)
	{
		semaphore.wait()
		var found = false
		for camera in self.app.cameras
		{
			if camera.network == self.network && camera.source.address == address && camera.source.port == self.app.settings.source.port
			{
				found = true
				break;
			}
		}
		if !found
		{
			//Log.info("addCamera: " + newCamera.source.toString());
			let camera = Camera(self.network, "", Source(address: address))
			self.newCameras.append(camera)
		}
		semaphore.signal()
	}

	//**********************************************************************
	// addCameras
	//**********************************************************************
	func addCameras()
	{
		if newCameras.count > 0
		{
			// sort the new cameras by IP address
			//Log.info("addCameras");
			newCameras.sort(by: compareCameras)
			
			// get the maximum number from the existing camera names
			var max = Utils.getMaxCameraNumber(app.cameras);
			
			// set the camera names and add the new cameras to the list of all cameras
			let defaultName = app.settings.cameraName + " ";
			for camera in newCameras
			{
				max += 1
				camera.name = defaultName + String(max);
				app.cameras.append(camera);
				//Log.info("camera: " + camera.toString());
			}
			
			app.save()
		}
	}

	//**********************************************************************
	// compareCameras
	//**********************************************************************
	func compareCameras(cam1: Camera, cam2: Camera) -> Bool
	{
		let octets1 = cam1.source.address.split(separator: ".")
		let octets2 = cam2.source.address.split(separator: ".")
		let last1 = Int(octets1[3])
		let last2 = Int(octets2[3])
		return last1! < last2!
	}
	
	//**********************************************************************
	// setStatus
	//**********************************************************************
	func setStatus(_ last: Bool)
	{
		DispatchQueue.main.async
		{
			self.progressView.progress = Float(self.numDone) / 254.0
			self.statusLabel.text = String(format: "newCamerasFound".local, self.newCameras.count)
			if self.newCameras.count > 0
			{
				self.statusLabel.textColor = UIColor.black
			}
			else if last
			{
				self.statusLabel.textColor = UIColor.red
			}
			if last
			{
				self.cancelButton.setTitle("done".local, for: UIControlState.normal)
				if self.newCameras.count > 0 && self.scanning
				{
					self.addCameras()
					DispatchQueue.main.asyncAfter(deadline: .now() + self.DISMISS_TIMEOUT, execute:
					{
						self.performSegue(withIdentifier: "UpdateCameras", sender: self)
					})
				}
			}
		}
	}
}