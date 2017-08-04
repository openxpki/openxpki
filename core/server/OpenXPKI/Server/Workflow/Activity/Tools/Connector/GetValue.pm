# OpenXPKI::Server::Workflow::Activity::Tools::Connector::GetValue
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Connector::GetValue;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Template;
use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $mode = $self->param('mode') || 'scalar';

    # simple mode, path is a single string
    my $path = $self->param('config_path');

    # for handling complex keys, split path into prefix, suffix and key

    my $path_prefix = $self->param('config_prefix') || '';
    my $path_key = $self->param('config_key') || '';
    my $path_suffix = $self->param('config_suffix') || '';

    my $delimiter = $self->param('delimiter') || '\.';

    if ($delimiter eq '.') { $delimiter = '\.'; }

    my @path;

    if ($path) {

        @path = split $delimiter, $path;

    } elsif($path_key) {

        if ($path_prefix) {
            @path = split $delimiter, $path_prefix;
        }

        push @path, $path_key;

        if ($path_suffix) {
            push @path, (split $delimiter, $path_suffix);
        }

    } else {
        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CONNECTOR_GET_VALUE_NO_PATH'
        );
    }

    CTX('log')->application()->debug("Calling Connector::GetValue in mode $mode with path " . join('|', @path));


    my $config = CTX('config');
    if ($mode eq 'map') {

        my $hash = $config->get_hash( \@path );
        my $map = $self->param('attrmap');

        ##! 16: 'Result from connector ' . Dumper $hash

        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CONNECTOR_GET_VALUE_NO_MAP'
        ) unless ($map);

        my %attrmap;
        if (ref $map eq 'HASH') {
            %attrmap = %{$map};
        } else {
            %attrmap = map { split(/\s*[=-]>\s*/) } split( /\s*,\s*/, $map );
        }
        foreach my $key (keys %attrmap) {
            ##! 32: 'Add item key: ' . $key .' - Value: ' . $attrmap{$key};
            $context->param( $key, $hash->{$attrmap{$key}});
        }

    } elsif ($mode eq 'hash') {

        my $hash = $config->get_hash( \@path );
        foreach my $key (keys %{$hash}) {
            if ($key =~ /^(wf_|workflow_|creator|_)/) { next; }
            ##! 32: 'Add item key: ' . $key .' - Value: ' . $attrmap{$key};
            $context->param( $key, $hash->{$key});
        }

    } elsif ($mode eq 'array') {

        ##! : 16 'Array mode'
        my @retarray = $config->get_list( \@path );
        my $retval = OpenXPKI::Serialization::Simple->new()->serialize( \@retarray );

        my $target_key = $self->param('target_key');

        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CONNECTOR_GET_VALUE_NO_TARGET_KEY'
        ) unless ($target_key);

        $context->param( $target_key, $retval );

    } elsif ($mode eq 'scalar') {

        my $target_key = $self->param('target_key');
        my $retval = $config->get( \@path );

        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CONNECTOR_GET_VALUE_VALUE_NOT_A_SCALAR'
        ) if (ref $retval);

        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CONNECTOR_GET_VALUE_NO_TARGET_KEY'
        ) unless ($target_key);

        # Fall back to default
        if ( not defined $retval ) {
            $retval = $self->param('default_value');
        }

        $context->param( $target_key, $retval );

    } else {
        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CONNECTOR_GET_VALUE_UNKNOWN_MODE'
        );
    }

    return 1;

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Connector::GetValue

=head1 Description

This activity reads a (set of) values from the config connector into the
context.

=head1 Configuration

=head2 Activity parameters

=over

=item mode (default: scalar)

* scalar: return a single value, requires target_key
* array:  return a single item which is a list, requires target_key
* map: map multiple values from the result using a map, requires attrmap
* hash: import the full result of the get_hash call, see note below!

=item delimiter (default: dot)

The delimiter to split the path string, used in regex context!

=item config_path

The path to the config item as string, split up at delimiter.
If set, config_key, config_prefix, config_suffix are B<not> used.

=item config_key

A single value to use as key when building the path using config_prefix
and/or config_suffix. Use if your key might contain the delimiter character.

=item config_prefix, config_suffix

String to be used around config_key to build the full path, see config_path.

=item attrmap

Mandatory in mode = map, defines the mapping rules in the format:

    context_name1 => connector_name1, context_name2 => connector_name2

=item target_key

The name of the context parameter to which the result should be written.
Mandatory when mode is array or scalar.

=item default_value

The default value to be returned if the connector did not return a result.
Only used with mode = scalar

=back

=head1 Examples

=head2 scalar mode, simple path

    class: OpenXPKI::Server::Workflow::Activity::Tools::Connector::GetValue
    param:
        _map_config_path: smartcard.policy.certs.type.[% context.cert_type %].escrow_key
        target_key: flag_need_escrow


=head2 hash map mode with path assembly

Creator usually contains the delimiter char, so we must use path assembly
(otherwise the username is split into path elements).

    class: OpenXPKI::Server::Workflow::Activity::Tools::Connector::GetValue
    param:
        mode: map
        config_prefix: smartcard.users.by_mail
        _map_config_key: "[% context.creator %]"
        attrmap: auth2_mail -> mail, auth2_cn -> cn


=head2 array mode with path assembly

    class: OpenXPKI::Server::Workflow::Activity::Tools::Connector::GetValue
    param:
        mode: array
        config_prefix: smartcard.policy.certs.type
        _map_config_key: "[% context.cert_type %]"
        config_suffix: allowed_profiles
        target_key: buid_profiles
