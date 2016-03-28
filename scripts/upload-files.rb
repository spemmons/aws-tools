#!/usr/bin/env ruby

require 'aws-sdk'

Aws.use_bundled_cert!

PROFILE = 'default'   # TODO - make this configurable?
REGION  = 'us-east-1' # TODO - make this configurable?

def upload_file(source,bucket,key_prefix,source_prefix)
  source_prefix = $1 if not source_prefix and source =~ /^(\.+\/*)/
  if File.directory?(source)
    upload_files(Dir["#{source}/*"],bucket,key_prefix,source_prefix)
  else
    key = "#{key_prefix}#{source[(source_prefix || '').length..-1]}"
    puts "PUT #{source} => s3://#{bucket.name}/#{key}"
    File.open(source,'rb') do|file|
      bucket.object(key).put(body: file)
    end
  end
end

def upload_files(sources,bucket,key,remove_prefix)
  sources.each do |source|
    upload_file(source,bucket,key,remove_prefix)
  end
end

begin
  return $stderr.puts "usage: #{$0} src-files s3-bucket key-prefix" if $*.length < 3

  key_prefix = $*.pop
  bucket_name = $*.pop

  credentials = Aws::SharedCredentials.new(profile_name: PROFILE)
  s3 = Aws::S3::Resource.new(region: REGION,credentials: credentials)
  bucket = s3.bucket(bucket_name)
  raise "bucket '#{bucket_name}' does not exist" unless bucket.exists?

  upload_files($*,bucket,key_prefix,nil)

rescue
  $stderr.puts "ERROR: #{$!}"
end
