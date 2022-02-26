//
//  ViewController.swift
//  ScreenCasting
//
//  Created by Khaos Tian on 6/6/19.
//  Copyright © 2019 Oltica. All rights reserved.
//

import Cocoa
import CoreMediaIO
import AVFoundation

class ViewController: NSViewController {

    private var previewLayer: AVCaptureVideoPreviewLayer?
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    @IBOutlet weak var labelEffectView: NSVisualEffectView!
    @IBOutlet weak var deviceLabel: NSTextField!
    
    private var captureSession: AVCaptureSession?
    
    private var activeDevice: AVCaptureDevice?
    
    private var isViewVisible = false

    private var isElementHidden = false
        
    override func viewDidLoad() {
        super.viewDidLoad()

        let gesture = NSClickGestureRecognizer(target: self, action: #selector(didClickOnView))
        view.addGestureRecognizer(gesture)

        labelEffectView.layer?.cornerRadius = 8
        AVCaptureDevice.requestAccess(for: .video) { result in
            guard result else {
                NSLog("Rejected.")
                return
            }
            self.setupAVStack()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePortFormatDescriptionDidChangeNotification(_:)),
            name: .AVCaptureInputPortFormatDescriptionDidChange,
            object: nil
        )
    }
    
    @objc
    private func newDocument(_ sender: AnyObject) {
        if let windowController = self.storyboard?.instantiateInitialController() as? NSWindowController {
            windowController.showWindow(sender)
        }
    }

    @objc
    private func didClickOnView() {
        guard captureSession != nil else {
            return
        }

        isElementHidden.toggle()

        if isElementHidden {
            hideElements()
        } else {
            showElements()
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let cameraSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .externalUnknown,
            ],
            mediaType: .video,
            position: .unspecified
        )
        
