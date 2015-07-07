solr-map-reduce-example
=======================

This project is meant to provide an example of how to build Solr indexes with MapReduce.

This a fork from the Mark Miller's project (https://github.com/markrmiller/solr-map-reduce-example).

The original script called run-example has been splitted into several scripts :

* setup-example.sh : downloads, installs and starts both hadoop (hdfs and yarn) and a 2 nodes solrcloud

* stop-hadoop-solr.sh : stops hadoop and solrcloud

* start-hadoop-solr.sh : starts hadoop and solrcloud

* run-example.sh : index twitter data into with a map-reduce job and the GoLive feature


These scripts are meant as both a way to quickly see something working and as a reference for building Solr indexes on your real Hadoop cluster.

This is not an example of good production settings! This setup is meant for a single node demo system.


Running the Example
----------------------

Download the repository files using the 'Download ZIP' button and extract them to a new directory. From that directory, run setup-example.sh then run-example.sh scripts and sit back and watch.


Other files
----------------------

log4j.properties - the log4j config file attached to the map-reduce job

readAvroContainer.conf - a Morphline for reading avro files

sample-statuses-20120906-141433-medium.avro - sample Twitter format data

schema.xml - a schema for the sample Twitter formated data


Software Versions
----------------------

This is currently using:

Hadoop 2.6.0

Solr 4.10.4


Web URLs
----------------------

Solr http://127.0.0.1:8983/solr
NameNode http://127.0.0.1:50075
Yarn http://127.0.0.1:8042


Links
----------------------

Running Solr on HDFS - https://cwiki.apache.org/confluence/display/solr/Running+Solr+on+HDFS

Morphlines - http://kitesdk.org/docs/current/kite-morphlines/index.html

