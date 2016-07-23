
AddCSLuaFile()

if(SERVER) then

	--Keep track of all the buildmoded players
	local BuildModed = {}
	
	util.AddNetworkString( "buildrequest" )
	util.AddNetworkString( "buildupdate" )
	util.AddNetworkString( "buildannounce" )
	util.AddNetworkString( "buildnotify" )
	util.AddNetworkString( "buildhudnotify" )
	
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
	
	local function BuildHUDNotify(ply, str)
		if(!ply:IsPlayer()) then
			return
		end
		net.Start( "buildhudnotify" )
		net.WriteString(str)
		net.Send(ply)
	end
	
	net.Receive( "buildrequest", function( len, ply )
		if(table.HasValue(BuildModed, ply)) then
			if(ply:GetMoveType() == MOVETYPE_NOCLIP) then
				BuildChatNotify(ply, "Get out of noclip before you leave build mode.")
				BuildHUDNotify(ply, "Get out of noclip before you leave build mode.")
			else
				if(table.RemoveByValue( BuildModed, ply ) != false) then
					BuildGlobalChatAnnounce(ply, " has left build mode.")
				end
			end
		else
			BuildGlobalChatAnnounce(ply, " has entered build mode.")
			table.insert( BuildModed, ply )
		end
		
		net.Start( "buildupdate" )
		net.WriteTable(BuildModed)
		net.Send(player.GetAll())
	end )
	
	local function BuildDisconnect(ply)
		table.RemoveByValue(BuildModed, ply)
		net.Start( "buildupdate" )
		net.WriteTable(BuildModed)
		net.Send(player.GetAll())
	end
	hook.Add("PlayerDisconnect", "BuildDisconnect", BuildDisconnect)
	
	--Damage restriction
	local function BuildShouldTakeDamage(ply, attacker)	
		if(table.HasValue(BuildModed, attacker) && (attacker != ply)) then
			BuildHUDNotify(attacker, "You can't hurt other players when you're in build mode.")
			return false
		end
	
		if(table.HasValue(BuildModed, ply)) then
			BuildHUDNotify(attacker, "You can't hurt players who are in build mode.")
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
		chat.AddText(Color(100,113,225), "[BuildMode] ", Color(220,220,220), net.ReadString())
	end )
	
	net.Receive( "buildupdate", function( len, ply )
		BuildModed = net.ReadTable()
	end )
	
	net.Receive( "buildannounce", function( len, ply )
		chat.AddText(Color(100,113,225), "[BuildMode] ", Color(220,220,220), net.ReadEntity(), net.ReadString())
	end )
	
	local function BuildChatCommands( ply, text, teamChat, isDead )
		if ply != LocalPlayer() then return end
	
		local expl = string.Explode(" ", text, false)
		local cmp = string.lower(expl[1])
		if ( cmp == "!build" || cmp == "!buildmode" || cmp == "!pvp" || cmp == "/build" || cmp == "/buildmode" || cmp == "/pvp" ) then
			net.Start( "buildrequest" )
			net.SendToServer()
			return true
		end
	end
	hook.Add( "OnPlayerChat", "BuildChatCommands", BuildChatCommands)
	
	//-----Quality of life stuff down here-----//
	
	surface.CreateFont( "bmCV15",
	{
		font      = "coolvetica",
		size      = ScreenScale(15),
		weight    = 500,
		antialias 	= true,
		blursize 	= 0,
		scanlines 	= 0,
		underline 	= false,
		italic 		= false,
		strikeout 	= false,
		symbol 		= false,
		rotary 		= false,
		shadow 		= false,
		additive 	= false,
		outline 	= false
	})
	
	local HUDNotifMessage = ""
	local HUDNotifDieTime = 0
	
	local HUDNotifLife = 3.5
	
	net.Receive( "buildhudnotify", function( len, ply )
		HUDNotifMessage = net.ReadString()
		HUDNotifDieTime = CurTime() + HUDNotifLife
	end )

	
	//predict noclip on client
	local function BuildModeNoclip( ply )
		return table.HasValue(BuildModed, ply);
	end
	hook.Add( "PlayerNoClip", "BuildModeNoclip", BuildModeNoclip )

	//HUD stuff
	hook.Add( "HUDPaint", "BuildModePaintHUD", function()
		//Indicator so you know if you have build mode or not.
		if(table.HasValue(BuildModed, LocalPlayer())) then
			local enablemessage = "Build Mode Active"
			surface.SetFont( "bmCV15" )
			surface.SetTextColor( 0, 255, 255, 160 )
			local w,h = surface.GetTextSize( enablemessage ) 
			surface.SetTextPos( ScrW()*0.5-w*0.5, h )
			surface.DrawText( enablemessage )
		end
		
		//Show HUD Notifications (instead of chat!)
		if(CurTime() < HUDNotifDieTime) then
			surface.SetFont( "bmCV15" )
			surface.SetTextColor( 255*math.Clamp((HUDNotifDieTime-(CurTime()+(HUDNotifLife-0.25)))*5,0,1), 255, 255, math.Clamp((HUDNotifDieTime-(CurTime()))*255,0,255) )
			local w,h = surface.GetTextSize( HUDNotifMessage ) 
			surface.SetTextPos( ScrW()*0.5-w*0.5, ScrH()*0.6 + h )
			surface.DrawText( HUDNotifMessage )
		end
	end )

	//Stencils to tell if another player is in build mode or not.
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
		
		render.SetStencilReferenceValue( 42 )
		
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
