# OpenXPKI::Server::Context (Singleton)
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005-2006 by The OpenXPKI Project

package OpenXPKI::Server::Context;

use strict;
use base qw( Exporter );

use Storable qw(dclone);

use OpenXPKI::Debug;
use Data::Dumper;

our @EXPORT_OK = qw( CTX );

#use Smart::Comments;

use OpenXPKI::Exception;

my $context = {
    initialized => 0,

    exported => {
        # always created by this package
        config           => undef,
        workflow_factory => undef,
        crypto_layer     => undef,
        pki_realm        => undef,
        pki_realm_by_cfg => undef,
        volatile_vault   => undef,
        log              => undef,
        dbi              => undef,
        dbi_log          => undef,

        # user-settable
        api            => undef,
        server         => undef,
        acl            => undef,
        session        => undef,
        authentication => undef,
        notification   => undef,
        workflow_id    => undef,
    },
};

our %who_forked_me;

# only called statically
sub CTX {
    my @objects = @_;

    # not needed as we would get an exception if the requested object is not
    # defined anyway. Removed as it affects the new auto mock objects for testing
    if (0) {
    if (! $context->{initialized}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONTEXT_CTX_NOT_INITIALIZED",
            params => { 'objects' => join ":", @objects },
            log => undef, # do not log exception
        );
    }}

    # TODO: add access control? (idea: limit access to this method to
    # authorized parts of the code only, explicity excluding interface
    # implementations...)

    my @return;
    foreach my $object (@objects) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONTEXT_CTX_OBJECT_NOT_FOUND",
            params  => {OBJECT => $object},
            log => undef, # do not log exception message
        ) unless exists $context->{exported}->{$object};

        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONTEXT_CTX_OBJECT_NOT_DEFINED",
            params  => {OBJECT => $object},
            log => undef, # do not log exception message
        ) unless defined $context->{exported}->{$object};

        push @return, $context->{exported}->{$object};
    }

    return @return if wantarray;
    return $return[0] if scalar @return;
    return;
}

# you cannot initialize the stored objects in the context
# itself because the modules uses the context too. If you
# try it then a use statement tries to check for CTX before
# all required modules for the Context module are loaded.
# The export will be performed after all required module
# are loaded.
#
# Example:
#
# context depends on init and init on dbi
# dbi uses CTX
#
# Result Context loaded
#        --> init must be loaded
#        --> dbi must be loaded
#        --> requires presence of CTX
#        --> CTX present after context can be executed
#        --> error CTX is no exported
#
# some people call this a deadlock

# add new entries to the context
sub setcontext {
    ##! 1: 'start'
    my $params = shift;

    my $force = delete($params->{'force'});
    ##! 16: 'force: ' . $force

    if (not $context->{initialized}) {
       $context->{initialized} = 1;
    }

    foreach my $key (keys %{$params}) {
    ### setting $key in context...
    if (! exists $context->{exported}->{$key} ) {
        ### unknown key...
        OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_CONTEXT_SETCONTEXT_ILLEGAL_ENTRY",
                params  => {NAME => $key},
            );
    }

    ### already defined?
    if (defined ($context->{exported}->{$key}) && (! $force)) {
        ### yes, bail out
        OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_CONTEXT_SETCONTEXT_ALREADY_DEFINED",
                params  => {NAME => $key},
            );
    }

    ##! 128: 'trying to set value for key: ' . $key
    ##! 128: 'value: ' . Dumper $params->{$key}
    if (! defined $params->{$key}) {
        OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_CONTEXT_SETCONTEXT_UNDEFINED_VALUE",
                params  => {NAME => $key},
            );
    }

    ### setting internal state...
    $context->{exported}->{$key} = $params->{$key};
    }

    return 1;
}

sub hascontext {
    my $key = shift;
    return defined ($context->{exported}->{$key});
}

sub killsession {
    $context->{exported}->{session} = undef;
    return 1;
}

1;
__END__

=head1 Name

 OpenXPKI::Server::Context (Singleton)

=head1 Description

This package provices a globally accessible Context singleton that holds
object references for the OpenXPKI base infrastructure.
Typically the package is included in every module that needs to access
basic functions such as logging or database operations.

During startup of the system this Context package must be initialized
once by passing in the configuration file (see create()).
After initialization has completed the package holds a global context
that can be accessed from anywhere within the OpenXPKI code structure.

Callers typically use the CTX() function to access this context. See
below for usage hints.

=head2 Basic objects (always available)

The following Context objects are always created and can be retrieved
by calling CTX('...') once create() has been called:

=over

=item * xml_config

=item * crypto_layer

=item * pki_realm

=item * volatile_vault

=item * log

=item * dbi

=back

=head2 Auxiliary objects (only available after explicit addition)

In addition to the above objects that are guaranteed to exist after
initialization has happened, the following can be retrieved if they
have been explicitly added to the Context after initialization
via setcontext().

=over

=item *    api

=item * server

=back

These objects are usually created and attached by the OpenXPKI Server
initialization procedure in order to make the objects available globally.


=head1 Functions

=head2 CTX($)

Allows to retrieve an object reference for the specified name.
If called before initialization has happened (see create() function)
calling CTX() yields an exception.
CTX() returns the associated object in the global context.

Usage:

  use OpenXPKI::Server::Context;
  my $config = OpenXPKI::Server::Context::CTX('xml_config');

or simpler:

  use OpenXPKI::Server::Context qw( CTX );
  my $config = CTX('xml_config');

=head2 CTX(@)

It is also possible to call CTX() in array context to obtain multiple
context entries at once:

  my ($config, $log, $dbi) = CTX('xml_config', 'log', 'dbi');


=head2 setcontext(%)

Allows to set additional globally available Context information after
the Context has been initialized via create().

To prevent abuse (storing arbitrary stuff globally) the Context module
only allows to set Context entries that are allowed explicitly.
Only the keys mentioned above are accepted, trying to set an unsupported
Context object yields an exception.

Please note that it is NOT possible to overwrite a Context object
once it has been set once. setcontext() will throw an exception if
somebody tries to set an object that has already been attached.

Usage:

  # attach this server object and the API to the global context
  OpenXPKI::Server::Context::setcontext({
    server => $self,
    api    => OpenXPKI::Server::API->new(),
  });

=head2 hascontext

Check if the requested entry is available from the context.

=head2 killsession

Delete the recorded session from the context. Used during server startup
where we start with a mock session and need a real one later.
