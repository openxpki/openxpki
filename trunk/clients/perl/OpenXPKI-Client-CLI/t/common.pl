
my $base = 't/instance';
our %config = (
    server_dir         => $base,
    config_dir         => "$base/etc/openxpki",
    var_dir            => "$base/var/openxpki",
    config_file        => "$base/etc/openxpki/config.xml",
    socket_file        => "/var/tmp/openxpki-client-test.socket",
    debug              => 0,
);

if ($ENV{DEBUG}) {
    $config{debug} = 1;
}

1;
