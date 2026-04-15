LocTrac Dev prompts
Date Apr, 14, 2026

Backlog Features and Bugs

⚠️ BUGS
⚠️Bug- Travel History Location jumping 
- [ ] See CLAUDE.md  @TravelHistoryView When Selecting Location expand it sometimes readjusts the order of the location.  These should be fixed with the most event stays per location starting at top, no jumping after expanding or collapsing..

⚠️Bug- Notifications not displaying missing event
- [ ] See CLAUDE.md  Stay Reminder Notification not properly alerting user that they are missing an entry for the current day.


🔧 FEATURES
🔧Feature - Environmental Factors menu view
- [ ] See CLAUDE.md Create a menu item for managing environmental impacts.  Option to remove trains and buses from environment impact calculations for public transportation, I want to be able to have my car mileage impacts incorporated into the infographics environmental impacts section.  Field for total miles per year, car type model epa rating, etc, type electric/hybrid/gas/diesel, add variable CO2 per mile for each car.  The type of car should impact the environmental impacts section.  Dates range car was used that should be applied to env calculations for any driving trips during that timeframe. Current car should be applied to any new trip if driving is selected.  Create a new menu optional “Environmental Factors” and create a manage car for Create, Update and delete. 

🔧Feature - Location Pictures should be imported and exported
- [ ] See CLAUDE.md when exporting and importing an option should be allowed for Location Pictures.

🔧Feature - add Claude to app
- [ ] See CLAUDE.md Add a Claude interface to LocTrac so users can ask questions about events, trips, activity, people.  Create all necessary views and api integrations to Claude. [prerequisite - User id, profile]

🔧Feature - Adding default person to stays
- [ ] See CLAUDE.md I want to create a utility the lets me select a name from my contacts and update events for a given time from with that Person to each stay.  Error check if that person already exists ignore the update.

🔧Feature - Activities display 
- [ ] See CLAUDE.md when adding or updating an event there too many activities (10) and takes up a lot of visual space need better UI approach using best practices for this.

🔧Feature - Car usage
- [ ] See CLAUDE.md I want to be able to have my car mileage impacts incorporated into the infographics environmental impacts section.  Field for total miles per year, car type model epa rating, etc, type electric/hybrid/gas/diesel.  The type of car should impact the environmental impacts section.  Current car should be applied to any new trip if driving is selected.  Create a new menu optional “Environmental Factors” and create a manage car for Create, Update and delete. 

🔧Feature - Integration with Apple fitness.  
- [ ] See CLAUDE.md I want to create an interface into Apple HealthKit to extract exercise entry to activity and minutes, also extract biking exercise and miles.  New fields will have to be created to store these extra fields and displayed in infographics activities section.  Exercise activity may need a more complex supporting data model.

🔧Feature - User/Account
- [ ] See CLAUDE.md I would like to make the a more publishable application that has current user capabilities Username and password, profile, preferences, etc.  The login functionality should allow user to create their own id’s using an email address, Apple ID or Google ID, 2 factor authentication, biometrics, account email verification.  I want the user id tied to backup.jason and not carried through all the data models.  However I want the ability for someone to import another’s backup files I theirs.  Each user should have a standard profile with option to reset password, turn certain features on/off Affirmations, Activity and People

🔧Feature - Batch updates to new entries
- [ ] See CLAUDE.md When entering a new stay, I want to be able to have the stay span over several days for the location, activities and people.  Can you help me review the Enter new stay screen to accommodate this

Planned for Future
* Date range filtering in Travel History
* Calendar heat map visualization
* Enhanced photo galleries
* Travel timeline view
* More statistics and analytics
🔧 Ideas for Version 2.0
* iCloud sync across devices
* Apple Watch companion app
* Advanced trip planning
* Travel goals and achievements
* Social sharing features

