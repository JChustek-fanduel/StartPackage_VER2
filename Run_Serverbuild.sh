#!/bin/sh
#######################################################################################################################################################################
#########
#######################################################################################################################################################################
######### Run_Serverbuild.sh 
#
#       This Script functions as the Front End to the  InitDay1.sh Server build script process - Linux version
#
#       Script facilitates the automation of the building of a new Informix Server Database Instance
#       Utilizes a yaml config file: BuildConfig.yaml
#       NOTE: When the  BuildConfig.yaml file is placed in /home/informix - it will be used and override the previous build config file
#
#
#######################################################################################################################################################################

SERVERNAMEnode1=$1
SERVERNAMEnode2=$2
MAXCHUNKS=$3
PRIMARY_SERVERNAME=$4
SECONDARY_SERVERNAME=$5
###restartmode=$6
NODE1_IP=$7
NODE2_IP=$8
BASEDIR=/opt/informix/scripts/Day1ServerBuild
HOME=/home/informix
####YAML CONFIG FILE
CONFIG=$BASEDIR/BuildConfig.yml
CONFIGNAME=BuildConfig.yml
CONFIGWRK=$BASEDIR/buildconfig-workfile
LOG=$BASEDIR/LOGS/DAY1Init.LOG
BACKUPS=/opt/informix/backups
OBBUILDIR=$BACKUPS/OBscripts
INDIR=$BASEDIR/RUN_INDICATORS
stop_all_processing="no"

#######This indicator forces the setup routine to re-run every time program is executed ########
#######Mainly used for testing and special cases                                        ########
####### Should normally be set to 0 where it will only run setup if setup has not yet  #########
####### been run.  Set to Always_run_initsetup=1 when you want to force it to setup    #########
####### for instance when you have introduced a new version of a script or program     #########

##Always_run_initsetup=0
Always_run_initsetup=1

##donotPrint=1
donotPrint=0



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

#######Check That User is INFORMIX
#####
function checkuser
{
export _username=`echo $USER`
if [ $_username != "informix" ]
then
echo
echo "  E R R O R : SCRIPT ${_scriptName} MUST BE RUN AS USER INFORMIX"
echo "  YOUR ARE CURRENTLY: $_username "
echo
echo "  ====== ABORTING RUN ======"
exit 100
fi

}

####Check for existence of the YAML CONFIG file *****

