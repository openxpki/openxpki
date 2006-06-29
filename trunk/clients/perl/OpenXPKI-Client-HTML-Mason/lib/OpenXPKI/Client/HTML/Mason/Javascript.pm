## Written by Michael Bell
## (C) Copyright 2005-2006 by The OpenXPKI Project

package OpenXPKI::Client::HTML::Mason::Javascript;

use OpenXPKI::i18n qw( i18nGettext );

our %FUNCTION = ();

sub new
{
    my $class = shift;
       $class = ref($class) || $class;
    my $self  = {@_};
    bless $self, $class;

    my @i18n = ();
    my @lines = ();
    foreach my $func (keys %FUNCTION)
    {
        push @lines, grep (/I18N_/, split (/\n/, $FUNCTION{$func}));
    }
    foreach my $line (@lines)
    {
        $line =~ s/^.*(I18N_[A-Z0-9]+).*$/$1/;
        push @i18n, $line;
    }
    foreach my $string (@i18n)
    {
        $self->{I18N}->{$string} = i18nGettext ($string);
    }

    return $self;
}

sub get_function
{
    my $self = shift;
    if (not defined $_[0])
    {
        my $func = "";
        foreach my $key (keys %FUNCTION)
        {
            $func .= $self->get_function ($key)."\n";
        }
        return $func;
    }
    my $func = shift;
       $func = $FUNCTION{$func};

    ## replace i18n key in the function
    ## parameters are replaced by the javascript stuff itself
    foreach my $key (keys %{$self->{I18N}})
    {
        $func =~ s/$key/$self->{I18N}->{$key}/g;
    }
    return $func;
}

## the definitions are at the end because they desorientate
## (with qq) the syntax parser of vim :)

$FUNCTION{default} = qq^
    <!-- Use the Microsoft ActiveX control to install the certificate -->
    <object
        classid="clsid:43f8f289-7a20-11d0-8f06-00c04fc295e1"
        codebase="xenroll.dll"
        id="certHelperOld">
    </object>
    <object
        classid= "clsid:127698e4-e730-4e5c-a2b1-21490a70c8a1"
        codebase="xenroll.dll"
        id="certHelperNew">
    </object>
^;

$FUNCTION{install_cert_ie} = qq^
<script type="text/javascript">
<!--
    function InstallCertIE (form)
    {
        // Explorer Installation

        if (form.cert.value == "") {
            // certificate not found
           document.all.result.innerText = "I18N_OPENXPKI_CLI_HTML_MASON_UI_HTML_JAVASCRIPT_NO_CERTIFICATE";
           return false;
        }
   
        try {
            certHelperOld.acceptPKCS7(form.cert.value);
        }
        catch(e) {
            try {
                certHelperNew.acceptPKCS7(form.cert.value);
            } catch (e) {
                // perhaps already installed
                document.all.result.innerText = "I18N_OPENXPKI_CLI_HTML_MASON_JAVASCRIPT_INSTALL_ERROR";
                return false;
            }
        }
        document.all.result.innerText = "I18N_OPENXPKI_CLI_HTML_MASON_JAVASCRIPT_INSTALL_SUCCESS";
    }
-->
</script>
^;


$FUNCTION{sign_form} = qq^
<script type="text/javascript">
<!--
function signForm(theForm, theWindow){
  if (navigator.appName == "Netscape"){
    if (signFormN(theForm, theWindow))
    	theForm.submit();
  } else {
    signFormIE(theForm,theWindow);
    theForm.submit();
  }
}

function signFormN(theForm, theWindow) {
  var signedText;

  var sObject;
  var result;
  var msg;

  //alert("the following Data will be signed: \\n\\n"+theForm.text.value);
  
  //alert ('Using integrated Javascript object crypto.');
  signedText = theWindow.crypto.signText(theForm.text.value, "ask");

  if ( signedText.length < 100 ) {
    if ( signedText == "error:internalError" ) {
      // alert( "Internal Browser Error.  Please check that your CA certificate " + 
      //       "is trusted to identify email users.");
      alert ("I18N_OPENXPKI_CLI_HTML_MASON_JAVASCRIPT_SIGN_FORM_MOZILLA_INTERNAL_ERROR");
    } else if ( signedText == "error:userCancel" ) {
      // alert( "Signing request cancelled." );
      alert ("I18N_OPENXPKI_CLI_HTML_MASON_JAVASCRIPT_SIGN_FORM_MOZILLA_CANCELLED");
    } else {
      // alert( "Unknown response string from your browser - " + signedText );
      msg = "I18N_OPENXPKI_CLI_HTML_MASON_JAVASCRIPT_SIGN_FORM_MOZILLA_UNKNOWN_ERROR";
      alert (msg.replace (/__SIGNED_TEXT__/, signedText));
    }
    return false;
  }
  theForm.signature.value = signedText;
  return true;
}
-->
</script>
<script type="text/vbscript">
<!--
Function UnicodeToAscii(ByRef pstrUnicode)
     Dim i, result
     
     result = ""
     For i = 1 To Len(pstrUnicode)
          result = result & ChrB(Asc(Mid(pstrUnicode, i, 1)))
     Next
         
     UnicodeToAscii = result
