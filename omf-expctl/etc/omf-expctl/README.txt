POST INSTALLATION
-----------------

After installing the nodeHandler4 packages, you have to create a link to the appropriate configuration file depending on your platform.

1) At WINLAB:
- the correct config file is /etc/omf-expctl/nodehandler.yaml.winlab
- to create the link, use the command:
  sudo ln -s /etc/omf-expctl/nodehandler.yaml.winlab /etc/omf-expctl/nodehandler.yaml

2) At NICTA:
- the correct config file is /etc/omf-expctl/nodehandler.yaml.nicta
- to create the link, use the command:
  sudo ln -s /etc/omf-expctl/nodehandler.yaml.nicta /etc/omf-expctl/nodehandler.yaml
