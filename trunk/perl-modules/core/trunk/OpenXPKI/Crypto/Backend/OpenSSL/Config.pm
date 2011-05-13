## OpenXPKI::Crypto::Backend::OpenSSL::Config
## Written 2005 and 2006 by Julia Dubenskaya and Michael Bell for the OpenXPKI project
## Improved 2011 by Martin Bartosch for the OpenXPKI project
## (C) Copyright 2005-2011 by The OpenXPKI Project
	
use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Config;

use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
##! 0: "FIXME: why do we have no delete_tmpfile operation?"
##! 0: "FIXME: a missing delete_tmpfile is a security risk"
use OpenXPKI qw(write_file get_safe_tmpfile);
use OpenXPKI::DN;
use OpenXPKI::DateTime;
use English;

use Data::Dumper;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = shift;
    bless $self, $class;

    ##! 2: "check XS availability"
    if (not exists $self->{XS} or not ref $self->{XS})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CONFIG_MISSING_XS");
    }

    ##! 2: "$self->{TMP} will be checked by the central OpenSSL module"
    if (not $self->{TMP})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CONFIG_TEMPORARY_DIRECTORY_UNAVAILABLE");
    }


    return $self;
}

############################
##     Public setters     ##
############################

sub set_engine
{
    my $self = shift;
    $self->{ENGINE} = shift;
    return 1;
}

sub set_profile
{
    my $self = shift;
    $self->{PROFILE} = shift;
    return 1;
}

