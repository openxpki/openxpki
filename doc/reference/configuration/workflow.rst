*Note: This is a draft for the new config format, this is not publicly available yet*

Configuration of the Workflow Engine
=====================================

All files mentioned here are below the node ``workflow``. Filenames are all lowercased.

Persister and Observer
----------------------

It should not be necessary to touch those. These values are used as a default for all workflows if there is no other name given in the head section of the workflow definition.

* ``persister`` holds the name of the used persister, it must be a scalar.
* ``observer`` can hold a scalar or list of class names.

Workflow Definitions
--------------------

Each workflow is represented by a file or directory structure below ``workflow.def.<name>``. The name of the file is equal to the internal name of the workflow. Each such file must have the following structure::

    head:
      label: The verbose name of the workflow, shown on the UI
      description: The verbose description of the workflow, shown on the UI
      prefix: internal short name, used to prefix the actions, must be unique.
      persister: optional, overrides global definiton as given above
      observer: optional, overrides global definiton as given above

    state: 
        name_of_state:  (used as literal name in the engine)
            autorun: 0/1
            autofail: 0/1
            label: visible name
            description: the text for the page head
            action: 
              - name_of_action > state_on_success ? condition_name
              - name_of_other_action > other_state_on_success !condition_name

    action:
        name_of_action: (as used above)
            label: Verbose name, shown as label on the button
            tooltip: Hint to show as tooltip on the button in 
            description: Verbose description, show on UI page
            class: Name of the implementation class
            abort: state to jump to on abort (UI button, optional) # not implemented yet
            resume: state to jump to on resume (after exception, optional) # not implemented yet
            validator: scalar/list of validator names, defined in validator section
            input: list of field names for input, to be defined in field section 
            param:
                key: value - passed as params to the action class

    field:
        field_name: (as used above)
            name: key used in context
            label: The fields label
            placeholder: Hint text shown in empty form elements
            tooltip: Text for "tooltip help"
            type:     Type of form element (default is input)
            required: 0|1
            default:  default value
            more_key: other_value  (depends on form type)

       
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
^^^^^^^^^^^^^

States
^^^^^^

The ``action`` attribute is a list (or scalar) holding the action name and the
follow up state. Put the name of the action and the expected state on success, 
seperated by the ``>`` sign (is greater than).

Action
^^^^^^


Field
^^^^^

*Select Field with options*

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

If the label tag is given (below option!), the values in the drop down are
i18n strings made from label + uppercase(key), e.g 
I18N_OPENXPKI_UI_WORKFLOW_FIELD_REASON_CODE_OPTION_UNSPECIFIED

Global Entities
---------------

You can define entities for action, condition and validator for global use in the corresponding files below ``workflow.global.``. The format is the same as described below, the "global_" prefix is added by the system.

Creating Macros
---------------

If you have a sequence of states/actions you need in multiple workflows, you can 
define them globally as macro. Just put the necessary state and action sections
as written above into a file below ``workflow.macros.<name>``. You need to have
one state named ``INITIAL`` and one ``FINAL``. 

To reference such a macro, create an action in your main workflow and replace the 
``class`` atttribute with ``macro``. Note that this is NOT an extension to the workflow
engine but only merges the definitions from the macro file with those of the current 
workflow. After successful execution, the workflow will be in the state passed in the 
``success`` attribute ofthe surrounding action.



