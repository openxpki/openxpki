
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

For production systems it is usual to have the Issuing CA under a 
Root CA and manage the Root CA on a offline system. As OpenXPKI needs
the full chain of a certificate, you need to import the root certificate
first::

    openxpkiadm certificate import --file ca-root-1.crt 

Issuing Certificate
^^^^^^^^^^^^^^^^^^^

After importing the root, or if you do not have a dedicated root, you 
can now import the issuing certificate::
        
    openxpkiadm certificate import  --file ca-one-signer-1.crt \
        --realm ca-one --token certsign
        
This will import the certificate and also create a so called alias to
mark this certificate as issuing token. With the default config, the key
file is expected to be at /etc/openxpki/ssl/ca-one/ca-one-signer-1.pem.


Datasafe Token
^^^^^^^^^^^^^^

The datasafe token is represented by a certificate but is never
exposed to the public so it is acceptable to use a self-signed 
certificate here. 

    openxpkiadm certificate import  --file ca-one-vault-1.crt \
        --realm ca-one --token datasafe
        
The token is used for encrypting new items only as long as the certificate
is valid. Expired tokens are still needed to decrypt existing items so
never delete or overwrite them!

Token Rollover
--------------

If the lifetime of a token is approaching its end, you can just add a
new token using the same commands as above. OpenXPKI will increase the 
internal generation counter and assign it to the new alias. Just make 
sure your key file has the correct name! If your token key are protected
with a password, make sure that all passwords for all generations are 
still accessible as long as you need the token - issuing tokens are 
usually used to sign CRLs even after their active issuing period is over
and datasafe tokens are required to access archived keys or other data.




