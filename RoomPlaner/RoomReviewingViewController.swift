//
//  RoomReviewingViewController.swift
//  RoomPlaner
//
//  Created by Hlib Sobolevskyi on 19.01.2023.
//

import SceneKit
import SceneKit.ModelIO
import ARKit
import MetalKit

class RoomReviewingViewController: UIViewController {
    
    @IBOutlet var sceneView: RoomReviewingARView!
    
    @IBOutlet weak var openObjectsListButton: UIButton!
    @IBOutlet var placedObjectsListButton: UIButton!
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    let coachingOverlay = ARCoachingOverlayView()
    
    var focusSquare = FocusSquare()
    
    let virtualObjectLoader = RoomVirtualObjectLoader()
    
    var objectsViewController: RoomObjectSelectionViewController?
    
    lazy var virtualObjectInteraction = VirtualObjectInteraction(sceneView: sceneView, viewController: self)
    
    let updateQueue = DispatchQueue(label: "serialRoomUpdateQueue")
    
    var session: ARSession {
        return sceneView.session
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.showsStatistics = true
        
        sceneView.scene.rootNode.addChildNode(focusSquare)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    @IBAction func scanObjectButtonWasPressed(_ sender: Any) {
        if let name = virtualObjectInteraction.selectedObject?.modelName, name.contains("SelecBox") {
            performSegue(withIdentifier: "scanSegue", sender: self)
        } else {
            print("!!!BOX NOT SELECTED")
        }
    }
    
    func placeRoomObject(_ virtualObject: RoomVirtualObject) {
        guard focusSquare.state != .initializing, let query = virtualObject.raycastQuery else {
            return
        }
       
        let trackedRaycast = createTrackedRaycastAndSet3DPosition(of: virtualObject, from: query, withInitialResult: virtualObject.mostRecentInitialPlacementResult)
        
        virtualObject.raycast = trackedRaycast
        virtualObjectInteraction.selectedObject = virtualObject
        virtualObject.isHidden = false
    }
    
    func updateFocusSquare(isObjectVisible: Bool) {
        if isObjectVisible || coachingOverlay.isActive {
            focusSquare.hide()
        } else {
            focusSquare.unhide()
        }
        
        if let camera = session.currentFrame?.camera, camera.trackingState == .normal,
            let query = sceneView.getRaycastQuery(),
            let result = sceneView.castRay(for: query).first {
            
            updateQueue.async {
                self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
                self.focusSquare.state = .detecting(raycastResult: result, camera: camera)
            }
            
            if !coachingOverlay.isActive {
                openObjectsListButton.isHidden = false
            }
        } else {
            updateQueue.async {
                self.focusSquare.state = .initializing
                self.sceneView.pointOfView?.addChildNode(self.focusSquare)
            }
            
            openObjectsListButton.isHidden = true
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let objectsViewController = segue.destination as? RoomObjectSelectionViewController {
            self.objectsViewController = objectsViewController
            objectsViewController.virtualObjects = RoomVirtualObject.availableObjects
            objectsViewController.delegate = self
            objectsViewController.sceneView = sceneView
        } else if let scanningViewController = segue.destination as? RoomObjectScanningViewController {
            guard let box = virtualObjectInteraction.selectedObject else { return }
            let position = box.position
            let scale = box.objectScale
            let min = SCNVector3(position.x - scale.x, position.y - scale.y, position.z - scale.z)
            let max = SCNVector3(position.x + scale.x, position.y + scale.y, position.z + scale.z)
            
            scanningViewController.bBox = BoundingBox((min: min, max: max))
            scanningViewController.bBoxOrigin = position
        }
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        objectsViewController = nil
    }
}
