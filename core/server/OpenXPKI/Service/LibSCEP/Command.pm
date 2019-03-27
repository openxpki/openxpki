use strict;
use warnings;

package OpenXPKI::Service::LibSCEP::Command;
use English;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;

my %command        : ATTR;
my %command_params : ATTR( :get<PARAMS> );

my %command_impl   : ATTR;
my %api            : ATTR( :get<API> );


# command registry
my %allowed_command = map { $_ => 1 } qw(
    GetCACert
    GetCACaps
    GetNextCACert
    PKIOperation
);

sub BUILD {
    my ($self, $ident, $arg_ref) = @_;
    ##! 1: "BUILD"
    ##! 2: ref $self

    $command{$ident}        = $arg_ref->{COMMAND};
    $command_params{$ident} = $arg_ref->{PARAMS};
    $api{$ident}            = OpenXPKI::Server::API->new();
    ##! 16: $command{$ident}
}

sub START {
    my ($self, $ident, $arg_ref) = @_;
    ##! 1: "START"
    ##! 2: ref $self
    # only in Command.pm base class: get implementation
    if (ref $self eq 'OpenXPKI::Service::LibSCEP::Command') {
        ##! 4: Dumper $arg_ref
        $self->attach_impl($arg_ref);
    }
}



sub attach_impl : PROTECTED {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;

    ##! 4: "attaching implementation"

    # command name
    my $cmd = $command{$ident};
    ##! 4: "command: $cmd"
    ##! 4: Dumper $arg

    # commands starting with an underscore are not allowed (might be a
    # private method in command implementation)
    if ($cmd =~ m{ \A _ }xms) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PROTECTED_METHOD_REQUESTED",
            params  => {
            COMMAND => $cmd,
        });
    }

    if (defined $cmd && $allowed_command{$cmd}) {
        # command was white-listed and explicitly allowed

        my $base = 'OpenXPKI::Service::LibSCEP::Command';
        # all commands except PKIOperation are consolideated in the LibSCEP
        # branch even when we run openca-tools
        if ($cmd eq 'PKIOperation') {
           $base = ref $self
        };

        my $class = $base . '::' . $cmd;
        ##! 8: "loading class $class"
        eval "use $class;";
        if ($EVAL_ERROR) { # no module available that implements the command
            ##! 8: "eval error $EVAL_ERROR"
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_NO_COMMAND_IMPL",
                params => { EVAL_ERROR => $EVAL_ERROR }
            );
        } else {
            ##! 8: "instantiating class $class"
            $command_impl{$ident} = eval "$class->new(\$arg)";

            if ($EVAL_ERROR) {
                OpenXPKI::Exception->throw(
                    message => "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_IMPL_INSTANTIATE_FAILED",
                    params  => {EVAL_ERROR => $EVAL_ERROR,
                    MODULE     => $class
                });
            }
        }
    } else {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_INVALID_COMMAND",
        );
    }

    return 1;
}


sub execute {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;

    ##! 4: "execute: $command{$ident}"

    if (! defined $command_impl{$ident}) {
        my $method = $command{$ident};
        ##! 8: "automatic API mapping for $method"

        return $self->command_response(
            $self->get_API()->$method($command_params{$ident}),
            $method, # explicitly provide command name to returned structure
        );
    } else {
        ##! 16: "ref child: " . ref $command_impl{$ident}
        my $cmd = $command{$ident};
        if ((ref $command_impl{$ident}) =~ qr/::$cmd\z/) {
            ##! 16: "implementation is present, delegating"
            return $command_impl{$ident}->execute({
                PARAMS => $command_params{$ident},
            });
        }
    }

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_INVALID_COMMAND",
        params  => {
            COMMAND => $command{$ident},
    });

    return;
}


