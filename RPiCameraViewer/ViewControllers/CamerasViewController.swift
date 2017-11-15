// Copyright © 2016-2017 Shawn Baker using the MIT License.
import UIKit

class CamerasViewController: UIViewController, UITableViewDataSource, UITableViewDelegate
{
	// outlets
	@IBOutlet weak var tableView: UITableView!
	
	// constants
	let SCAN_TIMEOUT = 0.5
	
	// instance variables
	let cameraCellId = "CameraCell"
	let emptyCellId = "EmptyCameraCell"
	let app = UIApplication.shared.delegate as! AppDelegate
	var camera = Camera()
	var cameras = [Camera]()

	//**********************************************************************
	// viewDidLoad
	//**********************************************************************
	override func viewDidLoad()
	{
		// initialize the views
		super.viewDidLoad()
		tableView.delegate = self
		tableView.dataSource = self

		// get the list of cameras
		refreshCameras()
		
		// if there are no cameras then do a scan
		if cameras.count == 0
		{
			DispatchQueue.main.asyncAfter(deadline: .now() + self.SCAN_TIMEOUT, execute:
			{
				self.performSegue(withIdentifier: "ScanForCameras", sender: self)
			})
		}
	}

	//**********************************************************************
	// didReceiveMemoryWarning
	//**********************************************************************
	override func didReceiveMemoryWarning()
	{
		super.didReceiveMemoryWarning()
	}

	//**********************************************************************
	// cancelCamera
	//**********************************************************************
	@IBAction func cancelCamera(segue:UIStoryboardSegue)
	{
	}

	//**********************************************************************
	// saveCamera
	//**********************************************************************
	@IBAction func saveCamera(segue:UIStoryboardSegue)
	{
		if segue.identifier == "SaveCamera",
			let vc = segue.source as? CameraViewController
		{
			// update the global list of cameras
			if let i = app.cameras.index(of: camera)
			{
				app.cameras.remove(at: i)
			}
			app.cameras.append(vc.camera)
			app.cameras = app.cameras.sorted(by: { $0.name < $1.name })
			app.save()
			
			// refresh the local list of cameras
			refreshCameras()
		}
	}

	//**********************************************************************
	// getCameras
	//**********************************************************************
	func getCameras()
	{
		cameras = app.settings.showAllCameras ? app.cameras : Utils.getNetworkCameras()
		cameras.sort(by: { $0.name < $1.name })
	}
	
	//**********************************************************************
	// refreshCameras
	//**********************************************************************
	func refreshCameras()
	{
		getCameras()
		tableView.reloadData()
	}
	
	//**********************************************************************
	// updateCameras
	//**********************************************************************
	@IBAction func updateCameras(segue:UIStoryboardSegue)
	{
		refreshCameras()
	}

	//**********************************************************************
	// deleteAllCameras
	//**********************************************************************
	@IBAction func deleteAllCameras(_ sender: UIBarButtonItem)
	{
		let alert = UIAlertController(title: "deleteAllCameras".local, message: "okToDeleteAllCameras".local, preferredStyle: .alert)
		
		alert.addAction(UIAlertAction(title: "yes".local, style: .default) { (action:UIAlertAction) in

			// remove the cameras from the global list of cameras
			for camera in self.cameras
			{
				if let i = self.app.cameras.index(of: camera)
				{
					self.app.cameras.remove(at: i)
				}
			}
			
			// refresh the local list of cameras
			self.refreshCameras()
		})
		alert.addAction(UIAlertAction(title: "no".local, style: .default))

		self.present(alert, animated: true, completion: nil)
	}

	// MARK: - Navigation

	//**********************************************************************
	// prepare
	//**********************************************************************
	override func prepare(for segue: UIStoryboardSegue, sender: Any?)
	{
		if let vc = segue.destination as? CameraViewController
		{
			if segue.identifier == "CreateCamera"
			{
				let source = Source(address: Utils.getBaseIPAddress(Utils.getIPAddress()))
				vc.camera = Camera(Utils.getNetworkName(), Utils.getNextCameraName(app.cameras), source)
				self.camera = vc.camera
			}
			else if segue.identifier == "EditCamera", let camera = sender as? Camera
			{
				vc.camera = Camera(camera)
				self.camera = camera
			}
		}
		else if let vc = segue.destination as? VideoViewController
		{
			if segue.identifier == "ShowVideo", let camera = sender as? Camera
			{
				vc.camera = Camera(camera)
			}
		}
	}

	// MARK:  UITableViewDataSource Methods

	//**********************************************************************
	// tableView numberOfRowsInSection
	//**********************************************************************
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
	{
		return cameras.count
	}

	//**********************************************************************
	// tableView cellForRowAt
	//**********************************************************************
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
	{
		let cell = tableView.dequeueReusableCell(withIdentifier: cameraCellId, for: indexPath)
		let camera = cameras[indexPath.row]
		cell.textLabel?.text = camera.name
		var details = camera.source.address + ":" + String(camera.source.port)
		if app.settings.showAllCameras
		{
			details = camera.network + ": " + details
		}
		cell.detailTextLabel?.text = details
		return cell
	}

	//**********************************************************************
	// tableView commit
	//**********************************************************************
	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath)
	{
		if editingStyle == .delete
		{
			// remove the camera from the global list of cameras
			let camera = cameras[indexPath.row]
			if let i = app.cameras.index(of: camera)
			{
				app.cameras.remove(at: i)
			}
			app.save()
			
			// refresh the local list of cameras
			refreshCameras()
		}
	}

	// MARK:  UITableViewDelegate Methods

	//**********************************************************************
	// tableView didSelectRowAt
	//**********************************************************************
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
	{
		let camera = cameras[indexPath.row]
		performSegue(withIdentifier: "ShowVideo", sender: camera)
	}
	
	//**********************************************************************
	// tableView accessoryButtonTappedForRowWith
	//**********************************************************************
	func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath)
	{
		let camera = cameras[indexPath.row]
		performSegue(withIdentifier: "EditCamera", sender: camera)
	}
}