function parse_config {

if [ -r /home/informix/$CONFIGNAME ]
then
echo_it "Found the Config File Override in $HOME - Program will use this yml Config file: $CONFIGNAME"
sleep 2
cp /home/informix/$CONFIGNAME $CONFIG
fi

#Now parse fields and set the parameters
#Convert file   
#The following code will be replaced by the YQ command processor once available on the system
sed -e 's/:[^:\/\/]/="/g;s/$/"/g;s/ *=/=/g' $CONFIG > /tmp/configtemp 
####$BASEDIR/buildconfig-workfile is the configuration work file which contains the massaged fields to be inserted into variables
### Now massage this workfile to strip out any comments so as not to confuse the grep statements which are pulling values
grep -v "#" /tmp/configtemp > $CONFIGWRK 

####Note GRABBING_FREQUENCY is set by the mainline routine when it only needs to use Frequency directives to control running the build process 
#####    GRABBING_FREQUENCY is set to 1 when the mainline only wants to set the frequency variables

if [ $GRABBING_FREQUENCY -eq 0 ]
then
###########################
#Process mode Section
###########################

##continuous 
mode_continuous=`grep "_continuous" $CONFIGWRK`
CONTINUOUS=`echo "$mode_continuous" | awk -F'"' '{print $2}'`
if [ "$CONTINUOUS" = "yes" ]
then
echo_it "continuous is set to yes - running in continuous mode"  
elif [ "$CONTINUOUS" = "no" ]
then
echo_it "continuous is set to no - running one time"  
else
echo_it "Invalid value set for continueous mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#interactive
mode_interactive=`grep "_interactive" $CONFIGWRK`
INTERACTIVE=`echo "$mode_interactive" | awk -F'"' '{print $2}'`
if [ "$INTERACTIVE" = "yes" ]
then
echo_it "interactive is set to yes - running in interactive mode"  
elif [ "$INTERACTIVE" = "no" ]
then
echo_it "interactive is set to no - running autonomously"  
else
echo_it "Invalid value set for interactive mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi
fi

#frequency
mode_frequency=`grep "_frequency" $CONFIGWRK`
FREQUENCY=`echo "$mode_frequency" | awk -F'"' '{print $2}'`
if [ "$FREQUENCY" = "daily" ]
then
echo_it "frequency is set to run daily - running in daily run mode"  
elif [ "$FREQUENCY" = "weekly" ]
then
echo_it "frequency is set to run weekly - running in weekly run mode"  
elif [ "$FREQUENCY" = "adhoc" ]
then
echo_it "frequency is set to run adhoc - running in on demand run mode"  
else
echo_it "Invalid value set for frequency mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#start_week_cycle_now
mode_startnow=`grep "_start_week" $CONFIGWRK`
MODE_STARTNOW=`echo "$mode_startnow" | awk -F'"' '{print $2}'`
if [ "$MODE_STARTNOW" = "yes" ]
then
echo_it "Mode Start Now for weekly cycle is set to yes - Starting Server build Now"  
start_build="yes"
elif [ "$MODE_STARTNOW" = "no" ]
then
echo_it "Mode Start Now is set to no - weekly cycle remains in effect"  
start_build="no"
else
echo_it "Invalid value set for start_week_cycle_now mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

##########Validate the weekly start build now setting ####################
if [ "$MODE_STARTNOW" = "yes" ]
then
  if [ "$FREQUENCY" != "weekly" ]
    then
    echo_it "ERROR: Invalid value set for start_week build cycle now  in the BuildConfig.yml Configuration File - Set to start_weekcycle but NOT in weekly MODE - fix Config File and then re-run -ABORT 100"
    exit 100
    fi

fi

#adhoc_build_start
adhoc_build_start=`grep "_adhoc" $CONFIGWRK`
MODE_ADHOCSTART=`echo "$adhoc_build_start" | awk -F'"' '{print $2}'`
if [ "$MODE_ADHOCSTART" = "yes" ]
then
echo_it "Mode Adhoc Build Start Now is set to yes - Starting Server build Now"  
touch $INDIR/start_adhoc_build
elif [ "$MODE_ADHOCSTART" = "no" ]
then
echo_it "Mode Adhoc Build Start  Now is set to no - Adhoc mode remains in effect without starting build"  
rm -f $INDIR/start_adhoc_build
else
echo_it "Invalid value set for start_adhoc_build mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

##########Validate the adhoc build setting ####################
if [ "$MODE_ADHOCSTART" = "yes" ]
then
  if [ "$FREQUENCY" != "adhoc" ]
   then
    echo_it "ERROR: Invalid value set for start_adhoc_build mode in the BuildConfig.yml Configuration File - Set to start_adhoc but NOT in ADHOC MODE - fix Config File and then re-run -ABORT 100"
    exit 100
    fi
fi
  

#Stop all processing
mode_stopnow=`grep "_stop_all" $CONFIGWRK`
MODE_STOPNOW=`echo "$mode_stopnow" | awk -F'"' '{print $2}'`
if [ "$MODE_STOPNOW" = "yes" ]
then
echo_it "Mode Stop all is set to yes - STOPPING ALL BUILD SERVICES"  
stop_all_processing="yes"
elif [ "$MODE_STOPNOW" = "no" ]
then
echo_it "Mode Start Now is set to no - The Server Build processing cycle remains in effect"  
stop_all_processing="no"
else
echo_it "Invalid value set for stop_all mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

if [ $GRABBING_FREQUENCY -eq 0 ]
then
#displaymessages
mode_displaymessages=`grep "_displaymessages" $CONFIGWRK`
DISPLAYMESSAGES=`echo "$mode_displaymessages" | awk -F'"' '{print $2}'`
if [ "$DISPLAYMESSAGES" = "yes" ]
then
echo_it "displaymessages is set to yes - running in displaymessages mode"  
donotPrint=0
elif [ "$DISPLAYMESSAGES" = "no" ]
then
echo_it "displaymessages is set to no - Messages will be silenced "  
donotPrint=1
else
echo_it "Invalid value set for displaymessages mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#run_onlyonprimary
mode_run_onlyonprimary=`grep "_run_onlyonprimary" $CONFIGWRK`
RUN_ONLY_ON_PRIMARY=`echo "$mode_run_onlyonprimary" | awk -F'"' '{print $2}'`
if [ "$RUN_ONLY_ON_PRIMARY" = "yes" ]
then
echo_it "run_onlyonprimary is set to yes - Running the build from only the Primary Server"  
elif [ "$RUN_ONLY_ON_PRIMARY" = "no" ]
then
echo_it "run_onlyonprimary is set to no - Running the build manually from both the Primary and Secondary servers"  
else
echo_it "Invalid value set for displaymessages mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#########################
#Process Server Section
#########################

#servernamenode1
SERVERS_servernamenode1=`grep "_servernamenode1" $CONFIGWRK`
servernamenode1=`echo "$SERVERS_servernamenode1" | awk -F'"' '{print $2}'`
echo_it "servernamenode1 is set to $servernamenode1"  

#servernamenode2
SERVERS_servernamenode2=`grep "_servernamenode2" $CONFIGWRK`
servernamenode2=`echo "$SERVERS_servernamenode2" | awk -F'"' '{print $2}'`
echo_it "servernamenode2 is set to $servernamenode2"  

#primary_servername
SERVERS_primary_servername=`grep "_primary_servername" $CONFIGWRK`
primary_servername=`echo "$SERVERS_primary_servername" | awk -F'"' '{print $2}'`
echo_it "primary servername is set to $primary_servername"  

#secondary_servername
SERVERS_secondary_servername=`grep "_secondary_servername" $CONFIGWRK`
secondary_servername=`echo "$SERVERS_secondary_servername" | awk -F'"' '{print $2}'`
echo_it "secondary servername is set to $secondary_servername"  

#management_servername
SERVERS_management_servername=`grep "_management_servername" $CONFIGWRK`
management_servername=`echo "$SERVERS_management_servername" | awk -F'"' '{print $2}'`
echo_it "The management servername is set to $management_servername"  

###########################
#General Run Section
###########################

#Grab the Location of the OBSCRIPTS Staging Directory
#general_obscript_stage_dir=`grep "_obscript_stage_dir" $CONFIGWRK`
#obscript_stage_dir=`echo "$general_obscript_stage_dir" | awk -F'"' '{print $2}'`
#echo_it "The OBSCRIPTS Staging Directory is set to $obscript_stage_dir"  

#restartmode
general_restartmode=`grep "_restartmode" $CONFIGWRK`
restartmode=`echo "$general_restartmode" | awk -F'"' '{print $2}'`
echo_it "RESTART MODE is set to $restartmode"  

#node1_ip
general_node1_ip=`grep "_node1_ip" $CONFIGWRK`
node1_ip=`echo "$general_node1_ip" | awk -F'"' '{print $2}'`
echo_it "node1_ip is set to $node1_ip"  

#node2_ip
general_node2_ip=`grep "_node2_ip" $CONFIGWRK`
node2_ip=`echo "$general_node2_ip" | awk -F'"' '{print $2}'`
echo_it "node2_ip is set to $node2_ip"  

#maxchunks
general_maxchunks=`grep "_maxchunks" $CONFIGWRK`
maxchunks=`echo "$general_maxchunks" | awk -F'"' '{print $2}'`
echo_it "maxchunks is set to $maxchunks"  

#template state
general_template_state=`grep "_template_state" $CONFIGWRK`
template_state=`echo "$general_template_state" | awk -F'"' '{print $2}'`
echo $template_state > $INDIR/state_parm
echo_it "The Template State is set to:  $template_state"  

#bypass_onconfig_check
general_bypass_onconfig_check=`grep "_bypass_onconfig_check" $CONFIGWRK`
bypassconfigchk=`echo "$general_bypass_onconfig_check" | awk -F'"' '{print $2}'`

if [ "$bypassconfigchk" = "yes" ]
then
echo_it "bypass_onconfig_check is set to yes - Will NOT check the onconfig file"  
elif [ "$bypassconfigchk" = "no" ]
then
echo_it "bypass_onconfig_check is set to no - The onconfig file will be checked"  
else
echo_it "Invalid value set for bypass_onconfig_check in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#bypass_download
general_bypass_download=`grep "_bypass_download" $CONFIGWRK`
bypassdownload=`echo "$general_bypass_download" | awk -F'"' '{print $2}'`

if [ "$bypassdownload" = "yes" ]
then
echo_it "bypass_download is set to yes - BYPASS is Set on - Will NOT download the full backup level 0 from AWS"  
elif [ "$bypassdownload" = "no" ]
then
echo_it "bypass_download is set to no - The Full Backup level 0 will be downloaded from AWS"  
else
echo_it "Invalid value set for bypass_download in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#bypass_refresh
general_bypass_refresh=`grep "_bypass_refresh" $CONFIGWRK`
bypassrefresh=`echo "$general_bypass_refresh" | awk -F'"' '{print $2}'`

if [ "$bypassrefresh" = "yes" ]
then
echo_it "bypass_refresh is set to yes - BYPASS is Set on - Will NOT RUN the Refresh Database Steps - Bypassing Refresh"  
elif [ "$bypassrefresh" = "no" ]
then
echo_it "bypass_refresh is set to no -  Will NOT Bypass the Refresh Steps - The Refresh Database Steps will RUN"  
else
echo_it "Invalid value set for bypass_refresh in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#Service Account Name - connects to scp over any necessary files including the OBScripts tar file
general_svc_acct=`grep "_svc_acct" $CONFIGWRK`
SVC_ACCT=`echo "$general_svc_acct" | awk -F'"' '{print $2}'`
echo_it "The Service Account is set to: $SVC_ACCT"  
fi

}


