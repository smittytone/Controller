//  DeviceTableViewController.swift
//  Created by Tony Smith on 1/16/18.
//  Copyright © 2018 Black Pyramid. All rights reserved.


import UIKit
import WatchKit
import WatchConnectivity


class DeviceTableViewController: UITableViewController, WCSessionDelegate {

    @IBOutlet weak var deviceTable:UITableView!

    var myDevices: DeviceList!
    var editingDevice: Device!
    var actionButton: UIBarButtonItem!
    var ddvc: DeviceDetailViewController!
    var phoneSession: WCSession? = nil

    var deviceRow: Int = -1
    var currentDevice: Int = -1
    var tableEditingFlag: Bool = false
    var tableOrderingFlag: Bool = false

    
    override func viewDidLoad() {

        super.viewDidLoad()

        // Set up the table's selection persistence
        self.clearsSelectionOnViewWillAppear = false

        // Set up the Edit button
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        self.navigationItem.rightBarButtonItem!.tintColor = UIColor.white
        self.navigationItem.rightBarButtonItem!.action = #selector(self.editTouched)

        // Set up the Actions button
        actionButton = UIBarButtonItem.init(title: "Actions",
                                           style: UIBarButtonItemStyle.plain,
                                           target: self,
                                           action: #selector(self.actionsTouched))
        self.navigationItem.leftBarButtonItem = actionButton
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.white

        // Initialise object properties
        self.tableOrderingFlag = false
        self.tableEditingFlag = false
        self.editingDevice = nil
        
        // Watch for app returning to foreground with DeviceDetailViewController active
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.viewWillAppear),
                                               name: NSNotification.Name.UIApplicationWillEnterForeground,
                                               object: nil)
    
