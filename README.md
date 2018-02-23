# cm-exportxml

Utility script to download the CDH client configuration files from Cloudera Manager via HTTP/HTTPS. This script can be use in a cron script to regularly pull the latest XML configuration files.

# Usage
Run the script without any argument to see the list of supported arguments:

```
$ ./exportxml.sh

Cloudera Haoop Client XML Files Downloader v1.0

USAGE:
  ./exportxml.sh [OPTIONS]

MANDATORY OPTIONS:
  -h, --host <arg>
        Cloudera Manager URL (e.g. http://cm-mycluster.com:7180).

  -u, --user <arg>
        Cloudera Manager username.

OPTIONS:
  -p, --password <arg>
        Cloudera Manager password. Will be prompted if unspecified.

  -c, --pwcmd <arg>
        Executable shell command that will output the Cloudera Manager password.

  -s, --services <arg>
        CDH service to download the client configuration zip file.
        Possible values are hdfs, hive, yarn, spark and spark2. Default is hdfs.

  -o, --outputdir <arg>
        Directory to save the zip file containing the client configuration files.
	  Default is current working dir.

  -n, --cluster <arg>
        Export only for a specific cluster. If not specified, the first cluster
        will be selected.
        
```

No administrative privileges are required to download the client configuration from CM. Create a dedicated CM service account with only read-only privilege to use with this script.

Use the -c/--pwcmd argument to specify a command/script that print the CM password when executed. This allows store the password as encrypted so that it can not easily read in clear text.

# Examples

Run the script with just the CM URL, username and password to download the zip file containing the client configuration files for HDFS.

```
$ ./exportxml.sh -h http://mktest-1.gce.cloudera.com:7180 -u guest -p guest
Sat Feb 24 00:11:40 +08 2018 [INFO ] Cloudera Manager seems to be running
Sat Feb 24 00:11:42 +08 2018 [INFO ] No cluster specified. Retrieved name of first cluster: MelTest Cluster
Sat Feb 24 00:11:42 +08 2018 [INFO ] Cluster name 'MelTest Cluster' is valid.
Sat Feb 24 00:11:44 +08 2018 [INFO ] Service hdfs client XML files downloaded to /Users/ckoh/Documents/Work/github/cm-exportxml/hdfs_MelTest Cluster.zip
```

The content of the zip file:

```
$ unzip -l hdfs_MelTest\ Cluster.zip
Archive:  hdfs_MelTest Cluster.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
      314  02-23-2018 08:11   hadoop-conf/log4j.properties
      315  02-23-2018 08:11   hadoop-conf/ssl-client.xml
     3555  02-23-2018 08:11   hadoop-conf/core-site.xml
     1594  02-23-2018 08:11   hadoop-conf/topology.py
      424  02-23-2018 08:11   hadoop-conf/topology.map
     2696  02-23-2018 08:11   hadoop-conf/hadoop-env.sh
     1757  02-23-2018 08:11   hadoop-conf/hdfs-site.xml
---------                     -------
    10655                     7 files
```