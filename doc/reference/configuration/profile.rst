Profile Configuration
======================

A certificate profile is the blueprint that determines all technical
aspects of the certificate such as subject pattern, key usages and
other extensions.

Naming
------

The internal name of the profile is the name of the node in the
configuration layer. If you keep the sample structure each profile is in
a single file in the profile directory, so the name of the profile is
the name of the file.

You can add `label` and `description` to the profile, which is used for
display purpose on the WebUI frontend only, it has no effect on the
actual certificate.


Validity
--------

The validity is usually defined by a relative time specification of the
format +YYMMDDhhmmss, (e.g. +0006 for six month, see OpenXPKI::DateTime)::

    validity:
        notafter: +0006

The actual value is determined at the moment the PKI really signs the
request. You can also add a notbefore date, in this case the notafter
date is calculated relative to notbefore::

    validity:
        notafter: +000001
        notafter: +0006

Above example will create a certificate with a notbefore 24 hours ahead
of the time of issuance and ends 6 months + 1 day later.

It is also possible to give an absolute date as YYYYMMDDhhmmss.

Styles
------

t.b.d

Subject and Process Information
-------------------------------

OpenXPKI can collect meta information based on the selected profile and
has a templating engine to build subject and subject alternative name
sections (SAN) from the input data in many different ways.

The input fields are summarized in three groups: subject, san and info::

    00_basic_style:
        label: I18N_OPENXPKI_UI_PROFILE_BASIC_STYLE_LABEL
        description: I18N_OPENXPKI_UI_PROFILE_BASIC_STYLE_DESC
        ui:
            subject:
                - hostname
                - hostname2
                - port
            san:
                - san_ipv4
            info:
                - requestor_gname
                - requestor_name
                - requestor_email
                - requestor_affiliation
                - comment

Each section can hold any number of fields, each field is defined by a
set of options::

    id: hostname
    label: I18N_OPENXPKI_UI_PROFILE_HOSTNAME
    placeholder: fully.qualified.example.com
    tooltip: I18N_OPENXPKI_UI_PROFILE_HOSTNAME_TOOLTIP
    description: I18N_OPENXPKI_UI_PROFILE_HOSTNAME_DESC
    type: freetext
    preset: "[% CN.0.replace(':.*','') %]"
    match: \A [A-Za-z\d\-\.]+ \z
    width: 60

The definition can be placed in the node `template` inside the profile
file or globally in the template directory.

To not break legacy configurations, the placeholder can be set using
"default" as keyword. The tooltip is set to description if missing.


Field Definition
^^^^^^^^^^^^^^^^

id
  the key used when this item is written into the workflow

label
  the label shown next to the input field

description
  description, shown as tooltip

type
  the type of the field, freetext or select

option
  list of options for the select field (used value is equal to the label)

preset
  in case a CSR is uploaded by the user, you can use parts of it to prefill
  the fields. Items from the subject can be referenced by the name of the
  component, items from the subject alternative name section are prefixed
  with the string `SAN_`, e.g. `SAN_DNS`. Note that all keys are uppercased
  and all items are arrays regardless of the number of items found!

  There are several options for preprocessing the items.

  First item of type CN::

     preset: CN.0

  All items of type OU (creates on field per item)::

     preset: OU.X

  Use templating to extract left side of CN up to the first colon::

    preset: "[% CN.0.replace(':.*','') %]"

  Use templating to create a list of items, the pipe symbol is used as seperator::

    preset: "[% FOREACH ou = OU %][% ou %]|[% END %]"

match
  a regex pattern that is applied to the user input for validation

width
  size of the field - not implemented yet, definition might change.

default
  A text which is shown as placeholder in the input field (this value is
  NOT a default value for the field)


Subject Rendering
^^^^^^^^^^^^^^^^^

The full distinguished name and the Subject Alternative Name items are
created using template toolkit rules from the information that have been
collected from the input fields in the "subject" step::

    subject:
        dn: CN=[% hostname.lower %][% IF port AND port != 443 %]:[% port %][% END %],DC=Test Deployment,DC=OpenXPKI,DC=org
        san:
            DNS:
             - "[% hostname.lower %]"
             - "[% FOREACH entry = hostname2 %][% entry.lower %] | [% END %]"

The name of the variable it the one given as "id" in the field definition,
all non empty values are available for DN and SAN rendering.

If you have provided an extra SAN section in the input fields definition,
those are merged into the SAN part WITHOUT any parsing "as is".


Extensions
----------

t.b.d.


Key Parameters
^^^^^^^^^^^^^^

OpenXPKI supports serverside key generation as well as PKCS10 upload.
For both cases you can control what algorithms and parameters are allowed,
even on a per profile basis. The default configuration has the key
definition in the default.yaml file.

Basic definition of allowed key and encryption algorithms::

    key:
        # Supported key algorithms (details need to be defined below!)
        alg:
          - rsa
          - ec
          - dsa

        # Supported encryption algorithms (as taken by openssl)
        enc:
          - aes256
          - _3des
          - idea

        # one of escrow, server, client, both
        # escrow is not implemented in workflows, yet!
        generate: both

For RSA and DSA, you need to define the allowed key sizes in bits:

    rsa:
        key_length:
          - 2048
          - 4096
          - _1024

Those values are used for the key generation dialog as well as for the
validation of uploaded PKCS10 files. Values with an underscore are hidden
from the UI.

For ECC, you need to specify the curve names::

    ec:
        curve_name:
          - prime256v1
          - secp384r1
          - secp521r1

The possbile "named" curves are limited by the ones supported by
Crypt::PKCS10 at the moment. For NIST P-192/256 you can use either the
secpXXXr1 or primeXXXv1 alias.
