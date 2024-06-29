#!/bin/sh

# This script is designed to takeover a $TARGET_SSID when it is no longer broadcasting. Useful for a LTE backup router. 
# If the target SSID is not found after a series of scan attempts, the script will configure the device to use the target SSID and notify via Slack.
# This can be added to crontab on the gl-x3000 in advanced settings
# */5 * * * * /root/takeover_wifi.sh
# Note: This script intentionally does not handle 'failback' when the $TARGET_SSID resumes broadcasting on another AP, e.g. Unifi.
# The intended wifi interface also has to be UP for scanning to work. It can be set to an arbitrary SSID. 

# Configuration
SLACK_WEBHOOK_URL=""  # Add your Slack webhook URL here
SLACK_USERNAME="gl-x3000 WiFi Monitor"
TARGET_SSID=""  # Add your target SSID here
MAX_SCAN_TRIES=3

# Check if we are already using the target SSID
current_ssid=$(uci get wireless.wifi2g.ssid)
if [ "$current_ssid" = "$TARGET_SSID" ]; then
    echo "SSID '$TARGET_SSID' is already set. Exiting script."
    
    # Slack message content
    message="*Info*: SSID *${TARGET_SSID}* is already set on gl-x3000. No action taken."

    # Construct the Slack message payload
    payload=$(cat <<EOF
{
  "attachments": [
    {
      "color": "#00BFFF",
      "text": "$message"
    }
  ],
  "username": "$SLACK_USERNAME"
}
EOF
)

    # Post the message to Slack and exit
    curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
    exit 0
fi

# Initialize counter for scan attempts
scan_attempts=0
ssid_found=false

# Loop to perform WiFi scan and check for the target SSID
while [ $scan_attempts -lt $MAX_SCAN_TRIES ]; do
    if iwinfo ra0 scan | grep -q "ESSID: \"$TARGET_SSID\""; then
        echo "SSID '$TARGET_SSID' found."
        ssid_found=true
        break  # Exit loop if SSID is found
    else
        echo "Attempt $((scan_attempts + 1)): SSID '$TARGET_SSID' not found."
    fi

    # Increment scan attempts
    scan_attempts=$((scan_attempts + 1))

    # Add a delay between scans if needed
    sleep 5  # Adjust delay time as necessary
done

# Check if SSID was not found after all attempts
if [ "$ssid_found" = false ]; then
    echo "SSID '$TARGET_SSID' not found after $MAX_SCAN_TRIES attempts. Taking corrective action..."

    # Change SSID configuration
    uci set wireless.wifi2g.ssid="$TARGET_SSID"
    uci commit wireless
    wifi

    # Slack message content
    message="*Alert*: Unifi SSID *${TARGET_SSID}* not found after $MAX_SCAN_TRIES attempts. Taking over SSID on gl-x3000"

    # Construct the Slack message payload
    payload=$(cat <<EOF
{
  "attachments": [
    {
      "color": "#FF0000",
      "text": "$message"
    }
  ],
  "username": "$SLACK_USERNAME"
}
EOF
)

    # Post the message to Slack
    curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
fi
