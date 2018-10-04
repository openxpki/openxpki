Customization of UI components
===============================

Menustructure, search options and some additional items can be configured
based on the user role using the files located in the uicontrol/ folder.
There can be one file for each role, if no role file is found, the
configuration from _default.yaml is loaded. Note that there is no
inheritance, so you always need to provide a full file per role.

Format Result List
------------------

Those options apply to (almost) all sections that deal with result lists
for workflows or certificates.

Column Layout
#############

Add a section ``cols`` to you definition block::
.
    cols:
      - label: I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL
        field: WORKFLOW_SERIAL
      - label: I18N_OPENXPKI_UI_WORKFLOW_SEARCH_UPDATED_LABEL
        field: WORKFLOW_LAST_UPDATE
      - label: I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL
        field: WORKFLOW_STATE
      - label: I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT
        field: context.cert_subject
      - label: I18N_OPENXPKI_UI_WORKFLOW_FIELD_TRANSACTION_ID_LABEL
        template: "[% context.transaction_id %]"

Label and either field or template are mandatory. Optional keys are sortkey,
which is required to use sorting together with templates, and format which
adds a formatting rule such as "timestamp" or "certstatus" (See the WebUI
Page API Reference for all available formats).

Pager
#####

The pager has default settings in the code but you can provide your own
values::

    pager:
      pagesizes: 10, 20, 50, 100
      pagersize: 5

The pagesizes parameter is responsible for the "Items per page" selector.
The pagersite parameter refers to the number of itesm in the page selector.

Certificate search mask
-----------------------

The four fields Subject, Subject. Alt Name, Profile and Status are fixed.
You can add additional that are combined to a cloneable dual-select field
to search for data in the certificate_attributes tables.

Add a block named "certsearch" to the uicontrol file::

  certsearch:
    default:
      attributes:
       - label: I18N_OPENXPKI_UI_WORKFLOW_FIELD_ENTITY_LABEL
         key: meta_entity

       - label: I18N_OPENXPKI_UI_SEARCH_REQUESTOR_NAME_LABEL
         key: meta_requestor
         pattern: '*%s*'
         operator: inlike

       - label: I18N_OPENXPKI_UI_SEARCH_REQUESTOR_EMAIL_LABEL
         key: meta_email
         operator: in
         transform: lower

Label and key are mandatory, key is the attributes key to be found in
certificate_attributes, as of v1.19 the default operator is "IN", so multiple
values given for the same key are "ORed" (up to 1.18 this was AND which
confused most users).

Possible operators are LIKE and EQUAL (values are ANDed!) or the special
"INLIKE" (LIKE pattern with values ORed).

The transform and pattern keyword allow preprocessing of the input values
prior passing it to the SQL engine. Transform can be ``upper`` or ``lower``
which applies the uppercase/lowercase method to the value, pattern is used
with sprintf::

    $val = sprintf($pattern, $val);

Each transformation is applied individually on each value.

Workflow search mask
-----------------------

This is the same as for the certificate search mask, the uicontrol key is
``wfsearch``, queries are executed against the workflow_attributes table.


Tasklist
--------

The page "My Tasks" can hold multiple blocks showing a list of workflows.
Minimal configuration for one item looks like::

  tasklist:
    - label: I18N_OPENXPKI_UI_TASKLIST_PENDING_REVOCATION_LABEL
      description: I18N_OPENXPKI_UI_TASKLIST_PENDING_REVOCATION_DESCRIPTION
      query:
        TYPE:
          - certificate_revocation_request_v2
        STATE:
          - PENDING

Label and description are shown on top of the result table, anything below
``query`` is handed as parameter to the search_workflow_instances API method.

If the result set of the query is empty, the default behaviour is to display
a default "No result" test. You can customize this text using the ``ifempty``
parameter:

  - label: I18N_OPENXPKI_UI_TASKLIST_PENDING_ENROLLMENT_LABEL
    description: I18N_OPENXPKI_UI_TASKLIST_PENDING_ENROLLMENT_DESCRIPTION
    ifempty: Sorry but there is nothing to do today...

If you dont want to show an empty the result at all, pass the special word
``hide``::

  - label: I18N_OPENXPKI_UI_TASKLIST_PENDING_ENROLLMENT_LABEL
    description: I18N_OPENXPKI_UI_TASKLIST_PENDING_ENROLLMENT_DESCRIPTION
    ifempty: hide