⚠️ RELEASES
Version 1.5
🔧Feature - Enhance Data Add state and Country to Locations (version 1.5)
- [x] See CLAUDE.md Evaluate my data models for country, state and city for international use.  Ability to add states in US, providences in Canada, etc.  Recommend implantation approach to modify models and how to clean up and populate existing data for a user.  Use geo coding when adding or manual entry and migration utility. Some Existing data has cities entries with “City Name, [State Name or Country names].  Utility should only retain the city name for city and then populate state and country or whatever the best practice is.
🔧Feature - Add Debug framework and option (version 1.5)
- [x] See CLAUDE.md I want to start using a best practice debugging approach that I can turn on/off from the menu and sections,views should show view name in italics on botton of screen when turned on.  Can you look at claude.md and project analysis to come up with some best practices approaches ?
🔧Feature - assess and validate time approach (version 1.5)
- [x] See CLAUDE.md, use debug feature to review, assess and validate my approach to how the application uses time.  The fundamental approach has always been capturing the date when a location was entered was the priority.  Any use of actual timestamps is challenging and I don’t think necessary.  Given that this is primary a travel location based app timezones, and flying across time zone can cause issues, entering data in one time zone and then viewing in another can cause problems in the past which I think I have addressed with current approach. There is currently a date mismatch bug when entering a new event.  When I edit an event for Apr 11, Edit Event is displayed but it shows Apr 10, 6:00pm.  
- [x] Need to pick this conversation back up.  we have eliminated alot of the issues by ignoring time stamp.  The key is this is working correctly in Travel history drilling down to an event and opening it displays the correct date.  However when I edit a calendar event entry it shows the current day-1 instead of the current day When I edit an event for Apr 11, Edit Event is displayed but it shows Apr 10, 6:00pm.  .  Use debugging switch to help narrow down.
🔧Feature - Flexible “What’s New” (version 1.5)
- [x] See CLAUDE.md Currently we have a list of what’s new in the current release.  Nah major feature is displayed on a page and progress through pages for each new major feature.  This is hard coded in the @WhatsNewFeature.swift.  I want to make this more flexible and dynamic.  There should be a process that looks for information in VERSION_x.x_RELEASE_NOTES.md and BACKLOG RELEASES x.x and “(Version x.x) eg. x.x = 1.5
🔧Feature - add Home view updates (version 1.5)
- [x] See CLAUDE.md @HomeView move Notifications to Menu top right. Remove quick links. Only display 3 Top affirmatioms, but make expandable to see all.  Same with People.  Add top 3 activities section and make expandable to all.  Apply same to Top vacation places and remove link to travel history. Change Top locations to Locations, change link to Location map to a link to manage locations view.
🔧Feature - add Location Pictures (version 1.5)
- [x] See CLAUDE.md under Manage Location @LocationsManagementView  view should show me an option to view, add and delete pictures.  Use the same code in @LocationDetailView
🔧Feature - travel history navigation for locations. (version 1.5)
- [x] See CLAUDE.md travel history “Other” location is displayed on each event stay remove from each stay it’s redundant and always “Other”
- [x] See CLAUDE.md travel history locations filter should be sorted by year and month as collapsible.  Some locations have over 400 event stays and it’s too much to scroll through without better user navigation.  The other view is fine and no changes necessary.

⚠️Bug- Manage Trips change Other(version 1.5)
- [x] See CLAUDE.md  @TripsManagementView When viewing trips if a location = “Other” instead of displaying “Other” use City Name.  
⚠️Bug- Manage Trips change Other (version 1.5)
- [x] See CLAUDE.md @OrphanedEventsAnalyzerView. We are picking up from previous conversation where it It appears these are all duplicates but on the day before they are actually supposed to be. For Example There is a Apr 2, 2022 event "Unknown" Chicago, United States,with note "Went with Catherine's team to look at mental health coffee shops".  But it the correct data there is an event stay for Apr3, 2022, Chicago, IL, United States,with note "Went with Catherine's team to look at mental health coffee shops"..  I would like to use this example to double check alll these errors have a corresponding event that is a day+1.  If the have a duplicate toggle for deletion, if not I'll use to make sure no data is lost.  The logic is not quite right here the example I gave of Apr 2, 2022 event "Unknown" Chicago, United States,with note "Went with Catherine's team to look at mental health coffee shops" says there is a duplicate of Apr 5, 2022 city Loft.  The logic is off by one day, should compare against Apr3, 2022 and the logic to determine if it is a duplicate is wrong.  It should compare against city AND Note fields.  I can't see State and Country, please add those fields and then I'll determine if they can be used to compare for dups see ORPHANED_EVENTS_IMPORT_FIX. Root cause a Merge Import brought in another “Other” location ID instead of replacing it causing orphaned events and also corrected import of local time vs standardized time.
⚠️Bug- Location Color(version 1.5)
- [x] See CLAUDE.md  After changing Location color not being propagated in the calendar
⚠️Bug- Backup and import causes “City” field to be imported as Unknown (version 1.5)
- [x] See CLAUDE.md  as part of our Country Standardization changes to data model has appeared to caused the City name to be imported as unknown.
⚠️Bug- Edit other event coordinates (version 1.5)
- [x] See CLAUDE.md  on Edit event @ModernEventsCalendarView. when Location = “Other”. The latitude and longitude and “Get coordinates” should be displayed.  The same as when adding a new Other event stay.