sub set_cert_list
{
    ##! 1: "start"
    my $self = shift;
    my $list = shift;
    $self->{INDEX_TXT} = "";

    foreach my $arrayref (@{$list})
    {
        ##! 4: "handle next certficate"

        # default revocation date if none is specified is epoch 0,
        # i.e. 01/01/1970 00:00:00
        my ($cert, $timestamp) = (undef, '700101000000Z');

	# Set dummy values for index.txt. These values are not used during
	# CRL generation.
	my $subject = '/DC=org/DC=openxpki/CN=Dummy';
	my $start = '700101000000Z';
	my $serial;

        if (ref($arrayref) ne 'ARRAY')
        {
            $cert      = $arrayref;
        } else {
            $cert      = $arrayref->[0];
	}

        if (ref($cert) eq '')
        {
	    # scalar string, it may either be a PEM encoded cert or the
	    # raw certificate serial number (decimal)
	    
	    if ($cert =~ m{ \A \d+ \z }xms) {
		# passed argument is numeric only and hence is the serial
		# number of the certificate to revoke
		$serial = $cert;
		$cert = '';
	    } else {
		# PEM encoded certificate, instantiate object
		eval {
		    ##! 1: "FIXME: where is the related free_object call?"
		    ##! 1: "FIXME: this is a memory leak"
		    $cert = $self->{XS}->get_object({DATA => $cert, TYPE => "X509"});
		};
		if (my $exc = OpenXPKI::Exception->caught())
		{
		    OpenXPKI::Exception->throw (
			message  => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_REVOKED_CERT_FAILED",
			children => [ $exc ]);
		} elsif ($EVAL_ERROR) {
		    $EVAL_ERROR->rethrow();
		}
	    }
        }

	if (ref($cert)) {
	    # cert is available as an object, obtain necessary data from it

            # $timestamp = [ gmtime ($timestamp) ];
            # $timestamp = POSIX::strftime ("%y%m%d%H%M%S",@{$timestamp})."Z";
	    ##! 4: "timestamp = $timestamp"

	    ##! 4: "create start time - notbefore"
	    $start = $self->{XS}->get_object_function ({
		OBJECT   => $cert,
		FUNCTION => "notbefore"});
	    $start = OpenXPKI::DateTime::convert_date(
		{
		    DATE      => $start,
		    OUTFORMAT => 'openssltime',
		});
	    ##! 4: "OpenSSL notbefore date: $start"

	    ##! 4: "create OpenSSL subject"
	    $subject = $self->{XS}->get_object_function ({
		OBJECT   => $cert,
		FUNCTION => "subject"});
	    $subject = OpenXPKI::DN->new ($subject);
	    $subject = $subject->get_openssl_dn ();

	    ##! 4: "create serials"
	    $serial = $self->{XS}->get_object_function ({
		OBJECT   => $cert,
		FUNCTION => "serial"});
	}
	

	if (ref($arrayref) eq 'ARRAY') {
            if (scalar @{$arrayref} > 1) {
                $timestamp = $arrayref->[1];
                ##! 4: "create timestamp"
                $timestamp = DateTime->from_epoch(epoch => $timestamp);
                $timestamp = OpenXPKI::DateTime::convert_date({
                    DATE      => $timestamp,
                    OUTFORMAT => 'openssltime',
                });
                ##! 16: 'revocation date is present: ' . $timestamp
            }
            if (scalar @{$arrayref} > 2) {
		my $reason_code = $arrayref->[2];
		
		if ($reason_code !~ m{ \A (?: unspecified | keyCompromise | CACompromise | affiliationChanged | superseded | cessationOfOperation | certificateHold | removeFromCRL ) \z }xms) {
		    CTX('log')->log(
			MESSAGE => "Invalid reason code '" . $reason_code . "' specified",
			PRIORITY => 'warn',
			FACILITY => [ 'system' ],
			);
		    $reason_code = 'unspecified';
		}
                # append reasonCode
                $timestamp .= ',' . $arrayref->[2];
                ##! 16: 'reason code is present: ' . $timestamp
            }
            if (scalar @{$arrayref} > 3) {
                # append invalidity date / Hold instruction OID
                # FIXME - implement code that treats hold instruction
                # correctly
                my $invalidity_date = $arrayref->[3];
                $invalidity_date = DateTime->from_epoch(epoch => $invalidity_date);
                $invalidity_date = OpenXPKI::DateTime::convert_date({
                    DATE      => $invalidity_date,
                    OUTFORMAT => 'openssltime',
                });
                $timestamp .= ',' . $invalidity_date;
                ##! 16: 'invalidity date is present: ' . $timestamp
            }
        }


        $serial = Math::BigInt->new ($serial);
        my $hex = substr ($serial->as_hex(), 2);
        $hex    = "0".$hex if (length ($hex) % 2);

        ##! 4: "prepare index.txt entry"
        my $entry = "R\t$start\t$timestamp\t$hex\tunknown\t$subject\n";
        ##! 4: "LINE: $entry"
        $self->{INDEX_TXT} .= $entry;
    }
    ##! 1: "end"
    return 1;
}

################################
##     Dump configuration     ##
################################

