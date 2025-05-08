package OpenXPKI::Server::API2::Plugin::UI::get_menu;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::get_menu

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;



=head1 COMMANDS

=head2 get_menu

Returns the UI menu and page definitions (I<HashRef>) for the current role (or
for pseudo role I<_default> if there is no configuration for the current role).

Upgrades elements with the old syntax I<key> to I<page> and removes any items
linked to a workflow that is not available for the given role.

=cut
command "get_menu" => {
} => sub {
    my ($self, $params) = @_;

    my $role = CTX('session')->data->role;
    $role = '_default' unless CTX('config')->exists( ['uicontrol', $role ] );

    # we silently assume that the config layer node can return a deep hash ;)
    my $menu = CTX('config')->get_hash( [ 'uicontrol', $role ], { deep => 1 });
    return unless $menu;

    # check type of 'main' entry
    my $ref = ref $menu->{main};
    if ($menu->{main} and $ref ne 'ARRAY') {
        my $realm = CTX('session')->data->pki_realm;
        OpenXPKI::Exception->throw(
            message => "Error: $realm.uicontrol.'$role'.main has wrong type. Expected: ARRAY ref, got: " . ($ref ? "$ref ref" : ($menu->{main} ? 'scalar' : 'undef')),
        );
    }

    my $wf_factory = CTX('workflow_factory')->get_factory;
    my $make_item = sub {
        my $elem = shift;
        # auto migrate to new keyword (v3.32+)
        ($elem->{page} = $elem->{key} && delete $elem->{key}) if (defined $elem->{key});

        # check if this is a workflow item
        my ($wf_type) = $elem->{page} =~ m{\Aworkflow!.+!wf_type!(\w+)};

        # check acl for workflows, just return if wf_type is not set
        return (!$wf_type || $wf_factory->can_create_workflow($wf_type)) ?
            $elem : ();
    };

    my @menu = map {
        $_->{entries} = [ map { $make_item->($_); } $_->{entries}->@* ] if ($_->{entries});
        $make_item->($_);
    } $menu->{main}->@*;

    return $menu;
};

__PACKAGE__->meta->make_immutable;
