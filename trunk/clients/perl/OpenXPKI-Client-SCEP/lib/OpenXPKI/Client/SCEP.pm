# OpenXPKI::Client::SCEP
# Written 2006 by Alexander Klink for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project

package OpenXPKI::Client::SCEP;

use base qw( OpenXPKI::Client );
use OpenXPKI::Server::Context qw( CTX );

use Data::Dumper;

{
    use warnings;
    use strict;
    use Carp;
    use English;

    use Class::Std;

    use OpenXPKI::i18n qw( i18nGettext );
    use OpenXPKI::Debug 'OpenXPKI::Client::SCEP';
    use OpenXPKI::Exception;

    my %operation_of :ATTR( :init_arg<OPERATION> ); # SCEP operation
    my %message_of   :ATTR( :init_arg<MESSAGE>   ); # SCEP message
    my %realm_of     :ATTR( :init_arg<REALM>     ); # PKI realm to use
    my %profile_of   :ATTR( :init_arg<PROFILE>   ); # endentity profile to use
    my %server_of    :ATTR( :init_arg<SERVER>    ); # server to use
    my %enc_alg_of   :ATTR( :init_arg<ENCRYPTION_ALGORITHM> ); 

    my %allowed_op = map { $_ => 1 } qw(
        GetCACaps
        GetCACert
        GetNextCACert
        GetCACertChain

        PKIOperation
    );

    sub START {
        my ($self, $ident, $arg_ref) = @_;
        
        # send configured realm, collect response
        ##! 4: "before talk"
        $self->talk('SELECT_PKI_REALM ' . $realm_of{$ident});
        my $message = $self->collect();
        if ($message eq 'NOTFOUND') {
            die("The configured realm (" . $realm_of{$ident} . ") was not found"
                . " on the server");
        }
        $self->talk('SELECT_PROFILE ' . $profile_of{$ident});
        $message = $self->collect();
        if ($message eq 'NOTFOUND') {
            die("The configured profile (" . $profile_of{$ident} . ") was not found on the server");
        }
        $self->talk('SELECT_SERVER ' . $server_of{$ident});
        $message = $self->collect();
        if ($message eq 'NOTFOUND') {
            die('The configured server (' . $server_of{$ident} . ') was not found on the server');
        }
        $self->talk('SELECT_ENCRYPTION_ALGORITHM ' . $enc_alg_of{$ident});
        $message = $self->collect();
        if ($message eq 'NOTFOUND') {
            die('The configured encryption algorithm (' . $enc_alg_of{$ident} 
                . ') was not found on the server');
        }
    }

    sub send_request {
        my $self = shift;
        my $ident = ident $self;
        my $op = $operation_of{$ident};
        my $message = $message_of{$ident};

        if ($allowed_op{$op}) {
            # send command message to server
            $self->send_command_msg(
                $op,
                {
                  MESSAGE => $message,
                }
            );
        }
        else { # OP is invalid, throw corresponding exception
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_CLIENT_SCEP_INVALID_OP",
            );
        }
        # get resulting command message from server
        my $server_result = $self->collect();
        return $server_result->{PARAMS};
    }
}
1; # Magic true value required at end of module
__END__

=head1 NAME

OpenXPKI::Client::SCEP - OpenXPKI Simple Certificate Enrollment Protocol Client


=head1 VERSION

This document describes OpenXPKI::Client::SCEP version $VERSION


=head1 SYNOPSIS

    use OpenXPKI::Client::SCEP;
    use CGI;

    my $query     = CGI->new();
    my $operation = $query->param('operation');
    my $message   = $query->param('message');
    
    my $scep_client = OpenXPKI::Client::SCEP->new(
        {
        SERVICE    => 'SCEP',
        REALM      => $realm,
        SOCKETFILE => $socket,
        TIMEOUT    => 120, # TODO - make configurable?
        PROFILE    => $profile, 
        OPERATION  => $operation,
        MESSAGE    => $message,
        SERVER     => $server,
        ENCRYPTION_ALGORITHM => $enc_alg,
        });
    my $result = $scep_client->send_request();

=head1 DESCRIPTION

OpenXPKI::Client::SCEP acts as a client that sends an SCEP request
to the OpenXPKI server. It is typically called from within a CGI
script that acts as the SCEP server.

=head1 INTERFACE 

=head2 START

Constructor, see Class::Std.

Expects the following named parameters:

=over

=item REALM

PKI Realm to access (must match server configuration).

=item OPERATION

SCEP operation to send. For allowed operations, see the %allowed_op
hash.

=item MESSAGE

SCEP message to send.

=back

=head2 send_request

Sends SCEP request to OpenXPKI server.
