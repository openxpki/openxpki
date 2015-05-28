#############
Enrollment UI
#############

This is a certificate enrollment interface for OpenXPKI. Basically, it
runs on a bastion host and accepts CSRs from external users. These
CSRs are passed to an internal OpenXPKI daemon via SCEP using the sscep
to forward the request.

Architecture
============

	+------------------------------+
	| Apache HTTP Server           |
	+------------------------------+
			|
			| (CGI call of 'enroller' script)
			|
			V
	+------------------------------+
	| Enroller Web UI              |
	+------------------------------+
			|
			| (enroller calls wrapper script)
			|
			V
	+------------------------------+
	| sscep Wrapper Script         |
	+------------------------------+
			|
			| (wrapper script calls sscep client)
			|
			V
	+------------------------------+
	| sscep client                 |
	+------------------------------+
			|
			| (SCEP request sent to server)
			|
			V
	+------------------------------+
	| SCEP Server                  |
	+------------------------------+


Configuration
=============

The Mojolicious framework is designed to run nicely in a PSGI or CGI
environment of a webserver. To run a test daemon that is reachable via
your web browser, run the following:

    script/enroller daemon

To run the test cases, use the following:

    script/enroller test

Apache HTTP Server
------------------

One method of serving the Enrollment UI is via Apache/CGI using the ScriptAlias directive:

    <Directory /srv/www/enroller>
		Options -FollowSymLinks
		AllowOverride None
		Order allow,deny
		Allow from all
	</Directory>
	ScriptAlias / /srv/www/enroller/script/enroller/
    
SCEP Client (e.g. sscep)
------------------------

**TODO**


