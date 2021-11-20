/*
	Project: Dynamic SQLite Housing System (SA-MP)
	Version: 1.0 (2021)
	Credits: Weponz (Developer), [N]1ghtM4r3_ (BETA Tester), H&Wplayz (BETA Tester)
*/
#define FILTERSCRIPT
#include <a_samp>//Credits: SA-MP Team
#include <samp_bcrypt>//Credits: _SyS_
#include <streamer>//Credits: Incognito
#include <sscanf2>//Credits: Y_Less
#include <zcmd>//Credits: ZeeX

#define ERROR_COLOUR 0xFF0000FF//Default: Red
#define NOTICE_COLOUR 0xFFFF00FF//Default: Yellow
#define LABEL_COLOUR 0xFFFFFFFF//Default: White

#define SERVER_DATABASE "houses.db"//This is where the database will be saved (scriptfiles)

#define MAX_HOUSES 500//This will be the maximum amount of houses that can be created

#define LAND_VALUE_PERCENT 12//The percentage of interest added when a nearby house sells (Default: 12%)

#define HOUSE_ONE_PRICE (random(500000) + 500000)//Default: 1 Story House (Random 500K-1M)
#define HOUSE_TWO_PRICE (random(1000000) + 1000000)//Default: 2 Story House (Random 1M-2M)
#define MANSION_ONE_PRICE (random(2000000) + 2000000)//Default: Small Mansion (Random 2M-4M)
#define MANSION_TWO_PRICE (random(4000000) + 4000000)//Default: Large Mansion (Random 4M-8M)
#define APARTMENT_PRICE (random(3000000) + 3000000)//Default: Apartment (Random 3M-6M)

#define BUY_DIALOG 1234//Change this number if it clashes with other scripts using the same dialogid
#define VERIFY_DIALOG 1235//Change this number if it clashes with other scripts using the same dialogid
#define ACCESS_DIALOG 1236//Change this number if it clashes with other scripts using the same dialogid
#define MENU_DIALOG 1237//Change this number if it clashes with other scripts using the same dialogid
#define NAME_DIALOG 1238//Change this number if it clashes with other scripts using the same dialogid
#define PASS_DIALOG 1239//Change this number if it clashes with other scripts using the same dialogid
#define SAFE_DIALOG 1240//Change this number if it clashes with other scripts using the same dialogid
#define BALANCE_DIALOG 1241//Change this number if it clashes with other scripts using the same dialogid
#define DEPOSIT_DIALOG 1242//Change this number if it clashes with other scripts using the same dialogid
#define WITHDRAW_DIALOG 1243//Change this number if it clashes with other scripts using the same dialogid
#define SELL_DIALOG 1244//Change this number if it clashes with other scripts using the same dialogid
#define COMMANDS_DIALOG 1245//Change this number if it clashes with other scripts using the same dialogid

forward EncryptHousePassword(playerid, houseid);
forward VerifyHousePassword(playerid, bool:success);

new DB:server_database;
new DBResult:database_result;

enum player_data
{
	player_houseid,
	player_salehouse,
	player_saleprice,
	player_saleowner,
	player_saleto,
	player_spam,
	bool:player_saleactive
};
new PlayerData[MAX_PLAYERS][player_data];

enum house_data
{
	house_owner[MAX_PLAYER_NAME],
	house_name[64],
	house_value,
	house_safe,
	Float:house_extx,
	Float:house_exty,
	Float:house_extz,
	Float:house_intx,
	Float:house_inty,
	Float:house_intz,
	Float:house_enterx,
	Float:house_entery,
	Float:house_enterz,
	Float:house_entera,
	Float:house_exitx,
	Float:house_exity,
	Float:house_exitz,
	Float:house_exita,
	house_extinterior,
	house_extworld,
	house_intinterior,
	house_intworld,
	house_mapicon,
	house_entercp,
	house_exitcp,
	Text3D:house_label,
	bool:house_active
};
new HouseData[MAX_HOUSES][house_data];

stock GetName(playerid)
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));
	return name;
}

stock IsNumeric(string[])
{
    for(new i = 0, j = strlen(string); i < j; i++)
    {
        if(string[i] > '9' || string[i] < '0') return 0;
    }
    return 1;
}

stock Float:GetPosBehindPlayer(playerid, &Float:x, &Float:y, Float:distance)
{
    new Float:a;
    GetPlayerPos(playerid, x, y, a);
    
    if(IsPlayerInAnyVehicle(playerid))
	{
	    GetVehicleZAngle(GetPlayerVehicleID(playerid), a);
	}
    else
    {
        GetPlayerFacingAngle(playerid, a);
        
        x -= (distance * floatsin(-a, degrees));
        y -= (distance * floatcos(-a, degrees));
	}
    return a;
}

stock PointInRangeOfPoint(Float:range, Float:x, Float:y, Float:z, Float:x2, Float:y2, Float:z2)
{
    x2 -= x;
    y2 -= y;
    z2 -= z;
    return ((x2 * x2) + (y2 * y2) + (z2 * z2)) < (range * range);
}

stock ReturnPercent(amount, percent)
{
	return (amount / 100 * percent);
}

stock GetFreeHouseSlot()
{
	new query[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
		format(query, sizeof(query), "SELECT `ID` FROM `HOUSES` WHERE `ID` = '%i'", i);
		database_result = db_query(server_database, query);
		if(!db_num_rows(database_result))
		{
		    return i;
		}
	}
	return -1;
}

stock IsPlayerNearHouse(playerid, Float:distance)
{
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][house_active] == true)
	    {
	    	if(IsPlayerInRangeOfPoint(playerid, distance, HouseData[i][house_extx], HouseData[i][house_exty], HouseData[i][house_extz])) return 1;
	    }
	}
	return 0;
}

stock GetOwnedHouseID(playerid)
{
	new query[128], field[MAX_PLAYER_NAME];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][house_active] == true)
	    {
		    format(query, sizeof(query), "SELECT `OWNER` FROM `HOUSES` WHERE `ID` = '%i'", i);
			database_result = db_query(server_database, query);
			if(db_num_rows(database_result))
		  	{
		    	db_get_field_assoc(database_result, "OWNER", field, sizeof(field));

				db_free_result(database_result);

			 	if(!strcmp(HouseData[i][house_owner], GetName(playerid), true) && IsPlayerInRangeOfPoint(playerid, 100.0, HouseData[i][house_intx], HouseData[i][house_inty], HouseData[i][house_intz])) return i;
			}
			db_free_result(database_result);
		}
	}
	return -1;
}

