//
//  RecruitPageController.swift
//  PartyUP
//
//  Created by Fritz Vander Heide on 2015-12-04.
//  Copyright © 2015 Sandcastle Application Development. All rights reserved.
//

import UIKit

class RecruitPageController: UIViewController, PageProtocol {

	var page: Int!

	@IBOutlet weak var shareButton: UIButton!
	
	override func viewDidLoad() {
		var options : UIViewAnimationOptions = .Autoreverse
		options.insert(.Repeat)
		options.insert(.AllowUserInteraction)
		UIView.animateWithDuration(1.0, delay: 0, options: options, animations: { self.shareButton.alpha = 0.5 }, completion: nil)
	}

	@IBAction func recruit(sender: UIButton) {
		presentShareActions(self)
	}

}
