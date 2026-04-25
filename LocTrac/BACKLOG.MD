LocTrac Dev prompts

Start Prompt
Before we start always refer to Claude.md, any new feature or bug fix should update VERSION_2.0_RELEASE_NOTES.md, ask me if you should add appropriate debug statements following debug framework, and ask me if you should create recommended test for new functionality, improvements or bug fixes.  Ask if a summary .md or supporting .md docs are need.  Ask me these question for every response unless I directly ask for them.  Shall we begin?

New Feature and Doc Prompt
See Claude.md,  update VERSION_2.0_RELEASE_NOTES.md, CHAMGELOG and make sure claude.md is up to date with all of our changes.  Create a page view for this feature in WhatsNew.  Any questions or clarifications?

Ready to Publish
See Claude.md,  I have completed all the feature, bug and improvements for this release.  I want to review changeling and check whatsnew is up to date with all of them.  Commit and Tag  and push this version to lithium, create a new release, verify Release Date is correct and run a regression test.  Add this to claude.md so all I have to do is say I’m ready to publish this release.  Confirm anything, ask any clarifying questions so we can optimize this step in the future.

Documentation update
See Claude.md,  Please review all of these (version 2.0) changes Features, Bugs, Enhancements, improvements are captured in the CHAMGELOG, use existing wordage in CHANGELOG  if the essence of these are already in there. 

Backlog Features and Bugs

⚠️ BUGS


🔧 FEATURES
🔧Feature - Batch Delete (HOLD For now)
- [ ] See CLAUDE.md I want to create a utility the lets me select a date range delete option to remove all event stay data from a date range.  Add it to Main Menu, Administration Do you any questions, suggestions or clarifications before we start?




————————————————————
🔧Feature - Environmental Factors menu view
- [ ] See CLAUDE.md Create a menu item for managing environmental impacts.  Option to remove trains and buses from environment impact calculations for public transportation, I want to be able to have my car mileage impacts incorporated into the infographics environmental impacts section.  Field for total miles per year, car type model epa rating, etc, type electric/hybrid/gas/diesel, add variable CO2 per mile for each car.  The type of car should impact the environmental impacts section.  Dates range car was used that should be applied to env calculations for any driving trips during that timeframe. Current car should be applied to any new trip if driving is selected.  Create a new menu optional “Environmental Factors” and create a manage car for Create, Update and delete. provide tests per @LocTrac Testing Master Guide.md Do you any questions, suggestions or clarifications before we start?

🔧Feature - Car usage
- [ ] See CLAUDE.md I want to be able to have my car mileage impacts incorporated into the infographics environmental impacts section.  Field for total miles per year, car type model epa rating, etc, type electric/hybrid/gas/diesel.  The type of car should impact the environmental impacts section.  Current car should be applied to any new trip if driving is selected.  Create a new menu optional “Environmental Factors” and create a manage car for Create, Update and delete. provide tests per @LocTrac Testing Master Guide.md Do you any questions, suggestions or clarifications before we start?

🔧Feature - add Claude to app
- [ ] See CLAUDE.md Add a Claude interface to LocTrac so users can ask questions about events, trips, activity, people.  Create all necessary views and api integrations to Claude. [prerequisite - User id, profile] provide tests per @LocTrac Testing Master Guide.md Do you any questions, suggestions or clarifications before we start?

🔧Feature - Integration with Apple fitness.  
- [ ] See CLAUDE.md I want to create an interface into Apple HealthKit to extract exercise entry to activity and minutes, also extract biking exercise and miles.  New fields will have to be created to store these extra fields and displayed in infographics activities section.  Add this as an optional feature to user profile, Exercise activity may need a more complex supporting data model. provide tests per @LocTrac Testing Master Guide.md Do you any questions, suggestions or clarifications before we start?


