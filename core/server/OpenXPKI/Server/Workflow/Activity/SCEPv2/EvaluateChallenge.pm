# OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateChallenge
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateChallenge;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;

    my $context   = $workflow->context();
    my $server = $context->param( 'server' );
    my $config = CTX('config');

    my $challenge_password = $context->param('_challenge_password');

    ##! 64: 'checking existance: ' . $challenge_password
    if (!$challenge_password) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SCEP_EVALUATE_CHALLENGE_UNDEFINED',
        );
    }

    my @prefix = ( 'scep', $server, 'challenge' );

    # Test mode
    my $mode =  $config->get( [ @prefix, 'mode' ] ) || '';

    my @attrib = $config->get_scalar_as_list( [ @prefix, 'args' ] );
    my $tt = Template->new();
    my @path;
    my $param =  { context => $context->param() };
    foreach my $item (@attrib) {
        my $out;
        if (!$tt->process(\$item, $param, \$out)) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SCEP_EVALUATE_CHALLENGE_ERROR_PARSING_TEMPLATE',
                params => {
                    'TEMPLATE' => $item,
                    'ERROR' => $tt->error()
                }
            );
        }
        push @path, $out if ($out);
    }

    CTX('log')->application()->debug("SCEP validation path " . join("|", @path));


    my $res;
    # bind mode passes the plain password as additional argument
    if ($mode eq 'bind') {

        my $bind = $config->get( [ @prefix, 'value', @path ], { 'password' => $challenge_password } );
        ##! 32: 'bind result is ' . $bind
        # Evaluate whatever comes back to a boolean 0/1 -
        # check if its scalar as path building errors might make it always true
        $res =  ((ref $bind eq '') && $bind) ? 1 : 0;

        CTX('log')->application()->info("SCEP Challenge using bind " . ($res ? "validated" : "validation FAILED!"));


    } else {

        # for the moment we use plain text passwords only
        my $password = $config->get( [ @prefix, 'value', @path ] ) ;
        ##! 32: 'expected challenge is ' . $password
        $res = ($password eq $challenge_password ? 1 : 0);
        CTX('log')->application()->info("SCEP Challenge using compare " . ($res ? "validated" : "validation FAILED!"));

    }

    $context->param('valid_chall_pass' => $res);

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateChallenge

=head1 Description

Check the validity of the challenge password. Obtains the configuration
from the scep server config, runs in two modes.

=head2 bind

If you want to check the password against without revealing information about
it, use I<mode: bind>.

  challenge:
    mode: bind
    value@: connector:scep.connectors.challenge
      args:
      - "[% context.cert_subject %]"

This will call the given connector with the cert_subject as path argument,
the password is passed as parameter using the key "password", therefore you
need to use a a special connector that can consume this extra section.
The return value is evaluated in boolean context.

=head2 comparison

Fetch the password from the given source and compare it against the given
challenge. Supports only plain text password yet. Example for a mac address
based challenge source (mac is passed using the url param feature).

  challenge:
    value@: connector:scep.connectors.challenge
      args:
      - "[% context.url_mac %]"


This will use the value returned from the connector at
I<scep.connectors.challenge.00:11:22:33:44:55>.

If you have a static password for all requests, use:

  challenge:
    value: mypassword


