require 'erb'
require 'master_manipulator'
require 'dsc_utils'
test_name 'MODULES-2965 - C96624 - Apply DSC Manifest with "ensure" Set to "absent"'

# Init
local_files_root_path = ENV['MANIFESTS'] || 'tests/manifests'

# Manifest
fake_name = SecureRandom.uuid
test_file_contents = SecureRandom.uuid
dsc_manifest = <<-MANIFEST
dsc_puppetfakeresource {'#{fake_name}':
  dsc_ensure          => 'present',
  dsc_importantstuff  => '#{test_file_contents}',
  dsc_destinationpath => 'C:\\#{fake_name}'
}
MANIFEST

# Teardown
teardown do
  confine_block(:to, :platform => 'windows') do
    step 'Remove Test Artifacts'
    on(agents, "rm -rf /cygdrive/c/#{fake_name}")
  end

  uninstall_fake_reboot_resource(master)
end

# Setup
step 'Copy Test Type Wrappers'
install_fake_reboot_resource(master)
step 'Inject "site.pp" on Master'
site_pp = create_site_pp(master, :manifest => dsc_manifest)
inject_site_pp(master, get_site_pp_path(master), site_pp)

# Tests
confine_block(:to, :platform => 'windows') do
  agents.each do |agent|
    step 'Apply Manifest to Create File'
    on(agent, puppet('agent -t --environment production'), :acceptable_exit_codes => [0,2]) do |result|
      assert_match(/Stage\[main\]\/Main\/Node\[default\]\/Dsc_puppetfakeresource\[#{fake_name}\]\/ensure\: created/, result.stdout, 'DSC Resource missing!')
      assert_no_match(/Error:/, result.stderr, 'Unexpected error was detected!')
    end
  end
end

# New manifest to remove value.
dsc_remove_manifest = <<-MANIFEST
dsc_puppetfakeresource {'#{fake_name}':
  dsc_ensure          => 'absent',
  dsc_importantstuff  => '#{test_file_contents}',
  dsc_destinationpath => 'C:\\#{fake_name}'
}
MANIFEST

step 'Inject "site.pp" on Master'
site_pp = create_site_pp(master, :manifest => dsc_remove_manifest)
inject_site_pp(master, get_site_pp_path(master), site_pp)

confine_block(:to, :platform => 'windows') do
  agents.each do |agent|
    step 'Apply Manifest to Remove File'
    on(agent, puppet('agent -t --environment production'), :acceptable_exit_codes => [0,2]) do |result|
      assert_no_match(/Error:/, result.stderr, 'Unexpected error was detected!')
    end

    step 'Verify Results'
    # if this file exists, 'absent' didn't work
    on(agent, "test -f /cygdrive/c/#{fake_name}", :acceptable_exit_codes => [1])
  end
end
