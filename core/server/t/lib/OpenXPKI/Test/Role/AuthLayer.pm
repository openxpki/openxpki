package OpenXPKI::Test::Role::AuthLayer;
use Moose::Role;

=head1 NAME

OpenXPKI::Test::Role::AuthLayer - Moose role that extends L<OpenXPKI::Test>
to be able to test the auth layer

=head1 DESCRIPTION

=cut

# Core modules

# CPAN modules

# Project modules

requires "config_writer";
requires "testenv_root";

before 'init_user_config' => sub { # ... so we do not overwrite user supplied configs
    my $self = shift;
    $self->add_conf(
        "realm.test.auth.stack.Testing" => { handler => 'Testing', type => 'passwd' },
        "realm.test.auth.stack.Password" => { handler => 'Password', type => 'passwd' },
        "realm.test.auth.stack.FallThru" => { handler => ['Password','NoAuth'], type => 'passwd' },
        "realm.test.auth.stack.Tenant" => { handler => 'Tenant', type => 'passwd' },
        "realm.test.auth.handler.Testing" => { type => 'Anonymous' },
        "realm.test.auth.handler.NoAuth" =>  { type => 'NoAuth', role => 'Anonymous' },
        "realm.test.auth.handler.Password" => { type => 'Password', role => 'User', user => { foo => '$1$wBq76YnC$sA6EX6ahWLNVB9QYQG15r1' } },
        "realm.test.auth.handler.Tenant" => { type => 'Password', user => {
            foo => { 'digest' => '$1$wBq76YnC$sA6EX6ahWLNVB9QYQG15r1', role => 'User', tenant => 'Tenant A' },
            bar => { 'digest' => '$1$wBq76YnC$sA6EX6ahWLNVB9QYQG15r1', role => 'Operator', tenant => '' },
            guest => { 'digest' => '$1$wBq76YnC$sA6EX6ahWLNVB9QYQG15r1', role => 'Anonymous' },
        }},
    );
};

1;