Version 1.4
🔧Feature - Notifications (version 1.4)
- [x] See CLAUDE.md, update Release notes, Claude whatsnewfeature.swift, this is part of v1.4 updates and features.  Enable apple notifications, update stay, activities and people.  Catch up on stays if one isn’t entered for current day or past days. Notification Requirements
    •    The app should include an optional daily notification
    •    The notification must:
    •    Be sent once per day
    •    Be delivered between 12:00 AM and 12:00 PM
    •    Display the same affirmation as the widget
    •    Notification tone should be calm, supportive, and reassuring
    •    Notification is optional and sent once daily with the same message
🔧Feature - Add Readme, changelog and License to About Loctrac menu (version 1.4)
- [x] See CLAUDE.md Add  Readme.md, changelog.md and License.md files to menu “about LocTrac” view with buttons to read each. If first launch of a new version, a popup should present user with option to few new changes.  When a new release is ran for the first time it should display change log new features with a page for each new major feature with a next button to scroll through.  After it’s been displayed once don’t display again.

🔧Feature - Affirmations cleanup  (version 1.4)
- [x] There should be an option to allow user to select import Affirmations and an option to import Affirmation events with the selected date range. After the import it should display how many affirmations and how many affirmation events were imported.
- [x] See CLAUDE.md Import screen shout display the number of Affirmation events to be imported. And Number of actual Affirmations.  The share backup file option does not allow the user to select a specific file to be shared and selects the last backup.
- [x] See CLAUDE.md Import and backup affirmations in events, affirmations should be allowed to be selected as part of imports the same way people and activities.  The actual affirmations themselves should be backed up and imported.
- [x] See CLAUDE.md Add affirmations on iPad popup cuts off Add button, can it be resized!
- [x] See CLAUDE.md Default presets affirmations in @Affirmation should be added in the wizard in @FirstLaunchWizard and allow user to select any of them. 
- [x] See CLAUDE.md Change the menu name to  Manage Activities.  There is no color picker for affirmations, and where and what does the color feature do and presented?  I like how you broke the categories out Relationship, Success, etc.  This presentation should also be used when adding or updating the affirmation

🔧Feature - Revamp Travel history (version 1.4)
- [x] See CLAUDE.md There are over 1000 location entries and 500 Other entries and need to make more user friendly to navigate.  Can we make each location collapsable to hide entries?  Also the Title for each location should be the location name and the subtitle should be the city, country.  The Other screen is correct.  On both location and other views  add an activity, people and affirmation count to each summary and stay events.
- [x] Change All-> Locations and share should recognize filters
🔧Feature - Home Screen  revamp (version 1.4)
- [x] See CLAUDE.md I would to rework the home view remove recent stays, top locations should be rolling 12 mo.  Change other cities to Vacation places and make rolling 12 months top 5.  Add Environment impact highlights. Remove Today and upcoming events. Change Add Event button to Add Stay, remove “Add location”, add Travel Map, Infographics with links to those tabs.  Add people section highlighting top 5 people spent time with rolling 12 months.  Add a randomly selected affirmation as a reminder in its own selection.  Create a new affirmation section highlight top affirmations.

🔧Feature - Infographics vacation section (version 1.4)
- [x] See CLAUDE.md I would like to add a new section for vacations in infographics.  This will be based on information using data from “Other” location.  Unique places, countries, trips, and anything else relaxant that you could suggest that might be interesting.  Also Add share feature to Infographic.  Add a count to the end if each line in graph
- [x] Add share function for infographics view using the filter for all or specific year.

