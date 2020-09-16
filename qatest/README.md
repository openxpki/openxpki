## Status of test in this directory

### backend

Tests that run against the socket

#### activity

Only for manual testing during development - candidate to be removed

Requires a running: database, OpenXPKI

#### api2

Tests for APIv2 - need to fix problem with SampleConfig

Requires a running: -

#### paused_workflow

Need to create new workflow and rework tests, likely to be included in other tests

Requires a running: database, OpenXPKI

#### webui

Should be fully functional. Mocks CGI Requests via the Socket - no apache required!

Requires a running: database, OpenXPKI

#### webui-standalone

Uses a test server (new test framwork) and mocks CGI requests via socket - no apache or running server required.

Requires a running: database

### client

t.b.d

### frontend

Tests run against the webserver. Needs a properly configured webserver with TLS auth and chains setup. Path can be configured in `test.yaml`. Those are the main End-To-End tests which MUST work when a release is made.

Requires a running: database, OpenXPKI, Apache
