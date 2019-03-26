package OpenXPKI::Service::LibSCEP;

use base qw( OpenXPKI::Service );

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

## used modules

use OpenXPKI::i18n qw(set_language);
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Session::Data::SCEP;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Service::LibSCEP::Command;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;

sub init {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    ##! 1: "start"

    # init memory-only session
    $self->__init_session();

    CTX('session')->data->pki_realm($self->__init_pki_realm);

    my $server = $self->__init_server;
    CTX('session')->data->server($server);
    CTX('session')->data->user($server);

    CTX('session')->data->enc_alg($self->__init_encryption_alg);
    CTX('session')->data->hash_alg($self->__init_hash_alg);

    return 1;
}

sub __init_server : PROTECTED {
    ##! 4: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;

    my $config = CTX('config');

    my $message = $self->collect();
    ##! 16: "message collected: " . Dumper($message)
    my $requested_server;
    if ( $message =~ /^SELECT_SERVER (.*)/ ) {
        $requested_server = $1;
        ##! 16: "requested server: $requested_server"
    }
    else {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_LIBSCEP_NO_SELECT_SERVER_RECEIVED",
        );

        # this is an uncaught exception
    }

    # Retrieve valid scep server configurations from the connector
    my @scep_config = $config->get_keys('scep');
    my %scep_config = map {$_ => 1} @scep_config;

    if ($scep_config{$requested_server})
    {
        # the server is valid
        $self->talk('OK');
        return $requested_server;
    }
    else {   # the requested profile was not found in the server configuration
        $self->talk('NOTFOUND');
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_LIBSCEP_INVALID_SERVER_REQUESTED",
            params  => { REQUESTED_SERVER => $requested_server },
        );
    }
}

sub __init_hash_alg : PROTECTED {
    ##! 4: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;

    my $message = $self->collect();
    ##! 16: "message collected: " . Dumper($message)
    my $requested_hash_alg;
    if ( $message =~ /^SELECT_HASH_ALGORITHM (.*)/ ) {
        $requested_hash_alg = lc($1);
        ##! 16: "requested encryption_alg: $requested_encryption_alg"
    }
    else {
        OpenXPKI::Exception->throw( message =>
                "I18N_OPENXPKI_SERVICE_LIBSCEP_NO_SELECT_HASH_ALGORITHM_RECEIVED",
        );

        # this is an uncaught exception
    }
    if (  $requested_hash_alg eq 'md5'
        || $requested_hash_alg =~ /sha(1|224|256|384|512)/ )
    {
        # the encryption_alg is valid
        $self->talk('OK');
        return $requested_hash_alg;
    }
    else {    # the requested encryption algorithm is invalid
        $self->talk('NOTFOUND');
        OpenXPKI::Exception->throw(
            message =>
                "I18N_OPENXPKI_SERVICE_LIBSCEP_INVALID_ALGORITHM_REQUESTED",
            params => { REQUESTED_ALGORITHM => $requested_hash_alg },
        );
    }
}

sub __init_encryption_alg : PROTECTED {
    ##! 4: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;

    my $message = $self->collect();
    ##! 16: "message collected: " . Dumper($message)
    my $requested_encryption_alg;
    if ( $message =~ /^SELECT_ENCRYPTION_ALGORITHM (.*)/ ) {
        $requested_encryption_alg = lc($1);
        ##! 16: "requested encryption_alg: $requested_encryption_alg"
    }
    else {
        OpenXPKI::Exception->throw( message =>
                "I18N_OPENXPKI_SERVICE_LIBSCEP_NO_SELECT_ENCRYPTION_ALGORITHM_RECEIVED",
        );

        # this is an uncaught exception
    }
    if ($requested_encryption_alg =~ m{ (?: des | 3des | des3 | aes128 | aes192 | aes256 | blowfish | cast ) }xms)
    {
    # LibSCEP uses OpenSSL cipher names, and they use des3 instead of 3des
    if ($requested_encryption_alg eq '3des') {
        $requested_encryption_alg = 'des3';
    }

        # the encryption_alg is valid
        $self->talk('OK');
        return $requested_encryption_alg;
    }
    else {    # the requested encryption algorithm is invalid
        $self->talk('NOTFOUND');
        OpenXPKI::Exception->throw(
            message =>
                "I18N_OPENXPKI_SERVICE_LIBSCEP_INVALID_ALGORITHM_REQUESTED",
            params => { REQUESTED_ALGORITHM => $requested_encryption_alg },
        );
    }

}

sub __init_session : PROTECTED {
    # memory-only session is sufficient for SCEP
    my $session = OpenXPKI::Server::Session->new(
        type => "Memory",
        data_class => "OpenXPKI::Server::Session::Data::SCEP",
    )->create;
    OpenXPKI::Server::Context::setcontext({ session => $session, force => 1 });
    Log::Log4perl::MDC->put('sid', substr(CTX('session')->id,0,4));
}

sub __init_pki_realm : PROTECTED {
    my $self  = shift;
    my $ident = ident $self;
    my $arg   = shift;

    ##! 1: "start"

    my $message = $self->collect();
    ##! 16: "message collected: $message"
    my $requested_realm;
    if ( $message =~ /^SELECT_PKI_REALM (.*)/ ) {
        $requested_realm = $1;
        ##! 16: "requested realm: $requested_realm"
    }
    else {
        OpenXPKI::Exception->throw( message =>
                "I18N_OPENXPKI_SERVICE_LIBSCEP_NO_SELECT_PKI_REALM_RECEIVED", );
    }

    if (defined CTX('config')->exists("system.realms.$requested_realm")) {
    #if ( defined $realms{$requested_realm}->{NAME} ) {    # the realm is valid
        $self->talk('OK');
        return $requested_realm;
    }
    else {    # the requested realm was not found in the server configuration
        $self->talk('NOTFOUND');
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_LIBSCEP_INVALID_REALM_REQUESTED",
            params  => { REQUESTED_REALM => $requested_realm },
        );
    }
}

