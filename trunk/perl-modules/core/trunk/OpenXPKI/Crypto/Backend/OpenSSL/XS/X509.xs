MODULE = OpenXPKI		PACKAGE = OpenXPKI::Crypto::Backend::OpenSSL::X509

OpenXPKI_Crypto_Backend_OpenSSL_X509
_new_from_der(sv)
	SV * sv
    PREINIT:
	const unsigned char * dercert;
	STRLEN certlen;
    CODE:
	dercert = (const unsigned char *) SvPV(sv, certlen);
	RETVAL = d2i_X509(NULL,&dercert,certlen);
    OUTPUT:
	RETVAL

OpenXPKI_Crypto_Backend_OpenSSL_X509
_new_from_pem(sv)
	SV * sv
    PREINIT:
	unsigned char * pemcert;
	const unsigned char * dercert;
	STRLEN certlen, inlen;
	char inbuf[512];
	BIO *bio_in, *bio_out, *b64;
    CODE:
	pemcert = (unsigned char *) SvPV_force(sv, certlen);
	bio_in  = BIO_new(BIO_s_mem());
	bio_out = BIO_new(BIO_s_mem());
	b64     = BIO_new(BIO_f_base64());

	/* load encoded data into bio_in */
	BIO_write(bio_in, pemcert+27, certlen-27-25);

	/* set EOF for memory bio */
	BIO_set_mem_eof_return(bio_in, 0);

	/* decode data from one bio into another one */
	BIO_push(b64, bio_in);
        while((inlen = BIO_read(b64, inbuf, 512)) > 0)
		BIO_write(bio_out, inbuf, inlen);

	/* create dercert */
	certlen = BIO_get_mem_data(bio_out, &dercert);

	/* create cert */
	RETVAL = d2i_X509(NULL,&dercert,certlen);
	BIO_free(bio_in);
	BIO_free(bio_out);
        BIO_free(b64);
    OUTPUT:
	RETVAL

