# Personium
# Copyright 2017 FUJITSU LIMITED
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This is the PCUI 1.1 for manipulating personium.
# Please execute with Ruby 2.X or higher.
#
require 'readline'
require 'rest-client'
require 'json'
require 'rexml/document'
require 'io/console'
require 'optparse'

#
# Constant variavle.
#
# Base info.
PCUI_VERSION = '1.1'
# Log info.
LOG_SAVE_MESSAGE = 'Do you want to save the operation log? (yes | no)'
LOG_NAME = 'pcui_'
# Conf info.
PCUI_CONF = './pcui.conf'
URL_NUM = 5
CONF_ELEM = 'urls'

# Messages.
HR = "="*50
PROXY_CAUTION = "* If you are using a proxy server,\n  please set the environment variable HTTP_proxy.\n"
EDITOR_CAUTION = "* Edit mode is Emacs mode.\n"
OPENING_MESSAGE = HR + "\nThis is the PCUI #{PCUI_VERSION} for manipulating personium.\nPlease execute with Ruby 2.X or higher.\n\n" + PROXY_CAUTION + EDITOR_CAUTION + HR
ABN_CELL_COMMAND = 'Unusual Cell command.'
ABN_BOX_COMMAND = 'Unusual Box command.'
USEAGE_CELL = '[Cell mode command] -> username, token, pwd, ls, sl, extcell, relation, role, extrole, account, rcvmessage, sntmessage, cd {Box}, mk {Box}, acl, rm {Box}, help(?), quit(q)'
USEAGE_BOX = '[Box mode command] -> pwd, ls, sl, meta, url, cd .., put {Path}, get {File}, rm {File}, help(?), quit(q)'
ACCESS_TOKEN_EXP_MESSAGE = 'Access token has expired.'
# Mode control.
NOT_LOGIN = 0
CELL_MODE = 1
BOX_MODE  = 2
DEMAND_CELL  = 0
DEMAND_UID   = 1
DEMAND_PWD   = 2
DEMAND_TOKEN = 3


#
# Common module.
#
module CommonFunction
	def current_method()
		caller_locations(1).first.label
	end

	def no_echo_prompt io: STDIN, prompt: nil
	  print prompt unless prompt.nil?
	  input = io.noecho &:gets
	  print "\n"
	  input
	end
end

module RestCall
	def rest_caller(cmd, url, method, body)
		res_set = Hash.new
		res_set['rest_url'] = url
		res_set['status'] = nil
		res_set['message'] = ""
		begin
			case method
			when 'get'
				res_set['message'] = rest_get(res_set['rest_url'])
			when 'post'
				res_set['message'] = rest_post(res_set['rest_url'], body)
			when 'delete'
				res_set['message'] = rest_delete(res_set['rest_url'])
			when 'propfind'
				res_set['message'] = rest_propfind(res_set['rest_url'], body)
			when 'put'
				res_set['message'] = rest_put(res_set['rest_url'], body)
			when 'get_file'
				res_set['message'] = rest_get_file(res_set['rest_url'])
			else
			end
		rescue => ex
			res_set['message'] = "#{cmd} faild." + '<' + ex.message + '>'
			res_set['status'] = !nil
		ensure
			return res_set
		end
	end

	def rest_get(url)
		res = RestClient.get(url, {:Authorization => 'Bearer '+@access_token, :accept => 'json'})
		jres = JSON.parse(res)
		return JSON.pretty_generate(jres)
	end

	def rest_get_file(url)
		res = RestClient.get(url, {:Authorization => 'Bearer '+@access_token, :accept => 'json'})
		return res
	end

	def rest_post(url, body)
		res = RestClient.post(url, body.to_json, {:Authorization => 'Bearer ' + @access_token, :accept => 'json'})
		jres = JSON.parse(res)
		return JSON.pretty_generate(jres)
	end

	def rest_propfind(url, body)
		res = RestClient::Request.execute(method: :propfind, url: url, body: body, headers: {:Authorization => 'Bearer ' + @access_token, :Depth => '1'})
		return res
	end

	def rest_delete(url)
		res = RestClient.delete(url, {:Authorization => 'Bearer ' + @access_token, :accept => 'json'})
		# DELETE method has no response.
		return ''
	end

	def rest_put(url, body)
		res = RestClient.put(url, body, {:Authorization => 'Bearer ' + @access_token})
		return res
	end
end


