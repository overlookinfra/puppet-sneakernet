require 'logger'
require 'sinatra/base'
require 'cgi'
require 'uri'
require 'ripper'

MAXSIZE = 100000  # something like 3,000 lines of code

class PuppetSneakernet < Sinatra::Base
  require 'date'
  require 'minitar'
  require 'zlib'
  require 'puppet_forge'
  require 'puppetfile-resolver'
  require 'puppetfile-resolver/puppetfile/parser/r10k_eval'

  PuppetForge.user_agent = 'Puppet Sneakernet/0.0.1'

  set :logging, true
  set :strict, true
  set :root, File.dirname(__FILE__) +'/..'

  enable :sessions

  before do
    env["rack.logger"] = settings.logger if settings.logger

    if settings.csrf
      session[:csrf] ||= SecureRandom.hex(32)
      response.set_cookie 'authenticity_token', {
        :path    => '/',
        :value   => session[:csrf],
        :expires => Time.now + (60 * 60 * 24),
      }
    end
  end

  get '/' do
    erb :index
  end

  post '/download' do
    logger.info "Packing Puppetfile from #{request.ip}."
    logger.debug "Packing Puppetfile from #{request.ip}: #{params['code']}"

    validate_request!
    sanitize_code!

    pack_puppetfile
  end


  not_found do
    halt 404, "You shall not pass! (page not found)"
  end

  helpers do
    def validate_request!
      csrf_safe!
      check_size_limit!
    end

    def csrf_safe!
      return true unless settings.csrf
      if session[:csrf] == params['_csrf'] && session[:csrf] == request.cookies['authenticity_token']
        true
      else
        logger.warn 'CSRF attempt detected. Ensure that server time is correct.'
        logger.debug "session: #{session[:csrf]}"
        logger.debug "  param: #{params['_csrf']}"
        logger.debug " cookie: #{request.cookies['authenticity_token']}"

        halt 403, 'Request validation failed.'
      end
    end

    def check_size_limit!
      content = request.body.read
      request.body.rewind

      if content.size > MAXSIZE
        halt 400, "Submitted code size is #{content.size}, which is larger than the maximum size of #{MAXSIZE}."
      end
    end

    def sanitize_code!
      variants = [:command, :call, :fcall, :vcall]

      tokens  = Ripper.sexp(params['code']).flatten
      indices = tokens.map.with_index { |a, i| variants.include?(a) ? i : nil }.compact
      methods = indices.map { |i| tokens[i + 2] }.flatten.compact

      methods.reject! { |name| ['mod', 'forge', 'moduledir'].include? name }
      halt 400, "Arbitrary Ruby code is not supported. Please remove '#{methods.join(', ')}' and try again." unless methods.empty?
    end

    def pack_puppetfile
      begin
        # Parse the Puppetfile into an object model
        puppetfile = ::PuppetfileResolver::Puppetfile::Parser::R10KEval.parse(params['code'])
      rescue PuppetfileResolver::Puppetfile::Parser::ParserError => e
        logger.error 'Syntax error in Puppetfile'
        halt 400, "Syntax error in Puppetfile: #{e.message}"
      end

      # Make sure the Puppetfile is valid
      unless puppetfile.valid?
        logger.error 'Puppetfile is not valid'
        puppetfile.validation_errors.each { |err| logger.warn err }
        halt 400, 'Puppetfile is not valid'
      end

      resolver = PuppetfileResolver::Resolver.new(puppetfile, nil)
      result   = resolver.resolve(strict_mode: true)

      result.validation_errors.each { |err| logger.warn "Dependency resolution: #{err}"}

      unless result.dependency_graph.count > 0
        logger.warn 'No modules resolved!'
        halt 400, 'No modules resolved, press back and try again.'
      end

      buffer = StringIO.new
      tmpdir = Dir.mktmpdir
      Dir.mktmpdir('sneakernet') do |dir|
        Dir.chdir(dir) do
          Dir.mkdir('modules')

          File.open('Puppetfile', "w+") do |puppetfile|
            result.dependency_graph.each do |dep|
              mod = dep.payload
              next unless mod.is_a? PuppetfileResolver::Models::ModuleSpecification

              # record the module we're downloading
              puppetfile.write "mod '#{dep.payload.owner}-#{dep.payload.name}', '#{dep.payload.version}'\n"

              release_slug    = "#{dep.payload.owner}-#{dep.payload.name}-#{dep.payload.version}"
              release_tarball = release_slug + ".tar.gz"
              destination     = "modules/#{dep.payload.name}"

              logger.debug "Retrieving #{release_slug}"

              begin
                release = PuppetForge::Release.find(release_slug)
                release.download(Pathname(release_tarball))
                release.verify(Pathname(release_tarball))
                PuppetForge::Unpacker.unpack(release_tarball, destination, tmpdir)
                FileUtils.rm(release_tarball)

              rescue Faraday::BadRequestError
                logger.error "Error retrieving #{release_slug}"
                halt 400, "Error retrieving #{release_slug}"
              end
            end
          end

          Minitar.pack('.', Zlib::GzipWriter.new(buffer))
        end
      end
      FileUtils.rm_rf(tmpdir)

      attachment("Puppetfile.packed.#{Date.today}.tar.gz")
      buffer.string
    end

  end
end
