package OpenXPKI::Server::Workflow::Validator::Connector;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Validator );
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( validation_error configuration_error );

__PACKAGE__->mk_accessors(qw(path error));

sub _init {
    my ( $self, $params ) = @_;
    unless ( $params->{path} ) {
        configuration_error
            "You must define a value for path in ",
            "declaration of validator ", $self->name;
    }

    $self->path( $params->{path} );
    $self->error( 'I18N_OPENXPKI_UI_VALIDATOR_CONNECTOR_CHECK_FAILED' );
    $self->error( $params->{error} ) if ($params->{error});
}

sub _validate {

    my ( $self, $wf, $value ) = @_;

    ##! 1: 'start'

    # empty value
    ##! 16: ' value is ' . $value
    return 1 if (!defined $value || $value eq '');

    ##! 16: 'Validating value ' . $value
    my $cfg = CTX('config');

    my @path = split(/\./, $self->path());

    ##! 32: 'Validation Path is ' . join(".", @path);
    push @path, $value;
    my $result = $cfg->get( \@path );

    ##! 32: 'Raw result is ' . (defined $result ? $result : 'undef')
    if (!$result) {
        CTX('log')->application()->error("Validator failed on path " . $self->path());

        validation_error( $self->error() );
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
      class: OpenXPKI::Server::Workflow::Validator::Regex
      param:
          path: metadata.systemid
          error: SystemId is invalid
      arg:
       - $meta_system_id

The error parameter is optional, if set this is shown in the UI if the
validator fails.
