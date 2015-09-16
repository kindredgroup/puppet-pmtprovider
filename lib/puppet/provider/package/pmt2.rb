require 'puppet/provider/package'
require 'puppet/face'
require 'yaml'

Puppet::Type.type(:package).provide :pmt2, :source => :pmt2, :parent => Puppet::Provider::Package do

  #include Puppet::Util::Package

  desc "Manages puppet modules as packages via the Puppet Module Tool"

  has_feature :versionable
  has_feature :install_options

  commands :puppetcmd => 'puppet'

  def self.instances
    pmtface = Puppet::Face[:module, :current]
    pmtface.list[:modules_by_path].map do |module_path, modules|
      modules.map do |mod|
        {
          :name => mod.name,
          :ensure => mod.version,
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
    case @resource[:ensure]
    when true, false, Symbol
      pmt_install false
    else
      is = self.query
      if is
        if Puppet::Util::Package.versioncmp(@resource[:ensure], is[:ensure]) > 0
          self.debug "Upgrading module #{@resource[:name]} from version #{is[:ensure]} to #{@resource[:ensure]}"
          pmt_upgrade
        else Puppet::Util::Package.versioncmp(@resource[:ensure], is[:ensure]) < 0
          self.debug "Downgrading module #{@resource[:name]} from version #{is[:ensure]} to #{@resource[:ensure]}"
          pmt_install true
        end
      else
        pmt_install false
      end
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
    args << "--log_level=crit"
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

  def pmt_upgrade rs
    args = ["module", "upgrade"]
    args.push(join_options(@resource[:install_options]))
    args << "--force" if force
    args << @resource[:name]
    args << "--version=#{@resource[:ensure]}" unless @resource[:ensure].is_a? Symbol
    puppetcmd *args
  end

  def pmt_uninstall rs
    args = ["module", "uninstall"]
    args.push(join_options(@resource[:install_options]))
    args << "--force" if force
    args << @resource[:name]
    puppetcmd *args
  end

end
