#!/usr/bin/env bash
# =============================================================================
# spark-env.sh  --  spark-manager (cluster master)
# Path: /opt/spark/conf/spark-env.sh
# =============================================================================

# Hostname the master binds to and advertises. Workers register against
# spark://spark-manager:7077, so this must resolve on every node
# (/etc/hosts or DNS).
export SPARK_MASTER_HOST='spark-manager'

# Heap for the master *daemon* itself. The master only tracks cluster state,
# so this is small by design.
#
# NOTE: the correct variable is SPARK_DAEMON_MEMORY. There is no
# SPARK_MASTER_MEMORY in Spark -- setting it is a silent no-op.
export SPARK_DAEMON_MEMORY=1G
