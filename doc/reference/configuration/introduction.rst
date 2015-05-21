OpenXPKI Configuration
======================

Main configuration
------------------ 
The configuration of OpenXPKI consists of two, fundamental different, parts. There is one global system configuration, which holds information about database, filesystem, etc. where the system lives. The second part are the realm configurations, which define the properties of the certificates within the realm. Each pki realm has its own, independant configuration and is isolated from other realm, so you can run instances with different behaviour with one single OpenXPKI server.

We ship the software with a set of YaML files, and we recommend to keep the given layout. The following documentation uses some notations you should know about.

#. Configuration items are read as a path, which is denoted as a string with the path elements seperated by a dot, e.g. ``system.database.main.type``. 

#. The path is assembled from the directory, the name of the configuration file, the path of the element in the YaML notation. The value from the example above can be found in the directory ``system``, file ``database.yaml``, section ``main``, key ``type``.

#. All paths except those starting with *system* or *realm* refer to the configuration of a particular realm. The root node for building the path is the realm's directory found at ``realm/<name of the realm>``.

Config versioning
-----------------

This idea was dropped, configuration is now read freshly from the filesystem at every restart of the daemon.  

Activiate the new configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To activate a new config without a restart, you need to do a reload::

     openxpkicli reload
     
You can also just send a ``SIGHUP`` to the main process or restart the dameon.

**IMPORTANT**

Those parts of the system are preloaded on server init and need a restart to load a new configuration.

* worflow configuration

* authentication handlers

* database settings

* daemon settings (**never** change anything below `system.server` while the dameon is running as you might screw up your system!)



Logging
-------

OpenXPKI uses Log4perl as its primary system log. Logging during startup and in critical situations is done via STDERR. 
