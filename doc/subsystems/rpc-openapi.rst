.. _openapi-overview:

OpenAPI (aka Swagger)
=====================

This is not really an own subsystem but it offers an auto-generated `OpenAPI <https://www.openapis.org/>`_ 3.0 compliant specification of the RPC interface.

To generate the OpenAPI spec according to your current RPC configuration see :ref:`openapi-rpc-method`.

The `info` block of the specification is by default set to contain a generic `title` and inherits the `version` number from `system.config.api` (as obtained by the `version` API call). To provide your own values for the info block, add a section `[openapi]` to the RPC wrapper configuration and set the expected values::

    [openapi]
    title = Public Certificate Reqest API
    description = Request, Renew and Revoke your Certificates her
    version = 42.1


The data types of all relevant input/output parameters of those workflows exposed via RPC must be defined (in the workflow config) to be able to generate the OpenAPI spec. For details see :ref:`openapi-workflow-field-param`.
