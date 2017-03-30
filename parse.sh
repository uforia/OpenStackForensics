#!/bin/bash

CSV=output.txt
INSTANCEUUIDS=instanceuuids.txt
CINDERUUIDS=cinderuuids.txt
LOG=combined.log
TIMEFRAME='2014-04-21 [12|13|14|15|16|17|18|19|20|21|22|23]'
USERS="\
e75374ede9834b41919d07e6a311401c,admin \
253f4b4150a94040ac288bf8fd0dfea7,animall \
61b3f2a57e3041fa9cc956408bf2433b,macos \
847707c76b4940a99a221a3ce4f2dce4,helipadsales \
ab9892d9cb7e40078be899c34c20b020,ubishaft \
2c159dbdd4ba4f1587ecd502afbe1fe1,frikandelfun \
90dfd53b7d924654bff1f78d81591766,silkpath \
"

# Parse logs and determine UUIDs for Cinder and Instance

rm -f "$CSV"
echo "Username,UserID,Instance UUID,Project UUID,Creation Time(s),Start Time(s),Delete Time(s),Termination Time(s),Instance RAM,Instance Disk,Instance VCPU(s)" >> $CSV

for user in $USERS
do
	username=`echo $user|cut -d',' -f2`
	userid=`echo $user|cut -d',' -f1`
	#echo "User:			$username ($userid)"
	#echo "================================================================================"
	ENTRIES=`grep "$TIMEFRAME" $LOG|grep $userid|grep -o 'instance: [0-9a-zA-Z-]*' |sort -u|cut -d' ' -f2|sed '/^$/d'`
	for uuid in $ENTRIES
	do
		#echo "Instance UUID:		$uuid"
		PUUID=`grep "INFO nova.osapi_compute.wsgi.server" $LOG|grep $uuid|cut -d'[' -f2-|cut -d']' -f1|cut -d' ' -f3|sort -u`
		CTIME=`grep "Attempting to build [0-9]* instance" $LOG|grep $userid|grep $uuid|cut -d':' -f2-|cut -d' ' -f1-3|cut -c2-|sed s/' '/'.'/g`
		STIME=`grep "Starting instance..." $LOG|grep $userid|grep $uuid|cut -d':' -f2-|cut -d' ' -f1-3|cut -c2-|sed s/' '/'.'/g`
		DTIME=`grep "Deleting instance" $LOG|grep $userid|grep $uuid|cut -d':' -f2-|cut -d' ' -f1-3|cut -c2-|sed s/' '/'.'/g`
		TTIME=`grep "Terminating instance" $LOG|grep $userid|grep $uuid|cut -d':' -f2-|cut -d' ' -f1-3|cut -c2-|sed s/' '/'.'/g`
		SPECS=`grep "Attempting claim: " $LOG|grep $userid|grep $uuid|cut -d':' -f6-|cut -c2-`
		echo -n "$username,$userid,$uuid," >> $CSV
		if [ ! -z "$PUUID" ]; then
			for item in $PUUID
			do
				echo -n "$item " >> $CSV
				#echo "Project UUID(s):		$item"
			done
		fi
		echo -n "," >> $CSV
		if [ ! -z "$CTIME" ]; then
			for item in $CTIME
			do
				echo -n "$item " >> $CSV
				#echo "Creation time:		$item"
			done
		fi
		echo -n "," >> $CSV
		if [ ! -z "$STIME" ]; then
			for item in $STIME
			do
				echo -n "$item " >> $CSV
				#echo "Starting time:		$item"
			done
		fi
		echo -n "," >> $CSV
		if [ ! -z "$DTIME" ]; then
			for item in $DTIME
			do
				echo -n "$item " >> $CSV
				#echo "Deletion time:		$item"
			done
		fi
		echo -n "," >> $CSV
		if [ ! -z "$TTIME" ]; then
			for item in $TTIME
			do
				echo -n "$item " >> $CSV
				#echo "Termination time:	$item"
			done
		fi
		echo -n "," >> $CSV
		if [ ! -z "$SPECS" ]; then
			echo -n "$SPECS" >> $CSV
			#echo "Instance specs:		$SPECS"
		fi
		echo -e "" >> $CSV
	done
	echo ",,,,,,," >> $CSV
	#echo "================================================================================"
done

