
//  DeviceTableViewController.swift
//  Created by Tony Smith on 1/16/18.
//
//  Copyright 2018-19 Tony Smith
//
//  SPDX-License-Identifier: MIT
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
//  OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.


import UIKit

// FROM 1.2.0
// Add code to compile under Xcode 11
#if !os(iOS)
    import WatchKit
#endif

import WatchConnectivity


class DeviceTableViewController: UITableViewController, WCSessionDelegate {
    
    // MARK: Class Properties
    @IBOutlet weak var deviceTable:UITableView!

    var myDevices: DeviceList!
    var editingDevice: Device!
    var ddvc: DeviceDetailViewController!
    var actionButton: UIBarButtonItem!
    var phoneSession: WCSession? = nil
    var currentDeviceRow: Int = -1
    var tableEditingFlag: Bool = false
    var tableOrderingFlag: Bool = false
    var tableShowIDsFlag: Bool = true
    var watchAppInstalled: Bool = false
    var apps: [String : Any] = [:]
    
    // MARK: Class Constants
    let STATE_INSTALLING = 1
    let STATE_REMOVING = 0
    let STATE_NONE = -1

    
    // MARK: - Lifecycle Functions
    
    override func viewDidLoad() {

        super.viewDidLoad()

        // Set up the table's selection persistence
        self.clearsSelectionOnViewWillAppear = false

        // Set up the Edit button
        //self.navigationItem.rightBarButtonItem = self.editButtonItem
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "Add",
                                                                      style: UIBarButtonItem.Style.plain,
                                                                      target: self,
                                                                      action: #selector(self.addDevice))
        self.navigationItem.rightBarButtonItem!.tintColor = UIColor.white
        //self.navigationItem.rightBarButtonItem!.action = #selector(self.editTouched)

        // Set up the Actions button
        actionButton = UIBarButtonItem.init(title: "Actions",
                                           style: UIBarButtonItem.Style.plain,
                                           target: self,
                                           action: #selector(self.actionsTouched))
        self.navigationItem.leftBarButtonItem = actionButton
        self.navigationItem.leftBarButtonItem!.tintColor = UIColor.white

        // Initialise object properties
        self.editingDevice = nil
        
        // Watch for app returning to foreground with DeviceDetailViewController active
        let nc: NotificationCenter = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(self.viewWillAppear),
                       name: UIApplication.willEnterForegroundNotification,
                       object: nil)
        
        nc.addObserver(self,
                       selector: #selector(self.doInstall),
                       name: NSNotification.Name.init("com.bps.controller.install.switch.hit"),
                       object: nil)
        
        // Read in the current apps list
        do {
            if let file = Bundle.main.url(forResource: "apps", withExtension: "json") {
                let data = try Data(contentsOf: file)
                // NSLog(String.init(data: data, encoding: String.Encoding.utf8)!)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let object = json as? [String: Any] {
                    self.apps = object
                } else {
                    showAlert("Error", "Apps list JSON is invalid")
                }
            } else {
                showAlert("Error", "Apps list file missing")
            }
        } catch {
            showAlert("Error", "Apps list file damaged")
        }
    }


    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)

        // Get the list of devices
        self.myDevices = DeviceList.sharedDevices

        if self.editingDevice != nil {
            // 'editingDevice' is only non-nil if we have just edited a device's details
            // via a Device Detail View Controller
            if self.editingDevice.changed {
                // Only update the device record if it has been changed
                let device = self.myDevices.devices[self.currentDeviceRow]
                device.name = self.editingDevice.name
                device.code = self.editingDevice.code
                device.app = self.editingDevice.app
                device.watchSupported = self.editingDevice.watchSupported
                
                // May want to keep this set?
                device.changed = false
            }
            
            // Clear 'editingDevice'
            self.editingDevice = nil
        }
        
        // Read the default for whether we show or hide Agent IDs
        let defaults: UserDefaults = UserDefaults.standard
        if let defaultValue = defaults.value(forKey: "com.bps.controller.show.agentids") as? NSNumber {
            self.tableShowIDsFlag = defaultValue.boolValue
        }
        
        // Prepare the session
        if WCSession.isSupported() {
            // Only proceed on an iPhone
            // NOTE This is NOT a universal app
            self.phoneSession = WCSession.default
            if let session = self.phoneSession {
                session.delegate = self
                if session.activationState == WCSessionActivationState.activated {
                    // We're already active, so just update the flag
                    self.watchAppInstalled = true
                } else {
                    // Activate the WCSession
                    session.activate()
                    return
                }
            }
        }

        // Update table to show any changes made
        self.deviceTable.reloadData()
    }


    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        // Zap the Device Detail View Controller if present
        if self.ddvc != nil { self.ddvc = nil }
    }


    override func didReceiveMemoryWarning() {
        
        super.didReceiveMemoryWarning()
        
        // Zap the device detail view controller if we have one
        // NOTE We shouldn't have one!s
        if self.ddvc != nil { self.ddvc = nil }
    }
    
    
    // MARK: - Control Methods

    @objc func editTouched() {

        if !self.tableOrderingFlag {
            // The Nav Bar's Edit button has been tapped, so select or cancel editing mode
            self.deviceTable.setEditing(!self.deviceTable.isEditing, animated: true)

            // According to the current mode, set the title of the Edit button:
            // Editing mode: Done
            // Viewing mode: Edit
            // And whether the left-hand button is active (NOT during editing)
            if self.deviceTable.isEditing {
                self.tableEditingFlag = true
                self.navigationItem.rightBarButtonItem!.title = "Done"
                self.navigationItem.leftBarButtonItem!.isEnabled = false
            } else {
                self.tableEditingFlag = false
                self.navigationItem.rightBarButtonItem!.title = "Add"
                self.navigationItem.leftBarButtonItem!.isEnabled = true
            }
        } else {
            // If the 'Done' button is tapped while table is reordering,
            // cancel the reordering operation
            self.tableOrderingFlag = false
            self.tableEditingFlag = false
            self.deviceTable.setEditing(false, animated: true)
            self.navigationItem.rightBarButtonItem!.title = "Add"
            self.navigationItem.leftBarButtonItem!.isEnabled = true
            
            // TODO Decide whether we should update the watch automatically here
        }

        // Re-display the table to add/remove the editing/moving widgets
        self.deviceTable.reloadData()
    }


    @objc func addDevice() {

        // Trap taps on the 'Done' button, only shown when editing or reordering
        // the device list
        if self.tableEditingFlag || self.tableOrderingFlag {
            editTouched()
            return
        }

        // Create a new imp with default name and code values
        let device:Device = Device()

        // Add new imp to the list
        self.myDevices.devices.append(device)
        device.name = "Device \(self.myDevices.devices.count)"

        // And add it to the table
        self.deviceTable.reloadData()
    }


    @objc func actionsTouched() {
        
        // Build and show the Actions menu
        let actionMenu = UIAlertController.init(title: "Select an Action from the List Below",
                                                message: nil,
                                                preferredStyle: UIAlertController.Style.actionSheet)
        var action: UIAlertAction!
        
        // Update Watch item
        action = UIAlertAction.init(title: "Update Watch",
                                    style: UIAlertAction.Style.default) { (_) in
                                        self.updateWatch()
                                    }

        action.isEnabled = self.watchAppInstalled
        actionMenu.addAction(action)
        
        // Edit Device List item
        action = UIAlertAction.init(title: "Edit Device List",
                                    style: UIAlertAction.Style.default) { (_) in
                                        self.editTouched()
        }

        actionMenu.addAction(action)

        // Reorder Device List item
        action = UIAlertAction.init(title: "Re-order Device List",
                                    style: UIAlertAction.Style.default) { (_) in
                                        self.reorderDevicelist()
                                    }

        actionMenu.addAction(action)
        
        // Show/Hide Agent IDs item
        action = UIAlertAction.init(title: (self.tableShowIDsFlag ? "Hide" : "Show") + " Agent IDs in Device List",
                                    style: UIAlertAction.Style.default) { (_) in
                                            self.showAgentIDs()
                                    }
        
        actionMenu.addAction(action)
        
        // Clear list
        action = UIAlertAction.init(title: "Clear Device List",
                                    style: UIAlertAction.Style.default) { (_) in
                                        self.clearList()
                                    }
        
        actionMenu.addAction(action)
        
        // Show App Info item
        action = UIAlertAction.init(title: "Show App Info",
                                    style: UIAlertAction.Style.default) { (_) in
                                        self.showInfo()
        }

        actionMenu.addAction(action)

        // Cancel item
        action = UIAlertAction.init(title: "Cancel",
                                    style: UIAlertAction.Style.cancel,
                                    handler:nil)

        actionMenu.addAction(action)
        
        // Present the menu
        self.present(actionMenu,
                     animated: true,
                     completion: nil)
    }


    @objc func updateWatch() {

        // Send the app list
        sendDeviceList()
    }


    @objc func showInfo() {

        // Show application info
        var active: Bool = false
        if let session = self.phoneSession {
            active = session.activationState == WCSessionActivationState.activated ? true : false
        }
        
        let defaults: UserDefaults = UserDefaults.standard
        let i = defaults.value(forKey: "com.bps.controller.devices.installcount") as! String
        let c = defaults.value(forKey: "com.bps.controller.devices.listcount") as! String
        
        let alert = UIAlertController.init(title: "About Controller",
                                           message: "Use this app to add controllers for your Electric Imp-enabled devices to your Apple Watch. Add a new device here, select it to enter its details, then tap the switch to add the device to the Controller Watch app.\n\n" + "Watch app " + (self.watchAppInstalled ? "" : "not ") + "installed\nSession " + (active ? "" : "in") + "active\n" + "Devices: " + c + "\nInstalled: " + i,
                                           preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"),
                                      style: UIAlertAction.Style.default,
                                      handler: nil))
        self.present(alert, animated: true)
    }


    @objc func showAgentIDs() {
        
        // Switch the show/hide flag and update the table
        self.tableShowIDsFlag = !self.tableShowIDsFlag
        deviceTable.reloadData()
        
        // Save the new setting to preferences
        let defaults: UserDefaults = UserDefaults.standard
        defaults.set(self.tableShowIDsFlag, forKey: "com.bps.controller.show.agentids")
    }


    @objc func reorderDevicelist() {
        
        // Switch off table editing if it is on
        self.deviceTable.setEditing(true, animated:true)
        
        // Set the reordering flag
        self.tableOrderingFlag = !self.tableOrderingFlag
        self.tableEditingFlag = true
        
        // But use the editing flag to manage the right-hand button
        self.navigationItem.rightBarButtonItem!.title = "Done"
        self.navigationItem.leftBarButtonItem!.isEnabled = false
        
        // Re-display the table
        self.deviceTable.reloadData()
    }


    @objc func clearList() {
        
        // Clear the device list - but only after checking
        let alert = UIAlertController.init(title: "Are You Sure?",
                                           message: "This will remove all devices from this app and from your Watch",
                                           preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "No",
                                      style: UIAlertAction.Style.default,
                                      handler: nil))
        alert.addAction(UIAlertAction(title: "Yes",
                                      style: UIAlertAction.Style.destructive,
                                      handler: { (_) in
                                        self.myDevices.devices.removeAll()
                                        self.sendDeviceList()
                                        self.tableView.reloadData()
        }))
        
        self.present(alert, animated: true)
    }


    @objc func doInstall(_ note: Notification) {

        // Install or uninstall a single app when its row switch is flipped
        let data: [String : Int] = note.userInfo as! [String : Int]
        let row: Int = data["row"]!
        let state: Int = data["state"]!
        let device: Device = myDevices.devices[row]

        // Mark the device as installing or uninistalling
        device.installState = state

        // Send the current data to the watch
        sendDeviceList()
    }


    func sendDeviceList() {

        if let session = self.phoneSession {
            // Only send if we're activated
            if session.activationState == WCSessionActivationState.activated {
                // Construct a list of devices with watch support
                // var updateableDevices: [[String:String]] = []
                var dataString: String = ""

                // Assemble the sync list string:
                // Devices are separated by two newlines
                // Device fields are separated by one newline
                // Fields: name, agent ID, app type code
                if self.myDevices.devices.count > 0 {
                    for i in 0..<self.myDevices.devices.count {
                        let aDevice: Device = self.myDevices.devices[i]
                        // Add the device to the sync list if:
                        //   It's installed but not set to be removed
                        //   It's not installed but set to be installed
                        if (aDevice.isInstalled && aDevice.installState != self.STATE_REMOVING) || aDevice.installState == self.STATE_INSTALLING {
                            dataString = dataString + aDevice.name + "\n" + aDevice.code + "\n" + aDevice.app + "\n\n"
                        }
                    }
                } else {
                    dataString = "clear"
                }

                // Send the sync list
                do {
                    // Attempt to send the context data
                    try session.updateApplicationContext(["info" : dataString])

                    var installedCount: Int = 0

                    // If we're here, we've successfully send the context data,
                    // so update the device records: no longer installing/uninistalling,
                    // and is installed/uninstalled
                    if self.myDevices.devices.count > 0 {
                        for i in 0..<self.myDevices.devices.count {
                            let aDevice: Device = self.myDevices.devices[i]
                            if aDevice.installState == self.STATE_INSTALLING {
                                // Device was being installed; now it is
                                aDevice.installState = self.STATE_NONE
                                aDevice.isInstalled = true
                            } else if aDevice.installState == self.STATE_REMOVING {
                                // Device was being removed; now it is
                                aDevice.installState = self.STATE_NONE
                                aDevice.isInstalled = false
                            }

                            if aDevice.isInstalled {
                                installedCount = installedCount + 1
                            }
                        }
                    }

                    let defaults: UserDefaults = UserDefaults.standard
                    defaults.set("\(installedCount)", forKey: "com.bps.controller.devices.installcount")

                    NSLog("Sync list sent")
                } catch {
                    // Context data did not send for some reason, so mark
                    // the devices is no longer being installed/uninistalled
                    if self.myDevices.devices.count > 0 {
                        for i in 0..<self.myDevices.devices.count {
                            let aDevice: Device = self.myDevices.devices[i]
                            aDevice.installState = self.STATE_NONE
                        }
                    }

                    // Update the table to reflect the state
                    self.deviceTable.reloadData()
                    NSLog("Sync list not sent")

                    // Warn the user
                    showAlert("Sync Failed", "Could not connect to the Apple Watch to install/uninstall the selected app")
                }
            }
        }
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


    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let header: DeviceTableHeaderViewCell = tableView.dequeueReusableCell(withIdentifier:"header.cell")! as! DeviceTableHeaderViewCell
        
        var state = "DISCONNECTED"
        if let session = self.phoneSession {
            if session.activationState == WCSessionActivationState.activated { state = "CONNECTED" }
        }
        
        header.watchName.text = "WATCH \(state)"
        return header
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // Get a new table cell from the queue of existing cells, or create one if none are available
        if indexPath.row == self.myDevices.devices.count {
            // Append the extra row required by entering the table's editing mode
            // We use a standard UITableViewCell as all we need is a text label
            let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier:"new.cell", for:indexPath)
            cell.textLabel?.text = "Add New Device"
            return cell
        } else {
            // Add a row to display device information
            // We use a custom UITableViewCell
            let cell: DeviceTableViewCell = tableView.dequeueReusableCell(withIdentifier:"device.cell",
                                                                          for:indexPath) as! DeviceTableViewCell
            
            // Fill the cell with device data
            let device: Device = self.myDevices.devices[indexPath.row]
            cell.appName?.text = device.name.count > 0 ? device.name : "Device \(self.myDevices.devices.count)"
            cell.appIcon?.image = getAppImage(device.app)
            
            // Show bullets or the agent ID according to user preference
            var codeString: String = ""
            if device.code.count > 0 {
                if !self.tableShowIDsFlag {
                    for _ in 0..<device.code.count {
                        codeString = codeString + "•"
                    }
                } else {
                    codeString = device.code
                }
            }
            
            cell.appCode?.text = device.code.count > 0 ? codeString : "Code not yet set"
            cell.rowIndex = indexPath.row
            
            // For the install switch, disable it if the device has no watch support, and
            // hide it if the celling is in editing mode (true when editing or reordering)
            cell.installSwitch.isOn = device.isInstalled
            cell.installSwitch.isEnabled = device.watchSupported && self.watchAppInstalled
            cell.installSwitch.isHidden = self.tableEditingFlag

            // Do we show the re-order control? If so, hide the switch
            cell.showsReorderControl = self.tableOrderingFlag

            return cell
        }
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        // Get the device being shown at the row
        let device: Device = self.myDevices.devices[indexPath.row]
        
        // Instantiate the device detail view controller as required - ie. every time
        if self.ddvc == nil {
            let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
            self.ddvc = storyboard.instantiateViewController(withIdentifier: "device.detail.view") as? DeviceDetailViewController
            self.ddvc.navigationItem.title = device.name.count > 0 ? "Device Info" : "Device Setup"
            
            let button = UIButton(type: .system)
            button.setImage(UIImage(named: "icon_left"), for: UIControl.State.normal)
            button.setTitle("Devices", for: UIControl.State.normal)
            button.sizeToFit()
            button.addTarget(self.ddvc, action: #selector(self.ddvc.changeDetails), for: UIControl.Event.touchUpInside)
            self.ddvc.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
        }

        // Set DeviceDetailViewController's currentDevice properties
        // Create a new device if necessary
        if editingDevice == nil { editingDevice = Device() }

        self.editingDevice.name = device.name
        self.editingDevice.code = device.code
        self.editingDevice.app = device.app
        self.editingDevice.watchSupported = device.watchSupported
        
        // Record the selected row - we'll use it when this view controller comes back
        self.currentDeviceRow = indexPath.row

        // Point the device detail view controller at the current device
        self.ddvc.currentDevice = editingDevice
        self.ddvc.apps = self.apps

        // Present the device detail view controller
        self.navigationController?.pushViewController(self.ddvc, animated: true)
    }


    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {

        // NOTE All table rows are editable, including the 'Add New Device' row
        return true
    }


    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) ->UITableViewCell.EditingStyle {

        if !self.tableOrderingFlag {
            return (indexPath.row == self.myDevices.devices.count ? UITableViewCell.EditingStyle.insert : UITableViewCell.EditingStyle.delete)
        } else {
            return UITableViewCell.EditingStyle.none
        }
    }


    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {

        return !self.tableOrderingFlag
    }


    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
            // Remove the deleted row's imp from the data source FIRST
            self.myDevices.devices.remove(at: indexPath.row)

            // Now delete the table row itself then update the table
            tableView.deleteRows(at: [indexPath], with: UITableView.RowAnimation.automatic)
            tableView.reloadData()
        } else if editingStyle == .insert {
            // Create a new imp with default name and code values
            let device:Device = Device()

            // Add new imp to the list
            self.myDevices.devices.append(device)
            device.name = "Device \(self.myDevices.devices.count)"

            // And add it to the table
            tableView.insertRows(at: [indexPath],
                                 with: UITableView.RowAnimation.none)
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

    
    // MARK: - WCSessionDelegate Functions

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {

        if activationState == WCSessionActivationState.activated {
            if session.isPaired {
                if session.isWatchAppInstalled {
                    self.watchAppInstalled = true

                    // Update table to show any changes made
                    DispatchQueue.main.async {
                        self.deviceTable.reloadData()
                    }
                    
                    // Re-send the device list to make sure watch is up to date
                    sendDeviceList()
                } else {
                    // Watch app not installed, so warn user
                    //self.phoneSession = nil
                    self.watchAppInstalled = false
                    DispatchQueue.main.async {
                        self.showAlert("This app needs a companion Watch app", "Please install the companion app on your Watch")
                    }
                }
            } else {
                // iPhone is not paired with a watch, so warn user
                //self.phoneSession = nil
                self.watchAppInstalled = false
                DispatchQueue.main.async {
                    self.showAlert("This app requires an Apple Watch", "Please pair your Apple Watch with this iPhone")
                }
            }
        }
    }


    func sessionDidBecomeInactive(_ session: WCSession) {

        // NOP - Function required by delegate but not used

        // Update table to show any changes made
        DispatchQueue.main.async {
            self.deviceTable.reloadData()
        }
    }


    func sessionDidDeactivate(_ session: WCSession) {

        // Session has ended after watch A has disconnected, so connect to watch B

        // Update table to show any changes made
        DispatchQueue.main.async {
            self.deviceTable.reloadData()
        }
        
        // Connect to alternative watch
        session.activate()
    }
    
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        
        if session.isPaired == false || session.isWatchAppInstalled == false {
            self.watchAppInstalled = false
            
            // Update table to show any changes made
            DispatchQueue.main.async {
                self.deviceTable.reloadData()
            }
        }
    }
    
    
    // MARK: - Utility Functions
    
    func showAlert(_ title: String, _ message: String) {
        
        // Generic alert display function
        let alert = UIAlertController.init(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .`default`, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }


    func getAppImage(_ code: String) -> UIImage? {
        
        // Get the correct icon image for the app
        let imageName: String = getAppType(code)
        let image: UIImage? = UIImage(named: imageName)
        if image != nil {
            return image!
        } else {
            return UIImage(named: "unknown")
        }
    }


    func getAppType(_ code:String) -> String {
        
        // Return the app's name as derived from its known UUID
        // The name is used to get the appropriate icon file
        return getAppName(code).lowercased()
    }


    func getAppName(_ code: String) -> String {
        
        // Return the app's name as derived from its known UUID
        // The name is used to get the appropriate icon file
        let apps: [[String : Any]] = self.apps["apps"] as! [[String : Any]]
        if apps.count > 0 {
            for i in 0..<apps.count {
                let app = apps[i]
                if code == app["code"] as! String {
                    return app["name"] as! String
                }
            }
        }
        
        // Otherwise just return "unknown"
        return "unknown"
    }
    
}
