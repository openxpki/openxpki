# RT_SiteConfig.pm
#
# These are the bits you absolutely *must* edit.
#
# To find out how, please read
#   /usr/share/doc/request-tracker3.6/NOTES.Debian

# THE BASICS:

Set($rtname, 'rt.openxpki.example.com');
Set($Organization, 'example.com');

Set($CorrespondAddress , 'rt@my.domain.com');
Set($CommentAddress , 'rt-comment@my.domain.com');

Set($Timezone , 'Europe/London'); # obviously choose what suits you

# THE DATABASE:

Set($DatabaseType, 'mysql'); # e.g. Pg or mysql

# These are the settings we used above when creating the RT database,
# you MUST set these to what you chose in the section above.

Set($DatabaseUser , 'rtuser');
Set($DatabasePassword , 'wibble');
Set($DatabaseName , 'rtdb');

# THE WEBSERVER:

Set($WebPath , "/rt");
Set($WebBaseURL , "http://openxpkilive");

1;
