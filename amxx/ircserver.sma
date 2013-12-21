// Release under CeCill 2.1 License
// Script made by hackziner for the ufbteam (http://ufbteam.com)


#include <amxmodx>
#include <amxmisc>
#include <vault>
#include <sockets_hz>

#define PLUGIN "IRC server"
#define VERSION "0.3"
#define AUTHOR "hackziner"

#define DEFAULTPORT 6667
#define SERVERCHANNEL "server"

new listening_socket


enum IrcClient{
    Name[33],
	Username[33],
	TimeOut,
	IsAdmin,
	CSocket,
};

enum IrcChannel{
	IsCreated,
	Name[33],
	Title[33],
	user[64],
};

new IClients[128][IrcClient]
new IChannel[32][IrcChannel]
new this_chaussette
new serverip[64]
new adminpassword[32]
new serverchannel[16]

public plugin_init() {
	new error //you're the error
	new i,j

	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar("irc_server",VERSION,FCVAR_SERVER)
	register_cvar("irc_public_ip","192.168.0.69",FCVAR_SERVER)
	register_cvar("irc_listenning_socket","0",FCVAR_SERVER)
	register_cvar("irc_admin_password","voldiesuxor")
	
	
	for(i=0;i<128;i++)
		IClients[i][CSocket]=0
		
	for(i=0;i<32;i++)
		for(j=0;j<64;j++)
			IChannel[i][user][j]=-1
	
	get_cvar_string("irc_admin_password",adminpassword,31)
	
	format(serverchannel,15,SERVERCHANNEL)
	
	listening_socket=get_cvar_num("irc_listenning_socket")
	if(listening_socket!=0)
	{
	//init sockets
	for(i=0;i<128;i++)
		{
		new keykey[32]
		new valval[32]
		format(keykey,31,"ircsid%d",i)
		get_vaultdata(keykey,valval,31); 
		IClients[i][CSocket]=str_to_num(valval)
		format(keykey,31,"ircisad%d",i)
		get_vaultdata(keykey,valval,31); 
		IClients[i][IsAdmin]=str_to_num(valval)
		format(keykey,31,"ircname%d",i)
		get_vaultdata(keykey,IClients[i][Name],31)
		get_vaultdata(keykey,IClients[i][Username],31)
		if (IClients[i][CSocket]!=0)server_print("client %s socket reload :%d",IClients[i][Name],IClients[i][CSocket])
		}
	}
	
	if(listening_socket==0)listening_socket = socket_listen("127.0.0.1",DEFAULTPORT,SOCKET_TCP,error)
	
	set_cvar_num("irc_listenning_socket",listening_socket)
	socket_unblock(listening_socket)
	
	server_print("LISTENNING ANY ON PORT %d",DEFAULTPORT)
	
	register_concmd("amx_irc_force_port","force_port",ADMIN_LEVEL_B," port")
	 
	get_cvar_string("irc_public_ip",serverip,64)
	
	register_clcmd("say", "handle_say")
	register_clcmd("say_team","handle_say")
	
	set_task(0.5,"auto_accept_reply",0,"",0,"b")
	set_task(10.0,"auto_ping",0,"",0,"b")
}

public plugin_end () 
{
new i
for(i=0;i<128;i++)
	{
		new keykey[32]
		new valval[32]
		format(keykey,31,"ircsid%d",i)
		format(valval,31,"%d",IClients[i][CSocket])
		set_vaultdata(keykey,valval)
		format(keykey,31,"ircisad%d",i)
		format(valval,31,"%d",IClients[i][IsAdmin])
		set_vaultdata(keykey,valval)
		format(keykey,31,"ircname%d",i)
		set_vaultdata(keykey,IClients[i][Name])
	}
}

public force_port(id,level,cid)
{
	new error //It's you !
	if (!cmd_access(id,level,cid,2)) 
		return PLUGIN_HANDLED 
	new arg[32]
	read_argv(1, arg, 31)
	listening_socket = socket_listen("127.0.0.1",str_to_num(arg),SOCKET_TCP,error)
	socket_unblock(listening_socket)
	set_cvar_num("irc_listenning_socket",listening_socket)
	return 0
}

