MODULE = OpenXPKI		PACKAGE = OpenXPKI::Crypto::Backend::OpenSSL::PKCS10

OpenXPKI_Crypto_Backend_OpenSSL_PKCS10
_new_from_der(sv)
	SV * sv
    PREINIT:
	const unsigned char * dercsr;
	SSize_t csrlen;
    CODE:
	dercsr = SvPV(sv, csrlen);
	RETVAL = d2i_X509_REQ(NULL,&dercsr,csrlen);
    OUTPUT:
	RETVAL

OpenXPKI_Crypto_Backend_OpenSSL_PKCS10
_new_from_pem(sv)
	SV * sv
    PREINIT:
	unsigned char * pemcsr;
	const unsigned char * dercsr;
	SSize_t csrlen, inlen;
	char inbuf[512];
	BIO *bio_in, *bio_out, *b64;
    CODE:
	pemcsr  = SvPV(sv, csrlen);
	bio_in  = BIO_new(BIO_s_mem());
	bio_out = BIO_new(BIO_s_mem());
	b64     = BIO_new(BIO_f_base64());

	/* load encoded data into bio_in */
	BIO_write(bio_in, pemcsr+36, csrlen-36-34);

	/* set EOF for memory bio */
	BIO_set_mem_eof_return(bio_in, 0);

	/* decode data from one bio into another one */
	BIO_push(b64, bio_in);
        while((inlen = BIO_read(b64, inbuf, 512)) > 0)
		BIO_write(bio_out, inbuf, inlen);

	/* create dercsr */
	csrlen = BIO_get_mem_data(bio_out, &dercsr);

	/* create csr */
	RETVAL = d2i_X509_REQ(NULL,&dercsr,csrlen);
	BIO_free(bio_in);
	BIO_free(bio_out);
	BIO_free(b64);
    OUTPUT:
	RETVAL

char *
version(csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	BIO *out;
	char *version;
	unsigned char buf[1024];
	long l, i;
	const char *neg;
    CODE:
	out = BIO_new(BIO_s_mem());

	neg=(csr->req_info->version->type == V_ASN1_NEG_INTEGER)?"-":"";
	l=0;
	for (i=0; i<csr->req_info->version->length; i++)
		{ l<<=8; l+=csr->req_info->version->data[i]; }
	/* why we use l and not l+1 like for all other versions? */
	BIO_printf(out,"%s%lu (%s0x%lx)",neg,l,neg,l);
	l = BIO_get_mem_data(out, &version);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, l+1, char);
	memcpy (char_ptr, version, l);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

