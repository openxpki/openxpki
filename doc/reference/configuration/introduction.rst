Overview
========

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

Activate the new configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To activate a new config without a restart, you need to do a reload::

     openxpkictl reload

You can also just send a ``SIGHUP`` to the main process or restart the dameon.

**IMPORTANT**

Those parts of the system are preloaded on server init and need a restart to load a new configuration.

* worflow configuration

* authentication handlers

* database settings

* daemon settings (**never** change anything below `system.server` while the dameon is running as you might screw up your system!)


Config Caching and Signing
--------------------------

Instead of reading the config from the filesystem freshly on each startup,
there is an option to serialize the config tree into a blob which offers
the option to use PKCS7 signatures to verify the configuration.

Transform config tree into blob
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Use ``openxpkiadm buildconfig --config path/to/config.d`` to generate the
blob. The default target is a file ``config.oxi`` in the current directory,
you specify and alternate location with ``--target myconfig.blob``.

To sign the config blob, you need to add ``--key`` and ``--cert`` pointing
to the PEM encoded key/certificate files. Its good practice to also add the
chain certificates to verify the signer up to the root, use ``--chain`` to
point to a file holding the concatenated PEM block of the issuers to be
added.

Enable config bootstrap
^^^^^^^^^^^^^^^^^^^^^^^
You need to create a node named ``bootstrap`` on the top level of the
configuraion and should remove any other config items. The easiest way
to achieve this is to wipe anything from ``/etc/openxpki/config.d/``
and place a file called bootstrap.yaml here::

    # this is the only mandatory option
    LOCATION: /home/pkiadm/config.oxi

    # This is the default and should be left empty unless overridden
    # class: OpenXPKI::Config::Loader

    # if you want to use signed configs, set ONE of the ca* options
    # Path holding the certificates as files (filemame = hash)
    # ca_certificate_path: /etc/openxpki/ca/config.certs/
    # All certificates in one file
    # ca_certificate_file: /etc/openxpki/ca/config.pem

    # temp dir, required to create files to perform signature verification
    # tmpdir: /tmp

    # path to openssl
    # openssl: /usr/bin/openssl

Configure signature verification
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Signature is validated using ``openssl smime -verify``. If you have placed
the chain certificates into the config blob, it is sufficient to have the
root certificates here, if not, make sure you have all certificates here
to create the full chain. Directory needs to hold the certificates in the
well-known openssl hashed filename format, the single file must hold the
concatenated PEM blocks.

Note: Currently we do not make any checks on the certificate itself so any
certificate from the given roots/chains can be used for signing so it is
recommended to setup a dedicated CA for the config signature. We are working
on making the signer authorization pattern used in other parts of the system
available for config signatures with one of the next releases.


Logging
-------

OpenXPKI uses Log4perl as its primary system log. Logging during startup and in critical situations is done via STDERR.
