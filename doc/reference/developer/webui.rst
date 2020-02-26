========================
WebUI Page API Reference
========================

The web pages are created (mainly) on the client from a JSON control stucture delivered by the server. This document describes the structure expected by the rendering engine.

Top-Level Structure
===================

This is the root element of any json result::

    %structure = (
        page => { TOP_LEVEL_INFO },
        right => [ PAGE_SECTION, PAGE_SECTION,...] , # optional, information which will be displayed in additional right pane
        main => [ PAGE_SECTION, PAGE_SECTION,...] , # information which will be displayed in the main section
        reloadTree => BOOL (1/0), # optional, the browser will perform a complete reload. If an additional "goto" is set, the page-url will change to this target
        goto => STRING PAGE, # optional, will be evaluated as url-hashtag target
        status => { STATUS_INFO } # optional
    );

    Example { reloadTree => 1, goto => 'login/login' }


Page Head (TOP_LEVEL_INFO):
---------------------------

This is rendered as the page main headline and intro text.
::

    TOP_LEVEL_INFO:
    {
        label => STRING, #Page Header
        description => STRING, # additional text (opt.)
    }

*Example*::

    page => { label => 'OpenXPKI Login', description => 'Please log in!' }


Status Notification (STATUS_INFO):
----------------------------------

Show a status bar on top of the page, the level indicates the severity and results in different colors of the status bar.
::

    STATUS_INFO:
    {
        level => STRING, # allowed values: "info", "success","warn", "error"
        message => STRING # status message shown
    }

*Example*::

    status => { level => 'error', message => 'Login credentials are wrong!' }

Page Level
==========

The page sections (``main`` and ``right``) can hold multiple subpage definitions. The main section must always contain at least one section while right can be omitted or empty.

Page Section (PAGE_SECTION)
---------------------------

This is the top level container of each page section.
::

    PAGE_SECTION:
    {
        type => STRING # see SECTION-TYPE below for supported types
        content => {
            label => STRING # optional, section headline
            description => STRING , # optional, additional text (html is allowed)
            buttons => [ BUTTON_DEF, BUTTON_DEF, ... ] , # optional, defines the buttons/links for this section
            # additional content-params depending on type (see below)
        },
        # additional section-params depending on type:
    }


SECTION-TYPE "text"
-------------------

Print the label as subheadline (h2) and description as intro text, buttons are rendered after the text. Does not have any additional parameters. Note: If you omit label and description this can be used to render a plain button bar or even a single button.

SECTION-TYPE "grid"
-------------------

Grids are rendered using the `jquery datatable plugin (http://datatables.net) <http://datatables.net>`_. The grid related parameters are just pushed to the dataTables engine and therefore have a different notation and syntax used as the remainder of the project.
::

    content => {
        label => ..,
        description => ..,
        buttons => [ BUTTON_DEF, BUTTON_DEF, ... ] , # optional, defines the buttons/links for this grid
        columns => [ GRID_COL_DEF, GRID_COL_DEF , GRID_COL_DEF... ],
        data => [ GRID_ROW, GRID_ROW, GRID_ROW, ... ],
        actions => [ GRID_ACTION_DEF, GRID_ACTION_DEF, GRID_ACTION_DEF... ], # defines available actions, displayed as context menu
        processing_type => STRING, # only possible value (for now) is "all"
    }

    GRID_COL_DEF:
    {
        sTitle => STRING, # displayed title of that columnd AND unique key
        format => STRING_FORMAT # optional, triggers a formatting helper (see below)
    }

    GRID_ROW:
        ['col1','col2','col3']


    GRID_ACTION_DEF:
    {
        path => STRING_PATH, # will be submitted to server as page. terms enclosed in {brackets} will be evaluated as column-keys and replaced with the value of the given row for that column
        label => STRING, # visible menu entry
        target => STRING_TARGET # optional, where to open the new page, one of main|right|modal|tab
        icon => STRING , # optional, file name of image icon, must be placed in htdocs/img/contextmenu
    }


Columns, whose sTitle begin with an underscore will not be displayed but used as internal information (e.g. as path in GRID_ACTION_DEF). A column with the special title ``_status`` is used as css class for the row. Also a pulldown menu to filter by status will be displayed.
The rows hold the data in form of a positional array.

