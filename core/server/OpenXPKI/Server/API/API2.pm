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
use Data::Dumper;

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
    $self->_translate_validity_parameters($args);
    my $result = CTX('api2')->search_cert(%$args);
    my $result_legacy = [ map { OpenXPKI::Server::Database::Legacy->certificate_to_legacy($_) } @$result ];
    return $result_legacy;
}

=head2 search_cert_count

=cut
sub search_cert_count {
    my ($self, $args) = @_;
    $args = $self->_clean_args($args);
    $self->_translate_validity_parameters($args);
    CTX('api2')->search_cert_count(%$args);
}

sub _clean_args {
    my ($self, $args) = @_;
    my $cleaned_args = { map { lc($_) => $args->{$_} } keys %$args };
    ($cleaned_args->{order} = lc $cleaned_args->{order}) =~ s/ ^ certificate\. //msxi if $cleaned_args->{order};
    return $cleaned_args;
}

sub _translate_validity_parameters {
    my ($self, $args) = @_;

    # VALID_AT
    if ($args->{valid_at}) {
        $args->{valid_before}  = $args->{valid_at} + 1;
        $args->{expires_after} = $args->{valid_at} - 1;
        delete $args->{valid_at};
    }

    # NOTAFTER and NOTBEFORE
    my $convert_legacy = sub {
        my ($condition, $lt_param, $gt_param) = @_;
        # Check required hash keys
        for my $attr (qw( OPERATOR VALUE )) {
            OpenXPKI::Exception->throw(
                message => "Legacy DB condition has unknown syntax: missing hash key '$attr'",
                params  => { CONDITION => Dumper($condition) },
            ) unless $condition->{$attr};
        }
        my $op  = $condition->{OPERATOR};
        my $val = $condition->{VALUE};

        # Convert
        if ('GREATER_THAN' eq $op) { return { $gt_param => $val }; }
        elsif ('LESS_THAN' eq $op) { return { $lt_param => $val }; }
        elsif ('BETWEEN' eq $op) {
            if (ref $val ne 'ARRAY' or scalar @{$val} != 2) {
                OpenXPKI::Exception->throw(
                    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_WRONG_PARAM_FOR_BETWEEN",
                    params  => { VALUE => Dumper($val) }
                );
            }
            return { $gt_param => $val->[0]-1, $lt_param => $val->[1]+1 };
        }
        else {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_UNKNOWN_OPERATOR",
                params  => { CONDITION => Dumper($condition) }
            );
        }
    };

    if ($args->{notbefore}) {
        my $nb = $args->{notbefore}; delete $args->{notbefore};
        if (ref $nb eq 'HASH') {
            my $params = $convert_legacy->($nb, 'valid_before', 'valid_after');
            $args->{$_} = $params->{$_} for keys %{ $params };
        }
        else {
            $args->{valid_before} = $nb;
        }
    }

    if ($args->{notafter}) {
        my $na = $args->{notafter}; delete $args->{notafter};
        if (ref $na eq 'HASH') {
            my $params = $convert_legacy->($na, 'expires_before', 'expires_after');
            $args->{$_} = $params->{$_} for keys %{ $params };
        }
        else {
            $args->{expires_after} = $na;
        }
    }
}

1;