sub dump
{
    ##! 1: "start"
    my $self = shift;
    my $config = "";

    ##! 2: "cleanup to make sure that we get a fresh config"
    $self->__cleanup_files();

    ##! 2: "dump common part"

    $config = "## OpenSSL configuration\n".
              "## dynamically generated by OpenXPKI::Crypto::Backend::OpenSSL::Config\n".
              "\n".
              "openssl_conf = openssl_init\n".
              "default_ca   = ca\n";

    $config .= $self->__get_openssl_common();
    $config .= $self->__get_oids();
    $config .= $self->__get_engine();
    if (exists $self->{PROFILE})
    {
        ##! 4: "write serial file (for CRL and certs)"

        my $serial = $self->{PROFILE}->get_serial();
        if (defined $serial)
        {
            ##! 8: "get tempfilename for serial"
            $self->{FILENAME}->{SERIAL}     = $self->get_safe_tmpfile ({TMP => $self->{TMP}});
            ##! 8: "defined old filename for serial to make later a correct cleanup"
            $self->{FILENAME}->{SERIAL_OLD} = $self->{FILENAME}->{SERIAL}.".old";
            ##! 8: "serial present"
            $serial = Math::BigInt->new ($serial);
            if (not defined $serial)
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CONFIG_DUMP_WRONG_SERIAL");
            }
            ##! 8: "serial accepted by Math::BigInt"
            my $hex = substr ($serial->as_hex(), 2);
            $hex = "0".$hex if (length ($hex) % 2);
            ##! 8: "hex serial is $hex"
            $self->write_file (FILENAME => $self->{FILENAME}->{SERIAL},
                               CONTENT  => $hex);
            ##! 8: "specify a special filename to remove the new cert from the temp file area (see new_certs_dir)"
            $self->{FILENAME}->{NEW_CERT} = $self->{TMP}."/$hex.pem";
        }

        ##! 4: "write database files"

        ##! 4: "WARNING:FIXME: ATTR file of index.txt is not safe!"
        # ATTRFILE should be databasefile.attr
        # FIXME: we assume this file does not exist
        # FIXME: is this really safe? OpenSSL require it
        $self->{FILENAME}->{DATABASE} = $self->get_safe_tmpfile ({TMP => $self->{TMP}});
        $self->{FILENAME}->{ATTR} = $self->{FILENAME}->{DATABASE}.".attr";
        if (exists $self->{INDEX_TXT})
        {
            ##! 8: "INDEX_TXT present => this is a CRL"
            $self->write_file (FILENAME => $self->{FILENAME}->{DATABASE},
                               CONTENT  => $self->{INDEX_TXT});
        }
        else
        {
            ##! 8: "no INDEX_TXT => this is a certificate"
            $self->write_file (FILENAME => $self->{FILENAME}->{DATABASE},
                               CONTENT  => "");
        }
        $self->write_file (FILENAME => $self->{FILENAME}->{ATTR},
                           CONTENT  => "unique_subject = no\n");
        ##! 4: "create filenames for a better cleanup"
        $self->{FILENAME}->{DATABASE_OLD} = $self->{FILENAME}->{DATABASE}.".old";
        $self->{FILENAME}->{ATTR_OLD}     = $self->{FILENAME}->{ATTR}.".old";

        ##! 4: "PROFILE exists => CRL or cert generation"
        $config .= $self->__get_ca();
        $config .= $self->__get_extensions();
    
    }

    ##! 2: "write configuration file"

    $self->{FILENAME}->{CONFIG}   = $self->get_safe_tmpfile ({TMP => $self->{TMP}});
    $self->write_file (FILENAME => $self->{FILENAME}->{CONFIG},
                       CONTENT  => $config);

    ##! 16: 'config: ' . $config
    ##! 2: "set the configuration to the XS library"
    ##! 2: "should we integrate this into the get_config function?"
    OpenXPKI::Crypto::Backend::OpenSSL::set_config ($self->{FILENAME}->{CONFIG});

    ##! 1: "end"
    return 1;
}

sub __get_openssl_common
{
    ##! 4: "start"
    my $self = shift;
    my $config = "\n[ openssl_init ]\n\n";

    ##! 8: "add the engine and OID section references"

    $config .= "engines = engine_section\n".
               "oid_section = new_oids\n";

    ## utf8 support options
    ## please do not touch or OpenXPKI's utf8 support breaks
    ## utf8=yes                # needed for correct issue of cert. This is
    ##                         # interchangeable with -utf8 "subj" command line modifier.
    ## string_mask=utf8only    # needed for correct issue of cert
    ## will be ignored today by "openssl req"
    ## name_opt = RFC2253,-esc_msb

    $config .= "\n[ req ]\n\n".
               "utf8              = yes\n".
               "string_mask       = utf8only\n".
               "distinguished_name = dn_policy\n";

    $config .= "\n[ dn_policy ]\n\n".
               "# this is a dummy because of preserve\n".
               "domainComponent = optional\n";


   ##! 4: "end"
   return $config;
}

sub __get_oids
{
    ##! 4: "today this is an empty function"
    my $self = shift;
    return "\n[ new_oids ]\n";
}

