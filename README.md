# AppUpdaterDeferralForced

This workflow provides application patching with notifications, deferral tracking and forced install after maximum
deferrals reached. Workflow includes a customizable countdown timer on the final deferral to ensure the app gets
patched in a timely fashion. 

This patching workflow was designed to be run using Jamf Pro and utilizes the script parameters to set the various
options. Parameter 4 is the name of the app to be patched. Parameter 5 is the name of the app process needing
killed if the app is running. Parameter 6 is the custom trigger name of the policy used to install the app.
Parameter 7 is the number of deferrals the end user is allowed to defer until the app is patched automatically.
Parameter 8 is the number of seconds for the countdown timer before the dialog message is dismissed and the app is 
patched. 
