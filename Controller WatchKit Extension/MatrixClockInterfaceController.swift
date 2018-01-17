
//  MatrixClockInterfaceController.swift
//  Created by Tony Smith on 1/17/18.
//  Copyright © 2018 Black Pyramid. All rights reserved.


import WatchKit


class MatrixClockInterfaceController: WKInterfaceController {

    @IBOutlet weak var deviceLabel: WKInterfaceLabel!
    @IBOutlet weak var lightSwitch: WKInterfaceSwitch!


    // MARK: - Lifecycle Functions

    override func awake(withContext context: Any?) {

        super.awake(withContext: context)

        let aDevice: Device = context as! Device
        deviceLabel.setText(aDevice.name)
    }

    override func willActivate() {

        super.willActivate()
    }

    @IBAction func doSwitch(_ sender: Any) {

        // TODO
    }

    @IBAction func back(_ sender: Any) {

        // Go back to the device list
        popToRootController()
    }

}
