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

The system manages its configuration using an internal git repository. There are several issues you should be aware of:

#. Changes to the yaml configuration are never read or activated automagically, so you need to manually import changed files into the repository.

#. The head version of the repository is read on startup and not changed even if the repository advances.

#. A workflow stores a pointer to the version which was active when the workflow was created. This makes sure that the definition of a workflow can not change while it is running and affects all settings made within the realm. System settings are NOT subject of versioning and always used from the head version. Values read from external sources are also not versioned.

Importing a new configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

After makeing changes to your configuration, you can load it into the repository calling the CLI helper::

     $ openxpkiadm loadcfg
     Current Tree Version: 53c2795b7b2bb712647e7761e0f2b789753a2593
     
The output shows you the internal version id (git commit hash) of the new head. This will only import the configuration but not activate it. 

Activiate the new configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To activate a new config without a restart, you need to do a reload::

     openxpkicli reload
     
or using the `reload` option while importing::

    openxpkiadm loadcfg --reload

You can also just send a ``SIGHUP`` to the main process or restart the dameon.

**IMPORTANT**

Those parts of the system are preloaded on server init and need a restart to load a new configuration.

* authentication handlers

* database settings

* daemon settings (**never** change anything below `system.server` while the dameon is running as you might screw up your system!)



Logging
-------

OpenXPKI uses Log4perl as its primary system log. Logging during startup and in critical situations is done via STDERR. 
