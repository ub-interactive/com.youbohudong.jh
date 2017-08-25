#!/bin/bash
#
# =========================================================================
# Copyright 2014 Rado Buransky, Dominion Marine Media
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ========================================================================
#
#
# Check this blog post I wrote with detailed information:
# http://buransky.com/play-framework/init-d-shell-script-for-play-framework-distributed-application/
#
#
# Script to start, stop and check status of a Play framework application. It requires
# the Play application to be packaged using the "dist" command. Before you run the script,
# you have to set values of NAME, PORT and APP_DIR variables.
#
#         NAME – name of the application, must be the same as the name of shell script
#                generated by Play framework to run the app
#         PORT – port number at which the app should run
#         APP_DIR – path to directory where you have unzipped the packaged app
#
#
# Usage: control.sh {start|stop|status|restart}
#    port - requred for start and restart commands
#
# Example: control.sh restart app-name 9000
#
#
# The script uses RUNNING_PID file generated by Play framework which contains ID of the
# application server process.
#
#
# START YOUR APPLICATION WHEN MACHINE STARTS
# ==========================================
#
# The script uses RUNNING_PID file generated by Play framework which contains ID of
# the application server process.
#
#
# SAFE START
# ==========
#
# After starting the application the script checks whether the RUNNING_PID file has
# been created and whether the process is really running. After that it uses wget
# utility to issue an HTTP GET request for root document to do yet another check
# whether the server is alive. Of course this assumes that your application serves
# this document. If you don’t like (or have) wget I have provided curl version for
# your convenience as well.
#
#
# SAFE STOP
# =========
#
# Stop checks whether the process whose ID is in the RUNNING_PID file really belongs
# to your application. This is an important check so that we don’t kill an innocent
# process by accident. Then it sends termination signals to the process starting
# with the most gentle ones until the process dies.
#
#

# Script arguments (start, stop, restart or status)
COMMAND=$1

# ***********************************************
# *************  Set these variables  ***********

NAME=com-liao0007-jh
PORT=9001
APP_DIR=/var/www/com-liao0007-jh-1.0-SNAPSHOT

# ***********************************************
# ***********************************************

# Additional arguments to be passed to the Play application
APP_ARGS=-Dhttp.port=${PORT}

# Path to the RUNNING_PID file containing process ID
PID_FILE=$APP_DIR/RUNNING_PID

# Helper functions
echoProgress()
{
    setColor 6
        printf "%-70s" "$1..."
    resetColor
    return 0
}

echoError()
{
    setColor 6
        printf "ERROR"
        if [ ! -z "$1" ]
        then
        resetColor
                printf " [$1]"
        fi
        printf "\n"
    resetColor
    return 0
}

echoOK()
{
    setColor 2
        printf "OK"
        if [ ! -z "$1" ]
        then
        resetColor
                printf " [$1]"
        fi
        printf "\n"
    resetColor
    return 0
}

checkResult()
{
        if [ "$1" -ne 0 ]
        then
                echoError "$2"
                exit 1
        fi
}

setColor()
{
        tput setaf $1 2>/dev/null
}

resetColor()
{
        tput sgr0 2>/dev/null
}

# Checks if RUNNING_PID file exists and whether the process is really running.
checkPidFile()
{
    if [ -f $PID_FILE ]
    then
        if ps -p `cat $PID_FILE` > /dev/null
        then
            # The file exists and the process is running
            return 1
        else
            # The file exitsts, but the process is dead
            return 2
        fi
    fi

    # The file doesn't exist
    return 0
}

# Gently kill the given process
kill_softly()
{
    SAFE_CHECK=`ps $@ | grep [-]Duser.dir=$APP_DIR`
    if [ -z "$SAFE_CHECK" ]
    then
        # Process ID doesn't belong to expected application! Don't kill it!
        return 1
    else
        # Send termination signals one by one
        for sig in TERM HUP INT QUIT PIPE KILL; do
            if ! kill -$sig "$@" > /dev/null 2>&1 ;
            then
                break
            fi
            sleep 2
        done
    fi
}

