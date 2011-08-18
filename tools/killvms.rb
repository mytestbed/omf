#!/usr/bin/ruby -I/usr/share/omf-common-5.4

28.upto(30) { |n|
  1.upto(10) { |k|
    system("ssh node#{n} 'vzctl stop #{k}; vzctl destroy #{k}'")  
  }
  system("ssh node#{n} '/etc/init.d/omf-resmgr-5.4 restart'")
}