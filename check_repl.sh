#!/bin/bash

### CHECK ARGUMENTS ###

if [[ "$#" -eq "0" ]]
  then
    echo -e "No arguments supplied"
    echo -e "usage: $0 --m MASTER_IP [--mp MASTER_PORT] --s SLAVE_IP [--sp SLAVE_PORT] --cn SLAVE_CONNECTION_NAME --user USER --passwd PASSWORD"
    exit 1
fi

if [[ "$#" -lt 10 ]]; then
    echo "Illegal number of arguments set only $# arguments"
    echo -e "usage: $0 --m MASTER_IP [--mp MASTER_PORT] --s SLAVE_IP [--sp SLAVE_PORT] --cn SLAVE_CONNECTION_NAME --user USER --passwd PASSWORD"
    exit 1
fi


### SET VARIABLES ###

args=("$@")
j=1
for ((i=0; i < $#; i++))
{
  if [[ -z "${args[j]}" ]]
    then
      echo "No argument supplied"
      break
  fi

case ${args[i]} in
    "--m")
	    MASTER=${args[j]}
      ;;
    "--mp")
	    MASTER_PORT=${args[j]}
      ;;
    "--s")
	    SLAVE=${args[j]}
      ;;
    "--sp")
	    SLAVE_PORT=${args[j]}
      ;;
    "--cn")
	    CONNECTION_NAME=${args[j]}
      ;;
    "--user")
	    MYSQL_USER=${args[j]}
      ;;
    "--passwd")
	    PASSWORD=${args[j]}
      ;;
    *)
      ;;
  esac

  ((j++))

}

: "${MASTER_PORT:=3306}"
: "${SLAVE_PORT:=3306}"

### PRINT VARIABLE VALUES ###

echo "MASTER=$MASTER"
echo "MASTER_PORT=$MASTER_PORT"
echo "SLAVE=$SLAVE"
echo "SLAVE_PORT=$SLAVE_PORT"
echo "CONNECTION_NAME=$CONNECTION_NAME"
echo "MYSQL_USER=$MYSQL_USER"


MYSQL_MASTER="/usr/bin/mysql -u $MYSQL_USER -h $MASTER -P $MASTER_PORT -p$PASSWORD"
MYSQL_SLAVE="/usr/bin/mysql -u $MYSQL_USER -h $SLAVE -P $SLAVE_PORT -p$PASSWORD"

### END VARIABLES DEFINITION ###


### CHECK REPLICATION STATUS FUNCTION ###

function check_reptication {

STATUS_MASTER=$($MYSQL_MASTER -e "SHOW MASTER STATUS\G")
STATUS_SLAVE=$($MYSQL_SLAVE -e "SHOW SLAVE 'PARSER' STATUS\G")

### SLAVE ###
LAST_ERRNO=$(grep "Last_Errno" <<< "$STATUS_SLAVE" | awk '{ print $2 }')
LAST_ERROR=$(grep "Last_Error" <<< "$STATUS_SLAVE" | awk '{ print $2 }')
SECONDS_BEHIND_MASTER=$( grep "Seconds_Behind_Master" <<< "$STATUS_SLAVE" | awk '{ print $2 }')
IO_IS_RUNNING=$(grep "Slave_IO_Running" <<< "$STATUS_SLAVE" | awk '{ print $2 }')
SQL_IS_RUNNING=$(grep "Slave_SQL_Running" <<< "$STATUS_SLAVE" | awk '{ print $2 }')
SLAVE_MASTER_LOG_FILE=$(grep " Master_Log_File" <<< "$STATUS_SLAVE" | awk '{ print $2 }')
SLAVE_READ_POS=$(grep "Read_Master_Log_Pos" <<< "$STATUS_SLAVE" | awk '{ print $2 }')

### MASTER ###
MASTER_LOG_FILE=$(grep " File" <<< "$STATUS_MASTER" | awk '{ print $2 }')
MASTER_LOG_POS=$(grep " Position" <<< "$STATUS_MASTER" | awk '{ print $2 }')

ERRORS=()

### PRINT VALUES ###
echo "LAST_ERRNO = $LAST_ERRNO"
echo "SECONDS_BEHIND_MASTER = $SECONDS_BEHIND_MASTER"
echo "IO_IS_RUNNING = $IO_IS_RUNNING"
echo "SQL_IS_RUNNING = $SQL_IS_RUNNING"
echo "SLAVE_MASTER_LOG_FILE = $SLAVE_MASTER_LOG_FILE"
echo "SLAVE_READ_POS = $SLAVE_READ_POS"
echo "MASTER_LOG_FILE = $MASTER_LOG_FILE"
echo "MASTER_LOG_POS = $MASTER_LOG_POS"

}

### COLLECT ERRORS FUNCTION ###

function check_for_errors {

## Check For Last Error ##
if [ "$LAST_ERRNO" != 0 ]
then
    ERRORS=("${ERRORS[@]}" "Error when processing relay log (Last_Errno)")
    ERRORS=("${ERRORS[@]}" "(Last_Error = $LAST_ERROR)")
fi

## Check if IO thread is running ##
if [ "$IO_IS_RUNNING" != "Yes" ]
then
    echo -e "I/O thread for reading the master's binary log is not running (Slave_IO_Running)"
    echo -e "Trying to fix it ..."
    $MYSQL_SLAVE -e "start slave '$CONNECTION_NAME' io_thread;"
    SLAVE_STATUS=($MYSQL_SLAVE -e "show slave '$CONNECTIN_NAME' status;")
    IO_IS_RUNNING=$(grep "Slave_IO_Running" <<< "$SLAVE_STATUS" | awk '{ print $2 }')
    if [ "$IO_IS_RUNNING" != "Yes" ]
    then 
	    ERRORS=("${ERRORS[@]}" "I/O thread for reading the master's binary log is not running (Slave_IO_Running)")
	    echo -e "Failed to start Slave_IO_thread, to try to fix it manually run this SQL: "
            echo -e "start slave '$CONNECTION_NAME' io_thread;"
    else 
	    echo -e "Success start Slave_IO_thread on slave $CONNECTION_NAME"
    fi

fi

## Check for SQL thread ##
if [ "$SQL_IS_RUNNING" != "Yes" ]
then
    ERRORS=("${ERRORS[@]}" "SQL thread for executing events in the relay log is not running (Slave_SQL_Running)")
fi

## Check how slow the slave is ##
if [ "$SECONDS_BEHIND_MASTER" == "NULL" ]
then
    ERRORS=("${ERRORS[@]}" "The Slave is reporting 'NULL' (Seconds_Behind_Master)")
elif [ "$SECONDS_BEHIND_MASTER" -gt 3600 ]
then
    ERRORS=("${ERRORS[@]}" "The Slave is mpre then hour behind the master (Seconds_Behind_Master)")
fi

}

### PRINT ALL ERRORS FUNCTION ###

function print_errors {
	printf '%s\n' "${ERRORS[@]}"
}

### MAIN BODY ###

check_reptication
check_for_errors
print_errors

### do until no errors found with 5 minute interval

while [[ "$SECONDS_BEHIND_MASTER" != "0" && "$SLAVE_READ_POS" != "$MASTER_LOG_POS" ]];
do

	echo "sleep 5 munutes ..."
	sleep 5m
	check_reptication
	check_for_errors
        print_errors

done


echo "all OK!"
