#!/usr/bin/env ruby

require 'aws-sdk'

Aws.use_bundled_cert!

PROFILE = 'default'   # TODO - make this configurable?
REGION  = 'us-east-1' # TODO - make this configurable?

def upload_file(source,bucket,key_prefix,source_prefix,item_lookup)
  source_prefix = $1 if not source_prefix and source =~ /^(\.+\/*)/
  if File.directory?(source)
    upload_files(Dir["#{source}/*"],bucket,key_prefix,source_prefix,item_lookup)
  else
    key = "#{key_prefix}#{source[(source_prefix || '').length..-1]}"
    source_size = File.size(source)
    if (last_size = item_lookup[key]) and last_size == source_size
      puts "SKIP #{source}"
    else
      if last_size
        print "UPDATE #{source} => s3://#{bucket.name}/#{key} (#{last_size} => #{source_size})"
      else
        print "ADD #{source} => s3://#{bucket.name}/#{key} (#{source_size})"
      end
      start_time = Time.now
      File.open(source,'rb') do|file|
        bucket.object(key).put(body: file)
      end
      puts "... #{(Time.now - start_time).to_i}"
    end
  end
end

def upload_files(sources,bucket,key,remove_prefix,item_lookup)
  sources.each do |source|
    upload_file(source,bucket,key,remove_prefix,item_lookup)
  end
end

if $*.length < 3
  $stderr.puts "usage: #{$0} src-files s3-bucket key-prefix"
else
  begin

    key_prefix = $*.pop
    bucket_name = $*.pop

    credentials = Aws::SharedCredentials.new(profile_name: PROFILE)
    s3 = Aws::S3::Resource.new(region: REGION,credentials: credentials)
    bucket = s3.bucket(bucket_name)
    raise "bucket '#{bucket_name}' does not exist" unless bucket.exists?

    print "finding existing objects matching '#{key_prefix}'"
    item_lookup = {}
    bucket.objects(prefix: key_prefix).each do|object|
      print '.'
      item_lookup[object.key] = object.size
    end
    puts

    puts 'start uploading files...'
    upload_files($*,bucket,key_prefix,nil,item_lookup)

  rescue
    $stderr.puts "ERROR: #{$!}"
  end
end
