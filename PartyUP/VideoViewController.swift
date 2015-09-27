//
//  VideoViewController.swift
//  PartyUP
//
//  Created by Fritz Vander Heide on 2015-09-22.
//  Copyright © 2015 Sandcastle Application Development. All rights reserved.
//

import UIKit
import AVFoundation

class VideoViewController: UIViewController {

	private let playLayer = AVPlayerLayer()
	private var playControl: AVPlayer?

	var url: NSURL? {
		didSet {
			resetPlayer()
		}
	}

	var rate: Float = 1.0 {
		didSet {
			play(rate)
		}
	}
	var loop: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

		playLayer.frame = view.layer.bounds
		playLayer.videoGravity = AVLayerVideoGravityResizeAspect
		view.layer.addSublayer(playLayer)

		NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("applicationDidBecomeActiveNotification:"), name: UIApplicationDidBecomeActiveNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("applicationWillResignActiveNotification:"), name: UIApplicationWillResignActiveNotification, object: nil)
    }

	@objc
	func applicationDidBecomeActiveNotification(note: NSNotification) {
		play(rate)
	}

	@objc
	func applicationWillResignActiveNotification(note: NSNotification) {
		play(0.0)
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		play(rate)
	}

	override func viewDidDisappear(animated: Bool) {
		super.viewDidDisappear(animated)
		play(0.0)
	}

	func resetPlayer() {
		playControl?.removeObserver(self, forKeyPath: "status", context: UnsafeMutablePointer<Void>())
		NSNotificationCenter.defaultCenter().removeObserver(self, name: "playbackReachedEndNotification", object: playControl?.currentItem)

		if let url = url {
			playControl = AVPlayer(URL: url)
			playControl?.addObserver(self, forKeyPath: "status", options: .Initial, context: UnsafeMutablePointer<Void>())
			playLayer.player = playControl

			NSNotificationCenter.defaultCenter().addObserver(self,
				selector: Selector("playbackReachedEndNotification"),
				name: AVPlayerItemDidPlayToEndTimeNotification,
				object: playControl?.currentItem)
		}
	}

	deinit {
		playControl?.removeObserver(self, forKeyPath: "status", context: UnsafeMutablePointer<Void>())
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	private func play(rate: Float = 1.0) {

		if let player = playControl {
			switch player.status {
			case .ReadyToPlay:
				player.rate = rate
			case .Failed:
				resetPlayer()
			case .Unknown:
				break
			}
		}
	}

	override func prefersStatusBarHidden() -> Bool {
		return true
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		playLayer.frame = view.bounds
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {

		if keyPath == "status" {
			dispatch_async(dispatch_get_main_queue()) { if self.view.window != nil { self.play() } }
		}
	}

	func playbackReachedEndNotification() {
		playControl?.seekToTime(kCMTimeZero)
		if loop {
			play(rate)
		}
	}
}
