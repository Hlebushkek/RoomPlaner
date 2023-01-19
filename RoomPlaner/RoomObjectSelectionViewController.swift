//
//  RoomObjectSelectionViewController.swift
//  RoomPlaner
//
//  Created by Hlib Sobolevskyi on 19.01.2023.
//

import UIKit
import ARKit

protocol RoomObjectSelectionViewControllerDelegate: AnyObject {
    func roomObjectSelectionViewController(_ selectionViewController: RoomObjectSelectionViewController, didSelectObject: RoomVirtualObject)
}

class RoomObjectSelectionViewController: UIViewController {
    
    enum ModelImportOptions {
        case importFile
        case capturePhoto
        case captureVideo
        
        var name: String {
            switch self {
                case .importFile:   return "Import file"
                case .capturePhoto: return "Capture Photo"
                case .captureVideo: return "Capture Video"
            }
        }
    }
    
    @IBOutlet var collectionView: UICollectionView!
    var gradientView: GradientView? {
        return self.view as? GradientView
    }
    
    var virtualObjects = [RoomVirtualObject]()
    
    var selectedVirtualObjectRow: Int?
    
    weak var delegate: RoomObjectSelectionViewControllerDelegate?
    weak var sceneView: ARSCNView?
    
    private var lastObjectAvailabilityUpdateTimestamp: TimeInterval?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        gradientView?.colors = [#colorLiteral(red: 0.09019608051, green: 0, blue: 0.3019607961, alpha: 1), #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)]
        gradientView?.gradientAlpha = 0.6
    }
    
    func updateObjectAvailability() {
        guard let sceneView = sceneView else { return }
        
        // Update object availability only if the last update was at least half a second ago.
        if let lastUpdateTimestamp = lastObjectAvailabilityUpdateTimestamp,
            let timestamp = sceneView.session.currentFrame?.timestamp,
            timestamp - lastUpdateTimestamp < 0.5 {
            return
        } else {
            lastObjectAvailabilityUpdateTimestamp = sceneView.session.currentFrame?.timestamp
        }
                
        var newEnabledVirtualObjectRows = Set<Int>()
        for (row, object) in RoomVirtualObject.availableObjects.enumerated() {
            // Enable row always if item is already placed, in order to allow the user to remove it.
            if selectedVirtualObjectRow == row {
                newEnabledVirtualObjectRows.insert(row)
            }
            
            // Enable row if item can be placed at the current location
            if let query = sceneView.getRaycastQuery(for: object.allowedAlignment),
                let result = sceneView.castRay(for: query).first {
                object.mostRecentInitialPlacementResult = result
                object.raycastQuery = query
                newEnabledVirtualObjectRows.insert(row)
            } else {
                object.mostRecentInitialPlacementResult = nil
                object.raycastQuery = nil
            }
        }
        
        // Only reload changed rows
//        let changedRows = newEnabledVirtualObjectRows.symmetricDifference(enabledVirtualObjectRows)
//        enabledVirtualObjectRows = newEnabledVirtualObjectRows
//        let indexPaths = changedRows.map { row in IndexPath(row: row, section: 0) }
//
//        DispatchQueue.main.async {
//            self.tableView.reloadRows(at: indexPaths, with: .automatic)
//        }
    }
}

extension RoomObjectSelectionViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return virtualObjects.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RoomObjectCollectionViewCell.reuseIdentifier, for: indexPath) as? RoomObjectCollectionViewCell else {
            fatalError("Expected `\(RoomObjectCollectionViewCell.self)` type for reuseIdentifier \(RoomObjectCollectionViewCell.reuseIdentifier). Check the configuration in Main.storyboard.")
        }
        
        if (indexPath.row == 0) {
            cell.setup(with: nil, name: "Scan new Object")
        } else {
            cell.setup(with: nil, name: virtualObjects[indexPath.row - 1].modelName)
        }

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let box = SCNBox(width: 0.5, height: 0.5, length: 0.5, chamferRadius: 0.1)
        let material = box.firstMaterial!
        material.diffuse.contents = UIColor.blue
        material.isDoubleSided = true
        material.ambient.contents = UIColor.black
        material.lightingModel = .constant
        material.emission.contents = UIColor.red
        
        let object = virtualObjects[indexPath.row]
        delegate?.roomObjectSelectionViewController(self, didSelectObject: object)

        dismiss(animated: true, completion: nil)
    }
    
}