Version 2.0
Completed 
🔧Feature - Activities display  (version 2.0)
- [x] See CLAUDE.md when adding or updating an event there too many activities (10) and takes up a lot of visual space need better UI approach using best practices for this. Do you any questions, suggestions or clarifications before we start?🔧 Feature - Home Screen improve  “Add Stay”
- [x] See CLAUDE.md @HomeView user is presented with “Add Stay” button.  Currently this takes them to the calendarView.  I would like a little more intelligence built in.  provide tests per @LocTrac Testing Master Guide.md Do you any questions, suggestions or clarifications before we start? Accommodate 3 scenarios where it takes them to the actual event stay Add or Edit views for that day
    1. Priority should be displayed first if true- is there an event for the current day.
    2. If yes then - check to see if there is any missing days from the first oldest stay event day to current, continue cycling through until complete or it’s the next day and no current day event exists
    3. Provide default if case 1 and 2 are met - provide option to update current day event stay.  
🔧Feature - User/Account (version 2.0)
- [x] See CLAUDE.md I would like to make the a more publishable application that has current user capabilities Username and password, profile, preferences, etc.  The login functionality should allow user to create their own id’s using an email address, Apple ID or Google ID, 2 factor authentication, biometrics, account email verification.  I want the user id tied to backup.jason and not carried through all the data models.  However I want the ability for someone to import another’s backup files I theirs.  Each user should have a standard profile with option to reset password, turn certain features on/off Affirmations, Activity and People.  I want to create 2 roles Admin and User.  Admin will have access to certain utilities.  Not sure best was to expose this in app, perhaps creat an admin user account for login but has full access to the users data running on the users iPhone. provide tests per @LocTrac Testing Master Guide.md, update Claude.md. Do you any questions, suggestions or clarifications before we start?
🔧Feature - Enhance Data only ran one for successful entries (version 2.0)
- [x] See CLAUDE.md when When running Enhance Location, once a location as been successfully geolocated a flag should be set to set in the future.  Set the flag for any new entries if is geocoded.  Do new entries get geocoded?  Also when an entry location changes.   Do you any questions, suggestions or clarifications before we start?
🔧Feature - Copy and Paste event (version 2.0)
- [x] See CLAUDE.md I want to create a utility the lets me select an event day and copy all or parts of it’s data to another day or series of days  Error check if that event already exists and prompt the user to replace or update selected fields.  I’m not sure where best to expose this functionality?  Any suggestions, recommendations?  It is similar to when a user enters an end date greater than the current date but that is only allowed entering a new event.  . provide tests per @LocTrac Testing Master Guide.md Do you any questions, suggestions or clarifications before we start?
🔧Feature - Adding default person to stays (version 2.0)
- [x] See CLAUDE.md I want to create a utility the lets me select a name from my contacts and update events for a given time from with that Person to each stay.  Error check if that person already exists ignore the update. This is a one - off utility to help me clean up a large data set.  Add it to Main Menu, Administration Do you any questions, suggestions or clarifications before we start?
🔧Feature - Create testing strategy  (version 2.0)
- [x] See CLAUDE.md I want to create a comprehensive testing strategy for this app and put in Documents/LocTrac Testing Master Guide.md.  This should include unit testing, data testing, regression testing, etc.  Would like your recommendations on how best to do this using automation and Xcode.  Do you any questions, suggestions or clarifications before we start?
🔧Feature Improvement - Manage Trips  refresh. (version 2.0)
- [x] See CLAUDE.md @TripsManagementView->Refresh When viewing trips if a location = “Other” instead of displaying “Other” use City Name. Use same formatting for Location, “->” and Other.city name as in @TripsManagementView Do you any questions, suggestions or clarifications before we start?
🔧Feature - allow event stay Pictures (version 2.0)
- [x] See CLAUDE.md Allow user to add picture to event stays.  . 
🔧Feature - Location Pictures should be imported and exported
- [x] See CLAUDE.md when exporting and importing an option should be allowed for Location Pictures. Do you any questions, suggestions or clarifications before we start?
⚠️Bug- Notifications not displaying missing event(version 2.0)
- [x] See CLAUDE.md  @NotificationManager  Stay Reminder Notification doesn’t seem to be properly alerting user that they are missing an entry for the current day.  Can you confirm the logic is correct, once the current day is entered it shouldn’t display a notification to update it.
⚠️Bug- Refresh Trips not working correctly(version 2.0)
- [x] See CLAUDE.md  @TripRefreshView  when analyzing trips is identifying incorrect trips to be added and removed. From the screen shots below you can see the add trips don’t match the data, something is off and I need help trouble shooting.  Need to add debugs, here is the run log.provide tests per @LocTrac Testing Master Guide.md See picture 
⚠️Improvement- Debug view names(version 2.0)
- [x] See CLAUDE.md, Specifically Debug.  @DebugSettingsView , @DebugConfig. Setting the Show View Names doesn’t appear to be working in the app UI itself, it may only be in the log.  This will help me identify which screen needs to be updated in future feature work.  Can you run a comprehensive analysis of all the code to make sure this is working and all other debug options.  Provide recommendations and suggestions to fully implement Debug and provide tests per LocTrac Testing Master Guide.md
⚠️Bug- Don’r allow duplicate entries on same day(version 2.0)
- [x] See CLAUDE.md  put a constraint in the prohibits a user to enter more than 1 stay on a given day.  This can happen when user enters an end date greater than the current date selected more than one, its been to be a batch update feature but needs some more control,  in the @ModernEventFormView
⚠️Improvement- Menu Order(version 2.0)
- [x] See CLAUDE.md, @StartTabView Add “Adminstration” expand out similar to Data Management.  change the Menu order to
* About LocTrac
* Notifications
* <break>
* Manage Data
    * Manage Locations
    * Manage Events
    * Activities & Affirmations
    * Manage Trips
