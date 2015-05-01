#!/bin/bash

if [ -z "$HOME" ]; then
	export HOME="$( cd "$( dirname "$1" )" && pwd )"
fi;

export HADOOP_HOME=$HOME/hadoop
export HADOOP_CONF_DIR=$HOME/hadoop_conf/conf