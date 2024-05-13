package OpenXPKI::Server::API2::Plugin::Token::handle_alias;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::handle_alias

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;

=head1 COMMANDS

=head2 create_alias

Add an entry to the aliases table.

Minimal example:

    CTX('api2')->create_alias(
        alias_group => 'ca-signer',
        identifier => 'NTJi6a7rDCEjMTDWc7dop4cz05E',
    );

The default is to use the next generation in the given group.
The notbefore/notafter values are copied from the certificate unless
given, expected format is epoch, values must be inside the validity
interval of the certificate.

B<Parameters>

=over

=item * C<identifier> I<Str> - the certificate identifier to create the alias for

=item * C<alias_group> I<Str> - the name of the alias group

=item * C<generation> I<Int> - the generation for the alias

=item * C<global> I<Bool> - weather to create the alias globally

=item * C<notbefore> I<Int> - override the certificates notbefore date

=item * C<notafter> I<Int> - override the certificates notafter date

=back

=cut

protected_command "create_alias" => {
    identifier  => { isa => 'Base64', required => 1, },
    alias_group => { isa => 'AlphaPunct', required => 1, },
    generation  => { isa => 'Int', default => 0, },
    global      => { isa => 'Bool', default => 0 },
    notbefore   => { isa => 'Int', },
    notafter    => { isa => 'Int', },
} => sub {

    my ($self, $params) = @_;

    my $pki_realm = $params->global ? '_global' : CTX('session')->data->pki_realm;


    my $dbi = CTX('dbi');

    # query certificate table to check whether identifer actually exists
    my $certificate = $dbi->select_one(
        from    => 'certificate',
        columns => [ 'notbefore', 'notafter', 'status' ],
        where => { identifier => $params->identifier },
    );

    OpenXPKI::Exception->throw(
        message => 'cerificate identifier to add alias for does not exist',
        params => { identifier => $params->identifier }
    ) unless($certificate);

    my $notbefore = $certificate->{notbefore};
    if ($params->has_notbefore) {
        OpenXPKI::Exception->throw(
            message => 'given notbefore date must not be less than certificates notbefore date'
        ) if ($params->notbefore < $notbefore);
        $notbefore = $params->notbefore;
    }
    my $notafter =  $certificate->{notafter};
    if ($params->has_notafter) {
        OpenXPKI::Exception::Command->throw(
            message => 'given notafter date must not be more than certificates notafter date'
        ) if ($params->notafter > $notafter);
        $notafter = $params->notafter;
    }

    my $group = $params->alias_group;
    my $generation = $params->generation;
    if ($generation) {
        my $exists = $dbi->select_one(
            from   => 'aliases',
            columns => ['identifier'],
            where => {
                pki_realm => $pki_realm,
                group_id => $group,
                generation => $generation
            },
        );
        OpenXPKI::Exception::Command->throw(
            message => 'given alias already exists',
            params => {
                identifer => $exists->{identifer},
                alias_group => $group,
                generation => $generation
            }
        ) if ($exists);
    } else {
        # query aliases to get next generation id
        my $res_nextgen = $dbi->select_one(
            from   => 'aliases',
            columns => ['generation'],
            where => {
                pki_realm => $pki_realm,
                group_id => $group,
            },
            order_by => '-generation',
        );
        $generation = ($res_nextgen->{generation} || 0) + 1;
    }

    my $identifier_exists = $dbi->select_one(
        from   => 'aliases',
        columns => ['alias'],
        where => {
            pki_realm => $pki_realm,
            group_id => $group,
            identifier => $params->identifier,
        }
    );

    OpenXPKI::Exception::Command->throw(
        message => 'given identifier already exists in group',
        params => {
            alias => $identifier_exists->{alias},
            alias_group => $group,
            identifier => $params->identifier,
        }
    ) if ($identifier_exists);

    my $alias = sprintf "%s-%01d", $group, $generation;
    $dbi->insert(
        into => 'aliases',
        values  => {
            identifier => $params->identifier,
            group_id => $group,
            alias => $alias,
            generation => $generation,
            pki_realm => $pki_realm,
            notbefore => $notbefore,
            notafter => $notafter,
        }
    );
    return { alias => $alias };
};


=head2 delete_alias

Remove an entry from the alias table

Minimal example:

    CTX('api2')->delete_alias(
        alias => 'ca-signer-1',
    );

Will return a HashRef representing the alias entry that was removed
or an empty hash if the alias was not found in the database.

B<Parameters>

=over

=item * C<alias> I<Str> - the name of the alias to remove

=item * C<global> I<Bool> - weather to delete a globally defined alias

