//defines the OXI namespace
//and basic conf

var OXI = {

    _idCounter : 0,
    getUniqueId: function(){

        this._idCounter++;
        return 'oxi-'+this._idCounter;

    },

    _registeredMethods:{},
    registerMethod: function(identifier,method){
        this._registeredMethods[identifier] =  method;
    },

    callMethod: function(identifier){
        var m = this._registeredMethods[identifier];
        if(!m){
            App.applicationAlert('no method registerd with identifier '+identifier);
            return;
        }
        m();
    }


};
