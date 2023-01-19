//
//  RoomReviewingViewController + RoomObjectSelectionViewControllerDelegate.swift
//  RoomPlaner
//
//  Created by Hlib Sobolevskyi on 19.01.2023.
//

import SceneKit
import ARKit

extension RoomReviewingViewController: RoomObjectSelectionViewControllerDelegate {
    func placeVirtualObject(_ virtualObject: RoomVirtualObject) {
        guard focusSquare.state != .initializing, let query = virtualObject.raycastQuery else {
            return
        }
        
        let trackedRaycast = createTrackedRaycastAndSet3DPosition(of: virtualObject, from: query, withInitialResult: virtualObject.mostRecentInitialPlacementResult)
        
        virtualObject.raycast = trackedRaycast
        virtualObjectInteraction.selectedObject = virtualObject
        virtualObject.isHidden = false
    }
    
    // - Tag: GetTrackedRaycast
    func createTrackedRaycastAndSet3DPosition(of virtualObject: RoomVirtualObject, from query: ARRaycastQuery, withInitialResult initialResult: ARRaycastResult? = nil) -> ARTrackedRaycast? {
        if let initialResult = initialResult {
            self.setTransform(of: virtualObject, with: initialResult)
        }
        
        return session.trackedRaycast(query) { (results) in
            self.setVirtualObject3DPosition(results, with: virtualObject)
        }
    }
    
    func createRaycastAndUpdate3DPosition(of virtualObject: RoomVirtualObject, from query: ARRaycastQuery) {
        guard let result = session.raycast(query).first else {
            return
        }
        
        if virtualObject.allowedAlignment == .any && self.virtualObjectInteraction.trackedObject == virtualObject {
            
            // If an object that's aligned to a surface is being dragged, then
            // smoothen its orientation to avoid visible jumps, and apply only the translation directly.
            virtualObject.simdWorldPosition = result.worldTransform.translation
            
            let previousOrientation = virtualObject.simdWorldTransform.orientation
            let currentOrientation = result.worldTransform.orientation
            virtualObject.simdWorldOrientation = simd_slerp(previousOrientation, currentOrientation, 0.1)
        } else {
            self.setTransform(of: virtualObject, with: result)
        }
    }
    
    // - Tag: ProcessRaycastResults
    private func setVirtualObject3DPosition(_ results: [ARRaycastResult], with virtualObject: RoomVirtualObject) {
        
        guard let result = results.first else {
            fatalError("Unexpected case: the update handler is always supposed to return at least one result.")
        }
        
        self.setTransform(of: virtualObject, with: result)
        
        // If the virtual object is not yet in the scene, add it.
        if virtualObject.parent == nil {
            self.sceneView.scene.rootNode.addChildNode(virtualObject)
            virtualObject.shouldUpdateAnchor = true
        }
        
        if virtualObject.shouldUpdateAnchor {
            virtualObject.shouldUpdateAnchor = false
            self.updateQueue.async {
                self.sceneView.addOrUpdateAnchor(for: virtualObject)
            }
        }
    }
    
    func setTransform(of virtualObject: RoomVirtualObject, with result: ARRaycastResult) {
        virtualObject.simdWorldTransform = result.worldTransform
    }
    
    func roomObjectSelectionViewController(_ selectionViewController: RoomObjectSelectionViewController, didSelectObject object: RoomVirtualObject) {
        
        if let object = object as? RoomVirtualObject {
            virtualObjectLoader.loadVirtualObject(object, loadedHandler: { [unowned self] loadedObject in
                do {
                    let scene = try SCNScene(url: object.referenceURL, options: nil)
                    self.sceneView.prepare([scene], completionHandler: { _ in
                        DispatchQueue.main.async {
                            self.hideObjectLoadingUI()
                            self.placeVirtualObject(loadedObject)
                        }
                    })
                } catch {
                    fatalError("Failed to load SCNScene from object.referenceURL")
                }
            })
        } else {
//            self.sceneView.prepare([object], completionHandler: { _ in
//                DispatchQueue.main.async {
//                    self.hideObjectLoadingUI()
//                    self.placeVirtualObject(loadedObject)
//                }
//            })
        }
    }
    
    func displayObjectLoadingUI() {
        spinner.startAnimating()
        openObjectsListButton.isEnabled = false
    }

    func hideObjectLoadingUI() {
        spinner.stopAnimating()
        openObjectsListButton.isEnabled = true
    }
}
