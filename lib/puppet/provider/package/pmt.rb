require 'puppet/provider/package'
require 'puppet/face'
require 'yaml'

Puppet::Type.type(:package).provide :pmt, :source => :pmt, :parent => Puppet::Provider::Package do

  desc "Manages puppet modules as packages using the puppet module tool

  This provider supports the `install_options` attribute, which allows command-line flags
  to be passed to the execution of the puppet module tool. For example:

  package { 'puppetlabs-apache':
    ensure => present,
    provider => pmt,
    install_options [
      {
        '--modulepath' => '/custom/module/path'
      },
      {
        '--module_repository' => 'https://forge.example.com'
      }
    ]
  }
  "

  has_feature :versionable
  has_feature :install_options

  commands :puppetcmd => 'puppet'

  def self.instances
    {}
  end

  def latest
    pmt_search[:answers].select { |a|
      if @resource[:name].include?("/") && a["current_release"]["metadata"].has_key?("forge_name")
        a["current_release"]["metadata"]["forge_name"] == @resource[:name]
      elsif @resource[:name].include?("-") && a["current_release"]["metadata"].has_key?("name")
        a["current_release"]["metadata"]["name"] == @resource[:name]
      end
    }[0]["current_release"]["metadata"]["version"]
  end

  def install
    if @property_hash[:ensure] == :absent
      pmt_install false
    elsif @resource[:ensure] == :latest
      pmt_upgrade
    elsif Puppet::Util::Package.versioncmp(@resource[:ensure], @property_hash[:ensure]) < 0
      pmt_install true
    elsif Puppet::Util::Package.versioncmp(@resource[:ensure], @property_hash[:ensure]) > 0
      pmt_upgrade
    else
      pmt_install false
    end
  end

  def uninstall
    pmt_uninstall
  end

  def query
    # http://stackoverflow.com/questions/20283152/puppet-package-provider-what-is-the-query-method-for
    # also look in rpm.rb provider in core puppet
    @property_hash.update(query_hash)
    @property_hash.dup
  end

  def query_hash
    response = {}
    pmt_list[:modules_by_path].each do |module_path, mod|
      mod.each do |x|
        keyname = ""
        if @resource[:name].include?("/") && x.metadata.has_key?("forge_name")
          keyname = "forge_name"
        elsif @resource[:name].include?("-") && x.metadata.has_key?("name")
          keyname = "name"
        end
        if x.metadata[keyname] == @resource[:name]
          response[:instance] = "#{@resource[:name]}-#{x.metadata['version']}"
          response[:ensure] = x.metadata["version"]
          response[:provider] = self.name
        end
      end
    end
    response
  end

  def update
    # ensure => latest will send you here regardless of whetever anything is installed or not
    self.install
  end

  def pmt_list
    args = ["module", "list", "--render-as=yaml"]
    args.push(join_options(@resource[:install_options]))
    YAML.load(puppetcmd *args)
  end

  def pmt_search
    args = ["module", "search", "--render-as=yaml"]
    args.push(join_options(@resource[:install_options]))
    args << "--log_level=crit"  # because search has some info logging that ruins the yaml format
    args << @resource[:name]
    YAML.load(puppetcmd *args)
  end

  def pmt_install force
    args = ["module", "install"]
    args.push(join_options(@resource[:install_options]))
    args << "--force" if force
    args << @resource[:name]
    args << "--version=#{@resource[:ensure]}" unless @resource[:ensure].is_a? Symbol
    puppetcmd *args
  end

  def pmt_upgrade
    args = ["module", "upgrade", "--ignore-changes"]
    args.push(join_options(@resource[:install_options]))
    args << @resource[:name]
    args << "--version=#{@resource[:ensure]}" unless @resource[:ensure].is_a? Symbol
    puppetcmd *args
  end

  def pmt_uninstall
    args = ["module", "uninstall"]
    args.push(join_options(@resource[:install_options]))
    args << @resource[:name]
    puppetcmd *args
  end

end
