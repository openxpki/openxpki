package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetEntry;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Workflow::Exception qw(configuration_error workflow_error);

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $target_key;
    my $default_value;

    my $params = {
        namespace => $self->param('namespace'),
        key => $self->param('key'),
    };

    if (!$params->{namespace}) {
        configuration_error('Datapool::GetEntry requires the namespace parameter');
    }
    if (!$params->{key}) {
        configuration_error('Datapool::GetEntry requires the key parameter');
    }

    $target_key = $self->param('target_key') || '_tmp';

    $default_value = $self->param('default_value');

    if ($self->param('pki_realm')) {
        if ($self->param('pki_realm') eq '_global') {
            $params->{pki_realm} = '_global';
        } elsif($self->param('pki_realm') ne CTX('session')->data->pki_realm) {
            workflow_error( 'Access to foreign realm is not allowed' );
        }
    }

    ##! 16: ' Fetch from datapool ' . Dumper $params

    my $retval;
    my $msg = CTX('api2')->get_data_pool_entry(%$params);

    ##! 32: ' Result from datapool ' . Dumper $msg

    if ($msg) {
        # Prevent export of encrypted data to persisted context items
        if ($msg->{encrypted} && ($target_key !~ /^_/)) {
            workflow_error( 'persisting encrypted data is not allowed' );
        }
        $retval = $msg->{value};
    } elsif (defined $default_value) {
        ##! 16: 'No result - using default value'
        $retval = $default_value;
    }

    ##! 1: 'returned from get_data_pool_entry(): ' . $retval
    $context->param({ $target_key => $retval });

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetEntry

=head1 Description

Retrieve an entry from the Datapool.

=head1 Configuration

=head2 Parameters

In the activity definition, the following parameters must be set.

=over 8

=item namespace

The namespace to use for storing the key-value pair. Generally speaking,
there are no rigid naming conventions. The namespace I<sys>, however,
is reserved for internal server and system related data.

=item key

The value used as datapool key, use I<_map> syntax to use values from context!

=item target_key

The context target key to write the result to, the default is I<_tmp>.

B<Note:> If the retrieved value was encrypted in the datapool, the
target parameter must start with an underscore (=volatile parameter).

=item pki_realm

The realm of the datapool item to load, default is the current realm.

B<Note:> For security reasons it is not allowed to load items from other
realms except from special I<system> realms. The only system realm
defined for now is I<_global> which is available from all other realms.

=back


