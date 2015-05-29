MODULE = OpenXPKI		PACKAGE = OpenXPKI::Crypto::Backend::OpenSSL::ECDH

=pod
/*Generate a new EC Keypair by openSSL nid
 *  
 *	
 *
 */
=cut
SV * __new_ec_keypair( group_nid )
	SV* group_nid 	
CODE:
    EC_KEY *ec_key;
    BIO 	*out = NULL;
    long r=0, len=0;
    unsigned char * outkey= NULL;
    SV *key = NULL;

    //get new EC curve by ID 
    ec_key = EC_KEY_new_by_curve_name(SvIV(group_nid));

    if(!EC_KEY_generate_key(ec_key))
    {
        //if there was an error generating the key free the key memory
        EC_KEY_free(ec_key);
	croak("EC key generation failed");
    }
	
    //Set flag to use Key encoding using NID instead of an explicit EC curve 
    EC_KEY_set_asn1_flag(ec_key,OPENSSL_EC_NAMED_CURVE);
	
    out = BIO_new(BIO_s_mem());
    r = PEM_write_bio_ECPrivateKey(out, ec_key, NULL, NULL, 0, NULL, NULL);
    BIO_flush(out);
    len = BIO_get_mem_data(out, NULL);

    outkey = (unsigned char * )malloc(len+1);
    len = BIO_read(out, outkey,len);
    outkey[len]='\0';

    key = newSVpvn(outkey ,len);

    /* Clean up allocated memory */
    BIO_free(out);
    EC_KEY_free(ec_key);
    //free(outkey);

    RETVAL = key;
OUTPUT:
	RETVAL

=pod
/*
 * extract the EC pub key from an ASN.1 encoded EC keypair
 * the key string needs to be terminated by a '\0'
 *
 */
=cut
SV * __get_ec_pub_key( in )
SV *in
CODE:
    EC_KEY *ec_key;
    BIO 	*in_eckey = NULL , *out_ec_pub_key;
    long r=0, len=0;
    char *outkey;
    SV *key = NULL;

    in_eckey = BIO_new(BIO_s_mem());
    len = BIO_puts(in_eckey, SvPV(in, PL_na) );
    //printf("\n BIP_puts written: %d ", len);
    
    ec_key = PEM_read_bio_ECPrivateKey(in_eckey, NULL,NULL,NULL);  
    
    out_ec_pub_key =BIO_new(BIO_s_mem());

    r = PEM_write_bio_EC_PUBKEY(out_ec_pub_key ,ec_key);
    len = BIO_get_mem_data(out_ec_pub_key,NULL);
    outkey = (unsigned char* ) malloc (len+1);
    r = BIO_read(out_ec_pub_key, outkey,len);
    outkey[len]= '\0';
    key = newSVpvn(outkey ,len);

    /* Clean up allocated memory */
    EC_KEY_free(ec_key);
    BIO_free(in_eckey);
    BIO_free(out_ec_pub_key);
    free(outkey);
 
	RETVAL = key;
OUTPUT:
	RETVAL
=pod
/*
 * generate Session key, based on a pub key already supplied
 * generate a new keypair and return a new private and public key 
 *
 */
=cut

SV * __get_ecdh_key( in_pub_ec_key, out_ec_key, out_ec_pub_key )
SV *in_pub_ec_key
SV *out_ec_key
SV *out_ec_pub_key 
CODE:
    int keySize=200 , i=0;
    BIO  *out = NULL , *out_pub= NULL, *in_pub=NULL ,*tmp =NULL ;
    long r=0, len=0;
    unsigned char outkey[keySize] ;
    unsigned char *outbuf=NULL;
    EC_GROUP *group = NULL;
    EC_KEY 	*ec_pubkey = NULL , * eckey = NULL , *testkey =NULL ;
    char *c_ec_pub_key =NULL;
    char *c_ec_key =NULL;
    unsigned char * sessionkey=NULL;
    SV *key = NULL;

    //read supplied public key   
    in_pub = BIO_new(BIO_s_mem());
    r =  BIO_puts(in_pub, SvPV(in_pub_ec_key, PL_na));
    ec_pubkey = PEM_read_bio_EC_PUBKEY(in_pub, NULL,NULL,NULL);

    if(ec_pubkey == NULL)
    {
	if (ec_pubkey) EC_KEY_free(ec_pubkey);
        croak("missing or invalid public key");

    }
    
    group = EC_KEY_get0_group(ec_pubkey);
    if(group == NULL)
    {
        if (ec_pubkey) EC_KEY_free(ec_pubkey);
        croak("failed to get key group from supplied public key");
    }    

    tmp = BIO_new(BIO_s_mem());
    len = BIO_puts(tmp,  SvPV(out_ec_key, PL_na));

     //if there is no keypair supplied via out_ec_key, create a new keypair 
     if(len <= 0)
     {
	//generate new key 
	eckey = EC_KEY_new();
	//Set same group as used in the supplied public key
	if(! EC_KEY_set_group(eckey, group)){
		croak("can't set group from supplied public key");
	}

	if(!EC_KEY_generate_key(eckey))
	{
	    //if there was an error generating the key free the key memory
	    if (eckey) EC_KEY_free(eckey);
            if (ec_pubkey) EC_KEY_free(ec_pubkey);
	    if (out) BIO_free(out);
	    if (out_pub) BIO_free(out_pub);
	    if (tmp) BIO_free(tmp);

            croak("error key generation failed");
	}

      }else{
	eckey = PEM_read_bio_ECPrivateKey(tmp, NULL,NULL,NULL);

	    if(eckey == NULL)
	    {
		if (eckey) EC_KEY_free(eckey);
                if (ec_pubkey) EC_KEY_free(ec_pubkey);
	        if (out) BIO_free(out);
	        if (out_pub) BIO_free(out_pub);
	        if (tmp) BIO_free(tmp);

		croak("missing private key");
	    }
      }

     	out = BIO_new(BIO_s_mem());
     	r = PEM_write_bio_ECPrivateKey(out, eckey, NULL, NULL, 0, NULL, NULL); 	
     	len = BIO_get_mem_data(out, NULL );

     	c_ec_key = (char *) malloc (len+1);
     	r = BIO_read(out, c_ec_key,len);
     	(c_ec_key)[len]= '\0';

        sv_setpvn(out_ec_key,c_ec_key,len);

	out_pub=BIO_new(BIO_s_mem());
	r = PEM_write_bio_EC_PUBKEY(out_pub, eckey,NULL,NULL, 0,NULL, NULL);
	len = BIO_get_mem_data(out_pub,NULL);
	c_ec_pub_key = (char *) malloc (len+1);
	r = BIO_read(out_pub, c_ec_pub_key, len);
	(c_ec_pub_key)[len]= '\0';
	sv_setpvn(out_ec_pub_key,c_ec_pub_key,len);
	
	int n = ECDH_compute_key(outkey, keySize, EC_KEY_get0_public_key(ec_pubkey), eckey, NULL );
	//printf("n = %d \n", n);
	outkey[n]='\0';

	key = newSVpvn(outkey ,n);
	
	//	if (outkey) free(outkey);
		if (c_ec_key) free(c_ec_key);
		if (c_ec_pub_key) free(c_ec_pub_key);
		if (eckey) EC_KEY_free(eckey);
		if (ec_pubkey) EC_KEY_free(ec_pubkey);
		if (out) BIO_free(out);
		if (out_pub) BIO_free(out_pub);
		if (tmp) BIO_free(tmp);

	RETVAL = key;
OUTPUT:
	RETVAL