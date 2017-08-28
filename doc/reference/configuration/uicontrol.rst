Customization of UI components
===============================

Menustructure, search options and some additional items can be configured
based on the user role using the files located in the uicontrol/ folder.
There can be one file for each role, if no role file is found, the
configuration from _default.yaml is loaded. Note that there is no
inheritance, so you always need to provide a full file per role.

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