function get_golden_dist {
#User informix keys set up between management server and new server are pre-requisite
#scp the Golden Distribution tar file archive to the home directory  

if [ ! -d $HOME/dist ]
then
mkdir -p $HOME/dist
fi

scp $SVC_ACCT@$management_servername:/home/informix/dist/goldendistrib.tar $HOME/dist  >> $LOG 2>&1
if  [ $? -eq 0 ]
then
echo_it "The Golden Distributions successfylly transferred over from the management server - Refreshing Scripts Again"
touch $INDIR/golden_dists_grabbed
else
echo_it "ERROR: a Problem was encountered while Golden Distributions tar archive was transferred over from the management server "
echo_it "ERROR: The program may be able to use a previous copy of the Golden Distribution TAR Archive "

fi

cd $HOME/dist
#Now extract the golden distributions from the archive
tar -xvf $HOME/dist/goldendistrib.tar

if  [ $? -eq 0 ]
then
echo_it "The Golden Distributions successfylly extracted from tar archive goldendistrib.tar"
else
echo_it "ERROR: a Problem was encountered while Golden Distributions tar archive was being extracted to $HOME/dist directory - Investigate "
fi

}

function get_OB_Scripts {

#User informix keys set up between management server and new server are pre-requisite
#scp the OB Scripts archive to the home directory  

if [ ! -r $INDIR/OBscripts_grabbed ]
then
echo_it "Potential new build -The OB SCRIPTS have NOT yet been transferred over from the management server - Refreshing Scripts Now"
else
echo_it "The OB SCRIPTS have previously been transferred over from the management server - Refreshing Scripts Again"
fi

scp $SVC_ACCT@$management_servername:/tmp/OBscripts.tar $HOME  >> $LOG 2>&1
if  [ $? -eq 0 ]
then
echo_it "The OB SCRIPTS have been successfylly transferred over from the management server - Refreshing Scripts Again"
touch $INDIR/OBscripts_grabbed
#Now Rename the tar file to the expected name used by the downstream setup scripts
mv $HOME/OBscripts.tar $HOME/OBScripts.tar
else
echo_it "ERROR: a Problem was encountered while OB Scripts were transferred over from the management server "
echo_it "ERROR: The program may be able to use a previous copy of the OB Scripts TAR Archive "

fi

}

