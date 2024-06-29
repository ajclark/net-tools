#!/bin/bash

# This script is designed to send notifications to Slack based on UPS events. 
# The NUT UPS tools must be installed and configured.
# This has been tested with a pair of CyberPower 1500VA UPSes.
# cat /etc/nut/upsmon.conf
# MONITOR nas@localhost 1 upsmon upsmon master
# MONITOR network@localhost 1 upsmon upsmon master
# NOTIFYCMD /usr/local/bin/nut_slack_alert.sh
# NOTIFYFLAG ONBATT SYSLOG+EXEC
# NOTIFYFLAG ONLINE SYSLOG+EXEC


# Configuration
SLACK_WEBHOOK_URL=""  # Add your Slack webhook URL here
SLACK_USERNAME="UPS Monitor"

# Capture the entire message as one argument
full_message="$1"

# Use pattern matching to determine the event type based on common phrases in the messages
if [[ "$full_message" == *"on line power"* ]]; then
    event_type="Online"
    color="#36A64F"  # Green
elif [[ "$full_message" == *"on battery"* ]]; then
    event_type="On Battery"
    color="#FFA500"  # Orange
elif [[ "$full_message" == *"battery is low"* ]]; then
    event_type="Low Battery"
    color="#FF0000"  # Red
elif [[ "$full_message" == *"shutdown in progress"* ]]; then
    event_type="Forced Shutdown"
    color="#FF0000"  # Red
elif [[ "$full_message" == *"Communications with UPS"* && *"established"* ]]; then
    event_type="Comm OK"
    color="#36A64F"  # Green
elif [[ "$full_message" == *"Communications with UPS"* && *"lost"* ]]; then
    event_type="Comm Bad"
    color="#FF0000"  # Red
elif [[ "$full_message" == *"shutdown proceeding"* ]]; then
    event_type="Shutdown"
    color="#FFFF00"  # Yellow
elif [[ "$full_message" == *"battery needs to be replaced"* ]]; then
    event_type="Replace Battery"
    color="#FFA500"  # Orange
elif [[ "$full_message" == *"is unavailable"* ]]; then
    event_type="No Comm"
    color="#FF0000"  # Red
elif [[ "$full_message" == *"parent process died"* ]]; then
    event_type="No Parent"
    color="#FF0000"  # Red
else
    event_type="Unknown"
    color="#808080"  # Grey
    full_message="Unknown event type: $full_message"
fi

# Construct the Slack message payload
payload=$(cat <<EOF
{
  "attachments": [
    {
      "color": "$color",
      "text": "$full_message"
    }
  ],
  "username": "$SLACK_USERNAME"
}
EOF
)

# Send the message to Slack
curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