        let screenCastSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .externalUnknown,
            ],
            mediaType: .muxed,
            position: .unspecified
        )
        
        let devices = screenCastSession.devices + cameraSession.devices
        
        let menu = NSMenu(title: "Settings")
        
        let deviceTitleItem = NSMenuItem(title: "Source", action: nil, keyEquivalent: "")
        menu.addItem(deviceTitleItem)
        
        for device in devices {
            let item = NSMenuItem(title: device.localizedName, action: #selector(handleVideoSourceSelect(_:)), keyEquivalent: "")
            item.indentationLevel = 1
            item.representedObject = device
            item.state = activeDevice == device ? .on : .off
            menu.addItem(item)
        }
        
        if devices.isEmpty {
            menu.addItem(withTitle: "No Available Source", action: nil, keyEquivalent: "")
        }
        
        let videoFormats = activeDevice?.formats.filter { $0.mediaType == .video } ?? []
        if !videoFormats.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let formatTitleItem = NSMenuItem(title: "Format", action: nil, keyEquivalent: "")
            menu.addItem(formatTitleItem)
            
            for format in videoFormats {
                let frameRates = format.videoSupportedFrameRateRanges
                    .map { String(format: "%.2f fps", $0.maxFrameRate) }
                    .joined(separator: ",")
                
                let dimensions = format.formatDescription.dimensions
                let resolution = "\(dimensions.width)x\(dimensions.height)"
                
                let item = NSMenuItem(
                    title: "\(resolution) (\(frameRates)) - \(format.formatDescription.mediaSubType)",
                    action: #selector(handleVideoFormatSelect(_:)),
                    keyEquivalent: ""
                )
                item.indentationLevel = 1
                item.representedObject = format
                item.state = (activeDevice?.activeFormat == format) ? .on : .off
                menu.addItem(item)
            }
        }
        
        if let captureSession = captureSession {
            menu.addItem(NSMenuItem.separator())
            
            var availablePresets: [AVCaptureSession.Preset] = [
                .photo,
                .high,
                .medium,
                .low,
            ]
            
            if #available(macOS 10.15, *) {
                availablePresets.append(
                    contentsOf: [
                        .hd4K3840x2160,
                        .hd1920x1080,
                        .hd1280x720,
                    ]
                )
            }
            
            let presetTitleItem = NSMenuItem(title: "Preset", action: nil, keyEquivalent: "")
            menu.addItem(presetTitleItem)
            
            for preset in availablePresets {
                if captureSession.canSetSessionPreset(preset) {
                    let item = NSMenuItem(title: preset.rawValue, action: #selector(handleVideoPresetSelect(_:)), keyEquivalent: "")
                    item.indentationLevel = 1
                    item.representedObject = preset
                    item.state = captureSession.sessionPreset == preset ? .on : .off
                    menu.addItem(item)
                }
            }
        }
        
        NSMenu.popUpContextMenu(menu, with: event, for: self.view)
    }
    
    @objc
    private func handleVideoSourceSelect(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AVCaptureDevice else {
            return
        }
        
        configureInput(device)
    }
    
    @objc
    private func handleVideoPresetSelect(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? AVCaptureSession.Preset else {
            return
        }
        
        captureSession?.sessionPreset = preset
    }
    
    @objc
    private func handleVideoFormatSelect(_ sender: NSMenuItem) {
        guard let activeDevice = activeDevice,
              let format = sender.representedObject as? AVCaptureDevice.Format else {
            return
        }
        
        do {
            try activeDevice.lockForConfiguration()
            
            activeDevice.activeFormat = format
            
            activeDevice.unlockForConfiguration()
        } catch {
            NSLog("Failed to update device, error: \(error)")
        }
    }

    @objc
    private func handlePortFormatDescriptionDidChangeNotification(_ notification: NSNotification) {
        if let captureSession = captureSession, let port = notification.object as? AVCaptureInput.Port {
            guard captureSession.inputs.contains(where: { $0.ports.contains(port) }) else {
                return
            }
            
            if let formatDescription = port.formatDescription,
               let window = self.view.window,
               let screen = window.screen {
                
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                
                window.aspectRatio = NSSize(
                    width: CGFloat(dimensions.width)/CGFloat(dimensions.height),
                    height: 1
                )
                
                window.setContentSize(
                    NSSize(
                        width: Int(CGFloat(dimensions.width) / screen.backingScaleFactor),
                        height: Int(CGFloat(dimensions.height) / screen.backingScaleFactor)
                    )
                )
            }
        }
    }
    
    private func setupAVStack() {
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
        var allow: UInt32 = 1
        CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &prop,
            0,
            nil,
            UInt32(MemoryLayout.size(ofValue: allow)),
            &allow
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceConnected(_:)),
            name: .AVCaptureDeviceWasConnected,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceDisconnected(_:)),
            name: .AVCaptureDeviceWasDisconnected,
            object: nil
        )
    }
    
    @objc
    private func handleDeviceConnected(_ notification: Notification) {
        guard isViewVisible else {
            return
        }
        
        if activeDevice == nil,
           let device = notification.object as? AVCaptureDevice,
           device.hasMediaType(.muxed) {
            self.configureInput(device)
        }
    }
    
    @objc
    private func handleDeviceDisconnected(_ notification: Notification) {
        guard let device = notification.object as? AVCaptureDevice else {
            return
        }
        
        if self.activeDevice == device {
            teardown()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        isViewVisible = true
        activityIndicator.startAnimation(self)
        
        let screenCastSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .externalUnknown,
            ],
            mediaType: .muxed,
            position: .unspecified
        )
        
        if let device = screenCastSession.devices.first {
            self.configureInput(device)
        }
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        isViewVisible = false
        teardown()
    }
    
    private func teardown() {
        self.activeDevice = nil
        self.labelEffectView.isHidden = true
        self.captureSession?.stopRunning()
        self.captureSession = nil
        activityIndicator.startAnimation(self)
    }

    private func showElements() {
        updateWindowButtonsVisibility(false)
        labelEffectView.isHidden = false
    }

    private func hideElements() {
        updateWindowButtonsVisibility(true)
        labelEffectView.isHidden = true
    }

    private func updateWindowButtonsVisibility(_ isHidden: Bool) {
        guard let window = view.window else {
            return
        }

        window.standardWindowButton(.closeButton)?.isHidden = isHidden
        window.standardWindowButton(.miniaturizeButton)?.isHidden = isHidden
        window.standardWindowButton(.zoomButton)?.isHidden = isHidden
    }
    
    private func configureInput(_ device: AVCaptureDevice) {
        if activeDevice != nil {
            captureSession?.stopRunning()
        }
        let captureSession = AVCaptureSession()
        activeDevice = device
        
        do {
            try device.lockForConfiguration()
        } catch {
            NSLog("Unable to lock device")
        }
        print(device.manufacturer)
        print(device.localizedName)
        print(device.modelID)
        
        deviceLabel.stringValue = device.localizedName
        labelEffectView.isHidden = false
        
        captureSession.beginConfiguration()
        guard let videoInputDevice = try? AVCaptureDeviceInput(device: device),
            captureSession.canAddInput(videoInputDevice) else {
                NSLog("Can't add it.")
                return
        }
        
        captureSession.addInput(videoInputDevice)
        captureSession.commitConfiguration()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer = previewLayer
        
        captureSession.startRunning()
        device.unlockForConfiguration()
        activityIndicator.stopAnimation(self)
        self.captureSession = captureSession
    }
}