        // Prepare the session
        if WCSession.isSupported() {
            // Only proceed on an iPhone
            // NOTE This is NOT a universal app
            self.phoneSession = WCSession.default
            if let session = self.phoneSession {
                if session.isPaired {
                    if session.isWatchAppInstalled {
                        // All good
                        session.delegate = self
                        session.activate()
                    } else {
                        // Watch app not installed, so warn user
                        self.phoneSession = nil
                        showAlert("This app needs a companion Watch app", "Please install the companion app on your Watch")"
                    }
                } else {
                    // iPhone is not paired with a watch, so warn user
                    self.phoneSession = nil
                    showAlert("This app requires an Apple Watch", "Please pair your Apple Watch with this iPhone")
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)

        // Get the list of devices
        self.myDevices = DeviceList.sharedDevices

        if self.editingDevice != nil {
            // 'editingDevice' is only non-nil if we have just edited a device's details
            let device = self.myDevices.devices[deviceRow]
            device.name = self.editingDevice.name
            device.code = self.editingDevice.code
            device.app = self.editingDevice.app
            device.watchSupported = self.editingDevice.watchSupported
            self.editingDevice = nil
        }

        // Update table to show any changes made
        self.deviceTable.reloadData()
    }


    // MARK: - Control Methods

    @objc func editTouched() {

        if !self.tableOrderingFlag {
            // The Nav Bar's Edit button has been tapped, so select or cancel editing mode
            self.deviceTable.setEditing(!self.deviceTable.isEditing, animated: true)

            // According to the current mode, set the title of the Edit button:
            // Editing mode: Done
            // Viewing mode: Edit
            if self.deviceTable.isEditing {
                self.tableEditingFlag = true
                self.navigationItem.rightBarButtonItem!.title = "Done"
                self.navigationItem.leftBarButtonItem!.isEnabled = false
            } else {
                self.tableEditingFlag = false
                self.navigationItem.rightBarButtonItem!.title = "Edit"
                self.navigationItem.leftBarButtonItem!.isEnabled = true
            }
        } else {
            // If the 'Done' button is tapped while table is reordering,
            // cancel the reordering
            self.tableOrderingFlag = false
            self.tableEditingFlag = false
            self.deviceTable.setEditing(false, animated: true)
            self.navigationItem.rightBarButtonItem!.title = "Edit"
            self.navigationItem.leftBarButtonItem!.isEnabled = true
        }

        // Re-display the table to add/remove the editing/moving widgets
        self.deviceTable.reloadData()
    }

    @objc func actionsTouched() {

        // Show the Actions menu
        let actionMenu = UIAlertController.init(title: "Select an Action from the List Below", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        var action: UIAlertAction!

        action = UIAlertAction.init(title: "Update Watch", style: UIAlertActionStyle.default) { (alertAction) in
            self.updateWatch()
        }

        actionMenu.addAction(action)

        action = UIAlertAction.init(title: "Show App Info", style: UIAlertActionStyle.default) { (alertAction) in
            self.showInfo()
        }

        actionMenu.addAction(action)

        action = UIAlertAction.init(title: "Re-order Device List", style: UIAlertActionStyle.default) { (alertAction) in
            // Switch off editing if it is on
            self.deviceTable.setEditing(true, animated:true)

            // Set the reordering flag
            self.tableOrderingFlag = !self.tableOrderingFlag
            self.tableEditingFlag = true

            // But use the editing flag to manage the right-hand button
            self.navigationItem.rightBarButtonItem!.title = "Done"
            self.navigationItem.leftBarButtonItem!.isEnabled = false

            self.deviceTable.reloadData()
        }

        actionMenu.addAction(action)

        action = UIAlertAction.init(title: "Cancel", style: UIAlertActionStyle.cancel, handler:nil)

        actionMenu.addAction(action)

        self.present(actionMenu, animated: true, completion: nil)
    }

    @objc func updateWatch() {

        if let session = self.phoneSession {
            sendDeviceList(session)
        }
    }

    @objc func showInfo() {

        // Show application info
        let alert = UIAlertController.init(title: "Controller\nInformation", message: "This app...", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true)
    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {

        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        if tableEditingFlag == true && tableOrderingFlag == false {
            // If we're in edit mode, add an extra line for the 'New Device' entry...
            return self.myDevices.devices.count + 1
        } else {
            // ...otherwise just show the list of devices
            return self.myDevices.devices.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // Get a new table cell from the queue of existing cells, or create one if none are available
        let cell = tableView.dequeueReusableCell(withIdentifier:"device.cell", for:indexPath)

        if indexPath.row == self.myDevices.devices.count {
            // Append the extra row required by entering the table's editing mode
            cell.textLabel?.text = "Add New Device"
            cell.detailTextLabel?.text = ""
        } else {
            let device: Device = self.myDevices.devices[indexPath.row]
            cell.textLabel?.text = device.name.count > 0 ? device.name : "Device \(self.myDevices.devices.count)"
            cell.detailTextLabel?.text = device.code.count > 0 ? device.code : "Code not yet set"
            cell.imageView?.image = getAppImage(device.app)

            // Do we show the re-order control?
            cell.showsReorderControl = self.tableOrderingFlag
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        // Instantiate the device detail view controller as required - ie. every time
        if self.ddvc == nil {
            let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
            self.ddvc = storyboard.instantiateViewController(withIdentifier: "device.detail.view") as! DeviceDetailViewController
            self.ddvc.navigationItem.title = "Device Info"
            self.ddvc.navigationItem.leftBarButtonItem = UIBarButtonItem.init(title: "Devices",
                                                                              style: UIBarButtonItemStyle.plain,
                                                                              target: self.ddvc,
                                                                              action: #selector(self.ddvc.changeDetails))
            self.ddvc.navigationItem.leftBarButtonItem?.tintColor = UIColor.white
        }

        // Set DeviceDetailViewController's currentDevice properties

        // Create a new device if necessary
        if editingDevice == nil { editingDevice = Device() }

        let device: Device = self.myDevices.devices[indexPath.row]
        self.editingDevice.name = device.name
        self.editingDevice.code = device.code
        self.editingDevice.app = device.app
        self.editingDevice.watchSupported = device.watchSupported
        self.deviceRow = indexPath.row

        // Set the LED colour graphic
        self.ddvc.currentDevice = editingDevice

        // Present the device detail view controller
        self.navigationController?.pushViewController(self.ddvc, animated: true)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {

        // NOTE All table rows are editable, including the 'Add New Device' row
        return true
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) ->UITableViewCellEditingStyle {

        if !self.tableOrderingFlag {
            return (indexPath.row == self.myDevices.devices.count ? UITableViewCellEditingStyle.insert : UITableViewCellEditingStyle.delete)
        } else {
            return UITableViewCellEditingStyle.none
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
            // Remove the deleted row's imp from the data source FIRST
            self.myDevices.devices.remove(at: indexPath.row)

            // Now delete the table row itself then update the table
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.reloadData()
        } else if editingStyle == .insert {
            // Create a new imp with default name and code values
            let device:Device = Device()

            // Add new imp to the list
            self.myDevices.devices.append(device)

            // And add it to the table
            tableView.insertRows(at: [indexPath], with: UITableViewRowAnimation.none)
            self.deviceTable.reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {

        // NOTE Can move all rows except a the last line if it's 'Add New Device'
        return (indexPath.row == self.myDevices.devices.count ? false : self.tableOrderingFlag)
    }

    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

        let start: Int = fromIndexPath.row
        let end: Int = to.row
        let aDevice: Device = self.myDevices.devices[start]
        self.myDevices.devices.remove(at: start)
        self.myDevices.devices.insert(aDevice, at: end)
        tableView.reloadData()
    }

    func getAppImage(_ type:String) -> UIImage? {

        let imageName: String = getAppTypeAsString(type)
        return UIImage(named: imageName)
    }

    func getAppTypeAsString(_ code:String) -> String {

        if code == "761DDC8C-E7F5-40D4-87AC-9B06D91A672D" { return "weather" }
        if code == "8B6B3A11-00B4-4304-BE27-ABD11DB1B774" { return "homeWeather" }
        if code == "0028C36B-444A-408D-B862-F8E4C17CB6D6" { return "matrixclock" }

        return "unknown"
    }


    // MARK: - WCSessionDelegate Functions

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {

        if activationState == WCSessionActivationState.activated {
            // sendDeviceList(session)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {

        // NOP - Function required by delegate but not used
    }

    func sessionDidDeactivate(_ session: WCSession) {

        // NOP - Function required by delegate but not used
    }

    func sendDeviceList(_ session: WCSession) {

        // Construct a list of devices with watch support
        // var updateableDevices: [[String:String]] = []
        var dataString: String = ""
        
        if self.myDevices.devices.count > 0 {
            for i in 0..<self.myDevices.devices.count {
                let aDevice: Device = self.myDevices.devices[i]
                if aDevice.watchSupported {
                    dataString = dataString + aDevice.name + "\n" + aDevice.code + "\n" + aDevice.app + "\n\n"
                }
            }
        }
        
        if dataString.count > 0 {
            // Try sending the data as a message
            // session.sendMessage(["devices" : updateableDevices], replyHandler: nil, errorHandler: nil)
            
            if let session = self.phoneSession {
                do {
                    try session.updateApplicationContext(["info" : dataString])
                    print("Message Sent")
                } catch {
                    print("Message not sent")
                }
            }
        }
    }
    
    
    // MARK: Utility Functions
    
    func showAlert(_ title: String, _ message: String) {
        
        let alert = UIAlertController.init(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .`default`, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    
}