void
free(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    CODE:
	if (cert != NULL) X509_free(cert);

SV *
serial(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	char *serial;
    CODE:
	serial = i2s_ASN1_INTEGER(NULL,X509_get_serialNumber(cert));
        RETVAL = newSVpvn(serial, strlen(serial));
	OPENSSL_free(serial);
    OUTPUT:
	RETVAL

SV *
subject(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	BIO *out;
	char *subject;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	X509_NAME_print_ex(out, X509_get_subject_name(cert), 0, OPENXPKI_FLAG_RFC2253);
	n = BIO_get_mem_data(out, &subject);
	RETVAL = newSVpvn(subject, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
openssl_subject(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	char *subject;
    CODE:
	// X509_NAME_print_ex(out, X509_get_subject_name(cert), 0, XN_FLAG_COMPAT);
	subject = X509_NAME_oneline (X509_get_subject_name(cert), NULL, 0);
	RETVAL = newSVpvn(subject, strlen(subject+1));
	OPENSSL_free(subject);
    OUTPUT:
	RETVAL

SV *
issuer(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	BIO *out;
	char *issuer;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	X509_NAME_print_ex(out, X509_get_issuer_name(cert), 0, OPENXPKI_FLAG_RFC2253);
	n = BIO_get_mem_data(out, &issuer);
	RETVAL = newSVpvn(issuer, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
notbefore(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	char *not;
	int n;
	BIO *out;
    CODE:
	out = BIO_new(BIO_s_mem());
	ASN1_TIME_print(out, X509_get_notBefore(cert));
	n = BIO_get_mem_data(out, &not);
	RETVAL = newSVpvn(not, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
notafter(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	char *not;
	int n;
	BIO *out;
    CODE:
	out = BIO_new(BIO_s_mem());
	ASN1_TIME_print(out, X509_get_notAfter(cert));
	n = BIO_get_mem_data(out, &not);
	RETVAL = newSVpvn(not, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
alias(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	int n;
	unsigned char * alias;
    CODE:
	alias = X509_alias_get0(cert, &n);
        if (alias != NULL)
        {
	    RETVAL = newSVpvn((char *) alias, n);
        } else {
            RETVAL = NULL;
        }
    OUTPUT:
	RETVAL

SV *
fingerprint (cert, digest_name="sha1")
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
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
	if (X509_digest(cert,digest,md,&n))
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

unsigned long
subject_hash(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
    CODE:
	RETVAL = X509_subject_name_hash(cert);
    OUTPUT:
	RETVAL

SV *
emailaddress (cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	int j, n;
        STACK *emlst;
	BIO *out;
	char *emails;
    CODE:
	out = BIO_new(BIO_s_mem());
	emlst = X509_get1_email(cert);
	for (j = 0; j < sk_num(emlst); j++)
	{
		BIO_printf(out, "%s", sk_value(emlst, j));
		if (j+1 != (int)sk_num(emlst))
			BIO_printf(out,"\n");
	}
	X509_email_free(emlst);
	n = BIO_get_mem_data(out, &emails);
	RETVAL = newSVpvn(emails, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
version(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	BIO *out;
	char *version;
	long l;
    CODE:
	out = BIO_new(BIO_s_mem());
	l = X509_get_version(cert);
	BIO_printf (out,"%lu (0x%lx)",l+1,l);
	l = BIO_get_mem_data(out, &version);
	RETVAL = newSVpvn(version, l);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
pubkey_algorithm(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	BIO *out;
	char *pubkey;
	X509_CINF *ci;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	ci = cert->cert_info;
	i2a_ASN1_OBJECT(out, ci->key->algor->algorithm);
	n = BIO_get_mem_data(out, &pubkey);
	RETVAL = newSVpvn(pubkey, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
pubkey(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	BIO *out;
	EVP_PKEY *pkey;
	char *pubkey;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_get_pubkey(cert);
	if (pkey != NULL)
	{
		if (pkey->type == EVP_PKEY_RSA)
			RSA_print(out,pkey->pkey.rsa,0);
		else if (pkey->type == EVP_PKEY_DSA)
			DSA_print(out,pkey->pkey.dsa,0);
                else if (pkey->type == EVP_PKEY_EC)
                        EC_KEY_print(out,pkey->pkey.ec,0);
		EVP_PKEY_free(pkey);
	}
	n = BIO_get_mem_data(out, &pubkey);
	RETVAL = newSVpvn(pubkey, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
pubkey_hash (cert, digest_name="sha1")
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
	char *digest_name
    PREINIT:
	BIO *out;
	int j;
	unsigned int n;
	const EVP_MD *digest;
	char * hash;
	unsigned char md[EVP_MAX_MD_SIZE];
    CODE:
	out = BIO_new(BIO_s_mem());
	if (!strcmp ("sha1", digest_name))
		digest = EVP_sha1();
	else
		digest = EVP_md5();
	if (X509_pubkey_digest(cert,digest,md,&n))
	{
		BIO_printf(out, "%s:", OBJ_nid2sn(EVP_MD_type(digest)));
		for (j=0; j<(int)n; j++)
		{
			BIO_printf (out, "%02X",md[j]);
			if (j+1 != (int)n) BIO_printf(out,":");
		}
	}
	n = BIO_get_mem_data(out, &hash);
	RETVAL = newSVpvn(hash, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
keysize (cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	BIO *out;
	EVP_PKEY *pkey;
	char * length;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_get_pubkey(cert);
	if (pkey != NULL)
	{
            BIO_printf(out,"%d", EVP_PKEY_bits(pkey));
	}
	n = BIO_get_mem_data(out, &length);
	RETVAL = newSVpvn(length, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
modulus (cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	char * modulus;
	BIO *out;
	EVP_PKEY *pkey;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_get_pubkey(cert);
	if (pkey != NULL)
	{
	    if (pkey->type == EVP_PKEY_RSA)
		BN_print(out,pkey->pkey.rsa->n);
	    if (pkey->type == EVP_PKEY_DSA)
		BN_print(out,pkey->pkey.dsa->pub_key);
	    EVP_PKEY_free(pkey);
	}
	n = BIO_get_mem_data(out, &modulus);
	RETVAL = newSVpvn(modulus, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
exponent (cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	BIO *out;
	EVP_PKEY *pkey;
	char *exponent;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_get_pubkey(cert);
	if (pkey != NULL)
	{
	    if (pkey->type == EVP_PKEY_RSA)
		BN_print(out,pkey->pkey.rsa->e);
	    if (pkey->type == EVP_PKEY_DSA)
		BN_print(out,pkey->pkey.dsa->pub_key);
	    EVP_PKEY_free(pkey);
	}
	n = BIO_get_mem_data(out, &exponent);
	RETVAL = newSVpvn(exponent, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
extensions(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	BIO *out;
	char *ext;
	X509_CINF *ci;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	ci = cert->cert_info;
	// there is a bug in X509V3_extensions_print
	// the causes the function to fail if title == NULL and indent == 0
	X509V3_extensions_print(out, NULL, ci->extensions, 0, 4);
	n = BIO_get_mem_data(out, &ext);
	RETVAL = newSVpvn(ext, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
signature_algorithm(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	BIO *out;
	char *sig;
	X509_CINF *ci;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	ci = cert->cert_info;
	i2a_ASN1_OBJECT(out, ci->signature->algorithm);
	n = BIO_get_mem_data(out, &sig);
	RETVAL = newSVpvn(sig, n);
	BIO_free(out);
    OUTPUT:
	RETVAL

SV *
signature(cert)
	OpenXPKI_Crypto_Backend_OpenSSL_X509 cert
    PREINIT:
	BIO *out;
	char *sig;
	int n,i;
	unsigned char *s;
    CODE:
	out = BIO_new(BIO_s_mem());
	n=cert->signature->length;
	s=cert->signature->data;
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

