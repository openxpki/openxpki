## OpenXPKI::Crypto::X509
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2003-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::X509;

use OpenXPKI::Debug;
use OpenXPKI::DN;
use Math::BigInt;
use Digest::SHA1 qw(sha1_base64);
use OpenXPKI::DateTime;

use base qw(OpenXPKI::Crypto::Object);
use English;

# use Smart::Comments;

sub new
{
    my $self = shift;
    my $class = ref($self) || $self;
    $self = {};
    bless $self, $class;

    my $keys = { @_ };
    $self->{DATA}  = $keys->{DATA};
    $self->{TOKEN} = $keys->{TOKEN};

    if (not $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_X509_NEW_MISSING_DATA");
    }
    if (not $self->{TOKEN})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_X509_NEW_MISSING_TOKEN");
    }

    $self->__init();

    return $self;
}

sub __init
{
    my $self = shift;
    ##! 1: "start"

    ##########################
    ##     init objects     ##
    ##########################

    $self->{header} = OpenXPKI::Crypto::Header->new (DATA  => $self->{DATA});
    eval
    {
        $self->{x509} = $self->{TOKEN}->get_object({DATA  => $self->{header}->get_body(),
                                                    TYPE  => "X509"});
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_CRYPTO_X509_INIT_OBJECT_FAILED",
            children => [ $exc ]);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    }

    ###############################################
    ##  compute SHA1 hash of DER representation  ##
    ###############################################
    
    my $cert_der = $self->{TOKEN}->command({
                        COMMAND => 'convert_cert',
                        DATA    => $self->get_body(),
                        OUT     => 'DER',
    });
    $self->{SHA1} = sha1_base64($cert_der);
    ## RFC 3548 URL and filename safe base64
    $self->{SHA1} =~ tr/+\//-_/;
    
    ##########################
    ##     core parsing     ##
    ##########################

    $self->{PARSED}->{HEADER} = $self->{header}->get_parsed();
    foreach my $attr ( "serial", "subject", "issuer", "notbefore", "notafter",
                       "alias", "modulus", "pubkey", "fingerprint", "emailaddress",
                       "version", "pubkey_algorithm", "signature_algorithm", "exponent",
                       "keysize", "extensions", "openssl_subject" )
    {
        $self->{PARSED}->{BODY}->{uc($attr)} 
	= $self->{TOKEN}->get_object_function (
	    {
		OBJECT   => $self->{x509},
		FUNCTION => $attr,
	    });
        if ($attr eq 'serial') {
            # add serial in hex as well so clients do not have to convert
            # it themselves
            my $serial = Math::BigInt->new($self->{PARSED}->{BODY}->{SERIAL});
            $self->{PARSED}->{BODY}->{SERIAL_HEX} = $serial->as_hex();
            $self->{PARSED}->{BODY}->{SERIAL_HEX} =~ s{\A 0x}{}xms;
        }
    }
    $self->{TOKEN}->free_object ($self->{x509});
    delete $self->{x509};
    ##! 2: "loaded cert attributes"
    my $ret = $self->{PARSED}->{BODY};

    ### parsed body: $ret

    ###########################
    ##     parse subject     ##
    ###########################

    ## load the differnt parts of the DN into SUBJECT_HASH
    my $obj = OpenXPKI::DN->new ($ret->{SUBJECT});
    %{$ret->{SUBJECT_HASH}} = $obj->get_hashed_content();

    ## FIXME: the following comment and code are wrong
    ## FIXME: the second equal sign has not to be escaped because
    ## FIXME: because it is no special character
    ## FIXME: if there is a problem with a DN parser then this
    ## FIXME: parser has a bug
    #	## OpenSSL includes a bug in -nameopt RFC2253
    #	## = signs are not escaped if they are normal values
    #	my $i = 0;
    #	my $now = "name";
    #	while ($i < length ($ret->{DN}))
    #	{
    #		if (substr ($ret->{DN}, $i, 1) =~ /\\/)
    #		{
    #			$i++;
    #		} elsif (substr ($ret->{DN}, $i, 1) =~ /=/) {
    #			if ($now =~ /value/)
    #			{
    #				## OpenSSL forgets to escape =
    #				$ret->{DN} = substr ($ret->{DN}, 0, $i)."\\".substr ($ret->{DN}, $i);
    #				$i++;
    #			} else {
    #				$now = "value";
    #			}
    #		} elsif (substr ($ret->{DN}, $i, 1) =~ /[,+]/) {
    #			$now = "name";
    #		}
    #		$i++;
    #	}

    ##################################
    ##     parse emailaddresses     ##
    ##################################

    if ($ret->{EMAILADDRESS})
    {
        if (index ($ret->{EMAILADDRESS}, "\n") < 0 )
        {
            $ret->{EMAILADDRESSES}->[0] = $ret->{EMAILADDRESS};
        } else {
            my @harray = split /\n/, $ret->{EMAILADDRESS};
            $ret->{EMAILADDRESSES} = \@harray;
            $ret->{EMAILADDRESS}   = $ret->{EMAILADDRESSES}->[0];
        }
    }
    # OpenSSL's get_email has a bug so we must add rfc822Mailbox by ourselves
    if (not $ret->{EMAILADDRESS} and
        exists $ret->{SUBJECT_HASH}->{MAIL} and
        $ret->{SUBJECT_HASH}->{MAIL}[0])
    {
        $ret->{EMAILADDRESS}   = $ret->{SUBJECT_HASH}->{MAIL}[0];
        $ret->{EMAILADDRESSES} = \@{$ret->{SUBJECT_HASH}->{MAIL}};
    }

    ###############################
    ##     extension parsing     ##
    ###############################

    ## load all extensions
    $ret->{PLAIN_EXTENSIONS} = $ret->{EXTENSIONS};
    delete $ret->{EXTENSIONS};
    $ret->{OPENSSL_EXTENSIONS} = {};

    my ($val, $key);
    my @lines = split(/\n/, $ret->{PLAIN_EXTENSIONS});

    my $i = 0;
    while($i < @lines)
    {
        if ($lines[$i] =~ /^\s*([^:]+):\s*(?:critical|)\s*$/i)
        {
            $key = $1;
            $ret->{OPENSSL_EXTENSIONS}->{$key} = [];
            $i++;
            while(exists $lines[$i] and $lines[$i] !~ /^\s*[^:]+:\s*(?:critical|)\s*$/ && $i < @lines)
            {
                $val = $lines[$i];
                $val =~ s/^\s+//;
                $val =~ s/\s+$//;
                $i++;
                next if $val =~ /^$/;
		if ($key eq 'X509v3 Subject Alternative Name') {
		    # when OpenSSL encounters CSR IP Subject Alternative Names
		    # the parsed output contains "IP Address:d.d.d.d", however
		    # OpenSSL expects "IP:d.d.d.d" in a config file for
		    # certificate issuance if you intend to issue a certificate
		    # we hereby declare that "IP" is the canonical identifier
		    # for an IP Subject Alternative Name
		    $val =~ s{ \A IP\ Address: }{IP:}xms;
		}
                push(@{$ret->{OPENSSL_EXTENSIONS}->{$key}}, $val);
            }
        } else {
            ## FIXME: can this ever happen?
            $i++;
        }
    }

    ##! 2: "show all extensions and their values"
    while(($key, $val) = each(%{$ret->{OPENSSL_EXTENSIONS}}))
    {
        ##! 4: "found extension: $key"
        foreach(@{$val})
        {
            ##! 8: "with value(s): $_"
        }
    }

    ## signal CA certiticate
    my $h = $ret->{OPENSSL_EXTENSIONS}->{"X509v3 Basic Constraints"}[0];
    $h ||= "";
    $h =~ s/\s//g;
    if ($h =~ /CA:TRUE/i)
    {
        $ret->{IS_CA} = 1;
        $ret->{EXTENSIONS}->{BASIC_CONSTRAINTS}->{CA} = 1;
    } else {
        $ret->{IS_CA} = 0;
        $ret->{EXTENSIONS}->{BASIC_CONSTRAINTS}->{CA} = 0;
    }

    # add keyusage extensions as arrayref
    my $keyusage = $ret->{OPENSSL_EXTENSIONS}->{'X509v3 Key Usage'}->[0];
    my @keyusages = ();
    if ($keyusage) {
        @keyusages = split /, /, $keyusage;
    }
    $ret->{'EXTENSIONS'}->{'KEYUSAGE'} = \@keyusages;

    ## add extensions for chain tracking
    foreach my $item (@{$ret->{OPENSSL_EXTENSIONS}->{"X509v3 Authority Key Identifier"}})
    {
        next if (not defined $item or not length ($item));
        my ($value) = ($item =~ /^[^:]+:(.*)$/);
        $ret->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER}->{CA_KEYID} = $value
            if ($item =~ /^keyid:/);
        $ret->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER}->{CA_ISSUER_NAME} = $value
            if ($item =~ /^DirName:/);
            
        if ($item =~ /^serial:/)
        {
            $value =~ s/://g;
            $value = "0x$value";
            $value = Math::BigInt->new ($value);
            $value = $value->bstr();
            $ret->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER}->{CA_ISSUER_SERIAL} = $value;
        }
    }
    if ($ret->{OPENSSL_EXTENSIONS}->{"X509v3 Subject Key Identifier"}[0])
    {
        $ret->{EXTENSIONS}->{SUBJECT_KEY_IDENTIFIER} =
            $ret->{OPENSSL_EXTENSIONS}->{"X509v3 Subject Key Identifier"}[0];
        $ret->{EXTENSIONS}->{SUBJECT_KEY_IDENTIFIER} =~ s/^\s*//;
    }
    ## make them visible for the database interface
    foreach $key (keys %{$ret->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER}})
    {
        next if (not $key);
        $ret->{$key} = $ret->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER}->{$key};
    }
    $ret->{KEYID} = $ret->{EXTENSIONS}->{SUBJECT_KEY_IDENTIFIER}
        if (exists $ret->{EXTENSIONS}->{SUBJECT_KEY_IDENTIFIER});

    return 1;
}

