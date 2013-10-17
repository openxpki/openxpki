#!/usr/bin/perl
use strict;

use CGI;
#use CGI::Carp qw (fatalsToBrowser);
use CGI::Session;
use JSON;
use Data::Dumper;
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init($DEBUG);

my $session_id;
my $user;


sub handle {


    my $q = shift;
    my $session = new CGI::Session(undef, $q, {Directory=>'/tmp'});
    $session_id = $session->id;
    # the action param indicates what is requested, no action = Home/Login

    #    my $query = $q->param('record[subject]');

    #$session->param("my_name", $name);

    logger()->debug('Session id ' . $session_id);

    my $res;
    my $page = $q->param('page') || '';
    my $action = $q->param('action') || '';
    logger()->debug('action ' . $action);
    $user = $session->param('user');
    #my $user = {name=>'paul',login=>1};
    #actions which work without login
    if($page eq 'bootstrap!structure'){
        my $structure = ($user &&  $user->{login})?
        get_side_structure_logged_in($user)
        :get_side_structure_not_logged_in();
        ;
        return {structure => $structure, session_id=>$session_id, user=>$user};
    }



    # Login page

    logger()->debug('User ' .  Dumper $user );

    if (!$user ||  !$user->{login}) {

        if ($action eq 'login') {
            $res = handle_login( $q );
            $user =  $res->{user};
            logger()->debug('User logged in' .  Dumper $user );
            $session->param("user", $user ) unless( $res->{error});
        } else {
            $res = { 'page' => 'login' };
        }

        logger()->debug('Result after handling' . Dumper $res);

    } elsif ($page eq 'logout') {
        $session->delete();
        $session_id = '';
        $res = {'page' => 'login' , 'status' => { 'level' => 'success', 'message' => 'Session terminated' } };
    } elsif ($action eq 'certsearch') {
        $res = handle_certsearch( $q );
    } elsif ($action =~ /^request_cert/) {
        $res = handle_request_cert( $q,$session,$action );
    }elsif ($q->param('page')) {
        $res = {'page' => $q->param('page') };
    }



    # error occured, just send error hash
    my $page = $res->{page};
    return $res if(!$page  || ref $page eq 'HASH');
    

    if ($page eq 'login') {
        return {
            page => {
                'label' => 'OpenXPKI Login',
                'description' => 'Please log in ;)',
            },
            main => [
            #first section
            { action => 'login','type' => 'form',
                content => {
                    title=>'',
                    submit_label => 'do login',
                    
                    fields => [
                    { name => 'username', label => 'Username', type => 'text' },
                    { name => 'password', label => 'Password',type => 'password' },
                    ]
                }
            }
            ]
        };
    } elsif($page eq 'request_cert'){
        
        return {
            page => {
                'label' => 'Request cert',
                'description' => '',
            },
            main => [
            #first section
            { action => 'request_cert','type' => 'form',
                content => {
                    label=>'Step 1',
                    description=> 'First you must master provide a certificate type, then you can choose some mmore details',
                    submit_label => 'proceed',
                    fields => [
                    { name => 'cert_typ', label => 'Typ', type => 'select',options=>[{value=>'t1',label=>'Typ 1'},{value=>'t2',label=>'Typ 2'},{value=>'t3',label=>'Typ 3'}] },
                    
                    ]
                }
            }
            ]
        };
        
    }elsif ($page eq 'home') {
        return {
            page => {
                label => 'Welcome to OpenXPKI',
            },
            main => [
                {type => 'text',
                 content => {
                    label => 'My little Headline',
                    description => 'Some text block',
                    }
                }
            ],
        status => $res->{status}
    };
} elsif ($page eq 'search_certificates') {
    return {
        page => {
            label => 'Certificate Search',
            description => 'You can search for certs here.',

        },
        main => [{ type => 'form',action => 'certsearch',
            content => {
                label=>'',
                submit_label => 'search now',
                fields => [
                { name => 'subject', label => 'Subject', type => 'text',is_optional => 1 },
                { name => 'issuer', label => 'Issuer', type => 'text',is_optional => 1 },
                ]
            }
        }]
    };
} elsif ($page eq 'welcome') {
    return {
            page => {
                label => 'Welcome to OpenXPKI',
            },
            main => [
                {type => 'text',
                 content => {
                    label => 'Whats new?',
                    description => 'some news of the day...',
                    }
                }
            ],
        status => { level => 'success', message => 'Login successful' }
    };    
} elsif ($page eq 'test_reload') {
    if(!$session->param("pageReloaded")){
        $session->param("pageReloaded",1);
        return {page=>{},reloadTree=> 1,status=>{level=>'warn',message=>'page will reload now!'}};
    }else{
        $session->param("pageReloaded",0); 
        return {
            page => {},
            status => { level => 'success', message => 'Page has been reloaded!' }
        }; 
    }
    
}elsif($page eq 'test_goto'){
    my $target = 'search/search_certificates';
    return {page=>{},'goto'=> $target,status=>{level=>'info',message=>'url will change to '.$target}};
    
}elsif($page eq 'secret_page'){
   
    return {page=>{'label' => 'some special page'}};
    
}elsif($page eq 'test_key_value'){
   
    return {page=>{'label' => 'Test Key Value'},
            main => [
                {type => 'keyvalue',content => {
                    label => '',
                    description => '',
                    data => [
                        {label => 'key 1', value => 'value 1'},
                        {label => 'key 2', value => '1395226097', format=>'timestamp'},
                        {label => 'key 2', value => ['123','876']},
                    ]    
                }
            }]
        };
    
}else{
    return {
        page => {
            label => 'Sorry!',
            description => 'The page '.$page.' is not implemented yet.'
        }
        
        
            
        
    };

}


}

