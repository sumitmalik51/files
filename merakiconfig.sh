#!/bin/bash

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Check if workspace_id is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <workspace_id>"
    exit 1
fi

WORKSPACE_ID=$1

# Download meraki.conf
wget -v https://aka.ms/sentinel-ciscomerakioms-conf -O meraki.conf
if [[ $? -ne 0 ]]; then
    echo "Failed to download meraki.conf"
    exit 1
fi

# Copy meraki.conf to the desired location
cp meraki.conf /etc/opt/microsoft/omsagent/$WORKSPACE_ID/conf/omsagent.d/
if [[ $? -ne 0 ]]; then
    echo "Failed to copy meraki.conf"
    exit 1
fi

# Edit meraki.conf - replace <workspace_id> with real value
sed -i "s/<Workspace_Id>/$WORKSPACE_ID/g" /etc/opt/microsoft/omsagent/$WORKSPACE_ID/conf/omsagent.d/meraki.conf
if [[ $? -ne 0 ]]; then
    echo "Failed to update meraki.conf with workspace ID"
    exit 1
fi

# Restart the Azure Log Analytics agent for Linux
/opt/microsoft/omsagent/bin/service_control restart

# Modify /etc/rsyslog.conf file
echo '$template meraki,"%timestamp% %hostname% %msg%\n"' >> /etc/rsyslog.conf

# Create 10-meraki.conf and add filter conditions
cat <<EOL > /etc/rsyslog.d/10-meraki.conf
if \$rawmsg contains 'flows' then @@127.0.0.1:22033;meraki
& stop 
if \$rawmsg contains 'urls' then @@127.0.0.1:22033;meraki
& stop
if \$rawmsg contains 'ids-alerts' then @@127.0.0.1:22033;meraki
& stop
if \$rawmsg contains 'events' then @@127.0.0.1:22033;meraki
& stop
if \$rawmsg contains 'ip_flow_start' then @@127.0.0.1:22033;meraki
& stop
if \$rawmsg contains 'ip_flow_end' then @@127.0.0.1:22033;meraki
& stop 
EOL

# Restart rsyslog
systemctl restart rsyslog
if [[ $? -ne 0 ]]; then
    echo "Failed to restart rsyslog"
    exit 1
fi

echo "Script completed successfully!"

