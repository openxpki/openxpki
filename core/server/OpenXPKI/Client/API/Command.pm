package OpenXPKI::Client::API::Command;
use Moose;
use feature 'state';

# Core modules
use Scalar::Util qw( blessed );
use Data::Dumper;

# CPAN modules
use Feature::Compat::Try;
use Log::Log4perl qw(:easy);

# Project modules
use OpenXPKI::Client;
use OpenXPKI::Client::Simple;
use OpenXPKI::DTO::ValidationException;

=head1 NAME

OpenXPKI::Client::API::Command

=head1 SYNOPSIS

Base class for all implementations handled by C<OpenXPKI::Client::API>.

=cut

=head1 Attributes

=head2 log

A Log4perl logger instance to use as log target.

=cut

has log => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    default => sub { return Log::Log4perl->get_logger(); },
    lazy => 1,
);

=head1 Methods

=head2 _preprocess I<request object>

Validates the given request object against the field specification of
the class instance and will apply any default values or type conversions
to the input object.

It returns a C<OpenXPKI::DTO::ValidationException> object on validation
errors or just undef if anything went well.

=cut

sub _preprocess {

    my $self = shift;
    my $req = shift;

    # A List of objects implementing OpenXPKI::DTO::Field
    my $spec = $self->param_spec();
    my $input_last;
    try {
        foreach my $input (@$spec) {
            $input_last = $input;
            my $name = $input->name;
            DEBUG('Run input validation for ' . $name);
            # Read the expected key name and try to get the parameter from req
            my $val = $req->param( $name );
            # throws an exception if the value mismatches the type contraint
            if (defined $val) {
                # Empty input + hint flag = load choices
                if ($val eq '' && defined (my $hint = $input->hint())) {
                    my $choices_call = $hint || 'hint_'.$name;
                    DEBUG("Call $choices_call to get choices for $name");
                    my $choices = $self->$choices_call($req, $input);
                    TRACE(Dumper $choices);
                    return OpenXPKI::DTO::ValidationException->new( field => $input, reason => 'choice', choices => $choices )
                }
                $input->value($val);
            } elsif ($input->has_value($name)) {
                # write back a default value from the field spec into the request
                $req->params()->{$name} = $input->value();
            } elsif ($input->required) {
                return OpenXPKI::DTO::ValidationException->new( field => $input, reason => 'required' );
            }
            # Field is set if needed and field matches type contraint
        }
    } catch ($error) {
        # type constraint validation
        DEBUG(Dumper $input_last);
        if (blessed $error and $error->isa('Moose::Exception::ValidationFailed')) {
            return OpenXPKI::DTO::ValidationException->new( field => $input_last, reason => 'type' );
        }
        # something else went wrong
        $error->rethrow() if ref $error;
        die "$error";
    }
    return;
}

=head2 preprocess

This method calls C<_preprocess> and wraps errors into a "failed"
C<OpenXPKI::Client::API::Response> object (state code 400). It should
be overriden by the implementation class in case any additional
preprocessing is required.

The return value of any implementation must be undef if anything went
well or a OpenXPKI::Client::API::Response object with a state code set
to an unsuccessful value if anything goes wrong.

=cut

sub preprocess {

    my $self = shift;
    my $req = shift;

    my $res = $self->_preprocess($req);
    return unless $res;

    return OpenXPKI::Client::API::Response->new(
        state => 400,
        payload => $res
    );

}

=head2 client I<realm>

Constructs an OpenXPKI::Client object to talk to the given realm
on the backend system.

=cut

sub client {

    my $self = shift;
    my $realm = shift;
    state $client;

    return $client if ($client && $client->client->is_connected() && $client->realm eq $realm);

    DEBUG("Bootstrap client for realm $realm");
    $client = OpenXPKI::Client::Simple->new({
        config => { realm => $realm, socket => '/var/openxpki/openxpki.socket' },
        auth => { stack => '_System' },
    });
    return $client;
}

=head2 list_realm

Return the list of available realms by calling the backend.

=cut

sub list_realm {

    my $self = shift;
    state $client;
    $client = OpenXPKI::Client->new({
        SOCKETFILE => '/var/openxpki/openxpki.socket'
    });
    my $reply = $client->send_receive_service_msg('GET_REALM_LIST');
    DEBUG(Dumper $reply);
    return [ map { $_->{name} } @{$reply->{PARAMS}} ];

}


__PACKAGE__->meta()->make_immutable();

1;