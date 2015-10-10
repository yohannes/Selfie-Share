//
//  ViewController.swift
//  Selfie Share
//
//  Created by Yohannes Wijaya on 10/8/15.
//  Copyright © 2015 Yohannes Wijaya. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate {
    
    // MARK: - Stored Properties
    
    var images = [UIImage]()
    
    // manager class that handles all multipeer connnectivity
    var peerID: MCPeerID!
    // identifies each user uniquely in a session
    var mcSession: MCSession!
    // Used to create a session and thus telling others that it exists and handling invitations
    var mcAdvertiserAssistant: MCAdvertiserAssistant!
    
    // MARK: - IBOutlet Properties
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    // MARK: - Methods Override

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Selfie Share"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Camera, target: self, action: "importPicture")
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "showConnectionPrompt")
        
        self.peerID = MCPeerID(displayName: UIDevice.currentDevice().name)
        self.mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .Required)
        self.mcSession.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Delegate Methods
    
    func browserViewControllerDidFinish(browserViewController: MCBrowserViewController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    func browserViewControllerWasCancelled(browserViewController: MCBrowserViewController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.images.count ?? 0
    }
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let collectionViewCell = collectionView.dequeueReusableCellWithReuseIdentifier("ImageViewReusableIdentifier", forIndexPath: indexPath)
        
        if let imageView = collectionViewCell.viewWithTag(1000) as? UIImageView {
            imageView.image = self.images[indexPath.item]
        }
        
        return collectionViewCell
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        var newImage: UIImage!
        
        if let possibleImage = info["UIImagePickerControllerEditedImage"] as? UIImage {
            newImage = possibleImage
        }
        else if let possibleImage = info["UIImagePickerControllerOriginalImage"] as? UIImage {
            newImage = possibleImage
        }
        else { return }
        
        self.dismissViewControllerAnimated(true, completion: nil)
        
        self.images.insert(newImage, atIndex: 0)
        self.collectionView.reloadData()
        
        // 1. check if there's any peer to connect to
        if self.mcSession.connectedPeers.count > 0 {
            // 2. convert new image to NSData
            if let imageData = UIImagePNGRepresentation(newImage) {
                // 3. send it to all peers making sure it gets delivered
                do {
                    try self.mcSession.sendData(imageData, toPeers: self.mcSession.connectedPeers, withMode: MCSessionSendDataMode.Reliable)
                }
                catch let error as NSError {
                    let alertController = UIAlertController(title: "Send error", message: error.localizedDescription, preferredStyle: .Alert)
                    let alertAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
                    alertController.addAction(alertAction)
                    self.presentViewController(alertController, animated: true, completion: nil)
                }
            }
        }
        
    }
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        switch state {
        case MCSessionState.Connected: print("Connected: \(peerID.displayName)")
        case MCSessionState.Connecting: print("Connecting: \(peerID.displayName)")
        case MCSessionState.NotConnected: print("Not connected: \(peerID.displayName)")
        }
    }
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        if let image = UIImage(data: data) {
            dispatch_async(dispatch_get_main_queue(), { [unowned self] () -> Void in
                self.images.insert(image, atIndex: 0)
                self.collectionView.reloadData()
            })
        }
    }
    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {}
    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) {}

    // MARK: - Local Methods
    
    func importPicture() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.allowsEditing = true
        imagePickerController.delegate = self
        self.presentViewController(imagePickerController, animated: true, completion: nil)
    }
    
    func showConnectionPrompt() {
        let alertController = UIAlertController(title: "Connect to peers", message: nil, preferredStyle: .ActionSheet)
        let alertActionToHost = UIAlertAction(title: "Host a session", style: .Default, handler: self.startHosting)
        let alertActionToJoin = UIAlertAction(title: "Join a session", style: .Default, handler: self.joinSession)
        let alertActionToCancel = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addAction(alertActionToHost)
        alertController.addAction(alertActionToJoin)
        alertController.addAction(alertActionToCancel)
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func startHosting(alertAction: UIAlertAction) {
        self.mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "selfie-share", discoveryInfo: nil, session: self.mcSession)
        self.mcAdvertiserAssistant.start()
    }
    
    func joinSession(alertAction: UIAlertAction) {
        // used to look for sessions, showing users who is nearby and letting them join
        let mcBrowser = MCBrowserViewController(serviceType: "selfie-share", session: self.mcSession)
        mcBrowser.delegate = self
        self.presentViewController(mcBrowser, animated: true, completion: nil)
    }
}

