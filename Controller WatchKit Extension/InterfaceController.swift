
//  InterfaceController.swift
//  Controller WatchKit Extension
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


import WatchKit
import Foundation
import ClockKit
import WatchConnectivity


class InterfaceController: WKInterfaceController, WCSessionDelegate {


    @IBOutlet weak var deviceTable: WKInterfaceTable!


    let watchSession: WCSession = WCSession.default
    let docsDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
    
    var myDevices: DeviceList! = nil
    var listChanged: Bool = false
    var apps: [String : Any] = [:]
    

    // MARK: - Lifecycle Functions

    override func awake(withContext context: Any?) {

        super.awake(withContext: context)

        self.myDevices = DeviceList()
        self.watchSession.delegate = self
        self.watchSession.activate()
        self.setTitle("Controller")
    }
    
    override func willActivate() {

        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        // Load in the device list if it's present
        var docsPath = self.docsDir[0] + "/devices"
        let fm: FileManager = FileManager.default

        // ********** DEBUG ONLY **********
        // Change the following line to clear old files
        let debug: Bool = false
        if debug && fm.fileExists(atPath: docsPath) {
            do {
                try fm.removeItem(atPath: docsPath)
                NSLog("Deleted old devices file")
            } catch {
                NSLog("Could not delete old devices file")
            }
        }

        // Load in an old file, using deprecated code
        // We will convert it in due course
        if fm.fileExists(atPath: docsPath) {
            // Devices file is present on the iDevice, so load it in
            let load = NSKeyedUnarchiver.unarchiveObject(withFile:docsPath)

            if load != nil {
                let devicesList: DeviceList = load as! DeviceList
                let devices: [Device] = devicesList.devices as Array
                self.myDevices.devices.removeAll()
                self.myDevices.devices.append(contentsOf: devices)
                self.myDevices.currentDevice = devicesList.currentDevice

                // Save the list in the new format...
                saveDevices()

                // ...and delete the old one, if we were successful
                if !self.listChanged {
                    do {
                        try fm.removeItem(atPath: docsPath)
                        NSLog("Deleted 1.x devices file")
                    } catch {
                        NSLog("Could not delete 1.x devices file")
                    }
                }
            }
        } else {
            // FROM 2.0.0
            // Load in the 2.x devices list
            docsPath = self.docsDir[0] + "/devices2"

            if fm.fileExists(atPath: docsPath) {
                // Support iOS 12 secure method for decoding objects
                // Devices file is present on the iDevice, so load it in
                var loadedDevices: DeviceList? = nil

                do {
                    let data: Data = try Data(contentsOf: URL.init(fileURLWithPath: docsPath))
                    loadedDevices = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? DeviceList
                } catch {
                    loadedDevices = nil
                    NSLog("Could not load devices file. Error: \(error.localizedDescription)")
                }

                if loadedDevices != nil {
                    let devicesList = loadedDevices!
                    let devices: [Device] = devicesList.devices as Array
                    self.myDevices.devices.removeAll()
                    self.myDevices.devices.append(contentsOf:devices)
                    self.myDevices.currentDevice = devicesList.currentDevice
                }
            }
        }
        
        // Read in the current apps list
        do {
            if let file = Bundle.main.url(forResource: "apps", withExtension: "json") {
                let data = try Data(contentsOf: file)
                // NSLog(String.init(data: data, encoding: String.Encoding.utf8)!)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let object = json as? [String: Any] {
                    self.apps = object
                } else {
                    NSLog("Error", "Apps list JSON is invalid")
                }
            } else {
                NSLog("Error", "Apps list file missing")
            }
        } catch {
            NSLog("Error", "Apps list file damaged")
        }
        
