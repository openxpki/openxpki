//defines the OXI namespace
//and basic conf

var OXI = {
   
   Config:Ember.Object.create({
         serverUrl : '/cgi-bin/connect.cgi',
//         serverUrl : '/cgi-bin/mock.cgi',
         
         //root element in index.html (for ember application)
         rootElement: '#application',
         
         //name of cgi-session cookie (needed to reset the client session
         cookieName: 'CGISESSID',
         
         //delay (in milliseconds) before the ajax loading spinner shows off
         ajaxLoaderTimeout:500
      })
   
};
