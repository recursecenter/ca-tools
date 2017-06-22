#!/usr/bin/env ruby
#
# Creates a certificate signed by a CA made with mkca.rb
# Valid for two years.

require 'yaml'

CAKEY  = "ca.key"
CACERT = "ca.cert"

def err(*args)
  STDERR.puts(*args)
end

def usage
  err "usage: #$0 <keysize> <hostname>..."
end

def checkfile(filename)
  if File.exist?(filename)
    err "#{filename} already exists. Pick another filename."
    exit 1
  end
end

if ARGV.size <= 2
  usage
  exit 1
end

keysize = ARGV.shift
filename = ARGV.first

checkfile "#{filename}.key"
checkfile "#{filename}.csr"
checkfile "#{filename}.crt"

subject_hash = YAML.load(File.read("config.yml"))
subject_hash["CN"] = ARGV.first

subject = "/" + subject_hash.map { |k, v| "#{k}=#{v}"}.join("/")


subject_alt_names = ARGV.map { |hostname| "DNS:#{hostname}" }.join(',')

extensions = <<-END
[cert_extensions]
basicConstraints=critical,CA:false
subjectAltName=#{subject_alt_names}
END

system "openssl genrsa -out #{filename}.key #{keysize}"

system "bash", "-c", <<-SH
openssl req \\
  -new \\
  -sha256 \\
  -key #{filename}.key \\
  -subj "#{subject}" \\
  -reqexts cert_extensions \\
  -config <(cat /etc/ssl/openssl.cnf <(printf "#{extensions}")) \\
  -days 730 \\
  -out #{filename}.csr
SH

if File.exist?("ca.srl")
  serial = "-CAserial ca.srl"
else
  serial = "-CAcreateserial"
end

system "bash", "-c", <<-SH
openssl x509 \\
  -req \\
  -days 730 \\
  -sha256 \\
  -in #{filename}.csr \\
  -CA ca.crt \\
  -CAkey ca.key \\
  #{serial} \\
  -extensions cert_extensions \\
  -extfile <(cat /etc/ssl/openssl.cnf <(printf "#{extensions}")) \\
  -out #{filename}.crt
SH

system "rm #{filename}.csr"
