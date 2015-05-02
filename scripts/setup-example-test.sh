#!/bin/bash

export HOME="$( cd "$( dirname "$0" )/.." && pwd )"

# Variables initialisation
. $HOME/scripts/setenv.sh
cd $HADOOP_HOME


$ bin/hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.6.0.jar grep input output 'dfs[a-z.]+'