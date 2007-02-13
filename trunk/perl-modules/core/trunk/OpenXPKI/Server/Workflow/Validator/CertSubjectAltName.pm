package OpenXPKI::Server::Workflow::Validator::CertSubjectAltName;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use English;
use OpenXPKI::Serialization::Simple;
use Mail::RFC822::Address;
use Net::IP;

sub validate {
    my ( $self, $wf, $subject_alt_name ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $api     = CTX('api');
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);
    my $old_errors = scalar @{$errors};

    return if (not defined $subject_alt_name);

    ## deserialize
    my $list;
    eval
    {
        my $serializer = OpenXPKI::Serialization::Simple->new();
        $list = $serializer->deserialize($subject_alt_name);
    };
    if ($EVAL_ERROR)
    {
        push @{$errors}, [$EVAL_ERROR];
        $context->param ("__error" => $errors);
	CTX('log')->log(
	    MESSAGE  => "Could not deserialize subject alternative names ($subject_alt_name)",
	    PRIORITY => 'error',
	    FACILITY => 'system',
        );
        validation_error ($errors->[scalar @{$errors} -1]);
    }

    ## now check every subject alternative name component
    my @fixed = ();
    foreach my $pair (@{$list})
    {
        my $type  = $pair->[0];
        my $value = $pair->[1];

        ## check existence of the fields
        if (not defined $type or not length $type)
        {
            push @{$errors}, ["I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_MISSING_TYPE"];
            next;
        }
        if (not defined $value or not length $value)
        {
            push @{$errors}, ["I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_MISSING_VALUE"];
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
                      "EMAIL", $value];
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
                      "DNS", $value];
                next;
            }
        }
        elsif ($type eq "IP")
        {
            ## IPv4: 123.123.123.123
            ## IPv6: abcd:abcd:abcd:abcd:abcd:abcd:abcd:abcd
            ## IPv6: fe80::20a:e4ff:fe2f:6acd
            my $object = Net::IP->new($value);
            if (not Net::IP::ip_is_ipv4($value) and
                not Net::IP::ip_is_ipv6($value))
            {
                push @{$errors},
                     ["I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_WRONG_IP",
                      "IP", $value];
                next;
            }
        }
        elsif ($type eq "URI")
        {
            ## actually we have no URI validator
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
                      "GUID", $value];
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
                      "EMAIL", $value];
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
        else
        {
            push @{$errors},
                 ["I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_ALT_NAME_UNKNOWN_TYPE",
                  "TYPE", $value];
            next;
        }
        push @fixed, [$type, $value];
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

    ## serialize and store the fixed context
    ## the serialized text must be safe against \n truncation
    my $serializer = OpenXPKI::Serialization::Simple->new({SEPARATOR => "-"});
    $subject_alt_name = $serializer->serialize(\@fixed);
    $context->param ("cert_subject_alt_name" => $subject_alt_name);

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CertSubjectAltName

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="CertSubjectAltName"
           class="OpenXPKI::Server::Workflow::Validator::CertSubjectAltName">
    <arg value="cert_subject_alt_name"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks a given subject alternative name. This
includes the types and the values.

B<NOTE>: If you pass an empty string (or no string) to this validator
it will not throw an error. Why? If you want a value to be defined it
is more appropriate to use the 'is_required' attribute of the input
field to ensure it has a value.
