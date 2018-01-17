
//  Created by Tony Smith on 06/12/2016.
//  Copyright © 2016-17 Tony Smith. All rights reserved.


import Foundation

class Device: NSObject, NSCoding {

    var name: String = ""
    var code: String = ""
    var app: String = ""
    var watchSupported: Bool = false
    var changed: Bool = false

    // MARK: - Initialization Methods

    override init() {

        self.name = ""
        self.code = ""
        self.app = ""
        self.watchSupported = false
    }


    // MARK: - NSCoding Methods

    required init?(coder decoder: NSCoder) {

        self.name = ""
        self.code = ""
        self.app = ""
        self.watchSupported = false

        if let n = decoder.decodeObject(forKey: "device.name") { self.name = n as! String }
        if let c = decoder.decodeObject(forKey: "device.code") { self.code = c as! String }
        if let a = decoder.decodeObject(forKey: "device.app") { self.app = a as! String }

        self.watchSupported = decoder.decodeBool(forKey: "device.watch")
    }


    func encode(with encoder: NSCoder) {

        encoder.encode(self.name, forKey: "device.name")
        encoder.encode(self.code, forKey: "device.code")
        encoder.encode(self.app, forKey: "device.app")
        encoder.encode(self.watchSupported, forKey: "device.watch")
    }
}