function BUILD_SERVER {

### Remove certain indicators
rm -f $INDIR/InitDay1_started.ind
rm -f $INDIR/InitDay1_ended.ind
rm -f $INDIR/level_0_downloaded
rm -f $INDIR/start_daily_build.ind
rm -f $INDIR/start_weekly_build.ind
rm -f $INDIR/start_adhoc_build.ind
rm -f $INDIR/InitDay1_ended.ind
rm -f $INDIR/OBscripts_grabbedd
rm -f $INDIR/OB_load_completed.ind
rm -f $INDIR/load.max_time_exceeded.ind
rm -f $INDIR/OB_load_started.ind
rm -f $INDIR/OB_unload_completed.ind
rm -f $INDIR/OB_unload_started.indnd
rm -f $INDIR/PROGRESS_checkpoint.txt
rm -f $INDIR/PROGRESS_DETAILED_checkpoint.txt

#Check to see if the Init Day 1 Software has been set up yet through running the InitSetup.sh program
if [[ ! -d $BASEDIR ]] ; then
echo_it "The Initial Installation package has not been run - Setting Up the Installation Package Now"
###Must grab the ob scripts tar package which is used by the InitSetup.sh program for initial setup
mkdir -p $INDIR
mkdir -p $OBBUILDIR
##get_OB_Scripts  too early to run this - wait for config to be parsed first
##get_golden_dist too early to run this - wait for confi to be parsed first
$HOME/InitSetup.sh primary
touch $INDIR/first_time_thru
echo_it "First time through for this Server build - executed the InitSetup.sh program"
touch $BASEDIR/Setup_completed.flg
elif [ $Always_run_initsetup -eq 1 ]
then
   $HOME/InitSetup.sh primary
   echo_it "Executed the InitSetup.sh program again - due to the Always_run_initsetup indicator set to 1"
##   get_golden_dist too early to run
else
echo_it "The Initial Installation package setup has previously run - this phase is being skipped"
[ ! -d $INDIR ] && mkdir -p $INDIR
[ ! -d $OBBUILDIR ] && mkdir -p $OBBUILDIR
##get_golden_dist too early to run
fi


if [ -r /home/informix/$CONFIGNAME ]
then
echo_it "Found the Configuration File Override in $HOME - Program will use this yml Config file: $CONFIGNAME"
sleep 2
cp /home/informix/$CONFIGNAME $CONFIG
fi

if [ -r $CONFIG ]
then
##tput clear
echo_it "The Automated Server Build PROCESS is RUNNING"   
sleep 1
echo_it "PARSING VALID CONFIGURATION FILE" 
parse_config
else
echo_it "ERROR: YAML format BuildConfig.yml Configuration File NOT FOUND - Should be a valid file either in /home/informix or $BASEDIR" 
exit 100
fi

#Check to see if the OBSCRIPTS Have been grabbed yet from the management server

if [ -r $INDIR/OBscripts_grabbed ]
then
echo_it "The OB SCRIPTS have previously been transferred over from the management server - Refreshing Scripts Again"
else
echo_it "Potential new build -The OB SCRIPTS have NOT yet been transferred over from the management server - Refreshing Scripts Now"
fi

if [ -r $INDIR/first_time_thru ]
then
echo_it "The OB Scripts tar has previously been moved and unpacked since this is the first build for this server - skipping" 
rm -f $INDIR/first_time_thru
get_OB_Scripts
get_golden_dist
###Test for the init setup having been run - if not then unpack the OBscripts tar anyway just in case
[ ! -r $INDIR/InitSetupRun ] && cd $OBBUILDIR; tar -xvf $OBBUILDIR/OBScripts.tar --strip-components 3 > /dev/null
echo_it "Prepared OBscripts for processing - untar operation"
else
get_OB_Scripts
#Now move and unpack the OB SCripts TAR
cp $HOME/OBScripts.tar $OBBUILDIR
######echo "untarring obscripts"
cd $OBBUILDIR
tar -xvf $OBBUILDIR/OBScripts.tar --strip-components 3 > /dev/null
echo_it "Prepared OBscripts for processing - untar operation"
#####NOW GRAB THE GOLDEN DISRIBUTIONS
get_golden_dist

fi

################################################################
#####Comment out exit after testing ################
#############exit

##clear
#######################################################################################################################
#NOW MASSAGE THE restartmode, node1_ip,and node2_ip variables to be passed as true null values to the pararmeter line
# Translate from upper to lowercasse so it doesn't matter whether  the config is coded with lower or upper case
#######################################################################################################################
newrestart=`echo $restartmode  | tr '[:upper:]' '[:lower:]'`
restartmode=$newrestart
echo "restartmode is : $restartmode"

##if [ ! -z $restartmode ]
##then
## if [ $restartmode = "null" ]
##     then
##     unset restartmode
##      restartmode=" "
##fi
##fi

newnode1_ip=`echo $node1_ip  | tr '[:upper:]' '[:lower:]'`
node1_ip=$newnode1_ip
echo "node1_ip is: $node1_ip "

##if [ ! -z $node1_ip ]
## then
##   if [ $node1_ip = "null" ]
##       then
##       unset node1_ip
##fi
##fi

newnode2_ip=`echo $node2_ip  | tr '[:upper:]' '[:lower:]'`
node2_ip=$newnode2_ip
echo "node2_ip is: $node2_ip "

##if [ ! -z $node2_ip ]
## then
##  if [ $node2_ip = "null" ]
##      then
##      unset node2_ip
##fi
##fi

cd $BASEDIR
echo_it "Executing the InitDay1.sh process " 
####Now executing the InitDay1.sh script in the Background
nohup $BASEDIR/InitDay1.sh $servernamenode1 $servernamenode2 $maxchunks $primary_servername $secondary_servername $restartmode $node1_ip $node2_ip &

########## Run as Background Job and check to Make sure the job is Running ##############################
CHECKJOB=`ps -eaf|grep -c "InitDay1.sh $SERVERNAMEnode1"`
if [ $CHECKJOB -eq 2 ]
    then
      echo -n   "Successfully Started: The InitDay1 Build Process is Running:   "  >> $LOG
      date  >> $LOG
      sleep 5
  else
    echo_it "WARNING: The Server Build and Load Process did not Launch Correctly and is no longer running:-  Check for Additional Information:"
  fi

while [ $CHECKJOB -eq 2 ]
do

CHECKJOB=`ps -eaf|grep -c "InitDay1.sh $SERVERNAMEnode1"`
echo_it "The DAY 1 SERVER BUILD is still in Progress...... "
sleep 60
done

###Check for the InitDay1.sh build complete indicator which is set in the InitDay1.sh program##
if  [ -r $INDIR/InitDay1_ended.ind ]
 then
     Day1RC=`cat $INDIR/InitDay1_ended.ind`
    if [ $Day1RC -eq 0 ]
##if [ $? -eq 0 ]
      then 
      echo_it "Server Build Completed" 
      echo_it "Successful Server Build" 
#####      exit 0  do not exit
    else
     echo_it "The Server Build has Ended with Issues" 
     echo_it "Check LOGS and Messages for more Information - then rerun" 
     exit 3 
     fi
  else
echo_it "The Server Build Crashed and  Ended with Issues" 
echo_it "Check LOGS and Messages for more Information - then rerun" 
exit 3
fi

}

