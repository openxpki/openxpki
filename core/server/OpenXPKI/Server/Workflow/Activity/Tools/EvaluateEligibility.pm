package OpenXPKI::Server::Workflow::Activity::Tools::EvaluateEligibility;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use English;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Template;
use Workflow::Exception qw(configuration_error);

use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;

    my $context   = $workflow->context();
    my $config = CTX('config');

    my $target_key = $self->param('target_key') || 'eligibility_result';

    my @prefix;
    my $config_path = $self->param('config_path');
    # auto create from interface and server in context
    if ($config_path) {
        @prefix = split /\./, $config_path;
    } else {
        my $interface = $context->param('interface');
        my $server = $context->param('server');

        if (!$server || !$interface) {
            configuration_error('Neither config_path nor interface/server is set!');
        }
        @prefix = ( $interface, $server, 'eligible' );
        $config_path = join ".", @prefix;
    }


    # Reset the context
    $context->param( $target_key => undef );
    if ($self->param('raw_result')) {
        $context->param( $self->param('raw_result') => undef );
    }

    my $res = 0;

    # check if there are arguments
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
                    CTX('log')->application()->warn(sprintf("Eligibility check chrashed - do pause (%s) ", $EVAL_ERROR));

                    ##! 32: 'Doing pause'
                    $self->pause('I18N_OPENXPKI_UI_ELIGIBILITY_CHECK_UNEXPECTED_ERROR');
                }
            } else {
                $plain_result = $config->get( [ @prefix, 'value', @path ] );
            }

            ##! 32: 'result is ' . $plain_result

            CTX('log')->application()->debug("Eligibility check raw result " . (defined $plain_result ? $plain_result : 'undef') . ' using path ' . join('|', @path));


            # write the raw result if requested
            if ($self->param('raw_result')) {
                $context->param( $self->param('raw_result') => $plain_result );
            }


            if (!defined $plain_result) {
                $res = 0;

            # If a list of expected values is given, we check the return value
            } elsif ( $config->exists( [ @prefix, 'expect' ] ) ) {
                my @expect = $config->get_scalar_as_list( [ @prefix, 'expect' ] );

                ##! 32: 'Check against list of expected values'
                foreach my $valid (@expect) {
                    ##! 64: 'Probe ' .$valid
                    if ($plain_result eq $valid) {
                        $res = 1;
                        ##! 32: 'Match found' .$valid
                        last;
                    }
                }

                CTX('log')->application()->debug("Eligibility check for expected value " . ($res ? 'succeeded' : 'failed'));

            # Evaluate return value using regex
            } elsif ( $config->exists( [ @prefix, 'match' ] ) ) {

                my $regex = $config->get( [ @prefix, 'match', 'regex' ] );
                my $modifier = $config->get( [ @prefix, 'match', 'modifier' ] ) || '';

                $modifier =~ s/\s//g;
                if ($modifier =~ /[^alupimsx]/ ) {
                    configuration_error('Unexpected characters in modifier');
                }
                $modifier = "(?$modifier)" if ($modifier);
                $regex = qr/$modifier$regex/;

                $res = ($plain_result =~ $regex) ? 1 : 0;

                CTX('log')->application()->debug("Eligibility check using regex $regex " . ($res ? 'succeeded' : 'failed'));


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

        CTX('log')->application()->debug("Eligibility check without path - result " . (defined $plain_result ? $plain_result : undef));


    }

    $context->param( $target_key => $res );

    CTX('log')->application()->info("Eligibility check for " . $config_path . " " . ($res ? 'granted' : 'failed'));

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::EvaluateEligibility

=head1 Description

This activity can be used to check the eligibility of a request based
on information available in the workflow against a data source. It first
assembles a config path from the request context and fetches the value
from this location. Afterwards it can check the reveived value against
a whitelist of accepted values.

The result is always a boolean value (0 or 1) written into I<target_key>.

The activity is designed to run within "shared workflows" and reads the
data source configuration details from a config path. The default path
is I<$interface.$server.eligible> which can be changed by setting the
I<config_path> parameter.

=head2 Activity Configuration

=over

=item config_path

The path where to look up the data source config (see next section).

The default is equivalent to

  map_config_path: "[% context.interface %].[% context.server %].eligible"

=item target_key

The context key to store the evaluation result.
The default is I<eligibility_result>.

=item raw_result

The context key to store the raw result of the query, this is optional.

=item pause_on_error

Set this if you have connectors that might cause exceptions. You also
need to set a useful value for retry_count. Effective only in attribute
mode! (see also OpenXPKI::Server::Workflow::Activity). If not set,
connector errors will bubble up as exceptions to the workflow handler.

=back

=head2 Data Source Configuration

=head3 Dynamic using a Connector

Put this configutation into your server configuration:

    eligible:
      value@: connector:your.connector
        args:
         - "[% context.cert_subject %]"
         - "[% context.url_mac %]"
      expect:
        - Active
        - Build

The check will succeed, if the value returned be the connector has a
literal match in the given list.

If you do not specify an I<expected> list, the return value is mapped to
a boolean result by perl magic.

=head3 Compare result using a RegEx

Instead of a static I<expect> list, you can also define a regex to evaluate:

    eligible:
      value@: connector:your.connector
        args:
         - "[% context.cert_subject %]"
         - "[% context.url_mac %]"
      match:
        regex: (Active|Build)
        modifier: ''


=head3 Static

In cases where you just need a static value, independant from the actual
request content, leave out the arguments section and use a literal value:

    eligible:
      value: 1

B<Sidenote>: You can use a connector here as well, but in static mode we
always test for a literal "1" as return value!
