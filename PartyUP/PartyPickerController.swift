//
//  PartyPickerController.swift
//  PartyUP
//
//  Created by Fritz Vander Heide on 2015-09-15.
//  Copyright © 2015 Sandcastle Application Development. All rights reserved.
//

import UIKit
import Flurry_iOS_SDK
import CoreLocation

class PartyPickerController: UITableViewController, UISearchResultsUpdating, UISearchBarDelegate {

	static let VenueRefreshRequest = "VenueListRefreshRequest"

	private struct PartySections {
		static let animal = 0
		static let venue = 1
	}

	private var venues: [Venue]? {
		didSet {
            venues?.sortInPlace{ $0.promotion?.placement > $1.promotion?.placement }
			partyTable?.reloadData()
		}
	}

	private var venueTotal = 0

	var parties: PartyPlace? {
		didSet {
			if parties !== oldValue || parties?.venues.count > venueTotal {
				updateSearchResultsForSearchController(searchController)
				venueTotal = parties?.venues.count ?? 0

				if parties !== oldValue {
					partyTable?.setContentOffset(CGPointZero, animated: false)
				}

				if let parti = parties, avc = navigationController?.topViewController as? SampleTastingContoller
					where !parti.isFetching && avc.venues == nil {
					avc.venues = venues
				}
			}

			refreshControl?.endRefreshing()
		}
	}

	private var freshTimer: NSTimer?
	private var searchController: UISearchController!

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

		freshTimer = NSTimer.scheduledTimerWithTimeInterval(60, target: self, selector: Selector("updateFreshnessIndicators"), userInfo: nil, repeats: true)

		let nc = NSNotificationCenter.defaultCenter()
		nc.addObserver(self, selector: Selector("observeApplicationBecameActive"), name: UIApplicationDidBecomeActiveNotification, object: nil)
		nc.addObserver(self, selector: Selector("observeApplicationBecameInactive"), name: UIApplicationDidEnterBackgroundNotification, object: nil)
		nc.addObserver(self, selector: Selector("updatePromotions:"), name: Venue.PromotionUpdateNotification, object: nil)
    }

	deinit {
		freshTimer?.invalidate()
	}

	func observeApplicationBecameActive() {
		freshTimer = NSTimer.scheduledTimerWithTimeInterval(60, target: self, selector: Selector("updateFreshnessIndicators"), userInfo: nil, repeats: true)
		updateFreshnessIndicators()
	}

	func observeApplicationBecameInactive() {
		freshTimer?.invalidate()
	}

	@IBAction func updateLocalVenues() {
		NSNotificationCenter.defaultCenter().postNotificationName(PartyPickerController.VenueRefreshRequest, object: self)
	}

	func updateFreshnessIndicators() {
		partyTable.visibleCells.forEach { ($0 as? PartyTableCell)?.updateVitalityTime() }
	}

	func updatePromotions(note: NSNotification) {
		let oldPlace = (note.userInfo?["old"] as? Promotion)?.placement ?? 0
		if let what = note.object as? Venue, locals = venues {
			var src: Int?
			var dst: Int?
			let whatPlace = what.promotion?.placement ?? 0
			if oldPlace != whatPlace {
				for (index, venue) in locals.enumerate() {
					if venue == what {
						src = index
					} else if dst == nil && (venue.promotion?.placement) ?? 0 <= whatPlace {
						dst = index - (src != nil ? 1 : 0)
					}

					if src != nil && dst != nil {
						break
					}
				}

				if let src = src, dst = dst where src != dst {
					venues?.removeAtIndex(src)
					venues?.insert(what, atIndex: dst)
					partyTable.moveRowAtIndexPath(NSIndexPath(forRow: src, inSection: 1), toIndexPath: NSIndexPath(forRow: dst, inSection: 1))
				}
			}
		}
	}

    // MARK: - Table view data source

	override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return section == PartySections.animal ? parties?.place.locality : NSLocalizedString("Party Places", comment: "Header for Venues list in  the primary table")
	}

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return section == PartySections.animal ? 2 : venues?.count ?? 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		var cell: PartyTableCell
		if indexPath.section == PartySections.venue {
			cell = tableView.dequeueReusableCellWithIdentifier("PartyPooper", forIndexPath: indexPath) as! VenueTableCell
			if let venue = venues?[indexPath.row] {
				cell.title = venue.name
				cell.venues = [venue]
			}
		} else {
			cell = tableView.dequeueReusableCellWithIdentifier("PartyAnimal", forIndexPath: indexPath) as! AnimalTableCell
			switch indexPath.row {
			case 0:
				cell.title = NSLocalizedString("All Party Videos", comment: "All venues cell title prefix")
				cell.venues = venues
			case 1:
				cell.title = NSLocalizedString("Pregame Party Videos", comment: "Pregame cell title prefix")
				if let pregame = parties?.pregame {
					cell.venues = [pregame]
				} else {
					cell.venues = nil
				}
			default:
				cell.title = "Your shouldn't see this"
				cell.venues = nil
			}
		}
		return cell
	}

	// MARK: - Search

	func cancelSearch() {
		searchController.active = false
		searchBarCancelButtonClicked(searchController.searchBar)
	}

	func defocusSearch() {
		if searchController.searchBar.isFirstResponder() {
			searchController.searchBar.resignFirstResponder()
		}
	}

	func searchBarCancelButtonClicked(searchBar: UISearchBar) {
		if let searchString = searchBar.text {
			Flurry.logEvent("Venues_Filtered", withParameters: [ "search" : searchString])
		}
		searchBar.searchBarStyle = .Minimal
		updateSearchResultsForSearchController(searchController)
	}

	func updateSearchResultsForSearchController(searchController: UISearchController) {
		if let searchString = searchController.searchBar.text where searchController.active {
			searchController.searchBar.searchBarStyle = .Prominent
			venues = parties?.venues.filter{ $0.name.rangeOfString(searchString, options: .CaseInsensitiveSearch) != nil }
		} else {
            venues = parties.flatMap{Array($0.venues)}
		}
	}

    // MARK: - Navigation

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if let selection = (sender as? UITableViewCell).flatMap( {partyTable.indexPathForCell($0)} ) {
			if let viewerVC = segue.destinationViewController as? SampleTastingContoller {
				switch (selection.section, selection.row) {
				case (PartySections.venue, let row):
					viewerVC.venues = (venues?[row]).map { [$0] } ?? []
                    viewerVC.ads = (venues?[row]).flatMap { $0.ads } ?? []
					Flurry.logEvent("Venue_Videos", withParameters: ["venue" : venues?[row].name ?? "Mystery Venue"])
				case (PartySections.animal, 0):
					if let parti = parties where !parti.isFetching {
						viewerVC.venues = venues
					}
                    viewerVC.ads = parties?.ads ?? []
					Flurry.logEvent("Venue_Videos", withParameters: ["venue" : parties?.place.locality ?? "All"])
				case (PartySections.animal, 1):
					viewerVC.venues = (parties?.pregame).map { [$0] } ?? []
                    viewerVC.ads = (parties?.pregame).flatMap { $0.ads } ?? []
					Flurry.logEvent("Venue_Videos", withParameters: ["venue" : parties?.pregame.name ?? "Pregame"])
				default:
					viewerVC.venues = nil
					Flurry.logError("Invalid_Party_Selection", message: "An invalid selection was made in the party picking table", error: nil)
				}
			}
		}
	}

	@IBAction func segueFromTasting(segue: UIStoryboardSegue) {
		Flurry.logEvent("Returned_From_Tasting")
	}
}
