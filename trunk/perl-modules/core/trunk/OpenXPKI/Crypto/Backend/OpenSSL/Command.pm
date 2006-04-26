## OpenXPKI::Crypto::Backend::OpenSSL::Command
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;
use utf8;

use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_random;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs10;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_cert;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs12;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_cert;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_crl;

use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_key;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkcs10;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_cert;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_crl;

use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_sign;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_encrypt;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_decrypt;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_verify;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain;

package OpenXPKI::Crypto::Backend::OpenSSL::Command;

use OpenXPKI::Debug 'OpenXPKI::Crypto::Backend::OpenSSL::Command';
use OpenXPKI qw(read_file write_file get_safe_tmpfile);
use OpenXPKI::DN;
use OpenXPKI::DateTime;
use Date::Parse;
use File::Temp;
use File::Spec;
use POSIX qw(strftime);
use OpenXPKI::Exception;
use English;

sub new
{
    ##! 1: "start"
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = { @_ };
    bless $self, $class;

    ##! 2: "check engine availability"
    if (not exists $self->{ENGINE} or not ref $self->{ENGINE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_MISSING_ENGINE");
    }

    ##! 2: "check XS availability"
    if (not exists $self->{XS} or not ref $self->{XS})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_MISSING_XS");
    }

    ##! 2: "$self->{TMP} will be checked by the central OpenSSL module"
    if (not $self->{TMP})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_TEMPORARY_DIRECTORY_UNAVAILABLE");
    }

    ##! 1: "end"
    return $self;
}

sub set_tmpfile
{
    my $self = shift;
    my $keys = { @_ };

    foreach my $key (keys %{$keys})
    {
	push @{$self->{CLEANUP}->{FILE}}, $keys->{$key};

        $self->{$key."FILE"} = $keys->{$key};
    }
    return 1;
}

sub get_tmpfile
{
    my $self = shift;

    if (scalar(@_) == 0) {
        my $filename = $self->get_safe_tmpfile ({TMP => $self->{TMP}});
	push @{$self->{CLEANUP}->{FILE}}, $filename;
	return $filename;
    }
    else
    {
	while (my $arg = shift) {
            my $filename = $self->get_safe_tmpfile ({TMP => $self->{TMP}});
	    $self->set_tmpfile($arg => $filename);
	}
    }
}

sub set_env
{
    my $self = shift;
    my $keys = { @_ };

    foreach my $key (keys %{$keys})
    {
	push @{$self->{CLEANUP}->{ENV}}, $key;
        $ENV{$key} = $keys->{$key};
    }
    return 1;
}

sub cleanup
{
    my $self = shift;

    foreach my $file (@{$self->{CLEANUP}->{FILE}})
    {
        if (-e $file) 
	{
	    unlink $file;
	}
        if (-e $file)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CLEANUP_FILE_FAILED",
                params  => {"FILENAME" => $file});
        }
    }

    foreach my $variable (@{$self->{CLEANUP}->{ENV}})
    {
        delete $ENV{$variable};
        if (exists $ENV{$variable})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CLEANUP_ENV_FAILED",
                params  => {"VARIABLE" => $variable});
        }
    }

    return 1;
}

sub get_openssl_dn
{
    my $self = shift;
    my $dn   = shift;

    ##! 2: "rfc2253: $dn"
    my $dn_obj = OpenXPKI::DN->new ($dn);
    if (not $dn_obj) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_DN_FAILURE",
            param   => {"DN" => $dn});
    }

    ## this is necessary because OpenSSL needs the utf8 bytes
    #pack/unpack is too slow, try to use "use utf8;"
    #$dn = pack "C*", unpack "C0U*", $dn_obj->get_openssl_dn ();
    $dn = $dn_obj->get_openssl_dn ();
    ##! 2: "OpenSSL X.500: $dn"

    return $dn;
}

# sub get_config_variable
# {
#     my $self = shift;
#     my $keys = { @_ };
# 
#     my $name     = $keys->{NAME};
#     my $config   = $keys->{CONFIG};
#     my $filename = $keys->{FILENAME};
# 
#     $config = $self->read_file ($filename)
#         if (not $config);
# 
#     return "" if ($config !~ /^(.*\n)*\s*${name}\s*=\s*([^\n^#]+).*$/s);
# 
#     my $result = $config;
#        $result =~ s/^(.*\n)*\s*${name}\s*=\s*([^\n^#]+).*$/$2/s;
#        $result =~ s/[\r\n\s]*$//s;
#     if ($result =~ /\$/)
#     {
#         my $dir = $result;
#            $dir =~ s/^.*\$([a-zA-Z0-9_]+).*$/$1/s;
#         my $value = $self->get_config_variable (NAME => $dir, CONFIG => $config);
#         ## why we use this check?
#         ## return undef if (not defined $dir);
#         $result =~ s/\$$dir/$value/g;
#     }
#     return $result;
# }

