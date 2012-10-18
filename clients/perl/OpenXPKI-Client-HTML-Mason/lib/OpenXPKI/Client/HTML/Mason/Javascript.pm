## Written by Michael Bell
## Rewritten by Julia Dubenskaya
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
        $line =~ s/^.*(I18N_[A-Z0-9_]+).*$/$1/;
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

$FUNCTION{default} = "";

$FUNCTION{install_cert_ie} = << 'XEOF';
<script type="text/vbscript">
<!--
    Function InstallCertIE (form, mode)
        ' Explorer Installation
        Err.Clear
        On Error Resume Next

        if (form.cert.value = "") then
            ' certificate not found
            MsgBox("I18N_OPENXPKI_CLI_HTML_MASON_UI_HTML_JAVASCRIPT_NO_CERTIFICATE")
           InstallCertIE = false
        end if

        dim sProvName, nProvType
        dim xenroll
        dim enrollObj

        if mode <> "silent" then
            sProvName=GetSelectedProvName()
            nProvType=GetSelectedProvType()
            xenroll.providerType=nProvType
        else
            sProvName = form.csp.value
        end if

        // Windows Vista + IE 7 certificate installation
        // based on code from
        // http://wiki.cacert.org/wiki/IE7VistaSource
        // (c) CAcert Inc. / Philipp Gühring
        // available under Apache or BSD License
        if Instr(navigator.AppVersion, "Windows NT 6.0") > 0 Then
            // we are on Vista
            Set enrollObj = CreateObject("X509Enrollment.CX509Enrollment")
            enrollObj.Initialize(1)
            enrollObj.InstallResponse 0,form.cert.value,0,""
            if err.number <> 0 then
                MsgBox("I18N_OPENXPKI_CLI_HTML_MASON_JAVASCRIPT_INSTALL_ERROR")
                MsgBox err.Description
            else
                if mode <> "silent" then
                    MsgBox("I18N_OPENXPKI_CLI_HTML_MASON_JAVASCRIPT_INSTALL_SUCCESS")
                end if
                InstallCertIE = true
            end if
        else
            // XP
            Set xenroll = getXEnroll   

            xenroll.ProviderName=sProvName
            xenroll.acceptPKCS7(form.cert.value)
            
            if Err.Number <> 0 then
                ' perhaps already installed
                MsgBox("I18N_OPENXPKI_CLI_HTML_MASON_JAVASCRIPT_INSTALL_ERROR")
                MsgBox(Err.Number)
                InstallCertIE = false
            else
                if mode <> "silent" then
                    MsgBox("I18N_OPENXPKI_CLI_HTML_MASON_JAVASCRIPT_INSTALL_SUCCESS")
                end if
                InstallCertIE = true
            end if
        end if
    End Function
-->
</script>
XEOF


$FUNCTION{sign_form} = << "XEOF";
<script type="text/javascript">
<!--

var PROV_DSS=3;
var PROV_RSA_SCHANNEL=12;
var PROV_DSS_DH=13;
var PROV_DH_SCHANNEL=18;
var ALG_CLASS_SIGNATURE=1<<13;
var ALG_CLASS_HASH=4<<13;
var AT_KEYEXCHANGE=1;
var AT_SIGNATURE=2;

function GetSelectedProvName () {
    return document.OpenXPKI.csp.options[document.OpenXPKI.csp.options.selectedIndex].text;
}

function GetSelectedProvType () {
    return document.OpenXPKI.csp.options[document.OpenXPKI.csp.options.selectedIndex].value;
}

function GetKeyGenFlags (nKeyLength, nCryptUserProtected, nCryptExportable) {
    var nKeyGenFlags;

    // xenroll.GenKeyFlags
    //                        0x0400     keylength (first 16 bit) => 1024
    //                        0x00000001 CRYPT_EXPORTABLE
    //                        0x00000002 CRYPT_USER_PROTECTED
    //                        0x04000003
    //                        0x0200     => this works for some export-restricted browsers (512 bit)
    //                        0x02000003
    //                        33554435

    nKeyGenFlags=nKeyLength<<16;
    nKeyGenFlags|=nCryptUserProtected;
    nKeyGenFlags|=nCryptExportable;
    return nKeyGenFlags;
}

