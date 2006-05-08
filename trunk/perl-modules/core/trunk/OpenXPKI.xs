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

/* Standard trick to have a C pointer as a Perl object, see the typemap */
typedef X509          * OpenXPKI_Crypto_Backend_OpenSSL_X509;
typedef X509_CRL      * OpenXPKI_Crypto_Backend_OpenSSL_CRL;
typedef NETSCAPE_SPKI * OpenXPKI_Crypto_Backend_OpenSSL_SPKAC;
typedef X509_REQ      * OpenXPKI_Crypto_Backend_OpenSSL_PKCS10;

/* general pointer to avoid memory leaks because fo char * returns */
char * char_ptr = NULL;
char * uchar_ptr = NULL;

/* free is only safe if we test the pointer before free and
   reset the pointer to NULL after this macro */
#define SAFEFREE(pointer) if (pointer!=NULL) Safefree(pointer); pointer=NULL;

/* hack to avoid MSB escaping by OpenSSL */
#define OPENXPKI_FLAG_RFC2253 (XN_FLAG_RFC2253&(~ASN1_STRFLGS_ESC_MSB))

MODULE = OpenXPKI PACKAGE = OpenXPKI

INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL.xs
