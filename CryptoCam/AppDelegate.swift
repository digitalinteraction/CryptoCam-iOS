//
//  AppDelegate.swift
//  CryptoCam
//
//  Created by Gerard Wilkinson on 30/10/2016.
//  Copyright © 2016 Open Lab. All rights reserved.
//

import UIKit
import CoreLocation
import CoreBluetooth
import CoreData
import SVProgressHUD

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate {
    private static let KeyServiceUuid = CBUUID(string: "cc92cc92-ca19-0000-0000-000000000001")
    private static let KeyCharacUuid = CBUUID(string: "cc92cc92-ca19-0000-0000-000000000002")
    
    private var centralManager:CBCentralManager?
    private var peripheralManger:CBPeripheralManager?
    private var currentCCs = [(Cam, CBPeripheral, Date)]()
    
    private var keyTimer:Timer?
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        SVProgressHUD.setDefaultMaskType(.black)
        
        // Start Looking for Cameras
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManger = CBPeripheralManager(delegate: self, queue: nil)
        
        application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        
        // Start Collecting Keys
        startCollectingKeys()
        return true
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        checkAndUpdateCameras()
        completionHandler(UIBackgroundFetchResult.newData)
        print("PERFORMED BACKGROUND UPDATE")
    }
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {}
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("CoreBluetooth BLE hardware is powered off")
            break
        case .poweredOn:
            print("CoreBluetooth BLE hardware is powered on and ready")
            central.scanForPeripherals(withServices: [AppDelegate.KeyCharacUuid], options: nil)
            break
        case .resetting:
            print("CoreBluetooth BLE hardware is resetting")
            break
        case .unauthorized:
            print("CoreBluetooth BLE state is unauthorized")
            break
        case .unknown:
            print("CoreBluetooth BLE state is unknown")
            break
        case .unsupported:
            print("CoreBluetooth BLE hardware is unsupported on this platform")
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name else {
            return
        }
        
        if name.characters.count != 7 { return }
        
        let index = name.index(name.startIndex, offsetBy: 3)
        if name.substring(to: index) != "CC-" { return }
        
        let request = NSFetchRequest<Cam>(entityName: "Cam")
        request.predicate = NSPredicate(format: "id == %@", peripheral.identifier.uuidString)
        
        do {
            let cameras = try persistentContainer.viewContext.fetch(request)
            var cam:Cam!
        
            if cameras.count > 0 {
                cam = cameras.first!
            } else {
                cam = Cam(entity: NSEntityDescription.entity(forEntityName: "Cam", in: persistentContainer.viewContext)!, insertInto: persistentContainer.viewContext)
                cam.name = name
                cam.id = peripheral.identifier.uuidString
            }
        
            currentCCs.append((cam!, peripheral, Date().addingTimeInterval(600)))
            central.connect(peripheral, options: nil)
        } catch let camError {
            print("Unable to create cam: \(camError)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([AppDelegate.KeyServiceUuid])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        currentCCs = currentCCs.filter { $0.1.identifier != peripheral.identifier }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            let service = services.filter{ $0.uuid == AppDelegate.KeyServiceUuid }.first
            
            if let keyService = service {
                peripheral.discoverCharacteristics([AppDelegate.KeyCharacUuid], for: keyService)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let keyCharac = service.characteristics?.filter({$0.uuid == AppDelegate.KeyCharacUuid}).first {
            peripheral.readValue(for: keyCharac)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        do {
            var cam = currentCCs.filter{ $0.0.id == peripheral.identifier.uuidString }.first!
            let data = characteristic.value!
            
            let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: AnyObject]
            let video = Video(entity: NSEntityDescription.entity(forEntityName: "Video", in: persistentContainer.viewContext)!, insertInto: persistentContainer.viewContext)
            video.timestamp = NSDate()
            
            video.url = json["url"]! as? String
            video.key = json["key"]! as? String
            video.iv = json["iv"]! as? String
            video.cam = cam.0
            
            cam.2 = Date().addingTimeInterval(TimeInterval(json["reconnectIn"]!.int16Value / 1000))
            
            let index = currentCCs.index { $0.0.id == peripheral.identifier.uuidString }!
            currentCCs[index] = cam
            
            saveContext()
            
            print("Read Key from (\(peripheral.name!)), reconnect at (\(cam.2))")
        } catch let jsonError {
            print("Unable to read value: \(jsonError)")
        }
        
        centralManager?.cancelPeripheralConnection(peripheral)
    }
    
    func startCollectingKeys() {
        keyTimer = Timer(timeInterval: 1, repeats: true) { (timer) in
            print("Collecting keys from (\(self.currentCCs.count)) cameras.")
            self.checkAndUpdateCameras()
        }
        
        RunLoop.current.add(keyTimer!, forMode: RunLoopMode.commonModes)
    }
    
    func stopCollectingKeys() {
        keyTimer?.invalidate()
    }
    
    func checkAndUpdateCameras() {
        for c in self.currentCCs {
            if c.2 < Date() {
                let index = self.currentCCs.index(where: { $0.0 == c.0 })!
                var cam = c
                cam.2 = Date().addingTimeInterval(600)
                self.currentCCs[index] = cam
                let peripherals = self.centralManager?.retrievePeripherals(withIdentifiers: [c.1.identifier])
                if let peripherals = peripherals, peripherals.count > 0 {
                    self.centralManager?.connect(peripherals.first!, options: nil)
                }
            }
        }
    }
}

