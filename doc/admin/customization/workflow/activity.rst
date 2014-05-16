Writing a workflow activity
============================

Perl Code
----------

We strongly advise to create a custom namespace for your workflow classes!
You **should** derive your classes from *OpenXPKI::Server::Workflow::Activity*,
but you **must** derive if you want to use the pause/resume/autofail functionality.

A skeleton class OpenXPKI::Server::Workflow::Activity::Skeleton is provided as 
a point to start with. Here is some pseudocode to show the basic idea on the 
scheduler system.

pause a workflow
^^^^^^^^^^^^^^^^

If you need to wait for some other things to happen before you can continue, 
you can simply pause the workflow by calling::

    if ($need_to_wait) {
        $self->pause('Waiting for Godot');
    }    

The activity will return immediately and the workflow stops. After the retry_interval
elapsed, the scheduler reinstantiates the workflow, calls the *wake_up* funktion and 
afterwards the *execute* method again. 

You can also set the retry parameters from inside the action::
    
    # Set the interval after three invalid tries to 1 hour
    if ($workflow->get_retry_count() > 3) {
        $self->set_retry_intervall('+00000001');
    }
    
resume from an exception
^^^^^^^^^^^^^^^^^^^^^^^^

It might happen that your code raised an exception and you need to clean up
the context or check/rollback some other things before you will continue
the normal operation. Such code should be placed into the *resume* method
which gets executed after an exception was thrown.     
  

XML Configuration
------------------

To use an activity in the workflow system, you must create a mapping between
the perl class and a symbolic name. It is allowed to reuse the same class with
different names (and likely different parameters)::

    <action name="I18N_OPENXPKI_WF_ACTION_MY_ACTION"
        class="OpenXPKI::Server::Workflow::Custom::Activity::MyAction">                        
    </action>

For detailed information see the perldoc of Workflow.pm. 

The OpenXPKI server comes with a scheduler to detach workflows from the frontend
and continue them in the background.:: 
  
    <actions>
        <action name="I18N_OPENXPKI_WF_ACTION_MY_ACTION"
            class="OpenXPKI::Server::Workflow::Custom::Activity::MyAction"
                retry_count="5" 
                retry_interval="+0000000030">               
        </action>
    </actions>

You can set the retry parameters also in the workflow definition. Those settings
are superior to the once in the action definition:: 

    <state name="STEP3">
        <description></description>
    
        <action name="I18N_OPENXPKI_WF_ACTION_MY_ACTION" 
            resulting_state="SUCCESS"
            retry_count="7"                        
            autofail="yes">      
        </action>
      </state>


This configuration will run the action up to 7 times with a pause of approx 
30 minutes between the retries. If the method does not finish while its seventh
loop, the workflow is stopped with an error. As we have the *autofail* flag set,
the workflow is immediately send into the *FAILURE* state and set to finished.    
Note that the autofail flag is only allowed in the <state> block, but not in
the activity definition itself!

Important Precondition
^^^^^^^^^^^^^^^^^^^^^^

Do not use activities with pause together with conditions that might change over
time! Workflows are always resumed by state and if your paused activity is 
linked with a condition, it gets re-evaluated. If the result is false now,
the workflow layer will block access to the (formerly paused) activity so the 
watchdog can not rerun it. 

To solve such issues, either create two seperate states for the evaluation and the
paused activity (using a NOOP activity) or write your condition in a way that it 
will not change, e.g. by persisting the relevant parameters into the context on 
the first run.



