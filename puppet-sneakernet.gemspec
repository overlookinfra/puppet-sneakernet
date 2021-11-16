require 'date'

Gem::Specification.new do |s|
  s.name              = "puppet-sneakernet"
  s.version           = '0.0.2'
  s.date              = Date.today.to_s
  s.summary           = "Helps you retrieve the Puppet Forge modules you need for an air-gapped environment."
  s.homepage          = "https://github.com/puppetlabs/puppet-sneakernet/"
  s.email             = "community@puppet.com"
  s.authors           = ["Puppetlabs", "Ben Ford"]
  s.license           = "Apache-2.0"
  s.require_path      = "lib"
  s.executables       = %w( puppet-sneakernet )
  s.files             = %w( CHANGELOG.md README.md LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("doc/**/*")
  s.files            += Dir.glob("views/**/*")
  s.files            += Dir.glob("public/**/*")
  s.add_dependency      "sinatra",               "~> 2.0"
  s.add_dependency      "minitar"
  s.add_dependency      "puppet_forge"
  s.add_dependency      "puppetfile-resolver",   "~> 0.5.0"

  s.description       = <<-desc
    Puppet Sneakernet is a simple web service that turns a Puppetfile into a tarball
    of the complete environment that Puppetfile represents, with all the module
    dependencies resolved. Just untar that into the proper environmentpath on an
    air-gapped Puppet server.
  desc
end