sub get_openssl_time
{
    my $self = shift;
    my $time = shift;

    $time = str2time ($time);
    $time = [ gmtime ($time) ];
    $time = POSIX::strftime ("%y%m%d%H%M%S",@{$time})."Z";

    return $time;
}

sub write_config
{
    my $self    = shift;
    my $profile = shift;

    ## create neaded files

    $self->get_tmpfile ('CONFIG');
    $self->get_tmpfile ('SERIAL');
    $self->get_tmpfile ('DATABASE');
    # ATTRFILE should be databasefile.attr
    # FIXME: we assume this file does not exist
    $self->set_tmpfile (ATTR => $self->{DATABASEFILE} . ".attr");

    ## create serial, index and index attribute file

    $self->{SERIAL} = Math::BigInt->new ($profile->get_serial());
    my $hex = undef;
    if ($self->{SERIAL})
    {
        $hex = substr ($self->{SERIAL}->as_hex(), 2);
        $hex = "0".$hex if (length ($hex) % 2);
    }

    if (exists $self->{INDEX_TXT})
    {
        ## this is a CRL
        $self->write_file (FILENAME => $self->{DATABASEFILE},
                           CONTENT  => $self->{INDEX_TXT},
                           FORCE    => 1);
        ## some CRLs will be issued without a serial
        $hex = "" if (not defined $profile->get_serial() or
                      not length $profile->get_serial());
    }
    else
    {
        ## this is a certificate
        $self->write_file (FILENAME => $self->{DATABASEFILE},
                           CONTENT  => "",
                           FORCE    => 1);
    }
    if (not $self->{SERIAL} and not defined $hex)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_WRITE_CONFIG_FAILED_SERIAL");
    }

    $self->write_file (FILENAME => $self->{ATTRFILE},
                       CONTENT  => "unique_subject = no\n",
                       FORCE    => 1);
    $self->write_file (FILENAME => $self->{SERIALFILE},
                       CONTENT  => $hex,
                       FORCE    => 1);

    ## create config

    my $config = "";

    ## general part

    $config .= "default_ca        = ca\n";
    if (length ($self->{ENGINE}->get_engine_section()))
    {
        $config .= "openssl_conf = openssl_def\n".
                   "\n".
                   "[openssl_def]\n".
                   "\n".
                   "engines = engine_section\n".
                   "\n".
                   "[engine_section]\n".
                   "\n".
                   $self->{ENGINE}->get_engine()."=engine_config\n".
                   "\n".
                   "[engine_config]\n".
                   "\n".
                   $self->{ENGINE}->get_engine_section()."\n";
    }

    ## CA/REQ/DEFAULT section

    $config .= "[ ca ]\n";

    $config .= "new_certs_dir     = ".$self->{TMP}."\n";
    $config .= "certificate       = ".$self->{ENGINE}->get_certfile()."\n";
    $config .= "private_key       = ".$self->{KEYFILE}."\n";

    if (my $notbefore = $profile->get_notbefore()) {
	$config .= "default_startdate = " 
	    . OpenXPKI::DateTime::convert_date(
	    {
		OUTFORMAT => 'openssltime',
		DATE      => $notbefore,
	    })
	    . "\n";
    }
    
    if (my $notafter = $profile->get_notafter()) {
	$config .= "default_enddate = " 
	    . OpenXPKI::DateTime::convert_date(
	    {
		OUTFORMAT => 'openssltime',
		DATE      => $notafter,
	    })
	    . "\n";
    }
    $config .= "default_md        = ".$profile->get_digest()."\n";
    $config .= "database          = ".$self->{DATABASEFILE}."\n";
    $config .= "serial            = ".$self->{SERIALFILE}."\n";
    $config .= "crlnumber         = ".$self->{SERIALFILE}."\n" if (defined $hex and length $hex);
    $config .= "default_crl_days  = ".$profile->get_nextupdate_in_days()."\n";
    $config .= "x509_extensions   = v3ca\n";
    $config .= "preserve          = YES\n";
    $config .= "policy            = dn_policy\n";
    $config .= "name_opt          = RFC2253,-esc_msb\n";
    $config .= "utf8              = yes\n";
    $config .= "string_mask       = utf8only\n";
    $config .= "\n";

    $config .= "[ dn_policy ]\n";
    $config .= "# this is a dummy because of preserve\n";
    $config .= "domainComponent = optional\n";
    $config .= "\n";
    
    ## extension section
    
    $config .= "[ v3ca ]\n";
    my $sections = "";
    
    foreach my $name (sort $profile->get_named_extensions())
    {
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
            $sections .= "[ cdp ]\n";
            my $i = 0;
            foreach my $cdp (@{$profile->get_extension("cdp")})
            {
                $sections .= "URI.$i=$cdp\n";
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
            $config .= "\n";
        }
        elsif ($name eq "key_usage")
        {
            $config .= "keyUsage = $critical";
            my @bits = @{$profile->get_extension("key_usage")};
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
        elsif ($name eq "subject_alt_name")
        {
            $config .= "subjectAltName = $critical\@subject_alt_name\n";
            my $ref = $profile->get_extension("subject_alt_name");
            my $i   = 0;
            $sections .= "[ subject_alt_name ]\n";
            foreach my $pair (@{$ref})
            {
                ## the hash only includes one key/value pair
                $sections .= join (".", keys %{$pair}).".$i = ".
                             $pair->{join (".", keys %{$pair})}."\n";
                $i++;
            }
            $sections .= "\n";
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
    
    ##! 2: "config: $config\n$sections\n"
    $self->write_file (FILENAME => $self->{CONFIGFILE},
                       CONTENT  => $config."\n".$sections,
	               FORCE    => 1);
}

sub DESTROY
{
    my $self = shift;
    $self->cleanup();
}

1;
__END__

=head1 Description

This function is the base class for all available OpenSSL commands
from the OpenSSL command line interface. All commands are executed
inside of the OpenSSL shell.

=head1 Functions

=head2 new

is the constructor. The ENGINE and the TMP parameter must be always
present. All other parameters will be passed without any checks to
the hash of the class instance. The real checks must be implemented
by the commands itself.

=head2 set_tmpfile

expects a hash with prefix infront of FILE and the filename which is
a tmpfile. Example:

$self->set_tmpfile ("IN" => "/tmp/example.txt")

mapped to

$self->{INFILE} = "/tmp/example.txt";

All temporary file are cleaned up automatically.

=head2 get_tmpfile

If called without arguments this method creates a temporary file and 
returns its filename:

  my $tmpfile = $self->get_tmpfile();

If called with one or more arguments, the method creates a temporary
file for each argument specified and calls $self->set_tmpfile() for
this argument.

Calling

  $self->get_tmpfile(IN, OUT);

is equivalent to

  $self->set_tmpfile( IN  => $self->get_tmpfile(),
                      OUT => $self->get_tmpfile() );

All temporary file are set to mode 0600 and are cleaned up automatically.

=head2 set_env

This function works exactly like set_tmpfile but without any
automatical prefixes or suffixes. The environment is also
cleaned up automatically.

=head2 cleanup

performs the cleanup of any temporary stuff like files from
set_tmpfile and environment variables from set_env.

=head2 get_openssl_dn

expects a RFC2253 compliant DN and returns an OpenSSL DN.

=head2 get_openssl_time

expects a time string compliant with Date::Parse and returns
a timestring which is compliant with the format used in
index.txt.

=head2 write_config

expect an instance of the OpenXPKI crypto profile module. It writes
a complete OpenSSL configuration to the filesystem. This includes
an index.txt, an index.txt.attr, a serial file and an openssl.cnf.
It depends heavily on the correct instance variables which must
be configured by the commands. Such variables are:

=over

=item * SERIALFILE (with next serial in hex format)

=item * INDEX_TXT (for CRL generation)

=item * DATABASEFILE (index.txt filename)

=item * CONFIGFILE

=back

=head2 get_config_variable (no longer supported)

is used to find a configuration variable inside of an OpenSSL
configuration file. The parameters are the NAME of the configuration
parameter and the FILENAME of the file which contains the parameter
or the complete CONFIG itself.

The function is able to resolve any used variables inside of the
configuration. Defintions like $dir/certs are supported.
