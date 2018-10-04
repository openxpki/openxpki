package OpenXPKI::Server::Workflow::Validator::ValidityTime;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

# @TODO: unused / untested

sub validate {
    my ( $self, $wf, $time ) = @_;

    my $context = $wf->context();
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);

    if ($time !~ m{\A [0-9]{14} \z}xms) {
        push @{$errors}, [ 'I18N_OPENXPKI_UI_ERROR_VALIDATOR_VALIDITY_TIME_INVALID_FORMAT',
                         {TIME => $time} ];
        $context->param ("__error" => $errors);
        CTX('log')->application()->error("Invalid validity time '$time'");

        validation_error ($errors->[scalar @{$errors} -1]);
    }
    my ($year, $month, $day, $hour, $minute, $seconds)
        = ($time =~ m{ ([0-9]{4})
                       ([0-9]{2})
                       ([0-9]{2})
                       ([0-9]{2})
                       ([0-9]{2})
                       ([0-9]{2}) }xms);
    if ($month > 12 || $day > 31 || $hour > 23 || $minute > 59 || $seconds > 59) {
        push @{$errors}, [ 'I18N_OPENXPKI_UI_ERROR_VALIDATOR_VALIDITY_TIME_INVALID_CONTENT',
                         {TIME => $time} ];
        $context->param ("__error" => $errors);
        CTX('log')->application()->error("Invalid validity time '$time'");

        validation_error ($errors->[scalar @{$errors} -1]);
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::ValidityTime

=head1 SYNOPSIS

  validate_validitytime"
       class: OpenXPKI::Server::Workflow::Validator::ValidityTime

=head1 DESCRIPTION

The validator verifies that a validity time input looks like an ISO-date
of form YYYYMMDDHHMMSS.