function frequency_control {

#Pull frequency from the build config yaml file
GRABBING_FREQUENCY=1
####Will now grab frequency, start_week_cycle_now, and adhoc_build_start
parse_config
GRABBING_FREQUENCY=0
case $FREQUENCY in
       "daily")  
                echo_it "FREQUENCY has been set for the Server Build to Run Once Per Day "
                Run_Frequency=1
                          ;;
       "weekly")  
                echo_it "FREQUENCY has been set for the Server Build to Run Once Per Week "
                Run_Frequency=2

                          ;;
       "adhoc")  
                echo_it "FREQUENCY has been set for the Server Build to Run in adhoc mode - on demand "
                Run_Frequency=3

                          ;;
       *)  echo_it "Error in FREQUENCY parameter in frequency_control function- Invalid Value: $FREQUENCY"
            esac



}

function check_config {
###This function checks for whether there has been a change to the config file since
###the program started.  If there has been a config change it will update the process
###flow accordingly

GRABBING_FREQUENCY=1
####Will now grab frequency, start_week_cycle_now, and adhoc_build_start
parse_config
GRABBING_FREQUENCY=0

####We now have the latest setting for variable start_build
####start_build="yes"

}

#####################MAINLINE######################################

####################################################################
####If this is the First time through then set indicator and
####execute the initsetup.sh program on the primary ################
####################################################################
########### Execute the initsetup.sh program  ######################
####################################################################
##clear
####FIRST CHECK TO MAKE SURE THIS IS BEING RUN BY USER INFORMIX ####
checkuser
rm -f $BASEDIR/nohup.out
[ ! -d "/opt/informix/scripts/Day1ServerBuild/LOGS" ] && mkdir -p /opt/informix/scripts/Day1ServerBuild/LOGS
[ ! -d $INDIR ] && mkdir -p $INDIR

