# Automine
Management tool for Minecraft Bedrock Dedicated Server for Linux

### Installation

Automine expects to be in /opt/automine/, to change this you need modify the automine.sh script.

To install Automine simply clone the Automine repo to /opt/automine, then create a symlink to the automine.sh file like so:

`cd /opt/`

`git clone git@github.com:alaphoid/automine.git`

`ln -s /opt/automine/automine.sh /usr/bin/automine`

Run 'automine --help' for more information.
