
//  AppDelegate.swift
//  Created by Tony Smith on 1/16/18.
//  Copyright © 2018 Black Pyramid. All rights reserved.


import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var myDevices:DeviceList!
    let docsDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
    var launchedShortcutItem: UIApplicationShortcutItem?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

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
        
        var installCount: Int = 0
        for i in 0..<self.myDevices.devices.count {
            let device: Device = self.myDevices.devices[i]
            if device.isInstalled {
                installCount = installCount + 1
            }
        }
        
        // Set Settings Page details
        let defaults: UserDefaults = UserDefaults.standard
        defaults.set(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String, forKey: "com.bps.controller.app.version")
        defaults.set(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String, forKey: "com.bps.controller.app.build")
        defaults.set("\(installCount)", forKey: "com.bps.controller.devices.installcount")
        defaults.set("\(self.myDevices.devices.count)", forKey: "com.bps.controller.devices.listcount")

        // If a shortcut was launched, display its information and take the appropriate action.
        var shouldPerformAdditionalDelegateHandling = true

        if let shortcut = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {

            self.launchedShortcutItem = shortcut

            // This will block "performActionForShortcutItem:completionHandler" from being called.
            shouldPerformAdditionalDelegateHandling = false
        }

        return shouldPerformAdditionalDelegateHandling
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

        // Check for a previous 3D touch
        guard let shortcut = self.launchedShortcutItem else { return }

        // Handle the saved shortcut...
        _ = handleShortcut(shortcut)

        // ...then clear it
        self.launchedShortcutItem = nil
    }


    func applicationWillTerminate(_ application: UIApplication) {

        saveDevices()
        NotificationCenter.default.post(name:NSNotification.Name("com.bps.controller.will.quit"), object:self)
    }


    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {

        // Called when the user 3D taps the app icon on the home screen while the app is backgrounded
        let handledShortcut = handleShortcut(shortcutItem)
        completionHandler(handledShortcut)
    }


    // MARK: 3D Touch Handler Function

    func handleShortcut(_ shortcutItem: UIApplicationShortcutItem) -> Bool {

        var handled = false

        // Verify that the provided `shortcutItem`'s `type` is one handled by the application.
        guard let shortCutType = shortcutItem.type as String? else { return false }
        guard let last = shortCutType.components(separatedBy: ".").last else { return false }

        switch last {
            case "visitsite":
                // Handle Visit Site Quick Action: send a notification to the requisite view controller
                handled = true

                // Open the EI shop in Safari
                let uiapp = UIApplication.shared
                let url: URL = URL.init(string: "https://github.com/smittytone/Controller")!
                uiapp.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
                break
            default:
                break
        }

        return handled
    }


    // MARK: Save Device List Handler Function

    func saveDevices() {

        let defaults: UserDefaults = UserDefaults.standard
        
        if self.myDevices.devices.count > 0 {
            var installCount: Int = 0
            for i in 0..<self.myDevices.devices.count {
                let device: Device = self.myDevices.devices[i]
                if device.isInstalled {
                    installCount = installCount + 1
                }
            }
            
            defaults.set("\(installCount)", forKey: "com.bps.controller.devices.installcount")
            defaults.set("\(self.myDevices.devices.count)", forKey: "com.bps.controller.devices.listcount")
            defaults.set(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String, forKey: "com.bps.controller.app.version")
            defaults.set(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String, forKey: "com.bps.controller.app.build")

            // The app is going into the background or closing, so save the list of devices
            let docsPath = self.docsDir[0] + "/devices"
            
            // Run through the list of devices to look for empty device records,
            // which we don't want to save
            var i: Int = 0
            repeat {
                let device: Device = self.myDevices.devices[i]
                
                if device.name == "" && device.app == "" && device.code == "" {
                    // This is an empty device record so remove it
                    self.myDevices.devices.remove(at: i)
                }
                
                i = i + 1
            } while (self.myDevices.devices.count > i)
            
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

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
