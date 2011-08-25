# OpenXPKI::Crypto::Profile::Base.pm 
# Written 2005 by Michael Bell for the OpenXPKI project
# Copyright (C) 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Profile::Base;

use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;

use DateTime;
use Data::Dumper;

# use Smart::Comments;

sub get_path
{
    my $self      = shift;
    my $config_id = shift;

    ## scan for correct pki realm

    my $pki_realm = $self->{config}->get_xpath_count(
        XPATH => "pki_realm",
        CONFIG_ID => $config_id,
    );
    for (my $i=0; $i < $pki_realm; $i++)
    {
        if ($self->{config}->get_xpath (XPATH   => ["pki_realm", "name"],
                                        COUNTER => [$i, 0],
                                        CONFIG_ID => $config_id,
                                       )
              eq $self->{PKI_REALM})
        {
            $pki_realm = $i;
        } else {
            if ($pki_realm == $i+1)
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_PROFILE_BASE_GET_PATH_WRONG_PKI_REALM");
            }
        }
    }

    ## scan for correct ca
 
    my $ca = $self->{config}->get_xpath_count (
        XPATH   => ["pki_realm", "ca"],
        COUNTER => [$pki_realm],
        CONFIG_ID => $config_id,
    );
    for (my $i=0; $i < $ca; $i++)
    {
        if ($self->{config}->get_xpath (XPATH   => ["pki_realm", "ca", "id"],
                                        COUNTER => [$pki_realm, $i, 0],
                                        CONFIG_ID => $config_id,
                                       )
              eq $self->{CA})
        {
            $ca = $i;
        } else {
            if ($ca == $i+1)
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_PROFILE_BASE_GET_PATH_WRONG_CA");
            }
        }
    }

    ## return result
    return (PKI_REALM => $pki_realm, CA => $ca);
}

