# SpiderScripts
Welcome! These are a few scripts that we use at SURFsara to work with Spider.

## Ada
Ada stands for "Advanced dCache API". It is a client that talks to the dCache storage system API to get all kinds of information like directory listings and file checksums, and to do things like renaming, moving, deleting, staging (restoring from tape), and subscribing to server-sent-events so that you can automate actions when new files are written or files are staged. Ada does not transfer files; we suggest you use Rclone (https://rclone.org/) for that.
