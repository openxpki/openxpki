use Test::More 'no_plan';

use English;

TODO: {
    local $TODO = 'openxpki.cgi needs config options, cannot be used in a test. Solution: setup a complete webserver environment on which to test';

    diag( "Testing anonymous authentication" );

    require "t/common.pl";

    ## ask for the auth_stack page
    my $result = `perl bin/openxpki.cgi`;
    ok (! $EVAL_ERROR, 'CGI script');
    ok (0 == write_html ({FILENAME => "anonymous_auth_stack.html", DATA => $result}), 'HTML written to temporary file');

    ## parse the auth_stack page
    ## we use some tests here to verify check_html ... yes this is a kind of a hack
    my $xml;
    eval {
        $xml = get_parsed_xml ("anonymous_auth_stack.html");
    };
    ok (! $EVAL_ERROR, 'parsing HTML page');
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
    eval {
        $xml = get_parsed_xml ("anonymous_index.html");
    };
    ok ($xml);
    ok (0 == check_html ({PAGE  => $xml,
                          PATH  => "html:0/body:0/div:0/div:1/id",
                          VALUE => "navi"}));
    ok (0 == check_html ({PAGE  => $xml,
                          PATH  => "html:0/body:0/div:0/div:1/div:0/class",
                          VALUE => "menu"}));
    ok (0 == check_html ({PAGE  => $xml,
                          PATH  => "html:0/body:0/div:0/div:1/div:0/div:0/class",
                          VALUE => "menu_level_0"}));
    ok (0 == check_html ({PAGE  => $xml,
                          PATH  => "html:0/body:0/div:0/div:1/div:0/div:0/div:0/class",
                          VALUE => "menu_level_0_item_type_menu"}));
    ok (0 == check_html ({PAGE  => $xml,
                          PATH  => "html:0/body:0/div:0/div:1/div:0/div:0/div:0/a:0"}));
    ok (0 == check_html ({PAGE  => $xml,
                          PATH  => "html:0/body:0/div:0/div:1/div:0/div:0/div:0/a:0/href",
                          REGEX => "__session_id=[0-9a-f]+;"}));
}

1;
