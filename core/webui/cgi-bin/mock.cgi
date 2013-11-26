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
    }elsif($action eq 'cert_search!options'){
        
        #ajax autocompleter options
        return {options => [{value=>'c1',label=>'Cert 1'},{value=>'c2',label=>'Cert 2'},{value=>'c3',label=>'Cert 3'}]};
        
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
                    { name => 'cert_typ', label => 'Typ',prompt => 'please select a type', value=>'t2', type => 'select',options=>[{value=>'t1',label=>'Typ 1'},{value=>'t2',label=>'Typ 2'},{value=>'t3',label=>'Typ 3'}] },
                    
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
        
        right => [
                    {type => 'text',
                     content => {
                        label => 'Bla',#Right pane 1',
                        description => 'Text 1;: lajsdlkajsd lkajsd lkajsd lkajsd lkajs dlja skdj lasjd '
                        }
                    },
                ],
        
        main => [{ type => 'form',action => '',
            content => {
                label=>'',
                
                buttons => [
                            
                            {action => 'certsearch',do_submit=>1,label=>'search now'},#target=>'tab'
                        ],
                
                fields => [
                { name => 'subject', label => 'Subject', type => 'text',is_optional => 1 },
                { name => 'cert_purpose', label => 'Purpose',prompt=>'type in or select a value', editable=>1, type => 'select',options=>[{value=>'p1',label=>'Purpose 1'},{value=>'p2',label=>'Purpose 2'},{value=>'p3',label=>'Purpose 3'}] },
                { name => 'cert_id', label => 'Cert Id (ajax)',is_optional => 1, prompt=>'type in or select a value', type => 'select',options=> 'cert_search!options' },
                        
                { name => 'issuer', label => 'Issuer', type => 'text',is_optional => 1,clonable=>1, value => ['Issuer 1','Issuer 2'] },
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
   
    return {page=>{'label' => 'some special page','shortlabel'=>'special'}};
    
}elsif($page eq 'my_tasks'){
   
    return {page=>{'label' => 'My tasks'},main=>[
            {type => 'grid',
                    processing_type => 'all',
                    content => {
                            buttons => [
                                
                                {page => 'my_workflows',label=>'My workflows (tab)',target=>'tab'},
                                {page => 'home/my_certificates',label=>'My certificates (new page)',target=>'main',css_class=> 'btn-primary'},
                                {page => 'home/my_certificates',label=>'My certificates (tab)',target=>'tab'},
                                {page => 'home/my_certificates',label=>'My certificates (modal)',target=>'modal'},
                                {page => 'request_cert',label=>'Request cert (modal)',target=>'modal',css_class=> 'btn-info btn-lg'},
                                {page => 'request_cert',label=>'Request cert (tab)',target=>'tab'},
                                
                                
                            ],    
                            
                            actions => [
                                
                                {path => 'secret_page',
                                 label => 'Secret Page (modal)',
                                 target => 'modal',
                                },
                                {path => 'my_tasks',
                                 label => 'another (nested) my tasks...',
                                 target => 'tab',
                                },
                                {path => 'my_workflows',
                                 label => 'my workflows (tab)',
                                 target => 'tab',
                                },
                                ,
                                {path => 'my_certificates',
                                 label => 'my certificates',
                                 target => 'tab',
                                },
                            
                            ],
                        columns => [
            						{ sTitle => "title" },
            						{ sTitle => "description" },
            						
            						{ sTitle => "date_issued",format => 'timestamp'},
            						{ sTitle => "link",format => 'link'}
            						
            					] ,
            	        data => [
            	            ['Titel 1','Description 1',1379587708,{label=>'Z Test page',page => 'test_text',target=>'modal'}],
            	            
            	            ['Titel 2','Description 2',1379587799,{label=>'A Test page',page => 'test_text',target=>'modal'}],
            	            ['Titel 3','Description 3',1312158770,{label=>'B Test page',page => 'test_text',target=>'modal'}],
            	            ['Titel 4','Description 4',1376687708,{label=>'E Test page',page => 'test_text',target=>'modal'}],
            	            
            	        ],   
                        }
            }
        ]};
    
}elsif($page eq 'my_workflows'){
   
    return {page=>{'label' => 'My workflows'},main=>[
            {'type' => 'grid',
                    'processing_type' => 'all',
                    'content' => {
                            'actions' => [
                            {path => 'my_workflows!{date_issued}',
                             label => 'WF Test 1',
                             icon => 'view',
                             target => 'tab',
                            },
                            {path => 'my_workflows!blub',
                             label => 'WF Test 2',
                             target => 'tab',
                            },
                            
                        ],
                        'columns' => [
            						{ sTitle => "title" },
            						{ sTitle => "description" },
            						
            						{ sTitle => "date_issued",format => 'timestamp'}
            						
            					] ,
            	        'data' => [
            	            ['Workflow 1','sldkjflsdjflksjd flkjsd f 1',1379587708],
            	            ['Workflow 2','wertkwer ,sndf ksd f 2',1379587799],
            	            ['Workflow 3','asldkhlsadkjf lkasjd  3',1312158770],
            	            ['Workflow 4','wksghrkjqhwekjhqwkjeh 4',1376687708],
            	        ],   
                        }
            }
        ]};
    
}elsif($page eq 'my_certificates'){
   
    return {page=>{'label' => 'My certificates','description'=>'only one action assigned to grid'},main=>[
            {type => 'grid',
                    processing_type => 'all',
                    content => {
                         actions => [
                            
                            {path => 'test_text',target=>'modal',
                             label => 'Grid Main action',
                            },
                            
                        ],
                        buttons => [
                                
                                {page => 'test_key_value',label=>'Key Value (in Tab)',target=>'tab'},
                                {page => 'test_text',label=>'Plain text (in Tab)',target=>'tab'},
                                {page => 'test_text',label=>'Plain text (no target)'},
                                {page => 'test_text',label=>'Plain text (target self)',target=>'self'},
                                {page => 'request_cert',label=>'Request cert (tab)',target=>'tab'},
                                {page => 'request_cert',label=>'Request cert (self)',target=>'self'}
                            ],

                        columns => [
            						{ sTitle => "title" },
            						{ sTitle => "description" },
            						
            						{ sTitle => "date_issued",format => 'timestamp'}
            						
            					] ,
            	        data => [
            	            ['Cert 1','sldkjflsdjflksjd flkjsd f 1',1379587708],
            	            ['Cert 2','wertkwer ,sndf ksd f 2',1379587799],
            	            ['Cert 3','asldkhlsadkjf lkasjd  3',1312158770],
            	            ['Cert 4','wksghrkjqhwekjhqwkjeh 4',1376687708],
            	        ],   
                        }
            }
        ]};
    
}elsif($page eq 'test_loading'){
    sleep(5);
    return {page=>{'label' => 'phew...this took a while...'}};
    
}elsif($page eq 'test_key_value'){
   
    return {page=>{'label' => 'Test Key Value'},
            main => [
                {type => 'keyvalue',content => {
                    label => '',
                    description => '',
                    buttons => [
                            {action => 'test_text',label=>'Plain text (as action, no target)'},
                            {page => 'test_text',label=>'Plain text (no target (=main)',target=>'main'},
                            {page => 'test_text',label=>'Plain text (modal)',target=>'modal'},
                            {page => 'test_text',label=>'Plain text (tab)',target=>'tab'},
                            {page => 'test_key_value!page2',label=>'Page 2 (in Tab)',target=>'tab'},
                            {action => 'test_key_value!action2',page => 'test_key_value!page3',label=>'Action 2/Page 3 (in Tab)',target=>'tab'},
                        ],                    
                    data => [
                        {label => 'key 1', value => 'value 1'},
                        {label => 'key 2', value => '1395226097', format=>'timestamp'},
                        {label => 'key 2', value => ['123','876']},
                        {label => 'Link KV',  value => {label => 'Test KV 2',page => 'test_key_value2'},format=>'link'},
                        {label => 'Link Text',  value => {label => 'Test Textpage',page => 'test_text'},format=>'link'},
                    ]    
                }
            }]
        };
    
}elsif($page eq 'test_key_value2'){
   
    return {page=>{'label' => 'Test Key Value 2'},
            main => [
                {type => 'keyvalue',content => {
                    
                    data => [
                        {label => 'key 11', value => 'value 2'},
                        {label => 'key 111', value => 'value 2222'},
                        {label => 'key 21', value => '1395226097', format=>'timestamp'},
                        {label => 'key 21', value => ['456','789']},
                        {label => 'Link 2',  value => {label => 'Test KV 1',page => 'test_key_value'},format=>'link'},
                    ]    
                }
            }]
        };
    
}elsif($page eq 'test_text'){
    return {page=>{'label' => 'Some plain text',description=>'some long text sjahdasd  lajsd ajsd l kaj dljahweorzowejasdh'},
            status => {level=>'info',message => 'Status-Message'},
            
            right => [
                    {type => 'text',
                     content => {
                        label => '',#Right pane 1',
                        description => 'Text 1;: lajsdlkajsd lkajsd lkajsd lkajsd lkajs dlja skdj lasjd '
                        }
                    },
                ],
            
            
            main => [
                {type => 'text',
                 content => {
                    label => 'Block 1',
                    description => 'Text 1;: aksjdhkashdkahsdkhaksdhakshdkashdkjashdkjashd'
                    }
                },
                {type => 'text',
                content => {
                    label => 'Block 2',
                    description => 'Text 2 aksjdhkashdkahsdk <b>bold</b> <i>italic> text. <br> haksdhakshdkashdkjashdkjashd. <div class=xx>inside div</div>',
                    buttons => [
                            {action => 'test_key_value!action1',label=>'Action 1'},
                            {page => 'test_key_value',label=>'Key Value (main)'},
                            {page => 'test_key_value',label=>'Key Value (modal)',target=>'modal'},
                            {page => 'test_key_value',label=>'Key Value (in Tab)',target=>'tab'},
                            {action => 'test_key_value!action2',page => 'test_key_value!page3',label=>'Action 2/Page 3 (in Tab)',target=>'tab'},
                        ],
                    } 
                },
                {type => 'text',
                     content => {
                        label => 'Block 3',
                        description => 'Text 3 aksjdhkashdkahsdkhaksdhakshdkashdkjashdkjashd',
                    }
                }
            ]
        };
    
}else{
    return {
        page => { },
         status => {level=>'warn',message=>'The page '.$page.' is not implemented yet.'} 
        
        
            
        
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
        {key=> 'test_loading',label =>  "Test long loading"},
        {key=> 'test_key_value',label =>  "Test Key/Value"},
        {key=> 'test_text',label =>  "Plain text page"},
        ]
    }

    ];
}

sub handle_login {

    my $q = shift;
    my $dummy_user = {login=>'admin',name => 'D.Siebeck', role=> 'admin', password=>'oxi'};
    
    my $goto = ($q->param('original_target'))?$q->param('original_target'):'welcome';
    
    if ($q->param('username') eq $dummy_user->{login} && $q->param('password') eq $dummy_user->{password}) {
        return { goto => $goto, user=>$dummy_user, reloadTree=> 1, status => { level => 'success', message => 'Login successful' } };
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
                        
                        buttons => [
                            {action => 'request_cert!reset_typ',do_submit=>0,label=>'change type selection'},
                            {page => 'test_text',do_submit=>0,label=>'other (new) page'},#target="main" is implicit
                            {page => 'test_text',do_submit=>0,label=>'other page (same tab)',target=>'self'},
                            {action => 'request_cert',do_submit=>1,label=>'finish',css_class=>'btn-primary'},
                        ],
                        
                        fields => [
                        { name => 'cert_purpose', label => 'Purpose', type => 'select',freetext => 'other',options=>[{value=>'p1',label=>'Purpose 1'},{value=>'p2',label=>'Purpose 2'},{value=>'p3',label=>'Purpose 3'}] },
                        { name => 'some_text', label => 'Text', type => 'text' },
                        { name => 'opt_text', label => 'Text (opt)', type => 'text' ,is_optional=>1},
                        { name => 'is_urgent', label => 'Yes, this is urgent!', type => 'checkbox' },
                        { name => 'start_date', label => 'Start date', type => 'date', value=> '1379587708',notbefore => '1366587708', notafter => '1399587708'},
                        { name => 'today', label => 'today', type => 'date',value=>'now',return_format => 'iso8601'},
                        
                        { name => 'end_date', label => 'End date', type => 'date',notbefore=>'now'},
                        { name => 'sql_date', label => 'sql date', type => 'date',value=>'2014-05-24',return_format => 'printable'},
                        { name => 'no_date', label => 'no date', type => 'date',value=>'halleluhja',return_format => 'terse'},
                        
                        { name => 'hidden_info', label => 'Hidden',type => 'hidden',value=>'secret'},
                        { name => 'clone_key', label => 'Key', type => 'text',clonable=>1, 'value' =>['proposed value' ]},
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
    my @issuer  = $q->param('issuer[]');

    return {'status' => { 'level' => 'error', 'message' => 'Please specify either subject or issuer!' }} unless ($subject || @issuer);
    
    

    return {
        page => {label => 'Your Searchresult',target=>'main'},
        status => {level => 'info',message=> 'cert: '.$q->param('cert_id').', purpose: '.$q->param('cert_purpose').', given issuer: '.join(', ', @issuer)},
        
        main => [
                #first section
                {
        
                    'type' => 'grid',
                    'processing_type' => 'all',
                    'content' => {
                        #'label' => 'Grid-Headline',
                        'description' => 'some text before...',
                        'actions' => [
                            {path => 'cert!detail!{_id}',
                             label => 'Details',
                             icon => 'view',
                             target => 'tab'
                            },
                            {path => 'cert!copy!{identifier}',
                             label => 'Create copy'
                            },
                            {path => 'cert!mail2issuer!{email}',
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


