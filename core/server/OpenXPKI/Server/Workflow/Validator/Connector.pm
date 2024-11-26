package OpenXPKI::Server::Workflow::Validator::Connector;
use OpenXPKI;

use base qw( OpenXPKI::Server::Workflow::Validator );

use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( validation_error configuration_error );


sub _validate {

    my ( $self, $wf, $value ) = @_;

    ##! 1: 'start'
    my $path = $self->param('path') ||
        configuration_error "You must define a value for path";

    # empty value
    ##! 16: ' value is ' . $value
    return 1 if (!defined $value || $value eq '');

    ##! 16: 'Validating value ' . $value
    my $cfg = CTX('config');

    my @path = split(/\./, $path);

    ##! 32: 'Validation Path is ' . join(".", @path);
    push @path, $value;
    my $result;
    eval{
        $result = $cfg->get( \@path );
    };
    if ($EVAL_ERROR) {
        ##! 32: 'got eval error during calling connector ' . $EVAL_ERROR
        CTX('log')->application()->error("Exception while calling connector on path " . $path);
        validation_error( 'I18N_OPENXPKI_UI_VALIDATOR_CONNECTOR_EXCEPTION' );
        return 0;
    }

    ##! 32: 'Raw result is ' . (defined $result ? $result : 'undef')
    if (!$result) {
        CTX('log')->application()->error("Validator failed on path " . $path);
        validation_error( $self->param('error') || 'I18N_OPENXPKI_UI_VALIDATOR_CONNECTOR_CHECK_FAILED' );
        return 0;
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::Connector

=head1 SYNOPSIS

Build path from path + argument and query the config backend using a
I<get> call. Any true result is considered as "passed".

=head1 DESCRIPTION

Validates the context value referenced by argument using a connector. The path to
the connector must be given as parameter 'path' to the validator definition.

  global_validate_regex:
      class: OpenXPKI::Server::Workflow::Validator::Connector
      param:
          path: metadata.systemid
          error: SystemId is invalid
      arg:
       - $meta_system_id

The error parameter is optional, if set this is shown in the UI if the
validator fails.