function handleError(nResult) {
    var sErrorName="L_ErrNameUnknown_ErrorMessage";
    // analyze the error
    if (0==(0x80090008\^nResult)) {
        sErrorName="NTE_BAD_ALGID";
    } else if (0==(0x80090016\^nResult)) {
        sErrorName="NTE_BAD_KEYSET";
    } else if (0==(0x80090019\^nResult)) {
        sErrorName="NTE_KEYSET_NOT_DEF";
    } else if (0==(0x80090020\^nResult)) {
        sErrorName="NTE_FAIL";
    } else if (0==(0x80090009\^nResult)) {
        sErrorName="NTE_BAD_FLAGS";
    } else if (0==(0x8009000F\^nResult)) {
        sErrorName="NTE_EXISTS";
    } else if (0==(0x80092002\^nResult)) {
        sErrorName="CRYPT_E_BAD_ENCODE";
    } else if (0==(0x80092022\^nResult)) {
        sErrorName="CRYPT_E_INVALID_IA5_STRING";
    } else if (0==(0x80092023\^nResult)) {
        sErrorName="CRYPT_E_INVALID_X500_STRING";
    } else if (0==(0x80070003\^nResult)) {
        sErrorName="ERROR_PATH_NOT_FOUND";
    } else if (0==(0x80070103\^nResult)) {
        sErrorName="ERROR_NO_MORE_ITEMS";
    } else if (0==(0xFFFFFFFF\^nResult)) {
        sErrorName=L_ErrNameNoFileName_ErrorMessage;
    } else if (0==(0x8000FFFF\^nResult)) {
        sErrorName="E_UNEXPECTED";
    } else if (0==(0x00000046\^nResult)) {
        sErrorName=L_ErrNamePermissionDenied_ErrorMessage;
    } else if (0==(0x800704c7\^nResult)) {
        // not an error at all, user cancel
        return;
    }
    return "Error: "+sErrorName;
}

function signForm(theForm){
  if (navigator.appName == "Netscape"){
    if (signFormN(theForm))
    	theForm.submit();
  } else {
    signFormIE(theForm);
    theForm.submit();
  }
}

