require 'net/http'
require 'cgi'

class WebpayController < ApplicationController

  VALID_MAC_RESPONSE = 'CORRECTO'
	
	protect_from_forgery :except => [:success, :index, :failure, :check]

  def initialize
    
  end
	
	def index
		require 'date'
		@oc = "OC_" + Time.now.strftime("%Y%m%d%H%M%S")
		@mount = 10000
	end

	def success
		Rails.logger.debug "\n<<<<< success-request \n" 
	end

	def failure
		Rails.logger.debug "\n<<<<< failure-request \n" 
	end


	def check

    Rails.logger.debug "<<<<< comienza parseo"
    
    result = valida_mac(ENV, check_cgi_path, temp_file_param(request.raw_post))
    
    Rails.logger.debug "<<<<< result: #{result}"

    render :text => 'ACEPTADO', :layout => false
  end

  private
  
  # crea archivo temporal y guarda path
  def temp_file_param(raw)  
    file = Tempfile.new 'webpay-mac-check'
    file.write raw
    file.close
    path_file = file.path
    file.unlink
        
    Rails.logger.debug "<<<<< path_file: #{path_file}"

    path_file
  end

  def valida_mac(env, *path, path_param)
    status = 200
    headers = {}
    body = ''

    stderr = Tempfile.new 'webpay-cgi-stderr'
    IO.popen('-', 'r+') do |io|
      if io.nil?  # Child
        $stderr.reopen stderr.path
        ENV['DOCUMENT_ROOT'] = root_path
        ENV['SERVER_SOFTWARE'] = 'Rack Legacy'
        env.each {|k, v| ENV[k] = v if v.respond_to? :to_str}
        exec *path + " " + path_param
      else        # Parent
        io.write(env['rack.input'].read) if env['rack.input']
        io.close_write
        until io.eof? || (line = io.readline.chomp) == ''
          if line =~ /\s*\:\s*/
            key, value = line.split(/\s*\:\s*/, 2)
            if headers.has_key? key
              headers[key] += "\n" + value
            else
              headers[key] = value
            end
          end
        end
        body = io.read
        stderr.rewind
        stderr = stderr.read
        Process.wait
        unless $?.exitstatus == 0
          status = 500
          body = ErrorPage.new(env, headers, body, stderr).to_s
          headers = {'Content-Type' => 'text/html'}
        end
      end
    end

    status = headers.delete('Status').to_i if headers.has_key? 'Status'
    [status, headers, [body]]
  end

  def root_path
    Rails.root.join("vendor", "webpay").to_s
  end
  
  def check_cgi_path
    root_path + '/tbk_check_mac.cgi'
  end


end