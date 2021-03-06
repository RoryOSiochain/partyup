//
//  TutorialOverlayManager.swift
//  PartyUP
//
//  Created by Fritz Vander Heide on 2016-04-06.
//  Copyright © 2016 Sandcastle Application Development. All rights reserved.
//
import Instructions
import Foundation

struct TutorialMark {
	let identifier: Int
	let hint: String
	var view: UIView?

	init(identifier: Int, hint: String, view: UIView? = nil){
		self.identifier = identifier
		self.hint = hint
		self.view = view
	}
}

class TutorialOverlayManager: CoachMarksControllerDataSource, CoachMarksControllerDelegate {

	var marks: [TutorialMark]? {
		didSet {
			filterMarks()
		}
	}

	var tutoring: Bool {
		get {
			return coach.flatMap { $0.flow.started } ?? false
		}
	}
    
    var completion: ((Bool) -> Void)?

	private var coach: CoachMarksController?

	private let skip: CoachMarkSkipDefaultView = {
		let skip = CoachMarkSkipDefaultView()
		skip.setTitle(NSLocalizedString("Skip", comment: "Tutorial skip button label"), forState: .Normal)
		return skip
	}()

	private let defaults = NSUserDefaults.standardUserDefaults()
	private var unseen = [TutorialMark]()
	private weak var target: UIViewController?

	init(marks: [TutorialMark]) {
		self.marks = marks
		filterMarks()

		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(TutorialOverlayManager.filterMarks), name: NSUserDefaultsDidChangeNotification, object: nil)
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	@objc
	private func filterMarks() {
		if let marks = marks  where !marks.isEmpty{
			if let seen = defaults.arrayForKey(PartyUpPreferences.TutorialViewed) as? [Int] {
				unseen = marks.filter { !seen.contains($0.identifier) }
			}
		} else {
			unseen.removeAll()
		}
	}

	private func create() -> CoachMarksController {
		let coach = CoachMarksController()
		coach.dataSource = self
		coach.delegate = self
		coach.overlay.color = UIColor.darkGrayColor().colorWithAlphaComponent(0.4)
		coach.overlay.allowTap = true
		coach.overlay.allowTouchInsideCutoutPath = false
		return coach
	}

	func start(target: UIViewController) {
		if !unseen.isEmpty {
			if coach == nil {
				coach = create()
				coach?.skipView = unseen.count > 1 ? skip : nil
				coach?.startOn(target)
				self.target = target
			}
        } else {
            completion?(false)
        }
	}

	func stop() {
		coach?.stop()
	}

	func pause() {
		coach?.pause()
	}

	func resume() {
		coach?.resume()
	}

	func numberOfCoachMarksForCoachMarksController(coachMarksController: CoachMarksController) -> Int {
		return unseen.count
	}

	func coachMarksController(coachMarksController: CoachMarksController, coachMarkForIndex index: Int) -> CoachMark {
		if unseen[index].view == nil {
			unseen[index].view = UIApplication.sharedApplication().keyWindow?.viewWithTag(unseen[index].identifier)
		}
		return coachMarksController.helper.coachMarkForView(unseen[index].view)
	}

	func coachMarksController(coachMarksController: CoachMarksController, coachMarkViewsForIndex index: Int, coachMark: CoachMark) -> (bodyView: CoachMarkBodyView, arrowView: CoachMarkArrowView?) {
		let hint = NSLocalizedString(unseen[index].hint, comment: "Tutorial Mark \(unseen[index].identifier)")
		let next = NSLocalizedString("ok", comment: "Tutorial next label")
		var coachViews = coachMarksController.helper.defaultCoachViewsWithArrow(true, arrowOrientation: coachMark.arrowOrientation, hintText: hint, nextText: next)
		coachViews.bodyView.hintLabel.textAlignment = .Center
		if unseen[index].identifier < 0 {
			coachViews.arrowView = nil
		}
		return (bodyView: coachViews.bodyView, arrowView: coachViews.arrowView)
	}

	func coachMarksController(coachMarksController: CoachMarksController, didFinishShowingAndWasSkipped skipped: Bool) {
		if var seen = defaults.arrayForKey(PartyUpPreferences.TutorialViewed) as? [Int] {
			seen.appendContentsOf(unseen.map { $0.identifier})
			defaults.setObject(seen, forKey: PartyUpPreferences.TutorialViewed)
		}

		unseen.removeAll()
		coach = nil
        completion?(skipped)
	}

	func coachMarksController(coachMarksController: CoachMarksController, constraintsForSkipView skipView: UIView, inParentView parentView: UIView) -> [NSLayoutConstraint]? {

		var constraints: [NSLayoutConstraint] = []

		constraints.append(NSLayoutConstraint(item: skipView, attribute: .CenterX, relatedBy: .Equal, toItem: parentView, attribute: .CenterX, multiplier: 1.0, constant: 0))
		constraints.append(NSLayoutConstraint(item: skipView, attribute: .Bottom, relatedBy: .Equal, toItem: parentView, attribute: .BottomMargin, multiplier: 1.0, constant: 0))

		return constraints
	}
}
