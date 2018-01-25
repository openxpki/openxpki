package OpenXPKI::Server::API2::Plugin::Profile::get_field_definition;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::get_field_definition

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Profile::Util;

=head2 get_field_definition

Get the definition of input fields for a given profile/style.

B<Parameters>

=over

=item * C<profile> I<Str> - certificate profile name, required

=item * C<fields> I<ArrayRef> - list of field names to query, default: all fields
of the given style

=item * C<style> I<Bool> - profile style to query, required if C<fields> is not specified

=item * C<section> I<Str> - ui section (only used if C<style> was specified), default: "subject"

=back

=cut
command "get_field_definition" => {
    profile => { isa => 'AlphaPunct', required => 1, },
    fields  => { isa => 'ArrayRef', },
    style   => { isa => 'Str', },
    section => { isa => 'Str', },
} => sub {
    my ($self, $params) = @_;

    die "Either 'fields' or 'style' must be specified"
     unless $params->has_fields || $params->has_style;

    my $fields;
    if ($params->has_fields) {
        $fields = $params->fields;
    }
    # If 'style' is given we do the field lookup ourself
    else {
        my $section = $params->has_section ? $params->section : 'subject';
        my @fields = CTX('config')->get_list([ 'profile', $params->profile, 'style', $params->style, 'ui', $section ]);
        ##! 16: 'fields ' . Dumper \@fields
        $fields = \@fields;
    }

    my $util = OpenXPKI::Server::API2::Plugin::Profile::Util->new;
    my $result = $util->get_input_elements($params->profile, $fields);
    ##! 16: 'result ' . Dumper $result
    return $result;
};

__PACKAGE__->meta->make_immutable;
