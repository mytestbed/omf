#!/bin/sh

SOURCE1=planetlab6.cs.duke.edu
SOURCE1=orca_node1

SOURCE2=ec2-23-20-77-153.compute-1.amazonaws.com

SINK=planetlab4.rutgers.edu
#SINK=planetlab-02.cs.princeton.edu

ruby -I ../../../omf-common/ruby -I ../../ruby ../../ruby/omf-expctl.rb -C omf-expct-gec13.yaml demo-gec13-v3.rb --log ../../etc/omf-expctl/omf-expctl_log.xml -- --source1 $SOURCE1 --sink $SINK --source2 $SOURCE2
