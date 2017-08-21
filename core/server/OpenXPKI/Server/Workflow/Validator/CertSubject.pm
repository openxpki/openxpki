package OpenXPKI::Server::Workflow::Validator::CertSubject;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

## TODO: This currently not in use and therefor untested!

sub validate {
    my ( $self, $wf, $profile, $style, $subject ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $api     = CTX('api');

    return if (not defined $profile);
    return if (not defined $style);
    return if (not defined $subject);

    my @errors;

    ## check correctness of subject
    eval {
        my $object = OpenXPKI::DN->new ($subject);
    };
    if ($EVAL_ERROR)
    {
        CTX('log')->application()->error("Could not create DN object from subject '$subject'");


        validation_error('I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_MATCH_INVALID_FORMAT');
    }

    my $always = CTX('config')->get_hash(['profile', $profile, , 'style', $style, 'always']);

    foreach my $label (keys %{$always}) {
        my $regex = $always->{$label};
        if (not $subject =~ m{$regex}xs) {
            push @errors, { label => $label, regex => $regex, subject => $subject };
        }
    }

    my $never = CTX('config')->get_hash(['profile', $profile, , 'style', $style, 'never']);

    foreach my $label (keys %{$never}) {
        my $regex = $never->{$label};
        if (not $subject !~ m{$regex}xs) {
            push @errors, { label => $label, regex => $regex, subject => $subject };
        }
    }

    if (@errors) {
        CTX('log')->application()->error("Certificate subject validation error for subject '$subject'");

        validation_error ( 'I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_MATCH_FAILED', { invalid_fields => \@errors } );
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CertSubject

=head1 SYNOPSIS

   validate_subject_against_regex:
       class: OpenXPKI::Server::Workflow::Validator::CertSubject
       arg:
        - $cert_profile
        - $cert_subject_style
        - $cert_subject

=head1 DESCRIPTION

This validator checks a given subject according to the profile configuration.

B<NOTE>: If you pass an empty string (or no string) to this validator
it will not throw an error.