=back

=cut

protected_command "delete_alias" => {
    alias => { isa => 'AlphaPunct', required => 1, },
    global      => { isa => 'Bool', default => 0 },
} => sub {

    my ($self, $params) = @_;

    my $pki_realm = $params->global ? '_global' : CTX('session')->data->pki_realm;

    my $dbi = CTX('dbi');
    my $alias = $dbi->select_one(
        from   => 'aliases',
        columns => ['*'],
        where => {
            alias => $params->alias,
            pki_realm => $pki_realm,
        }
    );

    return {} unless ($alias);

    $dbi->delete(
        from => 'aliases',
        where => {
            alias => $params->alias,
            pki_realm => $pki_realm,
        }
    );

    return $alias;

};


=head2 update_alias

Update validity columns of an entry in the alias table

Minimal example:

    CTX('api2')->delete_alias(
        alias => 'ca-signer-1',
        notbefore => 0,
    );

Date values must be epoch, passing a value of I<0> will reset the
date to the certificates validity date.

Will return a HashRef representing the alias entry after updating it.
Throws an exception if the alias is not found.

B<Parameters>

=over

=item * C<alias> I<Str> - the name of the alias to remove

=item * C<global> I<Bool> - weather to delete a globally defined alias

=item * C<notbefore> I<Int> - override the certificates notbefore date

=item * C<notafter> I<Int> - override the certificates notafter date

=back

=cut

protected_command "update_alias" => {
    alias => { isa => 'AlphaPunct', required => 1, },
    global      => { isa => 'Bool', default => 0 },
    notbefore   => { isa => 'Int', },
    notafter    => { isa => 'Int', },
} => sub {

    my ($self, $params) = @_;

    my $pki_realm = $params->global ? '_global' : CTX('session')->data->pki_realm;

    my $dbi = CTX('dbi');
    my $alias = $dbi->select_one(
        from   => 'aliases',
        columns => ['*'],
        where => {
            alias => $params->alias,
            pki_realm => $pki_realm,
        }
    );

    OpenXPKI::Exception::Command->throw(
        message => 'Alias to update not found in database',
    ) unless ($alias);


    my $certificate = CTX('api2')->get_cert(
        identifier => $alias->{identifier}, format => "DBINFO"
    );


    my $update;
    # set notbefore date?
    if (!$params->has_notbefore) {
        # noop

    # reset to certificate validity
    } elsif ($params->notbefore eq "0") {
        $update->{notbefore} = $certificate->{notbefore};

    } elsif ($params->notbefore < $certificate->{notbefore}) {
        OpenXPKI::Exception::Command->throw(
            message => 'given notbefore date must not be less than certificates notbefore date'
        );
    } else {
        $update->{notbefore} = $params->notbefore;
    }

    # same for notafter
    if (!$params->has_notafter) {
        # noop

    # reset to certificate validity
    } elsif ($params->notafter == "0") {
        $update->{notafter} = $certificate->{notafter};

    # set to given date
    } elsif ($params->notafter > $certificate->{notafter}) {
        OpenXPKI::Exception::Command->throw(
            message => 'given notafter date must not be more than certificates notafter date'
        );
    } else {
        $update->{notafter} = $params->notafter;
    }

    OpenXPKI::Exception::Command->throw(
        message => 'No attributes set for update'
    ) unless (keys %{$update});

    $dbi->update(
        table => 'aliases',
        set => $update,
        where => {
            alias => $params->alias,
            pki_realm => $pki_realm,
        }
    );

    return { %$alias, %$update };

};

=head2 show_alias

Show an item from the alias table

Minimal example:

    CTX('api2')->show_alias(
        alias => 'ca-signer-1',
    );

Will return a HashRef representing the alias entry or an empty hash
if the alias is not known.

B<Parameters>

=over

=item * C<alias> I<Str> - the name of the alias to remove

=item * C<global> I<Bool> - weather to show a globally defined alias

=back

=cut

command "show_alias" => {
    alias => { isa => 'AlphaPunct', required => 1, documentation => 'the name of the alias to remove' },
    global      => { isa => 'Bool', default => 0, documentation => 'weather to show a globally defined alias' },
} => sub {

    my ($self, $params) = @_;

    my $pki_realm = $params->global ? '_global' : CTX('session')->data->pki_realm;

    my $alias = CTX('dbi')->select_one(
        from   => 'aliases',
        columns => ['*'],
        where => {
            alias =>  $params->alias,
            pki_realm => $pki_realm || '_global',
        },
        limit => 1,
    );

    return $alias || {};

};

__PACKAGE__->meta->make_immutable;
