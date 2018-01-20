
//  InterfaceController.swift
//  Controller WatchKit Extension
//  Created by Tony Smith on 1/16/18.
//
//  Copyright 2018 Tony Smith
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
    

    // MARK: - Lifecycle Functions

    override func awake(withContext context: Any?) {

        super.awake(withContext: context)

        self.myDevices = DeviceList()
        self.watchSession.delegate = self
        self.watchSession.activate()
    }
    
    override func willActivate() {

        super.willActivate()

        // Load in the device list if it's present
        let docsPath = self.docsDir[0] + "/devices"
        if FileManager.default.fileExists(atPath: docsPath) {
            // Devices file is present on the iDevice, so load it in
            let load = NSKeyedUnarchiver.unarchiveObject(withFile:docsPath)

            if load != nil {
                let devicesList: DeviceList = load as! DeviceList
                let devices: [Device] = devicesList.devices as Array
                self.myDevices.devices.removeAll()
                self.myDevices.devices.append(contentsOf: devices)
                self.myDevices.currentDevice = devicesList.currentDevice
            }
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
            let docsPath = self.docsDir[0] + "/devices"
            let success = NSKeyedArchiver.archiveRootObject(self.myDevices, toFile:docsPath)
            listChanged = !success
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
            
            presentAlert(withTitle: "I neet setup info",
                         message: "Please run the Controller app on your iPhone, add some devices, and click ‘Activate’",
                         preferredStyle: WKAlertControllerStyle.alert,
                         actions: [waa])
        } else {
            // Work out what type of app the selected device is running and
            // pop up the appropriate interface controller
            let aDevice: Device = self.myDevices.devices[rowIndex]
            var name: String = ""

            if aDevice.app == "761DDC8C-E7F5-40D4-87AC-9B06D91A672D" { name = "weather.ui" }
            if aDevice.app == "0028C36B-444A-408D-B862-F8E4C17CB6D6" { name = "matrixclock.ui" }
            if aDevice.app == "8B6B3A11-00B4-4304-BE27-ABD11DB1B774" { name = "homeweather.ui" }
            if aDevice.app == "0B5D0687-6095-4F1D-897C-04664B143702" { name = "thermal.ui" }
            
            if name.count > 0 {
                self.pushController(withName: name, context: aDevice)
            }
        }
    }

    func getAppTypeAsString(_ code:String) -> String {

        // Use the app code to return the correct app name
        if code == "761DDC8C-E7F5-40D4-87AC-9B06D91A672D" { return "Weather" }
        if code == "8B6B3A11-00B4-4304-BE27-ABD11DB1B774" { return "HomeWeather" }
        if code == "0028C36B-444A-408D-B862-F8E4C17CB6D6" { return "MatrixClock" }
        if code == "0B5D0687-6095-4F1D-897C-04664B143702" { return "ThermalForecast" }

        return "Unknown"
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
            if let dataString = context["info"] {
                let ds = dataString as NSString
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
                
                saveDevices()
                initializeUI()
            }
        }
    }
}