#
# Cell class.
#
class Cell
	include CommonFunction
	include RestCall

	attr_reader :url, :access_token, :username, :expires_in

	def initialize(url, username, password, proxy)
		@url = url
		@username = username
		@password = password
		@proxy = proxy

		# Get token.
		tokens = Hash.new
		if('' != @proxy)
			# Proxy url setting 'HTTP_proxy' env var.
			RestClient.proxy = @proxy
		end
		url = @url + '/__token'

		begin
			res = RestClient.post(url, {:grant_type => 'password', :username => @username, :password => @password})
			tokens = JSON.parse(res)
			@access_token = tokens["access_token"]
			@expires_in = Time.now + tokens["expires_in"]
		rescue
			raise 'Login faild.'
		end
	end

	def username()
		return @username
	end

	def token()
		return @access_token
	end

	def pwd()
		return @url
	end

	def ls()
		return rest_caller(current_method(), @url + '/__ctl/Box', 'get', '')
	end

	def sl()
		r = rest_caller(current_method(), @url + '/__ctl/Box', 'get', '')
		h = JSON.load(r['message'])
		s = ""
		for num in 0..h["d"]["results"].length-1 do
			s += list_formating(
				date_ms_to_yyyymmdd(h["d"]["results"][num]["__updated"]),
				h["d"]["results"][num]["Name"],
				h["d"]["results"][num]["Schema"]
			) + "\n"
		end

		r['message'] = s
		return r
	end

	def extcell()
		return rest_caller(current_method(), @url + '/__ctl/ExtCell', 'get', '')
	end

	def relation()
		return rest_caller(current_method(), @url + '/__ctl/Relation', 'get', '')
	end

	def role()
		return rest_caller(current_method(), @url + '/__ctl/Role', 'get', '')
	end

	def extrole()
		return rest_caller(current_method(), @url + '/__ctl/ExtRole', 'get', '')
	end

	def account()
		return rest_caller(current_method(), @url + '/__ctl/Account', 'get', '')
	end

	def rcvmessage()
		return rest_caller(current_method(), @url + '/__ctl/ReceivedMessage', 'get', '')
	end

	def sntmessage()
		return rest_caller(current_method(), @url + '/__ctl/SentMessage', 'get', '')
	end

	def mkbox(box_name)
		body = {"Name" => box_name, "Schema" => @url + '/' + box_name + '/'}
		return rest_caller(current_method(), @url + '/__ctl/Box', 'post', body)
	end

	def rmbox(box_name)
		return rest_caller(current_method(), @url + "/__ctl/Box('#{box_name}')/", 'delete', '')
	end

	def acl()
		body = '<?xml version="1.0" encoding="utf-8"?><D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>'
		return rest_caller(current_method(), @url, 'propfind', '')
	end

	# Private method.
	private
	def date_ms_to_yyyymmdd(ms)
		ms =~ /\/Date\((\d+)\)\//
		t = $1
		return Time.at(t.to_i/1000.0).strftime('%Y/%m/%d %H:%M:%S')
	end

	def list_formating(update_t, name, schema)
		return (update_t + "\t" + name  + "\t" + schema)
	end
end


#
# Box class.
#
class Box
	include CommonFunction
	include RestCall

	def initialize(url, box_name, access_token)
		@cell_url = url
		@url = url + '/' + box_name
		@access_token = access_token
	end

	def pwd()
		return @url
	end

	def ls()
		body = '<?xml version="1.0" encoding="utf-8"?><D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>'
		return rest_caller(current_method(), @url, 'propfind', body)
	end

	def sl()
		body = '<?xml version="1.0" encoding="utf-8"?><D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>'
		r = rest_caller(current_method(), @url, 'propfind', body)
		d = REXML::Document.new(r['message'])
		s = ""
		d.elements.each('multistatus/response') do |e|
			col = false
			if(e.elements['propstat/prop/resourcetype/collection'])
			else
				col = true
			end

			t = Time.parse(e.elements['propstat/prop/getlastmodified'].text)

			s += list_formating(
				col,
				date_gmt_to_yyyymmdd(t),
				e.elements['href'].text
			) + "\n"
		end

		r['message'] = s
		return r
	end

	def url()
		return rest_caller(current_method(), @cell_url + '/__box', 'get', '')
	end

	def meta()
		return rest_caller(current_method(), @url, 'get', '')
	end

	def put(file_name, file_body)
		return rest_caller(current_method(), @url + '/' + file_name, 'put', file_body)
	end

	def get(file_name)
		return rest_caller(current_method(), @url + '/' + file_name, 'get_file', '')
	end

	def exist()
		return rest_caller(current_method(), @url, 'get', '')
	end

	def rm(file_name)
		return rest_caller(current_method(), @url + '/' + file_name, 'delete', '')
	end

	# Private method.
	private
	def date_gmt_to_yyyymmdd(s)
		return s.getlocal.strftime('%Y/%m/%d %H:%M:%S')
	end

	def list_formating(col, update_t, schema)
		c = "-"
		if(col)
		else
			c = "c"
		end
		return (c + " " + update_t + " " + schema)
	end

