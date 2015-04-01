
package OpenXPKI::Server::Workflow::Validator;

use strict;

use Moose;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use Data::Dumper;

extends 'Workflow::Validator';

has 'params' => (
    is => 'rw',
    isa => 'HashRef',       
);

has '_map' => (
    is => 'rw',
    isa => 'HashRef',    
);

has 'workflow' => (
    is => 'rw',
    isa => 'Object',    
);


sub _init {
    my ( $self, $params ) = @_;

    # copy the source params
    my $params_merged = { % { $params }};

    # init the _map parameters
    my $_map = {};

    foreach my $key (keys %{$params}) {
        if ($key !~ /^_map_(.*)/) { next; }

        # Remove map key from the hash
        delete $params_merged->{$key};

        my $name = $1;
        my $val = $params->{$key};
        $_map->{$name} = $params->{$key};
        ##! 8: 'Found param ' . $name . ' - value : ' . $params->{$key}

    }

    $self->params( $params_merged );
    $self->_map( $_map );

    ##! 32: 'merged params ' . Dumper  $params_merged
    ##! 32: 'map ' . Dumper  $_map

    ##! 1: 'end'
    return 1;
}

sub param {

    my ( $self, $name ) = @_;

    unless ( defined $name ) {
        my $result = { %{ $self->params() } };

        # add mapped params
        my $map = $self->_map();
        foreach my $key (keys %{ $map }) {
            $result->{$key} = $self->param( $key );
        }
        return $result;
    }

    if ( exists $self->params()->{$name} ) {
        return $self->params()->{$name};
    } else {
        my $map = $self->_map();
        return undef unless ($map->{$name});
        ##! 16: 'query for mapped key ' . $name

        my $template = $map->{$name};
        # shortcut for single context value
        if ($template =~ /^\$(\S+)/) {
            my $ctxkey = $1;
            ##! 16: 'load from context ' . $ctxkey
            my $ctx = $self->workflow()->context()->param( $ctxkey );            
            if (OpenXPKI::Serialization::Simple::is_serialized($ctx)) {
                ##! 32: ' needs deserialize '
                my $ser  = OpenXPKI::Serialization::Simple->new();
                return $ser->deserialize( $ctx );
            } else {
                return $ctx;
            }
        } else {
            
            ##! 16: 'parse using tt ' . $template            
            my $oxtt = OpenXPKI::Template->new();
            my $out = $oxtt->render( $template, {  context => $self->workflow()->context()->param() } );
            
            ##! 32: 'tt result ' . $out
            return $out;
        }
    }
    return undef;
}

sub validate {

    ##! 1: 'start'
    
    my $self = shift;
    my $workflow = shift;
    my @args = @_;
    
    $self->workflow( $workflow );
    
    my @args_parsed = ( $workflow );
    
    # evaluate the arguments, $context escaping is already done by the 
    # workflow factory, now we look for TT strings and parse them.
    # Note that the string must start with the TT marker to be recognized
    
    my $oxtt = OpenXPKI::Template->new();
            
    foreach my $arg (@args) {
        if (ref $arg eq '' && $arg =~ m{ \A \s* \[%.+%\] }xsm) {
            ##! 16: 'Found template ' . $arg
            $arg = $oxtt->render( $arg, {  context => $workflow->context()->param() } );
            ##! 16: 'render result ' . $arg                        
        }
        push @args_parsed, $arg;               
    }
    
    $self->_validate( @args_parsed );

    return 1;

}

# Implement this (with the underscore) in your subclass
sub _validate {

    my $self = shift;
    OpenXPKI::Exception->throw({
        MESSAGE => 'I18N_OPENXPKI_SERVER_VALIDATOR_SUB_NOT_IMPLEMENTED',
        PARAMS => {
            'CLASS' => ref $self,
        }
    });

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Validator

=head1 SYNOPSIS
    
  my_validator
    class: OpenXPKI::Server::Workflow::Validator::MyValidatorClass
    param:      
      _map_path: [% context.key_in_context %] 
    arg: 
      - $cert_profile
      - $cert_subject_style
      - "[% context.other_key_in_context %]"

=head1 Description

A base clase for Validators, providing some magic for handling parameters
and arguments. 

=head2 Parameter Mapping

All parameters (instance configuration), can use the I<_map> syntax to 
resolve values from the context. @see OpenXPKI::Server::Workflow::Activity.

=head2 Argument Parsing

The Workflow base class already replaces arguments starting with a dollar 
sign by the approprate context values. In addition, argument values 
starting with a template toolkit sequence I<[%...> are parsed using 
OpenXPKI::Template with the full workflow context as parameters and the
given argument as template. 
 
=head1 Sub-Classing

To implement your own validator you need use Moose and inherit from this
class. Please implement your code in a method called I<_validate>, starting
with and underscore!  

      