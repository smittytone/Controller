//  DeviceTableViewController.swift
//  Created by Tony Smith on 1/16/18.
//  Copyright © 2018 Black Pyramid. All rights reserved.


import UIKit
import WatchKit
import WatchConnectivity


class DeviceTableViewController: UITableViewController {

    @IBOutlet weak var deviceTable:UITableView!

    var myDevices: DeviceList!
    var editingDevice: Device!
    var actionButton: UIBarButtonItem!
    var ddvc: DeviceDetailViewController!

    var deviceRow: Int = -1
    var currentDevice: Int = -1
    var tableEditingFlag: Bool = false
    var tableOrderingFlag: Bool = false
    var showIDFlag: Bool = true

    
    override func viewDidLoad() {

        super.viewDidLoad()

        // Set up the table's selection persistence
        self.clearsSelectionOnViewWillAppear = false

        // Set up the Edit button
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        self.navigationItem.rightBarButtonItem!.tintColor = UIColor.white
        self.navigationItem.rightBarButtonItem!.action = #selector(self.editTouched)

        // Set up the Actions button
        actionButton = UIBarButtonItem.init(title:"Actions",
                                           style:UIBarButtonItemStyle.plain,
                                           target:self,
                                           action:#selector(self.actionsTouched))
        self.navigationItem.leftBarButtonItem = actionButton
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.white

        // Initialise object properties
        self.tableOrderingFlag = false
        self.tableEditingFlag = false
        self.editingDevice = nil

        // Watch for app returning to foreground with DeviceDetailViewController active
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(self.viewWillAppear),
                                               name:NSNotification.Name.UIApplicationWillEnterForeground,
                                               object:nil)
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
            self.editingDevice = nil
        }

        // Check for show/hide Clock IDs preference
        let settings = UserDefaults.standard
        settings.synchronize()

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

        self.deviceTable.reloadData()
    }

    @objc func actionsTouched() {

        // Show the Actions menu
        let actionMenu = UIAlertController.init(title: "Select an Action from the List Below", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        var action: UIAlertAction!

        // Add the 'start scan' or 'cancel scan' action button
        action = UIAlertAction.init(title: "Update Watch", style: UIAlertActionStyle.default) { (alertAction) in
            self.updateWatch()
        }

        actionMenu.addAction(action)

        // Construct and add the other buttons
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

    func updateWatch() {

    }

    @objc func showInfo() {

        let alert = UIAlertController.init(title: "Controller\nInformation", message: "This sample app can be used to activate Bluetooth-enabled Electric Imp devices, such as the imp004m. Tap ‘Scan’ to find local devices (these must be running the accompanying Squirrel device code) and then select a device to set its WiFi credentials. The selected device will automatically provide a list of compatible networks — just select one from the list and enter its password (or leave the field blank if it has no password). Tap ‘Send BlinkUp’ to configure the device. The app will inform you when the device has successfully connected to the Electric Imp impCloud™", preferredStyle: UIAlertControllerStyle.alert)
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
            let device = self.myDevices.devices[indexPath.row]
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
            let storyboard = UIStoryboard.init(name:"Main", bundle:nil)
            self.ddvc = storyboard.instantiateViewController(withIdentifier:"device.detail.view") as! DeviceDetailViewController
            self.ddvc.navigationItem.title = "Device Info"
            self.ddvc.navigationItem.leftBarButtonItem = UIBarButtonItem.init(title:"Devices",
                                                                         style:UIBarButtonItemStyle.plain,
                                                                         target:self.ddvc,
                                                                         action:#selector(self.ddvc.changeDetails))
            self.ddvc.navigationItem.leftBarButtonItem?.tintColor = UIColor.white
        }

        // Set DeviceDetailViewController's currentDevice properties

        // Create a new device if necessary
        if editingDevice == nil { editingDevice = Device() }

        let device = self.myDevices.devices[indexPath.row]
        self.editingDevice.name = device.name
        self.editingDevice.code = device.code
        self.editingDevice.app = device.app
        self.deviceRow = indexPath.row

        // Set the LED colour graphic
        self.ddvc.currentDevice = editingDevice

        // Present the device detail view controller
        self.navigationController?.pushViewController(self.ddvc, animated: true)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {

        // All table rows are editable, including the 'Add New Device' row
        return true
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) ->UITableViewCellEditingStyle {

        if !tableOrderingFlag {
            return (indexPath.row == self.myDevices.devices.count ? UITableViewCellEditingStyle.insert : UITableViewCellEditingStyle.delete)
        } else {
            return UITableViewCellEditingStyle.none
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
            // Remove the deleted row's imp from the data source FIRST
            self.myDevices.devices.remove(at:indexPath.row)

            // Now delete the table row itself then update the table
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.reloadData()
        } else if editingStyle == .insert {
            // Create a new imp with default name and code values
            let device = Device()

            // Add new imp to the list
            self.myDevices.devices.append(device)

            // And add it to the table
            tableView.insertRows(at:[indexPath], with:UITableViewRowAnimation.none)
            self.deviceTable.reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {

        if indexPath.row == myDevices.devices.count { return false }
        return self.tableOrderingFlag
    }


    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

        let start = fromIndexPath.row
        let end = to.row
        let aDevice = self.myDevices.devices[start]
        self.myDevices.devices.remove(at:start)
        self.myDevices.devices.insert(aDevice, at:end)
        tableView.reloadData()
    }

    func getAppImage(_ type:Int) -> UIImage? {

        switch type {
        case 0:
            return UIImage(named: "weather")
        case 1:
            return UIImage(named: "homeweather")
        default:
            return UIImage(named: "matrixclock")
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
