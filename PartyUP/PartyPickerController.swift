//
//  PartyPickerController.swift
//  PartyUP
//
//  Created by Fritz Vander Heide on 2015-09-15.
//  Copyright © 2015 Sandcastle Application Development. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import SwiftLocation
import CoreLocation
import UIImageView_Letters
import JGProgressHUD

class PartyPickerController: UITableViewController, UISearchResultsUpdating, UISearchBarDelegate {

	private var filteredVenues: [Venue]? {
		didSet {
			partyTable.reloadData()
		}
	}

	var venues: [Venue]? {
		didSet {
			filteredVenues = venues
			self.refreshControl?.endRefreshing()
		}
	}

	private var searchController: UISearchController!
	private let progressHud = JGProgressHUD(style: .Light)

	private var lastLocation = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), altitude: -1, horizontalAccuracy: -1, verticalAccuracy: -1, course: -1, speed: -1, timestamp: NSDate(timeIntervalSinceReferenceDate: 0))

	@IBOutlet var partyTable: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

		searchController = UISearchController(searchResultsController: nil)
		searchController.searchResultsUpdater = self
		searchController.searchBar.delegate = self
		searchController.dimsBackgroundDuringPresentation = false
		searchController.hidesNavigationBarDuringPresentation = false
		searchController.searchBar.sizeToFit()
		searchController.searchBar.searchBarStyle = .Minimal
		tableView.tableHeaderView = searchController.searchBar
		definesPresentationContext = true

		progressHud.textLabel.text = "Fetching Venues"
		progressHud.showInView(view, animated: true)

		fetchPartyList()
    }

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	@IBAction func fetchPartyList() {
		do {
			try SwiftLocation.shared.currentLocation(.City, timeout: 30,
				onSuccess: { (location) in dispatch_async(dispatch_get_main_queue()) { self.updatePartyList(location!) } },
				onFail: { (error) in
					presentResultHud(self.progressHud, inView: self.view, withTitle: "Undetermined Location", andDetail: "Location services failure.", indicatingSuccess: false)
					})
		} catch {
			refreshControl?.endRefreshing()
			presentResultHud(progressHud, inView: view, withTitle: "Undeterined Location", andDetail: "Location services failure.", indicatingSuccess: false)
		}
	}

	func updatePartyList(location: CLLocation) {
		if location.distanceFromLocation(lastLocation) > 100 || location.timestamp.timeIntervalSinceDate(lastLocation.timestamp) > 60 {
			if let categories = NSUserDefaults.standardUserDefaults().stringForKey(PartyUpPreferences.VenueCategories) {
				let radius = "\(NSUserDefaults.standardUserDefaults().integerForKey(PartyUpPreferences.ListingRadius))"
				let params = ["ll" : "\(location.coordinate.latitude),\(location.coordinate.longitude)",
					"radius" : radius,
					"client_id" : FourSquareConstants.identifier,
					"client_secret" : FourSquareConstants.secret,
					"categoryId" : categories,
					"v" : "20140118",
					"intent" : "browse",
					"limit" : "50"]

				

				Alamofire.request(.GET, "https://api.foursquare.com/v2/venues/search", parameters: params)
					.validate()
					.responseJSON { response in
						if response.result.isSuccess {
							var vens = [Venue]()
							let json = JSON(data: response.data!)
							for venue in json["response"]["venues"].arrayValue {
								vens.append(Venue(venue: venue))
							}

							dispatch_async(dispatch_get_main_queue()) {self.venues = vens; self.lastLocation = location; self.progressHud.dismissAnimated(true) }
						} else {
							dispatch_async(dispatch_get_main_queue()) { self.refreshControl?.endRefreshing();
							presentResultHud(self.progressHud, inView: self.view, withTitle: "Venue Fetch Failed", andDetail: "The venue query failed.", indicatingSuccess: false)
							}
						}
				}
			}
		} else {
			refreshControl?.endRefreshing()
		}
	}

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredVenues?.count ?? 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("PartyPooper", forIndexPath: indexPath)
        cell.textLabel!.text = filteredVenues?[indexPath.row].name ?? "Mysterious Venue"
		cell.detailTextLabel!.text = filteredVenues?[indexPath.row].details
		cell.imageView?.bounds = CGRect(x: 0, y: 0, width: 50, height: 50)
		cell.imageView?.setImageWithString(cell.textLabel!.text, color: UIColor.orangeColor(), circular:  true)

        return cell
	}

	func searchBarCancelButtonClicked(searchBar: UISearchBar) {
		searchController.searchBar.searchBarStyle = .Minimal
		filteredVenues = venues
	}

	func updateSearchResultsForSearchController(searchController: UISearchController) {
		if let searchString = searchController.searchBar.text where searchController.active {
			searchController.searchBar.searchBarStyle = .Prominent
			filteredVenues = venues?.filter{ $0.name.rangeOfString(searchString, options: .CaseInsensitiveSearch) != nil }
		}
	}

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "Sample Tasting Segue" {
			if let selection = partyTable.indexPathForSelectedRow, party = filteredVenues?[selection.row] {
				let viewerVC = segue.destinationViewController as! SampleTastingContoller
				viewerVC.partyId = party.unique
				viewerVC.title = party.name
			}
		}
    }
}
