//
//  ViewModel.swift
//  Spike Essential Connector
//
//  Created by Rohit Funde on 2023/09/08.
//

import Combine
import CoreBluetooth
import AsyncBluetooth
import BoostBLEKit

private let serviceUuid = CBUUID(string: GATT.serviceUuid)
private let characteristicUuid = CBUUID(string: GATT.characteristicUuid)

@MainActor
class ViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var peripheral: Peripheral?
    @Published var characteristic: Characteristic?


    private let centralManager = CentralManager()
    private var deviceUtils: DeviceUtils?
    
    func connect() {
        Task {
            do {
                self.isScanning = true
                try await centralManager.waitUntilReady()
                let scanDataStream = try await centralManager.scanForPeripherals(withServices: [serviceUuid], options: nil)
                for await scanData in scanDataStream {
                    print("Found", scanData.peripheral.name ?? "Unknown")
                    
                    do {
                        self.peripheral = scanData.peripheral
                        try await centralManager.connect(scanData.peripheral, options: nil)
                        print("Connected")
                        
                        self.characteristic = try await scanData.peripheral.discoverCharacteristic()
                        print("Ready!")
                        
                        deviceUtils = DeviceUtils(characteristic: characteristic, peripheral: peripheral)
                        break
                    } catch {
                        print(error)
                        self.peripheral = nil
                        try await centralManager.cancelPeripheralConnection(scanData.peripheral)
                    }
                }
            } catch {
                print(error)
            }
            
            await centralManager.stopScan()
            self.isScanning = false
        }
    }
    
    func cancel() {
        Task {
            if let peripheral = self.peripheral {
                self.peripheral = nil
                try await centralManager.cancelPeripheralConnection(peripheral)
            }
            await centralManager.stopScan()
            self.isScanning = false
        }
    }
    
    func disconnect() {
        Task {
            do {
                if let peripheral = peripheral {
                    self.peripheral = nil
                    try await centralManager.cancelPeripheralConnection(peripheral)
                }
            } catch {
                print(error)
            }
        }
    }
    
    func start() {
        deviceUtils?.setPower(20)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            self.deviceUtils?.stop()
        }
    }
}

enum PeripheralError: Error {
    case serviceNotFound
    case characteristicNotFound
}

private extension Peripheral {
    
    func discoverCharacteristic() async throws -> Characteristic {
        try await discoverServices([serviceUuid])
        guard let service = discoveredServices?.first else {
            throw PeripheralError.serviceNotFound
        }
        print("Discovered a service")
        
        try await discoverCharacteristics([characteristicUuid], for: service)
        guard let characteristic = service.discoveredCharacteristics?.first else {
            throw PeripheralError.characteristicNotFound
        }
        print("Discovered a characteristic")
        
        return characteristic
    }
}
