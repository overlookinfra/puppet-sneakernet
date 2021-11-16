# Puppet Sneakernet

This is a simple POC web service that will turn a `Puppetfile` into a tarball
of a complete Puppet environment. All you need to do is paste the contents of
the `Puppetfile` into the textbox and press *Download*.

This will resolve the dependencies of your `Puppetfile`, create an environment
from them, and then pack the whole thing into a tarball. Save that tarball to
a USB key, then perform any review or approval required by your security and
quality policies.

Once approved, walk the USB key with the modules tarball across your air-gap
and uncompress them into your codebase. For example:

```
$ cd /etc/puppetlabs/code/environments/staging
$ tar -xvzf /media/USB/Puppetfile.packed.<date>.tar.gz --strip-components=1
```

We recommend using an MD5 checksum to prove that the tarball you deploy is the
same as the tarball you get approved. You can generate that with one of the
following commands, depending on your platform.

* `md5 Puppetfile.packed.<date>.tar.gz > md5sum`
* `md5sum Puppetfile.packed.<date>.tar.gz > md5sum`

## *⚠️ Warning! ⚠️*

Resolving dependencies in a `Puppetfile` means that you'll be installing code
that you didn't specifically request into your environment. Make sure you audit
the modules from the tarball, not just code from the source repositories of the
modules you specified in your `Puppetfile`.