🔧Feature - widget screen (version 1.4)
- [x] See CLAUDE.md Create Widget for application.  Show display highlights.  Widget Functionality
    •    The app must include a home screen widget that displays one affirmation per day
    •    Each affirmation is assigned to a specific day (example: Tuesday → “I am chosen”)
    •    The widget must:
    •    Automatically update at 12:00 AM (midnight) each day
    •    Display the new day’s affirmation
    •    Remain unchanged throughout the entire day
    •    The affirmation should be visible from 12:00 AM to 11:59 PM
    •    The widget should always display only the current day’s affirmation
Widget Behavior. 
    •   The widget is passive and requires no user interaction
    •    Each time the user views their home screen, the same affirmation is displayed
    •    The affirmation does not refresh or rotate during the day
Design Requirements
    •    The design should be minimal, clean, and aesthetically calming
    •    The widget should:
    •    Be easy to read at a glance
    •    Focus on a single affirmation
    •    Avoid clutter or unnecessary elements
Summary
One affirmation per day
    •    Updates at midnight
    •    Remains the same all day
    •    Widget is always visible and non-interactive

⚠️Bug- Home Screen people visit counts wrong (version 1.4)
- [x] See CLAUDE.md here is the output and yet home screen people show 3 stays for Tim Collum, Anthiony Davis, Madison Arey, McKinsey Arey and Mike Chott.  Please change this from stays back to visits.  The log clearly shows there are more than 3 for each of those people 📂 Loading from backup.json.  The log is too big to paste here, please remove "Events on" statements and try to streamling debug so I can paste

⚠️Bug - infographics (version 1.4)
- [x] See CLAUDE.md Location count should not count “Other” in infographics overview locations count.  People should be unique

⚠️Bug - duplicate others (version 1.4)
- [x] See CLAUDE.md when importing data with a merge it creates another “Other” location giving the user 2 Other locations.  Import should avoid creating a duplicate other.

⚠️Bug - share not working (version 1.4)
- [x] See CLAUDE.md Travel history “share” function not working
- [x] The share button doesn’t work in the infographicsview review claude.md for navigation hints. Our conversation keeps getting cut off midway through your responses and I don’t think all of the code changes you were in the middle of completed. It was partially work when Your prompt response was cut off when only part of the infographics pdf was printing out.  you where in the middle of adding everything.  I don’t want a quick fix I want a complete solution. 
- [x] Render journeymap in the the share pdf for @infographicsview

⚠️Bug - color picker (version 1.4)
- [x] See CLAUDE.md The Color picker @LocationsManagementView  “Edit Locations” “Theme Color”only allows vertical color selection any attempt to horizontal forces back to right 1/4 of spectrum.  I want users to be able to select anywhere on the spectrum. 

⚠️Bug - Calendar not refreshing after delete(version 1.4)
- [x] See CLAUDE.md After deleting or adding  an event stay the calendar doesn’t refresh until it’s moved to the next or previous month.  It needs to force refresh after add or delete.

Version 1.3
🔧Feature - Add Affirmation activity (1.3)
- [x] Move manage affirmations to the manage activities view.  Users should be able to add, update and delete affirmations.  When updating an event user should be able to select affirmations.  Currently only when creating a new event.  What does the star next to affirmation mean?
- [x] ✅ Add a Affirmation activity that allows users to implement multiple affirmations selection within including a header and text field for each.  User will have ability to select 1 or more affirmation on event update or creation.  Affirmations should be a perminant activity available in the startup wizard.  These affirmations should be persisted once they are entered and allow to update, modify and delete.  Can you come up with a creative solution for this feature?
🔧Feature - auto create Other as part of Wizard setup (1.3)
- [x] ✅The location of “Other” needs to be created upon first time run initiation.  The app is dependent on having this Location to handle non stay events

🔧Feature - import date range, activities, people (1.3)
- [x] ✅Need to revamp and upgrade the Backup & Import menu.  The menu option “Select Backup from File” change to “Import from Backup File” and description “Browse iCloud Drive or On My iPhone” -> “Select backup file to Import”.  The import view should give option to select a file from the list of backups listed on the Backup & Import view or select one from the Files app.  The import functionality should allow the user to preview and using a timeline slide bar select any period of to to restore from.  The import should only then import the data within the timeframe selected.
- [x] ✅ Add selection of what is to be imported (people, activities, trips, events or a combination of all)
- [x] ✅ Change title box “Backup Your Data”-> “Backup your Data and Import Data” “• Export all locations, events, and activities” append Import data from your backup.  All or selected timeframe”
Bug - calendar
- [x] ✅ On selection of different Mon year, toggling between people activity and locations don’t refresh until move to different month 
Version 1.2
🔧Feature - Travel History (1.2)
- [ ] HOLD- Now that we solved country in EventCountryUpdaterView,  this should also be applied when entering a new event stay with Location = other, so all new entries will have country populated, also need to incorporate adding state as well, both in utility and for new entries also getting runtime error No symbol named 'mappin.circle.badge.plus' found in system symbol set
- [x] ✅ is there a geocoding function we can use to update the country field in the event stays? this would eliminate the "unknown" when alot of the cities have the city name, country or city name, state if it's in the USA in the city name (ie, "Caen, France", "Castle Rock, CO") 

