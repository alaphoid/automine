# Automine
Management tool for Minecraft Bedrock Dedicated Server for Linux

### Installation

To install Automine simply clone the Automine repo to a dir (example: /opt/automine), then create a symlink to the automine.sh file like so:

`cd /opt/`

`git clone git@github.com:alaphoid/automine.git`

`ln -s /opt/automine/automine.sh /usr/bin/automine`

Make sure the user you plan to run the server as has read/write access to the folder you choose.  you should also run all automine commands as this user.

Run 'automine --help' for more information.

I typically clone this into the home dir of the user I want the service to run as.
