                       Amazon to Marc Converter
                             Version 0.1.2
                              2011-03-03

Installation Notes:

1> All five parts (two .pl Perl scripts and three .pm Perl modules) must be 
   installed in the same directory.

2> In order for this program to work you must have an Amazon Web Services Account.
   If you do not have one you can sign up for one at http://aws.amazon.com/.  You
   will also need to apply for an Amazon Associates account.

3> The above keys should be added to the az2marc.ini file.  Here is a Key/Value
   explanation:

    accesskey: AWS access key
    secretkey: AWS secret key
    associate: You Amazon Associates tag 
    tmp: Temp directory for saving batches
    analytics: Google Analytics key [optional]

4> Other Perl Modules that need to be installed are:
    
    LWP::Simple;
    Digest::SHA;