Action *target* ``modal`` creates a modal popup, ``tab`` inits or extends a tabbed window view in the current section.

*Example*::

    content => {
        columns => [
        { sTitle => "Serial" },
            { sTitle => "Subject" },
        { sTitle => "date_issued", format => 'timestamp'},
        { sTitle => "link", format => 'link'},
        { sTitle => "_id"}, # internal ID (will not be displayed)
        { sTitle => "_status"}, # row status
        ],
        data => [
            ['0123','CN=John M Miller,DC=My Company,DC=com',1379587708, {page => 'http://../', label => 'Click On Me'}, 'swBdX','issued'],
            ['0456','CN=Bob Builder,DC=My Company,DC=com',1379587517,{...},'qqA2H','expired'],
        ],
        actions => [
            {
                path => 'cert!detail!{_id}',
                label => 'Details',
                icon => 'view',
                target => 'modal'
            },
            {
                path => 'cert!mail2issuer!{email}',
                label => 'Send an email to issuer'
            },
        ]
    }

SECTION-TYPE "form"
-------------------

Render a form to submit data to the server
::

    content => {
        label => STRING,
        description => STRING,
        buttons => [ BUTTON_DEF, BUTTON_DEF, ... ], # a form must contain at least one button to be useful
        fields => [ FORM_FIELD_DEF, FORM_FIELD_DEF, ... ],
    }

    FORM_FIELD_DEF:
    {
        name => STRING # internal key - will be transmitted to server
        value => MIXED, # value of the field, scalar or array (depending on type)
        label => STRING, # displayed label
        type => STRING_FIELD_TYPE, # see FIELD-TYPE below for supported types
        is_optional => BOOL, # if false (or not given at all) the field is required
        clonable => BOOL, # creates fields that can be added more than once
        visible => BOOL, # if set to "false" ("0" in perl) this field will be not displayed (initial)
        keys => ARRAY, # optional, activates the special feature of "dynamic key value fields", see below.
        # + additional keys depending for some types
    }

FIELD-TYPE "text", "hidden", "password", "textarea"
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

No additional parameters, create a simple html form element without any extras.

FIELD-TYPE "static"
^^^^^^^^^^^^^^^^^^^

No additional parameters, creates a simple "readonly" text element with the
value treated as a "hidden" form element. If you want to display a formatted
version of the value instead, you can pass it using the *verbose* key.

FIELD-TYPE "checkbox/bool"
^^^^^^^^^^^^^^^^^^^^^^^^^^

A html checkbox; *value* and *is_optional* are without effect, as always 0 or 1 is send to the server.

FIELD-TYPE "date"
^^^^^^^^^^^^^^^^^^

A text field with a jquery datapicker attached. Additional (all optional) params are:
::

    FORM_FIELD_DEF:
    {
        notbefore => INTEGER, # optional, unixtime, earliest selectable date
        notafter => INTEGER, # optional, unixtime, earliest selectable date
        return_format => STRING # one of terse|printable|iso8601|epoch, see OpenXPKI::Datetime
    }

FIELD-TYPE "select"
^^^^^^^^^^^^^^^^^^^^

A html select element, the options parameter is required, others are optional::

    FORM_FIELD_DEF:
    {
        options => [{value=>'key 1',label=>'Label 1'},{value=>'key 2',label=>'Label 2'},...],
        prompt => STRING # first option shown in the box, no value (soemthing like "please choose")
        editable => BOOL # activates the ComboBox,
        actionOnChange => STRING_ACTION # if the pulldown is changed by the user (or an initial value is given), server will be called with this "action". See "Dynamic form rendering" for details.
    }

The ``options`` parameter can be fetched via an ajax call. If you set ``options => 'fetch_cert_status_options'``, an ajax call to "server_url.cgi?action=fetch_cert_status_options" is made. The call must return the label/value list as defined given above.

Setting the editable flag to a true value enables the users to enter any value into the select box (created with `Bootstrap Combobox <https://github.com/danielfarrell/bootstrap-combobox>`_).

FIELD-TYPE "radio"
^^^^^^^^^^^^^^^^^^

