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
    pmtface = Puppet::Face[:module, :current]
    pmtface.list[:modules_by_path].map do |module_path, modules|
      modules.map do |mod|
        {
          :name => mod.metadata["name"],
          :ensure => mod.metadata["version"],
          :install_options => [{"--modulepath" => module_path}],
          :provider => self.name
        }
      end
    end.flatten.map { |x| new(x) }
  end

  def latest
    pmt_search[:answers][0]['version']
  end

  def install
    is = self.query
    if is
      if Puppet::Util::Package.versioncmp(@resource[:ensure], is[:ensure]) < 0
        pmt_install true
      else
        pmt_install false
      end
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
        if x.metadata["name"] == @resource[:name] || x.metadata["forge_name"] == @resource[:name]
          response[:instance] = "#{@resource[:name]}-#{x.metadata['version']}"
          response[:ensure] = x.metadata["version"]
          response[:provider] = self.name
        end
      end
    end
    response
  end

  def update
    pmt_upgrade
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
    args = ["module", "upgrade"]
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
