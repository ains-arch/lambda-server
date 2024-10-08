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

# Add route for remote server through VPN
sleep 2  # Wait for the VPN to finish connecting
sudo ip route add $remote_server_ip dev tun0 # route traffic to the remote server through the vpn
sudo resolvectl dns tun0 $DNS_SERVER # set the DNS server ($ nslookup lambda.compute.cmc.edu)

echo "----------------------------------"
echo "Final IP Route:"
echo "----------------------------------"
ip route show
echo ""

echo "----------------------------------"
echo "Logging into Lambda Server:"
echo "----------------------------------"
ssh $USER@lambda.compute.cmc.edu -p $PORT