The radio type is the little brother of the select field, but renders the items as a list of items using html radio-buttons. It shares the syntax of the ``options`` field with the select element::

    FORM_FIELD_DEF:
    {
        options => [{....}] or 'ajax_action_string'..
        multi => BOOL, # optional, if true, uses checkbox elements instead radio buttons
    }


FIELD-TYPE "upload"
^^^^^^^^^^^^^^^^^^^

Renders a field to upload files with some additional benefits::

    FORM_FIELD_DEF:
    {
        mode => STRING, # one of hidden, visible, raw
        allowedFiles => ARRAY OF STRING, # ['txt', 'jpg'],
        textAreaSize => {width => '10', height => '15'},
    }

By default, a file upload button is shown which loads the selected file into a hidden textarea. Binary content is encoded with base64 and prefixed with the word "binary:". With `mode = visible` the textarea is also shown so the user can either upload or paste the data (which is very handy for CSR uploads), the textAreaSize will affect the size of the area field. With ``mode = raw`` the element degrades to a html form upload button and the selected file is send with the form as raw data.

AllowedFiles can contain a list of allowed file extensions.

Dynamic key value fields
^^^^^^^^^^^^^^^^^^^^^^^^
If a field is defined with the property "keys", a pulldown of options is displayed above the actual field. This allows the user to specify, which kind of information he wants to specify.
The content of the actual field will be submitted to the server with the selected key in the key-pulldown.

*Example*::

    { name => '...', label => 'Dyn Key-Value', 'keys' => [{value=>"key_x",label=>"Typ X"},{value=>"key_y",label=>"Typ Y"}], type => 'text' },

..

    This example definition will render a Textfield with label "Dyn Key-Value". Above the textfield a select is displayed with three options ("Typ x","Typ y" and "Typ z").
    If the user chooses "Typ Z", the entered value in the textfield will be posted to server with key "key_z".

    This feature makes often more sense in combination with "clonable" fields.

Dynamic form rendering
^^^^^^^^^^^^^^^^^^^^^^
If a select field is defined with the property "actionOnChange", each change event of this pulldown will trigger
an submit of all formvalues (without validity checks etc) to the server with key "action" set to the value of "actionOnChange".

The returned JSON must contain the key "_returnType" which should have the value "partial" or "full".
This "_returnType" defines the mode of re-definition of the content of the form.

**Partial redefinition:**

Beside the key "_returntype" the key "fields"  is expected in the returned JSON-Structure.
"fields" contains an array, which is semantically identic to the key "fields" in the definition of the form.
This array "fields" must contain only only the fields (and properties), which should react to the change of the (master-)field (pulldown) .
The property "name" is required (otherwise the client can not identify the field).
The property "type" can not be subject to changes. With aid of the property "visible" one can dynamically show or hide some fields.
Only known fields (which are already defined in the initial "fields"-property of the form-section) can be subject of the "partial" re-rendering.
Its not possible to add new fields here.

You can define more than one (cascading) dependent select.

*Example*:

    Initial definition of fields:

::

    fields => [
        { name => 'cert_typ', label => 'Typ',value=> 't2', prompt => 'please select a type',  type => 'select', actionOnChange => 'test_dep_select!change_type', options=>[{value=>'t1',label=>'Typ 1'},{value=>'t2',label=>'Typ 2'},{value=>'t3',label=>'Typ 3'}] },
        { name => 'cert_subtyp', label => 'Sub-Type',prompt => 'first select type!', type => 'select',options=>[] },
        { name => 'special', label => 'Spezial (nur Typ 2',  type => 'checkbox',visible => 0 },
    ]

..

    Action "test_dep_select!change_type" returns a (partially updated) definition of fields:

::

    {
        _returnType => 'partial',
        fields => [
            { name => 'cert_subtyp', options=> [{value=>'x', label => 'Subtyp X'},...],value=>'x'} ,
            { name => 'special',visible=> 1 }
        ]
    };

**Full redefinition:**

Is not implemented yet.


SECTION-TYPE "key-value"
-------------------------

Render a list of key/value items in a two column grid. The left column shows
the text given by *label*, the right column is formated based on *value* and
*format* (see Formatted Strings).

There is a special *format* type ``head`` which renders a table head tag spanning
both columns. If a context item is referenced, *value* is used as headline,
it might be decorated using a template. As an alternative, a fixed value can
be given using the key *label*.