sub get_side_structure_not_logged_in{
    return [
    {
        key => 'login_form',
        label =>  'Login',
        entries =>  [

        ]
    }
    ];
}

sub get_side_structure_logged_in{
    my $user = shift;
    return [
    {
        key=> 'home',
        label=>  'Home',
        entries=>  [
        {key=> 'my_tasks', label =>  "My tasks"},
        {key=> 'my_workflows',label =>  "My workflows"},
        {key=> 'my_certificates',label =>  "My certificates"} ,
        {key=> 'key_status',label =>  "Key status"}
        ]
    },

    {
        key=> 'request',
        label=>  'Request',
        entries=>  [
        {key=> 'request_cert', label =>  "Request new certificate"},
        {key=> 'request_renewal',label =>  "Request renewal"},
        {key=> 'request_revocation',label =>  "Request revocation"} ,
        {key=> 'issue_clr',label =>  "Issue CLR"},
        
        ]
    },

    {
        key=> 'info',
        label=>  'Information',
        entries=>  [
        {key=> 'ca_cetrificates', label =>  "CA certificates"},
        {key=> 'revocation_lists',label =>  "Revocation lists"},
        {key=> 'pollicy_docs',label =>  "Pollicy documents"}
        ]
    },

    {
        key=> 'search',
        label=>  'Search',
        entries=>  [
        {key=> 'search_certificates', label =>  "Certificates"},
        {key=> 'search_workflows',label =>  "Workflows"}
        ]
    },
    {
        key=> 'test',
        label=>  'Tests',
        entries=>  [
        {key=> 'test_reload',label =>  "Test page reload"},
        {key=> 'test_goto',label =>  "Test goto"},
        {key=> 'test_key_value',label =>  "Test Key/Value"},
        
        ]
    }

    ];
}

sub handle_login {

    my $q = shift;
    my $dummy_user = {login=>'admin',name => 'D.Siebeck', role=> 'admin', password=>'oxi'};
    if ($q->param('username') eq $dummy_user->{login} && $q->param('password') eq $dummy_user->{password}) {
        return { goto => 'welcome', user=>$dummy_user, reloadTree=> 1, status => { level => 'success', message => 'Login successful' } };
    }

    return { status => { level => 'error', message => 'Login credentials are wrong!' }};

}