sub get_converted
{
    my $self   = shift;
    my $format = shift;

    if (not $format)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_X509_GET_CONVERTED_MISSING_FORMAT");
    }
    if ($format ne "PEM" and $format ne "DER" and $format ne "TXT" and $format ne "PKCS7")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_X509_GET_CONVERTED_WRONG_FORMAT",
            params  => {"FORMAT" => $format});
    }

    if ($format eq 'PEM' ) {
        return $self->get_body();
    }
    else
    {
        my $result = eval {$self->{TOKEN}->command ({COMMAND => "convert_cert",
                                                     DATA    => $self->get_body(),
                                                     OUT     => $format})};
        if (my $exc = OpenXPKI::Exception->caught())
        {
            OpenXPKI::Exception->throw (
                message  => "I18N_OPENXPKI_CRYPTO_X509_GET_CONVERTED_CONVERSION_FAILED",
                children => [ $exc ]);
        } elsif ($EVAL_ERROR) {
            $EVAL_ERROR->rethrow();
        }
        return $result;
    }
}

sub get_identifier {
    my $self = shift;

    if (! exists $self->{SHA1}) {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_CRYPTO_X509_GET_IDENTIFIER_NOT_INITIALIZED',
        );
    }
    return $self->{SHA1};
}

sub get_status {
    my $self = shift;
    if (not exists $self->{STATUS}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_X509_GET_STATUS_NOT_INITIALIZED");
    }
    return $self->{STATUS};
}

