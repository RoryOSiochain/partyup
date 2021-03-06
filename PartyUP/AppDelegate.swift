//
//  AppDelegate.swift
//  PartyUP
//
//  Created by Fritz Vander Heide on 2015-09-13.
//  Copyright © 2015 Sandcastle Application Development. All rights reserved.
//

import UIKit
import AWSCore
import AWSS3
import AWSCognito
import Flurry_iOS_SDK
import FBSDKCoreKit

struct PartyUpPreferences
{
	static let VideoQuality = "VideoQuality"
	static let ListingRadius = "ListRadius"
	static let SampleRadius = "SampleRadius"
	static let VenueCategories = "VenueCategories"
	static let StaleSampleInterval = "StaleSampleInterval"
	static let CameraJump = "CameraJump"
	static let StickyTowns = "StickyTowns"
	static let PlayTutorial = "Tutorial"
	static let TutorialViewed = "TutorialViewed"
    static let AgreedToTerms = "Terms"
	static let RemindersInterface = "RemindersInterface"
	static let RemindersInterval = "RemindersInterval"
    static let SampleSuppressionThreshold = "SampleSuppressionThreshold"
    static let FeedNavigationArrows = "FeedNavigationArrows"
	static let SeedFacebookVideo = "SeedFacebookVideo"
    static let SeedFacebookBroadcast = "SeedFacebookBroadcast"
    static let SeedFacebookTimeline = "SeedFacebookTimeline"
    static let SeedStaleInterval = "SeedStaleInterval"
    static let PromptAuthentication = "PromptAuthentication"
    static let AllowAuthenticationPutoff = "AllowAuthenticationPutoff"
}

struct PartyUpConstants
{
	static let FavoriteLocationNotification = "FavoriteLocationNotification"
    static let RecordVideoNotification = "RecordVideoNotification"
	static let DefaultStoragePrefix = "media"
	static let TitleLogo: ()->UIImageView = {
		let logoView = UIImageView(image: UIImage(named: "Logo"))
		logoView.contentMode = .ScaleAspectFit
		logoView.bounds = CGRect(x: 0, y: 0, width: 24, height: 40)
		return logoView
	}
}

