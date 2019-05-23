MODULE = OpenXPKI		PACKAGE = OpenXPKI::Crypto::Backend::OpenSSL::CRL
  
OpenXPKI_Crypto_Backend_OpenSSL_CRL
_new_from_der(sv)
	SV * sv
    PREINIT:
	const unsigned char * dercrl;
	STRLEN crllen;
    CODE:
	dercrl = (unsigned char*) SvPV(sv, crllen);
	RETVAL = d2i_X509_CRL(NULL,&dercrl,crllen);
    OUTPUT:
	RETVAL

OpenXPKI_Crypto_Backend_OpenSSL_CRL
_new_from_pem(sv)
	SV * sv
    PREINIT:
	unsigned char * pemcrl;
	const unsigned char * dercrl;
	STRLEN crllen, inlen;
	char inbuf[512];
	BIO *bio_in, *bio_out, *b64;
	X509_CRL *crl;
    CODE:
	pemcrl = (unsigned char*) SvPV(sv, crllen);
	bio_in  = BIO_new(BIO_s_mem());
	bio_out = BIO_new(BIO_s_mem());
	b64     = BIO_new(BIO_f_base64());

	/* load encoded data into bio_in */
	BIO_write(bio_in, pemcrl+25, crllen-25-23);

	/* set EOF for memory bio */
	BIO_set_mem_eof_return(bio_in, 0);

	/* decode data from one bio into another one */
	BIO_push(b64, bio_in);
        while((inlen = BIO_read(b64, inbuf, 512)) > 0)
		BIO_write(bio_out, inbuf, inlen);

	/* create dercert */
	crllen = BIO_get_mem_data(bio_out, &dercrl);

	/* create cert */
	crl = d2i_X509_CRL(NULL,&dercrl,crllen);
	RETVAL = crl;
	BIO_free(bio_in);
	BIO_free(bio_out);
        BIO_free(b64);
    OUTPUT:
	RETVAL

void
free(crl)
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    CODE:
	if (crl != NULL) X509_CRL_free(crl);

SV *
version(crl)
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    PREINIT:
	BIO *out;
	char *version;
	long l;
    CODE:
	out = BIO_new(BIO_s_mem());
	l = X509_CRL_get_version(crl);
	BIO_printf (out,"%lu (0x%lx)",l+1,l);
	l = BIO_get_mem_data(out, &version);
	RETVAL = newSVpvn(version, l);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
issuer(crl)
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    PREINIT:
	BIO *out;
	char *issuer;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	X509_NAME_print_ex(out, X509_CRL_get_issuer(crl), 0, OPENXPKI_FLAG_RFC2253);
	n = BIO_get_mem_data(out, &issuer);
	RETVAL = newSVpvn(issuer,n);
	BIO_free(out);
    OUTPUT:
	RETVAL

unsigned long
issuer_hash(crl)
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    PREINIT:
    CODE:
	RETVAL = X509_NAME_hash(X509_CRL_get_issuer(crl));
    OUTPUT:
	RETVAL

SV *
last_update(crl)
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    PREINIT:
	char *not;
	int n;
	BIO *out;
    CODE:
	out = BIO_new(BIO_s_mem());
#if OPENSSL_VERSION_NUMBER < 0x10100000L
	ASN1_TIME_print(out, X509_CRL_get_lastUpdate(crl));
#else
	ASN1_TIME_print(out, X509_CRL_get0_lastUpdate(crl));
