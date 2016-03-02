#!/bin/bash

# ==============================================================================
# wasta-cinnamon-postinst.sh
#
#   This script is automatically run by the postinst configure step on
#       installation of wasta-cinnamon-*. It can be manually re-run, but
#       is only intended to be run at package installation.
#
#   2016-02-21 rik: initial script
#   2016-03-02 rik: modifying cinnamon version check
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Check to ensure running as root
# ------------------------------------------------------------------------------
#   No fancy "double click" here because normal user should never need to run
if [ $(id -u) -ne 0 ]
then
	echo
	echo "You must run this script with sudo." >&2
	echo "Exiting...."
	sleep 5s
	exit 1
fi

# ------------------------------------------------------------------------------
# Initial setup
# ------------------------------------------------------------------------------

echo
echo "*** Script Entry: wasta-cinnamon-postinst.sh"
echo

# Setup Diretory for later reference
DIR=/usr/share/wasta-cinnamon

# ------------------------------------------------------------------------------
# LightDM setup
# ------------------------------------------------------------------------------
if [ -e /usr/sbin/lightdm ];
then
    # tweak default lightdm logos to match wasta linux instead of Ubuntu:
    echo
    echo "*** Making LightDM adjustments"
    echo

    # set cinnamon logo to wasta-linux icon
    cp $DIR/resources/wl-round-22.png \
        /usr/share/unity-greeter/custom_cinnamon_badge.png

fi

# ------------------------------------------------------------------------------
# Cinnamon UI Adjustments
# ------------------------------------------------------------------------------
# Later can search for "wasta" in file to see where replaced.

# backup applet.js
if ! [ -e /usr/share/cinnamon/js/ui/applet.js.save ];
then
    cp /usr/share/cinnamon/js/ui/applet.js \
        /usr/share/cinnamon/js/ui/applet.js.save
fi

# Cinnamon panel: get rid of "Remove this applet" from right click
#   Below will remove text "Remove this applet" and will replace this._uuid with "wasta"
#   and this.instance_id with "wasta" (needed to set something or would crash cinnamon)
echo
echo "*** Disabling 'Remove this applet' in Cinnamon panel right-click menus"
echo
# remove display text
sed -i -e 's@Remove this applet@@' \
    /usr/share/cinnamon/js/ui/applet.js

# previous to 2.6, different sed needed
CINNAMON_OLD=$(cinnamon --version | grep -e "2.0" -e "2.2" -e "2.4")

# remove functionality: the ("wasta", "wasta") is a dummy variable so nothing
#   is called
if ! [ "$CINNAMON_OLD" ];
then
    # 2.6+: new syntax
    sed -i -e 's@\(.*removeAppletFromPanel(\).*\()\;\)@\1"wasta", "wasta"\2@' \
        /usr/share/cinnamon/js/ui/applet.js
else
    # 2.4(-): different syntax
    sed -i -e 's@\(.*removeAppletFromPanel,\) this\._uuid, this\.instance_id@\1 "wasta", "wasta"@' \
        /usr/share/cinnamon/js/ui/applet.js
fi

# backup panel.js
if ! [ -e /usr/share/cinnamon/js/ui/panel.js.save ];
then
    cp /usr/share/cinnamon/js/ui/panel.js \
        /usr/share/cinnamon/js/ui/panel.js.save
fi

# Cinnamon panel: remove "Looking Glass" entry from right click Troubleshoot
#   If line starts with 4 spaces and contains "addAction.*Looking Glass"
#   then add "// wasta " to beginning of lines  until "}" found
#   This works by being in form [address1] , [address2] [function].  It matches
#   [address1] and then will include in the buffer all lines until match of [address2]
#   Then the function is performed on the range of lines
echo
echo "*** Removing 'Looking Glass' from Cinnamon panel right-click menu"
echo
sed -i -e '/^    .*addAction.*Looking Glass/ , /\}/ s/^/\/\/ wasta /' \
    /usr/share/cinnamon/js/ui/panel.js

# Cinnamon panel: remove "Restore all settings to default" entry from right click Troubleshoot
#   If line starts with 4 spaces and contains "addAction.*Restore all settings to default"
#   then add "// wasta " to beginning of lines  until "    }" found (4 spaces first)

#   This works by being in form [address1] , [address2] [function].  It matches
#   [address1] and then will include in the buffer all lines until match of [address2]
#   Then the function is performed on the range of lines
echo
echo "*** Removing 'Restore all settings to default' from Cinnamon panel right-click menu"
echo
sed -i -e '/^    .*addAction.*Restore all settings to default/ , /^    \}/ s/^/\/\/ wasta /' \
    /usr/share/cinnamon/js/ui/panel.js

# Cinnamon panel: remove "Panel Edit mode" entry from right click
#   If line begins with 4 spaces and contains "addMenuItem(panelEditMode, then
#   add "// wasta " to beginning of line
echo
echo "*** Removing 'Panel Edit Mode' from Cinnamon panel right-click menu"
echo
sed -i -e '/^    .*addMenuItem(panelEditMode/ s/^/\/\/ wasta /' \
    /usr/share/cinnamon/js/ui/panel.js

# Menu Applet: Set "Menu Hover Delay" - NOTE: seems users have this replicated to
#   ~/.cinnamon/configs/menu@cinnamon.org/menu@cinnamon.org.json (this is created when cinnamon is
#   started if it doesn't exist).  So, have to loop through there too, setting
#   default AND value.
echo
echo "*** Setting Main Menu Hover Delay"
echo

sed -i -e 's@\(\"default\" \:\) 0@\1 200@' \
    /usr/share/cinnamon/applets/menu@cinnamon.org/settings-schema.json

# Panel-Launchers Applet: Set default apps
echo
echo "*** Setting Default Panel Launchers"
echo

sed -i -e 's@\(\"default\"\:\) \[.*@\1 \[\"firefox\.desktop\", \"thunderbird\.desktop\", \"nemo\.desktop\", \"libreoffice-writer\.desktop\", \"vlc\.desktop\"\]@' \
    /usr/share/cinnamon/applets/panel-launchers@cinnamon.org/settings-schema.json

# ------------------------------------------------------------------------------
# cinnamon-settings fixes
# ------------------------------------------------------------------------------
# ibus-setup: first remove: 
sed -i -e '\@ibus-setup@d' \
    /usr/share/cinnamon/cinnamon-settings/cinnamon-settings.py

# ibus-setup: add (need first element to be system-config-printer)
sed -i -e \
    'N;s@\(Keywords for filter.*\)\n\(.*system-config-printer\)@\1\n    [_("Keyboard Input Methods"),        "ibus-setup",                   "ibus-setup",         "hardware",       _("ibus, kmfl, keyman, keyboard, input, language")],\n\2@' \
    /usr/share/cinnamon/cinnamon-settings/cinnamon-settings.py

# ------------------------------------------------------------------------------
# ibus fixes
# ------------------------------------------------------------------------------
# set as system-wide default input method:
im-config -n ibus

# ------------------------------------------------------------------------------
# Dconf / Gsettings Default Value adjustments
# ------------------------------------------------------------------------------
echo
echo "*** Updating dconf / gsettings default values"
echo

# MAIN System schemas: we have placed our override file in this directory
# Sending any "error" to null (if key not found don't want to worry user)
glib-compile-schemas /usr/share/glib-2.0/schemas/ > /dev/null 2>&1 || true;

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------
echo
echo "*** Script Exit: wasta-cinnamon-postinst.sh"
echo

exit 0
