# OpenXPKI Trustcenter Software

A software stack based on perl and openssl to run a PKI/trustcenter with an enterprise-grade feature set. 

**core features**
- WebUI compatible with all major browsers
- Ready-to-run example config included
- File-based configuration (eases versioning, staged deployment and change control)
- Support for SCEP (Simple Certificate Enrollment Protocol)
- Easy adjustment of workflows to personal needs
- Run multiple separate CAs with a single installation
- automated rollover of CA generations
- Can use Hardware Security Modules (e. g. Thales HSMs) for crypto operations
- Issue certificates with public trusted CAs (e. g. SwissSign, Comodo, VeriSign)
- Based on OpenSSL and Perl, runs on most *nix platforms
- 100% Open Source, commercial support available

## Release

There is no planned release schedule, we make new releases after fixing relevant bugs or adding new features. You can download packages for Debian, Ubuntu and SuSE from the [package mirror](http://packages.openxpki.org). 

# Support / Issue Tracker

Check out the documentation on [readthedocs](http://openxpki.readthedocs.org/). There is also a [complete quickstart manual](http://openxpki.readthedocs.org/en/latest/quickstart.html).

Please use the [projects mailing lists](https://lists.sourceforge.net/lists/listinfo/openxpki-users) to get support. Please do **NOT** use the github issue tracker for general support and ask on the list before filing an issue. If you file an issue, add sufficient information to reproduce the problem.
  
# Contributing

Contributions are always welcome. Please fork and make a pull request against the development branch. Please also add you name to the AUTHORS file (which implies that you agree with the contributors license agreement).

# License

Apache License 2.0, also see LICENSE


