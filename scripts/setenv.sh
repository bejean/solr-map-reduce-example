#!/bin/bash

if [ -z "$HOME" ]; then
	export HOME="$( cd "$( dirname "$1" )" && pwd )"
fi;

# Working directory
export WORK_HOME="/opt/solr-mr"

export HADOOP_HOME=$WORK_HOME/hadoop
export HADOOP_CONF_DIR=$WORK_HOME/hadoop/etc/hadoop
export SOLR_HOME=$WORK_HOME/solr

## Solr + Hadoop Dists
#######################

# Using Hadoop 2.6.0
export HADOOP_VERSION="2.6.0"
export HADOOP_DISTRIB="hadoop-$HADOOP_VERSION"
export HADOOP_DISTRIB_URL="http://archive.apache.org/dist/hadoop/core/$HADOOP_DISTRIB/$HADOOP_DISTRIB.tar.gz"

# Using Solr 4.10.4
export SOLR_VERSION="4.10.4"
export SOLR_DISTRIB="solr-$SOLR_VERSION"
export SOLR_DISTRIB_URL="http://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/$SOLR_DISTRIB.tgz"

# collection to work with
export COLLECTION=collection1

