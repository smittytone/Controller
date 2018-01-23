# Controller #

Control Electric Imp Platform-based Internet of Things devices from your Apple Watch.

## Usage ##

The iPhone app provides a means to add devices — enter the device’s agent ID and a name — and sync the list of devices to the Watch app, which will provide an appropriate UI for each type of device. As such it is currently limited to the device types that I use, but the design is modular, so others can create UIs and WKInterfaceController objects of their own to personalise the app for their use.

**This code is currently under development and is not yet ready for use**

## Design ##

### Watch App ###

The Watch app presents a list of available devices. Selecting any of these presents a standard UI customised for the application the device is running. The device-specific UI presents the name of the device; its application type; a series of controls relevant to the device; and finally a button which takes the user back to the device list.

The *WKInterfaceController* instance which manages the device-specific UI is designed to hide the device controls until it has received status information from the the device’s agent — see below. Once this information is received, the UI is unhidden and ready for use. The *WKInterfaceController* instance presents a 'Loading...' label to inform the user.

### Squirrel ###

The Electric Imp application component of the design makes use of the Rocky library to serve standard application information at /info, and a device status (online or offline) information at /status. These and other application control endpoints can of course be modified as required — just update the appropriate section of the relevant *WKInterfaceController* instance.

Copyright 2018, Tony Smith.

Controller is made available under the MIT licence.
