package OpenXPKI::Server::Workflow::Validator::ValidityTime;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

sub validate {
    my ( $self, $wf, $time ) = @_;

    my $context = $wf->context();
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);

    if ($time !~ m{\A [0-9]{14} \z}xms) {
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_VALIDITYTIME_INVALID_FORMAT',
                         {TIME => $time} ];
        $context->param ("__error" => $errors);
        CTX('log')->log(
            MESSAGE => "Invalid validity time '$time'",
            PRIORITY => 'error',
            FACILITY => 'system',
        );
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
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_VALIDITYTIME_INVALID_CONTENT',
                         {TIME => $time} ];
        $context->param ("__error" => $errors);
        CTX('log')->log(
            MESSAGE => "Invalid validity time '$time'",
            PRIORITY => 'error',
            FACILITY => 'system',
        );
        validation_error ($errors->[scalar @{$errors} -1]);
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::ValidityTime

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="ValidityTime"
           class="OpenXPKI::Server::Workflow::Validator::ValidityTime">
    <arg value="$cert_role"/>
  </validator>
</action>

=head1 DESCRIPTION

The validator verifies that a validity time input looks like an ISO-date
of form YYYYMMDDHHMMSS.