# Get process ID from RUNNING_PID file and print it
printPid()
{
    PID=`cat $PID_FILE`
    printf "PID=$PID"
}

# Check port input argument
checkPort()
{
    if [ -z "$PORT" ]
    then
        echoError "Port not set!"
        return 1
    fi
}

# Check input arguments
checkArgs()
{
    # Check command
    case "$COMMAND" in
        start | stop | restart | status) ;;
        *)
            echoError "Unknown command"
            return 1
        ;;
    esac

    # Check application name
    if [ -z "$NAME" ]
    then
        echoError "Application name not set!"
        return 1
    fi

    # Check application directory
    if [ -z "$APP_DIR" ]
    then
        echoError "Application installation directory not set!"
        return 1
    fi

    # Check port
    case "$COMMAND" in
        start | restart)
            checkPort
            if [ $? != 0 ]
            then
                return 1
            fi
        ;;
    esac
}

checkAppStarted()
{
    # Wait a bit
    sleep 3

    # Check if RUNNING_PID file exists and if process is really running
    checkPidFile
    if [ $? != 1 ]
    then
        echoError
        cat $TMP_LOG 1>&2
        exit 1
    fi

    local HTTP_RESPONSE_CODE

    # Issue HTTP GET request using wget to check if the app is really started. Of course this
    # command assumes that your server supports GET for the root URL.
    HTTP_RESPONSE_CODE=`wget -SO- "http://localhost:$PORT/" 2>&1 | grep "HTTP/" | awk '{print $2}'`

    # The same functionality but using curl. For your convenience.
    #HTTP_RESPONSE_CODE=`curl --connect-timeout 20 --retry 3 -o /dev/null --silent --write-out "%{http_code}" http://localhost:$PORT/`

    checkResult $? "no response from server, timeout"

    if [ $HTTP_RESPONSE_CODE != 200 ]
    then
        echoError "HTTP GET / = $HTTP_RESPONSE_CODE"
        exit 1
    fi
}

# Check input arguments
checkArgs
if [ $? != 0 ]
then
    echo "Usage: $0 {start|stop|status|restart}"
    exit 1
fi

case "${COMMAND}" in
    start)
        echoProgress "Starting $NAME at port $PORT"

        checkPidFile
        case $? in
            1)    echoOK "$(printPid) already started"
                exit ;;
            2)    # Delete the RUNNING_PID FILE
                rm $PID_FILE ;;
        esac

        SCRIPT_TO_RUN=$APP_DIR/bin/$NAME
        if [ ! -f $SCRIPT_TO_RUN ]
        then
            echoError "Play script doesn't exist!"
            exit 1
        fi

        # * * * Run the Play application * * *
        TMP_LOG=`mktemp`
        PID=`$SCRIPT_TO_RUN $APP_ARGS > /dev/null 2>$TMP_LOG & echo $!`

        # Check if successfully started
        if [ $? != 0 ]
        then
            echoError
            exit 1
        else
            checkAppStarted
            echoOK "PID=$PID"
        fi
    ;;
    status)
        echoProgress "Checking $NAME at port $PORT"
        checkPidFile
        case $? in
            0)    echoOK "not running" ;;
            1)    echoOK "$(printPid) running" ;;
            2)    echoError "process dead but RUNNING_PID file exists" ;;
        esac
    ;;
    stop)
        echoProgress "Stopping $NAME"
        checkPidFile
        case $? in
            0)    echoOK "wasn't running" ;;
            1)    PRINTED_PID=$(printPid)
                kill_softly `cat $PID_FILE`
                if [ $? != 0 ]
                then
                    echoError "$PRINTED_PID doesn't belong to $NAME! Human intervention is required."
                    exit 1
                else
                    echoOK "$PRINTED_PID stopped"
                fi ;;
            2)    echoError "RUNNING_PID exists but process is already dead" ;;
        esac
    ;;

    restart)
        $0 stop $NAME $PORT
        if [ $? == 0 ]
        then
            $0 start $NAME $PORT
            if [ $? == 0 ]
            then
                # Success
                exit
            fi
        fi
        exit 1
    ;;
esac