# convenience method to be called by command implementation
sub command_response {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;
    my $command_name = shift; # optional

    # autodetect command name (only works if called from a dedicated
    # command implementation, not via automatic API call mapping)
    if (! defined $command_name) {
        my ($package, $filename, $line, $subroutine, $hasargs,
            $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(0);

        # only leave the last part of the package name
        ($command_name) = ($package =~ m{ ([^:]+) \z }xms);
    }

    return {
        SERVICE_MSG => 'COMMAND',
        COMMAND => $command_name,
        PARAMS  => $arg,
    };
}



sub __get_token_alias {

    my $self = shift;

    my $server = CTX('session')->data->server;
    my $token = CTX('config')->get(['scep', $server, 'token']);

    my $scep_token_alias;
    if ($token) {
        # Special token group requested
        $scep_token_alias = CTX('api2')->get_token_alias_by_group( 'group' => $token );
        CTX('log')->application()->debug("SCEP command requested special token ($token -> $scep_token_alias)");

    } else {
        # Use the default token group
        $scep_token_alias = CTX('api2')->get_token_alias_by_type( type => 'scep' );
    }

    return $scep_token_alias;
}


sub __get_token {

    my $self = shift;

    my $scep_token = CTX('crypto_layer')->get_token( { TYPE => 'scep', NAME => $self->__get_token_alias() } );

    if ( !defined $scep_token ) {
        OpenXPKI::Exception->throw(
            message => 'Unable to create SCEP token',
            params => { ALIAS => $self->token_alias() }
        );
    }

    return $scep_token;
}


sub get_next_ca_certificate {

    my $self = shift;

    my $pki_realm = CTX('session')->data->pki_realm;

    # Cache record is identifier by server name only
    my $cache_id = CTX('session')->data->server;

    my $cached_certs = CTX('api2')->get_data_pool_entry(
        namespace => 'scep.cache.getnextca',
        key => $cache_id,
    );
    if ($cached_certs && $cached_certs->{value}) {
        ##! 16: "Cache id $cache_id found"
        CTX('log')->application()->trace("SCEP GetNextCACert served from datapool $cache_id");
        return $cached_certs->{value};
    }

    my $next_ca = CTX('dbi')->select_one(
        from_join => "certificate identifier=identifier aliases",
        columns => [
            'certificate.data',
        ],
        where => {
            'aliases.pki_realm' => $pki_realm,
            'aliases.group_id' => 'root',
            'aliases.notbefore' => { '>', time() },
        },
        order_by => [ 'aliases.notbefore' ],
    );

    if (not $next_ca) {
        ##! 16: 'No cert found'
        CTX('log')->application()->debug("SCEP GetNextCACert nothing found (realm $pki_realm).");
        return;
    }

    ##! 16: 'Found nextca cert ' .  $next_ca->{alias}

    return $next_ca->{data};

}


1;
__END__

=head1 Name

OpenXPKI::Service::LibSCEP::Command

=head1 Description

SCEP service command base class. Handles command execution to
distinct command implementations.

=head1 Functions

=head2 START - new()

This class derives from Class::Std. Please read the corresponding
documentation concerning BUILD, START construction methods and other
class-specific internals.

The new() constructor creates a new command object that is capable
of executing the referenced interface command.
Expects the following named parameters:
  COMMAND => name of the command to execute
  PARAMS  => hash reference containing the command attributes

The constructor makes sure that only explicitly allowed commands are
accepted and throws an exception otherwise. If the constructor returns
without error (exception), the command was accepted as valid and the
passed parameters have been stored internally to be processed later
by the execute() method.

When attaching the implementation the class tries to 'use'
an actual Perl module which is named like the command. E. g.
if command 'foo' is requested, it tries to attach
OpenXPKI::Service::LibSCEP::Command::foo.pm.

=head2 execute

Executes the specified command implementation. Returns a data structure
that can be serialized and directly returned to the client.

=head2 command_response

Returns a properly formatted command response (hash reference containing
the proper arguments). To be called by command implementations.

=head2 __get_token

Return the scep token (crypto object), active group token if set in the
servers configuration or the default token.

=head2 __get_token_alias

get the scep token alias for the current server

=head2 get_next_ca_certificate

Return next ca certificate(s) as (concatenated) PEM encoded certificates.

Default is to fetch the certificate with a notbefore date greater than now
from the I<root> alias group of the current realm.

You can override this by creating a datapool item with namespace
I<scep.cache.getnextca> and the servername as key. The value must be a
single PEM encoded certificate or a string with multiple PEM blocks.
B<Note>: Multiple certificates are only supported using LibSCEP, the old
SCEP backend takes the first one and ignores the remainder.

Returns undef if no upcoming ca certificate is found.
