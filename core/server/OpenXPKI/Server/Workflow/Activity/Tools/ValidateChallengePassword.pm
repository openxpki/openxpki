package OpenXPKI::Server::Workflow::Activity::Tools::ValidateChallengePassword;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;

    my $context   = $workflow->context();
    my $config = CTX('config');

    my $challenge_password = $self->param('challenge_password') || '';

    my $target_key = $self->param('target_key') || 'challenge_password_valid';

    if (!defined $challenge_password || $challenge_password eq '') {
        CTX('log')->application()->warn("challenge password is empty");
        $context->param( $target_key => undef );
        return 1;
    }

    my @prefix = @{$self->_get_service_config_path('challenge')};

    # Reset the context
    $context->param( $target_key => undef );
    if ($self->param('raw_result')) {
        $context->param( $self->param('raw_result') => undef );
    }


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

    CTX('log')->application()->debug("challenge validation path " . join("|", @path));


    my $res;
    # bind mode passes the plain password as additional argument
    if ($mode eq 'bind') {

        my $bind = $config->get( [ @prefix, 'value', @path ], { 'password' => $challenge_password } );
        ##! 32: 'bind result is ' . $bind
        # Evaluate whatever comes back to a boolean 0/1 -
        # check if its scalar as path building errors might make it always true
        $res =  ((ref $bind eq '') && $bind) ? 1 : 0;

        CTX('log')->application()->info("validate challenge using bind " . ($res ? "validated" : "validation FAILED!"));


    } else {

        # for the moment we use plain text passwords only
        my $password = $config->get( [ @prefix, 'value', @path ] ) ;
        ##! 32: 'expected challenge is ' . $password
        $res = ($password eq $challenge_password ? 1 : 0);
        CTX('log')->application()->info("validate challenge using compare " . ($res ? "validated" : "validation FAILED!"));

    }

    $context->param( $target_key => $res);

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ValidateChallengePassword

=head1 Description

Check the validity of the challenge password.

The activity is designed to run within "shared workflows" and reads the
data source configuration details from a config path. The default path
is I<$interface.$server.challenge> which can be changed by setting the
I<config_path> parameter.

The result of the validation is written to the context key identified by
target_key. The result is a literal 0 or 1 if the the check failed / was
successful. If the given password is empty or undefined, the target key
is deleted/not set.

=head2 Activity Configuration

=over

=item challenge_password

The actual value of the password to check.

=item config_path

The path where to look up the data source config (see next section).

The default is equivalent to

  map_config_path: "[% context.interface %].[% context.server %].challenge"

=item target_key

The context key to store the evaluation result.
The default is I<challenge_password_valid>.

=item mode

Set the validation mode, one of "bind" or "literal" (default).

=back

=head2 Validation Mode

=head3 bind

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

=head3 literal

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