stock UpdateNearbyLandValue(houseid)
{
	new label[128], query[128];
    for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][house_active] == true && i != houseid)
		{
			if(PointInRangeOfPoint(100.0, HouseData[houseid][house_extx], HouseData[houseid][house_exty], HouseData[houseid][house_extz], HouseData[i][house_extx], HouseData[i][house_exty], HouseData[i][house_extz]))
			{
				HouseData[i][house_value] = (HouseData[i][house_value] + ReturnPercent(HouseData[i][house_value], LAND_VALUE_PERCENT));

			 	if(!strcmp(HouseData[i][house_owner], "~", true))
				{
					format(label, sizeof(label), "4-Sale\nPrice: $%i", HouseData[i][house_value]);
					UpdateDynamic3DTextLabelText(HouseData[i][house_label], LABEL_COLOUR, label);
				}
				else
				{
					format(label, sizeof(label), "%s\nValue: $%i", HouseData[i][house_name], HouseData[i][house_value]);
					UpdateDynamic3DTextLabelText(HouseData[i][house_label], LABEL_COLOUR, label);
				}

				format(query, sizeof(query), "UPDATE `HOUSES` SET `VALUE` = '%i' WHERE `ID` = '%i'", HouseData[i][house_value], i);
				database_result = db_query(server_database, query);
				db_free_result(database_result);
		    }
	    }
	}
	return 1;
}

public OnFilterScriptInit()
{
    server_database = db_open(SERVER_DATABASE);
    db_query(server_database, "CREATE TABLE IF NOT EXISTS `HOUSES` (`ID`, `OWNER`, `NAME`, `PASS`, `VALUE`, `SAFE`, `EXTX`, `EXTY`, `EXTZ`, `INTX`, `INTY`, `INTZ`, `ENTERX`, `ENTERY`, `ENTERZ`, `ENTERA`, `EXITX`, `EXITY`, `EXITZ`, `EXITA`, `EXTINTERIOR`, `EXTWORLD`, `INTINTERIOR`, `INTWORLD`)");

	new query[128], field[64], field2[MAX_PLAYER_NAME], label[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
		format(query, sizeof(query), "SELECT * FROM `HOUSES` WHERE `ID` = '%i'", i);
		database_result = db_query(server_database, query);
		if(db_num_rows(database_result))
		{
	 		db_get_field_assoc(database_result, "OWNER", field2, sizeof(field2));
	     	HouseData[i][house_owner] = field2;

	     	db_get_field_assoc(database_result, "NAME", field, sizeof(field));
	     	HouseData[i][house_name] = field;

	    	db_get_field_assoc(database_result, "VALUE", field, sizeof(field));
	      	HouseData[i][house_value] = strval(field);

	     	db_get_field_assoc(database_result, "SAFE", field, sizeof(field));
	     	HouseData[i][house_safe] = strval(field);

	     	db_get_field_assoc(database_result, "EXTX", field, sizeof(field));
	      	HouseData[i][house_extx] = floatstr(field);

	    	db_get_field_assoc(database_result, "EXTY", field, sizeof(field));
	    	HouseData[i][house_exty] = floatstr(field);

	      	db_get_field_assoc(database_result, "EXTZ", field, sizeof(field));
	     	HouseData[i][house_extz] = floatstr(field);

	    	db_get_field_assoc(database_result, "INTX", field, sizeof(field));
	     	HouseData[i][house_intx] = floatstr(field);

	      	db_get_field_assoc(database_result, "INTY", field, sizeof(field));
	      	HouseData[i][house_inty] = floatstr(field);

	     	db_get_field_assoc(database_result, "INTZ", field, sizeof(field));
	      	HouseData[i][house_intz] = floatstr(field);

	     	db_get_field_assoc(database_result, "ENTERX", field, sizeof(field));
	      	HouseData[i][house_enterx] = floatstr(field);

	      	db_get_field_assoc(database_result, "ENTERY", field, sizeof(field));
	      	HouseData[i][house_entery] = floatstr(field);

	      	db_get_field_assoc(database_result, "ENTERZ", field, sizeof(field));
	      	HouseData[i][house_enterz] = floatstr(field);

	      	db_get_field_assoc(database_result, "ENTERA", field, sizeof(field));
	      	HouseData[i][house_entera] = floatstr(field);

	      	db_get_field_assoc(database_result, "EXITX", field, sizeof(field));
	     	HouseData[i][house_exitx] = floatstr(field);

	    	db_get_field_assoc(database_result, "EXITY", field, sizeof(field));
	      	HouseData[i][house_exity] = floatstr(field);

	     	db_get_field_assoc(database_result, "EXITZ", field, sizeof(field));
	     	HouseData[i][house_exitz] = floatstr(field);

	     	db_get_field_assoc(database_result, "EXITA", field, sizeof(field));
	      	HouseData[i][house_exita] = floatstr(field);

	      	db_get_field_assoc(database_result, "EXTINTERIOR", field, sizeof(field));
	      	HouseData[i][house_extinterior] = strval(field);

	      	db_get_field_assoc(database_result, "EXTWORLD", field, sizeof(field));
	      	HouseData[i][house_extworld] = strval(field);

	     	db_get_field_assoc(database_result, "INTINTERIOR", field, sizeof(field));
	      	HouseData[i][house_intinterior] = strval(field);

	     	db_get_field_assoc(database_result, "INTWORLD", field, sizeof(field));
	      	HouseData[i][house_intworld] = strval(field);
	      	
	      	HouseData[i][house_active] = true;

			format(label, sizeof(label), "%s\nValue: $%i", HouseData[i][house_name], HouseData[i][house_value]);
			HouseData[i][house_label] = CreateDynamic3DTextLabel(label, LABEL_COLOUR, HouseData[i][house_extx], HouseData[i][house_exty], HouseData[i][house_extz] + 0.2, 4.0, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 1, HouseData[i][house_extworld], HouseData[i][house_extinterior], -1, 4.0);

			if(!strcmp(HouseData[i][house_owner], "~", true))
			{
				HouseData[i][house_mapicon] = CreateDynamicMapIcon(HouseData[i][house_extx], HouseData[i][house_exty], HouseData[i][house_extz], 31, -1, -1, -1, -1, 250.0);
			}
			else
			{
				HouseData[i][house_mapicon] = CreateDynamicMapIcon(HouseData[i][house_extx], HouseData[i][house_exty], HouseData[i][house_extz], 32, -1, -1, -1, -1, 250.0);
			}

			HouseData[i][house_entercp] = CreateDynamicCP(HouseData[i][house_extx], HouseData[i][house_exty], HouseData[i][house_extz], 1.0, HouseData[i][house_extworld], HouseData[i][house_extinterior], -1, 4.0);
			HouseData[i][house_exitcp] = CreateDynamicCP(HouseData[i][house_intx], HouseData[i][house_inty], HouseData[i][house_intz], 1.0, HouseData[i][house_intworld], HouseData[i][house_intinterior], -1, 4.0);

			db_free_result(database_result);
		}
	}
	return 1;
}

