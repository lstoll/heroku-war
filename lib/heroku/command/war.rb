require 'tmpdir'
require 'fileutils'
require 'pathname'
begin
  require 'json'
rescue LoadError
  display "json gem is required for the Repo plugin"
  exit(1)
end

WEBAPP_RUNNER_JAR = "http://repo1.maven.org/maven2/com/github/jsimone/webapp-runner/7.0.22.3/webapp-runner-7.0.22.3.jar"

# Slug manipulation
class Heroku::Command::War < Heroku::Command::BaseWithApp

  # war:deploy
  #
  # Deploy a .war to an app
  def deploy
    warfile = args.shift.downcase.strip rescue nil
    error "Invalid war file." unless warfile && File.exist?(warfile)

    warfilename = ""
    # Build a slug
    Dir.mktmpdir do |dir|
      builddir = File.join(dir, "build")
      slugfile = File.join(dir, "slugfile.img")
      Dir.mkdir(builddir)
      FileUtils.touch(slugfile)
      puts "---> Fetching webapp runner"
      res = heroku.get(WEBAPP_RUNNER_JAR)
      File.open(File.join(builddir, "webapp-runner.jar"), "w+") do |file|
        file.write res.body
      end

      system "ls #{builddir}"
      system "ls #{dir}"

      puts "---> Building slug"
      warfilename = Pathname.new(warfile).basename.to_s
      FileUtils.cp(File.expand_path(warfile), builddir)
      `#{mksquashfs_bin} #{builddir} #{slugfile} -all-root -noappend`

      slug_size = File.size(slugfile) / 1024.0 / 1024.0
      error "Error building slug" unless slug_size > 0
      puts "---> Compiled slug size is #{slug_size}MB"

      puts "---> Uploading slug"
      slug = File.read(slugfile)
      RestClient.put(release["slug_put_url"], slug, :content_type => nil)
    end
    puts "---> Slug upload create, creating release"
    payload = {
      "language_pack" => "WAR Deployer",
      "buildpack" => "heroku wardeploy",
      "process_types" => {"web" => "java -jar webapp-runner.jar --port $PORT #{warfilename}"},
      "addons" => release["addons"],
      # "config_vars" => {},
      "slug_version" => 2,
      "run_deploy_hooks" => true,
      "user" => heroku.user,
      "release_descr" => "Deploy WAR file",
      "head" => Digest::SHA1.hexdigest(Time.now.to_f.to_s),
      "slug_put_key" => release["slug_put_key"],
      "stack" => release["stack"],
    }
    create_release(payload)
    puts "---> App deployed to #{app}.herokuapp.com"
  end

  private

  def release
    @release ||= JSON.parse(heroku.get('/apps/' + app + '/releases/new'))
  end

  def create_release(d)
    heroku.post('/apps/' + app + '/releases', heroku.json_encode(d), :content_type => 'application/json')
  end

  def mksquashfs_bin
    return "/usr/bin/mksquashfs"  if File.exists?("/usr/bin/mksquashfs")
    return "/usr/sbin/mksquashfs" if File.exists?("/usr/sbin/mksquashfs")
    return "/usr/local/bin/mksquashfs" if File.exists?("/usr/local/bin/mksquashfs") # homebrew
    error "Can not find mksquashfs binary. `brew install squashfs`"
  end
end
