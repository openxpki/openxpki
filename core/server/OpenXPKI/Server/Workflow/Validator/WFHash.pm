package OpenXPKI::Server::Workflow::Validator::WFHash;

use strict;

use Moose;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;

use Workflow::Exception qw( configuration_error validation_error );

use Data::Dumper;

extends 'OpenXPKI::Server::Workflow::Validator';

sub _validate {
    my ( $self, $wf, $key ) = @_;


    validation_error('No key given') unless($key);  

    my $hash_name = $self->param('hash_name');

    configuration_error('No hash_name set') unless ($hash_name);

    my $hash = $wf->context()->param ( $hash_name );
    $hash = OpenXPKI::Serialization::Simple->new()->deserialize( $hash );

    validation_error('Hash to check does not exist or is not a hash' )if(!$hash || (ref $hash ne 'HASH'));

    ##! 8: 'Checking Key ' . $key
    ##! 16: 'Hash is ' . Dumper $hash

    if (!defined $hash->{$key}) {
        my $msg = $self->param('error') || (sprintf 'Key %s not defined in hash %s', $key, $hash_name);
        CTX('log')->application()->error($msg);
        validation_error($msg);
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::WFHash

=head1 SYNOPSIS

  validate_reason_code:
    class: OpenXPKI::Server::Workflow::Validator::WFHash
    param:
       hash_name: hash_to_check 

  arg:
    - $key_to_check


=head1 DESCRIPTION