# Find Cinder volumes that were created during timeframe
echo "Cinder Volume UUID,Volume Username,Volume User UUID,Volume Name,Volume Size,Volume Project ID,Attached Instance UUIDs,Creation Time(s),Attach Time(s),Delete Time(s),Update Time(s),Termination Time(s)" >> $CSV
CVOLS=`grep "$TIMEFRAME" $LOG|grep -o "Creating iscsi_target for: .*" $LOG|cut -d'-' -f2-|sort -u`
for uuid in $CVOLS
do
	echo -n "$uuid," >> $CSV
	#echo "Cinder UUID:		$uuid"
	VOLUID=`grep $uuid $LOG|grep "$TIMEFRAME"|grep -o "'user_id': u'[a-z|A-Z|0-9]*'"|sort -u|cut -d\' -f4`
	VOLUSER=`echo $USERS|grep -o "$VOLUID,[a-zA-Z0-9]* "|cut -d',' -f2`
	if [ -z $VOLUSER ]; then
		VOLUSER='Unknown'
	fi
	VOLNAME=`grep $uuid $LOG|grep -o "'display_name': u.*"|cut -d\' -f4|sort -u`
	VOLPROJ=`grep $uuid $LOG|grep "$TIMEFRAME"|grep -o "'project_id': u'[a-z|A-Z|0-9]*'"|sort -u|cut -d\' -f4`
	VOLCTIME=`grep "INFO cinder.volume.flows.create_volume" $LOG|grep -v "created successfully"|grep $uuid|cut -d':' -f2-|cut -d' ' -f1-3|cut -c2-|sed s/' '/'.'/g`
	VOLSIZE=`grep "INFO cinder.volume.flows.create_volume" $LOG|grep -v "created successfully"|grep $uuid|cut -d',' -f2|cut -d' ' -f3`GB
	VOLATIME=`grep "AUDIT cinder.api.v1.volumes" $LOG|grep $uuid|grep 'attach_time'|grep -v "'attach_time': None"|grep -o "'attach_time': u.*"|cut -d\' -f4|sort -u|sed s/'T'/'.'/g`
	VOLATTACH=`grep "AUDIT cinder.api.v1.volumes" $LOG|grep $uuid|grep 'instance_uuid'|grep -v "'instance_uuid': None"|grep -o "'instance_uuid': u.*"|cut -d\' -f4|sort -u|sed s/'T'/'.'/g`
	VOLDTIME=`grep "AUDIT cinder.api.v1.volumes" $LOG|grep $uuid|grep 'deleted_at'|grep -v "'deleted_at': None"|grep -o "'deleted_at': u.*"|cut -d\' -f4|sort -u`
	VOLUTIME=`grep "AUDIT cinder.api.v1.volumes" $LOG|grep $uuid|grep 'updated_at'|grep -v "'updated_at': None"|grep -o "'updated_at': datetime.datetime(.*)"|cut -d'(' -f2|cut -d')' -f1|sort -u|sed s/' '/''/g`
	VOLTTIME=`grep "AUDIT cinder.api.v1.volumes" $LOG|grep $uuid|grep 'terminated_at'|grep -v "'terminated_at': None"|grep -o "'terminated_at': u.*"|cut -d\' -f4|sort -u`
	if [ -z "$VOLNAME" ]; then
		VOLNAME='Unknown'
	fi
	echo -n "$VOLUSER,$VOLUID,$VOLNAME,$VOLSIZE,$VOLPROJ," >> $CSV
	#echo -n "Instance(s) attached:		"
	if [ ! -z "$VOLATTACH" ]; then
		for item in $VOLATTACH
		do
			echo -n "$item " >> $CSV
		done
	else
		echo -n "Unknown" >> $CSV
	fi
	echo -n "," >> $CSV
	for item in $VOLCTIME
	do
		#echo "Creation time:		$item"
		echo -n "$item " >> $CSV
	done
	echo -n "," >> $CSV
	if [ ! -z "$VOLATIME" ]; then
		for item in $VOLATIME
		do
			#echo "Attach time:		$item"
			echo -n "$item " >> $CSV
		done
	else
		echo -n "Unknown" >> $CSV
	fi
	echo -n "," >> $CSV
	#echo -e ""
	#echo -n "Volume deleted:		"
	if [ ! -z "$VOLDTIME" ]; then
		for item in $VOLDTIME
		do
			echo -n "$item " >> $CSV
		done
	else
		echo -n "Unknown" >> $CSV
	fi
	echo -n "," >> $CSV
	#echo -e ""
	if [ ! -z "$VOLUTIME" ]; then
		for item in $VOLUTIME
		do
			#echo -n "Volume updated:		"
			YEAR=`echo $item|cut -d',' -f1`
			MONTH=`echo $item|cut -d',' -f2`
			if [ $MONTH -le 10 ]; then
				MONTH=0$MONTH
			fi
			DAY=`echo $item|cut -d',' -f3`
			if [ $DAY -le 10 ]; then
				DAY=0$DAY
			fi
			HOUR=`echo $item|cut -d',' -f4`
			if [ $HOUR -le 10 ]; then
				HOUR=0$HOUR
			fi
			MINUTE=`echo $item|cut -d',' -f5`
			if [ $MINUTE -le 10 ]; then
				MINUTE=0$MINUTE
			fi
			SECOND=`echo $item|cut -d',' -f6|sed s/' '/''/g`
			if [ $SECOND -le 10 ]; then
				SECOND=0$SECOND
			fi
			DATE="$YEAR-$MONTH-$DAY.$HOUR:$MINUTE:$SECOND"
			echo -n "$DATE " >> $CSV
		done
	else
		echo -n "Unknown" >> $CSV
	fi
	echo -n "," >> $CSV
	#echo -n "Volume terminated:		"
	if [ ! -z "$VOLTTIME" ]; then
		for item in $VOLTTIME
		do
			echo -n "$item " >> $CSV
		done
	else
		echo -n "Unknown" >> $CSV
	fi
	echo -n "," >> $CSV
	echo -e "" >> $CSV
	#echo "User (volume owner):	$VOLUSER(UUID: $VOLUID)"
	#echo "Volume name:		$VOLNAME"
	#echo "Volume Project ID:	$VOLPROJ"
	#echo -e ""
done
