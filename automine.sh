#!/bin/bash
###############################################################################
# Bedrock Dedicated Server Controler                                          #
###############################################################################

# NOTES ###################################################
# Nothing yet

# Inspiration from:
# https://jamesachambers.com/minecraft-bedrock-edition-ubuntu-dedicated-server-guide/

#LOAD COMMON LIBRARIES ###################################
# Get script dir, make it AUTOMINE_HOME
SCRIPT=$(readlink -f $0)
AUTOMINE_HOME="`dirname $SCRIPT`"

# Load the config and common stuff library
source $AUTOMINE_HOME/config
source $AUTOMINE_HOME/automine_lib

###########################################################

# DECLARE VARIABLES########################################
APPNAME="Automatic Minecraft Server Manager"
APPVER="1.0.0-4"
APPDATE="June 12, 2020"
EXE="automine"

args=("$@")
#debug=0

CMD=null
SERVER_WEBPAGE="https://minecraft.net/en-us/download/server/bedrock/"
BDS_URL="https://minecraft.azureedge.net/bin-linux"
USERNAME=`whoami`

# DEFINE FUNCTIONS ########################################
trapabort()
{
  # Signal Handler
  com_info "Execution aborted!"
  exit 1;
}

help()
{
if [ -n "$1" ];then echo -e "\n${RED}ERROR: ${1}${NC}";fi
cat << EOF

${WHITE}Usage: $EXE [OPTIONS]${NC}

$APPNAME
This script is used to manage the Bedrock Dedicated Server.

This tool can setup a systemd service for one or more bedrock servers, along
with a nightly job to restart/backup/update the server at 4:30am.  In all
setup options 'servername' refers to the name of the dir the bedrock server
files are in, not the name of the world. Different servers can then be
seperated by directory and have systemd config and update scripts for each.

Automine will run the server in a screen session named using the serverame
value given. At any time this screen session can be connected to by name to get
console access to the Minecraft server.

Version $APPVER $APPDATE

${WHITE}  --start [servername]${NC}
        Start the Minecraft Server.
${WHITE}  --stop [servername] [minutes]${NC}
        Stop the Minecraft Server, minutes are optional.
${WHITE}  --restart [servername] [minutes]${NC}
        Restart the Miinecraft Server, minutes are optional.
${WHITE}  --backup [servername] [minutes]${NC}
        This will take a complete backup of the server.
${WHITE}  --update [servername] [minutes]${NC}
        Update the Minecraft Server.  Minutes is optional and will define a
        warning period before the server is shutdown. This will also take a
        backup before updating.
${WHITE}  --service [add/remove] [servername]${NC}
        Add or remove the systemd service. This will also setup a nightly
        cronjob and sudoers config to allow this user to control the service.
${WHITE}  -s${NC}
        Disables some of the output, used for the service config.

${WHITE}  --download${NC}
        Download the latest server version if newer than what we have already.
${WHITE}  --help${NC}
        Display this help info.
${WHITE}  --version${NC}
        Display version information.

${WHITE}Examples:${NC}
To start a Minecraft Server
$EXE --start pangea

Setup service and update job for pangea
$EXE --service add pangea

Update the Minecraft server with 2 minutes shutdown warning
$EXE --update pangea 2


Report bugs to <jon@jnjschneider.com>

EOF
}