* <break>
* Travel History
* <break>
* Administration
    * Data Management
    * Debug Settings
⚠️Bug- city & State editable (version 2.0)
- [x] See CLAUDE.md  City, state and country should not be editable on moderneventform when Location != “Other”.  This should only be allowed in Manage Location view
⚠️ Bug- infographic Event Types graph & legend not sync (version 2.0)
- [x] See CLAUDE.md  @InfographicsView The Event Type graph and legend colors are not in sync.  The legend has the correct colors.  However I would like to come up with a more user pleasing experience than what it is now.  I would some creative better visual options and revamp every where from input, edit and display. I soulless to keep colors in @ModernEventForm.md.  Search on .swift files for “Event Types” and provide a comprehensive list of files that need to be Modified. Do you any questions, suggestions or clarifications before we start? see pic 
- [x] Create a CRUD management view for Event Types, allow update, add and delete options.  Add this to the main Menu (3dot/circle top left) as “Manage Event Types” under “Manage Locations”.  Also Add an option in  in User Profile->Preference to set a default Event Type that persists throughout all entry/update forms that allow event type to be selected.
⚠️Bug- Edit Stay Event not populating City and state (version 2.0)
- [x] See CLAUDE.md  @ModernEventFormView not displaying City name and State name from parent when location = “Cabo” but Manage locations for Cabo is correct all of the other locations are displayed correctly see pic
Bug- setting Default location in preference(version 2.0)
- [x] See CLAUDE.md  when setting default location preference it doesn’t set the global variable like it does in manage locations.  Double check setting Default Travel Mode as well.
Improvement - Change tab name(version 2.0)
- [x] See CLAUDE.md @StartTabView Change tabItem “Location”. -> “Travel Map” and change the icon to a map icon that looks nice or a Map pin. No test scrips needed.
⚠️Improvement- Manage Location(version 2.0)
- [x] See CLAUDE.md, @LocationsManagementView Remove the filter bar  “abc A-Z”, “Most Used”, “Country”, there will not be many unique locations. No test scripts needed. No doc updates required, no debug
⚠️Bug- Travel History Location jumping (version 2.0)
- [x] See CLAUDE.md  @TravelHistoryView When Selecting Location expand it sometimes readjusts the order of the location.  These should be fixed with the most event stays per location starting at top, no jumping after expanding or collapsing.. No test scripts needed.No doc updates required, no debug
⚠️Bug- Enhance Locarion data off by 1 day.(version 2.0)
- [x] See CLAUDE.md  @LocationDataEnhancementView  specifically the date, time and Timezone section as it appears to be the same issue when analyzing the Event Errors I noticed the error dates were off by +1 day. provide tests per @LocTrac Testing Master Guide.md See pics


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




￼