public auto_ping()
{
new IiMsg[256]
new i
for(i=0;i<128;i++)
	{
		if (IClients[i][CSocket]>0)
		{
			format(IiMsg,255,"PING :0101^n^r")
			socket_send(IClients[i][CSocket], IiMsg,strlen(IiMsg))
		}
	}
}
public auto_accept_reply() { //Autoaccept all new connections
	new i
	
	if((this_chaussette=socket_accept(listening_socket))<0)
		{
			for(i=0;i<128;i++)
				if (IClients[i][CSocket]>0)
				{
				if (socket_change(IClients[i][CSocket],1))
					process_client(i)
				IClients[i][TimeOut]=IClients[i][TimeOut]+1
				if(IClients[i][TimeOut]>50)
					{
					server_print("IRC %s Ping Time Out",IClients[i][Name])
					socket_close(IClients[i][CSocket])
					IClients[i][CSocket]=0
					IClients[i][IsAdmin]=0
					new IiMsg[512]
					format(IiMsg,511,":%s!rien@rien.com QUIT :PING Time Out^n^r",IClients[i][Name])
					to_all_irc(IiMsg,-1)
					server_print("IRC %s Ping Time Out KICKED COMPLETED",IClients[i][Name])
					}
				}
				
		}
	else
		{
			new freeid = free_slot()
			IClients[freeid][CSocket]=this_chaussette
			server_print("IRC: a new user is connecting to the server")
		}

}


public free_slot(){
	new i
	for(i=0;i<128;i++)
	if(IClients[i][CSocket]==0) return i
	return 0
}

public igplist(list[512]){
	new pname[32]
	new id
	new maxplayers
	maxplayers = get_maxplayers()
	for(id = 1 ; id <= maxplayers ; id++)
		if(is_user_connected(id))
			{
			get_user_name(id,pname,31)
			replace_all ( pname, 31, " ", "_" )
			if(is_user_admin(id))
				format(list,511,"%s @%s",list,pname)
			else
				format(list,511,"%s %s",list,pname)
			}
}

public irclist(list[512]){
	new id
	for(id = 0 ; id <= 127 ; id++)
		if(IClients[id][CSocket]>0)
			{
			if (IClients[id][IsAdmin]==0)
				format(list,511,"%s %s",list,IClients[id][Name])
			if (IClients[id][IsAdmin]==1)
				format(list,511,"%s @%s",list,IClients[id][Name])
			}
	format(list,511,"%s @SERVER",list)
}

public ircchannellist(list[512],cid){
	format(list,511,"%s @GUARD",list)
	new pid
	new id
	for(id = 0 ; id < 64 ; id++)
		if((pid=IChannel[cid][user][id])>-1)
			format(list,511,"%s %s",list,IClients[pid][Name])
}

public to_all_irc(msg[512],idnot){
	new i
	for(i=0;i<64;i++)
		if(IClients[i][CSocket]>0 && idnot!=i) 
			socket_send(IClients[i][CSocket], msg,strlen(msg))
}

