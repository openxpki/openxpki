//defines the OXI namespace
//and basic conf

var OXI = {
   
   Config:Ember.Object.create({
         serverUrl : '/cgi-bin/connect.cgi',
         rootElement: '#application',
         cookieName: 'CGISESSID',
      })
   
};