sub handle_request_cert{
    my $q = shift;
    my $session = shift;
    my $action = shift;
    
    #demonstration of 2-step form with reset-action
    if($q->param('cert_typ')){
        $session->param('cert_typ',$q->param('cert_typ'));  
    }elsif($action eq 'request_cert!reset_typ'){
        #reset the first selection
        $session->param('cert_typ',undef);
    }
    
    my $typ = $session->param('cert_typ');
    if(!$typ){
        return {'page' => 'request_cert'};
    }
    
    
    if($typ){
        
        if($q->param('cert_purpose')){
            #process finished
            $session->param('cert_typ',undef);
            
            my $status = {level => 'success',message=> 'Congrats...you are finished!'};
            if($q->param('is_urgent')){
                $status = {level => 'warn',message=> 'Oh..its urgent. We will do what we can!'};
            }
            my @keys = $q->param();
            my @input;
            foreach my $k (@keys){
                push @input, sprintf('%s: %s',$k,$q->param($k)) ;
            }
            
            
            return {
                page => {
                     'label' => 'Request cert',
                     
                },  
                status => $status,
                main => [
                        {type => 'text',content => {
                            label => 'Your input',
                            description => join('<br>',@input)
                            }
                        }]
                };
                
        }else{
        
            return {
                page => {
                    'label' => 'Request cert',
                },
                status => {level => 'info',message=> 'well done ... we see the light at the end of the tunnel...'},
                main => [
                #first section
                { action => 'request_cert','type' => 'form',
                    content => {
                        label=>'Step 2',
                        description => sprintf('you choosed type "%s"... - are you sure?',$typ),
                        #submit_label => 'finish',
                        
                        buttons => [
                            {action => 'request_cert!reset_typ',do_submit=>0,label=>'change type selection'},
                            {action => 'request_cert',do_submit=>1,label=>'finish'},
                        ],
                        
                        fields => [
                        { name => 'cert_purpose', label => 'Purpose', type => 'select',options=>[{value=>'p1',label=>'Purpose 1'},{value=>'p2',label=>'Purpose 2'},{value=>'p3',label=>'Purpose 3'}] },
                        { name => 'some_text', label => 'Text', type => 'text' },
                        { name => 'opt_text', label => 'Text (opt)', type => 'text' ,is_optional=>1},
                        { name => 'is_urgent', label => 'Yes, this is urgent!', type => 'checkbox' },
                        { name => 'long_text', label => 'Some long text', type => 'textarea' },
                        ]
                    }
                }
                ]
            };
        }
    }else{
        
    }
       
}

sub handle_certsearch {

    my $q = shift;

    my $subject = $q->param('subject');
    my $issuer  = $q->param('issuer');

    return {'status' => { 'level' => 'error', 'message' => 'Please specify either subject or issuer!' }} unless ($subject || $issuer);
    
    

    return {
        page => {label => 'Your Searchresult'},
        status => {},
        
        main => [
                #first section
                {
        
                    'type' => 'grid',
                    'processing_type' => 'all',
                    'content' => {
                        #'label' => 'Grid-Headline',
                        'description' => 'some text before...',
                        'actions' => [
                            {path => 'cert!detail!{id}',
                             label => 'Details'
                            },
                            {path => 'cert!copy!{id}',
                             label => 'Create copy'
                            },
                            {path => 'cert!mail2issuer!{id}',
                             label => 'Send an email to issuer'
                            },
                        ],
                        'columns' => [
            						{ sTitle => "serial" },
            						{ sTitle => "subject" },
            						{ sTitle => "email"},
            						{ sTitle => "notbefore",format => 'timestamp'},
            						{ sTitle => "notafter",format => 'timestamp'},
            						{ sTitle => "issuer"},
            						{ sTitle => "identifier"},
            						{ sTitle => "_id"},#internal ID (will not be displayed)
            						{ sTitle => "_status"},#row status (will not be displayed, but translated in gridrow css class)
            					] ,
            	        'data' => [
            	            ['0123','CN=John M Miller,DC=My Company,DC=com','john.miller@my-company.com',1379587708,1395226097,'CN=CA 1,O=OpenXOKI Testing,ST=Bayern,C=DE','swBdX644xhsn-brmKLbKOb8buMc','888','issued'],
            	            ['0456','CN=Bob Builder,DC=My Company,DC=com','',1379587517,1411113697,'CN=CA 1,O=OpenXOKI Testing,ST=Bayern,C=DE','qqA2HidUoRvlSLhsFIB6_ps6CpQ','999','expired'],
            	            ['0776','CN=Bob Builder,DC=My Company,DC=com','',1279588888,1311113697,'CN=CA 1,O=OpenXOKI Testing,ST=Bayern,C=DE','qqA2HidUoRvlSLhsFIB6_ps6CxX','989','revoked'],
            	            ['7676','CN=John M Miller,DC=My Company,DC=com','john.miller@my-company.com',1379585522,1395220000,'CN=CA 1,O=OpenXOKI Testing,ST=Bayern,C=DE','swBdX644xhsn-brmKLbKOb8buyy','886','issued'],
            	            ['7670','CN=John M Miller,DC=My Company,DC=com','john.miller@my-company.com',1378585522,1395110000,'CN=CA 1,O=OpenXOKI Testing,ST=Bayern,C=DE','swBdX644xhsn-brmKLbKOb8bu11','880',''],
            	            ['7671','CN=John M Miller,DC=My Company,DC=com','john.miller@my-company.com',1398585522,1393560000,'CN=CA 1,O=OpenXOKI Testing,ST=Bayern,C=DE','swBdX644xhsn-brmKLbKOb8bu22','881','expired'],
            	        ],   
                        
                    },
                }
                ]
        
        
        
    };

}