void
free(csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    CODE:
	if (csr != NULL) X509_REQ_free(csr);
	SAFEFREE(char_ptr);

char *
subject(csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	BIO *out;
	char *subject;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	X509_NAME_print_ex(out, csr->req_info->subject, 0, OPENXPKI_FLAG_RFC2253);
	n = BIO_get_mem_data(out, &subject);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, subject, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

unsigned long
subject_hash(csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
    CODE:
	RETVAL = X509_NAME_hash(csr->req_info->subject);
    OUTPUT:
	RETVAL

char *
fingerprint (csr, digest_name="sha1")
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
	char *digest_name
    PREINIT:
	BIO *out;
	int j;
	unsigned int n;
	const EVP_MD *digest;
	char * fingerprint;
	unsigned char md[EVP_MAX_MD_SIZE];
	unsigned char str[3];
    CODE:
	out = BIO_new(BIO_s_mem());
	if (!strcmp ("sha1", digest_name))
		digest = EVP_sha1();
	else
		digest = EVP_md5();
	if (X509_REQ_digest(csr,digest,md,&n))
	{
		BIO_printf(out, "%s:", OBJ_nid2sn(EVP_MD_type(digest)));
		for (j=0; j<(int)n; j++)
		{
			BIO_printf (out, "%02X",md[j]);
			if (j+1 != (int)n) BIO_printf(out,":");
		}
	}
	n = BIO_get_mem_data(out, &fingerprint);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, fingerprint, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
emailaddress (csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	int j, n;
        STACK *emlst;
	BIO *out;
	char *emails;
    CODE:
	out = BIO_new(BIO_s_mem());
	emlst = X509_REQ_get1_email(csr);
	if (emlst != NULL)
	{
		for (j = 0; j < sk_num(emlst); j++)
		{
			BIO_printf(out, "%s", sk_value(emlst, j));
			if (j+1 != (int)sk_num(emlst))
				BIO_printf(out,"\n");
		}
		X509_email_free(emlst);
	}
	n = BIO_get_mem_data(out, &emails);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, emails, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
pubkey_algorithm(csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	BIO *out;
	char *pubkey;
	X509_REQ_INFO *ri;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	ri = csr->req_info;
	i2a_ASN1_OBJECT(out, ri->pubkey->algor->algorithm);
	n = BIO_get_mem_data(out, &pubkey);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
	memcpy (char_ptr, pubkey, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
pubkey(csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	BIO *out;
	EVP_PKEY *pkey;
	char *pubkey;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_REQ_get_pubkey(csr);
	if (pkey != NULL)
	{
		if (pkey->type == EVP_PKEY_RSA)
			RSA_print(out,pkey->pkey.rsa,0);
		else if (pkey->type == EVP_PKEY_DSA)
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
pubkey_hash (csr, digest_name="sha1")
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
	char *digest_name
    PREINIT:
	EVP_PKEY *pkey;
	ASN1_BIT_STRING *key;
	BIO *out;
	int j;
	unsigned int n;
	const EVP_MD *digest;
	char * fingerprint;
	unsigned char md[EVP_MAX_MD_SIZE];
	unsigned char str[3];
	unsigned char *data = NULL;
	int length;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_REQ_get_pubkey(csr);
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
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, fingerprint, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
keysize (csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	BIO *out;
	EVP_PKEY *pkey;
	unsigned char * pubkey;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_REQ_get_pubkey(csr);
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
modulus (csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	char * modulus;
	BIO *out;
	EVP_PKEY *pkey;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_REQ_get_pubkey(csr);
	if (pkey == NULL)
		BIO_printf(out,"");
	else if (pkey->type == EVP_PKEY_RSA)
		BN_print(out,pkey->pkey.rsa->n);
	else if (pkey->type == EVP_PKEY_DSA)
		BN_print(out,pkey->pkey.dsa->pub_key);
	else
		BIO_printf(out,"");
	if (pkey != NULL) EVP_PKEY_free(pkey);
	n = BIO_get_mem_data(out, &modulus);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, modulus, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
exponent (csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	BIO *out;
	EVP_PKEY *pkey;
	char *exponent;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	pkey=X509_REQ_get_pubkey(csr);
	if (pkey == NULL)
		BIO_printf(out,"");
	else if (pkey->type == EVP_PKEY_RSA)
		BN_print(out,pkey->pkey.rsa->e);
	else if (pkey->type == EVP_PKEY_DSA)
		BN_print(out,pkey->pkey.dsa->pub_key);
	else
		BIO_printf(out,"");
	if (pkey != NULL) EVP_PKEY_free(pkey);
	n = BIO_get_mem_data(out, &exponent);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, exponent, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
extensions(csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	BIO *out;
	char *ext;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	// there is a bug in X509V3_extensions_print
	// the causes the function to fail if title == NULL and indent == 0
	X509V3_extensions_print(out, NULL, X509_REQ_get_extensions(csr), 0, 4);
	n = BIO_get_mem_data(out, &ext);
	SAFEFREE(char_ptr);
	if (n)
	{
		Newz(0, char_ptr, n+1, char);
		memcpy (char_ptr, ext, n);
	}
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
attributes(csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	BIO *out;
	char *ext;
	STACK_OF(X509_ATTRIBUTE) *sk;
	int n,i;
    CODE:
	out = BIO_new(BIO_s_mem());
	sk=csr->req_info->attributes;
	for (i=0; i<sk_X509_ATTRIBUTE_num(sk); i++)
	{
		ASN1_TYPE *at;
		X509_ATTRIBUTE *a;
		ASN1_BIT_STRING *bs=NULL;
		ASN1_TYPE *t;
		int j,type=0,count=1,ii=0;
	
		a=sk_X509_ATTRIBUTE_value(sk,i);
		if(X509_REQ_extension_nid(OBJ_obj2nid(a->object)))
			continue;
		if ((j=i2a_ASN1_OBJECT(out,a->object)) > 0)
		{
			if (a->single)
			{
				t=a->value.single;
				type=t->type;
				bs=t->value.bit_string;
			}
			else
			{
				ii=0;
				count=sk_ASN1_TYPE_num(a->value.set);
get_next:
				at=sk_ASN1_TYPE_value(a->value.set,ii);
				type=at->type;
				bs=at->value.asn1_string;
			}
		}
		for (j=25-j; j>0; j--)
			BIO_write(out," ",1);
		BIO_puts(out,":");
		if (    (type == V_ASN1_PRINTABLESTRING) ||
			(type == V_ASN1_T61STRING) ||
			(type == V_ASN1_IA5STRING))
		{
			BIO_write(out,(char *)bs->data,bs->length);
			BIO_puts(out,"\n");
		}
		else
			BIO_puts(out,"unable to print attribute\n");
		if (++ii < count) goto get_next;
	}
	n = BIO_get_mem_data(out, &ext);
	SAFEFREE(char_ptr);
	if (n)
	{
		Newz(0, char_ptr, n+1, char);
		memcpy (char_ptr, ext, n);
	}
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
signature_algorithm(csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	BIO *out;
	char *sig;
	int n;
    CODE:
	out = BIO_new(BIO_s_mem());
	i2a_ASN1_OBJECT(out, csr->sig_alg->algorithm);
	n = BIO_get_mem_data(out, &sig);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, sig, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL

char *
signature(csr)
	OpenXPKI_Crypto_Backend_OpenSSL_PKCS10 csr
    PREINIT:
	BIO *out;
	char *sig;
	int n,i;
	unsigned char *s;
    CODE:
	out = BIO_new(BIO_s_mem());
	n=csr->signature->length;
	s=csr->signature->data;
	for (i=0; i<n; i++)
	{
		if ( ((i%18) == 0) && (i!=0) ) BIO_printf(out,"\n");
		BIO_printf(out,"%02x%s",s[i], (((i+1)%18) == 0)?"":":");
	}
	n = BIO_get_mem_data(out, &sig);
	SAFEFREE(char_ptr);
	Newz(0, char_ptr, n+1, char);
        memcpy (char_ptr, sig, n);
	RETVAL = char_ptr;
	BIO_free(out);
    OUTPUT:
	RETVAL
