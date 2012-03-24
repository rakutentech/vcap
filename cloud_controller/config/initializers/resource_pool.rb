require 'uri'
require 'resource_pool/filesystem_pool'
require 'resource_pool/s3_pool'

unless Rails.env.test?
  resources = URI.parse(AppConfig[:directories][:resources])
  pool = case resources.scheme
         when "s3"
           bucket_name, server = resources.host.split('.', 2)
           S3Pool.new(:directory => URI.decode(resources.path),
                      :access_key_id => URI.decode(resources.user),
                      :secret_access_key => URI.decode(resources.password),
                      :bucket_name => URI.decode(bucket_name),
                      :server => URI.decode(server))
         when "file"
           FilesystemPool.new(:directory => resource.path)
         else
           FilesystemPool.new(:directory => AppConfig[:directories][:resources])
         end
  CloudController.resource_pool = pool
end
