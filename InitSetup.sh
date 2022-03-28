#!/bin/sh
#######Check That User is INFORMIX
#####
HOMEDIR=/home/informix
LIB=/opt/informix/scripts/Day1ServerBuild
BASEDIR=/opt/informix/scripts/Day1ServerBuild
INDIR=$BASEDIR/RUN_INDICATORS
BACKUPS=/opt/informix/backups
OBBUILDIR=$BACKUPS/OBscripts
LOG=$BASEDIR/LOGS/DAY1Init.LOG
donotPrint=1
##donotPrint=0

function echo_it ()
{

if [ $donotPrint -eq 1 ]
  then
  echo -n "`date` : " >>  $LOG
  echo $1 >> $LOG
else
  echo -n "`date` : " | tee -a  $LOG
  echo $1 | tee -a $LOG
fi

}
function checkuser
{
export _username=`echo $USER`
if [ $_username != "informix" ]
then
echo_it " "
echo_it "  E R R O R : SCRIPT ${_scriptName} MUST BE RUN AS USER INFORMIX"
echo_it "  YOUR ARE CURRENTLY: $_username "
echo_it "                          "
echo_it "====== ABORTING RUN ======"
exit 100
fi

}

#...parameters passed
if [[ $# -lt 1 ]] ; then
    echo_it "Expecting 1 Parameter - USAGE: InitSetup.sh primary or InitSetup.sh secondary "
    echo_it "Rerun with proper usage"
exit 
fi
if [ $1 = "primary" ] 
then
continue
elif [ $1 = "secondary" ]
then
continue
else
echo_it "Expecting 1 Parameter - USAGE: InitSetup.sh primary or InitSetup.sh secondary "
echo_it "Rerun with proper usage"
fi
 


checkuser
clear 
echo_it "RUNNING INITIAL SETUP OF INIT DAY 1 "
echo_it "                                   "                                    
cd $HOMEDIR
#Check to make sure there is only 1 .cfg type file in the directory otherwise script cannot determine which is the correct golden source .cfg file
 configcount=`ls -l |grep -c .cfg`
 if [ $configcount -gt 1 ]
  then
    echo_it "WARNING :  Found more than one type .cfg config file. Cannot determine which is the correct golden source .cfg file" 
    echo_it "           There can be ONLY 1 .cfg golden source file resident in the /home/informix directory.  Correct and rerun this setup "
  exit
 fi

#CHECK FOR NECESSARY FILES
if [ ! -r $HOMEDIR/*.cfg ]
then
echo_it "WARNING: Missing Golden Source .cfg config file- name must be in the form STATE-INITIALS.cfg-  output from onstat -g cfg command - then move to $HOMEDIR and rerun this setup"
##exit 100
fi

if [ ! -r $HOMEDIR/OBScripts.tar ]
then
echo_it "WARNING: Missing OBScripts.tar file - DOWNLOAD Latest OB Refresh Scripts- move to $HOMEDIR and rerun this setup"
echo_it "         The OB Refresh Scripts: 1. must be Downloaded 2. then create a TAR archive of the scripts with the name \"OBScipts.tar\" 3. move to $HOMEDIR Directory on this primary host" 
exit 100
elif [ ! -r $HOMEDIR/DBInitDay1.tar ]
then
echo_it "WARNING: Missing DBInitDay1.tar file - Retrieve tar file - move to $HOMEDIR and rerun this setup"
exit 100
elif [ ! -r $HOMEDIR/goldendistrib.tar ]
then
echo_it "WARNING: Missing goldendistrib.tar file - Retrieve tar file - move to $HOMEDIR and rerun this setup"
##exit 100   - this is not considered an unrecoverable error - we do not exit
fi

if [ -r $HOMEDIR/*.cfg ]
then
UOWNER=`stat -c '%U' $HOMEDIR/*.cfg` 
  if [ $UOWNER != "informix" ]
   then
     echo_it "WARNING:  File `echo $HOMEDIR/*.cfg` must be owned by user informix"
     echo_it "Change Ownership to informix and re-run this setup"
   exit
  fi
fi

UOWNER=`stat -c '%U' $HOMEDIR/OBScripts.tar` 
if [ $UOWNER != "informix" ]
then
echo_it "WARNING:  File $HOMEDIR/OBScripts.tar must be owned by user informix"
echo_it "Change Ownership to informix and re-run this setup"
exit
fi

UOWNER=`stat -c '%U' $HOMEDIR/DBInitDay1.tar` 
if [ $UOWNER != "informix" ]
then
echo_it "WARNING:  File $HOMEDIR/DBInitDay1.tar must be owned by user informix"
echo_it "Change Ownership to informix and re-run this setup"
exit
fi


echo_it "Making Run Directories:"
sleep 1
[ ! -d $INDIR ] && mkdir -p $INDIR

if [ $1 = "primary" ]
then
mkdir -p $OBBUILDIR
mkdir -p $HOMEDIR/dist 
mkdir -p /opt/informix/scripts/Day1ServerBuild
mkdir -p /opt/informix/scripts/Day1ServerBuild/LOGS
elif [ $1 = "secondary" ]
then
mkdir -p /opt/informix/scripts/Day1ServerBuild
mkdir -p /opt/informix/scripts/Day1ServerBuild/LOGS
fi

echo_it "Copying Files to Run Directory"
sleep 1
if [ $1 = "primary" ]
then
cp $HOMEDIR/OBScripts.tar /informix/logs/OBSCRIPTS
cp $HOMEDIR/goldendistrib.tar $HOMEDIR/dist
fi

cp $HOMEDIR/DBInitDay1.tar $LIB
cp  $HOMEDIR/*.cfg $LIB/Goldconfig.cfg
echo_it "Untar the script Archives "
sleep 2
echo_it "DBInitDay1.tar:"
sleep 1
cd $LIB 
tar -xvf  $LIB/DBInitDay1.tar 
touch $INDIR/InitSetupRun

if [ $1 = "primary" ]
then
echo_it "OBScripts.tar:"
cd $OBBUILDIR
tar -xvf $OBBUILDIR/OBScripts.tar --strip-components 3 > /dev/null
echo_it "goldendistrib.tar:"
tar -xvf $HOMEDIR/dist/goldendistrib.tar 
fi

echo_it "                                          "
echo_it "********************************"                               
echo_it "****** SETUP COMPLETED  ********" 
echo_it "********************************"                               
echo_it "                                          "
exit 0
##echo_it "Ready to run: \"Run_as_Root.sh\" followed by \"InitDay1.sh\" - Located in $LIB "
##echo_it "NOTE: RUN FIRST ON SECONDARY FOLLOWED BY PRIMARY SERVER"
echo_it "                                                        "
