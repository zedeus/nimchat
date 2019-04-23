import asyncdispatch, asyncnet, os, strformat, strutils
import ./protocol

type
  Client = ref object
    socket: AsyncSocket
    netAddr: string
    connected: bool
    username: string
    id: int

  Server = ref object
    socket: AsyncSocket
    clients: seq[Client]

proc newServer(): Server =
  Server(socket: newAsyncSocket(), clients: @[])

proc `$`(client: Client): string =
  &"{client.id} ({client.netAddr})"

proc sendMessage(client: Client; text: string; mtype: MessageType) {.async.} =
  let message = createMessage("server", text, mtype)
  await client.socket.send(message)

proc sendError(client: Client; text: string) {.async.} =
  await sendMessage(client, text, ErrorMessage)

proc sendWarning(client: Client; text: string) {.async.} =
  await sendMessage(client, text, WarningMessage)

proc sendService(client: Client; text: string) {.async.} =
  if not client.connected: return
  await sendMessage(client, text, ServiceMessage)

proc relayMessage(server: Server; message: string; skip=(-1)) {.async.} =
  for c in server.clients:
    if c.connected and (skip == -1 or c.id != skip):
      await c.socket.send(message)

proc broadcast(server: Server; text: string; skip=(-1); mtype=ServiceMessage) {.async.} =
  let message = createMessage("server", text, mtype)
  await relayMessage(server, message, skip)

proc disconnect(client: Client) =
  echo client, " disconnected!"
  client.connected = false
  client.username = ""
  client.socket.close()

proc handleLogin(server: Server; client: Client; message: Message) {.async.} =
  if client.connected:
    return

  for c in server.clients:
    if c.username == message.username:
      await sendError(client, "Username already taken.")
      return

  client.username = message.username
  client.connected = true

  await sendService(client, "Login succesful.")
  await server.broadcast(&"user \"{client.username}\" has joined")

proc processMessage(server: Server; client: Client; message: string) {.async.} =
  let parsed = parseMessage(message)
  echo client, " sent: ", message

  case parsed.mtype
  of TextMessage:
    if verifyMessage(parsed):
      await relayMessage(server, message & "\c\l", skip=client.id)
    else:
      await sendWarning(client, "Message hash verification failed.")
  of ConnectionMessage:
    if parsed.text == "login":
      await handleLogin(server, client, parsed)
  else:
    discard

proc processClient(server: Server, client: Client) {.async.} =
  while true:
    let line = await client.socket.recvLine()
    if line.len == 0:
      if client.username != "":
        await server.broadcast(&"user \"{client.username}\" disconnected", skip=client.id)

      disconnect(client)
      return

    await processMessage(server, client, line)

proc loop(server: Server) {.async.} =
  while true:
    let (netAddr, clientSocket) = await server.socket.acceptAddr()
    let client = Client(
      socket: clientSocket,
      netAddr: netAddr,
      connected: false,
      id: server.clients.len
    )
    server.clients.add(client)
    asyncCheck server.processClient(client)
    echo "Accepted connection from ", netAddr, ", client id: ", client.id

proc main() =
  let server = newServer()
  var port = 7687

  if paramCount() == 1:
    port = paramStr(1).parseInt

  server.socket.bindAddr(Port(port))
  server.socket.listen()
  waitFor server.loop()

main()
