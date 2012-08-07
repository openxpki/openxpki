# OpenXPKI::Crypto::Profile::Base.pm 
# Written 2005 by Michael Bell for the OpenXPKI project
# Copyright (C) 2005-2006 by The OpenXPKI Project

=head1 Name
OpenXPKI::Crypto::Profile::Base - base class for cryptographic profiles
for certificates and CRLs.

=head1 Description
Base class for profiles used in the CA.
=cut

use strict;
use warnings;

package OpenXPKI::Crypto::Profile::Base;

use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use Template;

use OpenXPKI::Server::Context qw( CTX );

use DateTime;
use Data::Dumper;

# use Smart::Comments;


=head1 Functions

=head2 load_extension
Load data from the extensions section

=over
=item * PROFILE (certificates only)

Name of the profile to get the extension from.

=item * CA (crl only)

Name of the CA to get the extension from.

=item * EXT

Name of the extension to load.
=back
=cut
sub load_extension
{
    ##! 1: 'start'
    my $self  = shift;
    my $args  = shift;
    my $profile_path = $args->{PATH};    
    my $ext = $args->{EXT};
    my @values  = ();
    
    ##! 32: Dumper ( $args )
    
    my $config = CTX('config');
           
    ##! 4: "Profile: $profile_path, Extension: $ext"
    my $path = "$profile_path.extensions.$ext";
    
    ##! 16: 'path: ' . $path

    my $ext_type = $config->get_meta($path);
    ## is the extension used at all?
    if (!$ext_type) {
        ##! 16: "Extension $ext is not used"        
        return 0;
    }

    ## is this a critical extension?

    my $critical = $config->get("$path.critical");
    
    if ($critical) {
        $critical = 'true';
    } else {
        # FIXME: No flag in OID
        if (! defined $critical) {
            CTX('log')->log(
                MESSAGE  => "Critical flag is not set for $ext in profile $profile_path!",
                PRIORITY => 'warn',
                FACILITY => 'system',
            );
        }
        $critical = 'false';
    }
    
    if ($ext eq "basic_constraints")
    {
        $values[0] = ["CA", ($config->get("$path.ca") || 0) ];
        my $path_length = $config->get("$path.path_length");
        if (defined $path_length) 
        {
            $values[1] = ["PATH_LENGTH", $path_length];
        }
        $self->set_extension (NAME     => "basic_constraints",
                              CRITICAL => $critical,
                              VALUES   => [@values]);
    }
    elsif ($ext eq "key_usage")
    {
        my @bits = ( "digital_signature", "non_repudiation", "key_encipherment",
                     "data_encipherment", "key_agreement", "key_cert_sign",
                     "crl_sign", "encipher_only", "decipher_only" );
                     
        foreach my $bit (@bits) {
            push @values, $bit if ($config->get("$path.$bit"));    
        }                     
                              
        $self->set_extension (NAME     => "key_usage",
                              CRITICAL => $critical,
                              VALUES   => [@values]);
    }
    elsif ($ext eq "extended_key_usage")
    {
        my $bits_set = $config->get_hash("$path");
        ##! 16: "ext key usage bits: ". Dumper $bits_set
        my @bits = ( "client_auth", "email_protection" );
        foreach my $bit (@bits) {
            push @values, $bit if ( $bits_set->{$bit} );    
        }
         
        # check keys of hash for numeric oids
        foreach my $oid (keys %{$bits_set}) {
            if ($oid =~ /^\d+(\.\d+)+$/) {
                push @values, $oid;    
            }
        }          
    	            
        if (scalar @values)
        {
            $self->set_extension (NAME     => "extended_key_usage",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($ext eq "subject_key_identifier")
    {        
        if ($config->get("$path.hash"))
        {
            $self->set_extension (NAME     => "subject_key_identifier",
                                  CRITICAL => $critical,
                                  VALUES   => ["hash"]);
        }
    }
    elsif ($ext eq "authority_key_identifier")
    {
        
        my @bits = ( "keyid", "issuer" );
        foreach my $bit (@bits) {
            push @values, $bit if (  $config->get("$path.$bit") );    
        } 
        if (scalar @values)
        {
            $self->set_extension (NAME     => "authority_key_identifier",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($ext eq "issuer_alt_name")
    {        
        if ($config->get("$path.copy") )
        {
            $self->set_extension (NAME     => "issuer_alt_name",
                                  CRITICAL => $critical,
                                  VALUES   => ["copy"]);
        }
    }
    elsif ($ext eq "crl_distribution_points")
    {
        
        my @uri;
        my $meta = $config->get_meta("$path.uri");
        if ($meta && $meta->{TYPE} eq 'list') {                
            @uri = $config->get_list("$path.uri");
        } else {
            @uri = ( $config->get("$path.uri") );
        }
        
        # Parse using Template Toolkit 
        @values = @{ $self->process_templates(\@uri) };
        
        if (scalar @values)
        {
            $self->set_extension (NAME     => "cdp",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($ext eq "authority_info_access")
    {
        
        my @bits = ( "keyid", "issuer" );
        foreach my $bit (qw(ca_issuers ocsp)) {
        
            my @template_list; 
            my $meta = $config->get_meta("$path.$bit");
            if ($meta && $meta->{TYPE} eq 'list') {
                @template_list = $config->get_list("$path.$bit");
            } else {
                my $template = $config->get("$path.$bit");
                push @template_list, $template if ($template);
            }
                     
            # Parse using Template Toolkit and push result 
            if (scalar @template_list) {
                push @values, [uc($bit), $self->process_templates( \@template_list ) ];
            }                               
        }
 
    	if (scalar @values)
    	{
            $self->set_extension (NAME     => "authority_info_access",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($ext eq "user_notice")
    {
        my $meta = $config->get_meta("$path");
        if ($meta && $meta->{TYPE} eq 'list') {
            @values = $config->get_list("$path");
        } else {
            @values = ( $config->get("$path") );
        }
        
        if (scalar @values) {
            $self->set_extension (NAME     => "user_notice",
                              CRITICAL => $critical,
                              VALUES   => [@values]);
        }
                              
    }
    elsif ($ext eq "policy_identifier")
    {
        
        @values = $config->get_scalar_as_list("$path.oid");                        
        if (scalar @values)
        {
            $self->set_extension (NAME     => "policy_identifier",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($ext eq "cps")
    {        
        my $meta = $config->get_meta("$path.uri");
        if ($meta && $meta->{TYPE} eq 'list') {
            @values = $config->get_list("$path.uri");
        } else {
            @values = ( $config->get("$path.uri") );
        }

        if (scalar @values)
        {
            $self->set_extension (NAME     => "cps",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($ext eq "oid")
    {
            
        # The numeric value is used as key, the content is a hash below
        my @oids = $config->get_keys("$path");    

        foreach my $oid (@oids) { 
            $values[0] = ["FORMAT", $config->get("$path.$oid.format") ];
            $values[1] = ["ENCODING", $config->get("$path.$oid.encoding") ];
            $values[2] = ["CONTENT", $config->get("$path.$oid.value") ];
            $self->set_extension (NAME     => $oid,
                                  CRITICAL => $config->get("$path.$oid.critical") ? 'true' : 'false',
                                  VALUES   => [@values]);
        }
    }
    elsif ($ext eq "netscape.comment")
    {
        my $comment = $config->get("$path.text");
        if ($comment) 
        { 
            $self->set_extension (NAME     => "netscape.comment",
                              CRITICAL => $critical,
                              VALUES   => [ $comment ]);
        }
    }
    elsif ($ext eq "netscape.certificate_type")
    {
        my @bits = ( "ssl_client", "smime_client", "object_signing",
                     "ssl_client_ca", "smime_client_ca", "object_signing_ca" );
 
        foreach my $bit (@bits) {
            push @values, $bit if (  $config->get("$path.$bit") );    
        }                      

        if (scalar @values) {
            $self->set_extension (NAME     => "netscape.certificate_type",
              CRITICAL => $critical,
              VALUES   => [@values]);
        }
                              
    }
    elsif ($ext eq "netscape.cdp")
    {
        
        my $cdp = $config->get("$path.uri");
        if ($cdp) {            
            $self->set_extension (NAME     => "netscape.cdp",
                  CRITICAL => $critical,
                  VALUES   => [$cdp]);
        }

        my $ca_cdp = $config->get("$path.ca_uri");
        if ($ca_cdp) {
            $self->set_extension (NAME     => "netscape.ca_cdp",
                              CRITICAL => $critical,
                              VALUES   => [$ca_cdp]);
        }
    }
    else
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_LOAD_EXTENSION_UNKNOWN_NAME",
            params  => {NAME => $ext, PATH => $path});
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
    ##! 16: 'value: ' . Dumper ( $value )

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
    return grep /\d+\./, keys %{$self->{PROFILE}->{EXTENSIONS}};
}

sub get_named_extensions
{
    my $self = shift;
    return grep /[^(\d+\.)]/, keys %{$self->{PROFILE}->{EXTENSIONS}};
}

=head2 process_templates

Helper method to parse profile items through template toolkit.
Expects an array of strings containing one TT Template per line.
Available variables for substitution are 

=over

=item ISSUER.x Hash with the subject parts of the issuing certificate. 
Note that each key is an array itself, even if there is only a single value in it. 
Therefore you need to write e.g. ISSUER.OU.0 for the (first) OU entry. Its wise 
to do urlescaping on the output, e.g. [- ISSUER.OU.0 | uri -].

=item CAALIAS Alias name of the used ca (as given in the alias table)

=back
=cut
sub process_templates {
    
    my $self = shift;
    my $values = shift;    
    
    # Add ability to use template toolkit - check if there are tags inside
        
    ##! 32: ' Test for TT ' . Dumper ( $values )      
    if (! scalar(grep /\[.*\]/, @$values) ) {
        return $values;
    }
            
    ##! 16: 'Tags found - init TT'
    my $tt = Template->new();            

    # FIXME - this might be improves using some caching
    my $certificate = CTX('api')->get_certificate_for_alias( { 'ALIAS' => $self->{CA} });
    my $default_token = CTX('api')->get_default_token();
    
    my $x509 = OpenXPKI::Crypto::X509->new(
        DATA  => $certificate->{DATA},
        TOKEN => $default_token,
    );
        
    # Get Issuer Info from selected ca    
    my $issuer_info = $x509->{PARSED}->{BODY}->{SUBJECT_HASH};
       
    my %template_vars = (
        'ISSUER' => $issuer_info,
        'CAALIAS' => $self->{CA},
    ); 
    ##! 32: ' Template Vars ' . Dumper ( %template_vars )  
    
    my @newvalues;
    while (my $template = shift @$values) {  
        if ($template =~ /\[.+\]/) {
            my $output;
            #$template = '[% TAGS [- -] -%]' .  $template;
            $tt->process(\$template, \%template_vars, \$output);                    
            ##! 32: ' Tags found - ' . $template . ' -> '. $output
            if($output) {
                push @newvalues, $output;
            }                                                         
        } else {
            push @newvalues, $template;
        }                
    }            
         
    ##! 64: ' Processed CRL DP ' . Dumper ( @newvalues )        
    return \@newvalues;
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

 