# ARGUMENT PARSING FUNCTION
argparse()
{
  c=0;skip=0
  for i in "${args[@]}"
  do
  i=`echo $i | tr [A-Z] [a-z]`
  ((c++))
  if [ $skip -eq 0 ];then
    case $i in
      --start)
        if [ "$CMD" != "null" ];then help "Conflicting parameters specified";exit 1;fi
        SERVERNAME=${args[$c]};switchtest $i $SERVERNAME
        CMD='start'
      	skip=1;;
      --stop)
        SERVERNAME=${args[$c]};switchtest $i $SERVERNAME
        CMD='stop'
        if [ "${args[$(($c+1))]}" != "" ];then
          COUNTDOWN=${args[$(($c+1))]};switchtest $i $COUNTDOWN
      	  skip=2
        else
          COUNTDOWN=1
      	  skip=1
        fi
        ;;
      --restart)
        if [ "$CMD" != "null" ];then help "Conflicting parameters specified";exit 1;fi
        SERVERNAME=${args[$c]};switchtest $i $SERVERNAME
        CMD='restart'
        if [ "${args[$(($c+1))]}" != "" ];then
          COUNTDOWN=${args[$(($c+1))]};switchtest $i $COUNTDOWN
      	  skip=2
        else
          COUNTDOWN=1
      	  skip=1
        fi
        ;;
      --backup)
        if [ "$CMD" != "null" ];then help "Conflicting parameters specified";exit 1;fi
        SERVERNAME=${args[$c]};switchtest $i $SERVERNAME
        CMD='backup'
        if [ "${args[$(($c+1))]}" != "" ];then
          COUNTDOWN=${args[$(($c+1))]};switchtest $i $COUNTDOWN
      	  skip=2
        else
          COUNTDOWN=1
      	  skip=1
        fi;;
      --update)
        if [ "$CMD" != "null" ];then help "Conflicting parameters specified";exit 1;fi
        SERVERNAME=${args[$c]};switchtest $i $SERVERNAME
        CMD='update'
        if [ "${args[$(($c+1))]}" != "" ];then
          COUNTDOWN=${args[$(($c+1))]};switchtest $i $COUNTDOWN
      	  skip=2
        else
          COUNTDOWN=1
      	  skip=1
        fi;;
      --service)
        if [ "$CMD" != "null" ];then help "Conflicting parameters specified";exit 1;fi
        CMD="service_${args[$c]}"
        SERVERNAME=${args[$(($c+1))]};switchtest $i $SERVERNAME
        skip=2
        ;;
      -s)
        SERVICE=1;;
      --download)
        if [ "$CMD" != "null" ];then help "Conflicting parameters specified";exit 1;fi
        CMD='download'
        ;;
      --debug)
        debug=1;;
      --help)
        help;exit;;
      --version)
        echo $EXE $APPVER;exit;;
      *)
        help "Invalid option";exit 1;;
    esac
  else
    ((skip--))
  fi
  done

}

# SWITCHTEST FUNCTION
# This function is used by argparse to determine if an expected argument is
# an argument or the next switch paramater.
switchtest(){
  if [ -z `echo $2 | egrep '^[^-]'` ];then
    help "Missing argument for parameter: $1"
    exit 1
  fi
}

bds_start(){
  com_debug "Running: bds_start"
  # Does systemd config exist for this SERVERNAME
  if [ -z "$SERVICE" ] && [ $SYSD -eq 1 ];then
    # Use systemd to start the service
    com_info "Starting Minecraft server ($SERVERNAME)"
    sudo /usr/bin/systemctl start minecraft-$SERVERNAME
  else
    # Function to start the server
    # Check if server is already started
    if screen -list | grep -q "$SERVERNAME"; then
      com_info "Server is already started ($SERVERNAME)"
    else
      cd ${MINECRAFT_HOME}/${SERVERNAME}
      com_info "Starting Minecraft server ($SERVERNAME)"
      if [ -z "$SERVICE" ];then
        echo
        echo "  ${yellow}To view window type 'screen -r $SERVERNAME'"
        echo "  To minimize the window and let the server run in the background, press"
        echo "  Ctrl+a then Ctrl+d.  Lookup docs on GNU Screen for more details.${NC}"
      fi
      if ! screen -dmS $SERVERNAME /bin/bash -c "LD_LIBRARY_PATH=${MINECRAFT_HOME}/${SERVERNAME} ${MINECRAFT_HOME}/${SERVERNAME}/bedrock_server";then
        com_error "Error starting Minecraft Server ($SERVERNAME)" 1
      fi
    fi
  fi
}

