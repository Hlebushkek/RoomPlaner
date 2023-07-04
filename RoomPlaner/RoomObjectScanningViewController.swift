//
//  RoomObjectScanningViewController.swift
//  RoomPlaner
//
//  Created by Hlib Sobolevskyi on 20.01.2023.
//

import ARKit
import MetalKit
import SceneKit
import RealityKit

struct BoundingBox {
    let min: SCNVector3
    let max: SCNVector3

    init(_ boundTuple: (min: SCNVector3, max: SCNVector3)) {
        min = boundTuple.min
        max = boundTuple.max
    }

    func contains(_ point: SCNVector3) -> Bool {
        let contains =
        min.x <= point.x &&
        min.y <= point.y &&
        min.z <= point.z &&
        
        max.x > point.x &&
        max.y > point.y &&
        max.z > point.z

        return contains
    }
}

class RoomObjectScanningViewController: UIViewController,  MTKViewDelegate, ARSessionDelegate, ARSCNViewDelegate, RendererDelegate {
    
    @IBOutlet var mtkView: MTKView!
    
    @IBOutlet var backButton: UIButton!
    @IBOutlet var saveButton: UIButton!
    
    var session: ARSession!
    var wConfig: ARWorldTrackingConfiguration!
    var sConfig: ARWorldTrackingConfiguration!
    var renderer: Renderer!
    
    var arView: ARSCNView!
    var arBounds: CGRect!
    
    var scanNode: SCNNode!
    var mainAsset: MDLAsset!
    var scanTexture: UIImage!
    var textureImgs: [Int: UIImage] = [:]
    
    var allVerts: [[SCNVector3]] = []
    var allNorms: [[SCNVector3]] = []
    var allTCrds: [[vector_float2]] = []
    
    var cVerts: [SCNVector3] = []
    var cNorms: [SCNVector3] = []
    var cTCrds: [vector_float2] = []
    var nFaces: [[UInt32]] = []
    
    var bBox: BoundingBox!
    var bBoxOrigin: SCNVector3!
    
    let coachingOverlay = ARCoachingOverlayView()
    
    let virtualObjectLoader = RoomVirtualObjectLoader()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        session = ARSession()
        session.delegate = self
        
        wConfig = ARWorldTrackingConfiguration()
        wConfig.sceneReconstruction = .mesh
        wConfig.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        
        mtkView = MTKView(frame: view.frame)
        view.addSubview(mtkView)
        
        view.bringSubviewToFront(backButton)
        view.bringSubviewToFront(saveButton)
        
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.backgroundColor = .black
        mtkView.delegate = self

