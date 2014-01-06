#pragma semicolon 1

#include <sourcemod>
#include <steamtools>

#define MAX_MESSAGES 30
#define MAX_MESSAGE_LEN 256

new String:g_Messages[MAX_MESSAGES][MAX_MESSAGE_LEN];
new g_MessagesNum;

new Handle:g_Hostname;
new Handle:g_Prefix;

public OnPluginStart()
{
  AddCommandListener(Command_Say, "say");

  g_Hostname = FindConVar("hostname");
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

  new HTTPRequestHandle:HTTPRequest = INVALID_HTTP_HANDLE;
  HTTPRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, "http://hawkscatacombs.com:8000");
  Steam_SetHTTPRequestHeaderValue(HTTPRequest, "Content-Type", "text-html");
  Steam_SetHTTPRequestHeaderValue(HTTPRequest, "charset", "utf-8");
  Steam_SetHTTPRequestGetOrPostParameter(HTTPRequest, "hostname", hostname);
  Steam_SetHTTPRequestGetOrPostParameter(HTTPRequest, "messages", messages);
  Steam_SendHTTPRequest(HTTPRequest, OnHTTPRequestComplete);
}

public OnHTTPRequestComplete(HTTPRequestHandle:HTTPRequest, bool:requestSuccessful, HTTPStatusCode:statusCode)
{
  if (!requestSuccessful || statusCode != HTTPStatusCode_OK)
    return;

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
