/** some configuration */

OXI.Config = Ember.Object.create({

    serverUrl : '/cgi-bin/mock.cgi',
//    serverUrl : '/cgi-bin/connect.cgi',

    //root element in index.html (for ember application)
    rootElement: '#application',

    //name of cgi-session cookie (needed to reset the client session
    cookieName: 'CGISESSID',

});

