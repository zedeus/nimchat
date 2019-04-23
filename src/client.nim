import asyncdispatch, asyncnet, os, threadpool, strutils, strformat
import ./protocol

type
  Client = ref object
    socket: AsyncSocket
    server: string
    port: int
    username: string

proc displayMessage(message: Message) =
  echo &"{message.username}: {message.text}"

proc connect(client: Client) {.async.} =
  echo "Connecting to ", client.server
  await connect(client.socket, client.server, Port(client.port))
  echo "Connected!"

proc login(client: Client) {.async.} =
  echo "Logging in to ", client.server
  let message = createMessage(client.username, "login", ConnectionMessage)
  await client.socket.send(message)

  let response = await client.socket.recvLine()
  let parsed = parseMessage(response)

  if parsed.mtype == ServiceMessage:
    displayMessage(parsed)
  elif parsed.mtype == ErrorMessage:
    quit("ERROR: " & parsed.text)

proc processMessages(client: Client) {.async.} =
  while true:
    let line = await client.socket.recvLine()
    let parsed = parseMessage(line)
    displayMessage(parsed)

proc processInput(client: Client) {.async.} =
  var messageFlowVar = spawn stdin.readLine()
  while true:
    if messageFlowVar.isReady():
      let message = createMessage(client.username, ^messageFlowVar, TextMessage)
      asyncCheck client.socket.send(message)
      messageFlowVar = spawn stdin.readLine()
    poll()

proc newClient(): Client =
  if paramCount() < 3:
    quit("Please specify server address, port and username\nExample: ./client localhost 7687 user")

  new(result)
  result.server = paramStr(1)
  result.port = parseInt(paramStr(2))
  result.username = paramStr(3)
  result.socket = newAsyncSocket()

proc main() =
  let client = newClient()
  waitFor client.connect()
  waitFor client.login()

  asyncCheck client.processMessages()
  waitFor client.processInput()

main()
