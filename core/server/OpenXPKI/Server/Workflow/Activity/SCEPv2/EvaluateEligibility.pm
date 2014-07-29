# OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility;

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

        my $tt = Template->new();
        my @path;
        my $param =  { context => $context->param() };
        foreach my $item (@attrib) {
            my $out;
            if (!$tt->process(\$item, $param , \$out)) {
                OpenXPKI::Exception->throw({
                    MESSAGE => 'I18N_OPENXPKI_SERVER_ACTIVITY_EVALUATE_ELIGIBILITY_ERROR_PARSING_TEMPLATE',
                    PARAMS => {
                        'TEMPLATE' => $item,
                        'ERROR' => $tt->error()
                    }
                });
            }
            push @path, $out if ($out);
        }

        ##! 16: 'Lookup at path ' . Dumper @path
        if (@path) {
            my $plain_result = $config->get( [ @prefix, 'value', @path ] ) ;
            ##! 32: 'result is ' . $plain_result
            # Evaluate whatever comes back to a boolean 0/1 f
            $res = $plain_result ? 1 : 0;

            CTX('log')->log(
                MESSAGE => "SCEP eligibility check raw result " . $plain_result . ' using path ' . join('|', @path),
                PRIORITY => 'debug',
                FACILITY => 'application',
            );
        }
    } else {
    # No attribs, static case
      my $plain_result = $config->get( [ @prefix, 'value' ] ) ;
      ##! 32: 'static check - result is ' . Dumper $plain_result
      # check the ref and explicit return to make sure it was not a stupid config
      $res = (ref $plain_result eq '' && $plain_result eq '1');

      CTX('log')->log(
        MESSAGE => "SCEP eligibility check without path - result " . $plain_result,
        PRIORITY => 'debug',
        FACILITY => 'application',
      );

    }

    $context->param($flag => $res );

    CTX('log')->log(
        MESSAGE => "SCEP eligibility for " .
            ($is_initial ? 'initial enrollment ' : 'renewal ' ) .
            ($res ? 'granted' : 'failed'),
        PRIORITY => 'info',
        FACILITY => ['audit','application'],
    );

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

Renewal is disabled as the path is empty.

=head2 Configuration alternatives

To globally enable a feature without taking the request into account, omit the
args and set value to a literal 1:

  scep-server-1:
    eligible:
      initial:
        value: 1

      renewal:
        value: 1