sub set_status {
    my $self = shift;

    $self->{STATUS} = shift;
    return $self->get_status();
}

sub get_subject_key_id {
    my $self = shift;
    if (exists $self->{PARSED}->{BODY}->{EXTENSIONS}->{SUBJECT_KEY_IDENTIFIER}) {
        return $self->{PARSED}->{BODY}->{EXTENSIONS}->{SUBJECT_KEY_IDENTIFIER};
    }
    else {
        return undef;
    }
}

sub get_authority_key_id {
    my $self = shift;

    my $authkeyid
        = $self->{PARSED}->{BODY}->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER};
    if (exists $authkeyid->{CA_KEYID}) {
        return $authkeyid->{CA_KEYID};
    }
    elsif (exists $authkeyid->{CA_ISSUER_NAME}
        && exists $authkeyid->{CA_ISSUER_SERIAL}) {
        my $return_hashref;
        $return_hashref->{ISSUER_NAME}   = $authkeyid->{CA_ISSUER_NAME};
        $return_hashref->{ISSUER_SERIAL} = $authkeyid->{CA_ISSUER_SERIAL};
        return $return_hashref;
    }
    else {
        return undef;
    }
}

sub to_db_hash {
    my $self = shift;

    my %insert_hash;
    $insert_hash{CERTIFICATE_SERIAL} = $self->get_serial();
    $insert_hash{IDENTIFIER}         = $self->get_identifier();
    $insert_hash{DATA}               = $self->{DATA};
    $insert_hash{SUBJECT}            = $self->{PARSED}->{BODY}->{SUBJECT};
    $insert_hash{ISSUER_DN}          = $self->{PARSED}->{BODY}->{ISSUER};
    # combine email addresses
    if (exists $self->{PARSED}->{BODY}->{EMAILADDRESSES}) {
        $insert_hash{EMAIL} = '';
        foreach my $email (@{$self->{PARSED}->{BODY}->{EMAILADDRESSES}}) {
            $insert_hash{EMAIL} .= "," if ($insert_hash{EMAIL} ne '');
            $insert_hash{EMAIL} .= $email;
        }
    }
    $insert_hash{PUBKEY}             = $self->{PARSED}->{BODY}->{PUBKEY};
    # set subject key id and authority key id, if defined.
    if (defined $self->get_subject_key_id()) {
        $insert_hash{SUBJECT_KEY_IDENTIFIER} = $self->get_subject_key_id();
    }
    if (defined $self->get_authority_key_id() &&
            ref $self->get_authority_key_id() eq '') {
        # TODO: do we save if authority key id is hash, and if
        # yes, in which format?
        $insert_hash{AUTHORITY_KEY_IDENTIFIER}
            = $self->get_authority_key_id();
    }

    $insert_hash{NOTAFTER}           
        = OpenXPKI::DateTime::convert_date({
            DATE      => $self->{PARSED}->{BODY}->{NOTAFTER},
            OUTFORMAT => 'epoch',
    });
    $insert_hash{NOTBEFORE}
        = OpenXPKI::DateTime::convert_date({
            DATE      => $self->{PARSED}->{BODY}->{NOTBEFORE},
            OUTFORMAT => 'epoch',
    });
    return %insert_hash;
}
1;
__END__