public process_client(id)
{
	IClients[id][TimeOut]=0
	static recv[600]
	static lineparser[600]
	static instr[32]
	static data[512]
	static IMsg[512]
	if(strlen(recv)>4)server_print("<<%s <<%s",instr,data)
	socket_recv(IClients[id][CSocket], recv,600)
	format(recv,600,"%s^n",recv)
	IClients[id][TimeOut]=0
	while(containi(recv,"^n")>-1)
	{
		strtok(recv,lineparser,600,recv,600,'^n')
		strtok(lineparser, instr, 32, data, 512, ' ') 
		if(strlen(lineparser)>4)server_print("<<%s <<%s",instr,data)
		if (strcmp("NICK",instr,1)==0 && containi(data,":")==-1)
			{
			copyc(IClients[id][Name],32,data,'^n')
			format(IMsg,511,"NOTICE AUTH :*** Checking ... please wait %s^n",IClients[id][Name])
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
			server_print("IRC: %s has join the server",IClients[id][Name])


			}
		if (strcmp("USER",instr,1)==0 || strcmp("USERHOST",instr,1)==0)
			{
			copyc(IClients[id][Username],32,data,' ')
			format(IMsg,511,":%s MODE %s +i^n^r",IClients[id][Name],IClients[id][Username],id,IClients[id][Name])
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
			server_print("IRC: %s has join the server",IClients[id][Name])
			format(IMsg,511,"PING :0101^n^r")
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
			server_print("IRC: %s username change to %s",IClients[id][Name],IClients[id][Username])
			
			format(IMsg,511,":%s 001 %s :Welcome to this irc server ... powered by hackziner irc server^n^r",serverip,IClients[id][Name])
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
			format(IMsg,511,":%s 002 %s :Your host is %s^n^r",serverip,IClients[id][Name],serverip)
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))			
			format(IMsg,511,":%s 003 %s :This server was created by a drunk man, and this server host a lot of PORN ...^n^r",serverip,IClients[id][Name])
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))	
			format(IMsg,511,":%s 004 %s :Encore une ligne inutile ... sans commentaires ^n^r",serverip,IClients[id][Name])
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))	
			format(IMsg,511,":%s 005 %s :This server support ... nothing ... oh, maybe just your ass ^n^r",serverip,IClients[id][Name])
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))	
			format(IMsg,511,":%s 251 %s :Perhaps some people are online ... I don't how how many ^n^r",serverip,IClients[id][Name])
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))		
			format(IMsg,511,":%s 252 %s 74 : One operation is online, it's hackziner. Because like Chuck Norris, hackziner is everywhere and see everything ^n^r",serverip,IClients[id][Name])
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))	
			format(IMsg,511,":%s 253 %s 16 : What ? I don't understand, can you repeat ?^n^r",serverip,IClients[id][Name])
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))	
			
			format(IMsg,511,":%s 302 %s :%s=+~%s@%d.com^n^r",serverip,IClients[id][Name],IClients[id][Name],IClients[id][Username],id)
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
			server_print("IRC: Send userhost of %s",IClients[id][Name],IClients[id][Username])
	
			new palist[512]
			format(IMsg,511,":%s!%s@%d.com JOIN #%s^n^r",IClients[id][Name],IClients[id][Username],id,serverchannel)	
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))		
			format(IMsg,511,":%s 332 %s #%s :This is The SERVER Channel^n^r",serverip,IClients[id][Name],serverchannel)	
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))		
			copy(palist,512,IClients[id][Name])
			igplist(palist)
			irclist(palist)
			format(IMsg,511,":%s 353 = #%s :%s^n^r",serverip,serverchannel,palist)	
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))		
			format(IMsg,511,":%s 366 #%s :End of /NAMES list^n^r",serverip,serverchannel,IClients[id][Name])	
			socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
			
			format(IMsg,256,":%s!irc@rien.com JOIN #%s^n^r",IClients[id][Name],serverchannel)
			to_all_irc(IMsg,id)		
			IClients[id][IsAdmin]=0	
			
			client_print(0,print_chat,"IRC: %s has joined the server",IClients[id][Name])
			
			}
		if (containi(recv,"LAGTIMER")>-1)
			{
				format(IMsg,511,"PONG :LAGTIMER^n^r",IClients[id][Name])
				socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
				server_print("IRC: Pong replyed !!")
			}
		if (strcmp("JOIN",instr,1)==0)
			{
				new palist[512]
				new rien[32]
				//Parse channel request
				new chanel[32] //Yeah like the cosmetic
				strtok(lineparser, rien, 32, chanel, 32, '#') 
				
				
				format(IMsg,511,":%s!%s@%d.com JOIN #%s^n^r",IClients[id][Name],IClients[id][Username],id,chanel)	
				socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))		
				format(IMsg,511,":%s 332 %s #%s :Title of Channel %s^n^r",serverip,IClients[id][Name],chanel,chanel)	
				socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))		
				copy(palist,256,IClients[id][Name])
				if (strcmp(chanel,serverchannel,1)==0)
				{
					igplist(palist)
					irclist(palist)
				}
				else
				{
					new ii
					new iii
					if((ii=find_channel(chanel))>-1)
					{
						server_print("IRC: user %d is joining channel %d (%s)", id,ii,chanel)
						iii=free_user_channel(ii)
						IChannel[ii][user][iii]=id
						
					}
					else
					{
						ii=	empty_channel(chanel)
						server_print("IRC: Creating channel %d (%s)", ii,chanel)
						IChannel[ii][IsCreated]=1
						IChannel[ii][user][0]=id
						format(IChannel[ii][Name],31,"%s",chanel)
						format(IChannel[ii][Title],31,"Title of Channel %s",chanel)
					}
					
					ircchannellist(palist,ii)
				}
				format(IMsg,511,":%s 353 = #%s :%s^n^r",serverip,chanel,palist)	
				socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))		
				format(IMsg,511,":%s 366 #%s :End of /NAMES list^n^r",serverip,chanel,IClients[id][Name])	
				socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
				
				format(IMsg,256,":%s!irc@rien.com JOIN #%s^n^r",IClients[id][Name],chanel)
				to_all_irc(IMsg,id)		
				IClients[id][IsAdmin]=0				
			}
		if (strcmp("MODE",instr,1)==0)
			{
				format(IMsg,511,":%s 324 %s #server +tln 128^n^r",serverip,IClients[id][Name])	
				socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
			}
		if (strcmp("QUIT",instr,1)==0)
			{
				format(IMsg,256,":%s!irc@rien.com QUIT :has left the server^n^r",IClients[id][Name])
				to_all_irc(IMsg,id)
				socket_close(IClients[id][CSocket])
				IClients[id][CSocket]=0
				IClients[id][IsAdmin]=0
				server_print("IRC: %s has left the server",IClients[id][Name])
			}
		if (strcmp("PART",instr,1)==0)
			{
				new OMFG
				new AbbatBush //Very bad french wordplay :)
				new chanel[32]
				new rien[32]
				strtok(lineparser, rien, 32, chanel, 32, '#') 				
				OMFG=find_channel(chanel)
				for(AbbatBush=0;AbbatBush<64;AbbatBush++)
					if(IChannel[OMFG][user][AbbatBush]==id)IChannel[OMFG][user][AbbatBush]=-1
					
				format(IMsg,256,":%s!irc@rien.com PART %s^n^r",IClients[id][Name],data)
				to_all_irc(IMsg,-1)
				server_print("IRC: %s has left channel %s",IClients[id][Name],data)
				
			}
		if (strcmp("PRIVMSG",instr,1)==0)
			{
				new TmpMsg[128]		
				copyc(TmpMsg,127,data,' ')		
				if(strcmp("SERVER",TmpMsg,1)==0)
				{
					new splita[128]
					new splitb[128]
					strtok(data,splita,128,splitb,128,':')
					strtok(splitb,splita,128,TmpMsg,128,' ')
					if(strcmp("AUTH",splita,1)==0)
						{
						copyc(splitb,64,TmpMsg,'^n')
						if(strcmp(adminpassword,splitb,1)==0)
							{
								format(IMsg,511,":%s MODE #%s +o %s^n^r",serverip,serverchannel,IClients[id][Name])	
								to_all_irc(IMsg,-1)
								IClients[id][IsAdmin]=1
							}
						else
							{
								format(IMsg,256,":%s!irc@rien.com PRIVMSG %s :Stop it !^n^r",IClients[id][Name],IClients[id][Name])
								socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
							}	
						}
					else
						{
							if(IClients[id][IsAdmin]==1)
								{
									new cmd[128]
									copyc(cmd,127,splitb,'^n')
									strtolower(cmd)
									server_cmd("%s",cmd)
								}
							else
								{
									format(IMsg,256,":%s!irc@rien.com PRIVMSG %s :Stop it !^n^r",IClients[id][Name],IClients[id][Name])
									socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
								}		
						}
						
				}
				else
				{
					copyc(TmpMsg,127,data,'^n')
					client_print(0,print_chat,"IRC: %s says %s",IClients[id][Name],TmpMsg)
					format(IMsg,256,":%s!irc@rien.com PRIVMSG %s^n^r",IClients[id][Name],TmpMsg)
					to_all_irc(IMsg,id)
				}
			}
		if (strcmp("NOTICE",instr,1)==0)
			{
				new TmpMsg[128]
				copyc(TmpMsg,127,data,'^n')
				client_print(0,print_chat,"IRC: %s notice %s",IClients[id][Name],TmpMsg)
				format(IMsg,256,":%s!irc@rien.com NOTICE %s^n^r",IClients[id][Name],TmpMsg)
				to_all_irc(IMsg,id)
			}
		if (strcmp("AUTH",instr,1)==0)
			{
			new TmpMsg[64]
			copyc(TmpMsg,64,data,'^n')
			if(strcmp(adminpassword,TmpMsg,1)==0)
				{
					format(IMsg,511,":%s MODE #%s +o %s^n^r",serverip,serverchannel,IClients[id][Name])	
					to_all_irc(IMsg,-1)
					IClients[id][IsAdmin]=1
					server_print("IRC: %s is auth as admin !",IClients[id][Name])
					client_print(0,print_chat,"IRC: %s is auth as admin !",IClients[id][Name])
				}
			else
				{
					format(IMsg,256,":%s!irc@rien.com PRIVMSG %s :Little boy, Stop It !! !^n^r",IClients[id][Name],IClients[id][Name])
					socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
				}
			}
		if (strcmp("NICK",instr,1)==0 && containi(data,":")!=-1 )
			{
			new TmpMsg[64]
			new pnamea[32]
			new pnameb[32]
			copyc(TmpMsg,64,data,'^n')
			strtok(TmpMsg,pnamea,31,pnameb,31,':')
			format(IMsg,511,":%s NICK %s^n^r",IClients[id][Name],pnameb)
			client_print(0,print_chat,"IRC: %s is now known as %s",pnameb,IClients[id][Name])			
			to_all_irc(IMsg,-1)
			copyc(IClients[id][Name],32,pnameb,'^n')
			}

		if (strcmp("KICK",instr,1)==0)
			{
				if(IClients[id][IsAdmin]==1)
					{
						new pname[32]
						new pnamek[32]
						new pnamea[32]
						new pnameb[32]
						strtok(data,pnamea,31,pnameb,31,' ')
						copyc(pname,31,pnameb,'^n')
						copyc(pnamea,31,pname,'^n')
						copyc(pnamek,31,pname,'^n')
						server_print("Admin kick %s",pnamea)
						//If player on server
						new i
						new maxplayers
						maxplayers = get_maxplayers()
						for(i = 1 ; i <= maxplayers ; i++)
								{
								get_user_name(i,pname,31)
								get_user_name(i,pnameb,31)
								replace_all ( pname, 31, " ", "_" )
								if (strcmp(pname,pnamea,1)==0)
									server_cmd("KICK ^"%s^" IRC Chan Operator KICK (%s)",pnameb,IClients[id][Name])
								}
						//If player on irc
						copyc(pname,31,data,'^n')
						for(i=0;i<128;i++)
							if(strcmp(IClients[i][Name],pnamek,1)==0)
								{
									format(IMsg,256,":%s!irc@rien.com QUIT :KICKED By %s^n^r",pnamek,IClients[id][Name])
									to_all_irc(IMsg,-1)
									IClients[i][CSocket]=0
								}
					}
				else
					{
						format(IMsg,256,":%s!irc@rien.com PRIVMSG %s :You're not admin little boy !^n^r",IClients[id][Name],IClients[id][Name])
						socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
					}
			}
		if (containi(instr,"AMX")>-1)
			{
				server_print("%s try to execute a command from irc!",IClients[id][Name])
				if(IClients[id][IsAdmin]==1)
					{
						new cmd[128]
						copyc(cmd,127,lineparser,'^n')
						strtolower(cmd)
						server_cmd("%s",cmd)
					}
				else
					{
						format(IMsg,256,":%s!irc@rien.com PRIVMSG %s :Stop it !^n^r",IClients[id][Name],IClients[id][Name])
						socket_send(IClients[id][CSocket], IMsg,strlen(IMsg))
					}			
			}
	}
}


