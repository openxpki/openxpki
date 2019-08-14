## Status of test in this directory

### backend

Tests that run against the socket

#### activity

Only for manual testing during development - candidate to be removed

#### api

Tests for APIv1 - will be dropped with 3.0 as APIv1 is removed

#### api2

Tests for APIv2 - need to fix problem with SampleConfig

#### paused_workflow

Need to create new workflow and rework tests, likely to be included in other tests

#### webui

Should be fully functional. Mocks CGI Requests via the Socket - no apache required!

### client

t.b.d

### frontend

Tests run against the webserver. Needs a properly configured webserver with TLS auth and chains setup. Path can be configured in `test.yaml`. Those are the main End-To-End tests which MUST work when a release is made.