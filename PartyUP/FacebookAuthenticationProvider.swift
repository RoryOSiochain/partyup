//
//  FacebookAuthenticationProvider.swift
//  PartyUP
//
//  Created by Fritz Vander Heide on 2016-04-17.
//  Copyright © 2016 Sandcastle Application Development. All rights reserved.
//

import FBSDKCoreKit
import FBSDKLoginKit
import KeychainAccess
import AWSCore


class FacebookAuthenticationProvider: NSObject, AuthenticationProviding {
	var name: String { return "Facebook" }
	var logo: UIImage? { return UIImage(named: "Facebook White") }
	var color: UIColor { return UIColor(r: 59, g: 89, b: 152, alpha: 255) }

    required init(keychain: Keychain) {
		self.keychain = keychain
		self.loginManager = FBSDKLoginManager()
	}

	var isLoggedIn: Bool {
		return wasLoggedIn && FBSDKAccessToken.currentAccessToken() != nil
	}

	var wasLoggedIn: Bool {
		return keychain[provider] != nil
	}

	func loginFromViewController(controller: UIViewController, completionHander handler: LoginReport) {
		if FBSDKAccessToken.currentAccessToken() != nil {
			completeLoginWithError(nil, completionHandler:  handler)
		} else {
			loginManager.logInWithReadPermissions(["public_profile"], fromViewController: controller) { (result: FBSDKLoginManagerLoginResult!, error : NSError!) in
				self.completeLoginWithError(error, completionHandler:  handler)
			}
		}
	}

	func logout() {
		loginManager.logOut()
		keychain[provider] = nil
	}

    func resumeSessionWithCompletionHandler(handler: LoginReport) {
		if isLoggedIn {
			completeLoginWithError(nil, completionHandler: handler)
		}
	}

	// MARK: - Application Delegate Integration

	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		return FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
	}

	func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {
		return FBSDKApplicationDelegate.sharedInstance().application(application, openURL: url, sourceApplication: sourceApplication, annotation: annotation)
	}
    
    // MARK: - AWS Identity Provider
    
    var identityProviderName: String {
        return uri
    }
    
    func token() -> AWSTask {
        if let token = FBSDKAccessToken.currentAccessToken() {
            return AWSTask(result: token.tokenString)
        }
		else {
			return AWSTask(result: nil)
		}
    }

	// MARK: - Private

	private var provider: String { return "Facebook" }
	private var uri: String { return "graph.facebook.com" }

	private func completeLoginWithError(error: NSError?, completionHandler handler: LoginReport) {
		if FBSDKAccessToken.currentAccessToken() != nil {
			keychain[provider] = "YES"
			handler(error)
		} else {
			handler(error)
		}
	}

	private let keychain: Keychain
	private let loginManager: FBSDKLoginManager
}