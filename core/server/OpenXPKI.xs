#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* #include "ppport.h" */

/* #include <openssl/ossl_typ.h> */
#include <openssl/engine.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>
#include <openssl/bn.h>
#include <openssl/rsa.h>
#include <openssl/dsa.h>
#include <openssl/ec.h>

/* Standard trick to have a C pointer as a Perl object, see the typemap */
typedef X509_CRL      * OpenXPKI_Crypto_Backend_OpenSSL_CRL;

/* hack to avoid MSB escaping by OpenSSL */
#define OPENXPKI_FLAG_RFC2253 (XN_FLAG_RFC2253&(~ASN1_STRFLGS_ESC_MSB))

MODULE = OpenXPKI PACKAGE = OpenXPKI

INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL.xs