Add an item with *format* set to ``spacer`` to create an empty separator line
(there is a global workflow field named *spacer* in the default *ca-one* config
so you can just say ``- spacer`` in the workflow ``output`` section).

An option *className* can be set which is put into the rows' ``<tr>`` tag.

Item Level
==========

Buttons (BUTTON_DEF)
--------------------

Defines a button. There are three modes, depending on which one of these parameters is specified:
*page*, *action*, *href*.

**Common parameters** for *page* and *action*::

    {
        target => [main|modal|tab|active], # (optional, default is "main")
        label => STRING, # The label of the button
        tooltip => STRING, # (optional)
        className => STRING, # CSS class (optional)
        confirm => {
            label => STRING, #
            description => STRING, #
            confirm_label => STRING,  # (optional, defaults to "Confirm")
            cancel_label => STRING,  # (optional, defaults to "Abort")
        },
    }

*target*: determines where the contents returned by the server shall be displayed:

- ``main`` - as main tab (close all other tabs)
- ``modal`` - as a modal dialog
- ``tab`` - in a new tab
- ``active`` - in the active tab

**page**: load a page - calls an ``init_*`` method in the specified class::

    {
        page => STRING, # page to render (GET request with parameter "page")
        # + Common parameters (see above)
    }

**action**: execute action via AJAX - calls an ``action_*`` method in the specified class::

    {
        action => STRING, # action to execute (POST request with parameter "action")
        # + Common parameters (see above)
    }

**href**: open a custom URL::

    {
        href => STRING, # URL to call
        target => STRING, # any HTML link target, e.g. '_blank'
        label => STRING, # The label of the button
        tooltip => STRING, # (optional)
        className => STRING, # CSS class (optional)
    }

Formatted Strings (STRING_FORMAT)
---------------------------------

Tells the UI to process the data with a special formatter before rendering. Available methods are:

timestamp
^^^^^^^^^

Expects a unix timestamp and outputs a full UTC timestamp.

datetime
^^^^^^^^

Expects a parseable date, outputs a full UTC timestamp.

certstatus
^^^^^^^^^^

Colorizes the given status word using css tags, e.g. ``issued`` becomes::

    <span class="certstatus-issued">issued</span>

link
^^^^

Create an internal framework link to a page or action, expects a hash like::

    {
        label => STRING, #
        page => STRING, #
        target => [_blank|main|modal|tab|active], # (optional, defaults to "modal")
        tooltip => STRING, # optional
    }

extlink
^^^^^^^

Similar to *link* but: expects *href* to be an external target, default *target* is ``_blank``.

text
^^^^

Readable text without html markup (special characters will be escaped)

nl2br
^^^^^

Like text but with line breaks ``\n`` converted to ``<br>``

raw
^^^

Displayed as is.

code
^^^^

Rendered with fixed-with typo, unix linebreaks are converted to html linebreaks.

defhash/deflist
^^^^^^^^^^^^^^^

Outputs a key/value list (dl/dt/dd) - defhash expects a hash where keys are
labels. deflist expects an array where each item is a hash with keys key and
value.

ullist
^^^^^^

Array of values, each item becomes a <li> in the list, values are html-escaped.

rawlist
^^^^^^^

Like ullist but displays the items "as is" (can contain HTML markup)

linklist
^^^^^^^^

Array, where each item is a hash describing a _`link`

styled
^^^^^^

Expects a value in the format ``stylename:Text to display``. The part left
of the colon is extracted and the text at the right is wrapped with span
with style class "styled-``stylename``. Predefined stylenames are
``valid``, ``failed`` and ``attention``


Customization
=============

The framework allows to register additional components via an exposed api.

Form-Field
-----------

Add a new FormField-Type::

    OXI.FormFieldFactory.registerComponent('type','ComponentName',JS_CODE [,bOverwriteExisting]);

*Example*::

    OXI.FormFieldFactory.registerComponent('select','MySpecialSelect', OXI.FormFieldContainer.extend({
        ....
    }), true);

This will overwrite the handler for the select element. The ComponentName will be registered in the OXI Namespace and can be used to call the object from within userdefined code.


Formatter
---------

Add a new Format-Handler::

    OXI.FormatHelperFactory.registerComponent('format','ComponentName',JS_CODE [,bOverwriteExisting])




