package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::MergeEntry;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

# CPAN modules
use DateTime;
use Template;
use Workflow::Exception qw( workflow_error configuration_error );

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DateTime;


sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $params = { deserialize => 'simple' };
    # check for mandatory fields
    foreach my $key (qw( namespace key value )) {
        my $val =  $self->param($key);
        configuration_error('Mandatory parameter missing or empty: '.$key) unless (defined $val);
        $params->{ $key } = $val;
    }

    if ($self->param('pki_realm')) {
        if ($self->param('pki_realm') eq '_global') {
            $params->{pki_realm} = '_global';
        } elsif($self->param('pki_realm') ne CTX('session')->data->pki_realm) {
            workflow_error( 'Access to foreign realm is not allowed' );
        }
    }

    my $entry = CTX('api2')->get_data_pool_entry(%$params);
    if (!$entry) {
        workflow_error('Datapool Entry to merge with does not exist');
    }
    ##! 64: $entry

    # Existing data type must match incoming value
    if (ref $entry->{ value } eq 'ARRAY') {
        if (ref $params->{ value } eq 'ARRAY') {
            CTX('log')->application->info('Merge Datapool Entry in array mode');
            push @{$entry->{ value }}, @{$params->{ value }};
        } elsif (ref $params->{ value } eq '') {
            CTX('log')->application->info('Merge Datapool Entry in append mode');
            push @{$entry->{ value }}, $params->{ value };
        } else {
            workflow_error('Incoming value must be of type array or scalar to merge with existing array');
        }
    } elsif (ref $entry->{ value } eq 'HASH') {
        workflow_error('Incoming value must be of type hash to merge with existing hash')
            unless(ref $params->{ value } eq 'HASH');

        CTX('log')->application->info('Merge Datapool Entry in hash mode');
        my %in = %{$params->{ value }};
        map {
            defined $in{$_} ?
                $entry->{ value }->{$_} = $in{$_} :
                delete $entry->{ value }->{$_};
        } keys %in;

    } else {
        workflow_error('Datapool Entry is of unsupported type');
    }

    ##! 64: $entry

    try {
        $entry->{serialize} = 'simple';
        $entry->{force} = 1;
        ##! 32: 'Params ' . Dumper $params
        CTX('api2')->set_data_pool_entry(%$entry);
    }
    catch ($err) {
        workflow_error($err);
    }

    CTX('log')->application->info('Merge datapool entry: key = '.$params->{key}.', namespace = '.$params->{namespace});

    return 1;
}

1;
__END__

=head1 NAME

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::MergeEntry

=head1 DESCRIPTION

Merges incoming data into into an array existing in the datapool.

If the datapool value is an array ref, the incoming value must be
either an array ref or a single scalar. Both are appended to the end
of the existing list. No sorting or deduplication is done.

If the existing value is a hash ref, the incoming data must be a
hash ref, too. The merge of both is done as "shallow merge" on the
first level of keys. Items with a value of "undef" will be removed.

The expiration_date as well as the encryption status is carried over
from the original item.

=head1 CONFIGURATION

=head2 Parameters

Mandatory parameters are I<namespace>, I<key> and I<value>. You can
override the default realm by setting I<pki_realm>.

See the documentation of th SetEntry activity for details.