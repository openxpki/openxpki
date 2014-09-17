(c) Written by Sergei Vyshenski for the OpenXPKI project

A FreeBSD port for OpenXPKI, that is 

security/p5-openxpki,

is a formal constituent of the FreeBSD ports/packages system. 

General introduction of using FreeBSD ports/packages can be found here:

https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports.html

PORTS

FreeBSD "port" is similar to "source package" of Linux. It is supposed 
to build and install on all supported version of FreeBSD, and on all 
supported hardware platforms. Violation of this is considered a 
severe problem, which should be fixed urgently.

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

PACKAGES

FreBSD "package" is similar to the "binary package" of Linux. It is 
prepared and distributed by the FreeBSD project only for most popular
hardware platforms. Package version is usually behind the latest version 
of the port with the same name.

Some of available versions of a package can be seen here:

http://portsmon.freebsd.org/portoverview.py?category=security&portname=p5-openxpki

but for more accurate information about package availability for your
particular FreeBSD system just run from the console:

pkg search p5-openxpki

Reading about pkg (aka pkgng) utility is here:

https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/pkgng-intro.html

PORTS vs PACKAGES

Before building, the p5-openxpki port will ask you if you prefer to install 
tools for graphical visualization of workflows. Those tools may burden your 
server. Default answer here is NO. Note that package, distributed by the 
FreeBSD project is always pre-built with DEFAULT answers like this.

Moreover, each FreeBSD version has its default version of perl. Pre-built 
packages have exactly this version of perl in mind. If you install everything 
from ports, you have full control on everything which you install, 
version of perl including. If you install something from ports, and 
something from packages, then package manager will try to warn your 
against problems, but the mess is your usual destiny in this case.

That mentioned, security/p5-openxpki (either port or package) will install 
about 130-150 other ports/packages, which are prerequisites for p5-openxpki.

If you want, you can build yourself a package for any platform and with any 
options (with arbitrary answers during build process). Have a look here:

https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports-poudriere.html

Beware that a package is only useful if it is perfectly matched 
with all its 130-150 prerequisites (perl including) and with the rest 
of your particular FreeBSD system. That is why it is a very strange idea 
to build and publicly distribute a distinct package which is thorn away 
from its environment. At best, this package simply not installs at the end 
user side.

I would recommend to use port rather than package. This habit will guard 
you from many evident compatibility problems. A good utility to work 
with ports is ports-mgmt/portmaster available as a port/package itself. 
It asks (and memorize) all interactive questions at the early stage of 
the build process, and then goes into background and heavily uses all 
parallelism which is available on your system.

WHAT ELSE IS NEEDED

What neither port nor package installs (but what is crucially needed for 
the OpenXPKI operation), is 

- your favorite web server and its prerequisites,
- your favorite database and its prerequisites.

For a list of supported web servers and databases, have a look at 

http://openxpki.org
=============================================================
