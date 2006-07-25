
my $base = 't/instance';
our %config = (
    server_dir         => $base,
    cgi_dir            => "$base/cgi-bin",
    config_dir         => "$base/etc/openxpki",
    var_dir            => "$base/var/openxpki",
    config_file        => "$base/etc/openxpki/config.xml",
    socket_file        => "/var/tmp/openxpki-client-test.socket",
    http_server_port   => 8087,
    debug              => 1,
);