#### BUILD_SERVER ########
while [ ! -r /home/informix/HALT_SERVERBUILD ]
do
frequency_control

#frequency_control has parsed the yaml config file
#If we find the stop_all_processing field set to yes
#then set HALT_SERVERBUILD and exit 
if [ $stop_all_processing = "yes" ]
  then
     touch $HOME/HALT_SERVERBUILD
    break
fi

case $Run_Frequency in 
###Daily cycle
       1)      echo_it "The RUN FREQUENCY MODE is set to run once Daily" 
               BUILD_SERVER 
               # sleep 
##               sleep 86400
#####Wait for crontab job to set the once daily indicator to run the daily job                
               echo_it "Going into Wait Mode for the Next Daily Build Cycle"
               while [ ! -r $INDIR/start_daily_build.ind  ]  
                 do
                  sleep 60
                 done
               ;;
###Weekly cycle
       2)      echo_it "The RUN FREQUENCY MODE is set to run once Weekly" 
               BUILD_SERVER  
               # sleep control - sleep for 1 day - wake up and check for indicator to start running immediately
               #                 The routine will do this for a total of seven days - after 7 days will run
               #                 calls check_config  routine which looks for the start_week_cycle_now: yes
               #                 If it finds the setting at yes - it will start the build immediately and reset back to 
               #                 waiting for the 7 days unless the config is set again to yes.