sub load_extension
{
    ##! 1: 'start'
    my $self    = shift;
    my $keys    = { @_ };
    my @path    = @{$keys->{PATH}};
    my @counter = @{$keys->{COUNTER}};
    my @values  = ();
    my $cfg_id  = $keys->{CONFIG_ID};
    ##! 4: 'path: ' . Dumper \@path
    ##! 4: 'counter: ' . Dumper \@counter
    ##! 4: 'cfg_id: ' . $cfg_id

    ## is the extension used at all?

    ##! 16: 'check whether extension is present in config'
    my $scan = eval {
        $self->{config}->get_xpath_count(
            XPATH     => [@path],
            COUNTER   => [@counter],
            CONFIG_ID => $cfg_id,
        );
    };
    ##! 16: 'EVAL_ERROR: ' . $EVAL_ERROR
    ##! 16: 'scan' . $scan
    return 0 if ($EVAL_ERROR or not $scan);
    ##! 16: 'extension is present in config'

    ## is this a critical extension?

    my $critical;
    eval {
	$critical = $self->{config}->get_xpath (
	    XPATH     => [@path, "critical"],
	    COUNTER   => [@counter, 0, 0],
	    CONFIG_ID => $cfg_id);
    };
    if (! defined $critical) {
	$critical = 'false';
	# FIXME: should we generate a warning here that no criticality is
	# defined?
    }
    
    if ($path[$#path] eq "basic_constraints")
    {
        $values[0] = ["CA",
                      $self->{config}->get_xpath (XPATH   => [@path, "ca"],
                                                  COUNTER => [@counter, 0, 0],
                                                  CONFIG_ID => $cfg_id)];
        my $path_length;
        eval {
            $path_length = $self->{config}->get_xpath(
                XPATH   => [@path, "path_length"],
                COUNTER => [@counter, 0, 0],
                CONFIG_ID => $cfg_id
            );
        }; 
        if (defined $path_length) 
        {
            $values[1] = ["PATH_LENGTH",
                          $self->{config}->get_xpath (XPATH   => [@path, "path_length"],
                                                      COUNTER => [@counter, 0, 0],
                                                      CONFIG_ID => $cfg_id)];
        }
        $self->set_extension (NAME     => "basic_constraints",
                              CRITICAL => $critical,
                              VALUES   => [@values]);
    }
    elsif ($path[$#path] eq "key_usage")
    {
        my @bits = ( "digital_signature", "non_repudiation", "key_encipherment",
                     "data_encipherment", "key_agreement", "key_cert_sign",
                     "crl_sign", "encipher_only", "decipher_only" );
        for (my $i=0; $i < scalar @bits; $i++)
        {
            my $bit = $self->{config}->get_xpath (XPATH   => [@path, $bits[$i]],
                                                  COUNTER => [@counter, 0, 0],
                                                  CONFIG_ID => $cfg_id);
            $bit =~ s/\s+//g;
            $bit = "1" if ($bit eq "true");
            $bit = "0" if ($bit eq "false");
            push @values, $bits[$i] if ($bit);
        }
        $self->set_extension (NAME     => "key_usage",
                              CRITICAL => $critical,
                              VALUES   => [@values]);
    }
    elsif ($path[$#path] eq "extended_key_usage")
    {
        my @bits = ( "client_auth", "email_protection" );
        for (my $i=0; $i < scalar @bits; $i++)
        {
            my $config_value;
            eval {
               $config_value
                    = $self->{config}->get_xpath (XPATH   => [@path, $bits[$i]],
                                                  COUNTER => [@counter, 0, 0],
                                                  CONFIG_ID => $cfg_id);
            };
            if (defined $config_value &&
                   ($config_value eq 'true' || $config_value eq '1')) {
                push @values, $bits[$i];
            }
        }
	my $oid_count = 0;
	eval {
	    $oid_count 
		= $self->{config}->get_xpath_count (XPATH   => [@path, "oid"],
						    COUNTER => [@counter, 0],
                            CONFIG_ID => $cfg_id);
	};
        if ($oid_count > 0)
        {
            push @values, @{$self->{config}->get_xpath_list (XPATH   => [@path, "oid"],
                                                             COUNTER => [@counter, 0],
                                                             CONFIG_ID => $cfg_id)};
        }
	if (scalar @values)
        {
            $self->set_extension (NAME     => "extended_key_usage",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($path[$#path] eq "subject_key_identifier")
    {
        my $hash = $self->{config}->get_xpath (XPATH   => [@path, "hash"],
                                               COUNTER => [@counter, 0, 0],
                                               CONFIG_ID => $cfg_id);
        $hash = "1" if ($hash eq "true");
        $hash = "0" if ($hash eq "false");
        if ($hash)
        {
            $self->set_extension (NAME     => "subject_key_identifier",
                                  CRITICAL => $critical,
                                  VALUES   => ["hash"]);
        }
    }
    elsif ($path[$#path] eq "authority_key_identifier")
    {
        my $keyid = $self->{config}->get_xpath (XPATH   => [@path, "keyid"],
                                                COUNTER => [@counter, 0, 0],
                                                CONFIG_ID => $cfg_id);
        $keyid = "1" if ($keyid eq "true");
        $keyid = "0" if ($keyid eq "false");
        push @values, "keyid" if ($keyid);

        my $issuer = $self->{config}->get_xpath (XPATH   => [@path, "issuer"],
                                              COUNTER => [@counter, 0, 0],
                                              CONFIG_ID => $cfg_id);
        $issuer = "1" if ($issuer eq "true");
        $issuer = "0" if ($issuer eq "false");
        push @values, "issuer" if ($issuer);

        if (scalar @values)
        {
            $self->set_extension (NAME     => "authority_key_identifier",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($path[$#path] eq "issuer_alt_name")
    {
        my $copy = $self->{config}->get_xpath (XPATH   => [@path, "copy"],
                                               COUNTER => [@counter, 0, 0],
                                               CONFIG_ID => $cfg_id);
        $copy = "1" if ($copy eq "true");
        $copy = "0" if ($copy eq "false");
        if ($copy)
        {
            $self->set_extension (NAME     => "issuer_alt_name",
                                  CRITICAL => $critical,
                                  VALUES   => ["copy"]);
        }
    }
    elsif ($path[$#path] eq "crl_distribution_points")
    {
        my $count = 0;
        eval {
            $count = $self->{config}->get_xpath_count (XPATH   => [@path, "uri"],
                                              COUNTER => [@counter, 0],
                                              CONFIG_ID => $cfg_id);
        };
        if ($count) {
            push @values, @{$self->{config}->get_xpath_list (XPATH   => [@path, "uri"],
                                                             COUNTER => [@counter, 0],
                                                             CONFIG_ID => $cfg_id)};
        }
        if (scalar @values)
        {
            $self->set_extension (NAME     => "cdp",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($path[$#path] eq "authority_info_access")
    {
	my $ca_issuer_count = 0;
	eval {
	    $ca_issuer_count
		= $self->{config}->get_xpath_count (XPATH   => [@path, "ca_issuers"],
						    COUNTER => [@counter, 0],
                            CONFIG_ID => $cfg_id);
	};
        if ($ca_issuer_count > 0) {
            push @values, ["CA_ISSUERS",
                           $self->{config}->get_xpath_list (
                               XPATH   => [@path, "ca_issuers"],
                               COUNTER => [@counter, 0],
                               CONFIG_ID => $cfg_id)];
        }

	my $ocsp_count = 0;
	eval {
	    $ocsp_count 
		= $self->{config}->get_xpath_count (XPATH   => [@path, "ocsp"],
						    COUNTER => [@counter, 0],
                            CONFIG_ID => $cfg_id);
	};
	if ($ocsp_count > 0) {
	    push @values, ["OCSP",
			   $self->{config}->get_xpath_list (
			       XPATH   => [@path, "ocsp"],
			       COUNTER => [@counter, 0],
                   CONFIG_ID => $cfg_id)];
	}

	if (scalar @values)
	{
            $self->set_extension (NAME     => "authority_info_access",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($path[$#path] eq "user_notice")
    {
        push @values,  $self->{config}->get_xpath (XPATH   => [@path],
                                                   COUNTER => [@counter, 0],
                                                   CONFIG_ID => $cfg_id);
        $self->set_extension (NAME     => "user_notice",
                              CRITICAL => $critical,
                              VALUES   => [@values]);
    }
    elsif ($path[$#path] eq "policy_identifier")
    {
        if ($self->{config}->get_xpath_count (XPATH   => [@path, "oid"],
                                              COUNTER => [@counter, 0],
                                              CONFIG_ID => $cfg_id))
        {
            push @values, $self->{config}->get_xpath_list (XPATH   => [@path, "oid"],
                                                           COUNTER => [@counter, 0],
                                                           CONFIG_ID => $cfg_id);
        }
        if (scalar @values)
        {
            $self->set_extension (NAME     => "policy_identifier",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($path[$#path] eq "cps")
    {
        if ($self->{config}->get_xpath_count (XPATH   => [@path, "uri"],
                                              COUNTER => [@counter, 0],
                                              CONFIG_ID => $cfg_id))
        {
            push @values, $self->{config}->get_xpath_list (XPATH   => [@path, "uri"],
                                                 COUNTER => [@counter, 0],
                                                 CONFIG_ID => $cfg_id);
        }
        if (scalar @values)
        {
            $self->set_extension (NAME     => "cps",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($path[$#path] eq "oid")
    {
        my $count = $self->{config}->get_xpath_count (XPATH   => [@path],
                                                      COUNTER => [@counter],
                                                      CONFIG_ID => $cfg_id);
        for (my $i=0; $i<$count; $i++)
        {
            my $oid = $self->{config}->get_xpath (XPATH   => [@path, "numeric"],
                                                  COUNTER => [@counter, $i, 0],
                                                  CONFIG_ID => $cfg_id);
            $values[0] = ["FORMAT",
                          $self->{config}->get_xpath (XPATH   => [@path, "format"],
                                                      COUNTER => [@counter, $i, 0],
                                                      CONFIG_ID => $cfg_id)];
            $values[1] = ["ENCODING",
                          $self->{config}->get_xpath (XPATH   => [@path, "encoding"],
                                                      COUNTER => [@counter, $i, 0],
                                                      CONFIG_ID => $cfg_id)];
            $values[2] = ["CONTENT",
                          $self->{config}->get_xpath (XPATH   => [@path],
                                                      COUNTER => [@counter, $i],
                                                      CONFIG_ID => $cfg_id)];
            $self->set_extension (NAME     => $oid,
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($path[$#path] eq "netscape/comment")
    {
        push @values, $self->{config}->get_xpath (XPATH   => [@path],
                                                   COUNTER => [@counter, 0],
                                                  CONFIG_ID => $cfg_id);
        $self->set_extension (NAME     => "netscape/comment",
                              CRITICAL => $critical,
                              VALUES   => [@values]);
    }
    elsif ($path[$#path] eq "netscape/certificate_type")
    {
        my @bits = ( "ssl_client", "smime_client", "object_signing",
                     "ssl_ca", "smime_ca", "object_signing_ca" );
        for (my $i=0; $i < scalar @bits; $i++)
        {
            my $bit = $self->{config}->get_xpath (XPATH   => [@path, $bits[$i]],
                                                  COUNTER => [@counter, 0, 0],
                                                  CONFIG_ID => $cfg_id);
            $bit = "1" if ($bit eq "true");
            $bit = "0" if ($bit eq "false");
            push @values, $bits[$i] if ($bit);
        }
        $self->set_extension (NAME     => "netscape/certificate_type",
                              CRITICAL => $critical,
                              VALUES   => [@values]);
    }
    elsif ($path[$#path] eq "netscape/cdp")
    {
        my $cdp = $self->{config}->get_xpath (XPATH   => [@path, "url"],
                                              COUNTER => [@counter, 0, 0],
                                              CONFIG_ID => $cfg_id);
        $self->set_extension (NAME     => "netscape/cdp",
                              CRITICAL => $critical,
                              VALUES   => [$cdp]);

        $cdp = $self->{config}->get_xpath (XPATH   => [@path, "ca_url"],
                                           COUNTER => [@counter, 0, 0],
                                           CONFIG_ID => $cfg_id);
        $self->set_extension (NAME     => "netscape/ca_cdp",
                              CRITICAL => $critical,
                              VALUES   => [$cdp]);
    }
    else
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_LOAD_EXTENSION_UNKNOWN_NAME",
            params  => {NAME => $path[$#path]});
    }

    return 1;
}

sub set_extension
{
    ##! 1: 'start'
    my $self = shift;
    my $keys = { @_ };
    my $name     = $keys->{NAME};
    my $critical = $keys->{CRITICAL};
    my $value    = $keys->{VALUES};
    
    if (! defined $name) {
	OpenXPKI::Exception->throw(
	    message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_SET_EXTENSION_NAME_NOT_SPECIFIED",
	    );
    }
	
    if (! defined $value) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_SET_EXTENSION_VALUE_NOT_SPECIFIED",
	    );
    }
    if (! defined $critical) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_SET_EXTENSION_CRITICALITY_NOT_SPECIFIED",
	    params => {
		NAME => $name,
		VALUE => $value,
	    });
    }
    if ($critical !~ m{ \A (?:true|false) }xms) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_SET_EXTENSION_INVALID_CRITICALITY",
	    params => {
		NAME => $name,
		VALUE => $value,
		CRITICALITY => $critical,
	    });
    }
    
    ##! 16: 'name: ' . $name
    ##! 16: 'critical: ' . $critical
    ##! 16: 'value: ' . $value

    $critical = 0 if ($critical eq "false");
    $critical = 1 if ($critical eq "true");
    $self->{PROFILE}->{EXTENSIONS}->{$name}->{CRITICAL} = $critical;

    if (ref $value->[0])
    {
        ## these are value pairs (e.g. subject alt name)
        ## WARNING this is no clean copy by value
        $self->{PROFILE}->{EXTENSIONS}->{$name}->{PAIRS} = [ @{$value} ];
    }
    else
    {
        ## copy by value (normal array)
        $self->{PROFILE}->{EXTENSIONS}->{$name}->{VALUE} = [ @{$value} ];
    }

    return 1;
}


sub is_critical_extension
{
    my $self = shift;
    my $ext  = shift;

    if (not exists $self->{PROFILE}->{EXTENSIONS}->{$ext})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_IS_CIRITICAL_EXTENSION_NOT_FOUND");
    }

    return $self->{PROFILE}->{EXTENSIONS}->{$ext}->{CRITICAL};
}

sub get_extension
{
    my $self = shift;
    my $ext  = shift;

    if (not exists $self->{PROFILE}->{EXTENSIONS}->{$ext})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_GET_EXTENSION_NOT_FOUND",
            params  => {
                "EXTENSION" => $ext,
            },
        );
    }

    if (exists $self->{PROFILE}->{EXTENSIONS}->{$ext}->{VALUE})
    {
        return $self->{PROFILE}->{EXTENSIONS}->{$ext}->{VALUE};
    } else {
        return $self->{PROFILE}->{EXTENSIONS}->{$ext}->{PAIRS};
    }
}

sub set_serial
{
    my $self = shift;
    $self->{PROFILE}->{SERIAL} = shift;
    return 1;
}

sub get_serial
{
    my $self = shift;
    return $self->{PROFILE}->{SERIAL};
}

sub get_oid_extensions
{
    my $self = shift;
    return grep /\./, keys %{$self->{PROFILE}->{EXTENSIONS}};
}

sub get_named_extensions
{
    my $self = shift;
    return grep /^[^.]+$/, keys %{$self->{PROFILE}->{EXTENSIONS}};
}


sub get_entry_validity {
    my $self = shift;
    my $params = shift;

    if ((! exists $params->{XPATH}) || (ref $params->{XPATH} ne "ARRAY")) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_PROFILE_BASE_GET_ENTRY_VALIDITY_MISSING_PARAMETER",
	    params  => {
		PARAMETER => 'XPATH',
	    });
    }

    if ((! exists $params->{COUNTER}) || (ref $params->{COUNTER} ne "ARRAY")) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_PROFILE_BASE_GET_ENTRY_VALIDITY_MISSING_PARAMETER",
	    params  => {
		PARAMETER => 'COUNTER',
	    });
    }

    if (! exists $params->{CONFIG_ID}) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_PROFILE_BASE_GET_ENTRY_VALIDITY_MISSING_PARAMETER",
	    params  => {
		PARAMETER => 'CONFIG_ID',
	    });
    }
    
    my %entry_validity = ();

    foreach my $validitytype (qw( notbefore notafter )) {
	
	# parse validity entry
	### $validitytype
	my $validity;
	my $format;
	eval {
	    $format = $self->{config}->get_xpath(
            XPATH     => [ @{$params->{XPATH}},   'validity', $validitytype, 'format' ],
            COUNTER   => [ @{$params->{COUNTER}}, 0,          0,             0 ],
            CONFIG_ID => $params->{CONFIG_ID},
		);
	    
	    ### $format
	    $validity = $self->{config}->get_xpath(
            XPATH     => [ @{$params->{XPATH}},   'validity', $validitytype ],
            COUNTER   => [ @{$params->{COUNTER}}, 0,          0 ],
            CONFIG_ID => $params->{CONFIG_ID},
		);
	    ### $validity
	    
	};
	if (my $exc = OpenXPKI::Exception->caught()) {
	    # ignore exception for missing 'notbefore' entry
	    if (($exc->message() 
		 eq "I18N_OPENXPKI_XML_CACHE_GET_XPATH_MISSING_ELEMENT")
		&& ($validitytype eq "notbefore")) {
		# default: "now"
		$validity = undef;
	    }
	    else
	    {
		$exc->rethrow();
	    }
	} elsif ($EVAL_ERROR && (ref $EVAL_ERROR)) {
	    $EVAL_ERROR->rethrow();
	}
	
	### got format: $format
	### got validity: $validity
	
	if ((defined $format) &&
	    (defined $validity)) {
	    $entry_validity{$validitytype} = {
		VALIDITYFORMAT => $format,
		VALIDITY       => $validity,
	    };
	}
	
    }
    
    return %entry_validity;
}


our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    return if ($AUTOLOAD =~ m{ \A .*::DESTROY \z}xms);
    return "" if ($AUTOLOAD =~ s/^.*:get_//);
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_PROFILE_BASE_AUTOLOAD_ILLEGAL_FUNCTION",
        params  => {"FUNCTION" => $AUTOLOAD});
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Profile::Base - base class for cryptographic profiles
for certificates and CRLs.

=head1 Description

Base class for profiles used in the CA.

=head2 Subclassing

...

=head1 Functions

=head2 ...