        renderer = Renderer(session: session, view: mtkView)
        renderer.bBox = self.bBox
        renderer.bBoxOrigin = self.bBoxOrigin
        renderer.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        session.run(wConfig)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        session.pause()
    }
    
    @IBAction func backButtonWasPressed(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction func saveButtonWasPressed(_ sender: Any) {
        save()
    }
    
    func save() {
        // Fetch the default MTLDevice to initialize a MetalKit buffer allocator with
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to get the system's default Metal device!")
        }
        
        // Using the Model I/O framework to export the scan, so we're initialising an MDLAsset object,
        // which we can export to a file later, with a buffer allocator
        let allocator = MTKMeshBufferAllocator(device: device)
        let mainAsset = MDLAsset(bufferAllocator: allocator)
        
        // Convert the geometry of each ARMeshAnchor into a MDLMesh and add it to the MDLAsset
        let worldMeshes = renderer.worldMeshes
        let textureCloud = renderer.textureCloud
        
        for mesh in worldMeshes {
            
            let aTrans = SCNMatrix4(mesh.transform)
            
            let vertices: ARGeometrySource = mesh.vertices
            let normals: ARGeometrySource = mesh.normals
            let faces: ARGeometryElement = mesh.submesh
            let inBox: [Int32] = mesh.inBox
//            var texture: UIImage!
            
            // a face is just a list of three indices, each representing a vertex
            for f in 0..<faces.count {
                
                // check to see if each vertex of the face is inside of our box
                var c = 0
                let face = face(at: f, faces: faces)
                for fv in face {
                    // this is set by the renderer
                    if inBox[fv] == 1 {
                        c += 1
                    }
                }
                
                guard c == 3 else {continue}
                
                // all verts of the face are in the box, so the triangle is visible
                var fVerts: [SCNVector3] = []
                var fNorms: [SCNVector3] = []
//                var tCoords: [vector_float2] = []
                
                // convert each vertex and normal to world coordinates
                // get the texture coordinates
                for fv in face {
                    
                    let vert = vertex(at: UInt32(fv), vertices: vertices)
                    let vTrans = SCNMatrix4MakeTranslation(vert[0], vert[1], vert[2])
                    let wTrans = SCNMatrix4Mult(vTrans, aTrans)
                    let wPos = SCNVector3(wTrans.m41, wTrans.m42, wTrans.m43)
                    fVerts.append(wPos)
                    
                    let norm = normal(at: UInt32(fv), normals: normals)
                    let nTrans = SCNMatrix4MakeTranslation(norm[0], norm[1], norm[2])
                    let wNTrans = SCNMatrix4Mult(nTrans, aTrans)
                    let wNPos = SCNVector3(wNTrans.m41, wTrans.m42, wNTrans.m43)
                    fNorms.append(wNPos)
                    
                    
                    // here's where you would find the frame that best fits
                    // for simplicity, just use the last frame here
//                    let tFrame = textureCloud.last!.frame
//                    let tCoord = getTextureCoord(frame: tFrame, vert: vert, aTrans: mesh.transform)
//                    tCoords.append(tCoord)
//                    texture = textureImgs[textureCloud.count - 1]
                    
                    // visualize the normals if you want
                    if inBox[fv] == 1 {
                        //let normVis = lineBetweenNodes(positionA: wPos, positionB: wNPos, inScene: arView.scene)
                        //arView.scene.rootNode.addChildNode(normVis)
                    }
                }
                allVerts.append(fVerts)
                allNorms.append(fNorms)
//                allTCrds.append(tCoords)
                
                // make a single triangle mesh out each face
                let vertsSource = SCNGeometrySource(vertices: fVerts)
                let normsSource = SCNGeometrySource(normals: fNorms)
                let facesSource = SCNGeometryElement(indices: [UInt32(0), UInt32(1), UInt32(2)], primitiveType: .triangles)
//                let textrSource = SCNGeometrySource(textureCoordinates: tCoords)
                let geom = SCNGeometry(sources: [vertsSource, normsSource], elements: [facesSource])
                
                // texture it with a saved camera frame
                let mat = SCNMaterial()
//                mat.diffuse.contents = texture
                mat.isDoubleSided = false
                geom.materials = [mat]
                
                let meshNode = SCNNode(geometry: geom)
                let mesh = MDLMesh(scnNode: meshNode)
                
                DispatchQueue.main.async {
                    mainAsset.add(mesh)
//                    self.scanNode.addChildNode(meshNode)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: { [weak self] in
            self?.saveAsset(mainAsset, name: "newFullScan")
            self?.dismiss(animated: true)
        })
    }
    
    func saveAsset(_ asset: MDLAsset, name: String) {
        // Setting the path to export the OBJ file to
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlOBJ = documentsPath.appendingPathComponent("\(name).obj")
        print("PATH: \(urlOBJ)")
        
        if MDLAsset.canExportFileExtension("obj") {
            do {
                try asset.export(to: urlOBJ)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        } else {
            fatalError("Can't export OBJ")
        }
    }
    
    func normal(at index: UInt32, normals: ARGeometrySource) -> SIMD3<Float> {
        assert(normals.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per normal.")
        let normalPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * Int(index)))
        let normal = normalPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return normal
    }
    
    func vertex(at index: UInt32, vertices: ARGeometrySource) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
    
    func face(at index: Int, faces: ARGeometryElement) -> [Int] {
        let indicesPerFace = faces.indexCountPerPrimitive
        let facesPointer = faces.buffer.contents()
        var vertexIndices = [Int]()
        for offset in 0..<indicesPerFace {
            let vertexIndexAddress = facesPointer.advanced(by: (index * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
            vertexIndices.append(Int(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee))
        }
        return vertexIndices
    }
    
    func draw(in view: MTKView) {
        renderer.update()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("drawable size: \(size)")
    }
    
    func didSaveFrame(renderer: Renderer) {
        
    }
}

extension RoomObjectScanningViewController: ARCoachingOverlayViewDelegate {
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        
    }
}

extension ARMeshGeometry {
    func vertex(at index: UInt32) -> (Float, Float, Float) {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
        return vertex
    }
    
    /// To get the mesh's classification, the sample app parses the classification's raw data and instantiates an
    /// `ARMeshClassification` object. For efficiency, ARKit stores classifications in a Metal buffer in `ARMeshGeometry`.
    func classificationOf(faceWithIndex index: Int) -> ARMeshClassification {
        guard let classification = classification else { return .none }
        assert(classification.format == MTLVertexFormat.uchar, "Expected one unsigned char (one byte) per classification")
        let classificationPointer = classification.buffer.contents().advanced(by: classification.offset + (classification.stride * index))
        let classificationValue = Int(classificationPointer.assumingMemoryBound(to: CUnsignedChar.self).pointee)
        return ARMeshClassification(rawValue: classificationValue) ?? .none
    }
    
    func vertexIndicesOf(faceWithIndex faceIndex: Int) -> [UInt32] {
        assert(faces.bytesPerIndex == MemoryLayout<UInt32>.size, "Expected one UInt32 (four bytes) per vertex index")
        let vertexCountPerFace = faces.indexCountPerPrimitive
        let vertexIndicesPointer = faces.buffer.contents()
        var vertexIndices = [UInt32]()
        vertexIndices.reserveCapacity(vertexCountPerFace)
        for vertexOffset in 0..<vertexCountPerFace {
            let vertexIndexPointer = vertexIndicesPointer.advanced(by: (faceIndex * vertexCountPerFace + vertexOffset) * MemoryLayout<UInt32>.size)
            vertexIndices.append(vertexIndexPointer.assumingMemoryBound(to: UInt32.self).pointee)
        }
        return vertexIndices
    }
    
    func verticesOf(faceWithIndex index: Int) -> [(Float, Float, Float)] {
        let vertexIndices = vertexIndicesOf(faceWithIndex: index)
        let vertices = vertexIndices.map { vertex(at: $0) }
        return vertices
    }
}
