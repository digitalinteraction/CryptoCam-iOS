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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    private static let KeyServiceUuid = CBUUID(string: "cc92cc92-ca19-0000-0000-000000000001")
    private static let KeyCharacUuid = CBUUID(string: "cc92cc92-ca19-0000-0000-000000000002")
    
    private var centralManager:CBCentralManager?
    private var peripheralManger:CBPeripheralManager?
    private var currentCCs = [(Cam, CBPeripheral, Date)]()
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManger = CBPeripheralManager(delegate: self, queue: nil)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
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
            central.scanForPeripherals(withServices: nil, options: nil)
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
        if peripheral.name != "OL-CryptoCam" { return }
        
        let request = NSFetchRequest<Cam>(entityName: "Cam")
        request.predicate = NSPredicate(format: "id == %@", peripheral.identifier.uuidString)
        
        do {
            let cameras = try persistentContainer.viewContext.fetch(request)
            var cam:Cam!
        
            if cameras.count > 0 {
                cam = cameras.first!
            } else {
                cam = Cam(entity: NSEntityDescription.entity(forEntityName: "Cam", in: persistentContainer.viewContext)!, insertInto: persistentContainer.viewContext)
                cam.name = peripheral.name!
                cam.id = peripheral.identifier.uuidString
            }
        
            currentCCs.append((cam!, peripheral, Date()))
            peripheral.discoverServices([AppDelegate.KeyServiceUuid])
        } catch {
            print("Unable to create cam.")
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if let services = peripheral.services {
            let service = services.filter{ $0.uuid == AppDelegate.KeyServiceUuid }.first
            
            if let keyService = service {
                peripheral.discoverCharacteristics([AppDelegate.KeyCharacUuid], for: keyService)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if let keyCharac = service.characteristics?.filter({$0.uuid == AppDelegate.KeyCharacUuid}).first {
            peripheral.readValue(for: keyCharac)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        do {
            var cam = currentCCs.filter{ $0.0.id == peripheral.identifier.uuidString }.first!
            
            let json = try JSONSerialization.jsonObject(with: characteristic.value!, options: .allowFragments) as! [String: AnyObject]
            let video = Video(entity: NSEntityDescription.entity(forEntityName: "Video", in: persistentContainer.viewContext)!, insertInto: persistentContainer.viewContext)
            video.timestamp = NSDate()
            video.encryption = json["encryption"]!.stringValue
            video.url = json["url"]!.stringValue
            video.key = json["key"]!.stringValue
            video.cam = cam.0
            
            cam.2 = Date().addingTimeInterval(TimeInterval(json["reconnectIn"]!.int16Value))
        } catch {
            print("Unable to read value.")
        }
    }
}