sub __get_engine
{
    ##! 4: "start"
    my $self = shift;
    my $config = "\n[ engine_section ]\n";

    $config .= "\n".
               $self->{ENGINE}->get_engine()." = engine_config\n".
               "\n".
               "[ engine_config ]\n".
               "\n".
               $self->{ENGINE}->get_engine_section();

    ##! 4: "end"
    return $config;
}

sub __get_ca
{
    ##! 4: "start"
    my $self = shift;

    my $config = "\n[ ca ]\n";

    $config .= "new_certs_dir     = ".$self->{TMP}."\n";
    $config .= "certificate       = ".$self->{ENGINE}->get_certfile()."\n";
    $config .= "private_key       = ".$self->{ENGINE}->get_keyfile."\n";

    if (my $notbefore = $self->{PROFILE}->get_notbefore()) {
	$config .= "default_startdate = " 
	    . OpenXPKI::DateTime::convert_date(
	    {
		OUTFORMAT => 'openssltime',
		DATE      => $notbefore,
	    })
	    . "\n";
    }
    
    if (my $notafter = $self->{PROFILE}->get_notafter()) {
	$config .= "default_enddate = " 
	    . OpenXPKI::DateTime::convert_date(
	    {
		OUTFORMAT => 'openssltime',
		DATE      => $notafter,
	    })
	    . "\n";
    }

    if (exists $self->{FILENAME}->{SERIAL})
    {
        $config .= "crlnumber         = ".$self->{FILENAME}->{SERIAL}."\n".
                   "serial            = ".$self->{FILENAME}->{SERIAL}."\n";
    }

    my $digest = $self->{PROFILE}->get_digest();
    if ($digest =~ /md5/) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_BACKEND_OPENSSL_CONFIG_MD5_DIGEST_BROKEN',
        );
    }
    $config .= "default_md        = ".$self->{PROFILE}->get_digest()."\n".
               "database          = ".$self->{FILENAME}->{DATABASE}."\n".
               "default_crl_days  = ".$self->{PROFILE}->get_nextupdate_in_days()."\n".
               "x509_extensions   = v3ca\n".
               "crl_extensions    = v3ca\n".
               "preserve          = YES\n".
               "policy            = dn_policy\n".
               "name_opt          = RFC2253,-esc_msb\n".
               "utf8              = yes\n".
               "string_mask       = utf8only\n".
               "\n";

    ##! 4: "end"
    return $config;
}