#endif
	n = BIO_get_mem_data(out, &not);
	RETVAL = newSVpvn(not, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
next_update(crl)
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    PREINIT:
	char *not;
	int n;
	BIO *out;
    CODE:
	out = BIO_new(BIO_s_mem());
#if OPENSSL_VERSION_NUMBER < 0x10100000L
        ASN1_TIME_print(out, X509_CRL_get_nextUpdate(crl));
#else
	ASN1_TIME_print(out, X509_CRL_get0_nextUpdate(crl));
#endif
	n = BIO_get_mem_data(out, &not);
	RETVAL = newSVpvn(not, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
fingerprint (crl, digest_name="sha1")
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
	char *digest_name
    PREINIT:
	BIO *out;
	int j;
	unsigned int n;
	const EVP_MD *digest;
	char * fingerprint;
	unsigned char md[EVP_MAX_MD_SIZE];
    CODE:
	out = BIO_new(BIO_s_mem());
	if (!strcmp ("sha1", digest_name))
		digest = EVP_sha1();
	else
		digest = EVP_md5();
	if (X509_CRL_digest(crl,digest,md,&n))
	{
		BIO_printf(out, "%s:", OBJ_nid2sn(EVP_MD_type(digest)));
		for (j=0; j<(int)n; j++)
		{
			BIO_printf (out, "%02X",md[j]);
			if (j+1 != (int)n) BIO_printf(out,":");
		}
	}
	n = BIO_get_mem_data(out, &fingerprint);
	RETVAL = newSVpvn(fingerprint, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
signature_algorithm(crl)
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    PREINIT:
        BIO *out;
        const X509_ALGOR *sig_alg;
        const ASN1_BIT_STRING *signature;
	char *sig;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
#if OPENSSL_VERSION_NUMBER < 0x10100000L
	i2a_ASN1_OBJECT(out, crl->sig_alg->algorithm);
#else
        X509_CRL_get0_signature(crl, &signature, &sig_alg);
	i2a_ASN1_OBJECT(out, sig_alg->algorithm);
#endif
	n = BIO_get_mem_data(out, &sig);
	RETVAL = newSVpvn(sig, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
signature(crl)
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    PREINIT:
	BIO *out;
        const X509_ALGOR *sig_alg;
        const ASN1_BIT_STRING *signature;
	char *sig;
	int n,i;
	unsigned char *s;
    CODE:
	out = BIO_new(BIO_s_mem());
#if OPENSSL_VERSION_NUMBER < 0x10100000L
	n=crl->signature->length;
	s=crl->signature->data;
#else
        X509_CRL_get0_signature(crl, &signature, &sig_alg);
	n=signature->length;
        s=signature->data;
#endif
	for (i=0; i<n; i++)
	{
		if ( ((i%18) == 0) && (i!=0) ) BIO_printf(out,"\n");
		BIO_printf(out,"%02x%s",s[i], (((i+1)%18) == 0)?"":":");
	}
	n = BIO_get_mem_data(out, &sig);
	RETVAL = newSVpvn(sig, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
extensions(crl)
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    PREINIT:
	BIO *out;
        const STACK_OF(X509_EXTENSION) *exts;
	char *ext;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	// there is a bug in X509V3_extensions_print
	// the causes the function to fail if title == NULL and indent == 0
#if OPENSSL_VERSION_NUMBER < 0x10100000L
	X509V3_extensions_print(out, NULL, crl->crl->extensions, 0, 4);
#else
        exts = X509_CRL_get0_extensions(crl);
	X509V3_extensions_print(out, NULL, exts, 0, 4);
#endif
	n = BIO_get_mem_data(out, &ext);
	RETVAL = newSVpvn(ext, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

long
serial(crl)
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    PREINIT:
	ASN1_INTEGER *aint;
    CODE:
	RETVAL = -1;
	aint = X509_CRL_get_ext_d2i (crl, NID_crl_number, NULL, NULL);
	if (aint != NULL)
        {
	    RETVAL = ASN1_INTEGER_get (aint);
            ASN1_INTEGER_free(aint);
        }
    OUTPUT:
	RETVAL

SV *
revoked(crl)
	OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    PREINIT:
	BIO *out;
	char *ext;
	int n,i;
	STACK_OF(X509_REVOKED) *rev;
	X509_REVOKED *r;
    CODE:
	out = BIO_new(BIO_s_mem());
	// there is a bug in X509V3_extensions_print
	// the causes the function to fail if title == NULL and indent == 0

	rev = X509_CRL_get_REVOKED(crl);

	for(i = 0; i < sk_X509_REVOKED_num(rev); i++) {
		r = sk_X509_REVOKED_value(rev, i);
#if OPENSSL_VERSION_NUMBER < 0x10100000L
		i2a_ASN1_INTEGER(out,r->serialNumber);
#else
		i2a_ASN1_INTEGER(out,X509_REVOKED_get0_serialNumber(r));
#endif		
		BIO_printf(out,"\n        ");
#if OPENSSL_VERSION_NUMBER < 0x10100000L
		ASN1_TIME_print(out,r->revocationDate);
#else
		ASN1_TIME_print(out,X509_REVOKED_get0_revocationDate(r));
#endif
		BIO_printf(out,"\n");
#if OPENSSL_VERSION_NUMBER < 0x10100000L
		X509V3_extensions_print(out, NULL,
			r->extensions, 0, 8);
#else
		X509V3_extensions_print(out, NULL,
			X509_REVOKED_get0_extensions(r), 0, 8);
#endif
	}
	n = BIO_get_mem_data(out, &ext);
	RETVAL = newSVpvn(ext, n);
	BIO_free(out);
    OUTPUT:
	RETVAL
	
int
itemcnt(crl)
    OpenXPKI_Crypto_Backend_OpenSSL_CRL crl
    PREINIT:
    BIO *out;
    char *ext;
    int n,i;
    STACK_OF(X509_REVOKED) *rev;
    X509_REVOKED *r;
    CODE:
    rev = X509_CRL_get_REVOKED(crl);
    RETVAL = sk_X509_REVOKED_num(rev);
    if (RETVAL < 0) {
        RETVAL = 0;
    }
    OUTPUT:
    RETVAL
