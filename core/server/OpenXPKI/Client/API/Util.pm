package OpenXPKI::Client::API::Util;
use OpenXPKI;

sub to_cli_field ($fieldname) {
    $fieldname =~ s/_/-/g;
    return $fieldname;    
}

sub to_api_field ($fieldname) {
    $fieldname =~ s/-/_/g;
    return $fieldname;
}

1;
