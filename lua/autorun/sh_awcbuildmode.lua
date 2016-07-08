
AddCSLuaFile()

if(SERVER) then

	--Keep track of all the buildmoded players
	local BuildModed = {}
	
	util.AddNetworkString( "buildrequest" )
	util.AddNetworkString( "buildannounce" )
	util.AddNetworkString( "buildnotify" )
	
	local function BuildGlobalChatAnnounce(p1, str1)
		net.Start( "buildannounce" )
		net.WriteEntity(p1)
		net.WriteString(str1)
		net.Send(player.GetAll())
	end
	
	local function BuildChatNotify(ply, str)
		if(!ply:IsPlayer()) then
			return
		end
		net.Start( "buildnotify" )
		net.WriteString(str)
		net.Send(ply)
	end
	
	net.Receive( "buildrequest", function( len, ply )
		if(table.HasValue(BuildModed, ply)) then
			if(ply:GetMoveType() == MOVETYPE_NOCLIP) then
				BuildChatNotify(ply, "Get out of noclip before you leave build mode.")
			else
				if(table.RemoveByValue( BuildModed, ply ) != false) then
					BuildGlobalChatAnnounce(ply, " has left build mode.")
				end
			end
		else
			BuildGlobalChatAnnounce(ply, " has entered build mode.")
			table.insert( BuildModed, ply )
		end
	end )
	
	local function BuildDisconnect(ply)
		table.RemoveByValue(BuildModed, ply)
	end
	hook.Add("PlayerDisconnect", "BuildDisconnect", BuildDisconnect)
	
	--Damage restriction
	local function BuildShouldTakeDamage(ply, attacker)		
		if(table.HasValue(BuildModed, ply)) then
			BuildChatNotify(attacker, "You can't hurt players who are in build mode.")
			return false
		end
		
		if(table.HasValue(BuildModed, attacker) && (attacker != ply)) then
			BuildChatNotify(attacker, "You can't hurt other players when you're in build mode.")
			return false
		end
		
		return true
	end
	hook.Add("PlayerShouldTakeDamage", "BuildShouldTakeDamage", BuildShouldTakeDamage)
	
	//make this on client too later.
	local function BuildModeNoclip( ply )
		return table.HasValue(BuildModed, ply);
	end
	hook.Add( "PlayerNoClip", "BuildModeNoclip", BuildModeNoclip )
	
end

if (CLIENT) then
	concommand.Add( "buildmode", function(ply, cmd, args, argstring)
		net.Start( "buildrequest" )
		net.SendToServer()
	end )

	net.Receive( "buildnotify", function( len, ply )
		chat.AddText(Color(46,204,113), "[BuildMode] ", Color(220,220,220), net.ReadString())
	end )
	
	net.Receive( "buildannounce", function( len, ply )
		chat.AddText(Color(46,204,113), "[BuildMode] ", Color(220,220,220), net.ReadEntity(), net.ReadString())
	end )
	
	local function BuildChatCommands( ply, text, teamChat, isDead )
		if ply != LocalPlayer() then return end
	
		local expl = string.Explode(" ", text, false)
		
		if ( expl[1] == "!build" || expl[1] == "!buildmode" || expl[1] == "!pvp" || expl[1] == "/build" || expl[1] == "/buildmode" || expl[1] == "/pvp" ) then
			net.Start( "buildrequest" )
			net.SendToServer()
			return true
		end
	end
	hook.Add( "OnPlayerChat", "BuildChatCommands", BuildChatCommands)
	
end
