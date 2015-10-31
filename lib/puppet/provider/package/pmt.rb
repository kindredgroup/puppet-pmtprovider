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
    else
      pmt_install true
    end
  end

  def update
    if @property_hash[:ensure] == :absent
      pmt_install false
    else
      pmt_upgrade
    end
  end

  def uninstall
    pmt_uninstall
  end

  def query
    # http://stackoverflow.com/questions/20283152/puppet-package-provider-what-is-the-query-method-for
    # also look in rpm.rb provider in core puppet
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

  def install_options
    join_options(@resource[:install_options])
  end

  def pmt_list
    cmd = [command(:puppetcmd), "module", "list", "--render-as=yaml"]
    cmd.push(install_options.reject { |item| ['--force', '--ignore-dependencies'].include? item })
    output = execute(cmd)
    YAML.load(output)
  end

  def pmt_search
    cmd = [command(:puppetcmd), "module", "search", "--render-as=yaml"]
    cmd.push(install_options.reject { |item| ['--force', '--ignore-dependencies'].include? item })
    cmd << "--log_level=crit"  # because search has some info logging that ruins the yaml format
    cmd << @resource[:name]
    YAML.load(execute(cmd))
  end

  def pmt_install force
    cmd = [command(:puppetcmd), "module", "install"]
    cmd.push(install_options)
    cmd << "--force" if force && !cmd.include?("--force")
    cmd << @resource[:name]
    cmd << "--version=#{@resource[:ensure]}" unless @resource[:ensure].is_a? Symbol
    execute(cmd)
  end

  def pmt_upgrade
    cmd = [command(:puppetcmd), "module", "upgrade", "--ignore-changes"]
    cmd.push(install_options)
    cmd << @resource[:name]
    cmd << "--version=#{@resource[:ensure]}" unless @resource[:ensure].is_a? Symbol
    execute(cmd)
  end

  def pmt_uninstall
    cmd = [command(:puppetcmd), "module", "uninstall"]
    cmd.push(install_options)
    cmd << @resource[:name]
    execute(cmd)
  end

end
