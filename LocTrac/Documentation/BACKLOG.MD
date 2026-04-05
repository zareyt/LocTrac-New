LocTrac Dev prompts


Backlog Features and Bugs


Bug- Trip Journey
- [ ] Where do trip journeys pull there GPS coordinates from?  Location or event.  What if a user changes a location gps does all the events reflect that change?

Bug - calendar
- [ ] On selection of different Mon year, toggling between people activity and locations don’t refresh until move to different month 

Bug - infographics
- [ ] Location count should not count “Other” in infographics overview locations count.  People should be unique

Bug - color picker
- [ ] Color picker only allows strong color selection, this is standard iOS feature and not a bug, no change in code.



Feature - Add Affirmation activity
- [ ] Add a Affirmation activity that allows users to implement multiple affirmations selection within.  User will have ability to select 1 or more on event update or creation.

Feature - Add states to Locations
- [ ] States are not currently being stored in locations and other entries.  Use geo coding when adding or manual entry. 



Feature - Home Screen  revamp
- [ ] I would to rework the home view remove recent stays, top locations should be rolling 12 mo.  Change other cities to Vacation places and make rolling 12 months top 5.  Add Environment impact highlights. Remove Today and upcoming events. Change Add Event button to Add Stay, remove Add location, add Travel Map, Infographics with links to those tabs.  Add people section highlighting top 5 people spent time with rolling 12 months.

Feature - Infographics vacation section
- [ ] I would like to add a new section for vacations in infographics.  This will be based on information using data from “Other” location.  Unique places, countries, trips, and anything else relaxant that you could suggest that might be interesting 

Feature - Adding default person to stays
- [ ] I want to create a utility the lets me select a name from my contacts and update events for a given time from with that Person to each stay.  Error check if that person already exists ignore the update.

Feature - Car usage
- [ ] I want to be able to have my car mileage impacts incorporated into the infographics environmental impacts section.  Field for total miles per year, car type model epa rating, etc, type electric/hybrid/gas/diesel.  

Feature - Integration with Apple fitness.  
- [ ] I want to creat an interface into Apple HealthKit to extract exercise entry to activity and minutes, also extract biking exercise and miles.  New fields will have to be created to store these extra fields and displayed in infographics activities section. 


Feature - User/Account
- [ ] I would like to make the a more publishable application that has current user capabilities Username and password, profile, preferences, etc.  The login functionality should allow user to create their own id’s using an email address, Apple ID or Google ID, 2 factor authentication, biometrics, account email verification.

Feature - Batch updates to new entries
- [ ] When entering a new stay, I want to be able to have the stay span over several days for the location, activities and people.  Can you help me review the Enter new stay screen to accommodate this

Version 1.3
Feature - Add Readme, changelog and License to About Loctrac menu
- [ ] Add  Readme, changelog and License files to about LocTrac view with buttons to read each. Up first launch of a new version a popup should present user with option to few new changes.
Feature - auto create Other as part of Wizard setup 
- [ ] Need to revamp and upgrade the Backup & Import menu.  The menu option “Select Backup from File” change to “Import from Backup File” and description “Browse iCloud Drive or On My iPhone” -> “Select backup file to Import”.  The import view should give option to select a file from the list of backups listed on the Backup & Import view or select one from the Files app.  The import functionality should allow the user to preview and using a timeline slide bar select any period of to to restore from.  The import should only then import the data within the timeframe selected.
- [ ] Change title box “Backup Your Data”-> “Backup your Data and Import Data” “• Export all locations, events, and activities” append Import data from your backup.  All or selected timefram”
- [x] The location of “Other” needs to be created upon first time run initiation.  The app is dependent on having this Location to handle non stay events 

Version 1.2
Feature - Travel History (1.2)
- [ ] HOLD- Now that we solved country in EventCountryUpdaterView,  this should also be applied when entering a new event stay with Location = other, so all new entries will have country populated, also need to incorporate adding state as well, both in utility and for new entries also getting runtime error No symbol named 'mappin.circle.badge.plus' found in system symbol set
- [x] is there a geocoding function we can use to update the country field in the event stays? this would eliminate the "unknown" when alot of the cities have the city name, country or city name, state if it's in the USA in the city name (ie, "Caen, France", "Castle Rock, CO") 

Bug-Unknown Trip
- [x] If a user updates an existing location with new gps coordinates, does all the previous location event stays for that location get updated or do those events reference from the Location?
- [x] When a new trip is created a popup should come up asking for the transportation mode and any comments.  The transportation mode should still default to the type based on distance like it does not but allowing user to override it.
- [x] A new trip should automatically be created when a user enters a new event stay that is different than the previous day.  Likewise if an event stay is deleted it should check it affects a trip (ie its location was different than the previous day).
- [x] Trip refresh should only exclude type of trip (ie Train) and notes when comparing if a change is made.  There should also be an toggle to exclude a change, delete or add to be made.
- [x] There are a couple trips that have Unknown as a destination or origination and I can edit them.  They were caused by a blank stay entry which I have since corrected but need to be able to handle these and either error thrown or ability to add a stay.  There should be an option to refresh trips to with option to replace existing trips only if there is a change and select which trip to save.  Similar to how the Golfshot utility works.

