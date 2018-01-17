
//  InterfaceController.swift
//  Controller WatchKit Extension
//  Created by Tony Smith on 1/16/18.
//  Copyright © 2018 Black Pyramid. All rights reserved.

import WatchKit
import Foundation
import ClockKit
import WatchConnectivity


class InterfaceController: WKInterfaceController, WCSessionDelegate {

    @IBOutlet weak var deviceTable: WKInterfaceTable!

    var myDevices: DeviceList! = nil
    let docsDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
    

    // MARK: - Lifecycle Functions

    override func awake(withContext context: Any?) {

        super.awake(withContext: context)

        myDevices = DeviceList()
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
        } else {
            let session = WCSession.default
            session.delegate = self

            if session.receivedApplicationContext["devices"] != nil {
                let devices = session.receivedApplicationContext["devices"] as! [[String:String]]
                for i in 0..<devices.count {
                    let anEntry = devices[i]
                    let device = Device()
                    device.name = anEntry["name"]!
                    device.code = anEntry["code"]!
                    device.app = anEntry["app"]!
                }
                saveDevices()
                initializeUI()
            }
        }

        initializeUI()
    }
    
    override func didDeactivate() {

        // This method is called when watch view controller is no longer visible
        super.didDeactivate()

        // Save the device list
        saveDevices()
    }

    func saveDevices() {

        if self.myDevices.devices.count > 0 {
            // The app is going into the background or closing, so save the list of devices
            let docsPath = self.docsDir[0] + "/devices"
            let _ = NSKeyedArchiver.archiveRootObject(self.myDevices, toFile:docsPath)
        }
    }

    func initializeUI() {

        if self.myDevices.devices.count == 0 {
            self.deviceTable.setNumberOfRows(1, withRowType: "main.table.row")
            let aRow: TableRow = self.deviceTable.rowController(at: 0) as! TableRow
            aRow.nameLabel.setText("No Devices")
        } else {
            self.deviceTable.setNumberOfRows(self.myDevices.devices.count, withRowType: "main.table.row")

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
            // NOP
        } else {
            let aDevice: Device = self.myDevices.devices[rowIndex]

            if aDevice.app == "761DDC8C-E7F5-40D4-87AC-9B06D91A672D" {
                self.pushController(withName: "weather.ui", context: aDevice)
            }

            if aDevice.app == "0028C36B-444A-408D-B862-F8E4C17CB6D6" {
                self.pushController(withName: "matrixclock.ui", context: aDevice)
            }
        }
    }

    func getAppTypeAsString(_ code:String) -> String {

        if code == "761DDC8C-E7F5-40D4-87AC-9B06D91A672D" { return "Weather" }
        if code == "8B6B3A11-00B4-4304-BE27-ABD11DB1B774" { return "HomeWeather" }
        if code == "0028C36B-444A-408D-B862-F8E4C17CB6D6" { return "MatrixClock" }

        return "Unknown"
    }


    // MARK: - WCSessionDelegate Functions

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {

        WKInterfaceDevice.current().play(.click)
        if applicationContext["devices"] != nil {
            let devices = applicationContext["devices"] as! [[String:String]]
            for i in 0..<devices.count {
                let anEntry = devices[i]
                let device = Device()
                device.name = anEntry["name"]!
                device.code = anEntry["code"]!
                device.app = anEntry["app"]!
            }
            saveDevices()
            initializeUI()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {

        NSLog("Received Message")
        if message["devices"] != nil {
            self.myDevices.devices = message["devices"] as! [Device]
            saveDevices()
            initializeUI()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {

        // NOP
    }


}
