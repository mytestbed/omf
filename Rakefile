task :default => 'omf_dev:install_omf_dev'

OMF_VERSION = '5.4'
ROOT = File.expand_path(File.dirname(__FILE__))

namespace :omf_dev do
  desc 'Install OMF components in local development environment.'
  task :install do
    # COMMON
    #
    symlink = "/usr/share/omf-common-#{OMF_VERSION}"
    File.symlink("#{ROOT}/omf-common/ruby/", symlink) and puts symlink unless File.symlink?(symlink)

    # OML
    #
    symlink = "/usr/share/omf-oml-#{OMF_VERSION}"
    File.symlink("#{ROOT}/omf-oml/ruby/", symlink) and puts symlink unless File.symlink?(symlink)

    # Experiment Controlle
    #
    symlink = "/etc/omf-expctl-#{OMF_VERSION}"
    File.symlink("#{ROOT}/omf-expctl/etc/omf-expctl", symlink) and puts symlink unless File.symlink?(symlink)

    symlink = "/usr/share/omf-expctl-#{OMF_VERSION}"
    File.symlink("#{ROOT}/omf-expctl/ruby", symlink) and puts symlink unless File.symlink?(symlink)

    symlink = "/usr/share/omf-expctl-#{OMF_VERSION}/repository"
    File.symlink("#{ROOT}/omf-expctl/share/repository", symlink) and puts symlink unless File.symlink?(symlink)

    symlink = "/usr/bin/omf-#{OMF_VERSION}"
    File.symlink("#{ROOT}/omf-expctl/bin/omf", symlink) and puts symlink unless File.symlink?(symlink)

    # Aggregate Manager
    symlink = "/etc/omf-aggmgr-#{OMF_VERSION}"
    File.symlink("#{ROOT}/omf-aggmgr/etc/omf-aggmgr", symlink) and puts symlink unless File.symlink?(symlink)

    symlink = "/usr/share/omf-aggmgr-#{OMF_VERSION}"
    File.symlink("#{ROOT}/omf-aggmgr/ruby", symlink) and puts symlink unless File.symlink?(symlink)

    symlink = "/usr/share/omf-aggmgr-#{OMF_VERSION}"
    File.symlink("#{ROOT}/omf-aggmgr/ruby", symlink) and puts symlink unless File.symlink?(symlink)

    symlink = "/usr/sbin/omf-aggmgr-#{OMF_VERSION}"
    File.symlink("#{ROOT}/omf-aggmgr/sbin/omf-aggmgr", symlink) and puts symlink unless File.symlink?(symlink)

    symlink = "/usr/sbin/omf_create_psnode-#{OMF_VERSION}"
    File.symlink("#{ROOT}/omf-aggmgr/sbin/omf_create_psnode", symlink) and puts symlink unless File.symlink?(symlink)
  end

  desc 'Remove OMF components from local development environment.'
  task :remove do
    [
      "/usr/share/omf-common-#{OMF_VERSION}",
      "/usr/share/omf-oml-#{OMF_VERSION}",
      "/etc/omf-expctl-#{OMF_VERSION}",
      "/usr/share/omf-expctl-#{OMF_VERSION}/repository",
      "/usr/share/omf_expctl-#{OMF_VERSION}",
      "/usr/bin/omf-#{OMF_VERSION}",
      "/etc/omf-aggmgr-#{OMF_VERSION}",
      "/usr/share/omf-aggmgr-#{OMF_VERSION}",
      "/usr/share/omf-aggmgr-#{OMF_VERSION}",
      "/usr/sbin/omf-aggmgr-#{OMF_VERSION}",
      "/usr/sbin/omf_create_psnode-#{OMF_VERSION}"
    ].each do |s|
      File.unlink(s) if File.symlink?(s)
    end
  end
end
