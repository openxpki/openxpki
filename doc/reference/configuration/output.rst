Workflow Output Formatting
==========================


Buttons
-------

Key/Value Grid
---------------

redirect
^^^^^^^^
Creates an immediate redirect command with value as location.
The location must be an ember route, e.g. workflow!start!system_status.

If the value is a hashref, you can also show a status message (message, level)
and define a pause interval (pause - in seconds). The redirect target must be
in the target key, if not set the redirect target is the current workflow.
