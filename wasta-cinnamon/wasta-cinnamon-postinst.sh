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
#   2016-03-30 rik: reverting removal of panelEditMode from right-click
#   2016-04-29 rik: cinnamon backgrounds cleanup
#   2016-07-27 rik: cinnamon-backgrounds-settings: symlink if doesn't exist
#   2016-09-28 rik: adding nemo permissions to evince (so can 'open containing
#       folder')
#   2016-10-07 rik: notifications applet: set to show empty tray by default
#   2016-10-31 rik: adding gtk scrollbar fix (so will scroll 'one page at a
#       time')
#   2017-03-15 rik: cleaning up cinnamon json sed selections (to match only
#       within the specified block of code)
#   2017-11-22 rik: cleaning up "send by email" nemo action logic
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

# LEGACY: undo tweak that removed panelEditMode from the Cinnamon panel.
#   If it isn't there and a user enables panelEditMode through cinnamon-settings
#   but then closes cinnamon settings, all applets remain inactive and can't
#   use the menu to get to cinnamon-settings to turn off panelEditMode!  Stuck!
sed -i -e 's@^// wasta\(.*panelEditMode\)@/1@' \
    /usr/share/cinnamon/js/ui/panel.js

# Menu Applet: Set "Menu Hover Delay" - NOTE: seems users have this replicated to
#   ~/.cinnamon/configs/menu@cinnamon.org/1.json (this is created when cinnamon is
#   started if it doesn't exist).  So, have to loop through there too, setting
#   default AND value.
# sed -i -e \
#    '\|"hover-delay" *:|,\|}|    s|\("value" *:\).*|\1 200|' ~/.cinnamon/configs/menu@cinnamon.org/1.json
echo
echo "*** Setting Main Menu Hover Delay"
echo

sed -i -e \
    '\|"hover-delay" *:|,\|}|    s|\("default" *:\).*|\1 200,|' \
    /usr/share/cinnamon/applets/menu@cinnamon.org/settings-schema.json

sed -i -e \
    '\|"show-category-icons" *:|,\|}|    s|\("default" *:\).*|\1 false,|' \
    /usr/share/cinnamon/applets/menu@cinnamon.org/settings-schema.json

# Panel-Launchers Applet: Set default apps
echo
echo "*** Setting Default Panel Launchers"
echo

sed -i -e 's@\(\"default\"\:\) \[.*@\1 \[\"firefox\.desktop\", \"thunderbird\.desktop\", \"nemo\.desktop\", \"libreoffice-writer\.desktop\", \"vlc\.desktop\"\]@' \
    /usr/share/cinnamon/applets/panel-launchers@cinnamon.org/settings-schema.json

# Notifications Applet: Set "show empty tray" to true
echo
echo "*** Notifications Applet: showing empty tray by default"
echo
# this will make all settings 'true' by default, but too hard to match only
# the desired setting: no problem as with Cinnamon 3.0 there are only 2
# settings in this file, and the other is already 'true' by default.
sed -i -e 's@\("default".*\)false@\1true@g' \
    /usr/share/cinnamon/applets/notifications@cinnamon.org/settings-schema.json

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
# cinnamon backgrounds cleanup
# ------------------------------------------------------------------------------
# Cinnammon Backgrounds Settings Panel groups by the last element of the
#   xml config files, eg. adwaita.xml will show as "Adwaita".  Problem is
#   all of the Ubuntu background xml files are named wily-wallpapers.xml,
#   xenial-wallpapers.xml, etc.  That means they ALL have the name "wallpapers"
#   in the Settings Panel.  Rename adding series name at end to make more clear.
rename -v -f -e 's@([a-zA-Z]*)-wallpapers.xml@$1-wallpapers-$1.xml@' \
    /usr/share/gnome-background-properties/*wallpapers.xml
rename -v -f -e 's@([a-zA-Z]*)-backgrounds.xml@$1-backgrounds-$1.xml@' \
    /usr/share/gnome-background-properties/*backgrounds.xml

# cinnamon 3.0 won't look at gnome-background-properties so
#   symlinking if not found
if ! [ -e /usr/share/cinnamon-background-properties ];
then
    ln -s /usr/share/gnome-background-properties \
        /usr/share/cinnamon-background-properties
fi

# ------------------------------------------------------------------------------
# ibus fixes
# ------------------------------------------------------------------------------
# set as system-wide default input method:
im-config -n ibus

# ------------------------------------------------------------------------------
# Allow nemo as a helper for evince
# ------------------------------------------------------------------------------

# delete 'wasta' lines (will re-create below)
sed -i -e '\@wasta@d' /etc/apparmor.d/usr.bin.evince

sed -i -e 's@\(/usr/bin/nautilus Cx -> sanitized_helper.*\)@\1\n  /usr/bin/nemo Cx -> sanitized_helper,     # wasta: Cinnamon/Nemo@' \
    /etc/apparmor.d/usr.bin.evince

# ------------------------------------------------------------------------------
# Fix scrollbars to go "one page at a time" with click
# ------------------------------------------------------------------------------
# global gtk-3.0 setting location:
sed -i -e '$a gtk-primary-button-warps-slider = false' \
    -i -e '\#gtk-primary-button-warps-slider#d' \
    /etc/gtk-3.0/settings.ini

# "per theme" adjustments:
sed -i -e 's@\(gtk-primary-button-warps-slider\).*@\1 = false@' \
    /usr/share/themes/Arc/gtk-2.0/gtkrc \
    /usr/share/themes/Arc-Dark/gtk-2.0/gtkrc \
    /usr/share/themes/Arc-Darker/gtk-2.0/gtkrc

# ------------------------------------------------------------------------------
# "Send by Email" patch
# ------------------------------------------------------------------------------
# Not sure which cinnamon package provides this functionality... was not there
# originally with Cinnamon 2.8/3.0 but is now there in 3.6
if ! [ -e /usr/share/nemo/actions/send-by-mail.nemo_action ];
then
    echo
    echo "*** Adding 'Send by Email' Nemo action"
    echo

    cp $DIR/resources/wasta-send-by-email.nemo_action \
        /usr/share/nemo/actions
fi

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
