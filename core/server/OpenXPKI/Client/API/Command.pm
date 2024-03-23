package OpenXPKI::Client::API::Command;

use Moose;
with 'OpenXPKI::Role::Logger';

use feature 'state';

# Core modules
use Scalar::Util qw( blessed );
use Crypt::PK::ECC;
use Data::Dumper;

# CPAN modules
use Feature::Compat::Try;

# Project modules
use OpenXPKI::Client;
use OpenXPKI::Client::CLI;
use OpenXPKI::Client::Simple;
use OpenXPKI::DTO::ValidationException;
use OpenXPKI::DTO::Message::Command;
use OpenXPKI::DTO::Message::ProtectedCommand;

=head1 NAME

OpenXPKI::Client::API::Command

=head1 SYNOPSIS

Base class for all implementations handled by C<OpenXPKI::Client::API>.

=head1 Attributes

=cut

has api => (
    is => 'ro',
    isa => 'OpenXPKI::Client::API',
    required => 1,
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
            $self->log->debug('Run input validation for ' . $name);
            # Read the expected key name and try to get the parameter from req
            my $val = $req->param( $name );
            # throws an exception if the value mismatches the type contraint
            if (defined $val) {
                # Empty input + hint flag = load choices
                if ($val eq '' && (my $choices_call = $input->hint())) {
                    $self->log->debug("Call $choices_call to get choices for $name");
                    my $choices = $self->$choices_call($req, $input);
                    $self->log->trace(Dumper $choices) if $self->log->is_trace;
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
        $self->log->trace(Dumper $input_last) if $self->log->is_trace;
        if (blessed $error) {
            if ($error->isa('Moose::Exception::ValidationFailed')
                || $error->isa('Moose::Exception::ValidationFailedForTypeConstraint')) {
                return OpenXPKI::DTO::ValidationException->new( field => $input_last, reason => 'type' );
            }

            if ($error->can('rethrow')) {
                $error->rethrow();
            }
        }
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

=head2 is_protected

Return true if the command is marked as a protected command

=cut

sub is_protected {
    return shift->DOES('OpenXPKI::Client::API::Command::Protected');
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
    $self->log->trace(Dumper $reply) if $self->log->is_trace;
    return [ map { $_->{name} } @{$reply->{PARAMS}} ];

}

sub _build_hash_from_payload {

    my $self = shift;
    my $req = shift;
    return {} unless ($req->payload());

    my %params;
    foreach my $arg (@{$req->payload()}) {
        my ($key, $val) = split('=', $arg, 2);
        if ($params{$key}) {
            if (!ref $params{$key}) {
                $params{$key} = [$params{$key}, $val];
            } else {
                push @{$params{$key}}, $val;
            }
        } else {
            $params{$key} = $val;
        }
    }
    return \%params;

}


__PACKAGE__->meta()->make_immutable();

1;