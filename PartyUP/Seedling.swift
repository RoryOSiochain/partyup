//
//  Seedling.swift
//  PartyUP
//
//  Created by Fritz Vander Heide on 2016-07-02.
//  Copyright © 2016 Sandcastle Application Development. All rights reserved.
//

import Foundation
import FBSDKCoreKit
import CoreLocation
import SwiftDate
import SwiftyJSON
import Alamofire

extension Venue {
	func fetchSeedlings() {
        func pack(item item: JSON, source: String = "source", time: String = "updated_time", comment: String = "description", alias: String = "from", stale: NSDate = 7.days.ago) -> Seedling? {
            guard let source = item[source].string.flatMap({ NSURL(string: $0) }),
                let time = item[time].string.flatMap({ $0.toDate(DateFormat.ISO8601Format(.Full)) }) where time > stale else { return nil }
			let comment = item[comment].string
			let alias = item[alias]["name"].string
            
            return Seedling(user: NSUUID(), alias: alias, event: self, time: time, comment: comment, media: source, via: "Facebook")
        }

		let defaults = NSUserDefaults.standardUserDefaults()
		var fields = String()

        let video = defaults.integerForKey(PartyUpPreferences.SeedFacebookVideo)
        if video > 0 {
            fields += "videos.limit(\(video)){source,description,from,updated_time}"
        }
        let broad = defaults.integerForKey(PartyUpPreferences.SeedFacebookBroadcast)
        if broad > 0 {
            fields += fields.isEmpty ? "" : ","
            fields += "video_broadcasts.limit(\(broad)){video{source,description,from,updated_time}}"
        }
        let timeline = defaults.integerForKey(PartyUpPreferences.SeedFacebookTimeline)
        if timeline > 0 {
            fields += fields.isEmpty ? "" : ","
            fields += "albums.limit(1){photos.limit(\(timeline)){source,name,from,updated_time}}"
        }
        let stale = defaults.integerForKey(PartyUpPreferences.SeedStaleInterval).seconds.ago
        
		if let token = FBSDKAccessToken.currentAccessToken() {
			Alamofire.request(.GET,
			                  NSURL(string: "search", relativeToURL: FacebookConstants.GraphApiHost)!, parameters: ["q":name,"type":"place","center":"\(location.coordinate.latitude),\(location.coordinate.longitude)","distance":"\(100)","fields":"link","access_token":token.tokenString]).responseJSON { response in
					switch response.result {
					case .Success(let data):
						let places = JSON(data)
						if let id = places["data"][0]["id"].string {
							Alamofire.request(.GET,
								NSURL(string: id, relativeToURL: FacebookConstants.GraphApiHost)!, parameters: ["fields":fields,"access_token":token.tokenString]).responseJSON(queue: dispatch_get_main_queue()) { response in
									var seeders = [Seedling]()
									switch response.result {
									case .Success(let data):
										let page = JSON(data)
										for cast in page["video_broadcasts"]["data"].arrayValue {
											let video = cast["video"]
                                            if let seed = pack(item: video, stale: stale) {
												seeders.append(seed)
											}
                                        }
                                        for photo in page["albums"]["data"][0]["photos"]["data"].arrayValue {
                                            if let seed = pack(item: photo, comment: "name", stale: stale) {
                                                seeders.append(seed)
                                            }
                                        }
										for video in page["videos"]["data"].arrayValue {
                                            if let seed = pack(item: video, stale: stale) {
												seeders.append(seed)
											}
										}
									case .Failure(let error):
										print("Error fetching movies: \(error)")
									}

									self.seeds = seeders
							}
                        } else {
                            self.seeds = [Seedling]()
                        }
					case .Failure(let error):
						print("Error fetching places: \(error)")
						self.seeds = [Seedling]()
					}
			}
		} else {
			self.seeds = [Seedling]()
		}
	}
}

class Seedling: Tastable {
	let user: NSUUID
	let alias: String?
	unowned let event: Venue
	let time: NSDate
	let comment: String?
	let media: NSURL
    let via: String

    init(user: NSUUID, alias: String?, event: Venue, time: NSDate, comment: String?, media: NSURL, via: String = "Facebook") {
		self.user = user
		self.alias = alias
		self.event = event
		self.time = time
		self.comment = comment
		self.media = media
        self.via = via
	}
}

