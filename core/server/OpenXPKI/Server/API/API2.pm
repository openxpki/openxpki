package OpenXPKI::Server::API::API2;
use strict;
use warnings;
use utf8;

=head1 NAME

OpenXPKI::Server::API::API2 - Wrapper that redirects calls to the new API2

=head1 METHODS

=cut

# CPAN modules
use Class::Std;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Database::Legacy;



sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw( message =>
          'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED', );
}

=head2 search_cert

=cut
sub search_cert {
    my ($self, $args) = @_;
    $args = $self->_clean_args($args);
    my $result = CTX('api2')->search_cert(%$args);
    my $result_legacy = [ map { OpenXPKI::Server::Database::Legacy->certificate_to_legacy($_) } @$result ];
    return $result_legacy;
}

=head2 search_cert_count

=cut
sub search_cert_count {
    my ($self, $args) = @_;
    $args = $self->_clean_args($args);
    CTX('api2')->search_cert_count(%$args);
}

sub _clean_args {
    my ($self, $args) = @_;
    my $cleaned_args = { map { lc($_) => $args->{$_} } keys %$args };
    ($cleaned_args->{order} = lc $cleaned_args->{order}) =~ s/ ^ certificate\. //msxi if $cleaned_args->{order};
    return $cleaned_args;
}

1;
