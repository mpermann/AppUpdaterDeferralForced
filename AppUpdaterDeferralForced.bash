#!/bin/bash

# Name: AppUpdaterDeferralForced.bash
# Version: 1.1.3
# Created: 05-17-2022 by Michael Permann
# Updated: 10-21-2022
# The script is for patching an app with user notification before starting, if the app is running. It supports
# deferrals with tracking and forced install after deferrals run out. If the app is not running, it will be
# silently patched without any notification to the user. Parameter 4 is the name of the app to patch. Parameter
# 5 is the name of the app process. Parameter 6 is the policy trigger name for the policy installing the app.
# Parameter 7 is the number of allowed deferrals. Parameter 8 is the countdown timer in seconds. The script is
# relatively basic and can't currently kill more than one process or patch more than one app.

isAppRunning() {
APP_PROCESS_ID=$(/bin/ps ax | /usr/bin/pgrep -x "$APP_PROCESS_NAME" | /usr/bin/grep -v grep | /usr/bin/awk '{ print $1 }')
if [ -n "$APP_PROCESS_ID" ] # Check whether app is running by testing if string length of process id is non-zero.
then
    # Since APP_PROCESS_ID string length is non-zero, the app is running.
    echo 1
else
    # Since APP_PROCESS_ID string length is zero, the app is NOT running.
    echo 0
fi
}

killAppProcess() {
APP_PROCESS_ID=$(/bin/ps ax | /usr/bin/pgrep -x "$APP_PROCESS_NAME" | /usr/bin/grep -v grep | /usr/bin/awk '{ print $1 }')
kill -9 "$APP_PROCESS_ID"
}

createDeferralPlist() {
/usr/libexec/PlistBuddy -c "Add :CurrentDeferralCount integer 0" "/Library/Application Support/HeartlandAEA11/Reporting/${APP_NAME} Deferral.plist"
/usr/libexec/PlistBuddy -c "Add :MaxDeferral integer ${MAX_DEFERRAL}" "/Library/Application Support/HeartlandAEA11/Reporting/${APP_NAME} Deferral.plist"
echo "Deferral file created and count set to: 0"
CURRENT_DEFERRAL_COUNT=$(/usr/bin/defaults read "/Library/Application Support/HeartlandAEA11/Reporting/${APP_NAME} Deferral.plist" 'CurrentDeferralCount')
}

getDeferralCount() {
if [ -e "/Library/Application Support/HeartlandAEA11/Reporting/${APP_NAME} Deferral.plist" ]
then
    CURRENT_DEFERRAL_COUNT=$(/usr/bin/defaults read "/Library/Application Support/HeartlandAEA11/Reporting/${APP_NAME} Deferral.plist" 'CurrentDeferralCount')
else
    createDeferralPlist
fi
}

incrementDeferralCount() {
CURRENT_DEFERRAL_COUNT=$((++CURRENT_DEFERRAL_COUNT))
/usr/libexec/PlistBuddy -c "Set :CurrentDeferralCount $CURRENT_DEFERRAL_COUNT" "/Library/Application Support/HeartlandAEA11/Reporting/${APP_NAME} Deferral.plist"
}

deleteDeferralPlist() {
if [ -e "/Library/Application Support/HeartlandAEA11/Reporting/${APP_NAME} Deferral.plist" ]
then
    /bin/rm -rf "/Library/Application Support/HeartlandAEA11/Reporting/${APP_NAME} Deferral.plist"
else
    echo "No app deferral plist to remove."
fi
}

patchApp() {
"$JAMF_BINARY" policy -event "$POLICY_TRIGGER_NAME"
}

openApp() {
    /bin/launchctl asuser "$USER_ID" sudo -u "$CURRENT_USER" /usr/bin/open -a "/Applications/${APP_NAME}.app"
}

updateInventory() {
"$JAMF_BINARY" recon
}

notifyUserTwoChoice() {
DIALOG=$(/bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -windowType utility -windowPosition lr -title "$TITLE0" -description "$DESCRIPTION0" -icon "$LOGO" -button1 "$BUTTON1" -button2 "$BUTTON2" -defaultButton "$DEFAULT_BUTTON" -cancelButton "$CANCEL_BUTTON")
if [ "$DIALOG" = 0 ]
then
    # The default OK button was clicked, so proceed with app patching.
    echo 1
else
    # The Cancel button was clicked, so defer app patching.
    echo 0
fi
}

