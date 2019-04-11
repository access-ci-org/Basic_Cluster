The Shibboleth role requires additional post-install setup

## Overview
The SAML-based single-sign-on (SSO) requires an identity provider (IdP)
to issue user identities to the ood web application (SP).  This
role is pre-configured to use the samltest.id IdP for testing.

All authentication handshaking is handled by the web browser used to
access the ood web application.  In a normal deployment, your
ood node will have a host name registered in DNS.  You can access
this host name and get Shibboleth metadata for our SP from it's custom
metadata url, e.g. https://ood.example.org/Shibbolth.SSO/Metadata. This
metadata can be saved and uploaded to  https://samltest.id/upload.php.  After
uploading, you should be able to log in to the ood app using the test
accounts from samltest.id.

Notes:
* samltest.id should only be used during development since it
is not a production IdP.
* you likely want to use a different name than the above to avoid
conflicting with other users of samltest.id.

## Isolated Development Environments

If you are working in an isolated development environment, for example your ood
is running on a local Vagrant VM or in some other environment where
it doesn't make any sense to use DNS, then you should create a host to IP
mapping on the client from which you are testing (i.e. your laptop's
`/etc/hosts` file).  This will maps a host nameto your dev ood and let you use
that instead of an the IP address at which your dev ood instance is running.
Once that's in place you can follow the steps above to register your dev
instance's SP metadata with samltest.id.

For example, if your ood dev box is accessible at port 8080 on your local laptop
ip 127.0.0.1, then you can add an entry like this to /etc/hosts
```
127.0.0.1 localhost ood-dev.example.org
```

After that, you can access the dev instance metadata url
http://ood-dev.example.org:8080/Shibboleth.SSO/Metadata, save the Metadata
file, and upload that file to https://samltest.id/upload.php.  Finally, you can
test access your ood dev instance at  http://ood-dev.example.org:8080

## Common Shibboleth Errors

If you attempt to log into your dev ood instance and see an "Unable to Respond"
error like the following:

> Web Login Service - Unable to Respond
> The login service was unable to identify a compatible way to respond to the requested application. This is generally due to a misconfiguration on the part of the application and should be reported to the application's support team or owner.

Then you aren't using a host name for your dev instance for which samltest.id
has metadata. Register the metadata associated with the host name you are using
to access your dev instance or make sure you are using the correct host name to
access our dev instance.

If you see a message about "opensaml::FatalProfileException" with the message:

> A valid authentication statement was not found in the incoming message.

then you need to correctly update samltest.id with the current metadata for your
dev instance.  Simply get the current copy of the metadata at the metadata URL
and upload it to samltest.id again.  The new metadata will overwrite the old.