struct FacebookConstants
{
	static let GraphApiHost = NSURL(scheme: "https", host: "graph.facebook.com/v2.7", path: "/")!
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	private struct AwsConstants
	{
		static let BackgroundSession = "com.sandcastleapps.partyup.session"
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

		NSSetUncaughtExceptionHandler({
			(error) in Flurry.logError("Uncaught_Exception", message: "Uh oh", exception: error)
		})

		Flurry.setUserID(UIDevice.currentDevice().identifierForVendor?.UUIDString)
		Flurry.startSession(PartyUpKeys.FlurryIdentifier)

		let tint = UIColor(r: 247, g: 126, b: 86, alpha: 255)

		window?.tintColor = tint
		UINavigationBar.appearance().backgroundColor = UIColor.whiteColor()
		UINavigationBar.appearance().backIndicatorImage = UIImage(named: "Back")
		UINavigationBar.appearance().backIndicatorTransitionMaskImage = UIImage(named: "Back")
		UINavigationBar.appearance().translucent = false
		UINavigationBar.appearance().tintColor = tint
		UIToolbar.appearance().tintColor = tint
		UITextView.appearance().tintColor = tint
		UIButton.appearance().tintColor = tint

		let defaults = NSUserDefaults.standardUserDefaults()
		if let defaultsUrl = NSBundle.mainBundle().URLForResource("PartyDefaults", withExtension: "plist") {
			if let defaultsDictionary = NSDictionary(contentsOfURL: defaultsUrl) as? [String:AnyObject] {
				defaults.registerDefaults(defaultsDictionary)
			}
		}

		observeSettingsChange()

		application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [.Sound, .Alert], categories: nil))
        
        let manager = NSFileManager.defaultManager()
        let mediaTemp = NSTemporaryDirectory() + PartyUpConstants.DefaultStoragePrefix
        
        if !manager.fileExistsAtPath(mediaTemp) {
           try! NSFileManager.defaultManager().createDirectoryAtPath(mediaTemp, withIntermediateDirectories: true, attributes: nil)
        }

		#if DEBUG
			AWSLogger.defaultLogger().logLevel = .Warn
		#else
            AWSLogger.defaultLogger().logLevel = .Error
        #endif
        
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(AppDelegate.observeSettingsChange), name: NSUserDefaultsDidChangeNotification, object: nil)

		Sample.InitializeStamps()

		return AuthenticationManager.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
	}

	func observeSettingsChange() {
		let defaults = NSUserDefaults.standardUserDefaults()
		if defaults.boolForKey(PartyUpPreferences.PlayTutorial) {
			defaults.setBool(false, forKey: PartyUpPreferences.PlayTutorial)
			defaults.setObject([], forKey: PartyUpPreferences.TutorialViewed)
		}
	}

	func application(application: UIApplication, didRegisterUserNotificationSettings notificationSettings: UIUserNotificationSettings) {
        application.cancelAllLocalNotifications()
		if notificationSettings.types != .None {
			scheduleReminders()
			if let notifyUrl = NSBundle.mainBundle().URLForResource("PartyNotify", withExtension: "plist") {
				scheduleNotificationsFromUrl(notifyUrl, inApplication: application, withNotificationSettings: notificationSettings)
			}
		}
	}

	func application(application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: () -> Void) {

		AWSS3TransferUtility.interceptApplication(application, handleEventsForBackgroundURLSession: AwsConstants.BackgroundSession, completionHandler: completionHandler)
	}

	func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
		return AuthenticationManager.shared.application(application, openURL: url, sourceApplication: sourceApplication, annotation: annotation)
	}

	func scheduleNotificationsFromUrl(url: NSURL, inApplication application: UIApplication, withNotificationSettings notificationSettings: UIUserNotificationSettings) {
        if let notifications = NSArray(contentsOfURL: url) as? [[String:AnyObject]] {
            for notify in notifications {
                scheduleNotificationFromDictionary(notify, inApplication: application, withNotificationSettings: notificationSettings)
            }
        }
	}
    
    func scheduleNotificationFromDictionary(notify: [String : AnyObject], inApplication application: UIApplication, withNotificationSettings notificationSettings: UIUserNotificationSettings) {
        if let whens = notify["whens"] as? [[String:Int]],
            what = notify["messages"] as? [String],
            action = notify["action"] as? String,
            tag = notify["tag"] as? Int where what.count > 0 {
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
                for when in whens {
                    let relative = NSDateComponents()
                    relative.calendar = calendar
                    relative.hour = when["hour"] ?? NSDateComponentUndefined
                    relative.minute = when["minute"] ?? NSDateComponentUndefined
                    relative.weekday = when["weekday"] ?? NSDateComponentUndefined
                    let range = when["range"] ?? 0
                    let prebook = notify["prebook"] as? Int ?? 0
                    let iterations = prebook < 0 ? 1 : prebook
                    let randomize = notify["randomize"] as? Bool ?? false
                    var date = NSDate().dateByAddingTimeInterval(NSTimeInterval(range/2)*60)
                    for i in 0..<iterations {
                        if let futureDate = calendar?.nextDateAfterDate(date, matchingComponents: relative, options: .MatchNextTime) {
                            let localNote = UILocalNotification()
                            localNote.alertAction = action
                            localNote.alertBody = what[randomize ? Int(arc4random_uniform(UInt32(what.count))) : i % what.count]
                            localNote.userInfo = ["tag" : tag]
                            localNote.soundName = "drink.caf"
                            let offset = (NSTimeInterval(arc4random_uniform(UInt32(range))) - (NSTimeInterval(range/2))) * 60
                            localNote.fireDate = futureDate.dateByAddingTimeInterval(offset)
                            localNote.timeZone = NSTimeZone.defaultTimeZone()
                            if prebook < 0 {
                                localNote.repeatInterval = .WeekOfYear
                                localNote.repeatCalendar = calendar
                            }
                            application.scheduleLocalNotification(localNote)
                            date = futureDate
                        }
                    }
                }
        }
    }

	func scheduleReminders() {
		let application = UIApplication.sharedApplication()
		let interval = NSUserDefaults.standardUserDefaults().integerForKey(PartyUpPreferences.RemindersInterval)

		if let notes = application.scheduledLocalNotifications {
			for note in notes {
				if note.userInfo?["reminder"] != nil {
					application.cancelLocalNotification(note)
				}
			}
		}

		if NSUserDefaults.standardUserDefaults().boolForKey(PartyUpPreferences.RemindersInterface) {
			var minutes = [Int]()
			if interval > 0 { minutes.append(0) }
			if interval == 30 { minutes.append(30) }

			let now = NSDate()
			let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
			let relative = NSDateComponents()
			relative.calendar = calendar
			relative.timeZone = NSTimeZone.defaultTimeZone()

			for minute in minutes {
				relative.minute = minute
				let future = calendar.nextDateAfterDate(now, matchingComponents: relative, options: .MatchNextTime)
				let localNote = UILocalNotification()
				localNote.alertAction = NSLocalizedString("submit a video", comment: "Reminders alert action")
				localNote.alertBody = NSLocalizedString("Time to record a party video!", comment: "Reminders alert body")
				localNote.userInfo = ["reminder" : interval]
				localNote.soundName = "drink.caf"
				localNote.fireDate = future
				localNote.repeatInterval = .Hour
				localNote.repeatCalendar = calendar
				localNote.timeZone = NSTimeZone.defaultTimeZone()
				application.scheduleLocalNotification(localNote)
			}
		}
	}
}

