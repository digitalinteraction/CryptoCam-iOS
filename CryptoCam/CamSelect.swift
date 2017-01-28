//
//  CamSelectController.swift
//  CryptoCam
//
//  Created by Gerard Wilkinson on 30/10/2016.
//  Copyright © 2016 Open Lab. All rights reserved.
//

import UIKit
import CoreData

class CamSelectController: UITableViewController {
    private var cams = [Cam]()
    
    private var tappedCam:Cam?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refreshTable), for: .valueChanged)
        
        loadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadData() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        do {
            cams = try appDelegate.persistentContainer.viewContext.fetch(NSFetchRequest<Cam>(entityName: "Cam"))
        } catch {
            print("Unable to load cams")
        }
    }
    
    func refreshTable() {
        loadData()
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cams.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let cam = cams[indexPath.row]
        
        cell.textLabel!.text = cam.name
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cam = cams[indexPath.row]
        tappedCam = cam
        performSegue(withIdentifier: "camSegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier! == "camSegue" {
            let destination = segue.destination as! VideoSelectController
            destination.cam = tappedCam
        }
    }
}
