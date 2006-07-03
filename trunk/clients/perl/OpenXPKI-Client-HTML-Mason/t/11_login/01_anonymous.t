use Test::More tests => 15;

use English;

BEGIN {

    require "t/common.pl";

    ## ask for the auth_stack page
    my $result = `perl bin/openxpki.cgi`;
    ok (! $EVAL_ERROR);
    ok (0 == write_html ({FILENAME => "anonymous_auth_stack.html", DATA => $result}));

    ## parse the auth_stack page
    ## we use some tests here to verify check_html ... yes this is a kind of a hack
    my $xml = get_parsed_xml ("anonymous_auth_stack.html");
    ## dump_page ($xml);
    ok (0 == check_html ({PAGE => $xml, PATH => "html:0/body:0/div:0/div:1/form:0/action"}));
    ok (0 == check_html ({PAGE  => $xml,
                          PATH  => "html:0/body:0/div:0/div:1/form:0/method",
                          VALUE => "post"}));
    ok (0 < check_html ({PAGE => $xml, PATH => "html:0/body:0/div:0/div:1/form:0/select:0/none:0"}));
    ok (0 == check_html ({PAGE => $xml, PATH => "html:0/body:0/div:0/div:1/form:0/select:0/option:4"}));
    ok (0 > check_html ({PAGE => $xml, PATH => "html:0/body:0/div:0/div:1/form:0/select:0/option:5"}));
    ok (0 == check_html ({PAGE  => $xml,
                          PATH  => "html:0/body:0/div:0/div:1/form:0/select:0/name",
                          VALUE => "auth_stack"}));
    ok (0 == check_session_id ($xml));
    my $session_id = get_session_id ($xml);

    ## set authentication stack to anonymous
    $result = `perl bin/openxpki.cgi session_id=${session_id} auth_stack=Anonymous`;
    ok (! $EVAL_ERROR);
    ok (0 == write_html ({FILENAME => "anonymous_index.html", DATA => $result}));
    $xml = get_parsed_xml ("anonymous_index.html");
    ok ($xml);
    ok (0 == check_html ({PAGE  => $xml,
                          PATH  => "html:0/body:0/div:0/div:1/class",
                          VALUE => "navi"}));
    ok (0 == check_html ({PAGE  => $xml,
                          PATH  => "html:0/body:0/div:0/div:1/div:0/class",
                          VALUE => "menu"}));
    ok (0 == check_html ({PAGE  => $xml,
                          PATH  => "html:0/body:0/div:0/div:1/div:0/div:0/class",
                          VALUE => "menu_level_0"}));
}

diag( "Testing anonymous authentication" );
