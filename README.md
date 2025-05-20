# OpenXPKI Trustcenter Software

A software stack based on perl and openssl to run a PKI/trustcenter with an enterprise-grade feature set.

**core features**

- WebUI compatible with all major browsers
- Ready-to-run example config as public git repo ([openxpki/openxpki-config](https://github.com/openxpki/openxpki-config))
- File-based configuration (eases versioning, staged deployment and change control)
- Support for SCEP (Simple Certificate Enrollment Protocol) and EST
- Easy adjustment of workflows to personal needs
- Run multiple separate CAs with a single installation
- Automated rollover of CA generations
- Can use Hardware Security Modules (e. g. Thales HSMs) for crypto operations
- Issue certificates with public trusted CAs (e.g. Digicert, SwissSign, ACME)
- Based on OpenSSL and Perl, runs on most *nix platforms
- 100% Open Source, commercial support available

## Release

There is no planned release schedule, we make new releases after fixing relevant bugs or adding new features.

### Stable Releases

With release 3.2/3.3 we started to have two active release lines: A new stable release, which is fully tested and will usually upgrade seamlessly within the same major version (see https://semver.org/), gets a minor version with even number (3.2.0). Updates to this release will be done on critical bugs or minor improvements, such releases will be announced on the openxpki-users mailing lists.

Packages for Debian are provided via our [package mirror](http://packages.openxpki.org), prebuild docker images are available via Dockerhub ([whiterabbitsecurity/openxpki3](https://hub.docker.com/r/whiterabbitsecurity/openxpki3)).

Packages for SLES, RHEL, Ubuntu are available via subscription plans.

### Development Releases

Development releases will be tagged with an odd number (3.3.x), those releases should not be used in production. Packages might be published for such releases, the corresponding docker image is named ([whiterabbitsecurity/openxpki3dev](https://hub.docker.com/r/whiterabbitsecurity/openxpki3dev)).

## Getting Started

A public demo is available at https://demo.openxpki.org/.

To run OpenXPKI yourself get a Debian box (Current release is v3 for Bookworm) ready and download the packages from the [package mirror](http://packages.openxpki.org). The packages come with a full-featured sample config and a sample setup script - this gets your PKI up in less than 5 minutes! Just follow our [Quickstart Instructions](https://openxpki.readthedocs.io/en/latest/quickstart.html).

There is also a ready-to-use docker image *whiterabbitsecurity/openxpki3*, see https://github.com/openxpki/openxpki-docker.

## Support / Issue Tracker

Check out the documentation on [readthedocs](http://openxpki.readthedocs.org/). There is also a [complete quickstart manual](http://openxpki.readthedocs.org/en/latest/quickstart.html).

Please use the [projects mailing lists](https://lists.sourceforge.net/lists/listinfo/openxpki-users) to get support. Please do **NOT** use the github issue tracker for general support and ask on the list before filing an issue. If you file an issue, add sufficient information to reproduce the problem.

## Contributing

Contributions are always welcome. Please fork and make a pull request against the development branch. Please also add you name to the AUTHORS file (which implies that you agree with the contributors license agreement).

## License

Apache License 2.0, also see LICENSE