sub __get_extensions
{
    ##! 4: "start"
    my $self = shift;

    my $config   = "\n[ v3ca ]\n";
    my $profile  = $self->{PROFILE};
    my $sections = "";
    
   EXTENSIONS:
    foreach my $name (sort $profile->get_named_extensions())
    {
        ##! 64: 'name: ' . $name
        my $critical = "";
        $critical = "critical," if ($profile->is_critical_extension ($name));
	
        if ($name eq "authority_info_access")
        {
            $config .= "authorityInfoAccess = $critical";
            foreach my $pair (@{$profile->get_extension("authority_info_access")})
            {
                my $type;
                $type = "caIssuers" if ($pair->[0] eq "CA_ISSUERS");
                $type = "OCSP"       if ($pair->[0] eq "OCSP");
                foreach my $http (@{$pair->[1]})
                {
                    # substitute commas and semicolons in the URI,
                    # as they will otherwise be misinterpreted by
                    # openssl as seperators
                    $http =~ s{,}{%2C}xmsg;
                    $http =~ s{;}{%3B}xmsg;
                    $config .= "$type;URI:$http,";
                }
            }
            $config = substr ($config, 0, length ($config)-1); ## remove trailing ,
            $config .= "\n";
        }
        elsif ($name eq "authority_key_identifier")
        {
            $config .= "authorityKeyIdentifier = $critical";
            foreach my $param (@{$profile->get_extension("authority_key_identifier")})
            {
                $config .= "issuer:always," if ($param eq "issuer");
                $config .= "keyid:always,"  if ($param eq "keyid");
            }
            $config = substr ($config, 0, length ($config)-1); ## remove trailing ,
            $config .= "\n";
        }
        elsif ($name eq "basic_constraints")
        {
            $config .= "basicConstraints = $critical";
            foreach my $pair (@{$profile->get_extension("basic_constraints")})
            {
                if ($pair->[0] eq "CA")
                {
                    if ($pair->[1] eq "true")
                    {
                        $config .= "CA:true,";
                    } else {
                        $config .= "CA:false,";
                    }
                }
                if ($pair->[0] eq "PATH_LENGTH")
                {
                    $config .= "pathlen:".$pair->[1].",";
                }
            }
            $config = substr ($config, 0, length ($config)-1); ## remove trailing ,
            $config .= "\n";
        }
        elsif ($name eq "cdp")
        {
            $config .= "crlDistributionPoints = $critical\@cdp\n";
            $sections .= "\n[ cdp ]\n";
            my $i = 0;
            foreach my $cdp (@{$profile->get_extension("cdp")})
            {
                $sections .= "URI.$i=$cdp\n";
                $i++;
            }
            $sections .= "\n";
        }
        elsif ($name eq 'user_notice') {
            # FIXME - currently, you can only have a user_notice
            # together with a policy_identifier
            next EXTENSIONS;
        }
        elsif ($name eq 'policy_identifier') {
            $config .= "certificatePolicies = $critical\@cert_policies\n";
            $sections .= "\n[ cert_policies ]\n";
            my $i = 0;
            my @oids = @{ $profile->get_extension('policy_identifier')->[0] };
            ##! 16: '@oids: ' . Dumper \@oids
            if (scalar @oids) {
                $sections .= "policyIdentifier = " . $oids[0];
                $sections .= "\n";
            }
            my @user_notices;
            my $old_eval_error = $EVAL_ERROR;
            eval {
                # a user_notice might not be present, just leave the
                # array empty then
                #OpenXPKI::Exception->throw(
                #    message => 'I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_GET_EXTENSION_NOT_FOUND',
                #);
                @user_notices = @{$profile->get_extension('user_notice')};
            };
            my $exc = OpenXPKI::Exception->caught();
            if (defined $exc && $exc->message() eq 'I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_GET_EXTENSION_NOT_FOUND') {
                $EVAL_ERROR = $old_eval_error;
            }
            foreach my $notice (@user_notices) {
                $sections .= qq{userNotice.$i = \@notice$i\n};
                $i++;
            }
            $sections .= "\n";
            $i = 0;
            foreach my $notice (@user_notices) {
                $sections .= "\n[ notice$i ]\n";
                $sections .= qq{explicitText = "$notice"\n\n};
                $i++;
            }
            $sections .= "\n";
        }
        elsif ($name eq "extended_key_usage")
        {
            $config .= "extendedKeyUsage = $critical";
            my @bits = @{$profile->get_extension("extended_key_usage")};
            $config .= "clientAuth,"      if (grep /client_auth/,      @bits);
            $config .= "emailProtection," if (grep /email_protection/, @bits);
            my @oids = grep m{\.}, @bits;
            foreach my $oid (@oids)
            {
                $config .= "$oid,";
            }
            $config = substr ($config, 0, length ($config)-1); ## remove trailing ,
            $config .= "\n";
        }
        elsif ($name eq "issuer_alt_name")
        {
            $config .= "issuerAltName = $critical";
            my $issuer = join (",", @{$profile->get_extension("issuer_alt_name")});
            $config .= "issuer:copy" if ($issuer eq "copy");
            # FIXME: issuer:copy apparently does not work!
            $config .= "\n";
        }
        elsif ($name eq "key_usage")
        {
            my @bits = @{$profile->get_extension("key_usage")};
            if (scalar @bits > 0) {
                # only add keyUsage to config if configuration entries are present
                $config .= "keyUsage = $critical";
                $config .= "digitalSignature," if (grep /digital_signature/, @bits);
            $config .= "nonRepudiation,"   if (grep /non_repudiation/,   @bits);
            $config .= "keyEncipherment,"  if (grep /key_encipherment/,  @bits);
                $config .= "dataEncipherment," if (grep /data_encipherment/, @bits);
                $config .= "keyAgreement,"     if (grep /key_agreement/,     @bits);
                $config .= "keyCertSign,"      if (grep /key_cert_sign/,     @bits);
                $config .= "cRLSign,"          if (grep /crl_sign/,          @bits);
                $config .= "encipherOnly,"     if (grep /encipher_only/,     @bits);
                $config .= "decipherOnly,"     if (grep /decipher_only/,     @bits);
                $config = substr ($config, 0, length ($config)-1); ## remove trailing ,
                $config .= "\n";
            }
        }
        elsif ($name eq "subject_alt_name")
        {
            my $subj_alt_name = $profile->get_extension("subject_alt_name");
            my @tmp_array;
            foreach my $entry (@{$subj_alt_name}) {
                push @tmp_array, join(q{:}, @{$entry});
            }
            my $string = join(q{,}, @tmp_array);
            
            if ($string ne '') {
                $config .= "subjectAltName=" . $string . "\n";
            }
        }
        elsif ($name eq "subject_key_identifier")
        {
            $config .= "subjectKeyIdentifier = $critical";
            my @bits = @{$profile->get_extension("subject_key_identifier")};
            $config .= "hash" if (grep /hash/, @bits);
            $config .= "\n";
        }
        elsif ($name eq "netscape/ca_cdp")
        {
            $config .= "nsCaRevocationUrl = $critical".
                       join ("", @{$profile->get_extension("netscape/ca_cdp")})."\n";
        }
        elsif ($name eq "netscape/cdp")
        {
            $config .= "nsRevocationUrl = $critical".
                       join ("", @{$profile->get_extension("netscape/cdp")})."\n";
        }
        elsif ($name eq "netscape/certificate_type")
        {
            $config .= "nsCertType = $critical";
            my @bits = @{$profile->get_extension("netscape/certificate_type")};
            $config .= "client,"  if (grep /ssl_client/, @bits);
            $config .= "objsign," if (grep /object_signing/, @bits);
            $config .= "email,"   if (grep /smime_client/, @bits);
            $config .= "sslCA,"   if (grep /ssl_client_ca/, @bits);
            $config .= "objCA,"   if (grep /object_signing_ca/, @bits);
            $config .= "emailCA," if (grep /smime_client_ca/, @bits);
            $config = substr ($config, 0, length ($config)-1); ## remove trailing ,
            $config .= "\n";
        }
        elsif ($name eq "netscape/comment")
        {
            $config .= "nsComment = $critical\"";
            my $string =  join ("", @{$profile->get_extension("netscape/comment")});
	    # FIXME: this inserts a literal \n - is this intended?
	    $string =~ s/\n/\\\\n/g;
            $config .= "$string\"\n";
        }
        else
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_WRITE_CONFIG_UNKNOWN_NAMED_EXTENSION",
                params  => {NAME => $name});
        }
    }
    $config .= "\n".$sections;
    ##! 16: "extensions ::= $config"

    ##! 4: "end"
    return $config;
}

