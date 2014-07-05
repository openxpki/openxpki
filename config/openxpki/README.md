OpenXPKI basic system configuration
###################################

This directory contains a minimum and complete configuration set to run
a OpenXPKI instance using the WebUI. All contents need to be copied to
/etc/openxpki/.

Log configuration (log.conf)
-----------------------------

OpenXPKI uses Log4perl for its logging system. The location of the
configuration file is set in the systems configuration, where the default
is /etc/openxpki/log.conf. The file is ready for use, just copy it.


Global system configuration (config.d/system)
----------------------------------------------

Global system configuration, such as path to binaries and database. Should do
as is on most systems, minimal action: configure your database.


realm configuration (config.d/realm/ca-one)
-------------------------------------------

A single OpenXPKI instance can be used to run more than one logical 
certification authority - we call this a "realm". The example config comes 
with one preconfigured realm named "ca-one" which is "ready to go" for a 
first testdrive. You can create additional realms by just making a copy of
the directory (cp -pr ca-one ca-two) and put it into system/realm.yaml.

The feature examples also contain files to be put in the realm directory.
If you need to use such a feature you need to put its files in each realm
you want it to be enabled.