sub logger {

    return Log::Log4perl->get_logger();
}

my $q = CGI->new;
my $ret = handle($q);



#print $q->header(-cookie=> $q->cookie(CGISESSID =>  $session_id));# -cookie=> $q->cookie(CGISESSID =>  $session_id), -type => 'application/json' );
#print $q->header(-cookie=> $q->cookie(CGISESSID =>  $session_id), -type => 'application/json' );
#print $q->header({cookie=> [$q->cookie(CGISESSID =>  $session_id)],type=>'text/html'});

my %header = (
type => 'application/json',#'text/html',
status => '200 OK',
charset => 'utf-8',
cache_control => 'no-cache, no-store, must-revalidate',

);

my $cookie = $q->cookie(CGISESSID =>  $session_id);
$header{cookie} = $cookie;
print $q->header(\%header);
#print $q->header(\%header);

my $json = new JSON();

logger()->debug('will return ' .  Dumper $ret );

if (ref $ret eq 'HASH') {
    
    print $json->encode($ret);
} else {
    print $json->encode({ 'level' => 'error', 'message' => 'Application error!' });
}


1;

=head1 DISCLAIMER

This is a stupid mock up for our ui development, it does do anything usefule
and does not care about any input security, so please just dont use it.


=head1 General

=head2 Request format

Each request should have either the param action or page set, the return is
always a json hash either holding a definition for a new page or an error.

The global structure is as follows:

{
    page => {
        label => string, used as h1/title
        description => global intro text
    },
    status => {
        level =>  one of 'error','success','info','warn',
        message => the status message
    },
    
    goto => string, will be evaluated as url-hashtag target 
    
    reloadTree => bool, if set, the browser will perform a complete reload. If an additional "goto" is set, the page-url will change to this target
    
    
    main => {
        [
        #one or more sectiosns
        {
            type => text|grid|form|key-value
            
            content => {
                    label => string (section headline)
                    description => string (optional text
                    additional params depending from type ...
                }
            
            additional params depending from type 
            
        }
        ]
        Holds content for the main area, depends on page type
    }

}

=head2 Status

Most calls return a key status in the response hash. Subkeys are level and
message where level is one of 'error','success','info','warn'.


=head2 Forms

If you have a form, you need to send back the fields requested and the
parameter given by 'action' (as is). If the input is accepted, you will
get back a new page definition, if the input is not accepted, you will
get ONLY a hash with key 'error' holding a hash with the fieldnames and
a reason what is wrong. Optional is a second key named status.

=head1 Expected Test Cases

=head2 Login Form

Call without a valid session, you will get the description of the login form.
Hardcoded valid login is admin/openxpki - anything else should give an error.
The login currently ends in an empty Welcome page.

=head2 Certificate Search

Call with a valid session (do login - works using cookie magic) and the param
page=certsearch, fill the form as requested, you get back a 'grid' page.


