#!/usr/bin/env ruby
#
# Creates a self-signed certificate authority (ca.key, ca.crt)
# with a name constraint. Valid for five years.

require 'yaml'

KEYNAME =  "ca.key"
CERTNAME = "ca.crt"
KEYSIZE =  4096

def err(*args)
  STDERR.puts(*args)
end

def usage
  err "usage: #$0 <common-name> <name-constraint>"
end

if ARGV.size != 2
  usage
  exit 1
end

if File.exist?(KEYNAME)
  err "#{KEYNAME} already exists. Aborting."
  exit 1
end

if File.exist?(CERTNAME)
  err "#{CERTNAME} already exists. Aborting."
  exit 1
end

common_name = ARGV.shift
name_constraint = ARGV.shift

extensions = <<-END
[ca_extensions]
basicConstraints=critical,CA:true,pathlen:0
nameConstraints=critical,permitted;DNS:#{name_constraint}
END

subject_hash = YAML.load(File.read("config.yml"))
subject_hash["CN"] = common_name

subject = "/" + subject_hash.map { |k, v| "#{k}=#{v}"}.join("/")

system "openssl genrsa -out #{KEYNAME} #{KEYSIZE}"

system "bash", "-c", <<-SH
openssl req \\
  -new \\
  -x509 \\
  -sha256 \\
  -days 1825 \\
  -key ca.key \\
  -subj "#{subject}" \\
  -extensions ca_extensions \\
  -config <(cat /etc/ssl/openssl.cnf <(printf "#{extensions}")) \\
  -out #{CERTNAME}
SH