sub run {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

MESSAGE:
    while (1) {
        my $data;
        eval {
            $data = $self->collect();
            ##! 16: "data collected: " . Dumper $data
        };
        if ( my $exc = OpenXPKI::Exception->caught() ) {
            if ( $exc->message()
                =~ m{I18N_OPENXPKI_TRANSPORT.*CLOSED_CONNECTION}xms )
            {
                # client closed socket
                last MESSAGE;
            }
            else {
                $exc->rethrow();
            }
        }
        elsif ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_SERVICE_LIBSCEP_RUN_READ_EXCEPTION",
                params  => { EVAL_ERROR => $EVAL_ERROR, }
            );
        }

        last MESSAGE unless defined $data;

        my $service_msg = $data->{SERVICE_MSG};
        if ( !defined $service_msg ) {
            $self->talk(
                $self->__get_error(
                    {   ERROR =>
                            'I18N_OPENXPKI_SERVICE_LIBSCEP_RUN_MISSING_SERVICE_MESSAGE',
                    }
                )
            );

            next MESSAGE;
        }

        ##! 4: "$service_msg"

        ##! 4: "check for logout"
        if ( $service_msg eq 'LOGOUT' ) {
            ##! 8: "logout received - killing session and connection"
            CTX('log')->system()->info('Terminating session');

            exit 0;
        }

        if ( $service_msg eq 'COMMAND' ) {
            if ( exists $data->{PARAMS}->{COMMAND} ) {
                my $received_command = $data->{PARAMS}->{COMMAND};
                my $received_params  = $data->{PARAMS}->{PARAMS};
                ##! 16: "COMMAND: $received_command  PARAMS: " . Dumper $received_params

                my $command;
                eval {
                    $command = $self->__get_command( $received_command, $received_params );
                };
                if ( my $exc = OpenXPKI::Exception->caught() ) {
                    if ($exc->message() =~ m{ INVALID_COMMAND }xms )
                    {
                        ##! 16: "Invalid command $data->{PARAMS}->{COMMAND}"
                        # fall-through intended
                    }
                    else {
                        $exc->rethrow();
                    }
                }
                elsif ($EVAL_ERROR) {
                    OpenXPKI::Exception->throw(
                        message =>
                            "I18N_OPENXPKI_SERVICE_LIBSCEP_RUN_COULD_NOT_INSTANTIATE_COMMAND",
                        params => { EVAL_ERROR => $EVAL_ERROR, }
                    );
                }

                if ( defined $command ) {
                    my $result;
                    eval {
                        CTX('dbi')->start_txn();
                        $result = $command->execute();
                        CTX('dbi')->commit();
                    };
                    if (my $eval_err = $EVAL_ERROR) {
                        # the datapool semaphore and the workflow make intermediate commits
                        # so the rollback only affects any uncompleted actions
                        CTX('dbi')->rollback();
                        CTX('log')->system()->error("Error executing SCEP command '$received_command': $eval_err");

                        ##! 16: "Exception caught during command execution"
                        ##! 16: "$eval_err"
                        $self->talk(
                            $self->__get_error(
                                {   ERROR =>
                                        'I18N_OPENXPKI_SERVICE_LIBSCEP_RUN_COMMAND_EXECUTION_FAILED',
                                    EXCEPTION => $eval_err,
                                }
                            )
                        );

                        next MESSAGE;
                    }
                    CTX('log')->system()->debug("Executed SCEP command '$received_command'");


                    # sanity checks on command reply
                    if ( !defined $result || ref $result ne 'HASH' ) {
                        $self->talk(
                            $self->__get_error(
                                {   ERROR =>
                                        "I18N_OPENXPKI_SERVICE_LIBSCEP_RUN_ILLEGAL_COMMAND_RETURN_VALUE",
                                }
                            )
                        );

                        next MESSAGE;
                    }

                    $self->talk($result);

                    next MESSAGE;
                }
            }

            $self->talk(
                $self->__get_error(
                    {   ERROR =>
                            "I18N_OPENXPKI_SERVICE_LIBSCEP_RUN_UNRECOGNIZED_COMMAND",
                    }
                )
            );

            next MESSAGE;
        }

        $self->talk(
            $self->__get_error(
                {   ERROR =>
                        "I18N_OPENXPKI_SERVICE_LIBSCEP_RUN_UNRECOGNIZED_SERVICE_MESSAGE",
                }
            )
        );
    }

    return 1;
}

sub __get_command {

    my $self = shift;
    my $ident = ident $self;
    my $command = shift;
    my $params = shift;

    return OpenXPKI::Service::LibSCEP::Command->new({
        COMMAND => $command,
        PARAMS  => $params,
    });

}

1;
__END__

=head1 Name

OpenXPKI::Service::LibSCEP - SCEP service implementation

=head1 Description

This is the Service implementation which is used by SCEP clients.
The protocol is simpler than in the Default implementation, as it
does not use user authentication and session handling.

=head1 Protocol Definition

The protocol starts with the client sending a "SELECT_PKI_REALM" message
indicating which PKI realm the clients wants to use. Depending on whether
this realm is available at the server or not, the server responds with
either "OK" or "NOTFOUND".

