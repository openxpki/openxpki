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
    $self->error( 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CONNECTOR_CHECK_FAILED' );
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
        CTX('log')->log(
            MESSAGE  => "Validator failed on path " . $self->path(),
            PRIORITY => 'info',
            FACILITY => 'system',
        );
        validation_error( $self->error() );
        return 0;
    }
    
    return 1;
}

1;



=head1 NAME

OpenXPKI::Server::Workflow::Validator::Connector

=head1 SYNOPSIS

    <action name="..." class="...">
        <validator name="validate_connector">                                    
            <arg>meta_email</arg>            
        </validator>
    </action>        
            
=head1 DESCRIPTION

Validates the context value referenced by argument using a connector. The path to
the connector must be given as parameter 'path' to the validator definition.

  <validator name="global_validate_regex"
      class="OpenXPKI::Server::Workflow::Validator::Regex">     
      <param name="path" value="email">
      <param name="error" value="email is unknown">
  </validator>
 
The error parameter is optional, if set this is shown in the UI if the validator
fails.  
 
=over
 
=item email

Basic check for valid email syntax

=back 