#export HADOOP_HOME=/opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce #MR1
export HADOOP_HOME=/opt/cloudera/parcels/CDH/lib/hadoop-mapreduce #MR2

export HADOOP_HOME2=/opt/cloudera/parcels/CDH/lib/hadoop
ant -f build_pegasus.xml makejar
