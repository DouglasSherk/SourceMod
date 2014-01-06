/**
 * Cross-Server Chat by Hawk552
 * Last update: Jan 6, 2014
 *
 * Description
 *  This plugin and Python script allows you to chat between any number of
 *  servers without actually playing in them. For example, you could connect
 *  3 servers together using this, and then talk with people in the 2nd and 3rd
 *  servers while you're in the 1st server.
 *
 * How it Works
 *  A Python script is provided which acts as the master server to receive all
 *  server messages. Each server pings the master server every second, with a
 *  payload including all messages that have been sent on this server in the
 *  last second, and the master server replies with all messages sent by other
 *  servers in the last second.
 *
 * Requirements
 *  You must install the SteamTools extension to use this.
 *  https://forums.alliedmods.net/showthread.php?t=129763
 *  You must also have access to a server capable of running Python scripts,
 *  with an open port that is not in use.
 *
 * ConVars
 *  * sm_csc_host (string) (def. "http://YOURHOST.com") - The host and port
 *    that the master server Python script resides at.
 *  * sm_csc_prefix (string) (def. "") - The prefix to use for sending
 *    messages. A blank prefix means that all messages are networked. An
 *    example prefix is "#", which would mean that all messages that you want
 *    networked must be of the format "#message", e.g. "#hi hawk".
 *
 * Installation
 *  1. Install the SteamTools extension, if you haven't already.
 *     https://forums.alliedmods.net/showthread.php?t=129763
 *  2. Install the plugin on every game server you want networked. See
 *     installing plugins.
 *     https://wiki.alliedmods.net/Managing_your_Sourcemod_installation#Installing_Plugins
 *  3. Install the Python script on the server you want to be the master server.
 *     1. Copy the cross-server-chat.py script to somewhere that you can run it.
 *     2. Edit it and be sure to change the following:
 *        HOST_NAME = 'YOURHOSTNAME.com'
 *        PORT_NUMBER = 8000
 *     3. Run it by typing |python cross-server-chat.py|.
 *        You may consider running it in a Screen session so that it doesn't
 *        get terminated when you close the terminal.
 *        http://www.gnu.org/software/screen/manual/screen.html
 *  4. Restart the game server(s).
 *
 * Changelog
 *  1.0   Jan 6, 2014
 *   * Initial version
 */

#pragma semicolon 1

#include <sourcemod>
#include <steamtools>

#define MAX_MESSAGES 30
#define MAX_MESSAGE_LEN 256

#define DEFAULT_HOST "http://YOURHOST.com:8000"

new String:g_Messages[MAX_MESSAGES][MAX_MESSAGE_LEN];
new g_MessagesNum;

new Handle:g_Hostname;
new Handle:g_RequestHost;
new Handle:g_Prefix;

public Plugin:myinfo =
{
	name = "Cross-Server Chat",
	author = "Hawk552",
	description = "Networked chat between any number of servers.",
	version = "1.0",
	url = "http://hawkscatacombs.com"
}

public OnPluginStart()
{
  AddCommandListener(Command_Say, "say");

  g_Hostname = FindConVar("hostname");
  g_RequestHost = CreateConvar("sm_csc_host", DEFAULT_HOST, "Hostname for the master server Python script");
  g_Prefix = CreateConVar("sm_csc_prefix", "", "Prefix symbol for cross-server chat messages");
}

public Steam_FullyLoaded()
{
  CreateTimer(1.0, Timer_SendHTTPRequest, _, TIMER_REPEAT);
}

public Action:Timer_SendHTTPRequest(Handle:timer)
{
  decl String:messages[4096];
  messages[0] = '\0';
  for (new i = 0; i < g_MessagesNum; i++) {
    if (i > 0) {
      StrCat(messages, sizeof(messages), "\n");
    }
    StrCat(messages, sizeof(messages), g_Messages[i]);
  }
  g_MessagesNum = 0;

  decl String:hostname[128];
  GetConVarString(g_Hostname, hostname, sizeof(hostname));

  decl String:requestHost[128];
  GetConVarString(g_RequestHost, requestHost, sizeof(requestHost));

  if (strcmp(requestHost, DEFAULT_HOST) == 0) {
    PrintToServer("[SM] You have not set sm_csc_host.");
    PrintToServer("You must install the Python master server script on some");
    PrintToServer("server, and then point this server to it with this cvar.");
    return Plugin_Continue;
  }

  new HTTPRequestHandle:HTTPRequest = INVALID_HTTP_HANDLE;
  HTTPRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, requestHost);
  Steam_SetHTTPRequestHeaderValue(HTTPRequest, "Content-Type", "text-html");
  Steam_SetHTTPRequestHeaderValue(HTTPRequest, "charset", "utf-8");
  Steam_SetHTTPRequestGetOrPostParameter(HTTPRequest, "hostname", hostname);
  Steam_SetHTTPRequestGetOrPostParameter(HTTPRequest, "messages", messages);
  Steam_SendHTTPRequest(HTTPRequest, OnHTTPRequestComplete);

  return Plugin_Continue;
}

public OnHTTPRequestComplete(HTTPRequestHandle:HTTPRequest, bool:requestSuccessful, HTTPStatusCode:statusCode)
{
  if (!requestSuccessful || statusCode != HTTPStatusCode_OK) {
    PrintToServer("[SM] (Error %d) Failed to retrieve master server messages.", statusCode);
    return;
  }

  decl String:msg[4096];
  new responseSize = Steam_GetHTTPResponseBodySize(HTTPRequest);
  if (responseSize > 0) {
    Steam_GetHTTPResponseBodyData(HTTPRequest, msg, sizeof(msg));
  }

  Steam_ReleaseHTTPRequest(HTTPRequest);
  HTTPRequest = INVALID_HTTP_HANDLE;

  if (responseSize <= 0) {
    return;
  }

  decl String:messages[MAX_MESSAGES][MAX_MESSAGE_LEN];
  new numMessages = ExplodeString(msg, "\n", messages, MAX_MESSAGES, MAX_MESSAGE_LEN, true);

  for (new i = 0; i < numMessages; i++) {
    PrintToServer("(REMOTE) %s", messages[i]);
    PrintToChatAll("(REMOTE) %s", messages[i]);
  }
}

public Action:Command_Say(client, const String:command[], argc)
{
  decl String:text[MAX_MESSAGE_LEN];
  new startIndex = 0;
  if (GetCmdArgString(text, sizeof(text)) < 1) {
    return Plugin_Continue;
  }

  if (text[strlen(text)-1] == '"') {
    text[strlen(text)-1] = '\0';
    startIndex = 1;
  }

  decl String:prefix[10];
  GetConVarString(g_Prefix, prefix, sizeof(prefix));
  new prefixLen = strlen(prefix);

  if (strncmp(text[startIndex], prefix, prefixLen) == 0) {
    // Ignore the prefix.
    startIndex += prefixLen;

    FormatEx(g_Messages[g_MessagesNum++], MAX_MESSAGE_LEN, "%N:  %s", client, text[startIndex]);

    if (prefix[0] == '\0') {
      return Plugin_Continue;
    } else {
      PrintToChatAll("(TO REMOTES) %N:  %s", client, text[startIndex]);
      PrintToServer("(TO REMOTES) %N:  %s", client, text[startIndex]);
      return Plugin_Handled;
    }
  }

  return Plugin_Continue;
}