End Function

Function signFormIE(theForm, theWindow)
Dim SignedData

On Error Resume Next

Set Settings = CreateObject("CAPICOM.Settings")
Settings.EnablePromptForCertificateUI = True

Set SignedData = CreateObject("CAPICOM.SignedData")
If Err.Number <> 0 then
	'MsgBox("please register the capicom.dll on your machine " )
	MsgBox("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_SIGN_FORM_IE_MISSING_CAPICOM")
End If

SignedData.Content = UnicodeToAscii(theForm.text.value)

' we cannot use it by default because MsgBox can only handle up to 1024 characters
' MsgBox(theForm.text.Value)


theForm.signature.Value = SignedData.Sign (Nothing)
' theForm.signature.Value = SignedData.Sign (Nothing, False, CAPICOM_ENCODE_BASE64)

' SignedData.Verify (theForm.signature.Value)
' SignedData.Verify (theForm.signature.Value, False)
' SignedData.Verify (theForm.signature.Value, False, CAPICOM_VERIFY_SIGNATURE_AND_CERTIFICATE)

If Err.Number <> 0 then
	'MsgBox("Sign error: " & Err.Description)
	MsgBox("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_SIGN_FORM_IE_SIGN_ERROR" & Err.Description)
End If

End Function
-->
</script>
^;


