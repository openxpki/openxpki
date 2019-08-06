Workflow Definition
===================

Each workflow is represented by a file or directory structure below ``workflow.def.<name>`` inside the realm configuration. The name of the file is equal to the internal name of the workflow. Each such file must have the following structure, not all attributes are mandatory or useful in all situations::

    head:
        label: The verbose name of the workflow, shown on the UI
        description: The verbose description of the workflow, shown on the UI
        prefix: internal short name, used to prefix the actions, must be unique
                Must not contain any other characters than [a-z0-9]

    state:
        name_of_state:  (used as literal name in the engine)
            autorun: 0/1
            autofail: 0/1
            label: visible name
            description: the text for the page head
            action:
              - name_of_action > state_on_success ? condition_name
              - name_of_other_action > other_state_on_success !condition_name
            hint:
                name_of_action: A verbose text shown aside of the button
                name_of_other_action: A verbose text shown aside of the button
            button:
                name_of_action:
                    label: Label to put on the button (default is label from action)
                    format: layout of the button = assigned stylesheet
                    # add a confirmation popup when button is pressed
                    confirm:
                        label: Headline of the popup dialog
                        description: Text inside the popup
                        confirm: label of the proceed button
                        cancel: label of the abort button

    action:
        name_of_action: (as used above)
            label: Verbose name, shown as label on the button
            tooltip: Hint to show as tooltip on the button
            description: Verbose description, show on UI page
            class: Name of the implementation class
            button: Label for the submit button (default is "continue")
            abort: state to jump to on abort (UI button, optional) # not implemented yet
            resume: state to jump to on resume (after exception, optional) # not implemented yet
            validator:
              - name_of_validator (defined below)
            input:
              - name_of_field (defined below)
              - name_of_other_field
            param:
                key: value - passed as params to the action class

    field:
        field_name: (as used above)
            name:        key used in context
            label:       The fields label
            placeholder: Hint text shown in empty form elements
            tooltip:     Text for "tooltip help"
            type:        Type of form element (default is input)
            required:    0|1
            default:     default value
            api_type:    Shortcut syntax to specify an OpenAPI type
            api_label:   Label to use in OpenAPI specification
            more_key:    other_value  (depends on form type)

    validator:
        class: OpenXPKI::Server::Workflow::Validator::CertIdentifierExists
        param:
            emptyok: 1
        arg:
          - $cert_identifier


Note: All entity names must contain only letters (lower ascii), digits and the underscore.

Below is a simple, but working workflow config (no conditions, no validators, the global action is defined outside this file)::

    head:
        label: I am a Test
        description: This is a Workflow for Testing
        prefix: test

    state:
        INITIAL:
            label: initial state
            description: This is where everything starts
            action: run_test1 > PENDING

        PENDING:
            label: pending state
            description: We hold here for a while
            action: global_run_test2 > SUCCESS

        SUCCESS:
            label: finals state
            description: It's done - really!
            status:
                level: success
                message: This is shown as green status bar on top of the page

    action:
        run_test1:
        label: The first Action
        description: I am first!
        class: Workflow::Action::Null
        input: comment
        param:
            message: "Hi, I am a log message"

    field:
        comment: (as used above)
            name: comment
            label: Your Comment
            placeholder: Please enter a comment here
            tooltip: Tell us what you think about it!
            type: textarea
            required: 1
            default: ''


Workflow Head
-------------

States
------

The ``action`` attribute is a list (or scalar) holding the action name and the
follow up state. Put the name of the action and the expected state on success,
seperated by the ``>`` sign (is greater than).

Actions
-------

t.b.d.

Fields
------

SELECT field with options
^^^^^^^^^^^^^^^^^^^^^^^^^
::

    type: select
    option:
        item:
          - unspecified
          - keyCompromise
          - CACompromise
          - affiliationChanged
          - superseded
          - cessationOfOperation
        label: I18N_OPENXPKI_UI_WORKFLOW_FIELD_REASON_CODE_OPTION

If the ``label`` tag is given (below ``option``!) the values in the drop down are
i18n strings made from ``label`` + ``uppercase(key)``, e.g
*I18N_OPENXPKI_UI_WORKFLOW_FIELD_REASON_CODE_OPTION_UNSPECIFIED*.

.. _openapi-workflow-field-param:

OpenAPI specific field parameters
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
::

    api_type: Array[Str]
    api_label: List of surnames

To be able to generate the OpenAPI spec the data types of all relevant input/output parameters must be defined. The most precise way to do this is to specify ``api_type`` in a field definition.

If ``api_type`` is not given then OpenXPKI tries to deduce the correct OpenAPI type from the field parameters ``format`` and ``type`` (and from the field name in some rare cases). See Perl class ``OpenXPKI::Server::API2::Plugin::Workflow::get_openapi_typespec`` for technical details.


api_type
~~~~~~~~

``api_type`` accepts a custom shortcut syntax to define OpenAPI data types. The syntax is close to the syntax used in `Moose types <https://metacpan.org/pod/distribution/Moose/lib/Moose/Manual/Types.pod>`_. All type names are **case insensitive**.

**Supported types**

- ``String`` alias ``Str``
- ``Integer`` alias ``Int``
- ``Numeric`` alias ``Num``
- ``Boolean`` alias ``Bool``
- ``Array`` alias ``ArrayRef``

  The type of array items may be specified in square brackets::

      Array[ Str ]
      Array[ Str | Int ]

- ``Object`` alias ``Obj``, ``Hash``, ``HashRef``

  The object properties (i.e. hash items) may be specified in square brackets::

      Object[ age: Integer, name: String ]

**Type parameters/modifiers**

Modifiers may be passed in brackets. Please note that those modifiers are **case sensitive** as they are used as-is in the OpenAPI spec.
::

    String(format:password)
    Integer(minimum: 1)

**Examples**

Some more complex examples of nested types::

    Array[ Object[ comment:Str, names:Array[Str] ] ]
    HashRef[ size:Integer(minimum:5), data:Array, positions:Array[ Integer | Numeric ] ]

**Please note**

- types are **case insensitive**
- you can **insert spaces** wherever you like in a type definition

api_label
~~~~~~~~~

``api_label`` is used as a field description in the OpenAPI spec. If not given, ``label`` is used instead.


For an OpenAPI overview please see :ref:`openapi-overview`.

Global Entities
---------------

You can define entities for action, condition and validator for global use in the corresponding files below ``workflow.global.``. The format is the same as described below, the *global_* prefix is added by the system.

Creating Macros (not implemented yet!)
--------------------------------------

If you have a sequence of states/actions you need in multiple workflows, you can
define them globally as macro. Just put the necessary state and action sections
as written above into a file below ``workflow.macros.<name>``. You need to have
one state named ``INITIAL`` and one ``FINAL``.

To reference such a macro, create an action in your main workflow and replace the
``class`` atttribute with ``macro``. Note that this is NOT an extension to the workflow
engine but only merges the definitions from the macro file with those of the current
workflow. After successful execution, the workflow will be in the state passed in the
``success`` attribute ofthe surrounding action.



