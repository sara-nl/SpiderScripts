# SpiderScripts
Welcome! These are a few scripts that we use at SURF to work with [Spider](https://doc.spider.surfsara.nl/en/latest/Pages/about.html).

## ADA
ADA stands for "Advanced dCache API". It is a client that talks to the dCache storage system API to get all kinds of information like directory listings and file checksums, and to do things like renaming, moving, deleting, staging (restoring from tape), and subscribing to server-sent-events so that you can automate actions when new files are written or files are staged. ADA does not transfer files; we suggest you use [Rclone](https://rclone.org/) for that.

### Installation
ADA is pre-installed and ready to use on Spider. If you want to use ADA elsewhere, you can clone this repository:

```
git clone https://github.com/sara-nl/SpiderScripts.git
cd SpiderScripts
```
Install dependencies (if not already installed on your system):
```
brew install jq
brew install rclone
```
There are also optional dependencies to run tests and create macaroons:
```
brew install shunit2
pip install pymacaroons
wget https://raw.githubusercontent.com/sara-nl/GridScripts/master/view-macaroon -P ada
wget https://raw.githubusercontent.com/sara-nl/GridScripts/master/get-macaroon -P ada
```

To test the installation, run:
```
tests/unit_test.sh
```

The unit tests will perform a dry-run, i.e. commands are not actually send to the dCache API, but simply printed and compared to what is expected. To perform an integration test, where commands are actually executed on the dCache storage, you must first create a configuration file `tests/test.conf`. See `tests/test_example.conf` for what information is needed. Then run:
```
tests/integration_test.sh
```

### Documentation

For an overview of the commands and options, run:
```
ada --help
```

Read further how to use ADA in the [Spider Documentation](https://doc.spider.surfsara.nl/en/latest/Pages/storage/ada-interface.html).