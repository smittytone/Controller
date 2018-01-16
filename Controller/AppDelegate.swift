
//  AppDelegate.swift
//  Created by Tony Smith on 1/16/18.
//  Copyright © 2018 Black Pyramid. All rights reserved.


import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var myDevices:DeviceList!
    let docsDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // Set universal window tint for views that delegate this property to this object
        self.window!.tintColor = UIColor.init(red: 0.71, green: 0.00, blue: 0.02, alpha: 1.0)

        // Point 'myDevices' at the device list singleton
        self.myDevices = DeviceList.sharedDevices

        // Load in default device list if the file has already been saved
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
                NSLog("Device list loaded (%@)", docsPath);
            }
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {

        saveDevices()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {

        saveDevices()
        NotificationCenter.default.post(name:NSNotification.Name("com.bps.controller.will.quit"), object:self)
    }

    func saveDevices() {

        if self.myDevices.devices.count > 0 {
            // The app is going into the background or closing, so save the list of devices
            let docsPath = self.docsDir[0] + "/devices"
            let success = NSKeyedArchiver.archiveRootObject(self.myDevices, toFile:docsPath)
            if success {
                NSLog("Device list saved (%@)", docsPath)
            } else {
                NSLog("Device list save failed")
            }
        } else {
            NSLog("No devices to save")
        }
    }
}

