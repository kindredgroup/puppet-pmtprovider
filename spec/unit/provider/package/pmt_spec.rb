require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:pmt)

context 'installing vendor-modulename' do

  describe provider_class do
    #include PuppetSpec::Fixtures

    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => 'vendor-modulename',
        :ensure   => :installed,
        :provider => 'pmt'
      )
    end

    let(:provider) do
      provider = provider_class.new
      provider.resource = resource
      provider
    end

    before :each do
      resource.provider = provider
    end

    describe 'provider features' do
      it { is_expected.to be_versionable }
      it { is_expected.to be_install_options }
      [:install, :latest, :update, :install_options].each do |method|
        it "should have a(n) #{method}" do
          is_expected.to respond_to(method)
       end
     end
   end

  # describe 'when installing' do
  #   it 'should use the path to puppet with arguments' do
  #     provider_class.stubs(:command).with(:puppetcmd).returns "/my/puppet"
  #     provider.expects(:execute).with {|args| args.join(' ') == "/my/puppet module install vendor-modulename" }.returns ""
  #     provider.install
  #   end
  # end

  end

end
