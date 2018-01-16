
//  Created by Tony Smith on 06/12/2016.
//  Copyright © 2016-17 Tony Smith. All rights reserved.


import Foundation

class DeviceList: NSObject, NSCoding {

    static let sharedDevices: DeviceList = DeviceList()

    var devices: [Device] = []
    var currentDevice: Int = -1

    
    // MARK: - Initialization Methods

    override init() {

        self.currentDevice = -1
        self.devices = []
    }

    
    // MARK: - NSCoding Methods

    func encode(with encoder:NSCoder) {

        encoder.encode(self.currentDevice, forKey: "controller.current.index")
        encoder.encode(self.devices, forKey: "controller.device.list")
    }

    required init?(coder decoder: NSCoder) {

        self.devices = decoder.decodeObject(forKey: "controller.device.list") as! Array
        self.currentDevice = decoder.decodeInteger(forKey: "controller.current.index")
    }
    
}
