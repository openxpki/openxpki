MODULE = OpenXPKI		PACKAGE = OpenXPKI::Crypto::Backend::OpenSSL::SPKAC

OpenXPKI_Crypto_Backend_OpenSSL_SPKAC
_new(sv)
	SV * sv
    PREINIT:
	char * spkac;
	STRLEN len;
    CODE:
	spkac = (char*) SvPV(sv, len);
	RETVAL = NETSCAPE_SPKI_b64_decode(spkac, len);
    OUTPUT:
	RETVAL

char *
pubkey_algorithm(spkac)
	OpenXPKI_Crypto_Backend_OpenSSL_SPKAC spkac
    PREINIT:
	BIO *out;
	char *pubkey;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	i2a_ASN1_OBJECT(out, spkac->spkac->pubkey->algor->algorithm);
	n = BIO_get_mem_data(out, &pubkey);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
	memcpy (char_ptr, pubkey, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
pubkey(spkac)
	OpenXPKI_Crypto_Backend_OpenSSL_SPKAC spkac
    PREINIT:
	BIO *out;
	EVP_PKEY *pkey;
	char *pubkey;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_PUBKEY_get(spkac->spkac->pubkey);
	if (pkey != NULL)
	{
	    if (pkey->type == EVP_PKEY_RSA)
		RSA_print(out,pkey->pkey.rsa,0);
            if (pkey->type == EVP_PKEY_DSA)
		DSA_print(out,pkey->pkey.dsa,0);
	    EVP_PKEY_free(pkey);
	}
	n = BIO_get_mem_data(out, &pubkey);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
	memcpy (char_ptr, pubkey, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
pubkey_hash (spkac, digest_name="sha1")
	OpenXPKI_Crypto_Backend_OpenSSL_SPKAC spkac
	char *digest_name
    PREINIT:
	EVP_PKEY *pkey;
	BIO *out;
	int j;
	unsigned int n;
	const EVP_MD *digest;
	char * fingerprint;
	unsigned char md[EVP_MAX_MD_SIZE];
	unsigned char *data = NULL;
	int length;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_PUBKEY_get(spkac->spkac->pubkey);
	if (pkey != NULL)
	{
		length = i2d_PublicKey (pkey, NULL);
		/* data = OPENSSL_malloc(length+1); */
                /* Do not free this pointer! It is from the EVP_PKEY structure. */
		length = i2d_PublicKey (pkey, &data);
		if (!strcmp ("sha1", digest_name))
			digest = EVP_sha1();
		else
			digest = EVP_md5();

		if (EVP_Digest(data, length, md, &n, digest, NULL))
		{
			BIO_printf(out, "%s:", OBJ_nid2sn(EVP_MD_type(digest)));
			for (j=0; j<(int)n; j++)
			{
				BIO_printf (out, "%02X",md[j]);
				if (j+1 != (int)n) BIO_printf(out,":");
			}
		}
		/* OPENSSL_free (data); */
		EVP_PKEY_free(pkey);
	}
	n = BIO_get_mem_data(out, &fingerprint);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, (int)n+1, char);
        memcpy (char_ptr, fingerprint, (int)n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
keysize (spkac)
	OpenXPKI_Crypto_Backend_OpenSSL_SPKAC spkac
    PREINIT:
	BIO *out;
	EVP_PKEY *pkey;
	char * pubkey;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_PUBKEY_get(spkac->spkac->pubkey);
	if (pkey != NULL)
	{
		if (pkey->type == EVP_PKEY_RSA)
			BIO_printf(out,"%d", BN_num_bits(pkey->pkey.rsa->n));
		EVP_PKEY_free(pkey);
	}
	n = BIO_get_mem_data(out, &pubkey);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, pubkey, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
modulus (spkac)
	OpenXPKI_Crypto_Backend_OpenSSL_SPKAC spkac
    PREINIT:
	char * modulus;
	BIO *out;
	EVP_PKEY *pkey;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_PUBKEY_get(spkac->spkac->pubkey);
	if (pkey != NULL)
	{
	    if (pkey->type == EVP_PKEY_RSA)
		BN_print(out,pkey->pkey.rsa->n);
	    if (pkey->type == EVP_PKEY_DSA)
		BN_print(out,pkey->pkey.dsa->pub_key);
	    EVP_PKEY_free(pkey);
	}
	n = BIO_get_mem_data(out, &modulus);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, modulus, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
exponent (spkac)
	OpenXPKI_Crypto_Backend_OpenSSL_SPKAC spkac
    PREINIT:
	BIO *out;
	EVP_PKEY *pkey;
	char *exponent;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_PUBKEY_get(spkac->spkac->pubkey);
	if (pkey != NULL)
	{
	    if (pkey->type == EVP_PKEY_RSA)
		BN_print(out,pkey->pkey.rsa->e);
	    if (pkey->type == EVP_PKEY_DSA)
		BN_print(out,pkey->pkey.dsa->pub_key);
	    EVP_PKEY_free(pkey);
	}
	n = BIO_get_mem_data(out, &exponent);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, exponent, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
signature_algorithm(spkac)
	OpenXPKI_Crypto_Backend_OpenSSL_SPKAC spkac
    PREINIT:
	BIO *out;
	char *sig;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	i2a_ASN1_OBJECT(out, spkac->sig_algor->algorithm);
	n = BIO_get_mem_data(out, &sig);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, sig, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

void
free(spkac)
	OpenXPKI_Crypto_Backend_OpenSSL_SPKAC spkac
    CODE:
	/* 
        if (spkac != NULL) NETSCAPE_SPKI_free(spkac);
	SAFEFREE(char_ptr);
        */

