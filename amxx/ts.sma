/***
Simple teamspeak plugin by hackziner

hackziner@gmail.com

cvars:
	ts_ip
	ts_virtual_server
	ts_superadmin
	ts_superadmin_password
Commands:
	/teamspeak online //show who is on the teamspeak server
	/teamspeak calladmin msg //send a test msg to the teamspeak server
	/teamspeak reset //reset request flag

Licence CeCill 2.1

http://ufbteam.com

***/

#include <amxmodx>
#include <amxmisc>
#include <sockets>

#define PLUGIN "TS module"
#define VERSION "0.1"
#define AUTHOR "hackziner"

#define QUERYPORT 51234

new tcp_socket
new ts_ip[32]
new ts_virtual_server[32]
new ts_superadmin[32]
new ts_superadmin_password[32]
new status
new format_msg[128]

new request


public plugin_init() {

	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar("ts_version",VERSION,FCVAR_SERVER)
	register_cvar("ts_ip","192.168.0.69",FCVAR_SERVER)
	register_cvar("ts_virtual_server","8767",FCVAR_SERVER)
	register_cvar("ts_superadmin","superadmin")
	register_cvar("ts_superadmin_password","")
	
	get_cvar_string("ts_ip",ts_ip,31)
	get_cvar_string("ts_virtual_server",ts_virtual_server,31)
	get_cvar_string("ts_superadmin",ts_superadmin,31)
	get_cvar_string("ts_superadmin_password",ts_superadmin_password,31)
	
	register_clcmd("say", "handle_say")
	
	tcp_socket=socket_open(ts_ip,QUERYPORT,SOCKET_TCP,status)
	if(status!=0)
		{
		server_print("TS Module, Connection to TS server FAILED !")
		return PLUGIN_CONTINUE
		}

	set_task(1.0,"get_msg",0,"",0,"b")
	return PLUGIN_CONTINUE
}

public get_msg(){
	static buffer[5012]
	static des[5012]
	if(socket_change(tcp_socket,1))
	{
		socket_recv(tcp_socket,buffer,5011)
		if(containi(buffer,"[TS]")==0)
		{
		request=1
		format(format_msg,64,"slogin %s %s^n",ts_superadmin,ts_superadmin_password)
		socket_send(tcp_socket,format_msg,63)
		}
		if(containi(buffer,"OK")==0)
			{
			if(request==1)
				{
				client_print(0,print_chat,"TS: Superadmin login OK")
				server_print("TS: Superadmin login OK")
				format(format_msg,64,"sel %s ^n",ts_virtual_server)
				socket_send(tcp_socket,format_msg,63)
				request=3
				}
			if(request==3)
				{
				client_print(0,print_chat,"TS: Virtual server select OK")
				server_print("TS: Virtual server select OK")
				request=0
				}
			if(request==4)
				{
				client_print(0,print_chat,"TS: msg send to ts OK")
				server_print("TS: msg send to ts OK")
				request=0
				}
			}
		if(request==2)
			{
			new i
			new list[196]
			static parse[64]
			strtok(buffer,des,5012,buffer,5012,'^n')
			format(list,196,"Users Online: ")
			while(containi(buffer,"^n")>-1)
				{
				strtok(buffer,des,5012,buffer,5012,'^n')
				for(i=0;i<15;i++)
				strtok(des,parse,63,des,5012,'^t')
				format(list,196,"%s, %s",list,parse)
				}
			client_print(0,print_chat,"%s",list)
			server_print("%s",list)
			request=0
			}

	
	}
}


public handle_say(id){
	static said[192]
	read_args(said,192)
	
	if(containi(said,"/teamspeak reset")>-1)
		request=0
	if (request==0)
	{
		if(containi(said,"/teamspeak online")>-1)
			{
			request=2
			format(format_msg,64,"pl %s ^n",ts_virtual_server)
			socket_send(tcp_socket,format_msg,63)
			}
			
		if(containi(said,"/teamspeak calladmin")>-1)
			{
			new pname[32]
			request=2
			get_user_name(id,pname,31)
			format(format_msg,127,"msg %s %s call an admin '%s'^n",ts_virtual_server,pname,said)
			socket_send(tcp_socket,format_msg,63)
			request=4
			}
	}
	else
	{
			client_print(id,print_chat,"TS: Please retry in few second, there is already a request")
	}
}
