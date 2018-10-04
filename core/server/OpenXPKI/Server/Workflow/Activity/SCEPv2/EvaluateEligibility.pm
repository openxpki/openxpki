# OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use English;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Template;
use Data::Dumper;
use Workflow::Exception qw(configuration_error);

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;

    my $context   = $workflow->context();
    my $config = CTX('config');

    # To make support a bit easier, we write the operation mode
    # verbosely to the context (its in there already!)

    my $is_initial = (!( $context->param( 'signer_trusted' ) && $context->param('signer_sn_matches_csr' )));

    $context->param( 'request_mode' => ( $is_initial ? 'initial' : 'renewal' ) );

    ##! 16: 'request_mode ' . $context->param( 'request_mode' )

    # just check the connector for the current mode

    my $server = $context->param('server');

    $context->param('eligible_for_initial_enroll' => 0);
    $context->param('eligible_for_renewal' => 0);

    my ($flag, @prefix, $res);

    if ($is_initial) {
        @prefix = ( 'scep', $server, 'eligible','initial' );
        $flag = 'eligible_for_initial_enroll';
    } else {
        @prefix = ( 'scep', $server, 'eligible','renewal' );
        $flag = 'eligible_for_renewal';
    }

    my @attrib = $config->get_scalar_as_list( [ @prefix, 'args' ] );

    ##! 32: 'Attribs ' . Dumper @attrib
    # dynamic case - context is used in evaluation
    if (defined $attrib[0]) {

        my $tt = OpenXPKI::Template->new();
        my @path;
        my $param =  { context => $context->param() };
        foreach my $item (@attrib) {
            my $out = $tt->render($item, $param);
            push @path, $out if ($out);
        }

        ##! 16: 'Lookup at path ' . Dumper @path
        if (@path) {

            my $plain_result;
            if ($self->param('pause_on_error')) {

                if (!$self->param('retry_count')) {
                    configuration_error('pause_on_error also requires a non-zero retry_count to be set');
                }

                # run connector in eval to catch error
                eval {
                    $plain_result = $config->get( [ @prefix, 'value', @path ] );
                };
                if ($EVAL_ERROR) {
                    CTX('log')->application()->warn("SCEP eligibility check chrashed - do pause");

                    ##! 32: 'Doing pause'
                    $self->pause('I18N_OPENXPKI_UI_ELIGIBILITY_CHECK_UNEXPECTED_ERROR');
                }
            } else {
                $plain_result = $config->get( [ @prefix, 'value', @path ] );
            }
            ##! 32: 'result is ' . $plain_result

            CTX('log')->application()->debug("SCEP eligibility check raw result " . $plain_result . ' using path ' . join('|', @path));


            $context->param( 'eligibility_result' => $plain_result );

            # If a list of expected values is given, we check the return value
            my @expect= $config->get_scalar_as_list( [ @prefix, 'expect' ] );
            if (defined $plain_result && defined $expect[0]) {

                ##! 32: 'Check against list of expected values'
                foreach my $valid (@expect) {
                    ##! 64: 'Probe ' .$valid
                    if ($plain_result eq $valid) {
                        $res = 1;
                        ##! 32: 'Match found' .$valid
                        last;
                    }
                }

                CTX('log')->application()->debug("SCEP eligibility check for expected value " . ($res ? 'succeeded' : 'failed'));


            } else {
                # Evaluate whatever comes back to a boolean 0/1 f
                $res = $plain_result ? 1 : 0;
            }
        }

    } else {
        # No attribs, static case
        my $plain_result = $config->get( [ @prefix, 'value' ] );
        ##! 32: 'static check - result is ' . Dumper $plain_result
        # check the ref and explicit return to make sure it was not a stupid config
        $res = (ref $plain_result eq '' && $plain_result eq '1');

        CTX('log')->application()->debug("SCEP eligibility check without path - result " . $plain_result);


    }

    $context->param( $flag => $res );

    CTX('log')->application()->info("SCEP eligibility for " .
            ($is_initial ? 'initial enrollment ' : 'renewal ' ) .
            ($res ? 'granted' : 'failed'));

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility

=head1 Description

Check the eligability to perform initial enrollment or renewal against the
connector. The activity detects if we are in initial or renewal mode and
writes the decission to "request_mode".

=head1 Configuration

=head2 Activity Configuration

=over

=item pause_on_error

Set this if you have connectors that might cause exceptions. You also
need to set a useful value for retry_count. Effective only in attribute
mode! (see also OpenXPKI::Server::Workflow::Activity). If not set,
connector errors will bubble up as exceptions to the workflow handler.

=back

=head2 Data Source Configuration

=head3 Dynamic using a Connector

The data source must be configured in the config of the running scep
server:

  scep-server-1:
    eligible:
      initial:
        value@: connector:your.connector
        args:
         - "[% context.cert_subject %]"
         - "[% context.url_mac %]"

      renewal: ''

For inital enrollment, the given connector is queried using the requested
subject and mac address (gathered by url parameter), e.g.:

   your.connector.cn=foo,dc=bar.00:01:02:34:56:78

If the connector returns a true value, the enrollment is granted.
Renewal is disabled as the path is empty.

=head3 Dynamic with a return-value whitelist

If you need to make the decission based on the return value, you can add
a list of expected values to the definition:

    initial:
      value@: connector:your.connector
      args:
        - "[% context.cert_subject %]"
        - "[% context.url_mac %]"
      expected:
        - Active
        - Build

The check will succeed, if the value returned be the connector has a literal
match in the given list.

=head3 Static

To globally enable a feature without taking the request into account, omit the
args and set value to a literal 1:

  scep-server-1:
    eligible:
      initial:
        value: 1

      renewal:
        value: 1

Sidenote: You can use a connector here as well, but in static mode we always
test for a literal "1" as return value!
