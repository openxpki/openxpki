## OpenXPKI::Server::Workflow::Validator::CertSubjectParts
##
## Written 2007 by Alexander Klink for the OpenXPKI project
## Copyright (C) 2007 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Validator::CertSubjectParts;

use strict;
use warnings;
use utf8;

use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use English;
use Template;

use Data::Dumper;
use Encode;

sub validate {
    my ( $self, $wf, $profile, $profile_id, $style, $subject_parts ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $api     = CTX('api');
    my $config  = CTX('xml_config');
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);
    my $old_errors = scalar @{ $errors };

    return if (not defined $profile);
    return if (not defined $profile_id);
    return if (not defined $style);
    return if (not defined $subject_parts);

    ##! 16: 'wf->id(): ' . $wf->id()
    my $cfg_id = $api->get_config_id({ ID => $wf->id() });
    ##! 16: 'cfg_id: ' . $cfg_id
    if (! defined $cfg_id) {
        # as this is called during creation, the cfg id is not defined
        # yet, so we use the current one
        $cfg_id = $api->get_current_config_id();
    }
    ##! 16: 'cfg_id: ' . $cfg_id

    my $styles = $api->get_cert_subject_styles({
        PROFILE   => $profile,
        CONFIG_ID => $cfg_id,
    });
    ##! 64: 'styles: ' . Dumper $styles

    Encode::_utf8_off ($subject_parts);
    my $ser = OpenXPKI::Serialization::Simple->new();
    $subject_parts = $ser->deserialize($subject_parts);
    
    # delete empty entries from subject_parts (including empty
    # array elements)
    ##! 64: 'subject_parts before deleting empty parts: ' . Dumper $subject_parts
    foreach my $key (keys %{ $subject_parts }) {
        if (! ref $subject_parts->{$key}) {
            # translate scalars to one-element arrays    
            $subject_parts->{$key} = [ $subject_parts->{$key} ];
        }
        my @tmp = @{ $subject_parts->{$key} };
        my @cleaned = grep { $_ ne '' } @tmp;
        if (scalar @cleaned == 0) {
            # everything was empty, delete the whole key
            delete $subject_parts->{$key};
        }
        else {
            $subject_parts->{$key} = \@cleaned;
        }
    }
    ##! 64: 'subject_parts after deleting empty parts: ' . Dumper $subject_parts


    ## check correctness of subject
    # iterate over config and check regex against subject_parts
    # entry where defined

   CHECK:
    foreach my $part (@{ $styles->{$style}->{TEMPLATE}->{INPUT} }) {
        ##! 128: 'part: ' . Dumper $part
        my $id = $part->{ID};
        my $subj_part = $subject_parts->{'cert_subject_' . $id};
        my $min = 1;
        if (exists $part->{MIN}) {
            $min = $part->{MIN};
        }
        ##! 64: 'min: ' . $min
        if ($min > 0 && ! defined $subj_part) {
            push @{ $errors }, 
                [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERTSUBJECTPARTS_PART_NOT_AVAILABLE_BUT_REQUIRED',
                    {
                        PART => $id,
                    },
                ];
            next CHECK;
        }
        if ($min == 0 && ! defined $subj_part) {
            ##! 64: 'subj_part is undef and optional'
            # we can skip the rest of the tests if subj_part is undef
            next CHECK;
        }
        if (scalar @{ $subj_part } < $min) {
            push @{ $errors }, 
                [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERTSUBJECTPARTS_TOO_LITTLE_ELEMENTS',
                    {
                        PART   => $id,
                        MIN    => $min,
                        AMOUNT => scalar @{ $subj_part },
                    },
                ];
        }
        if (exists $part->{MAX}
              && scalar @{ $subj_part } > $part->{MAX}) {
            push @{ $errors },
                [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERTSUBJECTPARTS_TOO_MANY_ENTRIES_FOR_PART',
                    {
                        PART    => $id,
                        ENTRIES => scalar @{ $subj_part },
                        MAX     => $part->{MAX},
                    },
                ];
        }
        if (exists $part->{MATCH}) {
            # a regex exists, we have to match every element of subj_part
            # against it
            for (my $i = 0; $i < scalar @{ $subj_part }; $i++) {
                if ($subj_part->[$i] !~ m{$part->{MATCH}}xs) {
                    push @{ $errors },
                        [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERTSUBJECTPARTS_DID_NOT_MATCH_REGEX',
                            {
                                PART    => $id,
                                INDEX   => $i,
                                REGEX   => $part->{MATCH},
                            },
                        ];
                }
            }
        }
        if ($part->{TYPE} eq 'select') {
            my @options = @{ $part->{OPTIONS} };
            ##! 64: 'options: ' . Dumper \@options
            ##! 64: 'subj_part: ' . $subj_part->[0]
            if (! grep { $subj_part->[0] eq $_ } @options) {
                push @{ $errors },
                    [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERTSUBJECTPARTS_SELECT_DID_NOT_MATCH_OPTIONS',
                        {
                            PART    => $id,
                            OPTIONS => join q{, }, @{ $part->{OPTIONS} },
                        },
                    ];
            }
        }
    }

    ## did we find any errors?
    if (scalar @{$errors} and scalar @{$errors} > $old_errors)
    {
        $context->param ("__error" => $errors);
	CTX('log')->log(
	    MESSAGE  => "Certificate subject validation error",
	    PRIORITY => 'error',
	    FACILITY => 'system',
	    );

        validation_error ($errors->[scalar @{$errors} -1]->[0]);
    }

    # escape , in values
    # TODO - what more do we need to escape?

    foreach my $key (keys %{ $subject_parts }) {
        foreach my $elt (@{ $subject_parts->{$key} }) {
            $elt =~ s{,}{\\,}xmsg;
        }
    }
    ##! 64: 'subject_parts after escaping: ' . Dumper $subject_parts

    # save cert_subject to workflow context

    my $template_vars = {};
    foreach my $key (keys %{ $subject_parts }) {
        my ($template_key) = ($key =~ m{ \A cert_subject_(.*) \z }xms);
        if (scalar @{ $subject_parts->{$key} } == 1) {
            $template_vars->{$template_key} = $subject_parts->{$key}->[0];
        }
        else {
            $template_vars->{$template_key} = $subject_parts->{$key};
        }
    }
    ##! 64: 'template_vars: ' . Dumper $template_vars

    my $template = '[% TAGS [- -] -%]' . $styles->{$style}->{DN};
    my $tt = Template->new();
    my $cert_subject = '';
    $tt->process(\$template, $template_vars, \$cert_subject);

    $context->param('cert_subject' => $cert_subject);
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CertSubject

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="CertSubject"
           class="OpenXPKI::Server::Workflow::Validator::CertSubject">
    <arg value="$cert_profile"/>
    <arg value="$cert_subject_style"/>
    <arg value="$cert_subject"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks a given subject according to the profile configuration.

B<NOTE>: If you pass an empty string (or no string) to this validator
it will not throw an error. Why? If you want a value to be defined it
is more appropriate to use the 'is_required' attribute of the input
field to ensure it has a value.
