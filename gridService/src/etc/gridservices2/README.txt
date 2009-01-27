# Thierry - 
# To Install GridServices 2:
#
# - Install package using 'dpkg' or 'apt-get'
#   ( example: 'sudo dpkg --instal gridservices2_2.1.0_all.deb' )
#
# - Go to '/etc/gridservices2/'
#
# - Create a directory 'enabled'
#
# - Inside this directory 'enabled', create symlinks to the services you would like to
#   enable from the ones available in the directory 'available'
#   ( example: 'sudo ln -s ../available/frisbee.yaml.winlab frisbee.yaml' )
#   (          'sudo ln -s ../available/pxe.yaml.winlab pxe.yaml' )
#
# --- still necessary now ?
# - Edit '/opt/gridservices2-2.1.0/app/ogs.rb', search for the string 'PACKAGING HACK' and 
#   set the 'if' condition to 'false'
#   (TODO: Find another way to do that...)
# ---
#
# - Run the GridServices with 'sudo /etc/init.d/gridservices2 start'
#
# - Log file should be at '/var/log/gridservices2.log'
#
# - Default port on which the GS2 is listening should be '5022'
#
# For test/debug purpose only:
# sudo /usr/sbin/gridservices2 --port 5022