Bug-Unknown Trip
- [x] If a user updates an existing location with new gps coordinates, does all the previous location event stays for that location get updated or do those events reference from the Location?
- [x] When a new trip is created a popup should come up asking for the transportation mode and any comments.  The transportation mode should still default to the type based on distance like it does not but allowing user to override it.
- [x] A new trip should automatically be created when a user enters a new event stay that is different than the previous day.  Likewise if an event stay is deleted it should check it affects a trip (ie its location was different than the previous day).
- [x] Trip refresh should only exclude type of trip (ie Train) and notes when comparing if a change is made.  There should also be an toggle to exclude a change, delete or add to be made.
- [x] There are a couple trips that have Unknown as a destination or origination and I can edit them.  They were caused by a blank stay entry which I have since corrected but need to be able to handle these and either error thrown or ability to add a stay.  There should be an option to refresh trips to with option to replace existing trips only if there is a change and select which trip to save.  Similar to how the Golfshot utility works.

Version 1.1
🔧Feature - Travel History (1.1)
- [x] There used to be an “Other Locations” menu view that displays all the other locations and date traveled.  I would like to use that or create a new view in the menu that is modeled similar to Mane Location views but based on country, star ñ, Ciry field that could have multiple stays under them. I like the ABC A-Z, Most Used, country filters similar to Manage locations view.
🔧Feature - Location CRUD (1.1)
- [x] Integrate the existing “Default Location” menu option into manage trips view, this is now redundant given the new manage trips.  I like the “Default location view and it’s description and would like to keep that, you can also remove the star default feature next to each location in the manage trip given this new approach.
- [x] Replace “Add Location” menu option with a view “Manage Locations” that allows users to add, update and delete Locations, but not the “Other” location
Version 1.0 (LocTrac-New repo)
Doc Cleanup (1.0)
- [x] •Moved all documentation to Documents Folder
Version 0 (LocTrac repo)
🔧Potential consolidation (0.4.2)
- [x] •I now have both InfographicsCacheManager (persistent actor) and InfographicsCache (in-memory ObservableObject). If that’s intentional (e.g., warm in-memory cache + persisted backing store), great — otherwise, we can unify or layer them cleanly to reduce maintenance.

🔧Import Golfshot Utility (0.4.1)
- [x] I want to build an import utility to load data from my Golfshot app which I use to capture rounds of golf.  The utility to should update an event stay of the day of the golf ground and set the activity to golf, and put the name of the golf course in the notes.  The utility should prompt for an input file that is in .cvs format.  The field layout of the file should be in Round DateTime (UTC) (ie  9/19/2024 10:37:58 AM), Facility name (import to Notes). The data should start on row 1.  The import should report how many entries were added and general error handling. Add the to the main menu under Utilities folder.amd mine Backups and export too.  

Main Screen (0.4.x)
- [x] I would like to have a main screen that is a little more user friendly when entering the application.   The app should start here instead of locations tab.  THighlighting key information and main features to use in the application. Can you provide some recommendations?

Bug - get location coordinates 
- [x] Get location for lat and long is missing.  It should be available for adding/updating a Location and whenever user selects “Other” on a new stay.

Import and preview backups(0.4.x)
- [x] When creating a new backup the file is not displayed in the Exported Backups section with an updated count.  Also rename from “Backup & Export” -> “Backup & Import”
- [x] The utility has messed up some of my past data, I need to work on import functionality as part of the of the Backup Export utility.  I need to create an import function the selects from a backup and just copies the selected import file and replaces the existing backups.json file.  Can you add the functionality? I also want to preview the backups I can’t find them on my phone, where are they stored?
Version 0.3.0
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