bds_stop(){
  # Function to stop the server
  com_debug "Running bds_stop"
  com_debug "Countdown mins: $COUNTDOWN"
  if [ -z "$SERVICE" ] && [ $SYSD -eq 1 ];then
    # Use systemd to start the service
    case $1 in
      restart)
        type="Restarting";;
      *)
        type="Stopping";;
    esac
    com_debug "bds_stop: Set type to $type"
    # Check if server is running
    if ! screen -list | grep -q "$SERVERNAME"; then
      if [ "$type" == "Stopping" ];then
        com_info "Server is not currently running ($SERVERNAME)"
      fi
    else
      if [ $COUNTDOWN -gt 0 ];then
        com_debug "Countdown greater then 0: $COUNTDOWN"
        while [ $COUNTDOWN -gt 0 ]; do
          if [ $COUNTDOWN -eq 1 ]; then
            echo "Waiting for 60 seconds ..."
            screen -Rd $SERVERNAME -X stuff "say $type server in 60 seconds...$(printf '\r')"
            sleep 30;
            echo "Waiting for 30 seconds ..."
            screen -Rd $SERVERNAME -X stuff "say $type server in 30 seconds...$(printf '\r')"
            sleep 20;
            echo "Waiting for 10 seconds ..."
            screen -Rd $SERVERNAME -X stuff "say $type server in 10 seconds...$(printf '\r')"
            sleep 10;
          else
            echo "Waiting for $COUNTDOWN more minutes ..."
            screen -Rd $SERVERNAME -X stuff "say $type server in $COUNTDOWN minutes...$(printf '\r')"
            sleep 60;
          fi
          com_debug "Decrementing countdown"
          ((COUNTDOWN--))
        done
        echo
      fi
      com_info "Stopping Minecraft server ($SERVERNAME)"
      sudo /usr/bin/systemctl stop minecraft-$SERVERNAME
    fi
  else
     #Stop the server

    com_info "Stopping Minecraft server ($SERVERNAME)"
    screen -Rd $SERVERNAME -X stuff "say Stopping server...$(printf '\r')"
    screen -Rd $SERVERNAME -X stuff "stop$(printf '\r')"

    # Wait up to 20 seconds for server to close
    stopcheck=0
    while [ $stopcheck -lt 20 ]; do
      if ! screen -list | grep -q "$SERVERNAME"; then
        break
      fi
      sleep 1
      ((stopcheck++))
    done
    # Force quit if server is still open
    if screen -list | grep -q "$SERVERNAME"; then
      com_info "Minecraft server still hasn't stopped after 20 seconds, closing screen manually"
      screen -S $SERVERNAME -X quit
    fi
    com_info "Minecraft server stopped ($SERVERNAME)"
  fi
}

get_latest_bds_ver(){
  com_debug "Running get_latest_bds_ver"
  # Retrieve latest version of Minecraft Bedrock dedicated server
  wget -q -O ${DOWNLOADS}/version.html $SERVER_WEBPAGE
  local downloadURL=`grep -o 'https://minecraft.azureedge.net/bin-linux/[^"]*' ${DOWNLOADS}/version.html`
  local downloadFile=`echo "$downloadURL" | sed 's#.*/##'`
  local MINECRAFT_VER=`echo $downloadFile | sed -e 's/bedrock-server-//g' -e 's/.zip//g'`
  rm -f ${DOWNLOADS}/version.html
  echo $MINECRAFT_VER
}

