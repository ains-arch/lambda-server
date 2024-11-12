#!/bin/bash

# Make sure to fill in the following variables: $LAMBDA_SERVER_IP_ADDRESS, $USER, $DNS_SERVER, $PORT

# Function to gracefully disconnect all openconnect processes
disconnect_vpn() {
    echo "----------------------------------"
    echo "Disconnecting all openconnect VPN sessions..."
    # Find and kill all openconnect processes
    pids=$(pgrep openconnect)
    if [ -n "$pids" ]; then
        sudo kill -SIGINT $pids
        echo "VPN connections terminated."
    else
        echo "No openconnect processes found."
    fi
    exit 0
}

# Check if the -x argument is passed
if [ "$1" = "-x" ]; then
    disconnect_vpn
fi

# Check if a cookie argument is passed
if [ -z "$1" ]; then
    echo "Usage: ./lambda.sh webvpn:\"alphanumeric string\" or ./lambda.sh -x to disconnect"
    exit 1
fi

# Store the entire argument in $cookie
cookie="$1"

# Replace the 'webvpn:"' with 'webvpn=' and remove the trailing '"'
cookie="${cookie/webvpn:/webvpn=}"
cookie="${cookie%\"}"

echo "extracted" $cookie

# Get the remote server's IP address
remote_server_ip=$LAMBDA_SERVER_IP_ADDRESS
dns_server_ip=$DNS_SERVER # ($ nslookup lambda.compute.cmc.edu)

disconnect_vpn # TODO: skip the vpn connection if i already have one open that works

echo "----------------------------------"
echo "Initial IP Route:"
echo "----------------------------------"
ip route show
echo ""

echo "----------------------------------"
echo "Starting VPN Connection (openconnect dump):"
echo "----------------------------------"
sudo openconnect -vvv --dump -b --user=$USER@cmc.edu \
    --protocol=anyconnect https://vpn.claremontmckenna.edu \
    --os=win --useragent='AnyConnect Windows 4.9.00086' \
    --cookie="$cookie"
sleep 2  # Wait for the VPN to finish connecting

echo "----------------------------------"
echo "Configuring IP route:"
echo "----------------------------------"
# Add route for remote server through VPN
sudo ip route add $remote_server_ip dev tun0 # route traffic to the remote server through the vpn
echo ""
echo "-- Final IP Route:"
ip route show
sleep 2
echo ""

echo "----------------------------------"
echo "Configuring DNS:"
echo "----------------------------------"
echo "-- Initial DNS:"
sudo resolvectl # check initial setup (probably wrong)
echo ""
sudo resolvectl dns tun0 $dns_server_ip # set the DNS server
echo "-- Final DNS:"
sudo resolvectl
echo ""

echo "----------------------------------"
echo "Logging into Lambda Server:"
echo "----------------------------------"
ssh $USER@lambda.compute.cmc.edu -p $PORT
