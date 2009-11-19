POST INSTALLATION
-----------------

After installing the omf-expctl package, you have to create a link to the appropriate configuration file depending on your platform.

1) At WINLAB:
- the correct config file is /etc/omf-expctl-5.3/nodehandler.yaml.winlab
- to create the link, use the command:
  sudo ln -s /etc/omf-expctl-5.3/nodehandler.yaml.winlab /etc/omf-expctl-5.3/nodehandler.yaml

2) At NICTA:
- the correct config file is /etc/omf-expctl-5.3/nodehandler.yaml.nicta
- to create the link, use the command:
  sudo ln -s /etc/omf-expctl-5.3/nodehandler.yaml.nicta /etc/omf-expctl-5.3/nodehandler.yaml