public client_authorized ( id ) 
{
	new pname[32]
	new psid[32]
	new IiMsg[512]
	get_user_name(id,pname,31)
	replace_all ( pname, 31, " ", "_" )
	format(IiMsg,511,":%s!ingame@rien.com JOIN #%s^n^r",pname,serverchannel)
	to_all_irc(IiMsg,-1)
}


public client_disconnect ( id ) 
{
	new pname[32]
	new psid[32]
	new IiMsg[512]
	get_user_name(id,pname,31)
	replace_all ( pname, 31, " ", "_" )
	format(IiMsg,511,":%s!ingame@rien.com QUIT :has left the server^n^r",pname)
	to_all_irc(IiMsg,-1)
}


public handle_say(id) 
{
	static said[192]
	read_args(said,192)
	new pname[32]
	new psid[32]
	new IiMsg[512]
	get_user_name(id,pname,31)
	replace_all ( pname, 31, " ", "_" )
	format(IiMsg,511,":%s!ingame@rien.com PRIVMSG #%s :%s^n^r",pname,said,serverchannel)
	to_all_irc(IiMsg,-1)	
}

public find_channel(name[32])
{
new i
for(i=0;i<32;i++)
	if(!strcmp(IChannel[i][Name],name,1))
		return i
return -1
}

public empty_channel(name[32])
{
new i
for(i=0;i<32;i++)
	if(IChannel[i][IsCreated]==0)
		return i
return 0
}
public free_user_channel(id)
{
new i
for(i=0;i<64;i++)
	if(IChannel[id][user][i]==-1)
		return i
return 0
}
