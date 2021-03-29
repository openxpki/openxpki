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
    $self->add_config(
        "system.realms.test" => { label => "AuthTestRealm", baseurl => "http://127.0.0.1/test/" },
        "realm.test.auth.stack" => {
            Testing => { handler => 'Testing', type => 'passwd' },
            Password => { handler => 'Password', type => 'passwd' },
            FallThru => { handler => ['Password','NoAuth'], type => 'passwd' },
        },
        "realm.test.auth.handler" => {
            Testing => { type => 'Anonymous' },
            NoAuth =>  { type => 'NoAuth', role => 'Anonymous' },
            Password => { type => 'Password', role => 'User', user => { foo => '$1$wBq76YnC$sA6EX6ahWLNVB9QYQG15r1' } },
        },
        "realm.test.auth.roles" => {
            "Anonymous"   => { label => "Anonymous" },
            "RA Operator" => { label => "RA Operator" },
            "System"      => { label => "System" },
            "User"        => { label => "User" },
        },
    );
};

1;