Version 1.1
Feature - Travel History (1.1)
- [x] There used to be an “Other Locations” menu view that displays all the other locations and date traveled.  I would like to use that or create a new view in the menu that is modeled similar to Mane Location views but based on country, star ñ, Ciry field that could have multiple stays under them. I like the ABC A-Z, Most Used, country filters similar to Manage locations view.

Feature - Location CRUD (1.1)
- [x] Integrate the existing “Default Location” menu option into manage trips view, this is now redundant given the new manage trips.  I like the “Default location view and it’s description and would like to keep that, you can also remove the star default feature next to each location in the manage trip given this new approach.
- [x] Replace “Add Location” menu option with a view “Manage Locations” that allows users to add, update and delete Locations, but not the “Other” location

Version 1.0
Doc Cleanup (1.0)
- [x] •Moved all documentation to Documents Folder

Potential consolidation (4.2)
- [x] •I now have both InfographicsCacheManager (persistent actor) and InfographicsCache (in-memory ObservableObject). If that’s intentional (e.g., warm in-memory cache + persisted backing store), great — otherwise, we can unify or layer them cleanly to reduce maintenance.

Import Golfshot Utility (4.1)
- [x] I want to build an import utility to load data from my Golfshot app which I use to capture rounds of golf.  The utility to should update an event stay of the day of the golf ground and set the activity to golf, and put the name of the golf course in the notes.  The utility should prompt for an input file that is in .cvs format.  The field layout of the file should be in Round DateTime (UTC) (ie  9/19/2024 10:37:58 AM), Facility name (import to Notes). The data should start on row 1.  The import should report how many entries were added and general error handling. Add the to the main menu under Utilities folder.amd mine Backups and export too.  

Main Screen (4.x)
- [x] I would like to have a main screen that is a little more user friendly when entering the application.   The app should start here instead of locations tab.  THighlighting key information and main features to use in the application. Can you provide some recommendations?

Bug - get location coordinates 
- [x] Get location for lat and long is missing.  It should be available for adding/updating a Location and whenever user selects “Other” on a new stay.

Import and preview backups(4.x)
- [x] When creating a new backup the file is not displayed in the Exported Backups section with an updated count.  Also rename from “Backup & Export” -> “Backup & Import”
- [x] The utility has messed up some of my past data, I need to work on import functionality as part of the of the Backup Export utility.  I need to create an import function the selects from a backup and just copies the selected import file and replaces the existing backups.json file.  Can you add the functionality? I also want to preview the backups I can’t find them on my phone, where are they stored?

Version 3.0
Clean up Infographics
- [x] I want a view that displays trips per year and for all and add a trips section in infographics.  Can we take advantage of update flag for the infographics Journey Map and Environment Impact sections so that it only has to run if there is an update?  Also, instead of automatically calculating the  Journey and Environment impacts, create a button to Refresh only if  there has been an update to the data.  This will improve the speed of the screen and eliminate unnecessary  calculations every time the Infographics tab is opened

Updates to Infographics
- [x] Add Trips Taken to Overview and type of trips (ie Flight, drive, bus, etc).  On the Top locations section changes “visits” to “Days”, Change “Travel Companions” to “People Met/Stayed with” and change “trips” to “days”.  Under “Environmental Impacts” add a carbon footprint rating or score.

Calendar revamp
- [x] I would like to refresh and update the Calendar view to look more user friendly and display a little more information.  Using more standar calendar functions in ios17+ Similar to how the trip update is laid out.  With activities model same as transportation mode, calendar popups, etc.  Also would like a see a filter that defaults to “location” like it does now where a colored dot is displayed on the calendar for location. The filter would also allow select on “activities” and “people”.  Can you provide some recommendations?

Bug- Infographics state count
- [x] I don’t think state count is being calculated correctly, there is one more state being counted than should.  Could location and other that is in the same state be counted as 2 instead of 1?

Bug - system crash infographics
- [x] I want to make sure that we are over geocoding for state for any locations, it seems that we should only do this once and if necessary create a field in the model for state and old calculate for new entries once the have all been migrated.   And this approach should be applied to any other fields in infographics to eliminate unnecessary processing. 
- [x] When entering infographics then current year then previous year the app crashes with Thread 1: EXC_BREAKPOINT (code=1, subcode=0x1c78b7754).  Think of optimizing infographics even more by persisting all the content once it calculates and only recalculating if there is a change to a given year then only that year and total would have to be recalculated and depending on what changed in the data only that section would have to be recalculated.  For example if 1 activity was changed only the Top Activities section would have to be updated not all of the other sections.

Locations management
- [x] Create a menu to manage locations with same look and feel as trip management.  Allow user to set 1 location as the default.  That default should be selected when adding a new event stay.  The location. Can also still be managed from selecting location from the map view

Trip Errors
- [x] Getting errors /Users/timarey/Documents/Development/SwiftUI/Projects/LocTrac/LocTrac/Views/ListView Tab/TripFormView.swift:233:25 Type 'Event.EventType' has no member 'staycation' /Users/timarey/Documents/Development/SwiftUI/Projects/LocTrac/LocTrac/Views/ListView Tab/TripFormView.swift:228:21 Type 'Theme' has no member 'blue'

￼