        // Present the UI
        initializeUI()
    }
    
    override func didDeactivate() {

        // This method is called when watch view controller is no longer visible
        super.didDeactivate()

        // Save the device list
        if listChanged { saveDevices() }
    }
    
    
    // MARK: - Misc Methods

    func saveDevices() {
        
        // The app is going into the background or closing, so save the list of devices
        if self.myDevices.devices.count > 0 {
            let docsPath = self.docsDir[0] + "/devices2s"

            // FROM 2.0.0
            // Support iOS 12 secure method for decoding objects
            var success: Bool = false

            do {
                // Encode the object to data
                let data: Data = try NSKeyedArchiver.archivedData(withRootObject: self.myDevices!,
                                                                  requiringSecureCoding: true)

                try data.write(to: URL.init(fileURLWithPath: docsPath))
            } catch {
                success = false
                NSLog("Couldn't write to save file: " + error.localizedDescription)
            }

            self.listChanged = !success
        }
    }


    func initializeUI() {

        // Prepare the UI
        if self.myDevices.devices.count == 0 {
            // There are no devices to be listed yet, so create a table row
            // that says just that
            self.deviceTable.setNumberOfRows(1, withRowType: "main.table.row")
            let aRow: TableRow = self.deviceTable.rowController(at: 0) as! TableRow
            aRow.nameLabel.setText("No Devices")
        } else {
            // Tell the table how many rows it will need to show
            self.deviceTable.setNumberOfRows(self.myDevices.devices.count, withRowType: "main.table.row")
            
            // Run through the device list to add each device to the UI
            for i in 0..<self.myDevices.devices.count {
                let aDevice: Device = self.myDevices.devices[i]
                let aRow: TableRow = self.deviceTable.rowController(at: i) as! TableRow
                aRow.nameLabel.setText(aDevice.name)
                aRow.appIcon.setImage(UIImage.init(named: getAppNameLower(aDevice.app)))
            }
        }
    }


    // MARK: - Table Handler Functions

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {

        if self.myDevices.devices.count == 0 {
            // The app doesn't know about any devices, so tell the user to sync data from the iPhone
            let waa: WKAlertAction = WKAlertAction.init(title: "OK", style: WKAlertActionStyle.default, handler: {
                // NOP
            })
            
            presentAlert(withTitle: "Add Some Devices",
                         message: "Please run the Controller app on your iPhone, add some devices, and select ‘Update Watch’ from the ‘Actions’ menu",
                         preferredStyle: WKAlertControllerStyle.alert,
                         actions: [waa])
        } else {
            // Work out what type of app the selected device is running and
            // pop up the appropriate interface controller
            let aDevice: Device = self.myDevices.devices[rowIndex]
            var name: String = ""

            name = getAppNameLower(aDevice.app) + ".ui"
            
            if name.count > 0 {
                self.pushController(withName: name, context: aDevice)
            }
        }
    }

    func getAppNameLower(_ code:String) -> String {
        
        return getAppName(code).lowercased()
    }
    
    func getAppName(_ code: String) -> String {
        
        let apps: [[String : Any]] = self.apps["apps"] as! [[String : Any]]
        if apps.count > 0 {
            for i in 0..<apps.count {
                let app = apps[i]
                if code == app["code"] as! String {
                    return app["name"] as! String
                }
            }
        }
        
        return "unknown"
    }


    // MARK: - WCSessionDelegate Functions

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {

        WKInterfaceDevice.current().play(.click)
        
        DispatchQueue.main.async() {
            self.processContext()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {

        // NOP
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {

        // NOP
    }
    
    func processContext() {
        
        // Get the latest received context and use the data that it contains
        // to reconstruct the device list, making sure we save the list and
        // re-display the UI
        if let context = watchSession.receivedApplicationContext as? [String : String] {
            WKInterfaceDevice.current().play(.click)
            if let dataString = context["info"] {
                let ds = dataString as NSString
                if ds.length != 0 {
                    if ds == "clear" {
                        self.myDevices.devices.removeAll()
                    } else {
                        let devices = ds.components(separatedBy: "\n\n")
                        if devices.count > 1 {
                            self.myDevices.devices.removeAll()
                            for i in 0..<devices.count - 1 {
                                let d = devices[i] as NSString
                                let device = d.components(separatedBy: "\n")
                                let aDevice: Device = Device()
                                aDevice.name = device[0]
                                aDevice.code = device[1]
                                aDevice.app = device[2]
                                
                                self.myDevices.devices.append(aDevice)
                            }
                        }
                    }
                } else {
                    self.myDevices.devices.removeAll()
                }
                
                saveDevices()
                initializeUI()
            }
        }
    }
}
