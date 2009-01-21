package OpenXPKI::Server::Workflow::Validator::CertSubjectAltNameParts;
##
## Written 2007 by Alexander Klink for the OpenXPKI project
## (based on Validator::CertSubjectAltName)
## Copyright (C) 2007 by The OpenXPKI Project
use base qw( Workflow::Validator );

use strict;
use warnings;
use utf8;

use OpenXPKI::Debug;
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use English;
use OpenXPKI::Serialization::Simple;
use Mail::RFC822::Address;
use Net::IP;

use Data::Dumper;
use Encode;

sub validate {
    my ( $self, $wf, $profile, $subj_style, $subject_parts, $subject_alt_name_parts ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $api     = CTX('api');
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);
    my $old_errors = scalar @{$errors};

    return if (not defined $subject_alt_name_parts);

    ##! 16: 'wf->id(): ' . $wf->id()
    my $cfg_id = $api->get_config_id({ ID => $wf->id() });
    ##! 16: 'cfg_id: ' . $cfg_id
    if (! defined $cfg_id) {
        # as this is called during creation, the cfg id is not defined
        # yet, so we use the current one
        $cfg_id = $api->get_current_config_id();
    }

    ##! 16: 'cfg_id: ' . $cfg_id
    Encode::_utf8_off ($subject_alt_name_parts);
    Encode::_utf8_off ($subject_parts);
    my $ser = OpenXPKI::Serialization::Simple->new();
    $subject_alt_name_parts = $ser->deserialize($subject_alt_name_parts);
    $subject_parts          = $ser->deserialize($subject_parts);

    my @sans = ();
    # combine key/value pairs into san array
    foreach my $key (grep m{ _key \z }xms, keys %{ $subject_alt_name_parts }) {
        my ($id) = ($key =~ m{ \A cert_subject_alt_name_(.*)_key \z }xms);
        if (! ref $subject_alt_name_parts->{$key}) {
            # scalar case
            my $type  = $subject_alt_name_parts->{$key};
            my $value = $subject_alt_name_parts->{
                        'cert_subject_alt_name_' . $id . '_value'};
            if ($type =~ m{ \A ((?: \d+\.)+ \d) \z}xms) { # type is an OID
                my $oid  = $1;
                $type = 'otherName';
                $value = $oid . ';UTF8:' . $value;
            }

            push @sans, [ $type, $value ];
        }
        elsif (ref $subject_alt_name_parts->{$key} eq 'ARRAY') {
            for (my $i = 0; $i < scalar @{ $subject_alt_name_parts->{$key} }; $i++) {
                my $type  = $subject_alt_name_parts->{$key}->[$i];
                my $value = $subject_alt_name_parts->{
                        'cert_subject_alt_name_' . $id . '_value'}->[$i];
                if ($type =~ m{ \A (\d+\.)+\d \z}xms) { # type is an OID
                    my $oid  = $1;
                    $type = 'otherName';
                    $value = $oid . ';UTF8:' . $value;
                }
                push @sans, [ $type, $value ];
            }
        }
    }
    ##! 64: '@sans: ' . Dumper \@sans

    # delete entries with empty values from @sans
    @sans = grep { $_->[1] ne '' } @sans;

    ##! 64: '@sans: ' . Dumper \@sans

#    foreach my $san (@sans) {
#        if (! ref $subject_alt_name_parts->{$key}) {
#            # translate scalars to one-element arrays    
#            $subject_alt_name_parts->{$key} = [ $subject_alt_name_parts->{$key} ];
#        }
#        my @tmp = @{ $subject_alt_name_parts->{$key} };
#        my @cleaned = grep { $_ ne '' } @tmp;
#        if (scalar @cleaned == 0) {
#            # everything was empty, delete the whole key
#            delete $subject_alt_name_parts->{$key};
#            # ... and the corresponding 'key' key
#            $key =~ s{ _value \z}{_key}xms;
#            delete $subject_alt_name_parts->{$key};
#        }
#        else {
#            $subject_alt_name_parts->{$key} = \@cleaned;
#        }
#    }
#    ##! 64: 'subject_alt_name_parts after deleting empty parts: ' . Dumper $subject_alt_name_parts

    ## now check every subject alternative name component
    foreach my $pair (@sans) {
         my $type  = $pair->[0];
         my $value = $pair->[1];

         ## check existence of the fields
         if (not defined $type or not length $type)
         {
             push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_MISSING_TYPE', {} ];
             next;
         }
         if (not defined $value or not length $value)
         {
             push @{$errors}, ["I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_MISSING_VALUE", {} ];
             next;
         }

         ## check the values
         if ($type eq "email")
         {
             ## testuser@openxpki.org
             if (not Mail::RFC822::Address::valid ($value))
             {
                 push @{$errors},
                      ["I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_WRONG_EMAIL",
                       { "EMAIL" => $value } ];
                 next;
             }
         }
         elsif ($type eq "DNS")
         {
             ## www.openxpki.org
             if ($value !~ /^[0-9a-zA-Z\-]+(\.[0-9a-zA-Z\-]+)+$/)
             {
                 push @{$errors},
                      ["I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_WRONG_DNS",
                       { "DNS" => $value } ];
                 next;
             }
         }
         elsif ($type eq "IP")
         {
             ## IPv4: 123.123.123.123
             ## IPv6: abcd:abcd:abcd:abcd:abcd:abcd:abcd:abcd
             ## IPv6: fe80::20a:e4ff:fe2f:6acd
             if (not Net::IP::ip_is_ipv4($value) and
                 not Net::IP::ip_is_ipv6($value))
             {
                 push @{$errors},
                      ["I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_WRONG_IP",
                       { "IP" => $value }];
                 next;
             }
         }
         elsif ($type eq "URI")
         {
             ## actually we have no URI validator
             ## TODO - maybe use Data::Validate::URI ?
         }
         elsif ($type eq "GUID")
         {
             ## UUID (RFC 4122): f81d4fae-7dec-11d0-a765-00a0c91e6bf6
             ## Microsoft GUID:  F8:1d:4F ...
             ## totally 128 Bit
             if ($value =~ /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/i)
             {
                 ## RFC 4122 syntax used
                 $value = substr ($value, 0,  8).substr($value,  9);
                 $value = substr ($value, 0, 12).substr($value, 13);
                 $value = substr ($value, 0, 16).substr($value, 17);
                 $value = substr ($value, 0, 20).substr($value, 21);
                 for (my $i=15; $i > 0; $i--)
                 {
                     $value = substr($value, 0, $i*2).":".substr($value, $i*2);
                 }
                 ## now we have the normal Microsoft representation
             }
             if ($value =~ /^[0-9a-f]{2}(:[0-9a-f]{2}){15}$/i)
             {
                 ## Mircosoft GUID representation
                 $value = uc($value);
             }
             else
             {
                 push @{$errors},
                      ["I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_WRONG_GUID",
                       { "GUID" => $value }];
                 next;
             }
         }
         elsif ($type eq "UPN")
         {
             ## this should look like an emailaddress
             if (not Mail::RFC822::Address::valid ($value))
             {
                 push @{$errors},
                      ["I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_WRONG_UPN",
                       { "EMAIL" => $value} ];
                 next;
             }
         }
         elsif ($type eq "DirName")
         {
             ## actually we have no checks for DirName
         }
         elsif ($type eq "RID")
         {
             ## we have no checks for RIDs
         }
         elsif ($type eq 'otherName') {
            ## we have no checks for any OID, but we accept it
            ## if the type is an OID 
         }
         else
         {
             push @{$errors},
                  ["I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_UNKNOWN_TYPE",
                   { "TYPE" =>  $type}];
             next;
         }
    }

    ## did we find any errors?
    if (scalar @{$errors} and scalar @{$errors} > $old_errors)
    {
        $context->param ("__error" => $errors);
	CTX('log')->log(
	    MESSAGE  => 'Invalid subject alternative name (' . join(', ', @{$errors}) . ')',
	    PRIORITY => 'error',
	    FACILITY => 'system',
        );
        validation_error ($errors->[scalar @{$errors} -1]);
    }
    # save subject alt names in context
    my $pkcs10 = $context->param('pkcs10');
    my $styles;
    if (defined $pkcs10) {
        $styles = CTX('api')->get_cert_subject_styles({
            PROFILE   => $profile,
            CONFIG_ID => $cfg_id,
            PKCS10    => $pkcs10,
        });
    }
    else {
        $styles = CTX('api')->get_cert_subject_styles({
            PROFILE   => $profile,
            CONFIG_ID => $cfg_id,
        });
    }
    ##! 64: 'styles: ' . Dumper $styles
 
    # template evaluation for 'fixed' SANs
    my $template_vars = {};
    foreach my $key (keys %{ $subject_parts }) {
        my ($template_key) = ($key =~ m{ \A cert_subject_(.*) \z }xms);
        $template_vars->{$template_key} = $subject_parts->{$key};
    }
    foreach my $san (@{ $styles->{$subj_style}->{SUBJECT_ALTERNATIVE_NAMES} }) {
         if ($san->{KEY}->{TYPE} eq 'fixed') {
             my $template = '[% TAGS [- -] -%]' . $san->{VALUE}->{TEMPLATE};
             my $tt = Template->new();
             my $result = '';
             ##! 64: 'template: ' . $template
             ##! 64: 'template_vars: ' . Dumper $template_vars
             # check if template vars contains variables that are arrays,
             # if so (and the corresponding variable is used in the
             # template), iterate over them
             my $iterated = 0;
             TEMPLATE_VARS:
             foreach my $key (keys %{ $template_vars }) {
                 ##! 64: 'key: ' . $key
                 if (ref $template_vars->{$key} eq 'ARRAY') {
                     ##! 64: '... is an array.'
                     if ($template !~ /$key/) {
                         ##! 64: 'template does not contain ' . $key . ', skipping.'
                         next TEMPLATE_VARS;
                     }
                     $iterated = 1;
                     # if we have an array, create a temporary template
                     # vars hash ref that contains one element as a scalar
                     # and evaluate those
                     foreach my $value (@{ $template_vars->{$key} }) {
                         ##! 64: 'iterating, value = ' . $value
                         # copy the existing template_vars except for the
                         # non-scalar key:
                         my $temp_template_vars = {};
                         COPY:
                         foreach my $k (keys %{ $template_vars }) {
                             next COPY if $k eq $key;
                             $temp_template_vars->{$k} = $template_vars->{$k};
                         }
                         # replace the corresponding template var with
                         # a scalar entry
                         $temp_template_vars->{$key} = $value;
                         ##! 64: 'copied template vars: ' . Dumper $temp_template_vars
                         my $temp_result = '';
                         $tt->process(\$template, $temp_template_vars, \$temp_result);
                         if ($temp_result ne '') {
                             push @sans, [ $san->{KEY}->{VALUE}, $temp_result ];
                         }
                     }
                 }
             }
             ##! 64: 'sans after iteration: ' . Dumper \@sans

             if (! $iterated) {
                 # by default, just process the template with the template
                 # vars and create (at most) one SAN entry in the @sans
                 # array:
                 $tt->process(\$template, $template_vars, \$result);
                 if ($result ne '') {
                     push @sans, [ $san->{KEY}->{VALUE}, $result ];
                 }
             }
         }
    }
    ##! 64: 'sans after evaluating fixed: ' . Dumper \@sans
    $context->param('cert_subject_alt_name' => $ser->serialize(\@sans));

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CertSubjectAltName

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="CertSubjectAltNameParts"
           class="OpenXPKI::Server::Workflow::Validator::CertSubjectAltNameParts">
    <arg value="cert_subject_alt_name_parts"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks the given subject alternative names. This
includes the types and the values.