download_bds(){
  com_debug "Running download_bds"
  # Check if a minecraft dir foor this version already esists, create it if not
  if [ -d "${DOWNLOADS}/bedrock-server-${MINECRAFT_VER}" ];then
    com_info "Already have the latest version downloaded"
  else
    com_info "Creating directory: ${MINECRAFT_HOME}/downloads/bedrock-server-${MINECRAFT_VER}"
    mkdir ${DOWNLOADS}/bedrock-server-${MINECRAFT_VER}
    if [ $? -ne 0 ];then
      com_error "Couldn't create ${MINECRAFT_HOME}/downloads/bedrock-server-${MINECRAFT_VER}" 1
    fi
    cd ${DOWNLOADS}/bedrock-server-${MINECRAFT_VER}

  # Download the server archive if necessary
    if [ ! -f "bedrock-server-${MINECRAFT_VER}.zip" ];then
      com_info "Downloading bedrock-server-${MINECRAFT_VER}.zip"
      wget -q --show-progress https://minecraft.azureedge.net/bin-linux/bedrock-server-${MINECRAFT_VER}.zip
      com_info "Unpacking files";echo
      unzip -q bedrock-server-${MINECRAFT_VER}.zip
      rm -f bedrock-server-${MINECRAFT_VER}.zip
      # Remove unneeded stuff
      rm -f ${BASE_CFG}/*
      mkdir ${BASE_CFG}/worlds

      base_configs="server.properties whitelist.json permissions.json"
      for config in $base_configs;do
        mv $config ${BASE_CFG}/
      done
      rm -f bedrock_server_realms.debug
      cp -R worlds/* ${BASE_CFG}/worlds/
      rm -rf worlds/*
    fi
  fi
  # Verify the needed files are there
  if [ ! -f "${DOWNLOADS}/bedrock-server-${MINECRAFT_VER}/bedrock_server" ];then
    com_error "Critical files missing in the download, exiting"
    com_error "Check ${DOWNLOADS}/bedrock-server-${MINECRAFT_VER}/" 1
  fi
}

backup_server(){
  com_debug "Running backup_server"
  com_info "Backing up server to: ${BACKUPS}/${SERVERNAME}_${TIME}.tar.gz"
  cd $MINECRAFT_HOME
  if ! tar -pzcf ${BACKUPS}/${SERVERNAME}_${TIME}.tar.gz $SERVERNAME;then com_error "There was an error backing up $SERVERNAME" 1;fi
  # Delete backups older then BACKUP_AGE variable
  find ${BACKUPS}/ -name *.tar.gz -mtime +${BACKUP_AGE} -delete
  if [ $? -ne 0 ];then com_error "Cleaning up old backups";fi
}

# PROGRAM START ###########################################

# Capture and handle signals
trap 'trapabort' HUP INT QUIT TERM

argparse

if [ "$CMD" == "null" ];then
  help "Missing argument";exit 1
fi

# Echo header
if [ -z "$SERVICE" ];then
  echo;echo "${YELLOW}$APPNAME - $APPVER ${NC}";echo
fi

# Create downloads dir if it doesn't exist
if [ ! -d $DOWNLOADS ];then
  mkdir -p $DOWNLOADS 2> /dev/null || com_error "Failed to create $DOWNLOADS, check permissions" 1
fi

if [ ! -d $BACKUPS ];then
  mkdir -p $BACKUPS 2> /dev/null || com_error "Failed to create $BACKUPS, check permissions" 1
fi

if [ ! -d $BASE_CFG ];then
  mkdir -p $BASE_CFG 2> /dev/null || com_error "Failed to create $BASE_CFG, check permissions" 1
fi

/usr/bin/systemctl status minecraft-$SERVERNAME >/dev/null && SYSD=1 || SYSD=0

com_debug "SYSD: $SYSD"

# Check SERVERNAME is valid
if [ ! -f "${MINECRAFT_HOME}/${SERVERNAME}/bedrock_server" ];then
  read -p "Specified server $SERVERNAME doesn't exist yet, create it? (y/N): " ans
  echo
  case $ans in
    Y|y)
      com_info "Creating server $SERVERNAME"
      com_info "Checking for the latest version of Minecraft Bedrock server..."
      MINECRAFT_VER=`get_latest_bds_ver`
      com_info "Latest version: $MINECRAFT_VER"
      # Download the latest version
      download_bds
      if [ -d "${MINECRAFT_HOME}/${SERVERNAME}/worlds" ];then
        com_error "Possibly detected worlds in the target dir, aborting" 1
      fi
      rm -rf ${MINECRAFT_HOME}/${SERVERNAME}
      cp -R ${DOWNLOADS}/bedrock-server-${MINECRAFT_VER} ${MINECRAFT_HOME}/${SERVERNAME} || com_error "There was an error setting up the server, check permissions" 1
      cp -R ${BASE_CFG}/* ${MINECRAFT_HOME}/${SERVERNAME}/ || com_error "Failed copying base configs into $SERVERNAME, check permissions" 1
      # Update world name in server.properties
      sed -i "s/server-name=Dedicated Server/server-name=${SERVERNAME}/g" ${MINECRAFT_HOME}/${SERVERNAME}/server.properties
      sed -i "s/level-name=Bedrock level/level-name=${SERVERNAME}/g" ${MINECRAFT_HOME}/${SERVERNAME}/server.properties

      ;;
    *)
      com_error "Could not find server: $SERVERNAME" 1
      ;;
  esac
fi

TIME=`date +%Y.%m.%d_%H-%M`

case $CMD in
  start)
    bds_start;;
  stop)
    bds_stop;;
  restart)
    bds_stop restart
    bds_start;;
  backup)
    # Stop the server with restart notice
    bds_stop restart
    backup_server
    bds_start
    com_info "Backup is complete"
    ;;
  update)
    com_info "Checking for the latest version of Minecraft Bedrock server..."
    MINECRAFT_VER=`get_latest_bds_ver`
    com_info "Latest version: $MINECRAFT_VER"
    # Download the latest version
    download_bds
    # Stop the server with restart notice
    bds_stop restart
    # Run backup function
    backup_server
    cd $MINECRAFT_HOME
    # Rename current servername with a date
    if ! mv $SERVERNAME ${SERVERNAME}_${TIME};then com_error "There was an error backing up $SERVERNAME" 1;fi
    # Copy latest ver to SERVERNAME
    com_info "Updating Bedrock Dedicated Server files"
    if ! cp -R ${DOWNLOADS}/bedrock-server-${MINECRAFT_VER} ${MINECRAFT_HOME}/${SERVERNAME};then
      com_error "There was an error updating the files" 1
    fi
    cd ${MINECRAFT_HOME}/${SERVERNAME}
    # Copy World and configs
    com_info "Restoring configs"
    if ! cp ${MINECRAFT_HOME}/${SERVERNAME}_${TIME}/server.properties ./;then com_error "Error restoring server.properties" 1;fi
    if ! cp ${MINECRAFT_HOME}/${SERVERNAME}_${TIME}/whitelist.json ./;then com_error "Error restoring whitelist.json" 1;fi
    if ! cp ${MINECRAFT_HOME}/${SERVERNAME}_${TIME}/permissions.json ./;then com_error "Error restoring permissions.json" 1;fi
    com_info "Restoring worlds"
    if ! cp -R ${MINECRAFT_HOME}/${SERVERNAME}_${TIME}/worlds ./;then com_error "Error restoring worlds" 1;fi
    chmod 755 bedrock_server

    cd $MINECRAFT_HOME
    rm -rf ${MINECRAFT_HOME}/${SERVERNAME}_${TIME}
    bds_start
    com_info "Update is complete"
    ;;
  service_add)
    # Install systemd config
    com_info "Installing /etc/systemd/system/minecraft-${SERVERNAME}.service"
cat << EOF > /tmp/minecraft-${SERVERNAME}.service
[Unit]
Description=Minecraft Server - $SERVERNAME
After=network-online.target

[Service]
User=${USERNAME}
WorkingDirectory=${MINECRAFT_HOME}
Type=forking
ExecStart=/bin/bash /usr/bin/automine -s --start $SERVERNAME
ExecStop=/bin/bash /usr/bin/automine -s --stop $SERVERNAME 0
GuessMainPID=no
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
EOF
    sudo cp /tmp/minecraft-${SERVERNAME}.service /etc/systemd/system/minecraft-${SERVERNAME}.service
    rm -f /tmp/minecraft-${SERVERNAME}.service
    sudo /usr/bin/systemctl daemon-reload
    sudo /usr/bin/systemctl enable minecraft-${SERVERNAME}
    if [ ! -f "/usr/bin/automine" ];then
      sudo ln -s $SCRIPT /usr/bin/automine
    fi
    if [ $? -eq 0 ];then
      com_info "Service 'minecraft-${SERVERNAME}' is installed and enabled"
      com_info "Run 'systemctl start minecraft-${SERVERNAME}' to start"
    else
      com_error "There was a problem enabling the minecraft-${SERVERNAME} service" 1
    fi

    # Add sudoers permissions for user to control the service

cat << EOF > /tmp/sudoers_minecraft-${SERVERNAME}
${USERNAME} ALL=NOPASSWD: /usr/bin/systemctl start minecraft-$SERVERNAME
${USERNAME} ALL=NOPASSWD: /usr/bin/systemctl stop minecraft-$SERVERNAME
${USERNAME} ALL=NOPASSWD: /usr/bin/systemctl restart minecraft-$SERVERNAME
${USERNAME} ALL=NOPASSWD: /usr/bin/systemctl status minecraft-$SERVERNAME
EOF

    sudo cp /tmp/sudoers_minecraft-${SERVERNAME} /etc/sudoers.d/minecraft-${SERVERNAME}
    rm -f /tmp/sudoers_minecraft-${SERVERNAME}
    com_info "Added SUDO config for $USERNAME to control minecraft-${SERVERNAME} service"

    # Setup nightly update job
    crontab -l > /tmp/crontab_minecraft-${SERVERNAME}
    grep "Update minecraft server: ${SERVERNAME}" /tmp/crontab_minecraft-${SERVERNAME} > /dev/null
    if [ $? -ne 0 ];then
cat << EOF >> /tmp/crontab_minecraft-${SERVERNAME}
# Update minecraft server: ${SERVERNAME}
30 4 * * * /usr/bin/automine --update ${SERVERNAME} 1
EOF

      crontab < /tmp/crontab_minecraft-${SERVERNAME}
    fi
    rm -f /tmp/crontab_minecraft-${SERVERNAME}
    com_info "Added user crontab entry to update minecraft-${SERVERNAME}"
    ;;
  service_remove)
    # Remove systemd config
    com_info "Stopping the service and removing systemd config"
    if [ ! -f "/etc/systemd/system/minecraft-${SERVERNAME}.service" ];then
      com_error "Service config does not exist, can't auto remove" 1
    fi
    sudo /usr/bin/systemctl stop minecraft-${SERVERNAME}
    if [ $? -ne 0 ];then
      com_error "Problem stopping the service" 1
    fi
    sudo /usr/bin/systemctl disable minecraft-${SERVERNAME}
    sudo rm -f /etc/systemd/system/minecraft-${SERVERNAME}.service
    sudo /usr/bin/systemctl daemon-reload
    com_info "Service minecraft-${SERVERNAME} is removed"
    
    # Remove sudoers config
    sudo rm -f /etc/sudoers.d/minecraft-${SERVERNAME}
    com_info "Removed SUDO config for minecraft-${SERVERNAME} service"

    # Remove nightly update crontab
    crontab -l > /tmp/crontab_minecraft-${SERVERNAME}
    egrep -v "Update minecraft server: ${SERVERNAME}|--update ${SERVERNAME}" /tmp/crontab_minecraft-${SERVERNAME} > /tmp/crontab_minecraft-${SERVERNAME}_edit
    crontab < /tmp/crontab_minecraft-${SERVERNAME}_edit
    rm -f /tmp/crontab_minecraft-${SERVERNAME}*
    com_info "Removed user crontab entry to update minecraft-${SERVERNAME}"
    echo
    com_info "Server dir was left alone: ${MINECRAFT_HOME}/${SERVERNAME}"
    ;;
  download)
    com_info "Checking for the latest version of Minecraft Bedrock server..."
    MINECRAFT_VER=`get_latest_bds_ver`
    com_info "Latest version: $MINECRAFT_VER"
    download_bds
    ;;
  *)
    help "Incorrect options provided"
    exit 1
    ;;
esac
if [ -z "$SERVICE" ];then echo;fi
exit

# CHANGE LOG ##################################################################
# June 12, 2020 - v1.0.0-4
# - Numerous improvements to auto service adding
#
# June 3, 2020 - v1.0.0-3
# - Reverted to dynamic dir
# - Fixed bad option in date command
#
# June 2, 2020 - v1.0.0-2
# - Default install location: /opt/automine/
# - Added some debug output
# - Static paths for libraries and config
#
# May 27, 2020 - v1.0.0-1
# - Ready for use
# - Added service/cronjob/sudoers setup
#
# May 21, 2020 - v0.0.1-0
# - First release
#

