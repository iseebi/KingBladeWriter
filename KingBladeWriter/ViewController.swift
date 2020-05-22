//
//  ViewController.swift
//  KingBladeWriter
//
//  Created by Nobuhiro Ito on 5/16/20.
//  Copyright © 2020 Nobuhiro Ito. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {
    let serviceUUID = CBUUID(string: "00000000-0000-1000-8000-00805F9B34FB")
    let parrotPatterns: [[UInt8]] = [
        [0xFF, 0x8D, 0x8B, 0x00],
        [0xFE, 0xD6, 0x89, 0x00],
        [0x88, 0xFF, 0x89, 0x00],
        [0x87, 0xFF, 0xFF, 0x00],
        [0x8B, 0xB5, 0xFE, 0x00],
        [0xD7, 0x8C, 0xFF, 0x00],
        [0xFF, 0x8C, 0xFF, 0x00],
        [0xFF, 0x68, 0xF7, 0x00],
        [0xFE, 0x6C, 0xB7, 0x00],
        [0xFF, 0x69, 0x68, 0x00],
    ]

    @IBOutlet var connectButton: UIButton!
    @IBOutlet var redSlider: UISlider!
    @IBOutlet var greenSlider: UISlider!
    @IBOutlet var blueSlider: UISlider!
    @IBOutlet var whiteSlider: UISlider!
    
    private var centralDispatchQueue: DispatchQueue?
    private var centralManager: CBCentralManager?
    private var targetDevice: CBPeripheral?
    private var kingBladeControlCharacteristic: CBCharacteristic?
    private var parrotIndex = 0
    private var parrotTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        let centralDispatchQueue = DispatchQueue(label: "net.iseteki.KingBladeWriter.centralWatch")
        let centralManager = CBCentralManager(delegate: self, queue: centralDispatchQueue)
        self.centralDispatchQueue = centralDispatchQueue
        self.centralManager = centralManager
        
        [redSlider, greenSlider, blueSlider, whiteSlider].forEach { (sliderOrNil) in
            guard let slider = sliderOrNil else { return }
            slider.minimumValue = 0
            slider.maximumValue = 255
            slider.value = 128
        }
    }
    
    func writeColor(red: UInt8, green: UInt8, blue: UInt8, white: UInt8) {
        guard let peripheral = self.targetDevice,
            let kingBladeControl = self.kingBladeControlCharacteristic
            else { return }
        var command: [UInt8] = [0x00, red, green, blue, white, 0x00, 0x00, 0x00, 0x00, 0x00]
        let commandData = NSData(bytes: &command, length: command.count)
        peripheral.writeValue(commandData as Data, for: kingBladeControl, type: .withResponse)
    }
    
    @IBAction func connectButtonTapped(_ sender: Any) {
        guard let centralManager = self.centralManager else { return }
        
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    
    @IBAction func sliderValueChanged(_ sender: Any) {
        print("sliderValueChanged")
        let red = UInt8(redSlider.value)
        let green = UInt8(greenSlider.value)
        let blue = UInt8(blueSlider.value)
        let white = UInt8(whiteSlider.value)
        writeColor(red: red, green: green, blue: blue, white: white)
    }
    
    @IBAction func partyButtonTapped(_ sender: Any) {
        guard parrotTimer == nil else { return }
        parrotTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true, block: { [weak self] (timer) in
            guard let `self` = self else { return }
            let pattern = self.parrotPatterns[self.parrotIndex]
            self.writeColor(red: pattern[0], green: pattern[1], blue: pattern[2], white: pattern[3])

            self.parrotIndex = self.parrotIndex + 1
            if self.parrotIndex >= self.parrotPatterns.count {
                self.parrotIndex = 0
            }
        })
    }
}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("centralManagerDidUpdateState")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("didDiscover")
        guard peripheral.name == "KBX5" else { return }
        
        self.targetDevice = peripheral
        central.connect(peripheral, options: nil)
    }
    

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("didConnect")
        guard self.targetDevice == peripheral else { return }
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services,
            let service = services.first(where: { $0.uuid == serviceUUID })
            else { return }
        peripheral.discoverCharacteristics([serviceUUID], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics,
            let characteristic = characteristics.first(where: { $0.uuid == serviceUUID })
            else { return }
        kingBladeControlCharacteristic = characteristic
    }
}
