# Automine
Management tool for Minecraft Bedrock Dedicated Server for Linux

### Installation

To install Automine simply clone the Automine repo to a dir (example: ~/), copy the automine dir to where it will go, then create a symlink to the automine.sh file like so:

`git clone https://github.com/alaphoid/automine.git`
`mkdir /opt/`
`cp -Rp automine /opt/`
`ln -s /opt/automine/automine.sh /usr/bin/automine`

Do not run automine from the clone dir, you may lose your config changes in the future.

Make sure the user you plan to run the server as has read/write access to the folder you choose, and has sudoer permissions to create a service and start/stop the minecraft server.  You should run all automine commands as this user.

Run 'automine --help' for more information.

I typically clone this into the home dir of the user I want the service to run as.

### Configuration

You need to configure 2 main things, the server dir and the backup dir.  The server directory is the parent directory of where your server will be located.

Example, if you set your server dir to /mnt/minecraft and then create a server called 'testserver' the Bedrock Dedicated Server files will be in /mnt/minecraft/testserver/

Automine will create the server directory if required as well as a systemd service for the server.

The backup dir is simply where the nightly backup will be stored, this should ideally be on a different disk than the server itself.  You can also configure how many backups you wish to keep.

### Other Notes

I may create a tgz release at some point and include an installer, but don't hold your breath.