end


#
# Message output machine.
#
class Msg
	attr_accessor :log_save

	def initialize()
		@log_save = false
	end

	def out(str_array)
		str_array.each{|str|
			puts '# ' + str
		}

		if(@log_save)
			now = Time.now
			file_name = LOG_NAME + now.strftime('%Y%m%d') + '.log'
			f = open(file_name, "a")
			str_array.each{|str|
				f.puts '[' + now.strftime('%Y/%m/%d %H:%M:%S') + '] # ' + str
			}
			f.close
		end
	end
end


#
# Config file control class.
#
class ActiveConf
	attr_reader :path, :menu_num, :element

	def initialize(path, menu_num, element)
		@path = path
		@menu_num = menu_num
		@element = element
	end

	def save(str)
		array = Array.new

		if(File.exist?(@path))
			f = open(@path)
			h = JSON.parse(f.read)
			f.close

			array = h[@element]
			array.delete(str)
			if(array.length > (@menu_num-1))
				array.delete_at(0)
			end
		end
		array.push(str)

		config_data = {@element => array}

		f = File.open(@path, 'w')
		f.puts JSON.pretty_generate(config_data)
		f.close()
	end

	def get()
		h = Hash.new
		begin
			f = open(@path)
			h = JSON.parse(f.read)
			f.close
		rescue
			h["urls"] = []
		ensure
			return(h)
		end
	end
end


#
# Main control.
#
# Function for get cell token.
if __FILE__ == $0
	include CommonFunction

	# Initialize
	cell_url = ''
	box_url = ''
	user_name = ''
	password = ''
	current_mode = NOT_LOGIN			# 0:Not login, 1:Cell, 2:Box
	login_control_mode = DEMAND_CELL	# 0: Demand cell name, 1:Demand user name, 2:Demand password, 3:Demand cell token
	tokens = Hash.new
	proxy = ''

	#
	# Option check.
	#
	opt = OptionParser.new
	opt.banner = "Usage: ruby pcui.rb\nThis is the PCUI #{PCUI_VERSION} for manipulating personium.\n"
	opt.version = PCUI_VERSION
	opt.on('-h', '--help', 'show this help')	{puts opt; exit}
	opt.on('-v', '--version', 'show version')	{puts 'pcui ' + opt.version; exit}
	opt.parse(ARGV)

	#
	# Start & Setting.
	#
	msg = Msg.new()
	puts OPENING_MESSAGE
	while buf = Readline.readline(LOG_SAVE_MESSAGE + '> ', true)
		if(buf.length > 0)
			case buf
			when 'yes', 'y'
				msg.log_save = true
				break
			when 'no', 'n'
				break
			when 'quit', 'q'
				exit
			else
			end
		end
	end


	#
	# Login = Get cell token.
	#
	# Create Cell url select menu.
	ac = ActiveConf.new(PCUI_CONF, URL_NUM, CONF_ELEM)
	urls_hash = ac.get()
	urls = urls_hash["urls"].reverse

	url_select_msg = "Input your Cell URL\n"
	select_no = 0
	urls.each{|u|
		select_no += 1
		url_select_msg += "[#{select_no}] #{u}\n"
	}
	login_msg = [url_select_msg, 'Username', 'Password']

	# Proxy url get. Prioritize the HTTP_proxy, http_proxy variable.
	if(nil != ENV['HTTP_PROXY'])
		# Proxy url setting 'HTTP_PROXY' env var.
		proxy = ENV['HTTP_PROXY']
	end
	if(nil != ENV['http_proxy'])
		# Proxy url setting 'http_proxy' env var.
		proxy = ENV['http_proxy']
	end
	if(nil != ENV['HTTP_proxy'])
		# Proxy url setting 'HTTP_proxy' env var.
		proxy = ENV['HTTP_proxy']
	end

	cell_url = ''

	while buf = Readline.readline(login_msg[login_control_mode] + '> ', true)
		if(buf.length > 0)

			# Abort login processing.
			exit	if(('quit' == buf) || ('q' == buf))

			if(login_control_mode == DEMAND_CELL)
				case buf
				when /^\d+$/
					if((0 < buf.to_i) && (URL_NUM >= buf.to_i))
						if(urls.length >= buf.to_i)
							cell_url = urls[buf.to_i - 1]
						end
					end
				else
					cell_url = buf
				end

				if('/' == cell_url[cell_url.length-1])
					cell_url = cell_url.chop!
				end
			elsif(login_control_mode == DEMAND_UID)
				user_name = buf
				login_control_mode += 1

				# Input password no echo.
				buf = (no_echo_prompt prompt: login_msg[login_control_mode] + '> ')
				password = buf.chomp!

