#!/usr/bin/env bash

# Function to check if a user belongs to a specific group
is_user_in_group() {
    local user=$1
    local group=$2
    groups $user | grep -q "\b$group\b"
}

# Customizing timeout policy based on user or group
if is_user_in_group "$(whoami)" "adm"; then
    # Extend timeout for admin users
    TMOUT=3600 # 60 minutes for admin
else
    # Default timeout for other users
    TMOUT=1200 # 20 minutes
fi

# Set the TMOUT variable and export it
readonly TMOUT
export TMOUT

# Disabling coredumps - with a conditional switch
DISABLE_COREDUMPS=true

if [ "$DISABLE_COREDUMPS" = true ] ; then
    ulimit -c 0 > /dev/null 2>&1
fi

# Setting a stronger umask
UMASK_VALUE=027
umask $UMASK_VALUE

# Logging the applied settings
log_file="/tmp/hardened-profiled-$(whoami).log"
{
    echo "$(date) - Applied settings:"
    echo "TMOUT set to $TMOUT"
    echo "Coredumps disabled: $DISABLE_COREDUMPS"
    echo -e "Umask set to $UMASK_VALUE\n"
} >> $log_file

# Ensure the log file is only readable by the user who created it
chmod 600 $log_file

# Additional security measures can be added here
