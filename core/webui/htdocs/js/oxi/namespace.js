//defines the OXI namespace
//and basic conf

var OXI = {
   
   Config:Ember.Object.create({
         
         serverUrl : '/cgi-bin/mock.cgi',
         
         //root element in index.html (for ember application)
         rootElement: '#application',
         
         //name of cgi-session cookie (needed to reset the client session
         cookieName: 'CGISESSID',
         
         
      })
   
};
