
my $base = 't/instance';
our %config = (
    server_dir         => $base,
    cgi_dir            => "$base/cgi-bin",
    config_dir         => "$base/etc/openxpki",
    var_dir            => "$base/var/openxpki",
    config_file        => "$base/etc/openxpki/config.xml",
    socket_file        => "/var/tmp/openxpki-client-test.socket",
    http_server_port   => 8087,
    debug              => 0,
    openssl            => "/usr/bin/openssl",
);

if ($ENV{DEBUG}) {
    $config{debug} = 1;
}
if ($ENV{TEST_OPENSSL}) {
    $config{openssl} = $ENV{TEST_OPENSSL};
}

1;