public OnFilterScriptExit()
{
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][house_active] == true)
	    {
			DestroyDynamic3DTextLabel(HouseData[i][house_label]);
			DestroyDynamicMapIcon(HouseData[i][house_mapicon]);
			DestroyDynamicCP(HouseData[i][house_entercp]);
			DestroyDynamicCP(HouseData[i][house_exitcp]);

			HouseData[i][house_active] = false;
		}
	}
	
    db_close(server_database);
	return 1;
}

public OnPlayerConnect(playerid)
{
    PlayerData[playerid][player_houseid] = -1;
	PlayerData[playerid][player_salehouse] = -1;
	PlayerData[playerid][player_saleprice] = 0;
	PlayerData[playerid][player_saleowner] = INVALID_PLAYER_ID;
	PlayerData[playerid][player_saleto] = INVALID_PLAYER_ID;
	PlayerData[playerid][player_spam] = 0;
	PlayerData[playerid][player_saleactive] = false;
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid)
	{
	    case BUY_DIALOG:
	    {
	        if(response)
	        {
	            new string[128];
		   		format(string, sizeof(string), "{FFFFFF}Are you sure you want to buy this house for $%i?", HouseData[PlayerData[playerid][player_houseid]][house_value]);
	            return ShowPlayerDialog(playerid, VERIFY_DIALOG, DIALOG_STYLE_MSGBOX, "{FFFFFF}Verify Purchase", string, "Yes", "No");
	        }
	        else
	        {
				SetPlayerInterior(playerid, HouseData[PlayerData[playerid][player_houseid]][house_intinterior]);
				SetPlayerVirtualWorld(playerid, HouseData[PlayerData[playerid][player_houseid]][house_intworld]);
   	    	  	SetPlayerPos(playerid, HouseData[PlayerData[playerid][player_houseid]][house_enterx], HouseData[PlayerData[playerid][player_houseid]][house_entery], HouseData[PlayerData[playerid][player_houseid]][house_enterz]);
   	    	  	SetPlayerFacingAngle(playerid, HouseData[PlayerData[playerid][player_houseid]][house_entera]);
   	    	  	return SetCameraBehindPlayer(playerid);
	        }
	    }
	    case VERIFY_DIALOG:
	    {
	        if(response)
	        {
	            new houseid = PlayerData[playerid][player_houseid];
	            if(GetPlayerMoney(playerid) < HouseData[houseid][house_value]) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You don't have enough money to buy this house.");
	            
	            GivePlayerMoney(playerid, -HouseData[houseid][house_value]);
	            
	            UpdateNearbyLandValue(houseid);
	            
				new owner[MAX_PLAYER_NAME], name[64], label[128], query[200];
				format(owner, sizeof(owner), "%s", GetName(playerid));
				format(name, sizeof(name), "%s's House", GetName(playerid));
				format(label, sizeof(label), "%s\nValue: $%i", name, HouseData[houseid][house_value]);
				
				HouseData[houseid][house_owner] = owner;
				HouseData[houseid][house_name] = name;
				
				UpdateDynamic3DTextLabelText(HouseData[houseid][house_label], LABEL_COLOUR, label);
				
				DestroyDynamicMapIcon(HouseData[houseid][house_mapicon]);
				HouseData[houseid][house_mapicon] = CreateDynamicMapIcon(HouseData[houseid][house_extx], HouseData[houseid][house_exty], HouseData[houseid][house_extz], 32, -1, -1, -1, -1, 250.0);
				
				SetPlayerPos(playerid, HouseData[houseid][house_exitx], HouseData[houseid][house_exity], HouseData[houseid][house_exitz]);
				SetPlayerFacingAngle(playerid, HouseData[houseid][house_exita] + 180);
				SetCameraBehindPlayer(playerid);

				format(query, sizeof(query), "UPDATE `HOUSES` SET `OWNER` = '%q', `NAME` = '%q' WHERE `ID` = '%i'", owner, name, houseid);
				database_result = db_query(server_database, query);
				db_free_result(database_result);
	        }
	        return 1;
		}
	    case ACCESS_DIALOG:
	    {
	        if(response)
	        {
	            if(strlen(inputtext) < 3 || strlen(inputtext) > 32) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: The password must be from 3-32 characters long.");

	            new houseid = PlayerData[playerid][player_houseid], query[128], field[64];
	            format(query, sizeof(query), "SELECT `PASS` FROM `HOUSES` WHERE `ID` = '%i'", houseid);
				database_result = db_query(server_database, query);
		     	if(db_num_rows(database_result))
				{
					db_get_field_assoc(database_result, "PASS", field, sizeof(field));
			    	bcrypt_verify(playerid, "VerifyHousePassword", inputtext, field);
				}
				db_free_result(database_result);
	        }
	        return 1;
	    }
	    case MENU_DIALOG:
	    {
	        if(response)
	        {
	            switch(listitem)
	            {
	                case 0:
	                {
	                    return ShowPlayerDialog(playerid, SAFE_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Safe", "{FFFFFF}Balance\nDeposit\nWithdraw", "Select", "Cancel");
	                }
	                case 1:
	                {
	                    return ShowPlayerDialog(playerid, NAME_DIALOG, DIALOG_STYLE_INPUT, "{FFFFFF}Change House Name", "{FFFFFF}Please enter a new name for your house below:", "Enter", "Cancel");
	                }
	                case 2:
	                {
	                    return ShowPlayerDialog(playerid, PASS_DIALOG, DIALOG_STYLE_PASSWORD, "{FFFFFF}Change House Password", "{FFFFFF}Please enter a new password to give access to other players:", "Enter", "Cancel");
	                }
	                case 3:
	                {
	                    new string[128];
	                    format(string, sizeof(string), "{FFFFFF}Do you want to sell your house for $%i?", HouseData[PlayerData[playerid][player_houseid]][house_value]);
	                    return ShowPlayerDialog(playerid, SELL_DIALOG, DIALOG_STYLE_MSGBOX, "{FFFFFF}Sell House", string, "Yes", "No");
	                }
				}
	        }
	        return 1;
		}
	    case NAME_DIALOG:
	    {
	        if(response)
	        {
	            if(strlen(inputtext) < 1 || strlen(inputtext) > 64) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: Your house name must be from 1-64 characters long.");
	            
	            new houseid = PlayerData[playerid][player_houseid], name[64], query[128], label[128];
	            format(name, sizeof(name), "%s", inputtext);
	            
	            HouseData[houseid][house_name] = name;
	            
	            format(label, sizeof(label), "%s\nValue: $%i", HouseData[houseid][house_name], HouseData[houseid][house_value]);
				UpdateDynamic3DTextLabelText(HouseData[houseid][house_label], LABEL_COLOUR, label);

				format(query, sizeof(query), "UPDATE `HOUSES` SET `NAME` = '%q' WHERE `ID` = '%i'", HouseData[houseid][house_name], houseid);
				database_result = db_query(server_database, query);
				db_free_result(database_result);
				
				GameTextForPlayer(playerid, "~g~Name Changed!", 3000, 5);
	        }
	        return 1;
		}
	    case PASS_DIALOG:
	    {
	        if(response)
	        {
	            if(strlen(inputtext) < 3 || strlen(inputtext) > 32) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: Your house password must be from 3-32 characters long.");

				bcrypt_hash(playerid, "EncryptHousePassword", inputtext, 12, "i", PlayerData[playerid][player_houseid]);
	        }
	        return 1;
		}
	    case SAFE_DIALOG:
	    {
	        if(response)
	        {
	            new string[64];
	            switch(listitem)
	            {
	                case 0:
	                {
	                    format(string, sizeof(string), "{FFFFFF}Funds: $%i", HouseData[PlayerData[playerid][player_houseid]][house_safe]);
	                    return ShowPlayerDialog(playerid, BALANCE_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}Balance", string, "Back", "Close");
	                }
	                case 1:
	                {
	                    format(string, sizeof(string), "{FFFFFF}Deposit (Holding: $%i)", GetPlayerMoney(playerid));
	                    return ShowPlayerDialog(playerid, DEPOSIT_DIALOG, DIALOG_STYLE_INPUT, string, "{FFFFFF}How much would you like to deposit?", "Enter", "Back");
	                }
	                case 2:
	                {
	                    format(string, sizeof(string), "{FFFFFF}Withdraw (Funds: $%i)", HouseData[PlayerData[playerid][player_houseid]][house_safe]);
	                    return ShowPlayerDialog(playerid, WITHDRAW_DIALOG, DIALOG_STYLE_INPUT, string, "{FFFFFF}How much would you like to withdraw?", "Enter", "Back");
	                }
				}
	        }
	        return 1;
		}
	    case BALANCE_DIALOG:
	    {
	        if(response)
	        {
	            ShowPlayerDialog(playerid, SAFE_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Safe", "{FFFFFF}Balance\nDeposit\nWithdraw", "Select", "Cancel");
	        }
	        return 1;
		}
	    case DEPOSIT_DIALOG:
	    {
	        if(response)
	        {
	            if(!IsNumeric(inputtext) || strval(inputtext) < 1) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must input a number greater than 0.");
	            if(GetPlayerMoney(playerid) < strval(inputtext)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You are not holding that much money.");
	            
	            GivePlayerMoney(playerid, -strval(inputtext));
	            
	            new houseid = PlayerData[playerid][player_houseid], query[128];
	            HouseData[houseid][house_safe] = (HouseData[houseid][house_safe] + strval(inputtext));
	            
				format(query, sizeof(query), "UPDATE `HOUSES` SET `SAFE` = '%i' WHERE `ID` = '%i'", HouseData[houseid][house_safe], houseid);
				database_result = db_query(server_database, query);
				db_free_result(database_result);
	            
	            return GameTextForPlayer(playerid, "~g~Money Deposited!", 3000, 5);
	        }
	        else
	        {
	            ShowPlayerDialog(playerid, SAFE_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Safe", "{FFFFFF}Balance\nDeposit\nWithdraw", "Select", "Cancel");
	        }
	        return 1;
		}
	    case WITHDRAW_DIALOG:
	    {
	        if(response)
	        {
	            if(!IsNumeric(inputtext) || strval(inputtext) < 1) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must input a number greater than 0.");
	            
	            new houseid = PlayerData[playerid][player_houseid];
	            if(strval(inputtext) > HouseData[houseid][house_safe]) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You do not have that much money in your safe.");

	            GivePlayerMoney(playerid, strval(inputtext));

	            HouseData[houseid][house_safe] = (HouseData[houseid][house_safe] - strval(inputtext));

	            new query[128];
				format(query, sizeof(query), "UPDATE `HOUSES` SET `SAFE` = '%i' WHERE `ID` = '%i'", HouseData[houseid][house_safe], houseid);
				database_result = db_query(server_database, query);
				db_free_result(database_result);

	            return GameTextForPlayer(playerid, "~g~Money Withdrawn!", 3000, 5);
	        }
	        else
	        {
	            ShowPlayerDialog(playerid, SAFE_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Safe", "{FFFFFF}Balance\nDeposit\nWithdraw", "Select", "Cancel");
	        }
		}
		case SELL_DIALOG:
		{
	        if(response)
	        {
	            new houseid = PlayerData[playerid][player_houseid];
	            GivePlayerMoney(playerid, (HouseData[houseid][house_value] + HouseData[houseid][house_safe]));
	            
	            GameTextForPlayer(playerid, "~g~House Sold!", 3000, 5);
	            
				new name[64], owner[MAX_PLAYER_NAME], query[200], label[128];
				
				format(owner, sizeof(owner), "~");
				format(name, sizeof(name), "4-Sale");
				format(label, sizeof(label), "%s\nPrice: $%i", name, HouseData[houseid][house_value]);
				
				HouseData[houseid][house_owner] = owner;
				HouseData[houseid][house_name] = name;
				HouseData[houseid][house_safe] = 0;

				format(query, sizeof(query), "UPDATE `HOUSES` SET `OWNER` = '%q', `NAME` = '%q', `SAFE` = '%i' WHERE `ID` = '%i'", owner, name, HouseData[houseid][house_safe], houseid);
				database_result = db_query(server_database, query);
				db_free_result(database_result);
				
				DestroyDynamicMapIcon(HouseData[houseid][house_mapicon]);
				HouseData[houseid][house_mapicon] = CreateDynamicMapIcon(HouseData[houseid][house_extx], HouseData[houseid][house_exty], HouseData[houseid][house_extz], 31, -1, -1, -1, -1, 250.0);

				return UpdateDynamic3DTextLabelText(HouseData[houseid][house_label], LABEL_COLOUR, label);
	        }
		}
	}
	return 1;
}

public OnPlayerEnterDynamicCP(playerid, checkpointid)
{
    if(GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
    {
		for(new i = 0; i < MAX_HOUSES; i++)
		{
	    	if(HouseData[i][house_active] == true)
	    	{
	   	    	if(checkpointid == HouseData[i][house_entercp])
	   	    	{
	   	    	    new string[64];
	   	    	    if(!strcmp(HouseData[i][house_owner], "~", true))
			   		{
			   		    PlayerData[playerid][player_houseid] = i;

			   		    format(string, sizeof(string), "{FFFFFF}4-Sale: $%i", HouseData[i][house_value]);
					   	ShowPlayerDialog(playerid, BUY_DIALOG, DIALOG_STYLE_MSGBOX, string, "{FFFFFF}Would you like to buy or preview this house?", "Buy", "Preview");
					}
					else if(!strcmp(HouseData[i][house_owner], GetName(playerid), true))
					{
					    SetPlayerInterior(playerid, HouseData[i][house_intinterior]);
					    SetPlayerVirtualWorld(playerid, HouseData[i][house_intworld]);
	   	    	    	SetPlayerPos(playerid, HouseData[i][house_enterx], HouseData[i][house_entery], HouseData[i][house_enterz]);
	   	    	    	SetPlayerFacingAngle(playerid, HouseData[i][house_entera]);
	   	    	    	SetCameraBehindPlayer(playerid);

	   	    	    	SendClientMessage(playerid, NOTICE_COLOUR, "SERVER: Type /menu to access the list of house features.");
					}
					else
					{
			   		    PlayerData[playerid][player_houseid] = i;

					    format(string, sizeof(string), "{FFFFFF}Owner: %s", HouseData[i][house_owner]);
					    ShowPlayerDialog(playerid, ACCESS_DIALOG, DIALOG_STYLE_PASSWORD, string, "{FFFFFF}Please enter the password to gain access:", "Enter", "Cancel");
					}
					return 1;
	   	    	}
	   	    	else if(checkpointid == HouseData[i][house_exitcp])
	   	    	{
					SetPlayerInterior(playerid, HouseData[i][house_extinterior]);
					SetPlayerVirtualWorld(playerid, HouseData[i][house_extworld]);

	   	    	    SetPlayerPos(playerid, HouseData[i][house_exitx], HouseData[i][house_exity], HouseData[i][house_exitz]);
	   	    	    SetPlayerFacingAngle(playerid, HouseData[i][house_exita]);
	   	    	    return SetCameraBehindPlayer(playerid);
	   	    	}
   	    	}
		}
	}
	return 1;
}

public EncryptHousePassword(playerid, houseid)
{
	new password[64];
	bcrypt_get_hash(password);

	new query[128];
	format(query, sizeof(query), "UPDATE `HOUSES` SET `PASS` = '%s' WHERE `ID` = '%i'", password, houseid);
	database_result = db_query(server_database, query);
	db_free_result(database_result);
	
	return GameTextForPlayer(playerid, "~g~Password Changed!", 3000, 5);
}

public VerifyHousePassword(playerid, bool:success)
{
 	if(success)
	{
	    new houseid = PlayerData[playerid][player_houseid];
		SetPlayerInterior(playerid, HouseData[houseid][house_intinterior]);
		SetPlayerVirtualWorld(playerid, HouseData[houseid][house_intworld]);
   	  	SetPlayerPos(playerid, HouseData[houseid][house_enterx], HouseData[houseid][house_entery], HouseData[houseid][house_enterz]);
   	   	SetPlayerFacingAngle(playerid, HouseData[houseid][house_entera]);
   	 	return SetCameraBehindPlayer(playerid);
 	}
	else
 	{
 		SendClientMessage(playerid, ERROR_COLOUR, "SERVER: Invalid password. Contact the owner for access.");
 	}
	return 1;
}

CMD:hcmds(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");
	return ShowPlayerDialog(playerid, COMMANDS_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Commands", "{FFFFFF}/menu (Players)\n/sellhouse (Players)\n/accepthouse (Players)\n/declinehouse (Players)\n/createhouse (Admins)\n/deletehouse (Admins)\n/deleteallhouses (Admins)\n/resethouseprice (Admins)\n/resetallprices (Admins)\n/resethouseowner (Admins)\n/resetallowners (Admins)", "Close", "");
}

CMD:menu(playerid, params[])
{
	if(GetOwnedHouseID(playerid) == -1) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be inside an owned house to use /menu.");
	PlayerData[playerid][player_houseid] = GetOwnedHouseID(playerid);
	return ShowPlayerDialog(playerid, MENU_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Menu", "{FFFFFF}Access Safe\nChange Name\nChange Password\nSell House", "Select", "Cancel");
}

CMD:sellhouse(playerid, params[])
{
	new houseid = GetOwnedHouseID(playerid);
	if(houseid == -1) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be inside an owned house to sell it.");
	if((gettime() - 5) < PlayerData[playerid][player_spam]) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: Please wait 5 seconds before using this command again.");
    PlayerData[playerid][player_spam] = gettime();
    
	new targetid, price;
	if(sscanf(params, "ui", targetid, price)) return SendClientMessage(playerid, ERROR_COLOUR, "USAGE: /sellhouse [player] [price]");
	if(!IsPlayerConnected(targetid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player is not connected.");
	if(IsPlayerNPC(targetid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player is an NPC.");
	if(targetid == playerid) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You cannot sell your house to yourself.");
	if(price < 1) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: The sale price must be greater than 0.");
	
	PlayerData[targetid][player_salehouse] = houseid;
	PlayerData[targetid][player_saleprice] = price;
	PlayerData[targetid][player_saleowner] = playerid;

	PlayerData[targetid][player_saleactive] = true;
	
	PlayerData[playerid][player_saleto] = targetid;
	
	new string[200];
	format(string, sizeof(string), "SERVER: You have offered %s (%i) your house for $%i. Please wait for their response.", GetName(targetid), targetid, price);
	SendClientMessage(playerid, NOTICE_COLOUR, string);
	
	format(string, sizeof(string), "SERVER: %s (%i) has offered you their house for $%i. Type /accepthouse or /declinehouse to respond.", GetName(playerid), playerid, price);
	return SendClientMessage(targetid, NOTICE_COLOUR, string);
}

CMD:accepthouse(playerid, params[])
{
	if(PlayerData[playerid][player_saleactive] == false) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You have not been offered any houses to purchase.");
	
	new houseid = PlayerData[playerid][player_salehouse], price = PlayerData[playerid][player_saleprice], targetid = PlayerData[playerid][player_saleowner];
	if(targetid == INVALID_PLAYER_ID)
	{
		PlayerData[playerid][player_saleactive] = false;
		return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player has recently disconnected.");
	}
	if(PlayerData[targetid][player_saleto] != playerid)
	{
		PlayerData[playerid][player_saleactive] = false;
		return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player has offered the house to someone else.");
	}
	if(GetPlayerMoney(playerid) < PlayerData[playerid][player_saleprice]) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You don't have enough money to accept that offer.");
	
	GivePlayerMoney(playerid, -price);
	GivePlayerMoney(targetid, price);
	
	UpdateNearbyLandValue(houseid);
	
	PlayerData[playerid][player_saleactive] = false;
	PlayerData[targetid][player_saleto] = INVALID_PLAYER_ID;

	new query[128], label[128], name[64];
	GameTextForPlayer(playerid, "~g~Offer Accepted!", 3000, 5);
	GameTextForPlayer(targetid, "~g~Offer Accepted!", 3000, 5);

	format(name, sizeof(name), "%s's House", GetName(playerid));
	
	HouseData[houseid][house_owner] = GetName(playerid);
	HouseData[houseid][house_name] = name;
	
	GivePlayerMoney(targetid, HouseData[houseid][house_safe]);
	
	HouseData[houseid][house_safe] = 0;

	format(query, sizeof(query), "UPDATE `HOUSES` SET `OWNER` = '%q', `NAME` = '%q', `SAFE` = '%i' WHERE `ID` = '%i'", GetName(playerid), name, HouseData[houseid][house_safe], houseid);
	database_result = db_query(server_database, query);
	db_free_result(database_result);

	format(label, sizeof(label), "%s\nValue: $%i", name, HouseData[houseid][house_value]);
	return UpdateDynamic3DTextLabelText(HouseData[houseid][house_label], LABEL_COLOUR, label);
}

CMD:declinehouse(playerid, params[])
{
	if(PlayerData[playerid][player_saleactive] == false) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You have not been offered any houses to decline.");
	
	new targetid = PlayerData[playerid][player_saleowner];
	if(targetid == INVALID_PLAYER_ID)
	{
		PlayerData[playerid][player_saleactive] = false;
		return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player has recently disconnected.");
	}
	if(PlayerData[targetid][player_saleto] != playerid)
	{
		PlayerData[playerid][player_saleactive] = false;
		return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player has offered the house to someone else.");
	}

	PlayerData[playerid][player_saleactive] = false;
	PlayerData[targetid][player_saleto] = INVALID_PLAYER_ID;

	GameTextForPlayer(playerid, "~r~Offer Declined!", 3000, 5);
	return GameTextForPlayer(targetid, "~r~Offer Declined!", 3000, 5);
}

CMD:createhouse(playerid, params[])
{
	new type[16];
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");
	if(sscanf(params, "s[16]", type)) return SendClientMessage(playerid, ERROR_COLOUR, "USAGE: /createhouse [house1/house2/mansion1/mansion2/apartment]");
	if(IsPlayerNearHouse(playerid, 5.0)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You cannot create a house within 5 metres of another one.");

	new houseid = GetFreeHouseSlot(), owner[MAX_PLAYER_NAME], password[64], Float:pos[4], query[700], name[64], label[128];
	if(houseid == -1) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You have reached the max amount of houses the server can have, increase MAX_HOUSES in the script.");

	if(!strcmp(type, "house1", true))//1 Story House
	{
		HouseData[houseid][house_value] = HOUSE_ONE_PRICE;

		HouseData[houseid][house_intx] = 2196.84;
		HouseData[houseid][house_inty] = -1204.36;
		HouseData[houseid][house_intz] = 1049.02;
		
		HouseData[houseid][house_enterx] = 2193.9001;
		HouseData[houseid][house_entery] = -1202.4185;
		HouseData[houseid][house_enterz] = 1049.0234;
		HouseData[houseid][house_entera] = 91.9386;
		
		HouseData[houseid][house_intinterior] = 6;
		HouseData[houseid][house_intworld] = houseid;
	}
	else if(!strcmp(type, "house2", true))//2 Story House
	{
  		HouseData[houseid][house_value] = HOUSE_TWO_PRICE;

		HouseData[houseid][house_intx] = 2317.77;
		HouseData[houseid][house_inty] = -1026.76;
		HouseData[houseid][house_intz] = 1050.21;

		HouseData[houseid][house_enterx] = 2320.0730;
		HouseData[houseid][house_entery] = -1023.9533;
		HouseData[houseid][house_enterz] = 1050.2109;
		HouseData[houseid][house_entera] = 358.4915;

		HouseData[houseid][house_intinterior] = 9;
		HouseData[houseid][house_intworld] = houseid;
	}
	else if(!strcmp(type, "mansion1", true))//Small Mansion
	{
		HouseData[houseid][house_value] = MANSION_ONE_PRICE;

		HouseData[houseid][house_intx] = 2324.41;
		HouseData[houseid][house_inty] = -1149.54;
		HouseData[houseid][house_intz] = 1050.71;

		HouseData[houseid][house_enterx] = 2324.4490;
		HouseData[houseid][house_entery] = -1145.2841;
		HouseData[houseid][house_enterz] = 1050.7101;
		HouseData[houseid][house_entera] = 357.5873;

		HouseData[houseid][house_intinterior] = 12;
		HouseData[houseid][house_intworld] = houseid;
	}
	else if(!strcmp(type, "mansion2", true))//Large Mansion
	{
		HouseData[houseid][house_value] = MANSION_TWO_PRICE;

		HouseData[houseid][house_intx] = 140.28;
		HouseData[houseid][house_inty] = 1365.92;
		HouseData[houseid][house_intz] = 1083.85;

		HouseData[houseid][house_enterx] = 140.1788;
		HouseData[houseid][house_entery] = 1369.1936;
		HouseData[houseid][house_enterz] = 1083.8641;
		HouseData[houseid][house_entera] = 359.2263;

		HouseData[houseid][house_intinterior] = 5;
		HouseData[houseid][house_intworld] = houseid;
	}
	else if(!strcmp(type, "apartment", true))//Apartment
	{
		HouseData[houseid][house_value] = APARTMENT_PRICE;

		HouseData[houseid][house_intx] = 225.7121;
		HouseData[houseid][house_inty] = 1021.4438;
		HouseData[houseid][house_intz] = 1084.0177;

		HouseData[houseid][house_enterx] = 225.8993;
		HouseData[houseid][house_entery] = 1023.9148;
		HouseData[houseid][house_enterz] = 1084.0078;
		HouseData[houseid][house_entera] = 358.4921;

		HouseData[houseid][house_intinterior] = 7;
		HouseData[houseid][house_intworld] = houseid;
	}
	else return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: Invalid house type. Must be: house1/house2/mansion1/mansion2/apartment");
	
	format(owner, sizeof(owner), "~");
	format(password, sizeof(password), "$2y$12$1h2ra6euo5IoIGlVWgvnN.kIOiImlQRnML7Zw/GDZ6Ogb89kA9Lpe");//Randomized Bcrypt Password
	format(name, sizeof(name), "4-Sale", HouseData[houseid][house_value]);
	format(label, sizeof(label), "%s\nPrice: $%i", name, HouseData[houseid][house_value]);
	
	GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
	GetPlayerFacingAngle(playerid, pos[3]);
	
	HouseData[houseid][house_owner] = owner;
	HouseData[houseid][house_name] = name;
	HouseData[houseid][house_safe] = 0;
	HouseData[houseid][house_extx] = pos[0];
	HouseData[houseid][house_exty] = pos[1];
	HouseData[houseid][house_extz] = pos[2];
	
	GetPosBehindPlayer(playerid, pos[0], pos[1], 2.0);
	
	HouseData[houseid][house_exitx] = pos[0];
	HouseData[houseid][house_exity] = pos[1];
	HouseData[houseid][house_exitz] = pos[2];
	HouseData[houseid][house_exita] = (pos[3] + 180);
	
	SetPlayerPos(playerid, pos[0], pos[1], pos[2]);
	
	HouseData[houseid][house_active] = true;
	
	HouseData[houseid][house_extinterior] = GetPlayerInterior(playerid);
	HouseData[houseid][house_extworld] = GetPlayerVirtualWorld(playerid);
	
	HouseData[houseid][house_label] = CreateDynamic3DTextLabel(label, LABEL_COLOUR, HouseData[houseid][house_extx], HouseData[houseid][house_exty], HouseData[houseid][house_extz] + 0.2, 4.0, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 1, HouseData[houseid][house_extworld], HouseData[houseid][house_extinterior], -1, 4.0);
	HouseData[houseid][house_mapicon] = CreateDynamicMapIcon(HouseData[houseid][house_extx], HouseData[houseid][house_exty], HouseData[houseid][house_extz], 31, -1, -1, -1, -1, 250.0);
	
	HouseData[houseid][house_entercp] = CreateDynamicCP(HouseData[houseid][house_extx], HouseData[houseid][house_exty], HouseData[houseid][house_extz], 1.0, HouseData[houseid][house_extworld], HouseData[houseid][house_extinterior], -1, 4.0);
	HouseData[houseid][house_exitcp] = CreateDynamicCP(HouseData[houseid][house_intx], HouseData[houseid][house_inty], HouseData[houseid][house_intz], 1.0, HouseData[houseid][house_intworld], HouseData[houseid][house_intinterior], -1, 4.0);
	
	format(query, sizeof(query),
"INSERT INTO `HOUSES` (`ID`, `OWNER`, `NAME`, `PASS`, `VALUE`, `SAFE`, `EXTX`, `EXTY`, `EXTZ`, `INTX`, `INTY`, `INTZ`, `ENTERX`, `ENTERY`, `ENTERZ`, `ENTERA`, `EXITX`, `EXITY`, `EXITZ`, `EXITA`, `EXTINTERIOR`, `EXTWORLD`, `INTINTERIOR`, `INTWORLD`) VALUES ('%i', '%q', '%q', '%s', '%i', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%i', '%i', '%i')",
houseid, owner, name, password, HouseData[houseid][house_value], HouseData[houseid][house_safe], HouseData[houseid][house_extx], HouseData[houseid][house_exty], HouseData[houseid][house_extz], HouseData[houseid][house_intx], HouseData[houseid][house_inty], HouseData[houseid][house_intz], HouseData[houseid][house_enterx], HouseData[houseid][house_entery], HouseData[houseid][house_enterz], HouseData[houseid][house_entera],
HouseData[houseid][house_exitx], HouseData[houseid][house_exity], HouseData[houseid][house_exitz], HouseData[houseid][house_exita], HouseData[houseid][house_extinterior], HouseData[houseid][house_extworld], HouseData[houseid][house_intinterior], HouseData[houseid][house_intworld]);
	database_result = db_query(server_database, query);
	db_free_result(database_result);
	
	return GameTextForPlayer(playerid, "~g~House Created!", 3000, 5);
}

CMD:deletehouse(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");
	
	new query[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][house_active] == true)
	    {
		    if(IsPlayerInRangeOfPoint(playerid, 5.0, HouseData[i][house_extx], HouseData[i][house_exty], HouseData[i][house_extz]))
		  	{
				DestroyDynamic3DTextLabel(HouseData[i][house_label]);
				DestroyDynamicMapIcon(HouseData[i][house_mapicon]);
				DestroyDynamicCP(HouseData[i][house_entercp]);
				DestroyDynamicCP(HouseData[i][house_exitcp]);

				HouseData[i][house_active] = false;

				format(query, sizeof(query), "DELETE FROM `HOUSES` WHERE `ID` = '%i'", i);
				database_result = db_query(server_database, query);
				db_free_result(database_result);
				return GameTextForPlayer(playerid, "~r~House Deleted!", 3000, 5);
		    }
	    }
	}
	return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be within 5 metres of a house to delete it.");
}

CMD:deleteallhouses(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");

	new query[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][house_active] == true)
	    {
		    DestroyDynamic3DTextLabel(HouseData[i][house_label]);
			DestroyDynamicMapIcon(HouseData[i][house_mapicon]);
			DestroyDynamicCP(HouseData[i][house_entercp]);
			DestroyDynamicCP(HouseData[i][house_exitcp]);

			HouseData[i][house_active] = false;

			format(query, sizeof(query), "DELETE FROM `HOUSES` WHERE `ID` = '%i'", i);
			database_result = db_query(server_database, query);
			db_free_result(database_result);
		}
	}
	return GameTextForPlayer(playerid, "~r~All Houses Deleted!", 3000, 5);
}

CMD:resethouseowner(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");
	
	new owner[MAX_PLAYER_NAME], query[128], name[64], label[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][house_active] == true)
	    {
		    if(IsPlayerInRangeOfPoint(playerid, 5.0, HouseData[i][house_extx], HouseData[i][house_exty], HouseData[i][house_extz]))
		  	{
		    	GameTextForPlayer(playerid, "~r~House Owner Reset!", 3000, 5);

		     	format(owner, sizeof(owner), "~");
		     	format(name, sizeof(name), "4-Sale");
		      	format(label, sizeof(label), "%s\nPrice: $%i", name, HouseData[i][house_value]);

		      	HouseData[i][house_owner] = owner;
		     	HouseData[i][house_name] = name;
		     	HouseData[i][house_safe] = 0;

		      	DestroyDynamicMapIcon(HouseData[i][house_mapicon]);
				HouseData[i][house_mapicon] = CreateDynamicMapIcon(HouseData[i][house_extx], HouseData[i][house_exty], HouseData[i][house_extz], 31, -1, -1, -1, -1, 250.0);

				format(query, sizeof(query), "UPDATE `HOUSES` SET `OWNER` = '%q', `NAME` = '%q', `SAFE` = '%i' WHERE `ID` = '%i'", owner, name, HouseData[i][house_safe], i);
				database_result = db_query(server_database, query);
				db_free_result(database_result);

				return UpdateDynamic3DTextLabelText(HouseData[i][house_label], LABEL_COLOUR, label);
			}
		}
	}
	return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be within 5 metres of a house to reset the owner.");
}

CMD:resetallowners(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");

	new owner[MAX_PLAYER_NAME], query[128], name[64], label[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][house_active] == true)
	    {
		    format(owner, sizeof(owner), "~");
		 	format(name, sizeof(name), "4-Sale");
		 	format(label, sizeof(label), "%s\nPrice: $%i", name, HouseData[i][house_value]);

		  	HouseData[i][house_owner] = owner;
		  	HouseData[i][house_name] = name;
		  	HouseData[i][house_safe] = 0;

			DestroyDynamicMapIcon(HouseData[i][house_mapicon]);
			HouseData[i][house_mapicon] = CreateDynamicMapIcon(HouseData[i][house_extx], HouseData[i][house_exty], HouseData[i][house_extz], 31, -1, -1, -1, -1, 250.0);

			format(query, sizeof(query), "UPDATE `HOUSES` SET `OWNER` = '%q', `NAME` = '%q', `SAFE` = '%i' WHERE `ID` = '%i'", owner, name, HouseData[i][house_safe], i);
			database_result = db_query(server_database, query);
			db_free_result(database_result);

			UpdateDynamic3DTextLabelText(HouseData[i][house_label], LABEL_COLOUR, label);
		}
	}
	return GameTextForPlayer(playerid, "~r~All Owners Reset!", 3000, 5);
}

CMD:resethouseprice(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");

	new query[128], label[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][house_active] == true)
	    {
		    if(IsPlayerInRangeOfPoint(playerid, 5.0, HouseData[i][house_extx], HouseData[i][house_exty], HouseData[i][house_extz]))
		  	{
				if(HouseData[i][house_intinterior] == 6)//1 Story House
				{
		        	HouseData[i][house_value] = HOUSE_ONE_PRICE;
				}
				else if(HouseData[i][house_intinterior] == 9)//2 Story House
				{
		        	HouseData[i][house_value] = HOUSE_TWO_PRICE;
				}
				else if(HouseData[i][house_intinterior] == 12)//Small Mansion
				{
		         	HouseData[i][house_value] = MANSION_ONE_PRICE;
				}
				else if(HouseData[i][house_intinterior] == 5)//Large Mansion
				{
		         	HouseData[i][house_value] = MANSION_TWO_PRICE;
				}
				else if(HouseData[i][house_intinterior] == 7)//Apartment
				{
		       		HouseData[i][house_value] = APARTMENT_PRICE;
				}

				if(!strcmp(HouseData[i][house_owner], "~", true))
				{
					format(label, sizeof(label), "4-Sale\nPrice: $%i", HouseData[i][house_value]);
					UpdateDynamic3DTextLabelText(HouseData[i][house_label], LABEL_COLOUR, label);
				}
				else
				{
					format(label, sizeof(label), "%s\nValue: $%i", HouseData[i][house_name], HouseData[i][house_value]);
					UpdateDynamic3DTextLabelText(HouseData[i][house_label], LABEL_COLOUR, label);
				}

				format(query, sizeof(query), "UPDATE `HOUSES` SET `VALUE` = '%i' WHERE `ID` = '%i'", HouseData[i][house_value], i);
				database_result = db_query(server_database, query);
				db_free_result(database_result);

				return GameTextForPlayer(playerid, "~r~House Price Reset!", 3000, 5);
		    }
	    }
	}
	return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be within 5 metres of a house to delete it.");
}

CMD:resetallprices(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");
	
	new query[128], label[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][house_active] == true)
	    {
		    if(HouseData[i][house_intinterior] == 6)//1 Story House
			{
	       		HouseData[i][house_value] = HOUSE_ONE_PRICE;
			}
			else if(HouseData[i][house_intinterior] == 9)//2 Story House
			{
	        	HouseData[i][house_value] = HOUSE_TWO_PRICE;
			}
			else if(HouseData[i][house_intinterior] == 12)//Small Mansion
			{
	        	HouseData[i][house_value] = MANSION_ONE_PRICE;
			}
			else if(HouseData[i][house_intinterior] == 5)//Large Mansion
			{
	        	HouseData[i][house_value] = MANSION_TWO_PRICE;
			}
			else if(HouseData[i][house_intinterior] == 7)//Apartment
			{
	       		HouseData[i][house_value] = APARTMENT_PRICE;
			}

			if(!strcmp(HouseData[i][house_owner], "~", true))
			{
				format(label, sizeof(label), "4-Sale\nPrice: $%i", HouseData[i][house_value]);
				UpdateDynamic3DTextLabelText(HouseData[i][house_label], LABEL_COLOUR, label);
			}
			else
			{
				format(label, sizeof(label), "%s\nValue: $%i", HouseData[i][house_name], HouseData[i][house_value]);
				UpdateDynamic3DTextLabelText(HouseData[i][house_label], LABEL_COLOUR, label);
			}

			format(query, sizeof(query), "UPDATE `HOUSES` SET `VALUE` = '%i' WHERE `ID` = '%i'", HouseData[i][house_value], i);
			database_result = db_query(server_database, query);
			db_free_result(database_result);
		}
	}
	return GameTextForPlayer(playerid, "~r~All Prices Reset!", 3000, 5);
}

