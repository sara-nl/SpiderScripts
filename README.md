# SpiderScripts
Welcome! These are a few scripts that we use at SURF to work with Spider.

## ADA
ADA stands for "Advanced dCache API". It is a client that talks to the dCache storage system API to get all kinds of information like directory listings and file checksums, and to do things like renaming, moving, deleting, staging (restoring from tape), and subscribing to server-sent-events so that you can automate actions when new files are written or files are staged. ADA does not transfer files; we suggest you use [Rclone](https://rclone.org/) for that.

Ada can authenticate to a dCache API using basic authentication (username/password), X509 authentication (user certificates or proxies), Macaroons, and OIDC tokens. Please verify that the dCache API you talk to, supports the desired authentication method.

ADA is pre-installed on the SURF Spider cluster. If you want to use ADA elsewhere, you can clone this repository.

For an overview of the commands and options, run:
```
ada --help
```

Read further how to use ADA in the [Spider Documentation](https://doc.spider.surfsara.nl/en/latest/Pages/storage/ada-interface.html).