function signFormN(theForm) {
  var signedText;

  var sObject;
  var result;
  var msg;

  //alert("the following Data will be signed: \\n\\n"+theForm.text.value);
  
  //alert ('Using integrated Javascript object crypto.');
  signedText = crypto.signText(theForm.text.value, "ask");

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
          MsgBox result
     Next
         
     For i = 1 To Len(result)
          MsgBox(AscW(Mid(result,i,1)))
     Next
     UnicodeToAscii = result
End Function

Function LeftShift(value, width)
	LeftShift = Int(value * 2^width)
End Function

Function RightShift(value, width)
	RightShift = Int(value / 2^width)
End Function

Function UnicodeToUTF8(ByRef pstrUnicode)
    ' converts a unicode string to UTF8
    ' reference: http://en.wikipedia.org/wiki/UTF8
    Dim i, result

    result = ""
    For i = 1 To Len(pStrUnicode)
        CurrentChar = Mid(PstrUnicode, i, 1)
        CodePoint = AscW(CurrentChar)
        If (CodePoint < 0) Then
            ' AscW is broken. Badly. It can only return an integer,
            ' which is 32767 at most. So everything up to 65535 is
            ' AscW() + 65536. That Unicode chars exist beyond 65535
            ' is apparently unknown to Microsoft ...
            CodePoint = CodePoint + 65536
        End If

        MaskSixBits   = 2^6 - 1 ' the lower 6 bits are 1
        MaskFourBits  = 2^4 - 1 ' the lower 4 bits are 1
        MaskThreeBits = 2^3 - 1 ' the lower 3 bits are 1
        MaskTwoBits   = 2^2 - 1 ' the lower 3 bits are 1
        
        'MsgBox(CurrentChar & " : " & CodePoint)
        If (CodePoint >= 0) And (CodePoint < 128) Then
            ' for codepoints < 128, just add one byte with the
            ' value of the codepoint (this is the ASCII subset)
            Zs = CodePoint
            result = result & ChrB(Zs)
        End If
        ' this is common for all of the following
        Zs = CodePoint And MaskSixBits
        If (CodePoint >= 128) And (CodePoint < 2048) Then
            ' for naming, see the Wikipedia article referenced above
            Ys = RightShift(CodePoint, 6)
            FirstByte  = LeftShift(6, 5) Xor Ys ' 110yyyy 
            SecondByte = LeftShift(2, 6) Xor Zs ' 10zzzzz
            'MsgBox "Case 1: " & FirstByte & ", " & SecondByte
            result = result & ChrB(FirstByte) & ChrB(SecondByte)
        End If
        If (CodePoint >= 2048) And (CodePoint < 65536) Then
            Ys = RightShift(CodePoint, 6) And MaskSixBits
            Xs = RightShift(CodePoint, 12) And MaskFourBits
            FirstByte  = LeftShift(14, 4) Xor Xs ' 1110xxxx
            SecondByte = LeftShift(2, 6) Xor Ys  ' 10yyyyyy
            ThirdByte  = LeftShift(2, 6) Xor Zs  ' 10zzzzzz
            'MsgBox "Case 2: " & FirstByte & ", " & SecondByte & ", " & ThirdByte
            result = result & ChrB(FirstByte) & ChrB(SecondByte) & ChrB(ThirdByte)
        End If 
    Next
    UnicodeToUTF8 = result
End Function

Function signFormIE(theForm)
Dim SignedData

On Error Resume Next
Err.Clear

Set Settings = CreateObject("CAPICOM.Settings")
Settings.EnablePromptForCertificateUI = True

Set SignedData = CreateObject("CAPICOM.SignedData")
If Err.Number <> 0 then
	'MsgBox("please register the capicom.dll on your machine " )
	MsgBox("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_SIGN_FORM_IE_MISSING_CAPICOM")
End If

SignedData.Content = UnicodeToUTF8(theForm.text.value)

theForm.signature.Value = SignedData.Sign (Nothing)

If Err.Number <> 0 then
	'MsgBox("Sign error: " & Err.Description)
	MsgBox("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_SIGN_FORM_IE_SIGN_ERROR" & Err.Description)
End If

End Function
-->
</script>
XEOF


$FUNCTION{gen_csr_ie} = << "XEOF";
<script type="text/vbscript">
<!--
        const PROV_RSA_FULL=1
        const KEY_LEN_MIN=1
        const KEY_LEN_MAX=0

        Function getXEnroll
            dim error
            Err.Clear

            On Error Resume Next

            dim XEnrollObject
            Set XEnrollObject = CreateObject("CEnroll.CEnroll.2")
            if Err.Number <> 0 then
                if ( (Err.Number = 438) or (Err.Number = 429) ) then
                    ' the msgbox is used to signal the error code
                    ' because 429 and 438 do not always mean MS 02-48
                    MsgBox("Error: " & Hex(err))
                    document.write("<h1>" & "I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_MS02_48_BUG_DETECTED" & "</h1>" )
                else
                    document.write("<h1>Can't instantiate the CEnroll control: " & Hex(err) & "</h1>")
                end if
                
                getXEnroll = ""
                Err.Clear
            end if
            Set getXEnroll = XEnrollObject
        End Function

        Function CreateCSR (mode)
            dim theForm 
            dim sProvName, nProvType
            dim options
            dim index
            dim szName
            dim sz10
            dim xenroll
            dim nSupportedKeyUsages

            Dim g_objClassFactory
            Dim obj
            Dim objPrivateKey
            Dim g_objRequest
            Dim g_objRequestCMC

            On Error Resume Next
            set theForm = document.OpenXPKI
            set re = new regexp 

            // Windows Vista + IE 7 CSR generation
            // based on code from
            // http://wiki.cacert.org/wiki/IE7VistaSource
            // (c) CAcert Inc. / Philipp Gühring
            // available under Apache or BSD License

            If Instr(navigator.AppVersion, "Windows NT 6.0") > 0 Then
                // we are on Vista
                Set g_objClassFactory = CreateObject("X509Enrollment.CX509EnrollmentWebClassFactory")
                Set obj = g_objClassFactory.CreateObject("X509Enrollment.CX509Enrollment")
                Set objPrivateKey = g_objClassFactory.CreateObject("X509Enrollment.CX509PrivateKey")
                Set objRequest = g_objClassFactory.CreateObject("X509Enrollment.CX509CertificateRequestPkcs10")
                Set objDN = g_objClassFactory.CreateObject("X509Enrollment.CX500DistinguishedName")
                objPrivateKey.ProviderName = theForm.csp.value
                objPrivateKey.ProviderType = "24"
                objPrivateKey.KeySpec = "1"
                objRequest.InitializeFromPrivateKey 1, objPrivateKey, ""
                objDN.Encode("CN=Dummy")
                objRequest.Subject = objDN
                obj.InitializeFromRequest(objRequest)
                CSR=obj.CreateRequest(1)
                theForm.pkcs10.value = CSR
                If len(CSR) = 0 Then
                    MsgBox ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_VISTA_ERROR_DURING_CSR_CREATION")
                End If
            Else
                // XP
                set xenroll = getXEnroll

                re.Pattern = "__CSP_NAME__"
                if mode <> "silent" then
                    sProvName=GetSelectedProvName()
                    nProvType=GetSelectedProvType()
                    if Len(nProvType) > 0 then
                        'MsgBox ("The used Cryptographic Service Provider is " & xenroll.ProviderName)
                        MsgBox (re.Replace ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_CSP_NAME", xenroll.ProviderName))
                    else
                        sProvName=""
                        nProvType=PROV_RSA_FULL
                        'MsgBox ("The used Cryptographic Service Provider is the default one.")
                        MsgBox ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_USING_DEFAULT_CSP")
                    end if
                else
                    sProvName=theForm.csp.value
                    nProvType=PROV_RSA_FULL
                end if

                xenroll.ProviderName=sProvName
                xenroll.ProviderType=nProvType
                xenroll.HashAlgorithm = "SHA1"
                nSupportedKeyUsages=xenroll.GetSupportedKeySpec()
                if 0=nSupportedKeyUsages then
                    nSupportedKeyUsages=AT_SIGNATURE or AT_KEYEXCHANGE
                end if
                if (PROV_DSS=nProvType) or (PROV_DSS_DH=nProvType) or (PROV_DH_SCHANNEL=nProvType) then
                    nSupportedKeyUsages=AT_SIGNATURE
                end if

                alternate_subject = "cn=unsupported,dc=subject,dc=by,dc=MSIE"
                szName = theForm.ie_subject.value

                re.Pattern = "__SUBJECT__"
                'MsgBox ("SUBJECT is " & szName)
                ' if mode <> "silent" then
                '    Msgbox (re.Replace ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_SUBJECT", szName))
                ' end if

                xenroll.GenKeyFlags = GetKeyGenFlags(theForm.bits.value, 2, 1)
                xenroll.KeySpec = 1 ' AT_KEYEXCHANGE
                sz10 = xenroll.CreatePKCS10(szName, "1.3.6.1.4.1.311.2.1.21")
                if (0<>Err.Number) and (mode<>"silent") then
                    ' XEnroll failed
                    dim nResult
                    nResult=handleError(Err.Number)
                    if Len(nResult)>0 then
                        MsgBox(nResult)
                    else
                        'user canselled request generation
                        exit function
                    end if
                end if

                ' try pragmatical failover - we simply set another subject
                if Len(sz10) = 0 then 
                    if mode <> "silent" then
                        MsgBox (re.Replace ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_FAILOVER", alternate_subject))
                        xenroll.GenKeyFlags = GetKeyGenFlags(theForm.bits.value, 2, 0)
                        xenroll.KeySpec = 1 ' AT_KEYEXCHANGE
                        sz10 = xenroll.CreatePKCS10(alternate_subject, "1.3.6.1.4.1.311.2.1.21")

                        if Len(sz10) = 0 then 
                            'MsgBox ("The generation of the request failed") 
                            MsgBox ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_GENERATION_FAILED") 
                        end if
                    end if
                    exit function 
                end if 

                theForm.pkcs10.value = sz10
                'MsgBox (theForm.pkcs10.value)

                'MsgBox ("The certificate service request was successfully generated.")
                if mode <> "silent" then
                    MsgBox ("I18N_OPENXPKI_CLI_HTML_MASON_VBSCRIPT_GEN_CSR_GENERATION_SUCCEEDED") 
                end if
            End If
            theForm.submit 
        End Function

        function checkCSPPresent(cspToCheck)
            dim csps
            csps = enumCSP()
            for each csp in csps
                if csp = cspToCheck Then
                    checkCSPPresent = true
                    exit function
                end if
            next
            checkCSPPresent = false
        End function

        function enumCSP
            on Error Resume Next

            const nMinProvType=1
            const nMaxProvType=600
            dim nProvType, nOrigProvType, nProvIndex, sProvName
            dim XEnroll
	    dim cspNames(100)
	    dim cspIdx

            // Windows Vista + IE 7 CSP listing
            // based on code from
            // http://wiki.cacert.org/wiki/IE7VistaSource
            // (c) CAcert Inc. / Philipp Gühring
            // available under Apache or BSD License

            If Instr(navigator.AppVersion, "Windows NT 6.0") > 0 Then
                // we are on Vista
                Set csps = CreateObject("X509Enrollment.CCspInformations")
                If IsObject(csps) Then
                    csps.AddAvailableCsps()
                    //Document.OpenXPKI.keytype.value="VI"
                    For j = 0 to csps.Count-1
                        Set oOption = document.createElement("OPTION")
                        oOption.text = csps.ItemByIndex(j).Name
                        oOption.value = j
                        Document.OpenXPKI.csp.add(oOption)
			cspNames(j) = csps.ItemByIndex(j).Name 
                    Next
                Else
                    MsgBox("I18N_OPENXPKI_CLI_HTML_MASON_UI_HTML_JAVASCRIPT_VISTA_NO_X509ENROLLMENT_OBJECT")
                End If
            Else
                // Windows 2K / XP using the XEnroll control
                set XEnroll = getXEnroll
                ' save the original provider type
                nOrigProvType=XEnroll.ProviderType
                if 0<>Err.Number then
                    ' XEnroll failed
                    exit function
                end if

                cspIdx = 0
                ' take each of the provider types
                for nProvType=nMinProvType To nMaxProvType
                    if PROV_RSA_SCHANNEL<>nProvType then
                        XEnroll.ProviderType=nProvType
                        ' take each of the providers of the type nProvType
                        nProvIndex=0
                        sProvName=""
                        do
                            'get provider name
                            sProvName=XEnroll.enumProviders(nProvIndex, 0)
                            if &H80070103=Err.Number Then 
                                ' no more providers of the type nProvType
                                Err.Clear
                                exit do
                            elseIf 0<>Err.Number Then
                                ' XEnroll failed
                                exit function
                            end if
                            ' add provider name to the list box
                            dim oElement
                            set oElement=document.createElement("Option")
                            oElement.text=sProvName
                            oElement.value=nProvType

                            document.OpenXPKI.csp.add(oElement)
			    // csp might be hidden var, ignore that it does not support add
                            if 438 = Err.Number Then
                                Err.Clear
                            end if
			    cspNames(cspIdx) = sProvName 
                            cspIdx = cspIdx + 1

                            ' get the next provider number
                            nProvIndex=nProvIndex+1
                        loop
                    end if
                next
                ' restore the original provider type
                XEnroll.ProviderType=nOrigProvType
                document.OpenXPKI.elements[0].focus()
                GetKeyLength()
            End If
            enumCSP = cspNames
        end function

        function GetMinMaxKeyLength (bMinMax, bExchange)
            on Error Resume Next
              
            const KEY_LEN_MIN_DEFAULT=512
            const KEY_LEN_MAX_DEFAULT=4096
            dim sProvName, nProvType, nProvIndex
            dim xenroll
            dim csps

            If Instr(navigator.AppVersion, "Windows NT 6.0") > 0 Then
                // we are on Vista
                // Set csps = CreateObject("X509Enrollment.CCspInformations")
                Set csps = CreateObject("X509Enrollment.CCspInformation")
                sProvName = GetSelectedProvName()
                csps.InitializeFromName(sProvName)
                if bMinMax = 1 then
                    GetMinMaxKeyLength = csps.CspAlgorithms.ItemByName("RSA").MinLength
                else
                    GetMinMaxKeyLength = csps.CspAlgorithms.ItemByName("RSA").MaxLength
                end if
            Else
                // XP
                set xenroll = getXEnroll
                
                sProvName=GetSelectedProvName()
                nProvType=GetSelectedProvType()
                xenroll.ProviderName=sProvName
                xenroll.providerType=nProvType

                GetMinMaxKeyLength=xenroll.GetKeyLen(bMinMax, bExchange)
                
                if (0<>Err.Number) or (KEY_LEN_MIN_DEFAULT>GetMinMaxKeyLength) or (KEY_LEN_MAX_DEFAULT<GetMinMaxKeyLength) then
                    if KEY_LEN_MIN=bMinMax then
                        GetMinMaxKeyLength=KEY_LEN_MIN_DEFAULT
                    else
                        GetMinMaxKeyLength=KEY_LEN_MAX_DEFAULT
                    end if
                end if
            End If 
        end function

       sub GetKeyLength
            on Error Resume Next

            dim nKeyMin, nKeyMax
            dim nPowerSize
            dim oOption
           
            nKeyMin=GetMinMaxKeyLength(KEY_LEN_MIN, 1)
            nKeyMax=GetMinMaxKeyLength(KEY_LEN_MAX, 0)

            ' remove previous values of key length
            do
                if document.OpenXPKI.bits.length=0 then
                   exit do
                else
                    document.OpenXPKI.bits.remove(0)
                end if
            loop
            ' find the smallest power of 2 that is greater or equal then
            ' the minimal key length (generates much nicer keylengths
            ' if the minimal key length is for example 384)
            nPowerSize = 1
            do
                if nPowerSize >= nKeyMin then
                    exit do
                else
                    nPowerSize = nPowerSize * 2
                end if
            loop
            ' add key length to the list
            do
                if nPowerSize>nKeyMax then
                    exit do
                else
                    set oOption = document.createElement("OPTION") 
                    oOption.text = nPowerSize
                    oOption.value = nPowerSize
                    document.OpenXPKI.bits.add(oOption)
                    nPowerSize=nPowerSize*2                   
                end if
            loop

        end sub
-->
</script>
XEOF

1;
__END__

=head1 Name

OpenXPKI::Client::HTML::Mason::Javascript

=head1 Description

This class provides the web interface with all needed Javascript and
Visual Basic Script code. Such code is needed to create signatures and
PKCS#10 requests. The code supports i18n.

=head1 Functions

=head2 new

is the constructor and should not be called with any parameters.
This constructor translates all function to the current locale. This
means that you should not call new before the locale environment is
set.

=head2 get_function

can be used in two ways with the name of a Javascript functionality or
without. If you specify no name then you get all translated Javascript
functions as one string. If you specify a name then you only get the
code for a single functionality. The following functions are available:

=over

=item * default

initializes Microsoft's CAPI objects.

=item * install_cert_ie

=item * sign_form

=item * gen_csr_ie

=back
