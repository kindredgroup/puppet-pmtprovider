require 'puppet/provider/package'
require 'puppet/face'

Puppet::Type.type(:package).provide :pmt, :parent => Puppet::Provider::Package do

  desc "Manages puppet modules as packages via the Puppet Module Tool"

  has_feature :versionable, :install_options

  @@module = Puppet::Face[:module, :current]

  def self.instances
    # dont know how to implement this in any reliable fashion
    # but afaik only affects "puppet resource package" reverse lookup
    {}
  end

  def latest
    options = self.class.parse_options(@resource[:install_options])
    @@module.search(@resource[:name], options)[:answers][0]['version']
  end

  def install
    should = @resource.should(:ensure)
    options = self.class.parse_options(@resource[:install_options])
    if options.has_key? :modulepath
      options[:target_dir] = options[:modulepath]
    end
    case should
    when true, false, Symbol
      @@module.install(@resource[:name], options)
    else
      options[:version] = @resource[:ensure]
      is = self.query
      if is
        if Puppet::Util::Package.versioncmp(should, is[:ensure]) > 0
          self.debug "Upgrading module #{@resource[:name]} from version #{is[:ensure]} to #{should}"
          @@module.upgrade(@resource[:name], options)
        else Puppet::Util::Package.versioncmp(should, is[:ensure]) < 0
          self.debug "Downgrading module #{@resource[:name]} from version #{is[:ensure]} to #{should}"
          options[:force] = true
          @@module.install(@resource[:name], options)
        end
      end
    end
  end

  def uninstall
    @@module.uninstall(@resource[:name], self.class.parse_options(@resource[:install_options]))
  end

  def self.parse_options install_options
    opts = {}
    install_options.each do |x|
      x.each do |key, value|
        opts[key.to_sym] = value
      end
    end
    opts
  end

  def query
    # http://stackoverflow.com/questions/20283152/puppet-package-provider-what-is-the-query-method-for
    # also look in rpm.rb provider in core puppet
    @property_hash.update(self.class.query_hash(@resource))
    @property_hash.dup
  end

  def self.query_hash rs
    response = {}
    @@module.list(self.parse_options(rs[:install_options]))[:modules_by_path].each do |module_path, modules|
      modules.each do |mod|
        if mod.forge_name == rs[:name]
          response[:instance] = "#{mod.forge_name}-#{mod.version}"
          response[:ensure] = mod.version
          response[:provider] = self.name
        end
      end
    end
    response
  end

  def update
    self.install
  end

end