$FUNCTION{gen_csr_ie} = qq^
    <script type="text/vbscript">
    <!--
        dim PROV_RSA_FULL
        dim OLD_XENROLL
        dim NEW_XENROLL

        PROV_RSA_FULL = 1
        OLD_XENROLL   = 0
        NEW_XENROLL   = 1

        Function getXEnroll
            dim tester

            On Error Resume Next

            tester = certHelperOld.MyStoreName
            if Len (tester) > 0 then
                getXEnroll = OLD_XENROLL
                'MsgBox ("You are using an old Internet Explorer with a security bug in XEnroll.dll (MS02-48).")
                MsgBox ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_MS02_48_BUG_DETECTED")
            else
                tester = certHelperNew.MyStoreName
                if Len (tester) > 0 then
                    getXEnroll = NEW_XENROLL
                    'MsgBox ("You are using patched Internet Explorer.")
                    MsgBox ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_IE_PATCHED")
                end if
            end if
        End Function

        Sub GenReq
            dim theForm 
            dim options
            dim index
            dim szName
            dim sz10
            dim xenroll

            On Error Resume Next
            set theForm = document.OPENXPKI
            Set re = new regexp 

            xenroll = getXEnroll

            re.Pattern = "__CSP_NAME__"
            name = theForm.csp.options(document.OPENXPKI.csp.selectedIndex).value
            if Len(name) > 0 then
                if xenroll = OLD_XENROLL then
                    certHelperOld.ProviderName=name
                    'MsgBox ("The used Cryptographic Service Provider is " & certHelperOld.ProviderName)
                    MsgBox (re.Replace ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_CSP_NAME", certHelperOld.ProviderName))
                else
                    certHelperNew.ProviderName=name
                    'MsgBox ("The used Cryptographic Service Provider is " & certHelperNew.ProviderName)
                    MsgBox (re.Replace ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_CSP_NAME", certHelperNew.ProviderName))
                end if
            else
                if xenroll = OLD_XENROLL then
                    certHelperOld.ProviderName=""
                else
                    certHelperNew.ProviderName=""
                end if
                'MsgBox ("The used Cryptographic Service Provider is the default one.")
                MsgBox ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_USING_DEFAULT_CSP")
            end if

            csr = ""
    
            szName = theForm.dn.value

            re.Pattern = "__SUBJECT__"
            'MsgBox ("SUBJECT is " & szName)
            Msgbox (re.Replace ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_SUBJECT", szName))

            if xenroll = OLD_XENROLL then
                certHelperOld.providerType = PROV_RSA_FULL
                certHelperOld.HashAlgorithm = "SHA1"
                certHelperOld.KeySpec = 1
                certHelperOld.GenKeyFlags = 134217731
                if theForm.bits.value =  512 then
                    certHelperOld.GenKeyFlags = 33554435
                end if
                if theForm.bits.value =  1024 then
                    certHelperOld.GenKeyFlags = 67108867
                end if
                if theForm.bits.value =  2048 then
                    certHelperOld.GenKeyFlags = 134217731
                end if
                sz10 = certHelperOld.CreatePKCS10(szName, "1.3.6.1.4.1.311.2.1.21")
            else
                certHelperNew.providerType = PROV_RSA_FULL
                certHelperNew.HashAlgorithm = "SHA1"
                certHelperNew.KeySpec = 1
                certHelperNew.GenKeyFlags = 134217731
                if theForm.bits.value =  512 then
                    certHelperNew.GenKeyFlags = 33554435
                end if
                if theForm.bits.value =  1024 then
                    certHelperNew.GenKeyFlags = 67108867
                end if
                if theForm.bits.value =  2048 then
                    certHelperNew.GenKeyFlags = 134217731
                end if
                sz10 = certHelperNew.CreatePKCS10(szName, "1.3.6.1.4.1.311.2.1.21")
            end if

            ' certHelper.GenKeyFlags
            '                        0x0400     keylength (first 16 bit) => 1024
            '                        0x00000001 CRYPT_EXPORTABLE
            '                        0x00000002 CRYPT_USER_PROTECTED
            '                        0x04000003
            '                        0x0200     => this works for some export-restricted browsers (512 bit)
            '                        0x02000003
            '                        33554435

            if Len(sz10) = 0 then 
                if xenroll = OLD_XENROLL then
                    certHelperOld.GenKeyFlags = 134217730
                    if theForm.bits.value =  512 then
                        certHelperOld.GenKeyFlags = 33554434
                    end if
                    if theForm.bits.value =  1024 then
                        certHelperOld.GenKeyFlags = 67108866
                    end if
                    if theForm.bits.value =  2048 then
                        certHelperOld.GenKeyFlags = 134217730
                    end if
                    sz10 = certHelperOld.CreatePKCS10(csr, "1.3.6.1.4.1.311.2.1.21")
                else
                    certHelperNew.GenKeyFlags = 134217730
                    if theForm.bits.value =  512 then
                        certHelperNew.GenKeyFlags = 33554434
                    end if
                    if theForm.bits.value =  1024 then
                        certHelperNew.GenKeyFlags = 67108866
                    end if
                    if theForm.bits.value =  2048 then
                        certHelperNew.GenKeyFlags = 134217730
                    end if
                    sz10 = certHelperNew.CreatePKCS10(csr, "1.3.6.1.4.1.311.2.1.21")
                end if

                if Len(theForm.asn1.value) = 0 then 
                    'MsgBox ("The generation of the request failed") 
                    MsgBox ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_GENERATION_FAILED") 
                    Exit Sub
                end if

            end if 

            theForm.request.value = sz10
            'msgbox (theForm.request.value)

            'msgbox ("The certificate service request was successfully generated.")
            MsgBox ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_GENERATION_SUCCEEDED") 

            theForm.submit 
        End Sub 

        sub enumCSP

            dim prov
            dim name
            dim element
            dim xenroll

            On Error Resume Next

            xenroll = getXEnroll

            prov=0
            document.OPENXPKI.csp.selectedIndex = 0

            do
                name = ""
                if xenroll = OLD_XENROLL then
                    name = certHelperOld.enumProviders(prov,0)
                else
                    name = certHelperNew.enumProviders(prov,0)
                end if
                if Len (name) = 0 then
                    exit do
                else
                    set element = document.createElement("OPTION") 
                    element.text = name
                    element.value = name
                    document.OPENXPKI.csp.add(element) 
                    prov = prov + 1
                end if
            loop

            document.OPENXPKI.elements[0].focus()

        end sub
    -->
    </script>
^;

1;