notifyUserOneChoice() {
DIALOG=$(/bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -button1 "$BUTTON1" -windowType utility -title "$TITLE1" -defaultButton "$DEFAULT_BUTTON" -alignCountdown center -description "$DESCRIPTION1" -countdown -icon "$LOGO" -windowPosition lr -alignDescription left -timeout "$TIMER")
# The default OK button was clicked, so proceed with app patching.
echo 1
}

notifyUserComplete() {
DIALOG=$(/bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -windowType utility -windowPosition lr -title "$TITLE2" -description "$DESCRIPTION2" -icon "$LOGO" -button1 "$BUTTON1" -defaultButton "1")
# The default OK button was clicked on notification complete dialog.
echo 1
}

APP_NAME=$4
APP_PROCESS_NAME=$5
POLICY_TRIGGER_NAME=$6
MAX_DEFERRAL=$7
TIMER=$8
getDeferralCount
CURRENT_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
USER_ID=$(/usr/bin/id -u "$CURRENT_USER")
LOGO="/Library/Application Support/HeartlandAEA11/Images/HeartlandLogo@512px.png"
JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
JAMF_BINARY=$(which jamf)
TITLE0="Quit Application"
DESCRIPTION0="Greetings Heartland Area Education Agency Staff

An update for $APP_NAME is available.  Please return to $APP_NAME and save your work and quit the application BEFORE returning here and clicking the \"OK\" button to proceed with the update. 

Caution: your work could be lost if you don't save it and quit $APP_NAME before clicking the \"OK\" button.

You may click the \"Cancel\" button to defer this update. You can defer a maximum of $MAX_DEFERRAL times. You have deferred $CURRENT_DEFERRAL_COUNT times.

Any questions or issues please contact techsupport@heartlandaea.org.
Thanks!"
TITLE1="Quit Application"
DESCRIPTION1="Greetings Heartland Area Education Agency Staff

An update for $APP_NAME is available.  Please return to $APP_NAME and save your work and quit the application BEFORE returning here and clicking the \"OK\" button to proceed with the update. 

Caution: your work could be lost if you don't save it and quit $APP_NAME before clicking the \"OK\" button.

You can defer a maximum of $MAX_DEFERRAL times. You have deferred $CURRENT_DEFERRAL_COUNT times.

Any questions or issues please contact techsupport@heartlandaea.org.
Thanks!"
TITLE2="Update Complete"
DESCRIPTION2="Thank You! 

$APP_NAME has been updated on your computer."
BUTTON1="OK"
BUTTON2="Cancel"
DEFAULT_BUTTON="1"
CANCEL_BUTTON="2"

getDeferralCount
if [ "$(isAppRunning)" = 1 ]
then
    echo "App is running."
    if [ "$CURRENT_DEFERRAL_COUNT" != "$MAX_DEFERRAL" ]
    then
        echo "App is running and max deferrals not reached."
        if [ "$(notifyUserTwoChoice)" = 1 ]
        then
            if [ "$(isAppRunning)" = 1 ]
            then
            echo "User chose OK and app is running. Kill app process and proceed to patch app."
            killAppProcess
            else
            echo "User chose OK and app not running. Proceed to patch app."
            fi
        else
            echo "User chose Cancel. Defer patching, increment counter and exit."
            incrementDeferralCount
            exit 1
        fi
    else
        echo "Max deferrals reached. Display dialog with OK button and countdown timer."
        notifyUserOneChoice
        if [ "$(isAppRunning)" = 1 ]
        then
            echo "App running. Kill app process and proceed to patch app."
            killAppProcess
        else
            echo "App not running. Proceed to patch app."
        fi
    fi
else
    echo "App not running. Proceed to patch app silently."
    echo "Delete deferral plist file."
    deleteDeferralPlist
    echo "Run policy to patch app."
    patchApp
    echo "Run policy to update inventory."
    updateInventory
    exit 0
fi
echo "Delete deferral plist file."
deleteDeferralPlist
echo "Run policy to patch app."
patchApp
echo "Run policy to update inventory."
updateInventory
echo "Launch app since it was open."
openApp
echo "Notify user update is complete."
notifyUserComplete
exit 0