=begin
			elsif(login_control_mode == DEMAND_PWD)
				password = buf
=end
			end
			login_control_mode += 1

			# Check normal Cell URL is set in variable.
			login_control_mode = DEMAND_CELL	if(cell_url.length == 0)

			if(login_control_mode == DEMAND_TOKEN)
				begin
					msg.out(['Accessing ' + cell_url + '/__token ...'])
					cell = Cell.new(cell_url, user_name, password, proxy)
					ac.save(cell_url)
					break
				rescue
					msg.out(['Login faild. Try again.'])
					login_control_mode = DEMAND_CELL
				end
			end
		end
	end


	#
	# Resource Control.
	#
	current_mode = CELL_MODE
	msg.out([USEAGE_CELL])
	while buf = Readline.readline("#{cell_url}#{box_url}> ", true)
		# Cell control.
		if(CELL_MODE == current_mode)
			case buf
			when 'username'
				msg.out([cell.username()])
			when 'token'
				msg.out([cell.token()])
			when 'pwd'
				msg.out([cell.pwd()])
			when 'ls'
				res_set = cell.ls()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'sl'
				res_set = cell.sl()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'extcell'
				res_set = cell.extcell()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'relation'
				res_set = cell.relation()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'role'
				res_set = cell.role()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'extrole'
				res_set = cell.extrole()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'account'
				res_set = cell.account()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'rcvmessage'
				res_set = cell.rcvmessage()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'sntmessage'
				res_set = cell.sntmessage()
				msg.out([res_set['rest_url'], res_set['message']])
			when /cd[ ]+([^ ]+)/
				if($1 == '..')
					msg.out(['Current path is Cell. Cannot up path.'])
				else
					box = Box.new(cell.url, $1, cell.access_token)

					# Box exist check.
					res_set = box.exist()
					msg.out([res_set['rest_url']])
					if(res_set['status'].nil?)
						box_url = '/' + $1
						current_mode = BOX_MODE
						msg.out([USEAGE_BOX])
					else
						msg.out([res_set['message']])
					end

				end
			when /mk[ ]+([^ ]+)/
				res_set = cell.mkbox($1)
				msg.out([res_set['rest_url'], res_set['message']])
			when /rm[ ]+([^ ]+)/
				res_set = cell.rmbox($1)
				msg.out([res_set['rest_url'], res_set['message']])
			when /acl/
				res_set = cell.acl()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'help', '?'
				msg.out([USEAGE_CELL])
			when 'quit', 'q'
				break
			else
				msg.out([ABN_CELL_COMMAND, USEAGE_CELL])
			end

		# Box control.
		elsif(BOX_MODE == current_mode)
			case buf
			when 'pwd'
				msg.out([box.pwd()])
			when 'ls'
				res_set = box.ls()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'sl'
				res_set = box.sl()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'url'
				res_set = box.url()
				msg.out([res_set['rest_url'], res_set['message']])
			when 'meta'
				res_set = box.meta()
				msg.out([res_set['rest_url'], res_set['message']])
			when /cd[ ]+([^ ]+)/
				if($1 == '..')
					box_url = ''
					current_mode = CELL_MODE
					msg.out([USEAGE_CELL])
				else
					msg.out(['Current path is Box. Cannot down path.'])
				end
			when /put[ ]+([^ ]+)/
				file_path = $1
				if(File.file?(file_path))
					file_name = File.basename(file_path)
					file_body = File.binread(file_path)

					res_set = box.put(file_name, file_body)
					msg.out([res_set['rest_url'], res_set['message']])
				else
					msg.out(["#{file_path} is not exist."])
				end
			when /get[ ]+([^ ]+)/
				res_set = box.get($1)
				msg.out([res_set['rest_url']])
				if(res_set['status'].nil?)
					File.binwrite('./' + $1, res_set['message'])
				else
					msg.out([res_set['message']])
				end
			when /rm[ ]+([^ ]+)/
				res_set = box.rm($1)
				msg.out([res_set['rest_url'], res_set['message']])
			when 'help', '?'
				msg.out([USEAGE_BOX])
			when 'quit', 'q'
				break
			else
				msg.out([ABN_BOX_COMMAND, USEAGE_BOX])
			end
		end
	end
end