##               cyclenum=0 
##               while [ $cyclenum -lt 8 ]  
##               do 
##               sleep 86400
##               cyclenum=$((cyclenum+1))  
##               echo_it "The WEEKLY CYCLE is ACTIVE - Currently Waited for $cyclenum day(s) - will run after 7 days"
##    examine config file to see if the process weekly cycle now is set to YES - if set to yes then it will start to build server immediately                
##    Also if the stop_all_processing field is set to yes then we HALT the build immediately
               echo_it "Going into Wait Mode for the Next WEEKLY Build Cycle"
               while [ ! -r $INDIR/start_weekly_build.ind  ]  
                 do
                  sleep 60
########The commented out code allows for the dynamic changing of the mode from running to stop
##                   check_config
##                   if [ $stop_all_processing = "yes" ]
##                    then
##                      touch $HOME/HALT_SERVERBUILD
##                      break
##                   fi
                 done
             
##                   if [ $stop_all_processing = "yes" ]
##                    then
##                  echo_it "Halting Processing due to config setting"
##                    else
##                  echo_it "WEEKLY CYCLE Setting has indicated to start weekly build now ...Starting the Server Build Now." 
##                   fi

               ;;
###Adhoc cycle -daemon mode
       3)  echo_it "The RUN FREQUENCY MODE is set to ADHOC - Will run upon trigger set"  
           echo_it "Waiting for the adhoc start indicator: start_adhoc_build to be set -then the Server build will start"   
           echo_it "Going into Wait Mode for the Next ADHOC Build Cycle"
               while [ ! -r $INDIR/start_adhoc_build.ind ]
           do
           sleep 60
           done
              
          BUILD_SERVER 
          rm -f $INDIR/start_adhoc_build.ind
          ;;
       *)  echo_it "Error in Run Frequency parameter in mainline- Invalid Value: $Run_Frequency"

          esac

done

echo_it "The Run_Serverbuild.sh Daemon is Exiting due to FLAG SETTING: /home/informix/HALT_SEVERBUILD is set"
exit 100
