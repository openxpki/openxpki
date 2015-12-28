(c) Written by Sergei Vyshenski for the OpenXPKI project

A FreeBSD port for OpenXPKI, that is 

security/p5-openxpki,

is a formal constituent of the FreeBSD ports/packages system
and is distributed by the FreBSD project in a regular way.

General introduction on using FreeBSD ports/packages can be found here:

https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports.html

PORTS

A FreeBSD "port" is similar to a "source package" of Linux. It is supposed 
to build and install on all supported versions of FreeBSD, and on all 
supported hardware platforms. Violation of this is considered a 
severe problem to be fixed urgently.

List of supported FreeBSD versions is here:

https://www.freebsd.org/security/security.html#sup

List of supported hardware platforms is here:

https://www.freebsd.org/platforms/

The latest available version of the port (along with a list of its 
direct prerequisites) can be found here:

http://www.freshports.org/security/p5-openxpki/

The latest available version of the port (along with a list of its 
both direct and indirect prerequisites) can be found here:

https://www.freebsd.org/cgi/ports.cgi?query=p5-openxpki&stype=name

Conditional prerequisites (set with interactive dialog, see below) 
are not shown here.

PACKAGES

A FreBSD "package" is similar to a "binary package" of Linux. It is 
prepared and distributed by the FreeBSD project only for most popular
hardware platforms. Package version is often  behind the latest version 
of the port with the same name.

Some of available versions of the package can be seen here:

http://portsmon.freebsd.org/portoverview.py?category=security&portname=p5-openxpki

Real time package build information is available on 
http://beefy1.isc.freebsd.org/
http://beefy2.isc.freebsd.org/

but for more accurate information about package availability for your
particular FreeBSD system just run from the console:

pkg search p5-openxpki

Reading about pkg (aka pkgng) utility is here:

https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/pkgng-intro.html

PORTS vs PACKAGES

Before building for the first time, the p5-openxpki port asks you if you 
prefer to install tools for graphical visualization of workflows. 
(Conditional prerequisites emerge in this way.) Those tools may burden 
your server. Default answer here is NO. In the future you may reconsider
your answers with explicit call

make config

from the port directory before rebuilding the port.

Note that any package, distributed by the FreeBSD project, is always 
pre-built with DEFAULT answers of this type.

Moreover, FreeBSD has its own vision about default version of perl (which 
changes with time). Pre-built packages have exactly this version of perl 
in mind. If you install everything from ports, you have full control of 
everything which you install, version of perl including. Just install 
your favorite version of perl BEFORE installing of the OpenXPKI and 
other perl-related software. If you install something from ports, and 
something from packages, then package manager will try to warn your 
against problems, but the mess is your usual destiny in this case.

By the way, FreeBSD has efficient automatic tools to substitute one version 
of perl with another. This can be done without need of manual reinstall of
perl related ports/packages, which are already installed on your system.
Several ways of this substitution on your particular system are usually 
documented in a file UPDATING, which can be found in the root of the ports
directory, usually /usr/ports/UPDATING. This file warns you when 
ports/packages for perl itself, that is ports/packages with names lang/perl*,
go through essential changes. To see a fresh version of this file you need 
to update ports tree on your system in a regular way. Related reading:

https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports-using.html

It is a good idea to distinguish between two different procedures: 

1) update of ports tree on your system, main utility here can be portsnap,

2) update of ports already installed on your system to their the 
newest available versions. This makes use of updated ports tree. Main 
utility here can be portmaster.

That mentioned, security/p5-openxpki (either port or package) will install 
about 130-150 other ports/packages, which are (direct/indirect/conditional) 
prerequisites for p5-openxpki. Among these prerequisites it installs 
ports/packages, which are part of the OpenXPI project or are very closely
related to its development:

devel/p5-Workflow,
security/p5-openxpki-i18n,
devel/p5-Connector,
security/openca-tools-forked.

If you want, you can build yourself a package for any platform, any FreeBSD 
version, and with any options (with arbitrary answers during build process). 
Have a look here:

https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports-poudriere.html

Beware that the package is only useful if it is perfectly matched 
with all its 130-150 prerequisites (perl including) and with the rest 
of your particular FreeBSD system. That is why it is a very strange idea 
to build and publicly distribute a distinct package which is thorn away 
from its environment. At best, this package simply not installs at the end 
user side.

I would recommend to always use ports rather than packages. This habit will 
guard you against  many evident compatibility problems. A good utility to 
install and update your ports is ports-mgmt/portmaster available as 
a port/package itself. It asks (and memorizes) all interactive questions at 
the early stage of the build process, and then goes into background and 
heavily uses all parallelism which is available on your system.

WHAT ELSE IS NEEDED

What neither port nor package installs (but what is crucially needed for 
the OpenXPKI operation), is 

- Enable utf8 locale (e.g. en_US.utf8) for the translation staff to operate
  (translation is needed even for English language).
- Install your favorite database (enable utf8 support), 
  e.g. databases/mysql56-server
- Install perl interface for your favorite database, 
  e.g. databases/p5-DBD-mysql
- Install your favorite web server.
  Choose from two versions of the handler: based on CGI or FastCGI
  perl core modules.
  Copy CGI or FastCGI scripts from /usr/local/share/examples/openxpki/cgi-bin to the location
  where your web server can use them. Set executable permissions for them. 
  Copy htdocs files from /usr/local/share/examples/openxpki/htdocs to the location 
  where your web server can use them.
  You can see some samples in /usr/local/share/examples/openxpki/config/apache.
- If you want your server to act just as the simplest CA, 
  then the basic deployment procedure is all you need:
  copy sample configuration for this case with 
    cp -R /usr/local/share/examples/openxpki/config/openxpki/* /usr/local/etc/openxpki/
  and follow advice at:
  https://openxpki.readthedocs.org/en/latest/quickstart.html
  Without this deployment procedure OpenXPKI server would not start.
- If you want more complex role for your server inside the PKI infrastructure,
  then you need to perform further deployment procedure for your server atop 
  the basic deployment. 
- This port has created user:group as openxpki:openxpki, which owns 
  the OpenXPKI server.
- After first fresh installation, create empty log files as follows
  (assuming your web server is owned by user www):

install -m 660 -o openxpki -g openxpki /dev/null /var/log/openxpki/openxpki.log
install -m 660 -o www -g www /dev/null /var/log/openxpki/webui.log
install -m 660 -o www -g www /dev/null /var/log/openxpki/scep.log
install -m 660 -o www -g www /dev/null /var/log/openxpki/soap.log

- It is essential that www and openpki are two different users in your system.

- Start daemons in this order:
    database server,
    OpenXPKI server (/usr/local/etc/rc.d/openxpki start),
    web server.
- Docs installed (if you opted so) into /usr/local/share/doc/openxpki
- Mind FreeBSD specific file structure:
    /usr/local/etc/openxpki: server configuration, logs configuration.
    /var/openxpki: pid file, socket file, ...
    /var/openxpki/session: session files.
    /var/log/openxpki: server log files.
    /var/tmp: temporary directory.
=============================================================
