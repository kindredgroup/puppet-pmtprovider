require 'spec_helper'
describe 'pmtprovider' do

  context 'with defaults for all parameters' do
    it { should contain_class('pmtprovider') }
  end
end
