
//  Device.swift
//  Created by Tony Smith on 06/12/2016.
//
//  Copyright 2016-19 Tony Smith
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


import Foundation

class Device: NSObject, NSCoding, NSSecureCoding {

    // FROM 1.2.0
    // Support iOS 12 secure method for decoding objects
    static var supportsSecureCoding: Bool {
        return true
    }

    var name: String = ""
    var code: String = ""
    var app: String = ""
    var watchSupported: Bool = false
    var changed: Bool = false
    var isInstalled: Bool = false
    var autoBack:Bool = false
    var installState: Int = -1
    
    let STATE_INSTALLING = 1
    let STATE_REMOVING = 0
    let STATE_NONE = -1

    
    // MARK: - Initialization Methods

    override init() {

        self.name = ""
        self.code = ""
        self.app = ""
        self.watchSupported = false
        self.isInstalled = false
        self.autoBack = true
        self.installState = self.STATE_NONE
    }


    // MARK: - NSCoding Methods

    required init?(coder decoder: NSCoder) {

        self.name = ""
        self.code = ""
        self.app = ""
        self.watchSupported = false
        self.isInstalled = false
        self.autoBack = true
        self.installState = self.STATE_NONE

        // FROM 1.2.0
        // Support iOS 12 secure method for decoding objects
        self.name = decoder.decodeObject(of: NSString.self, forKey: "device.name") as String? ?? ""
        self.code = decoder.decodeObject(of: NSString.self, forKey: "device.code") as String? ?? ""
        self.app = decoder.decodeObject(of: NSString.self, forKey: "device.app") as String? ?? ""

        self.watchSupported = decoder.decodeObject(of: NSNumber.self, forKey: "device.watch") as! Bool
        self.isInstalled = decoder.decodeObject(of: NSNumber.self, forKey: "device.installed") as! Bool
        self.autoBack = decoder.decodeObject(of: NSNumber.self, forKey: "device.autoback") as! Bool
    }

    
    func encode(with encoder: NSCoder) {

        // FROM 1.2.0
        // Support iOS 12 secure method for decoding objects
        encoder.encode(self.name as NSString, forKey: "device.name")
        encoder.encode(self.code as NSString, forKey: "device.code")
        encoder.encode(self.app as NSString, forKey: "device.app")
        encoder.encode(NSNumber(value: self.watchSupported), forKey: "device.watch")
        encoder.encode(NSNumber(value: self.isInstalled), forKey: "device.installed")
        encoder.encode(NSNumber(value: self.autoBack), forKey: "device.autoback")
    }
}
