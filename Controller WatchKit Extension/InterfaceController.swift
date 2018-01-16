
//  InterfaceController.swift
//  Controller WatchKit Extension
//  Created by Tony Smith on 1/16/18.
//  Copyright © 2018 Black Pyramid. All rights reserved.

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {

    var myDevices: DeviceList!
    let docsDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)

    override func awake(withContext context: Any?) {

        super.awake(withContext: context)

        // Load in the device list if it's present
        let docsPath = self.docsDir[0] + "/devices"
        if FileManager.default.fileExists(atPath: docsPath) {
            // Devices file is present on the iDevice, so load it in
            let load = NSKeyedUnarchiver.unarchiveObject(withFile:docsPath)

            if load != nil {
                let devices1 = load as! DeviceList
                let devices2 = devices1.devices as Array
                self.myDevices.devices.removeAll()
                self.myDevices.devices.append(contentsOf:devices2)
                self.myDevices.currentDevice = devices1.currentDevice
            }
        }
    }
    
    override func willActivate() {

        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {

        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    override func willDisappear() {

        super.willDisappear()
        saveDevices()
    }

    func saveDevices() {

        if self.myDevices.devices.count > 0 {
            // The app is going into the background or closing, so save the list of devices
            let docsPath = self.docsDir[0] + "/devices"
            let _ = NSKeyedArchiver.archiveRootObject(self.myDevices, toFile:docsPath)
        }
    }

}
