General
=======

Download links to certificates/crls are always in all available formats:
* DER/PEM/TXT (all)
* PKCS7 with Chain (all certs)
* PKCS12 / JavaKS (own certs if key exists)

Entity-cert lists should use background colors to visualize expired (yellow) and revoked (red) items.

Home
====

My Tasks
--------

Show outstanding approvals, organized in two grids.
top: outstanding certificate requests, columns: workflow, update, subject, profile, creator
bottom: outstanding revocations, columns: workflow, update, subject, reason, creator
Links: workflow -> opens workflow, subject -> open search with subject set

My Workflows
------------

Show a grid with workflows onwed by user
toolbar buttons "Status: all, finished, failed, pending"
Columns: id, type, current state, proc info, last update

Links: row opens workflow

My Certificates
---------------

List certs owned by user (can be local grid)
columns: serial, subject, notafter, status, (hidden: notbefore, issuer, profile)
toolbar buttons "Status: all, valid, expired, revoked"
On click - overlay (or right pane) with detail + download links

Key Status
----------

List systems crypto keys
columns: token name, notbefore, notafter, validity status, token state (filled after toolbar button with extra call as this can be expensive).
Click: open dialog to unlock (enter password) or lock (button with confirmation)

Information
===========

CA Certificates
---------------

List systems certs in grid (ca issuer and scep from alias table)
columns: CN, Usage (SCEP/CA), notbefore, notafter, validity status
Same as "my certificate"

Revocation Lists
----------------

Grid with crls
columns: Issuer, CRL number, Last update, Next update, Entries
overlay (or inline links) to download

Policy Documents
----------------

plain html, should be possbile to define by customer (load custom html from server)

Search
=======

Add tab bar to main screen, first tab is fixed "your search", add result tabs as they are needed.
Search page has some fixed fields and dynamic fields that must be requested from the server.

Certificates
------------

Fixed fields:
subject, issuer (text)
notbefore/notafter (date from/to)
status: checkbox/toolbar valid/revoked/expired

SAN-Filter:
key = dropdown from fixed values
value = free text
after filling one line a new one appears

Meta-Filter:
key = dropdown from dynamic list (obtained from server)
value = free text
after filling one line a new one appears

Result columns: subject, email, notafter, serial (hidden: notbefore, issuer)
Download and Details see "My Certs"

Workflows
---------

Fixed fields:
id (numeric)
type: dropdown, values from config (workflow names)
state: checkbox/toolbar (success, failed, pending, paused, crashed)
wfl-state: freetext

Context-Filter:
like Meta-Filter in Certificate

Result: see My Workflow

Request
=======

The request section is the place to create new workflows, each menu item is linked to a workflow type to be created. On request, the server provides the form manager info for the inital create step. The UI should render the initial form and submit it to create the workflow. The server will respond with either a new form description or an informal message that the workflow has reached a certain state.

Detail Pages
============

Certificate
-----------

Overlay/Right pane shows dense info (Subject, SAN, Fingerprint, Validity/Revocation, Issuer)
Full details in Popup/new Tab includes full extension section as in current implementation, rendering should be a simple key/value table, info is compiled by server!

Action-Buttons, obtained from server (Renew, Revoke, Change Metadata, Search)


Workflow
--------

Fixed Info-Block with id, type, type description, current statem wfl-state
Dynamic key/value table with dynamic info send by server
Action-Buttons, obtained from server, actions that require parameters are linked to a dynamic form (see form manager)

Form Manager
============

All forms presented by the workflow system need to be rendered based on a descriptive config send from the server (info is compiled from the workflow fields). The form as three levels: page -> section -> fields

The page is the top level container, that can hold 1 or many sections, that hold 1 or many fields. Each element has label, description and a helptext.

Page
----

Label = Headline
Description = Introtext

Section
-------

Group fields together in layout, optionally having additional label and text.

Fields
------

A basic field has a label, a name and a type definiton.
Valid types are html form types plus:
+ date (text field with date picker)
+ signature (textarea + widget to create a x509 based signature)

Values for select elements are passed either as symbolic name to a predefined set (e.g. crr reason) or as verbose array with the field definition. Each field can have the name of a validation rule attached, on-the-fly validation is done on the client. When the is send to the server, it will respond with either a list of errors in the current form or the ruleset for the next page to be rendered.
Fieldtypes and Validation rules should be easily extendable, t.b.d: perhaps its easier to bundle validation + layout into complex types (e.g. field type = type, size, validator).





