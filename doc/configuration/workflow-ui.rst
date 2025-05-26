Workflow UI Rendering
=====================

The UI uses information from the workflow definition to render display and input pages. There are two different kinds of pages, switches and inputs.

Action Switch Page
------------------

Used when the workflow comes to a state with more than one possible action.

*headline*

Concated string from state.label + workflow.label

*descriptive intro*

String as defined in state.description, can contain HTML tags

*workflow context*

By default a plain dump of the context using key/values, array/hash values are converted to a html list/dd-list. You can define a custom output table with labels, formatted values and even links, etc - see the section "Workflow Output Formatting" fore details.

*button bar / simple layout*

One button is created for each available action, the button label is taken from action.label. The value of action.tooltip becomes a mouse-over label.

*button bar / advanced layout*

If you set the state.hint attribute, each button is drawn on its own row with a help text shown aside.

Form Input Page
---------------

Used when the workflow comes to a state where only one action is available or where one action was choosen.

*headline*

Concated string from action.label (if none is given: state.label ) + workflow.label

*descriptive intro*

String as defined in action.description, can contain HTML tags

*form fields*

The field itself is created from label, placeholder and tooltip. If at least one form field has the description attribute set,
an explanatory block for the fields is added to the bottom of the page.

Markup of Final States
----------------------

If the workflow is in a final state, the default is to render a colored
status bar on with a message that depends on the name of the state.
Recognized names are SUCCESS, CANCELED and FAILURE which generate a
green/yellow/red bar with a corresponding error message. The state name
NOSTATUS has no status bar at all.

If the state does not match one of those names, a yellow bar saying
"The workflow is in final state" is show.

To customize/suppress the status bar you can add level and message
to the state definition (see above).
