#!/bin/sh
set -e # exist immediate if a command exits with a non-zero status

# initialize username/password variables
email=$1 # first argument is the email
username=$(echo "$email" | sed 's/@.*$//') # username everything up to @
password=$(openssl rand -base64 8) # password is 11 "random" characters followed by =

# initialize the supplementary group
if [ "$2" = '' ]; then # if no second argument
    # primary group: the group that the OS assigns to files that the user creates
    # can think of it as the "default" group. every user needs to be assigned to one
    echo "must specify a primary group in the second command line arg"
    exit
fi

# delete a user that already exists
# `id -u $username` returns the uid of the user if it exists, or error if not
if id -u $username; then 
    echo "$username exists..."
    read -p "enter [Y] to delete" reallydelete # assigns the user response to "reallydelete"
    if [ "$reallydelete" = "Y" ]; then
        userdel $username # removes /etc/passwd and /etc/shadow entries for $username
        echo "deleted"
    else # if you don't want to delete the user
        exit 0
    fi
fi

# create the user
echo "creating user $username"
# useradd -m: create the user's home directory if it does not exist
# useradd -p: defines initial password
# TODO: what does this "$(mkpasswd $password)" line do? the documentation
# makes it seem like it would that argument as the user name and assign it to
# that user
# useradd -s: sets path to user's login shell as /bin/bash
# useradd -g: makes the user's primary group "students"
# TODO: then why are we "initializing the primary group" up in $2 :10
useradd -m -p "$(mkpasswd $password)" -s /bin/bash "$username" -g "students"
chage -d0 "$username" # forces the user to change their password on the next log in
# set soft block limit to 100Mb, hard block limit to 200Mb for $username on /
quotatool -u "$username" -b -q 100M -l 200M /
chown -R "$username" "/home/$username" # recursively makes the user the owner of their home dir
chgrp -R "students" "/home/$username" # recursively makes students the group owner of their home dir

# create the data structures settings
if [ "$2" = 'csci046' ]; then
    echo 'modifying account permissions for csci046'
    usermod -a -G csci046 "$username" # add the user to the supplementary group csci046
fi

# create the bigdata settings
if [ "$2" = 'csci143' ]; then
    echo 'modifying account permissions for csci143'
    usermod -a -G csci143 "$username" # add the user to the supplementary group csci143
    # set soft block limit to 10Gb, hard block limit to 11Gb for $username on /
    quotatool -u "$username" -b -q 10G -l 11G /
    # set soft block limit to 200Gb, hard block limit to 250Gb for $username on /data
    quotatool -u "$username" -b -q 200G -l 250G /data
    # make the user a directory in the /data/users_bigdata directory
    bigdata_dir="/data/users_bigdata/$username/"
    mkdir "$bigdata_dir"
    chown "$username" "$bigdata_dir" # make the user the owner of the user's /data/users_bigdata dir
    chgrp "students" "$bigdata_dir" # make the students the group owner of the user's new dir
    # create symbolic link to /data/users_bigdata/$username in the user's home directory
    ln -s "$bigdata_dir" "/home/$username/bigdata"
fi

# print the contents of the email to send to the new users
echo '=================================='
echo "I've created an account for you on the lambda server." 
echo 
echo "your username: $username"
echo "your password: $password"
echo
echo "The server is located at lambda.compute.cmc.edu:5055 inside CMC's VPN.  You should receive separate instructions from the CMC IT staff for logging into the VPN."
echo ""
echo "After logging into the VPN, you can login to the lambda server by running the following terminal command:"
echo
echo "$ ssh $username@lambda.compute.cmc.edu -p 5055"
echo
echo "You will be required to change your password on the first login."
echo 
echo "Do not share your password with anyone else.  Sharing of passwords will be treated as an academic integrity violation."

#echo "Account limitations:"
#echo " * You currently don't have access to any of the GPUs on the server.  If you need access to the GPUs, let me know and I'll give you permission."
#echo " * Your home directory has 20GB allocated to it.  If you need more space, let me know and I'll give you more."
#echo
#echo "You can find all of the datasets in the /data directory.  The Twitter data is located at /data/Twitter\ dataset and the reddit data is located at /data/files.pushshift.io/reddit "

