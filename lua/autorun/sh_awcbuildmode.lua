
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
		
		net.Start( "buildrequest" )
		net.WriteTable(BuildModed)
		net.Send(player.GetAll())
	end )
	
	local function BuildDisconnect(ply)
		table.RemoveByValue(BuildModed, ply)
		net.Start( "buildrequest" )
		net.WriteTable(BuildModed)
		net.Send(player.GetAll())
	end
	hook.Add("PlayerDisconnect", "BuildDisconnect", BuildDisconnect)
	
	--Damage restriction
	local function BuildShouldTakeDamage(ply, attacker)	
		if(table.HasValue(BuildModed, attacker) && (attacker != ply)) then
			BuildChatNotify(attacker, "You can't hurt other players when you're in build mode.")
			return false
		end
	
		if(table.HasValue(BuildModed, ply)) then
			BuildChatNotify(attacker, "You can't hurt players who are in build mode.")
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
	local BuildModed = {}

	concommand.Add( "buildmode", function(ply, cmd, args, argstring)
		net.Start( "buildrequest" )
		net.SendToServer()
	end )

	net.Receive( "buildnotify", function( len, ply )
		chat.AddText(Color(46,204,113), "[BuildMode] ", Color(220,220,220), net.ReadString())
	end )
	
	net.Receive( "buildrequest", function( len, ply )
		BuildModed = net.ReadTable()
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
	
	--effects
	
	
	//local matBuildMode = CreateMaterial( "matBuildMode", "UnlitGeneric", { [ "$basetexture" ] = "models/props_combine/com_shield001a" } )
	local matBuildMode = Material("models/props_combine/com_shield001a")
	local function BuildDrawSilhouette()

		render.ClearStencil()
		render.SetStencilEnable( true )
		
		render.SetStencilWriteMask( 3 ) -- Fix halo lib ( 3 = 0b11 )
		render.SetStencilTestMask( 3 )

		render.SetStencilFailOperation( STENCILOPERATION_KEEP )
		render.SetStencilZFailOperation( STENCILOPERATION_KEEP )
		render.SetStencilPassOperation( STENCILOPERATION_REPLACE )
		render.SetStencilCompareFunction( STENCILCOMPARISONFUNCTION_ALWAYS )
		
		render.SetStencilReferenceValue( 10 )
		
		for _, ply in pairs( BuildModed ) do
			if(ply:IsValid() && ply:GetActiveWeapon():IsValid()) then
				ply:DrawModel()
				ply:GetActiveWeapon():DrawModel()
			end
		end
		
		render.SetStencilCompareFunction( STENCILCOMPARISONFUNCTION_EQUAL )
		render.SetMaterial( matBuildMode )
		render.DrawScreenQuad()
		
		render.SetStencilEnable( false )
		
	end
	hook.Add("PostDrawOpaqueRenderables", "BuildDrawSilhouette", BuildDrawSilhouette)
	
end
