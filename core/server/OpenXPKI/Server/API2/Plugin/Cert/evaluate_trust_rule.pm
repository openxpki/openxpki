package OpenXPKI::Server::API2::Plugin::Cert::evaluate_trust_rule;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::evaluate_trust_rule

=cut

use Data::Dumper;
# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

=head1 COMMANDS

=head2 evaluate_trust_rule

=cut

command "evaluate_trust_rule" => {
    signer_subject  => { isa => 'Str', required => 1 },
    signer_identifier => { isa => 'Str', required => 1 },
    signer_realm    => { isa => 'Str', required => 1 },
    signer_profile  => { isa => 'Str' },
    signer_issuer   => { isa => 'Str' }, # identifier
    signer_root     => { isa => 'Str' }, # identifier
    rule            => { isa => 'HashRef', required => 1 },
} => sub {
    my ($self, $params) = @_;

    my $trustrule =  $params->rule;
    my $matched = 0;
    my $meta;

    ##! 32: $trustrule
    ##! 64: $params
    foreach my $key (keys %{$trustrule}) {
        my $match = $trustrule->{$key};
        ##! 64: 'expected match ' . $key . '/' . $match
        if ($key eq 'subject') {
            $matched = ($params->signer_subject =~ /^$match$/i);

        } elsif ($key eq 'identifier') {
            $matched = ($params->signer_identifier eq $match);

        } elsif ($key eq 'realm') {
            # if issuer_alias is used the realm check is done on the alias
            $matched = ($trustrule->{issuer_alias}) ? 1 :
                ($params->signer_realm eq $match || $match eq '_any');

        } elsif ($key eq 'profile') {

            # if signer profile was not passed we load it from the database
            my $signer_profile = $params->signer_profile ||
                CTX('api2')->get_profile_for_cert( identifier => $params->signer_identifier );
            $matched = ($signer_profile eq $match);

        } elsif ($key eq 'issuer_alias' || $key eq 'root_alias') {

            my $identifier = ($key eq 'issuer_alias') ? $params->signer_issuer : $params->signer_root;

            # identifier was not passed so we can not check it - abort rule
            return unless($identifier);

            my $alias = CTX('dbi')->select_one(
                from    => 'aliases',
                columns => [ 'alias' ],
                where   => {
                    group_id => $match,
                    identifier => $identifier,
                    notbefore => { '<' => time },
                    notafter  => { '>' => time },
                    pki_realm => [ $trustrule->{realm}, '_global' ],
                },
            );
            ##! 64: "Result for $key ($identifier) in $match: " . ($alias->{alias} || 'no result')
            $matched = (defined $alias->{alias});

        } elsif ($key =~ m{meta_}) {
            # reset the matched state!
            $matched = 0;
            if (!defined $meta->{$key}) {
                my $attr = CTX('api2')->get_cert_attributes(
                    identifier => $params->signer_identifier,
                    attribute => $key,
                    tenant => ''
                );
                $meta->{$key} = $attr->{$key} || [];
                ##! 64: 'Loaded attr ' . Dumper $meta->{$key}
            }
            foreach my $aa (@{$meta->{$key}}) {
                ##! 64: "Attr $aa"
                next unless ($aa eq $match);
                $matched = 1;
                last;
            }

        } else {
            CTX('log')->system()->error("Trusted Signer Authorization unknown ruleset $key/$match");
            $matched = 0;
        }
        return unless($matched);

        CTX('log')->application()->debug("Trusted Signer Authorization matched subrule $match");

        ##! 32: 'Matched ' . $match
    }
    return $matched;
};

__PACKAGE__->meta->make_immutable;