sub get_config_filename
{
    my $self = shift;
    return $self->{FILENAME}->{CONFIG};
}

#####################
##     cleanup     ##
#####################

sub cleanup
{
    ##! 1: "start"
    my $self = shift;

    ##! 2: "delete profile"
    delete $self->{PROFILE} if (exists $self->{PROFILE});

    ##! 2: "delete index.txt database"
    delete $self->{INDEX_TXT} if (exists $self->{INDEX_TXT});

    ##! 2: "cleanup files"
    $self->__cleanup_files();

    ##! 1: "end"
    return 1;
}

sub __cleanup_files
{
    ##! 1: "start"
    my $self = shift;

    ##! 2: "return if no files must be deleted"
    return 1 if (not exists $self->{FILENAME} or
                 not scalar keys %{$self->{FILENAME}});

    ##! 2: "delete all temp files"
    foreach my $filename (sort keys %{$self->{FILENAME}})
    {
        ##! 4: "filename: $filename"
        unlink($self->{FILENAME}->{$filename});
    }
    delete $self->{FILENAME};

    ##! 1: "end"
    return 1;
}

sub DESTROY
{
    my $self = shift;
    $self->__cleanup_files();
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Config

=head1 Description

This module was designed to create an OpenSSL configuration on the fly for
the various operations of OpenXPKI. The module support the following
different section types:

=over

=item - general OpenSSL configuration

=item - engine configuration

=item - new OIDs

=item - CA configuration

=item - CRL extension configuration

=item - certificate extension configuration

=item - CRL distribution points

=item - subject alternative names

=back

=head1 Functions

=over

=item - new

=item - set_engine

=item - set_profile

=item - set_cert_list

This method prepares the OpenSSL-specific representation of the certificate
database (index.txt). The method expects an arrayref containing a list
of all certificates to revoke.

A single entry in this array may be one of the following:

=over

=item * a single certificate (see below on how to specify a certificate)

=item * an arrayref of the format [ certificate, revocation_timestamp, reason_code, invalidity_timestamp ]

=back

With the exception of the certificate all additional parameters 
are optional and can be left out.

If a revocation_timestamp is specified, it is used as the revocation
timestamp in the generated CRL.
The timestamp is specified in seconds since epoch.

The reason code is accepted literally. It should be one of
  'unspecified',
  'keyCompromise',
  'CACompromise',
  'affiliationChanged',
  'superseded',
  'cessationOfOperation',

The reason codes
  'certificateHold',
  'removeFromCRL'.
are currently not handled correctly and should be avoided. However, they
will currently simply be passed in the CRL which may not have the desired 
result.

If the reason code is incorrect, a warning is logged and the reason code
is set to 'unspecified' in order to make sure the certificate gets revoked
at all.

If a invalidity_timestamp is specified, it is used as the invalidity
timestamp in the generated CRL.
The timestamp is specified in seconds since epoch.

A certificate can be specified as

=over

=item * a PEM encoded X.509v3 certificate (scalar)

=item * a reference to an OpenXPKI::Crypto::Backend::OpenSSL::X509 object

=item * a string containing the serial number of the certificate to revoke

=back

Depending on the way the certificate to revoke was specified the method
has to perform several actions to deduce the correct information for CRL
issuance.
If a PEM encoded certificate is passed, the method is forced to parse
to parse the certificate before it can build the revocation data list.
This operation introduces a huge overhead which may influence system
behaviour if many certificates are to be revoked.
The lowest possible overhead is introduced by the literal specification
of the serial number to put on the revocation list.

NOTE: No attempt to verify the validity of the specified serial numbers 
is done, in particular in the "raw serial number" case there is even 
no check if such a serial number exists at all.

=item - dump

=item - get_config_filename

=back

=head1 Example

my $profile = OpenXPKI::Crypto::Backend::OpenSSL::Config->new (
              {
                  TMP    => '/tmp',
              });
$profile->set_engine($engine);
$profile->set_profile($crl_profile);
$profile->dump();
my $conf = $profile->get_config_filename();
... execute an OpenSSL command with "-config $conf" ...
... or execute an OpenSSL command with "OPENSSL_CONF=$conf openssl" ...

=head1 See Also

OpenXPKI::Crypto::Profile::Base, OpenXPKI::Crypto::Profile::CRL,
OpenXPKI::Crypto::Profile::Certificate and OpenXPKI::Crypto::Backend::OpenSSL
