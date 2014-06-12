
require 'pack/pack.rb'
require 'cmds/boomman_pack_type.rb'
require 'cmds/cmd_property_update.rb'
require 'cmds/game_cmds_common.rb'


class AgentNode
	
	attr_accessor :pid
	
	def player
		if(@pid == nil)
			return nil
		end
		return $game_players.find_player_by_pid(@pid);
	end
	
end


module GameCMDS
	
	include GameCMDCommon
	
	SUCCESS = 1	# 成功
	FAIL    = 0	# 失败
	
	def response_msg(node, code, msg)
		
		os.write_byte(code)
		os.write_string(msg)
		pack = Pack.create( 0, PACK_TYPE_MESSAGE, os );
		node.send_pack(pack);
		
	end
	
	# => 协议号	:PACK_TYPE_REGIST_SESSION
	# => 注册一个session
	def regiest_session(sender, pack)
		
		os = FSOutputStream.new();
		
		now = Time.now
		session_id = sender.id 
		time       = now.tv_sec

		os.write_int32( session_id );
		os.write_int64( time );
		
		pack = Pack.create( pack.serial,  PACK_TYPE_REGIST_SESSION, os);
		
		sender.send_pack(pack);
		
	end
	
	# => 协议号	:PACK_TYPE_VERSION
  # => 获取版本
	def version(sender, pack)

		max_version  = pack.input.read_byte();		# 
		mind_version = pack.input.read_byte();
		min_version  = pack.input.read_byte();
		
		os = FSOutputStream.new()				# 
		
		os.write_byte(max_version);
		os.write_byte(mind_version);
		os.write_byte(min_version);
		
	  response = Pack.create( pack.serial, PACK_TYPE_VERSION, os );
		
	  sender.send_pack(response);
		
	end

	# => 协议号	:PACK_TYPE_AUTHORIZE
	# => 获取登陆授权ID
	def authorize(sender, pack)
		
		user_name = pack.input.read_string();
		user_pwd = pack.input.read_string();
		user = $game_users.find_user_by_account( user_name, user_pwd );

		os = FSOutputStream.new()				# 
		
		if(user != nil)
			user.cache();
			os.write_byte(SUCCESS);
			os.write_string(User.generate_cache_key( user_name, user_pwd ));
		else
			os.write_byte(FAIL);
		end
		

	  response = Pack.create( pack.serial, PACK_TYPE_AUTHORIZE, os );
	  sender.send_pack(response);
		
		p user_name, user_pwd
			
	end
  
	# => 协议号
	# => 注册
	def regist( sender, pack )
		
		
		user_name = pack.input.read_string();
		user_pwd = pack.input.read_string();
		user_uuid = pack.input.read_string();
		user = $game_users.regist_user( user_name, user_pwd, user_uuid );

		os = FSOutputStream.new()				# 
		
		if(user != nil)
			os.write_byte(SUCCESS);
			os.write_string(user_name);
			os.write_string(user_pwd);
		else
			os.write_byte(FAIL);
		end
	  response = Pack.create( pack.serial, PACK_TYPE_REGIST, os );
	  sender.send_pack(response);
		
	end
	
	# => 协议号	:PACK_TYPE_LOGIN
	# => 登陆
	def login(sender, pack)
		
		authorize = pack.input.read_string();
		
		player = nil;
		user = $game_users.find_user_by_authorize(authorize);
		if(user != nil)
			player = $game_players.login(user.pid);
		end
		os = FSOutputStream.new()				
		
		if(user != nil && player != nil)
			os.write_byte(SUCCESS)
			player.write_to_stream(os);
		else
			os.write_byte(FAIL)
		end
		
		sender.pid = player.pid;
		player.client = sender;
		
		
	  response = Pack.create( pack.serial, PACK_TYPE_LOGIN, os );
	  sender.send_pack(response);
		
	end
    
	# => 协议号	:PACK_TYPE_INIT_PLAYER
	# => 初始化人物
	def init_player(sender, pack)
		
		player = sender.player
		
		# 0-man 1 woman
		sex = pack.input.read_byte();
		# name
		name = pack.input.read_string();
		
		os = FSOutputStream.new()
		if(sex != 0 and sex != 1)
			os.write_byte(FAIL);
		else
			if(player.sex == -1)
				os.write_byte(SUCCESS);
				player.init(sex, name);
				player.write_to_stream(os);
				player.cache();
			else
				os.write_byte(FAIL);
			end			
		end	
		response = Pack.create( pack.serial, PACK_TYPE_INIT_PLAYER, os );
	  sender.send_pack(response);
			
	end
	
    
	# => 协议号	:PACK_TYPE_CHAT_MSG
	# => 聊天
	def chat_msg(sender, pack)
		
		type = pack.input.read_byte();
		msg  = pack.input.read_string();
		
		# 委托到协议内
		CMDChatMsg.execute(sender, self, type, msg)
		
	end
	
	
	
end