# SpiderScripts

Welcome! These are a few scripts that we use at SURF to work with the [Spider compute cluster](https://doc.spider.surfsara.nl/en/latest/Pages/about.html).

## ADA - Advanced dCache API

### About ADA

ADA is a client that talks to the [dCache storage system](https://dcache.org/) [API](https://www.dcache.org/manuals/UserGuide-10.2/frontend.shtml) to work with data in dCache.

#### Features

* List directory and file information
* List file checksums
* Rename, move and delete files and directories
* Work with labels on files: set labels, remove them, and search directories for files with labels
* Work with file metadata (extended attributes): set attributes, delete them, and search directories for files with certain attributes
* Stage files (restore from tape), check whether they are online or not
* Show available space in dCache
* Subscribe to server-sent-events to set up automated workflows

Many of these operations can be done recursively. For authentication, ADA supports X509, tokens (macaroons and OIDC) and basic auth (username/password), depending on the dCache configuration. 

#### Limitations

* ADA does not transfer files; we suggest you use [Rclone](https://rclone.org/) for that.
* ADA depends on dCache. The dCache system you work with may have limitations that impact ADA.

### Installation

ADA has been tested on Linux and MacOS. It is pre-installed and ready to use on the Spider compute cluster. If you want to use ADA elsewhere, you can clone this repository:

```
git clone https://github.com/sara-nl/SpiderScripts.git
cd SpiderScripts
```

Install dependencies (if not already installed on your system):
```
# MacOS
brew install jq rclone bash

# Redhat/Rocky/Alma
dnf install jq rclone
```

There are also optional dependencies to run tests and create macaroons:
```
brew install shunit2 (or "wget https://raw.githubusercontent.com/kward/shunit2/refs/heads/master/shunit2")
pip install pymacaroons
wget https://raw.githubusercontent.com/sara-nl/GridScripts/master/view-macaroon -P ada
wget https://raw.githubusercontent.com/sara-nl/GridScripts/master/get-macaroon -P ada
```

### Availability
The commands now are only available in the installed folder. To make them accessible from any location on your computer do:

#### MacOs

```
chmod +x ./ada
sudo ln -s ./ada /usr/local/bin/ada
sudo ln -s ./get-macaroon /usr/local/bin/get-macaroon
sudo ln -s ./view-macaroon /usr/local/bin/view-macaroon
```

Test with a new terminal and type in `ada --help`.

#### Linux

TODO



### Testing

To test the installation, run:
```
tests/unit_test.sh
```

The unit tests will perform a dry-run, i.e. commands are not actually sent to the dCache API, but simply printed and compared to what is expected. 

The integration test actually executes commands on the dCache API. Set up a configuration file `tests/test.conf` based on `tests/test_example.conf`. Then run:
```
tests/integration_test.sh
```

### Documentation

For an overview of the commands and options, run:
```
ada --help
```

Read further how to use ADA in the [Spider Documentation](https://doc.spider.surfsara.nl/en/latest/Pages/storage/ada-interface.html).
