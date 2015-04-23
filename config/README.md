Copyright (c) 2014 by The OpenXPKI Project

OpenXPKI sample configuration
#############################

This directory contains configuration snippets to be used with OpenXPKI.

core configuration
------------------

A basic configuration to run OpenXPKI with the core functionality is held
in the openxpki directory. Copy it to /etc/openxpki and edit as needed 
(minimal effort, setup database connection in system/database.yaml).

Inside the feature directory, you will find more config files to use/enable
certain features of OpenXPKI such as SCEP or SOAP Interfaces or advanced
authentication and publication setups. If not stated otherwise, the contents
of those feature directories need to be copied on top of the basic
configuration inside /etc/openxpki. Please take care, that some files need to
be merged and not overwritten.

Each of the feature directories has a README file giving a brief explanation,
please refer to the online documentation for additional info:
http://openxpki.readthedocs.org/en/latest/quickstart.html

sample profiles (profiles)
--------------------------

The basic configuration comes with two sample profiles for a web-server
and a user/email certificate. This directory contains additional profiles.
To use a profile, just copy it to your realm's profile directory.
A brief description of each profile is given inline with each file.


workflow definitions in OmniGraffle (graffle)
---------------------------------------------

Some of the recent, more complex workflows have been modelled using
OmniGraffle. The script in ./tools/scripts/ogflow.pl may be used to
convert from .graffle to the .xml files. Unfortunately, OmniGraffle
is NOT an open source tool. It was used to "scratch an itch", but
we have not found an open source alternative.
*This is deprecated as we will replace the workflows by a yaml config soon*


apache configuration (apache)
-----------------------------

Contains configuration snippets for apache to setup aliases, etc.


