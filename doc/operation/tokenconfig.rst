
Crypto Token Configuration 
==========================

Overview
--------

A cypto token is an entity used to do cryptographic operations. OpenXPKI
organizes those tokens using groups and generations. A default system 
has four groups:

* certsign - represents the Issuing CA
* datasafe - used internally to encrypt sensitive data
* scep - the operational certificate of the SCEP server
* root - the root certificate of the Issuing CA chain

OpenXPKI expects that a token has only a limited lifetime and is 
substituted by a successor at a certain point in time. This relation is
expressed by the generation counter.

Initial Setup
-------------

All tokens consist of a private key and a certificate, the certificate
must be present in the OpenXPKI internal database and is referenced by
the certificate identifier. The private key lives outside the OpenXPKI
systems. When using the default config, the system expects the private
key as file where the name of the file is constructed from the complete
alias name. 

Root Certificate
^^^^^^^^^^^^^^^^




    openxpkiadm certificate import  --file ca-root-1.crt 
        
    openxpkiadm certificate import  --file ca-one-signer-1.crt \
        --realm ca-one --token certsign