=head1 Name

OpenXPKI::Crypto::X509

=head1 Description

This class is used for the handling of X.509v3 certificates. All
functions of OpenXPKI::Crypto::Object are supported. All functions
which differ from the base class OpenXPKI::Crypto::Object are
described below.

=head1 Functions

=head2 new

The constructor supports two options - TOKEN and DATA.
TOKEN must be a crypto token from the token manager. This
is necessary to extract some informations from the data. The
parameter DATA must contain a PEM encoded certificate. This is
the base of the object.

=head2 get_converted

expects only one value - the requested format of the certificate.
PEM, TXT, PKCS7 and DER are supported. TXT is a plain text representation
which can be directly displayed to the user.

=head2 get_identifier

returns the base64-encoded SHA1 hash of the DER representation of the
certificate, which is used as an identifier in the database

=head2 set_status

sets the certificate status, i.e. ISSUED, SUSPENDED, REVOKED

=head2 get_status

gets the certificate status

=head2 get_subject_key_id

gets the subject key identifier from the extension, if present.
If not, returns undef.

=head2 get_authority_key_id

gets the authority key identifier from the extension, if present.
Returns either the key identifier as a string or a hash reference
containing the ISSUER_NAME and ISSUER_SERIAL field, if the key identifier
is not present. If none of the above are available, returns undef.

=head2 to_db_hash

returns the certificate data in a format that can be inserted into the
database table 'CERTIFICATE'.
