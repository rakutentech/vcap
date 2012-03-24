#
# Author: Yohei Sasaki <yssk22@gmail.com>
#

require 'resource_pool/resource_pool'
require 'aws/s3'
require 'tmpdir'

# 
# A resource pool implementation to use S3.
#
class S3Pool < ResourcePool
  attr_accessor :directory, :levels, :modulos, :bucket_name

  def initialize(options = {})
    super
    @directory = @options[:directory] || Dir.mktmpdir.to_s[1..-1] # avoid start with /
    # Defaults give over 2B objects, given 32k limit per directory for files.
    # Files look like /shared/resources/MOD#1/MOD#2/SHA1
    @levels    = @options[:levels] || 2
    @modulos   = @options[:modulos] || [269, 251]
    unless @modulos.size == @levels
      raise ArgumentError, 'modulos array must have one entry per level'
    end

    # S3 Options
    @access_key_id     = @options[:access_key_id] || 'my-access-key-id'
    @secret_access_key = @options[:secret_access_key] || 'my-secret-access-key'
    @bucket_name       = @options[:bucket_name] || 'mybucket'

    # TODO: configurable region
    AWS::S3::Base.establish_connection!(:access_key_id     => @access_key_id,
                                        :secret_access_key => @secret_access_key)
  end

  def resource_known?(descriptor)
    return false unless Hash === descriptor
    resource_path = path_from_sha1(descriptor[:sha1])
    begin
      found = AWS::S3::S3Object.find resource_path, bucket_name
      found.content_length == descriptor[:size].to_i
    rescue AWS::S3::NoSuchKey
      false
    end
  end

  def add_path(path)
    file = File.stat(path)
    return if file.directory? || file.symlink?
    return if file.size < minimum_size
    return if file.size > maximum_size
    logger.debug "[S3] add_path: #{path}"
    sha1 = Digest::SHA1.file(path).hexdigest
    resource_path = path_from_sha1(sha1)
    return if File.exists?(resource_path)

    # store file from path to S3.
    AWS::S3::S3Object.store(resource_path, open(path), bucket_name)
    true
  end
  
  def resource_sizes(resources)
    sizes = []
    resources.each do |descriptor|
      resource_path = path_from_sha1(descriptor[:sha1])
      if File.exists?(resource_path)
        entry = descriptor.dup
        begin
          found = AWS::S3::S3Object.find(resource_path, bucket_name)
          entry[:size] = size
        rescue AWS::S3::NoSuchKey
          entry[:size] = 0
        end
        sizes << entry
      end
    end
    sizes
  end
  
  private
  def overwrite_destination_with!(descriptor, destination)
    FileUtils.mkdir_p File.dirname(destination)
    resource_path = path_from_sha1(descriptor[:sha1])
    open(destination,"w") do |file|
      AWS::S3::S3Object.stream(resource_path, bucket_name) do |chunk|
        file.write(chunk)
      end
    end 
  end

  def path_from_sha1(sha1)
    sha1 = sha1.to_s.downcase
    as_integer = Integer("0x#{sha1}")
    dirs = []
    levels.times do |i|
      dirs << as_integer.modulo(modulos[i]).to_s
    end
    dir = File.join(directory, *dirs)
    File.join(dir, sha1)
  end
end
